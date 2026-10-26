import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:printing/printing.dart';
import 'ticket_document.dart';
import 'ticket_pdf.dart';
import 'pos_store.dart';
import 'pos_logic.dart';
import 'operations.dart';
import 'platform_receipt.dart';
import 'package:pdf/pdf.dart';

bool printCompleted(Json j) => [
  'İşaretlendi',
  'Simüle edildi',
  'Sürücüye Gönderildi',
].contains(j['state']);
bool printUncertain(Json j) =>
    ['Gönderiliyor', 'Belirsiz'].contains(j['state']);
String printJobKey(Json j) => '${j['orderId']}:${j['batchId']}';

abstract class PrinterGateway {
  Future<bool> send(PrintableTicket document, String printerUrl, String name);
}

class WindowsPrinterGateway implements PrinterGateway {
  @override
  Future<bool> send(
    PrintableTicket document,
    String printerUrl,
    String name,
  ) async {
    final info = await Printing.info();
    if (!info.canPrint || !info.directPrint) {
      throw const FormatException(
        'Windows doğrudan yazdırma desteği bulunamadı.',
      );
    }
    return Printing.directPrintPdf(
      printer: Printer(url: printerUrl),
      name: name,
      onLayout: (_) async => document.bytes,
      format: document.format,
      dynamicLayout: false,
    );
  }
}

class PrintService {
  PrintService(
    this.store, {
    PrinterGateway? gateway,
    Future<PrintableTicket> Function(TicketDocument)? render,
  }) : gateway = gateway ?? WindowsPrinterGateway(),
       render = render ?? TicketPdf.render;
  static final _active = <String>{};
  final PosStore store;
  final PrinterGateway gateway;
  final Future<PrintableTicket> Function(TicketDocument) render;
  String token() => base64UrlEncode(
    List.generate(24, (_) => Random.secure().nextInt(256)),
  ).replaceAll('=', '');
  Map<dynamic, dynamic> find(Json s, String key) => (s['printJobs'] as List)
      .whereType<Map>()
      .firstWhere((j) => printJobKey(j.cast<String, dynamic>()) == key);
  Future<String> print(String key) async {
    if (!_active.add(store.filePath)) {
      throw const FormatException('Tek yazıcıda başka işlem devam ediyor.');
    }
    RandomAccessFile? lock;
    var held = false;
    try {
      lock = File(
        '${store.filePath}.printer.lock',
      ).openSync(mode: FileMode.append);
      try {
        lock.lockSync(FileLock.exclusive);
        held = true;
      } on FileSystemException {
        throw const FormatException('Tek yazıcıda başka işlem devam ediyor.');
      }
      return await _print(key);
    } finally {
      if (held) lock?.unlockSync();
      lock?.closeSync();
      _active.remove(store.filePath);
    }
  }

  Future<String> _print(String key) async {
    final claim = token();
    final result = store.command('print_$claim', {'job': key}, (s) {
      final settings = s['settings'] as Map? ?? {};
      if (settings['printerMode'] != 'windows' ||
          '${settings['printerUrl'] ?? ''}'.isEmpty) {
        throw const FormatException(
          'Önce Ayarlar’dan tek Windows / USB yazıcısını seçin.',
        );
      }
      final j = find(s, key);
      if (printCompleted(j.cast<String, dynamic>()) ||
          printUncertain(j.cast<String, dynamic>())) {
        throw const FormatException(
          'İş tamamlandı veya sonucu belirsiz. Yeniden gönderilmedi.',
        );
      }
      final order = mutableOrder(s, j['orderId'] as int)!;
      final platform = isPlatform(order);
      final original = platform
          ? originalPlatformReceipt(j.cast<String, dynamic>())
          : null;
      final document = platform
          ? null
          : kitchenTicket(s, j.cast<String, dynamic>());
      if (document != null && document.lines.isEmpty) {
        throw const FormatException('Bu partide yazdırılacak ürün yok.');
      }
      if (document != null) j['ticketSnapshot'] = document.toJson();
      j['state'] = 'Gönderiliyor';
      j['claim'] = claim;
      j['attempts'] = (j['attempts'] as int? ?? 0) + 1;
      (j.putIfAbsent('audit', () => <dynamic>[]) as List).add({
        'at': utcNow(),
        'actor': 'Kasa (PC)',
        'action': 'Windows kuyruğuna gönderim başlatıldı',
        'claim': claim,
      });
      return {
        'document': document?.toJson(),
        'platformPdf': original == null ? null : base64Encode(original),
        'printerUrl': settings['printerUrl'],
      };
    });
    var enteredDriver = false;
    String state, error = '';
    try {
      final PrintableTicket document;
      if (result['platformPdf'] != null) {
        final bytes = base64Decode('${result['platformPdf']}');
        final page = await Printing.raster(
          bytes,
          pages: const [0],
          dpi: 72,
        ).first;
        document = PrintableTicket(
          bytes,
          PdfPageFormat(page.width.toDouble(), page.height.toDouble()),
        );
      } else {
        document = await render(
          TicketDocument.fromJson(
            (result['document'] as Map).cast<String, dynamic>(),
          ),
        );
      }
      final digest = sha256.convert(document.bytes).toString();
      store.command('print_pdf_$claim', {'job': key, 'sha256': digest}, (s) {
        final j = find(s, key);
        if (j['claim'] != claim || j['state'] != 'Gönderiliyor') {
          throw const FormatException('Yazdırma sahipliği değişti.');
        }
        j['pdfSha256'] = digest;
        return {};
      });
      enteredDriver = true;
      final sent = await gateway.send(
        document,
        '${result['printerUrl']}',
        'Nohut Falafel $key',
      );
      state = sent ? 'Sürücüye Gönderildi' : 'Bekliyor';
      error = sent
          ? 'Windows kuyruğu kabul etti; fiziksel çıktı ayrıca kontrol edilmeli.'
          : 'Yazdırma iptal edildi.';
    } catch (_) {
      state = enteredDriver ? 'Belirsiz' : 'Hata';
      error = enteredDriver
          ? 'Sürücü sonucu bilinmiyor. Fiziksel çıktıyı ve Windows kuyruğunu doğrulayın; otomatik tekrar yok.'
          : 'PDF hazırlanamadı; sürücüye gönderilmedi.';
    }
    store.command('print_result_$claim', {'state': state}, (s) {
      final j = find(s, key);
      if (j['claim'] != claim || j['state'] != 'Gönderiliyor') {
        throw const FormatException(
          'Yazdırma sonucu elle değiştirilmiş; üzerine yazılmadı.',
        );
      }
      j['state'] = state;
      j['error'] = error;
      (j['audit'] as List).add({
        'at': utcNow(),
        'actor': 'Kasa (PC)',
        'action': state,
        'error': error,
      });
      return {};
    });
    return state;
  }

  void reconcile(
    String key, {
    required bool outputExists,
    required String reason,
  }) {
    if (!_active.add(store.filePath)) {
      throw const FormatException('Tek yazıcıda başka işlem devam ediyor.');
    }
    RandomAccessFile? lock;
    var held = false;
    try {
      lock = File(
        '${store.filePath}.printer.lock',
      ).openSync(mode: FileMode.append);
      try {
        lock.lockSync(FileLock.exclusive);
        held = true;
      } on FileSystemException {
        throw const FormatException(
          'Yazıcı işlemi devam ediyor; henüz doğrulama yapılamaz.',
        );
      }
      _reconcile(key, outputExists: outputExists, reason: reason);
    } finally {
      if (held) lock?.unlockSync();
      lock?.closeSync();
      _active.remove(store.filePath);
    }
  }

  void _reconcile(
    String key, {
    required bool outputExists,
    required String reason,
  }) {
    if (reason.trim().isEmpty) {
      throw const FormatException('Kontrol açıklaması gerekli.');
    }
    final request = token();
    store.command(
      'print_check_$request',
      {'job': key, 'outputExists': outputExists},
      (s) {
        final j = find(s, key);
        if (!printUncertain(j.cast<String, dynamic>())) {
          throw const FormatException(
            'Yalnız belirsiz / yarım kalmış işler doğrulanabilir.',
          );
        }
        j['state'] = outputExists ? 'Sürücüye Gönderildi' : 'Bekliyor';
        j['error'] = 'Elle doğrulandı: ${reason.trim()}';
        (j.putIfAbsent('audit', () => <dynamic>[]) as List).add({
          'at': utcNow(),
          'actor': 'Kasa (PC)',
          'action': outputExists
              ? 'Çıktı var'
              : 'Çıktı yok; yeniden kuyruğa alındı',
          'reason': reason.trim(),
        });
        return {};
      },
    );
  }
}
