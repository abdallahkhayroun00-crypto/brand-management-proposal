import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'operations_ui.dart';
import 'ticket_document.dart';
import 'ticket_pdf.dart';

Future<void> saveTicketPdf(
  BuildContext context,
  TicketDocument document,
) async {
  final fields = await askFields(context, '80 mm PDF Kaydet', [
    (
      'Yeni PDF dosya yolu',
      path.join(
        Directory.current.path,
        'nohut-${document.kind.name}-${document.orderId}-${document.batchId}.pdf',
      ),
    ),
  ]);
  if (fields == null) return;
  try {
    final file = File(fields[0]);
    if (file.existsSync()) {
      throw const FormatException('Dosya zaten var. Yeni bir ad seçin.');
    }
    final bytes = await TicketPdf.build(document);
    // Reserve the name atomically after rendering, including concurrent exports.
    await file.create(exclusive: true);
    await file.writeAsBytes(bytes, flush: true);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF kaydedildi: ${file.path}')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF kaydedilemedi: $e')));
    }
  }
}
