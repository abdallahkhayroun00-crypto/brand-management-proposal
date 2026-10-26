import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:printing/printing.dart';
import 'operations_ui.dart';
import 'pos_logic.dart';
import 'platform_receipt.dart';
import 'workspace_ui.dart';

class PlatformReceiptView extends StatelessWidget {
  const PlatformReceiptView({
    super.key,
    required this.state,
    required this.order,
    required this.edit,
  });
  final Json state, order;
  final EditState edit;
  @override
  Widget build(BuildContext context) {
    final job = asMaps(state['printJobs'])
        .where((j) => j['orderId'] == order['id'] && j['batchId'] == 1)
        .firstOrNull;
    final receipt = job?['platformReceipt'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${order['source']} · Orijinal Platform Fişi',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        const Text(
          'Bu sipariş için Nohut tasarımı kullanılmaz. Platform panelindeki hazır sipariş fişini kullanın. Otomatik fiş indirme API’si bağlı değil. Sipariş fişi, mali fatura düzenlendiği anlamına gelmez.',
          style: TextStyle(fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 12),
        if (receipt == null) ...[
          const Expanded(
            child: WorkEmpty(
              title: 'Orijinal platform fişi bekleniyor',
              message:
                  'Platform panelinden fişi doğrudan yazdırabilir veya PDF olarak kaydedip burada ilgili siparişe ekleyebilirsiniz.',
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Platformdan İndirilen Orijinal PDF’yi Ekle'),
            onPressed: () async {
              final input = await askFields(context, 'Orijinal Platform Fişi', [
                ('Platform panelinden indirilen PDF dosya yolu', ''),
                ('Doğrulama: Bu fiş bu siparişe aitse EVET yazın', ''),
              ]);
              if (input == null) return;
              try {
                final file = File(input[0]);
                if (await file.length() > 5 * 1024 * 1024) {
                  throw const FormatException('PDF en fazla 5 MB olabilir.');
                }
                final bytes = await file.readAsBytes();
                // Parse before persistence; no replacement content is generated.
                await Printing.raster(bytes, pages: const [0], dpi: 30).first;
                edit(
                  (s) => attachPlatformReceipt(
                    s,
                    order['id'] as int,
                    bytes,
                    fileName: path.basename(file.path),
                    matchesOrder: input[1].trim().toUpperCase() == 'EVET',
                  ),
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Fiş eklenemedi: $e')));
                }
              }
            },
          ),
        ] else ...[
          Text(
            '${receipt['fileName']} · ${receipt['provenance']}',
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: PdfPreview(
              build: (_) async => originalPlatformReceipt(job!),
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              useActions: false,
            ),
          ),
          const Text(
            'Orijinal PDF değiştirilmez. Tek yazıcıya gönderim: Yazdırma Kuyruğu.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ],
    );
  }
}
