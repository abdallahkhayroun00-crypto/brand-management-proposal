import 'package:flutter/material.dart';
import 'pos_logic.dart';
import 'operations.dart';
import 'operations_ui.dart';
import 'ticket_document.dart';
import 'ticket_paper.dart';
import 'ticket_actions.dart';
import 'print_service.dart';
import 'platform_receipt_ui.dart';
import 'platform_receipt.dart';

class PrinterWorkspace extends StatefulWidget {
  const PrinterWorkspace({
    super.key,
    required this.state,
    required this.edit,
    this.service,
  });
  final Json state;
  final EditState edit;
  final PrintService? service;
  @override
  State<PrinterWorkspace> createState() => _PrinterWorkspaceState();
}

class _PrinterWorkspaceState extends State<PrinterWorkspace> {
  String filter = 'Bekleyen', search = '';
  String? selected;
  bool sending = false;
  String keyOf(Json j) => '${j['orderId']}:${j['batchId']}';
  bool completed(Json j) => printCompleted(j);
  void simulate(Json selected, bool success) => widget.edit((s) {
    final j = (s['printJobs'] as List).cast<Map>().firstWhere(
      (j) => '${j['orderId']}:${j['batchId']}' == keyOf(selected),
    );
    if (printCompleted(j.cast<String, dynamic>()) ||
        printUncertain(j.cast<String, dynamic>())) {
      throw const FormatException('Tamamlanmış iş tekrar gönderilmez');
    }
    final order = mutableOrder(s, j['orderId'] as int);
    if (order != null && isPlatform(order)) {
      originalPlatformReceipt(j.cast<String, dynamic>());
    }
    j['state'] = success ? 'Simüle edildi' : 'Hata';
    j['attempts'] = (j['attempts'] as int? ?? 0) + 1;
    j['error'] = success ? '' : 'DEMO · Yazıcı erişilemiyor';
  });
  @override
  Widget build(BuildContext context) {
    final jobs = asMaps(widget.state['printJobs']).reversed.toList();
    final rows = jobs
        .where(
          (j) =>
              (filter == 'Tümü' ||
                  filter == 'Bekleyen' &&
                      !completed(j) &&
                      !printUncertain(j) &&
                      j['state'] != 'Hata' ||
                  filter == 'Hata' && j['state'] == 'Hata' ||
                  filter == 'Doğrula' && printUncertain(j) ||
                  filter == 'Tamamlanan' && completed(j)) &&
              '${j['orderId']} ${j['batchId']}'.contains(search),
        )
        .toList();
    final job =
        rows.where((j) => keyOf(j) == selected).firstOrNull ?? rows.firstOrNull;
    TicketDocument? document;
    final order = job == null
        ? null
        : mutableOrder(widget.state, job['orderId'] as int);
    final platform = order != null && isPlatform(order);
    String preview = 'Önizlemek için soldan bir mutfak işi seçin.';
    if (job != null) {
      try {
        preview = receiptText(widget.state, job);
        if (!platform) document = kitchenTicket(widget.state, job);
      } catch (_) {
        preview = 'Sipariş bilgisi bulunamadı.';
      }
    }
    final list = Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Sipariş / parti ara',
              ),
              onChanged: (v) => setState(() => search = v),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.print_outlined,
                          size: 40,
                          color: Color(0xff9aaf9f),
                        ),
                        SizedBox(height: 12),
                        Text('Bu görünümde iş yok.'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final j = rows[i],
                          order = mutableOrder(
                            widget.state,
                            j['orderId'] as int,
                          );
                      return ListTile(
                        key: ValueKey('print-job-${keyOf(j)}'),
                        selected: job != null && keyOf(j) == keyOf(job),
                        selectedTileColor: const Color(0xffedf5e9),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xfff1f5ed),
                          child: Icon(
                            j['state'] == 'Hata'
                                ? Icons.error_outline
                                : completed(j)
                                ? Icons.check_rounded
                                : Icons.print_outlined,
                            color: j['state'] == 'Hata'
                                ? Colors.deepOrange
                                : const Color(0xff527752),
                          ),
                        ),
                        title: Text(
                          '#${j['orderId']} · ${order?['source'] ?? 'Sipariş'}${order?['table'] == null ? '' : ' ${order!['table']}'}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text('Parti ${j['batchId']} · ${j['state']}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => setState(() => selected = keyOf(j)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
    final paper = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Mutfak Fişi Önizleme',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                const Icon(Icons.receipt_long_outlined),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              job == null
                  ? 'Tek yazıcı'
                  : "#${job['orderId']} · Parti ${job['batchId']} · Deneme ${job['attempts'] ?? 0}",
              style: const TextStyle(color: Color(0xff7c8b80), fontSize: 12),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xfffffcf4),
                  border: Border.all(color: const Color(0xffe8e0cf)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: platform
                    ? PlatformReceiptView(
                        state: widget.state,
                        order: order,
                        edit: widget.edit,
                      )
                    : SingleChildScrollView(
                        child: document != null
                            ? TicketPaper(document: document)
                            : SelectableText(
                                preview,
                                style: const TextStyle(
                                  fontFamily: 'Consolas',
                                  height: 1.65,
                                  fontSize: 13,
                                ),
                              ),
                      ),
              ),
            ),
            if (job != null && '${job['error'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '${job['error']}',
                  style: const TextStyle(
                    color: Colors.deepOrange,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (document != null || platform && job?['platformReceipt'] != null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (document != null)
                    OutlinedButton.icon(
                      onPressed: () => saveTicketPdf(context, document!),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('80 mm PDF Kaydet'),
                    ),
                  if (widget.state['settings']?['printerMode'] == 'windows')
                    FilledButton.icon(
                      onPressed:
                          sending ||
                              widget.service == null ||
                              job == null ||
                              completed(job) ||
                              printUncertain(job)
                          ? null
                          : () async {
                              setState(() => sending = true);
                              try {
                                final result = await widget.service!.print(
                                  keyOf(job),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(result)),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(SnackBar(content: Text('$e')));
                                }
                              } finally {
                                if (mounted) setState(() => sending = false);
                              }
                            },
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: Text(
                        sending ? 'Gönderiliyor…' : 'Seçili Yazıcıya Gönder',
                      ),
                    ),
                ],
              ),
            if (job != null && printUncertain(job) && widget.service != null)
              Wrap(
                spacing: 6,
                children: [
                  for (final exists in [true, false])
                    TextButton(
                      onPressed: sending
                          ? null
                          : () async {
                              final v = await askFields(
                                context,
                                exists
                                    ? 'Çıktı / Windows Kuyruğu Doğrulandı'
                                    : 'Çıktı Oluşmadığı Doğrulandı',
                                [
                                  (
                                    'Fiziksel çıktı ve Windows kuyruğu kontrol notu',
                                    '',
                                  ),
                                ],
                              );
                              if (v != null) {
                                try {
                                  widget.service!.reconcile(
                                    keyOf(job),
                                    outputExists: exists,
                                    reason: v[0],
                                  );
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('$e')),
                                    );
                                  }
                                }
                              }
                            },
                      child: Text(
                        exists
                            ? 'Çıktı Var · Tamamla'
                            : 'Çıktı Yok · Kuyruğa Al',
                      ),
                    ),
                ],
              ),
            if (job != null &&
                (!platform || job['platformReceipt'] != null) &&
                !completed(job) &&
                !printUncertain(job) &&
                widget.state['settings']?['printerMode'] != 'windows')
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Demo Test Araçları',
                  style: TextStyle(fontSize: 12),
                ),
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: () => simulate(job, true),
                        child: Text(
                          job['state'] == 'Hata'
                              ? 'Tekrar Dene · Demo'
                              : 'Başarı Simülasyonu',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => simulate(job, false),
                        child: const Text('Hata Simülasyonu'),
                      ),
                    ],
                  ),
                ],
              ),
            Text(
              widget.state['settings']?['printerMode'] == 'windows'
                  ? 'Tek Windows / USB yazıcısı seçili. Sürücüde 80 mm kâğıdı ayarlayın. Kuyruk kabulü fiziksel baskı doğrulaması değildir. Mali fiş / fatura oluşturulmaz.'
                  : 'Fiziksel yazıcı seçili değil. PDF ve simülasyon kullanılabilir; mali fiş veya fatura oluşturulmaz.',
              style: const TextStyle(fontSize: 11, color: Color(0xff7c8b80)),
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Yazdırma Kuyruğu',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tek mutfak yazıcısı · Kuyruktan işi seç, fişi ve sonucunu birlikte gör.',
          style: TextStyle(color: Color(0xff7c8b80)),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            for (final tab in [
              'Bekleyen',
              'Hata',
              'Doğrula',
              'Tamamlanan',
              'Tümü',
            ])
              ChoiceChip(
                label: Text(
                  '$tab · ${jobs.where((j) => tab == 'Tümü' || tab == 'Bekleyen' && !completed(j) && j['state'] != 'Hata' && !printUncertain(j) || tab == 'Hata' && j['state'] == 'Hata' || tab == 'Doğrula' && printUncertain(j) || tab == 'Tamamlanan' && completed(j)).length}',
                ),
                selected: filter == tab,
                onSelected: (_) => setState(() => filter = tab),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: c.maxWidth < 1050 ? 300 : 390, child: list),
                const SizedBox(width: 18),
                Expanded(child: paper),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
