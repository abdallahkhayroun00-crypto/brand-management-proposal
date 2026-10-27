import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'operations.dart';
import 'pos_logic.dart';
import 'pos_store.dart';

typedef PrintTransport = Future<void> Function(String text, String printer);

/// One laptop owns the queue. A spool acknowledgement is not a paper sensor.
class ReceiptPrinter {
  ReceiptPrinter(this.store, {PrintTransport? transport})
    : transport = transport ?? windowsPrint;
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
      if (printer.isEmpty || settings['autoPrint'] != true) return;
      Map? job;
      for (final candidate in (next['printJobs'] as List).cast<Map>()) {
        final o = mutableOrder(next, candidate['orderId'] as int);
        if (candidate['state'] == 'Bekliyor' &&
            candidate['createdAt'] is String &&
            (settings['autoPrintEnabledAt'] == null ||
                '${candidate['createdAt']}'.compareTo(
                      '${settings['autoPrintEnabledAt']}',
                    ) >=
                    0) &&
            o != null &&
            o['cancelled'] != true &&
            !isPlatform(o)) {
          job = candidate;
          break;
        }
      }
      if (job == null) return;
      final id = job['orderId'], batch = job['batchId'];
      final text = receiptText(next, Map<String, dynamic>.from(job));
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

Future<void> windowsPrint(String text, String printer) async {
  if (!Platform.isWindows) {
    throw const FormatException('Windows yazıcısı gerekir');
  }
  final dir = await Directory.systemTemp.createTemp('nohut-receipt-');
  try {
    final logo = await rootBundle.load(
      'assets/printing/nohut-receipt-logo.png',
    );
    await File('${dir.path}/logo.png').writeAsBytes(
      logo.buffer.asUint8List(logo.offsetInBytes, logo.lengthInBytes),
    );
    await File('${dir.path}/job.json').writeAsString(
      jsonEncode({
        'text': text,
        'printer': printer,
        'logo': '${dir.path}/logo.png',
      }),
    );
    final executable =
        '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe';
    final script = await rootBundle.loadString(
      'assets/printing/print-receipt.ps1',
    );
    final body = script.replaceFirst(
      RegExp(r'^param[^\n]*\n'),
      r'$JobPath = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($env:NOHUT_RECEIPT_JOB))'
      '\n',
    );
    final command =
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
    final errors = process.stderr.transform(utf8.decoder).join();
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
