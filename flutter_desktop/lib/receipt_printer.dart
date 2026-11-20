import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'operations.dart';
import 'pos_logic.dart';
import 'pos_store.dart';
import 'receipt_layout.dart';
import 'trendyol_go_readonly.dart';

typedef PrintTransport = Future<void> Function(String text, String printer);

/// One laptop owns the queue. A spool acknowledgement is not a paper sensor.
class ReceiptPrinter {
  ReceiptPrinter(this.store, {PrintTransport? transport})
    : transport =
          transport ??
          ((text, printer) => windowsPrint(
            text,
            printer,
            settings: store.read().data['settings'] as Map?,
          ));
  final PosStore store;
  final PrintTransport transport;
  bool _busy = false, _disposed = false;
  Timer? _timer;

  void start() {
    // A crash during spooling is ambiguous: never blindly print it twice.
    final snap = store.read(), next = copyJson(store.read().data);
    var changed = false;
    for (final j in (next['printJobs'] as List).cast<Map>()) {
      if (j['state'] == 'Gönderiliyor') {
        j['state'] = 'Kontrol gerekli';
        j['error'] =
            'Program gönderim sırasında kapandı; yazıcıyı kontrol edin.';
        changed = true;
      }
    }
    for (final order in mutableTgoOrders(next)) {
      if (order['kitchenPrintState'] == 'Gönderiliyor') {
        order['kitchenPrintState'] = 'Kontrol gerekli';
        changed = true;
      }
    }
    if (changed) store.replace(next, snap.revision);
    _timer = Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => unawaited(pump()),
    );
  }

  Future<void> pump() async {
    if (_busy || _disposed) return;
    _busy = true;
    try {
      final snap = store.read(), next = copyJson(snap.data);
      final settings = next['settings'] as Map? ?? {};
      final printer = '${settings['printerName'] ?? ''}'.trim();
      if (printer.isEmpty) return;
      for (final order in mutableTgoOrders(next)) {
        if (order['kitchenPrintState'] != 'Bekliyor') continue;
        if (!tgoKitchenActive(order)) {
          order['kitchenPrintState'] = 'Atlandı';
          store.replace(next, snap.revision);
          return;
        }
        order['kitchenPrintState'] = 'Gönderiliyor';
        if (!store.replace(next, snap.revision).ok) return;
        var outcome = 'Kuyruğa gönderildi';
        try {
          await transport(tgoKitchenTicket(order), printer);
        } catch (_) {
          outcome = 'Kontrol gerekli';
        }
        if (_disposed) return;
        final current = store.read(), updated = copyJson(current.data);
        final key = tgoOrderKey(order);
        for (final target in mutableTgoOrders(updated)) {
          if (tgoOrderKey(target) == key &&
              target['kitchenPrintState'] == 'Gönderiliyor') {
            target['kitchenPrintState'] = outcome;
          }
        }
        store.replace(updated, current.revision);
        return;
      }
      final paymentOnly = settings['receiptPolicy'] == 'onPayment';
      if (!paymentOnly && settings['autoPrint'] != true) return;
      Map? job;
      for (final candidate in (next['printJobs'] as List).cast<Map>()) {
        final o = mutableOrder(next, candidate['orderId'] as int);
        if ((!paymentOnly || candidate['kind'] == 'paymentReceipt') &&
            candidate['state'] == 'Bekliyor' &&
            candidate['createdAt'] is String &&
            (settings['autoPrintEnabledAt'] == null ||
                '${candidate['createdAt']}'.compareTo(
                      '${settings['autoPrintEnabledAt']}',
                    ) >=
                    0) &&
            o != null &&
            (o['cancelled'] != true || correctionKitchenJob(next, candidate)) &&
            !isPlatform(o)) {
          job = candidate;
          break;
        }
      }
      if (job == null) return;
      final id = job['orderId'], batch = job['batchId'];
      final text = job['kind'] == 'paymentReceipt'
          ? job['text'] as String
          : receiptText(next, Map<String, dynamic>.from(job));
      job['state'] = 'Gönderiliyor';
      job['attempts'] = (job['attempts'] as int? ?? 0) + 1;
      if (!store.replace(next, snap.revision).ok) return;
      String? failure;
      try {
        await transport(text, printer);
      } catch (e) {
        failure = '$e';
      }
      if (_disposed) return;
      // Read current state after I/O, preserving intervening phone orders.
      final result = store.read(), finished = copyJson(result.data);
      final target = (finished['printJobs'] as List).cast<Map>().firstWhere(
        (j) => j['orderId'] == id && j['batchId'] == batch,
      );
      target['state'] = failure == null
          ? 'Kuyruğa gönderildi'
          : 'Kontrol gerekli';
      target['error'] = failure ?? '';
      target['spooledAt'] = DateTime.now().toUtc().toIso8601String();
      store.replace(finished, result.revision);
    } finally {
      _busy = false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}

Future<void> windowsPrint(String text, String printer, {Map? settings}) async {
  if (!Platform.isWindows) {
    throw const FormatException('Windows yazıcısı gerekir');
  }
  final dir = await Directory.systemTemp.createTemp('nohut-receipt-');
  try {
    final cfg = ReceiptDimensions(settings);
    final transport = settings?['receiptTransport'] ?? 'windows';
    if (!['windows', 'escpos'].contains(transport))
      throw const FormatException('Yazdırma yöntemi geçersiz');
    if (transport == 'escpos' && cfg.offset != 0)
      throw const FormatException(
        'ESC/POS için yatay kaydırma 0 olmalı; kağıdı ortalayın',
      );
    final artwork = await renderReceipt(text, settings: settings);
    await File('${dir.path}/receipt.png').writeAsBytes(artwork.png);
    if (transport == 'escpos')
      await File('${dir.path}/receipt.bin')
          .writeAsBytes(escPosReceipt(artwork));
    await File('${dir.path}/job.json').writeAsString(
      jsonEncode({
        'printer': printer,
        'transport': transport,
        'imagePath': '${dir.path}/receipt.png',
        'rawPath': '${dir.path}/receipt.bin',
        'paperWidthMm': cfg.paper,
        'printableWidthMm': cfg.width,
        'marginMm': cfg.margin,
        'offsetMm': cfg.offset,
      }),
    );
    final executable =
        '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe';
    final script = await rootBundle.loadString(
      'assets/printing/print-raster.ps1',
    );
    final body = script.replaceFirst(
      RegExp(r'^param[^\n]*\n'),
      r'$JobPath = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($env:NOHUT_RECEIPT_JOB))'
      '\n',
    );
    final command =
        '[Console]::OutputEncoding = [Text.UTF8Encoding]::new(\$false)\n'
        'try {\n$body\n'
        r'} catch { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }'
        '\nexit 0';
    // PowerShell's EncodedCommand expects UTF-16LE; job data never enters source.
    final encoded = base64Encode([
      for (final unit in command.codeUnits) ...[unit & 255, unit >> 8],
    ]);
    final process = await Process.start(
      executable,
      ['-NoProfile', '-NonInteractive', '-EncodedCommand', encoded],
      environment: {
        'NOHUT_RECEIPT_JOB': base64Encode(utf8.encode('${dir.path}/job.json')),
      },
    );
    await process.stdin.close();
    final output = process.stdout.drain<void>();
    final errors = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .join();
    int code;
    try {
      code = await process.exitCode.timeout(const Duration(seconds: 45));
    } on TimeoutException {
      process.kill();
      await process.exitCode;
      throw const FormatException(
        'Yazıcı yanıtı belirsiz. Tekrar basmadan önce çıktıyı kontrol edin.',
      );
    }
    await output;
    final error = await errors;
    if (code != 0) throw FormatException('Yazıcı hatası: $error');
  } finally {
    await dir.delete(recursive: true);
  }
}
