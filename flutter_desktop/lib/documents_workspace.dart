import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pos_logic.dart';
import 'operations.dart';
import 'operations_ui.dart';
import 'platform_runtime.dart';
import 'invoice_documents.dart';
import 'ticket_document.dart';
import 'ticket_paper.dart';
import 'ticket_actions.dart';
import 'workspace_ui.dart';
import 'platform_receipt_ui.dart';

class DocumentsWorkspace extends StatefulWidget {
  const DocumentsWorkspace({
    super.key,
    required this.state,
    required this.edit,
    required this.runtime,
    required this.onOrder,
    required this.onPrinter,
  });
  final Json state;
  final EditState edit;
  final PlatformRuntime runtime;
  final ValueChanged<int> onOrder;
  final VoidCallback onPrinter;
  @override
  State<DocumentsWorkspace> createState() => _DocumentsWorkspaceState();
}

class _DocumentsWorkspaceState extends State<DocumentsWorkspace> {
  int? selected;
  String tab = 'Hesap Özeti', source = 'Tümü', search = '';
  Future<void> register(Json order) async {
    final fields = [
      'Belge no (sağlayıcının verdiği)',
      'ETTN (sağlayıcının verdiği)',
      'Sağlayıcı / düzenleyen sistem',
      'Düzenleme tarihi YYYY-MM-DD',
      'Belge tutarı ₺',
      'Kalıcı HTTPS belge bağlantısı (isteğe bağlı)',
    ];
    final controllers = [
      for (var i = 0; i < fields.length; i++)
        TextEditingController(
          text: i == 3
              ? DateTime.now().toUtc().toIso8601String().substring(0, 10)
              : i == 4
              ? (orderTotalCents(order) / 100).toStringAsFixed(2)
              : '',
        ),
    ];
    var confirmed = false, error = '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: const Text('Harici Düzenlenmiş Fatura Kaydı'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Bu ekran fatura kesmez. Yetkili sağlayıcı / GİB üzerinden önceden düzenlenmiş belgenin siparişle eşlemesini kaydeder.',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < fields.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: TextField(
                        controller: controllers[i],
                        decoration: InputDecoration(labelText: fields[i]),
                      ),
                    ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: confirmed,
                    onChanged: (v) => refresh(() => confirmed = v!),
                    title: const Text(
                      'Bu belge harici sistemde gerçekten düzenlendi; bilgileri belgeden girdim.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  if (error.isNotEmpty)
                    Text(
                      error,
                      style: const TextStyle(
                        color: Colors.deepOrange,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: !confirmed
                  ? null
                  : () {
                      try {
                        if (widget.edit(
                          (s) => registerInvoice(
                            s,
                            order['id'] as int,
                            number: controllers[0].text,
                            ettn: controllers[1].text,
                            provider: controllers[2].text,
                            issuedAt: controllers[3].text,
                            amountCents: parseMoney(controllers[4].text),
                            url: controllers[5].text,
                            externallyIssued: confirmed,
                          ),
                        )) {
                          Navigator.pop(ctx);
                        } else {
                          refresh(
                            () => error =
                                'Belge kaydedilemedi. Bilgileri ve sipariş tutarını kontrol edin.',
                          );
                        }
                      } catch (e) {
                        refresh(() => error = '$e');
                      }
                    },
              child: const Text('Mevcut Belgeyi Kaydet'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final c in controllers) {
      c.dispose();
    }
  }

  Future<void> queue(Json document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trendyol Go · Fatura Bağlantısını Gönder'),
        content: const Text(
          'Yalnızca harici sistemde düzenlenmiş belgenin bağlantısı gönderilir. Bağlantı en az 10 yıl erişilebilir tutulmalıdır. Bu işlem fatura oluşturmaz.\n\nKalıcı erişimi ve doğru sipariş / belge eşleşmesini doğruladınız mı?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Doğruladım · Kuyruğa Al'),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        widget.edit(
          (s) => queueInvoiceLink(
            s,
            '${document['id']}',
            retentionConfirmed: true,
          ),
        )) {
      unawaited(widget.runtime.runOnce());
    }
  }

  Widget salesDocuments(Json order) {
    final documents = invoiceDocuments(
      widget.state,
    ).where((d) => d['orderId'] == order['id']).toList();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WorkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'e-Fatura / e-Arşiv sağlayıcısı bağlı değil',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 8),
                Text(
                  'Hazırlık fişi ve hesap özeti mali fatura değildir. Yasal belge numarası, ETTN, KDV veya imza bu uygulama tarafından uydurulmaz. Platform komisyon / teslimat belgeleri restoran satış belgesinden ayrıdır.',
                  style: TextStyle(fontSize: 12, height: 1.6, color: muted),
                ),
                SizedBox(height: 12),
                FilledButton(
                  onPressed: null,
                  child: Text('Mali Fatura Kes · Sağlayıcı Gerekli'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (documents.isEmpty)
            WorkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Bu siparişe eşlenmiş harici belge yok.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: order['cancelled'] == true
                          ? null
                          : () => register(order),
                      icon: const Icon(Icons.add_link, size: 18),
                      label: const Text('Harici Düzenlenmiş Belgeyi Kaydet'),
                    ),
                  ),
                ],
              ),
            ),
          for (final d in documents)
            WorkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${d['number']}',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${d['status']}\nSağlayıcı: ${d['provider']}\nETTN: ${d['ettn']}\nDüzenleme: ${istanbulTime(d['issuedAt'], dateOnly: true)}\nTutar: ${formatTry(d['amountCents'] as int)}',
                    style: const TextStyle(fontSize: 12, height: 1.8),
                  ),
                  if (d['amountCents'] != orderTotalCents(order) ||
                      d['orderFingerprint'] != invoiceOrderFingerprint(order))
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'Sipariş değişti. Harici belge ve tutarı sağlayıcı üzerinden doğrulayın.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ),
                  if ('${d['url']}'.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SelectableText(
                      '${d['url']}',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: '${d['url']}'),
                        ),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Bağlantıyı Kopyala'),
                      ),
                    ),
                  ],
                  const Divider(height: 24),
                  if (order['source'] == 'Trendyol Go')
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed:
                            (![
                                  'stage',
                                  'live',
                                ].contains(order['integrationMode']) ||
                                invoiceJobs(
                                  widget.state,
                                ).any((j) => j['documentId'] == d['id']))
                            ? null
                            : () => queue(d),
                        icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                        label: Text(
                          order['integrationMode'] == 'live'
                              ? 'CANLI · Fatura Bağlantısını Gönder'
                              : order['integrationMode'] == 'stage'
                              ? 'STAGE · Fatura Bağlantısını Gönder'
                              : 'DEMO · Canlı Gönderim Kapalı',
                        ),
                      ),
                    ),
                  if (order['source'] == 'Yemeksepeti')
                    const Text(
                      'Yemeksepeti belge yükleme API yetkisi / sözleşmesi doğrulanmadı. Gerekli yüklemeyi resmi partner panelinden yapın. Bu uygulama yüklenmiş gibi işaretlemez.',
                      style: TextStyle(fontSize: 12, color: muted, height: 1.6),
                    ),
                  for (final j in invoiceJobs(
                    widget.state,
                  ).where((j) => j['documentId'] == d['id']))
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Platform Senkronizasyonu: ${j['status']}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Deneme: ${j['attempts']} · Kasa (PC)\n${j['error'] ?? ''}',
                            style: const TextStyle(fontSize: 12, color: muted),
                          ),
                          if (j['status'] == 'Hata')
                            OutlinedButton(
                              onPressed: () {
                                if (widget.edit(
                                  (s) => retryInvoiceLink(s, '${j['id']}'),
                                )) {
                                  unawaited(widget.runtime.runOnce());
                                }
                              },
                              child: const Text('Güvenli Yeniden Dene'),
                            ),
                          if (j['status'] == 'Belirsiz')
                            Wrap(
                              spacing: 6,
                              children: [
                                for (final delivered in [true, false])
                                  TextButton(
                                    onPressed: () async {
                                      final fields = await askFields(
                                        context,
                                        'Platform Belge Kaydı Doğrulaması',
                                        [
                                          (
                                            'Partner paneli kontrolü / destek referansı',
                                            '',
                                          ),
                                        ],
                                      );
                                      if (fields != null) {
                                        widget.edit(
                                          (s) => reconcileInvoiceLink(
                                            s,
                                            '${j['id']}',
                                            delivered: delivered,
                                            reason: fields[0],
                                          ),
                                        );
                                      }
                                    },
                                    child: Text(
                                      delivered
                                          ? 'Yüklendiğini Doğruladım'
                                          : 'Platformta Yok · Doğruladım',
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = asMaps(widget.state['orders']).reversed
        .where(
          (o) =>
              (source == 'Tümü' || o['source'] == source) &&
              '${o['id']} ${o['source']} ${o['table'] ?? ''}'
                  .toLowerCase()
                  .contains(search.toLowerCase()),
        )
        .toList();
    final order =
        orders.where((o) => o['id'] == selected).firstOrNull ??
        orders.firstOrNull;
    final document = order == null ? null : billDocument(order);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        workHeading(
          'Fiş & Fatura',
          'Hazırlık fişi, hesap özeti ve harici mali belge kaydı ayrı işlemlerdir.',
          action: OutlinedButton.icon(
            onPressed: widget.onPrinter,
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Mutfak Fişleri / Yazdırma'),
          ),
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final value in [
              'Tümü',
              'Masa',
              'Gel-Al',
              'Trendyol Go',
              'Yemeksepeti',
            ])
              ChoiceChip(
                label: Text(value),
                selected: source == value,
                onSelected: (_) => setState(() {
                  source = value;
                  selected = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 260,
                child: WorkCard(
                  padding: 10,
                  child: Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Sipariş / masa ara',
                        ),
                        onChanged: (v) => setState(() {
                          search = v;
                          selected = null;
                        }),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView(
                          children: [
                            for (final o in orders)
                              ListTile(
                                key: ValueKey('document-order-${o['id']}'),
                                selected: o['id'] == order?['id'],
                                selectedTileColor: const Color(0xffedf3e8),
                                title: Text(
                                  '#${o['id']} · ${o['source']}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  '${o['table'] == null ? '' : 'Masa ${o['table']} · '}${formatTry(orderTotalCents(o))}',
                                ),
                                onTap: () =>
                                    setState(() => selected = o['id'] as int),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: order == null
                    ? const WorkCard(
                        child: WorkEmpty(
                          title: 'Sipariş seçin',
                          message:
                              'Fişler ve belge kayıtları siparişe göre açılır.',
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: WorkTabs(
                                  values: const [
                                    'Hesap Özeti',
                                    'Satış Belgeleri',
                                  ],
                                  selected: tab,
                                  onChanged: (v) => setState(() => tab = v),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Siparişi Aç',
                                onPressed: () =>
                                    widget.onOrder(order['id'] as int),
                                icon: const Icon(Icons.open_in_new),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: tab == 'Hesap Özeti'
                                ? isPlatform(order)
                                      ? WorkCard(
                                          child: PlatformReceiptView(
                                            state: widget.state,
                                            order: order,
                                            edit: widget.edit,
                                          ),
                                        )
                                      : WorkCard(
                                          child: Column(
                                            children: [
                                              Expanded(
                                                child: SingleChildScrollView(
                                                  child: TicketPaper(
                                                    document: document!,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              OutlinedButton.icon(
                                                onPressed: () => saveTicketPdf(
                                                  context,
                                                  document,
                                                ),
                                                icon: const Icon(
                                                  Icons.picture_as_pdf_outlined,
                                                  size: 18,
                                                ),
                                                label: const Text(
                                                  'Hesap Özeti · 58 mm PDF Kaydet',
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                : salesDocuments(order),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
