import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'ticket_document.dart';
import 'pos_logic.dart';
import 'workspace_ui.dart' show istanbulTime;

class TicketPdf {
  static Future<Uint8List> build(TicketDocument ticket) async =>
      (await render(ticket)).bytes;
  static Future<PrintableTicket> render(TicketDocument ticket) async {
    if (ticket.source == 'Trendyol Go' || ticket.source == 'Yemeksepeti') {
      throw const FormatException(
        'Platform siparişinde orijinal platform fişi kullanılır; Nohut fişi üretilmez.',
      );
    }
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/nohut-wordmark.png')).buffer.asUint8List(),
    );
    final doc = pw.Document(
      title: '${ticket.heading} ${ticket.reference}',
      author: 'Nohut Falafel',
      creator: 'Nohut Falafel Desktop',
    );
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    final chunks = <List<TicketLine>>[];
    for (var i = 0; i < ticket.lines.length; i += 20) {
      chunks.add(
        ticket.lines.sublist(i, (i + 20).clamp(0, ticket.lines.length)),
      );
    }
    if (chunks.isEmpty) chunks.add([]);
    for (var page = 0; page < chunks.length; page++) {
      final last = page == chunks.length - 1;
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          margin: const pw.EdgeInsets.all(4 * PdfPageFormat.mm),
          theme: theme,
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Center(
                child: pw.Image(
                  logo,
                  width: 148,
                  height: 106,
                  fit: pw.BoxFit.contain,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                ticket.heading,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: bold, fontSize: 18),
              ),
              if (chunks.length > 1)
                pw.Text(
                  'Bölüm ${page + 1}/${chunks.length} - Aynı sipariş',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7),
                ),
              pw.Divider(thickness: 1.4, height: 22),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      ticket.destination,
                      style: pw.TextStyle(font: bold, fontSize: 15),
                    ),
                  ),
                  pw.SizedBox(width: 4),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        ticket.reference,
                        style: pw.TextStyle(font: bold, fontSize: 12),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        istanbulTime(ticket.stamp).replaceAll(' · ', ' '),
                        style: const pw.TextStyle(fontSize: 6.5),
                      ),
                    ],
                  ),
                ],
              ),
              if (ticket.externalCode.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 5),
                  child: pw.Text(
                    'Platform Sipariş: ${ticket.externalCode}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
              pw.Divider(height: 24, borderStyle: pw.BorderStyle.dashed),
              for (final line in chunks[page])
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 19,
                        child: pw.Text(
                          '${line.quantity}',
                          style: pw.TextStyle(font: bold, fontSize: 13),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              line.name,
                              style: pw.TextStyle(font: bold, fontSize: 10.5),
                            ),
                            for (final removed in line.removed)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 3),
                                child: pw.Text(
                                  'Çıkar: $removed',
                                  style: const pw.TextStyle(fontSize: 7),
                                ),
                              ),
                            if (line.note.isNotEmpty)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(top: 3),
                                child: pw.Text(
                                  line.note,
                                  style: const pw.TextStyle(fontSize: 7),
                                ),
                              ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 4),
                      if (ticket.kind != TicketKind.correction)
                        pw.Text(
                          formatTry(line.amountCents),
                          style: pw.TextStyle(font: bold, fontSize: 7),
                        ),
                    ],
                  ),
                ),
              if (last) ...[
                pw.Divider(height: 18, borderStyle: pw.BorderStyle.dashed),
                if (ticket.kind == TicketKind.bill &&
                    ticket.lineSubtotalCents != ticket.totalCents) ...[
                  pw.Text(
                    'Ürün toplamı: ${formatTry(ticket.lineSubtotalCents)}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    'Platform tutar farkı: ${formatTry(ticket.totalCents - ticket.lineSubtotalCents)}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.SizedBox(height: 6),
                ],
                pw.Text(
                  'Toplam Ürün: ${ticket.quantity}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Divider(height: 18, borderStyle: pw.BorderStyle.dashed),
                if (ticket.kind != TicketKind.correction)
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          ticket.totalLabel,
                          style: pw.TextStyle(font: bold, fontSize: 9.5),
                        ),
                      ),
                      pw.Text(
                        formatTry(ticket.totalCents),
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: ticket.platformTotalCents == null ? 15 : 11,
                        ),
                      ),
                    ],
                  ),
                if (ticket.platformTotalCents != null) ...[
                  pw.SizedBox(height: 7),
                  if (ticket.kind == TicketKind.newOrder &&
                      ticket.platformTotalCents != ticket.totalCents)
                    pw.Text(
                      'Platform tutar farkı: ${formatTry(ticket.platformTotalCents! - ticket.totalCents)}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          'PLATFORM SİPARİŞ TOPLAMI',
                          style: pw.TextStyle(font: bold, fontSize: 8),
                        ),
                      ),
                      pw.Text(
                        formatTry(ticket.platformTotalCents!),
                        style: pw.TextStyle(font: bold, fontSize: 15),
                      ),
                    ],
                  ),
                  pw.Text(
                    'Tahsilat / kurye platforma aittir.',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ],
                if (ticket.kind == TicketKind.bill) ...[
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Alınan: ${formatTry(ticket.paidCents)}   Kalan: ${formatTry(ticket.dueCents)}',
                    style: pw.TextStyle(font: bold, fontSize: 9),
                  ),
                  for (final p in ticket.payments)
                    pw.Text(p, style: const pw.TextStyle(fontSize: 8)),
                ],
                pw.Divider(height: 22, borderStyle: pw.BorderStyle.dashed),
                pw.Text(
                  'Afiyet Olsun',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: bold, fontSize: 16),
                ),
                pw.Text(
                  'Nohut Falafel',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  ticket.legal,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 6),
                ),
              ],
            ],
          ),
        ),
      );
    }
    final bytes = await doc.save();
    return PrintableTicket(
      bytes,
      doc.document.pdfPageList.pages.first.pageFormat,
    );
  }
}

class PrintableTicket {
  const PrintableTicket(this.bytes, this.format);
  final Uint8List bytes;
  final PdfPageFormat format;
}
