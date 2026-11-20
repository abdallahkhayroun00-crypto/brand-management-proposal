import 'dart:io';

import 'package:flutter/material.dart';

import 'brand.dart';
import 'pos_logic.dart';
import 'order_reporting.dart';
import 'trendyol_go_readonly.dart';

class TgoSettingsPanel extends StatefulWidget {
  const TgoSettingsPanel({super.key, required this.integration});
  final TrendyolGoReadonly integration;
  @override
  State<TgoSettingsPanel> createState() => _TgoSettingsPanelState();
}

class _TgoSettingsPanelState extends State<TgoSettingsPanel> {
  late final TextEditingController supplier, apiKey, apiSecret, email;
  bool visible = false, saving = false, prefilled = false;
  void _hydrateCredentials() {
    if (prefilled || !mounted) return;
    final c = widget.integration.credentials;
    if (c == null) return;
    if (supplier.text.isEmpty) supplier.text = c.supplierId;
    if (email.text.isEmpty) email.text = c.email;
    prefilled = true;
  }

  @override
  void initState() {
    super.initState();
    final c = widget.integration.credentials;
    supplier = TextEditingController(text: c?.supplierId ?? '');
    apiKey = TextEditingController();
    apiSecret = TextEditingController();
    email = TextEditingController(text: c?.email ?? '');
    prefilled = c != null;
    widget.integration.addListener(_hydrateCredentials);
  }

  @override
  void dispose() {
    widget.integration.removeListener(_hydrateCredentials);
    supplier.dispose();
    apiKey.dispose();
    apiSecret.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      final old = widget.integration.credentials;
      await widget.integration.save(
        TgoCredentials(
          supplier.text.trim(),
          apiKey.text.trim().isEmpty ? (old?.apiKey ?? '') : apiKey.text.trim(),
          apiSecret.text.trim().isEmpty
              ? (old?.apiSecret ?? '')
              : apiSecret.text.trim(),
          email.text.trim(),
        ),
      );
      apiKey.clear();
      apiSecret.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API bilgileri güvenle kaydedildi.')),
        );
      }
    } on FormatException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API bilgileri kaydedilemedi.')),
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.integration,
    builder: (context, _) {
      final s = widget.integration;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Uber Eats Trendyol Go',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 7),
              const Text(
                'Salt okunur bağlantı · Siparişler alınır; platformda kabul, iptal, fiyat veya durum değişikliği yapılmaz.',
              ),
              if (!TrendyolGoReadonly.liveSyncEnabled)
                const Text('Ayarları kaydedebilirsiniz. Canlı sipariş eşitlemesi bu sürümde geçici olarak kapalı.'),
              const SizedBox(height: 16),
              TextField(
                controller: supplier,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Satıcı ID (Cari ID)',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
              ),
              const SizedBox(height: 11),
              TextField(
                controller: apiKey,
                obscureText: !visible,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  helperText:
                      'Kayıtlı anahtarı korumak için boş bırakabilirsiniz.',
                ),
              ),
              const SizedBox(height: 11),
              TextField(
                controller: apiSecret,
                obscureText: !visible,
                decoration: const InputDecoration(
                  labelText: 'API Secret',
                  helperText:
                      'Kayıtlı anahtarı korumak için boş bırakabilirsiniz.',
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => visible = !visible),
                  icon: Icon(
                    visible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  label: Text(visible ? 'Gizle' : 'Göster'),
                ),
              ),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Entegrasyon e-posta',
                  helperText:
                      'Zorunlu x-executor-user başlığı için hesabın e-postası.',
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: const Icon(Icons.save),
                    label: const Text('Güvenli Kaydet'),
                  ),
                  OutlinedButton.icon(
                    onPressed: !TrendyolGoReadonly.liveSyncEnabled ||
                            s.syncing || s.credentials?.valid != true
                        ? null
                        : () => s.sync(),
                    icon: const Icon(Icons.sync),
                    label: const Text('Bağlantıyı Test Et / Güncelle'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Bağlantı: ' + s.status,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (s.lastSync.isNotEmpty)
                Text('Son senkronizasyon: ' + s.lastSync),
              if (s.error.isNotEmpty)
                Text(s.error, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              const Text(
                'Gizli anahtarlar Windows DPAPI ile şifrelenir ve güncellemelerden bağımsız olarak AppData klasöründe kalır.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class TgoOrdersPanel extends StatefulWidget {
  const TgoOrdersPanel({
    super.key,
    required this.orders,
    required this.integration,
    required this.businessDay,
    required this.showHistory,
    required this.onPeriodChanged,
    required this.autoKitchen,
    required this.onAutoKitchenChanged,
    required this.onKitchenPrint,
  });

  final List<Json> orders;
  final TrendyolGoReadonly integration;
  final String businessDay;
  final bool showHistory;
  final VoidCallback onPeriodChanged;
  final bool autoKitchen;
  final ValueChanged<bool> onAutoKitchenChanged;
  final ValueChanged<Json> onKitchenPrint;

  @override
  State<TgoOrdersPanel> createState() => _TgoOrdersPanelState();
}

class _TgoOrdersPanelState extends State<TgoOrdersPanel> {
  String query = '';
  String? dayFilter;
  String status = '';

  Future<void> _pickDate() async {
    final yesterday = DateTime.parse(widget.businessDay)
        .subtract(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: yesterday,
      initialDate: dayFilter == null ? yesterday : DateTime.parse(dayFilter!),
    );
    if (date != null && mounted) {
      setState(() => dayFilter = date.toIso8601String().substring(0, 10));
    }
  }

  @override
  Widget build(BuildContext context) {
    final TgoOrdersPanel(
      :orders, :integration, :businessDay, :showHistory, :onPeriodChanged,
    ) = widget;
    final theme = Theme.of(context);
    final datedOrders = <(DateTime, Json)>[];
    for (final order in orders) {
      final createdAt = DateTime.tryParse('${order['createdAt'] ?? ''}');
      if (createdAt == null) continue;
      final day = istanbulDay(createdAt);
      if (showHistory) {
        if (dayFilter != null && day != dayFilter) continue;
        if (status.isNotEmpty && order['status'] != status) continue;
        if (query.isNotEmpty &&
            ![order['orderNumber'], order['orderCode'], displayOrderNumber(order)]
                .any((value) => '${value ?? ''}'.toLowerCase().contains(query))) {
          continue;
        }
      }
      if (showHistory ? day.compareTo(businessDay) < 0 : day == businessDay) {
        datedOrders.add((createdAt, order));
      }
    }
    datedOrders.sort((a, b) {
      final byDate = b.$1.compareTo(a.$1);
      if (byDate != 0) return byDate;
      return (b.$2['dailyNumber'] as int? ?? 0)
          .compareTo(a.$2['dailyNumber'] as int? ?? 0);
    });
    final connected = integration.status.startsWith('Bağlı ·');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: NohutBrand.green,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.delivery_dining_outlined, color: NohutBrand.cream),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trendyol Go', style: theme.textTheme.titleLarge?.copyWith(
                      color: NohutBrand.cream,
                    )),
                    Text(
                      connected ? 'Bağlı · Salt okunur' : integration.status,
                      style: const TextStyle(color: NohutBrand.cream),
                    ),
                    if (integration.error.isNotEmpty)
                      Text(integration.error,
                          style: const TextStyle(color: NohutBrand.cream)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Siparişleri yenile',
                style: IconButton.styleFrom(
                  foregroundColor: NohutBrand.cream,
                  disabledForegroundColor: NohutBrand.cream.withAlpha(140),
                ),
                onPressed: integration.syncing ||
                    !TrendyolGoReadonly.liveSyncEnabled ||
                    integration.credentials?.valid != true
                    ? null
                    : integration.sync,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        if (integration.syncing) const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                showHistory ? 'Geçmiş Siparişler' : 'Bugünün Siparişleri',
                style: theme.textTheme.titleMedium,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => query = '');
                onPeriodChanged();
              },
              icon: Icon(showHistory ? Icons.today_outlined : Icons.history),
              label: Text(showHistory ? 'Bugüne Dön' : 'Geçmiş'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (showHistory)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 230,
                child: TextField(
                  onChanged: (value) =>
                      setState(() => query = value.trim().toLowerCase()),
                  decoration: const InputDecoration(labelText: 'Sipariş No / Kod'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(dayFilter ?? 'Tarih Seç'),
              ),
              if (dayFilter != null)
                TextButton(
                  onPressed: () => setState(() => dayFilter = null),
                  child: const Text('Tarihi Temizle'),
                ),
              DropdownButton<String>(
                value: status,
                items: [
                  const DropdownMenuItem(value: '', child: Text('Tüm Durumlar')),
                  for (final (value, label) in const [
                    ('Created', 'Yeni'),
                    ('Picking', 'Hazırlanıyor'),
                    ('Invoiced', 'Hazırlandı'),
                    ('Shipped', 'Yolda'),
                    ('Delivered', 'Teslim Edildi'),
                    ('Cancelled', 'İptal'),
                    ('UnSupplied', 'Karşılanamadı'),
                  ])
                    DropdownMenuItem(value: value, child: Text(label)),
                ],
                onChanged: (value) => setState(() => status = value ?? ''),
              ),
            ],
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: const Text('Otomatik Mutfak Fişi'),
              selected: widget.autoKitchen,
              onSelected: widget.onAutoKitchenChanged,
            ),
          ),
        const SizedBox(height: 8),
        if (datedOrders.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                showHistory
                    ? 'Kayıtlı geçmiş sipariş bulunamadı.'
                    : connected
                        ? 'Bugün için sipariş yok.'
                        : 'Bağlantıyı Ayarlar → Trendyol Go bölümünden kontrol edin.',
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 820
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final (_, order) in datedOrders)
                    SizedBox(
                      width: width,
                      child: _TgoOrderCard(
                        order: order,
                        onKitchenPrint: showHistory
                            ? null
                            : () => widget.onKitchenPrint(order),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _TgoOrderCard extends StatelessWidget {
  const _TgoOrderCard({required this.order, this.onKitchenPrint});
  final Json order;
  final VoidCallback? onKitchenPrint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = '${order['status'] ?? ''}';
    final (statusLabel, statusColor, statusBg) = switch (status) {
      'Created' => ('Yeni', const Color(0xff325577), const Color(0xffe9f0f5)),
      'Picking' => ('Hazırlanıyor', const Color(0xff765720), const Color(0xfff7ecd4)),
      'Invoiced' => ('Hazırlandı', NohutBrand.green, const Color(0xffe5ebdf)),
      'Shipped' => ('Yolda', const Color(0xff325577), const Color(0xffe9f0f5)),
      'Delivered' => ('Teslim Edildi', NohutBrand.green, const Color(0xffe5ebdf)),
      'Cancelled' => ('İptal', const Color(0xff8d3930), const Color(0xfff6e6e3)),
      'UnSupplied' => ('Karşılanamadı', const Color(0xff8d3930), const Color(0xfff6e6e3)),
      _ => (status.isEmpty ? 'Durum bilinmiyor' : status, NohutBrand.muted,
          const Color(0xffeeeeea)),
    };
    final payment = '${order['paymentType'] ?? ''}';
    final paymentLabel = switch (payment) {
      'PAY_WITH_CARD' => 'Kart',
      'PAY_WITH_CASH' => 'Nakit',
      _ => payment.replaceAll('_', ' '),
    };
    final note = '${order['customerNote'] ?? ''}'.trim();
    final reason = '${order['cancelReason'] ?? ''}'.trim();
    final eta = {
      for (final key in ['courierEtaFrom', 'courierEtaTo'])
        if (order[key] is String) istanbulStamp(order[key]).split(' ').last,
    }.join('–');
    final printState = order['kitchenPrintState'] as String?;
    final showCourier = order['pickup'] != true &&
        const ['Created', 'Picking', 'Invoiced'].contains(status);
    final lines = asMaps(order['lines']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text('#${displayOrderNumber(order)}',
                    style: theme.textTheme.titleLarge),
                ),
                const SizedBox(width: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: statusBg, borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text(statusLabel, style: TextStyle(
                      color: statusColor, fontWeight: FontWeight.w700,
                    )),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text('Platform no: ${order['orderNumber']}'),
                Text(istanbulStamp(order['createdAt'])),
                Text(order['pickup'] == true ? 'Gel-Al' : 'Paket Servis'),
                if ('${order['orderCode'] ?? ''}'.isNotEmpty)
                  Text("Sipariş kodu: ${order['orderCode']}"),
                if (order['testPackage'] == true) const Text('Test siparişi'),
              ],
            ),
            const Divider(height: 20),
            if (showCourier && order['courierNearby'] == true)
              const Text('Kurye yakında'),
            if (showCourier && eta.isNotEmpty) Text('Tahmini kurye varışı: $eta'),
            if (reason.isNotEmpty) Text('İptal nedeni: $reason'),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 34, child: Text('${line['qty']}×',
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${line['name']}'),
                          if (line['options'] case final List options when options.isNotEmpty)
                            Text(options.join(', '), style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text('Müşteri notu: $note', style: theme.textTheme.bodySmall),
              ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(child: Text(paymentLabel.isEmpty ? 'Platform toplamı' : paymentLabel)),
                Text(formatTry(order['totalCents'] as int? ?? 0),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            if (onKitchenPrint != null && tgoKitchenActive(order))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _openExternalPage(
                    context,
                    'https://partner.tgoyemek.com/',
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(switch (status) {
                    'Created' => 'Kabul Et · GO Yemek Paneli',
                    'Picking' => 'Hazır · GO Yemek Paneli',
                    _ => 'GO Yemek Panelini Aç',
                  }),
                ),
              ),
            if (printState != null)
              Text('Mutfak fişi · $printState', style: theme.textTheme.bodySmall)
            else if (onKitchenPrint != null && tgoKitchenActive(order))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onKitchenPrint,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Mutfak Fişi Yazdır'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MigrosOrdersPanel extends StatelessWidget {
  const MigrosOrdersPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Migros Yemek · Bağlı değil',
              style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Nohut POS için Migros Yemek entegrasyon erişimi gerekli.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openExternalPage(
                context,
                'https://restoran.migrosonline.com/login',
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Migros Restoran Panelini Aç'),
            ),
          ],
        ),
      ),
    );
  }
}

class FeedbackPanel extends StatefulWidget {
  const FeedbackPanel({
    super.key,
    required this.integration,
    required this.orders,
  });

  final TrendyolGoReadonly integration;
  final List<Json> orders;

  @override
  State<FeedbackPanel> createState() => _FeedbackPanelState();
}

enum _FeedbackSource { trendyol, google, yemeksepeti }

class _FeedbackPanelState extends State<FeedbackPanel> {
  _FeedbackSource source = _FeedbackSource.trendyol;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final (value, label) in const [
              (_FeedbackSource.trendyol, 'Trendyol Go'),
              (_FeedbackSource.google, 'Google Maps'),
              (_FeedbackSource.yemeksepeti, 'Yemeksepeti'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: source == value,
                onSelected: (_) => setState(() => source = value),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Offstage(
          offstage: source != _FeedbackSource.trendyol,
          child: TgoReviewsPanel(
            orders: widget.orders,
            integration: widget.integration,
          ),
        ),
        if (source == _FeedbackSource.google)
          const _ExternalReviewsCard(
            icon: Icons.place_outlined,
            title: 'Google Maps',
            description: 'Nohut Falafel yorumlarını Google Maps’te okuyun.',
            action: 'Google Maps’te Aç',
            url: 'https://www.google.com/maps/place/Nohut+Falafel/@40.7650391,30.3602224,17z/data=!4m8!3m7!1s0x14ccb3cd4595bcab:0xd28ffffa342dbede!8m2!3d40.7650391!4d30.3602224!9m1!1b1!16s%2Fg%2F11wjq__p26?hl=tr',
          ),
        if (source == _FeedbackSource.yemeksepeti)
          const _ExternalReviewsCard(
            icon: Icons.restaurant_outlined,
            title: 'Yemeksepeti',
            description: 'Yorumları görmek için restoran hesabınızla Partner Paneli’ne giriş yapın.',
            action: 'Partner Panelini Aç',
            url: 'https://partner-app.yemeksepeti.com/',
          ),
      ],
    );
  }
}

Future<void> _openExternalPage(BuildContext context, String url) async {
  try {
    final ProcessResult result;
    if (Platform.isWindows) {
      result = await Process.run('rundll32.exe', [
        'url.dll,FileProtocolHandler',
        url,
      ]);
    } else {
      result = await Process.run(
        Platform.isMacOS ? 'open' : 'xdg-open',
        [url],
      );
    }
    if (result.exitCode == 0) return;
  } on ProcessException {
    // Offer the address for manual opening if the browser cannot be launched.
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: SelectableText('Tarayıcı açılamadı. $url')),
  );
}

class _ExternalReviewsCard extends StatelessWidget {
  const _ExternalReviewsCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    required this.url,
  });

  final IconData icon;
  final String title, description, action, url;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: NohutBrand.green),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openExternalPage(context, url),
              icon: const Icon(Icons.open_in_new),
              label: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}

class TgoReviewsPanel extends StatefulWidget {
  const TgoReviewsPanel({
    super.key, required this.integration, required this.orders,
  });

  final TrendyolGoReadonly integration;
  final List<Json> orders;

  @override
  State<TgoReviewsPanel> createState() => _TgoReviewsPanelState();
}

class _TgoReviewsPanelState extends State<TgoReviewsPanel> {
  final storeId = TextEditingController();
  List<Json> reviews = [];
  String error = '';
  int page = 0;
  bool loading = false, loaded = false, hasNextPage = false;

  @override
  void initState() {
    super.initState();
    final stores = widget.orders
        .where((order) => order['supplierId'] == widget.integration.credentials?.supplierId)
        .map((order) => '${order['storeId'] ?? ''}')
        .where((id) => id.isNotEmpty)
        .toSet();
    if (stores.length == 1) storeId.text = stores.single;
  }

  @override
  void dispose() {
    storeId.dispose();
    super.dispose();
  }

  Future<void> loadPage(int index) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final result = await widget.integration.readReviews(storeId.text.trim(), index);
      if (!mounted) return;
      setState(() {
        reviews = result.reviews;
        hasNextPage = result.hasNextPage;
        page = index;
        loaded = true;
      });
    } on FormatException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Yorumlar alınamadı. Bağlantıyı kontrol edin.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_outline, color: NohutBrand.green),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Trendyol Go',
                      style: Theme.of(context).textTheme.titleLarge)),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 210,
                    child: TextField(
                      controller: storeId,
                      enabled: !loading,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Şube ID (Store ID)'),
                      onChanged: (_) => setState(() {
                        reviews = [];
                        loaded = false;
                        error = '';
                      }),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: loading ? null : () => loadPage(0),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Değerlendirmeleri Getir'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
        if (loading) const LinearProgressIndicator(),
        if (error.isNotEmpty)
          Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        if (loaded && reviews.isEmpty && error.isEmpty)
          const Text('Bu sayfada değerlendirme yok.'),
        for (final review in reviews)
          _reviewTile(review),
        if (loaded && (page > 0 || hasNextPage))
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: loading || page == 0 ? null : () => loadPage(page - 1),
                child: const Text('Önceki'),
              ),
              TextButton(
                onPressed: loading || !hasNextPage ? null : () => loadPage(page + 1),
                child: const Text('Sonraki'),
              ),
            ],
          ),
    ],
  );

  Widget _reviewTile(Json review) {
    final rating = review['rating'];
    final comment = review['comment'];
    final score = rating is Map ? rating['average'] : null;
    final message = comment is Map ? comment['text'] : null;
    final timestamp = review['createdDate'];
    final date = timestamp is num && timestamp >= 0 && timestamp <= 8640000000000000
        ? DateTime.fromMillisecondsSinceEpoch(timestamp.toInt(), isUtc: true)
            .add(const Duration(hours: 3)).toIso8601String().split('T').first
        : null;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.star, color: NohutBrand.gold),
        title: Text('${score is num ? score : '—'} / 5'),
        subtitle: message is String && message.trim().isNotEmpty ? Text(message) : null,
        trailing: date == null ? null : Text(date),
      ),
    );
  }

}
