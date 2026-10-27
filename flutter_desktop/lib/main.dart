import 'order_reporting.dart';

import 'dart:async';

import 'receipt_printer.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'floor_plan.dart';
import 'lan_server.dart';
import 'pos_logic.dart';
import 'pos_store.dart';
import 'operations.dart';
import 'operations_ui.dart';
import 'platform_workflows.dart';
import 'platform_ui.dart';

const dark = Color(0xff193f2c);
const cream = Color(0xfff5f7f1);
const emerald = Color(0xff3b7550);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NohutFalafelApp());
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    this.price,
  });
  final int id;
  final String name;
  final String category;
  final double? price;
}

class OrderRequest {
  const OrderRequest({
    required this.source,
    required this.table,
    required this.pickupChannel,
    required this.lines,
    this.customer = const {},
  });
  final String source;
  final int? table;
  final String pickupChannel;
  final List<Json> lines;
  final Json customer;
}

class NohutFalafelApp extends StatelessWidget {
  const NohutFalafelApp({
    super.key,
    this.databaseFile,
    this.startServer = true,
  });
  final String? databaseFile;
  final bool startServer;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Nohut Falafel · Yönetici Paneli',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: dark, surface: cream),
      scaffoldBackgroundColor: cream,
      fontFamily: 'Segoe UI',
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: const BorderSide(color: Color(0xffe1e8df)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    ),
    home: ManagerDesktop(databaseFile: databaseFile, startServer: startServer),
  );
}

class ManagerDesktop extends StatefulWidget {
  const ManagerDesktop({super.key, this.databaseFile, this.startServer = true});
  final String? databaseFile;
  final bool startServer;
  @override
  State<ManagerDesktop> createState() => _ManagerDesktopState();
}

class _ManagerDesktopState extends State<ManagerDesktop> {
  late final PosStore store;
  late final ReceiptPrinter receiptPrinter;
  late final PosLanServer lan;
  List<Product> menu = const [];
  String page = 'dashboard';
  int? selectedTable, selectedOrder;
  bool floorEditing = false;
  Map<int, Rect> draftFloor = {...floorDefaults};
  String orderFilter = 'Tümü';
  String orderSearch = '',
      orderStatus = '',
      orderStaff = '',
      orderFrom = '',
      orderTo = '';

  static const sections = [
    ('dashboard', Icons.dashboard_outlined, 'Genel Bakış'),
    ('tables', Icons.table_restaurant_outlined, 'Masalar'),
    ('orders', Icons.receipt_long_outlined, 'Tüm Siparişler'),
    ('online', Icons.delivery_dining_outlined, 'Online Siparişler'),
    ('payments', Icons.point_of_sale_outlined, 'Kasa & Ödemeler'),
    ('printer', Icons.print_outlined, 'Yazdırma Kuyruğu'),
    ('staff', Icons.people_alt_outlined, 'Personel Yönetimi'),
    ('reports', Icons.bar_chart_outlined, 'Raporlar'),
    ('wifi', Icons.wifi_tethering_outlined, 'Personel Wi-Fi'),
    ('settings', Icons.settings_outlined, 'Ayarlar'),
  ];

  @override
  void initState() {
    super.initState();
    store = PosStore(databaseFile: widget.databaseFile);
    lan = PosLanServer(store);
    receiptPrinter = ReceiptPrinter(store);
    receiptPrinter.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Menu initialization precedes staff order acceptance.
      unawaited(_startLan());
    });
  }

  Future<void> _startLan() async {
    await _loadMenu();
    if (mounted && widget.startServer) await lan.start();
  }

  Future<void> _loadMenu() async {
    try {
      final text = await rootBundle.loadString('assets/menu.json');
      if (!mounted) return;
      final data = jsonDecode(text) as Map;
      final products = (data['products'] as List).map((item) {
        final p = item as Map;
        return Product(
          id: p['id'] as int,
          name: p['name'] as String,
          category: p['category'] as String,
          price: p['price'] is num ? (p['price'] as num).toDouble() : null,
        );
      }).toList();
      final snap = store.read();
      final next = copyJson(snap.data);
      next.putIfAbsent('localMenu', () => data['products']);
      for (final product in (next['localMenu'] as List).cast<Map>()) {
        if (product['category'] == 'drink' && product['price'] == null) {
          product['price'] = 45;
        }
      }
      seedPlatformMenu(next, asMaps(next['localMenu']));
      store.replace(next, snap.revision);
      if (mounted) setState(() => menu = products);
    } catch (e) {
      _notify('Menü dosyası okunamadı: $e', error: true);
    }
  }

  @override
  void dispose() {
    receiptPrinter.dispose();
    lan.dispose();
    store.dispose();
    super.dispose();
  }

  void _notify(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? const Color(0xffa63831) : dark,
        content: Text(message),
      ),
    );
  }

  bool _edit(void Function(Json state) change) {
    try {
      final snap = store.read();
      final next = copyJson(snap.data);
      change(next);
      final result = store.replace(next, snap.revision);
      if (!result.ok) {
        _notify(
          'Başka cihaz önce kayıt yaptı. Güncel hesap yüklendi; işlemi kontrol edin.',
          error: true,
        );
        return false;
      }
      return true;
    } on FormatException catch (e) {
      _notify(e.message, error: true);
      return false;
    } catch (e) {
      _notify('İşlem kaydedilemedi: $e', error: true);
      return false;
    }
  }

  void _switch(String next) {
    setState(() {
      page = next;
      selectedOrder = null;
      if (next != 'tables') selectedTable = null;
      floorEditing = false;
    });
  }

  Future<void> _composer({int? table, int? addToOrder}) async {
    final savedMenu = asMaps(store.read().data['localMenu']);
    if (savedMenu.isNotEmpty) {
      menu = savedMenu
          .map(
            (p) => Product(
              id: p['id'] as int,
              name: p['name'] as String,
              category: p['category'] as String,
              price: (p['price'] as num?)?.toDouble(),
            ),
          )
          .toList();
    }
    if (menu.isEmpty) {
      _notify('Menü yükleniyor veya okunamadı.', error: true);
      return;
    }
    final request = await showDialog<OrderRequest>(
      context: context,
      builder: (ctx) => _OrderComposer(
        products: menu,
        table: table,
        adding: addToOrder != null,
      ),
    );
    if (request == null) return;
    int? created;
    final ok = _edit((data) {
      if (addToOrder != null) {
        addOrderBatch(data, addToOrder, request.lines);
        created = addToOrder;
      } else {
        final o = newLocalOrder(
          state: data,
          source: request.source,
          table: request.table,
          pickupChannel: request.pickupChannel,
          productLines: request.lines,
        );
        o['customer'] = request.customer;
        created = o['id'] as int;
      }
    });
    if (ok) {
      setState(() {
        page = request.source == 'Masa' || table != null ? 'tables' : 'orders';
        selectedTable = request.table ?? table;
        selectedOrder = created;
      });
      _notify('Sipariş SQLite veritabanına kaydedildi · #$created');
    }
  }

  void _onTable(int table) {
    if (floorEditing) return;
    final order = activeTable(store.read().data, table);
    if (order == null) {
      unawaited(_composer(table: table));
    } else {
      setState(() {
        selectedTable = table;
        selectedOrder = order['id'] as int;
      });
    }
  }

  Future<void> _pay(
    Json order, {
    int? guestId,
    String? guestName,
    int? maximumCents,
  }) async {
    if (order['source'] != 'Masa' && order['source'] != 'Gel-Al') return;
    final due = maximumCents ?? orderDueCents(order);
    final amount = TextEditingController(text: (due / 100).toStringAsFixed(2));
    final received = TextEditingController(
      text: (due / 100).toStringAsFixed(2),
    );
    var method = 'Nakit';
    if (due <= 0) {
      _notify('Bu hesapta kalan ödeme bulunmuyor.');
      return;
    }
    final result = await showDialog<(int, String, int?)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(
            'Ödeme · #${displayOrderNumber(order)} ${guestName ?? ''}',
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ödenecek en fazla ${formatTry(due)}'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Yöntem'),
                  items: ['Nakit', 'Kart']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setDialog(() => method = v ?? 'Nakit'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Tutar (₺)'),
                ),
                if (method == 'Nakit') ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: received,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Alınan nakit (₺)',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'Kart seçeneği şu anda banka POS cihazına bağlı değildir.',
                  style: TextStyle(fontSize: 11, color: Colors.deepOrange),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final n = parseMoney(amount.text),
                      r = method == 'Nakit' ? parseMoney(received.text) : null;
                  Navigator.pop(ctx, (n, method, r));
                } on FormatException catch (e) {
                  _notify(e.message, error: true);
                }
              },
              child: const Text('Ödemeyi Kaydet'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    amount.dispose();
    received.dispose();
    if (!mounted) return;
    if (result == null) return;
    final (amountCents, methodName, receivedCents) = result;
    final ok = _edit((data) {
      final target = mutableOrder(data, order['id'] as int);
      if (target == null) throw const FormatException('Sipariş bulunamadı');
      if (guestId != null && amountCents > (maximumCents ?? 0)) {
        throw const FormatException('Kişi bakiyesi aşıldı');
      }
      recordPayment(
        target,
        amountCents,
        methodName,
        receivedCents: receivedCents,
        guestId: guestId,
      );
      if (guestId != null) {
        final payments = target['payments'] as List;
        final latest = payments.last as Map;
        latest['guestCheckId'] = guestId;
        latest['guestName'] = guestName;
      }
    });
    if (ok) _notify('Ödeme kaydedildi · ${formatTry(amountCents)} (demo)');
  }

  void _closeTable(Json order) {
    if (_edit((data) {
      final target = mutableOrder(data, order['id'] as int);
      if (target == null) throw const FormatException('Sipariş bulunamadı');
      closeLocalTable(target);
    })) {
      setState(() {
        selectedTable = null;
        selectedOrder = null;
      });
      _notify('Masa kapatıldı ve boşaltıldı.');
    }
  }

  void _equalSplit(Json order, int people) {
    _edit(
      (data) => splitEqually(mutableOrder(data, order['id'] as int)!, people),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([store, lan]),
    builder: (ctx, _) {
      final data = store.read().data;
      final width = MediaQuery.sizeOf(context).width;
      final condensed = width < 1050;
      return Scaffold(
        body: Row(
          children: [
            SizedBox(width: condensed ? 74 : 235, child: _sidebar(condensed)),
            Expanded(
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    height: 76,
                    padding: const EdgeInsets.symmetric(horizontal: 27),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'NOHUT FALAFEL / YÖNETİCİ',
                                style: TextStyle(
                                  color: Color(0xff8c998f),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sections.firstWhere((s) => s.$1 == page).$3,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          lan.running ? Icons.wifi_tethering : Icons.wifi_off,
                          color: lan.running ? emerald : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lan.running
                              ? 'Local Server · AKTİF'
                              : 'Local Server · KAPALI',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: lan.running ? emerald : Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const CircleAvatar(
                          backgroundColor: dark,
                          child: Text(
                            'PC',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1400),
                        child: _page(data),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _sidebar(bool condensed) => Material(
    color: dark,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 24, 14, 20),
          child: Row(
            children: [
              const Icon(Icons.restaurant, color: Color(0xfff0d6a7), size: 30),
              if (!condensed) ...[
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NOHUT FALAFEL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'WINDOWS İŞLETME PANELİ',
                        style: TextStyle(
                          color: Color(0xffb4cebc),
                          fontSize: 9,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            children: [
              for (final item in sections)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Tooltip(
                    message: item.$3,
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: condensed ? 15 : 12,
                      ),
                      dense: true,
                      leading: Icon(
                        item.$2,
                        color: page == item.$1
                            ? Colors.white
                            : const Color(0xffbfd4c4),
                      ),
                      title: condensed
                          ? null
                          : Text(
                              item.$3,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: page == item.$1
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                      tileColor: page == item.$1
                          ? const Color(0xff37694d)
                          : Colors.transparent,
                      onTap: () => _switch(item.$1),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!condensed)
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Text(
              'SQLite · Yalnızca güvenilir personel Wi-Fi\nBanka POS / ÖKC / API entegrasyonu yok',
              style: TextStyle(
                color: Color(0xffa4c4af),
                fontSize: 10,
                height: 1.5,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _page(Json db) {
    switch (page) {
      case 'tables':
        return _tables(db);
      case 'orders':
        return _orders(db);
      case 'online':
        return _online(db);
      case 'payments':
        return _payments(db);
      case 'printer':
        return _printer(db);
      case 'staff':
        return _staff(db);
      case 'reports':
        return _reports(db);
      case 'wifi':
        return _wifi(db);
      case 'settings':
        return _settings(db);
      default:
        return _dashboard(db);
    }
  }

  Widget _sectionTitle(String title, String description, {Widget? action}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 17),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: dark,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff708374),
                    ),
                  ),
                ],
              ),
            ),
            ?action,
          ],
        ),
      );

  Widget _metric(
    String label,
    String amount,
    IconData icon, {
    Color color = dark,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xff809081),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            amount,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );

  Widget _dashboard(Json db) {
    final orders = asMaps(db['orders']);
    final active = orders
        .where((o) => o['closed'] != true && o['cancelled'] != true)
        .toList();
    final busy = List.generate(
      5,
      (i) => activeTable(db, i + 1),
    ).where((o) => o != null).length;
    final cash = orders.fold<int>(0, (sum, o) {
      if (o['source'] == 'Masa' || o['source'] == 'Gel-Al') {
        return sum + orderPaidCents(o);
      }
      return sum;
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: dark,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                color: Color(0xfff0d9ab),
                size: 48,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nohut Falafel · İşletme Sistemi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Windows Flutter · Lokal SQLite · Telefon siparişleri QR üzerinden',
                      style: TextStyle(color: Color(0xffbddec6), fontSize: 12),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _composer(),
                icon: const Icon(Icons.add),
                label: const Text('Sipariş Al'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, c) {
            final n = c.maxWidth > 1100 ? 4 : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: n,
              mainAxisExtent: 160,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                _metric(
                  'Aktif Sipariş',
                  '${active.length}',
                  Icons.receipt_outlined,
                ),
                _metric(
                  'Dolu Masa',
                  '$busy / 5',
                  Icons.table_restaurant_outlined,
                ),
                _metric(
                  'Restoran Tahsilatı · Demo',
                  formatTry(cash),
                  Icons.payments_outlined,
                ),
                _metric(
                  'Yazdırma Bekleyen',
                  '${asMaps(db['printJobs']).where((j) => j['state'] != 'İşaretlendi').length}',
                  Icons.print_outlined,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 15),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Son Siparişler',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 13),
                if (orders.isEmpty)
                  const Text(
                    'Henüz sipariş yok. Masa veya Gel-Al ile başlayın.',
                  ),
                for (final o in orders.reversed.take(6))
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(
                      '#${displayOrderNumber(o)} · ${o['source']}${o['table'] == null ? '' : ' · Masa ${o['table']}'}',
                    ),
                    subtitle: Text(o['closed'] == true ? 'Kapalı' : 'Açık'),
                    trailing: Text(formatTry(orderTotalCents(o))),
                    onTap: () => setState(() {
                      selectedOrder = o['id'] as int;
                      page = 'orders';
                    }),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tables(Json db) {
    final order = selectedOrder == null
        ? null
        : asMaps(
            db['orders'],
          ).where((o) => o['id'] == selectedOrder).firstOrNull;
    final positions = floorEditing
        ? draftFloor
        : positionsFromJson(db['floorPositions']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          'Masa Yönetimi',
          '5 masa · KAPI ve sandalyeler · Masa hesabı ve ödeme yalnızca PC üzerinde.',
          action: FilledButton.icon(
            onPressed: () => _composer(),
            icon: const Icon(Icons.add),
            label: const Text('Masa Siparişi'),
          ),
        ),
        Row(
          children: [
            if (!floorEditing)
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  floorEditing = true;
                  draftFloor = {...positionsFromJson(db['floorPositions'])};
                }),
                icon: const Icon(Icons.open_with),
                label: const Text('Yerleşimi Düzenle'),
              ),
            if (floorEditing) ...[
              OutlinedButton(
                onPressed: () =>
                    setState(() => draftFloor = {...floorDefaults}),
                child: const Text('İlk Yerleşim'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => setState(() => floorEditing = false),
                child: const Text('Vazgeç'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  final done = _edit(
                    (data) =>
                        data['floorPositions'] = positionsToJson(draftFloor),
                  );
                  if (done) setState(() => floorEditing = false);
                },
                child: const Text('Düzeni Kaydet'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 15),
        RestaurantFloorPlan(
          state: db,
          positions: positions,
          editing: floorEditing,
          selected: selectedTable,
          onTable: _onTable,
          onMove: (n, delta) => setState(() {
            final r = draftFloor[n]!;
            final left = (r.left + delta.dx)
                .clamp(0.0, 1.0 - r.width)
                .toDouble();
            final top = (r.top + delta.dy)
                .clamp(0.0, 1.0 - r.height)
                .toDouble();
            draftFloor[n] = Rect.fromLTWH(left, top, r.width, r.height);
          }),
        ),
        const SizedBox(height: 17),
        if (order != null && order['source'] == 'Masa') _orderDetail(order),
        if (order == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Text(
                floorEditing
                    ? 'Masaları sürükleyin. Numaralar, hesaplar ve 5 masa değişmez.'
                    : 'Boş masaya tıklayın: yeni sipariş. Dolu masaya tıklayın: hesap, ek sipariş ve ödeme.',
                style: const TextStyle(color: Color(0xff647a67)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _orderDetail(Json o) {
    final id = o['id'] as int;
    final closed = o['closed'] == true;
    final total = orderTotalCents(o), paid = orderPaidCents(o);
    final split = asMaps(o['guestChecks']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sipariş #${displayOrderNumber(o)} · ${o['source']}${o['table'] == null ? '' : ' · Masa ${o['table']}'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        closed
                            ? 'Kapalı'
                            : 'Açık · ${o['serviceStatus'] ?? 'Hazırlanıyor'}',
                        style: const TextStyle(
                          color: Color(0xff708273),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!closed &&
                    (o['source'] == 'Masa' || o['source'] == 'Gel-Al'))
                  OutlinedButton.icon(
                    onPressed: () =>
                        _composer(table: o['table'] as int?, addToOrder: id),
                    icon: const Icon(Icons.add),
                    label: const Text('Ek Sipariş'),
                  ),
              ],
            ),
            const Divider(height: 26),
            for (final line in activeLines(o))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cream,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '${line['qty']}×',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        '${line['name'] ?? line['productKey'] ?? 'Ürün'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      formatTry(
                        cents(line['price']) *
                            ((line['qty'] as num?)?.toInt() ?? 0),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 25),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 10,
              children: [
                Text(
                  'Toplam: ${formatTry(total)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Alınan: ${formatTry(paid)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Kalan: ${formatTry(orderDueCents(o))}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: dark,
                  ),
                ),
              ],
            ),
            if (split.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'Kişi Hesapları',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              for (final guest in split)
                Builder(
                  builder: (context) {
                    final allocated = asMaps(
                      guest['allocations'],
                    ).fold<int>(0, (sum, a) => sum + (a['cents'] as int));
                    final rest = guestBalance(
                      o,
                      guest['id'] as int,
                    ).clamp(0, allocated).toInt();
                    return ListTile(
                      title: Text(
                        '${guest['name'] ?? 'Kişi'} · ${formatTry(allocated)}',
                      ),
                      subtitle: Text('Kalan ${formatTry(rest)}'),
                      trailing: rest > 0 && !closed
                          ? FilledButton(
                              onPressed: () => _pay(
                                o,
                                guestId: guest['id'] as int,
                                guestName: '${guest['name']}',
                                maximumCents: rest,
                              ),
                              child: const Text('Öde'),
                            )
                          : const Icon(Icons.check_circle, color: emerald),
                    );
                  },
                ),
            ],
            const SizedBox(height: 17),
            if (!closed && (o['source'] == 'Masa' || o['source'] == 'Gel-Al'))
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (split.isEmpty && orderDueCents(o) > 0)
                    FilledButton.icon(
                      onPressed: () => _pay(o),
                      icon: const Icon(Icons.payments),
                      label: const Text('Nakit / Kart'),
                    ),
                  if (split.isEmpty && orderPaidCents(o) == 0)
                    PopupMenuButton<int>(
                      onSelected: (n) => _equalSplit(o, n),
                      itemBuilder: (context) => [
                        for (final n in [2, 3, 4, 5, 6, 7, 8, 9, 10])
                          PopupMenuItem(
                            value: n,
                            child: Text('$n kişiye eşit böl'),
                          ),
                      ],
                      child: const Chip(label: Text('⚖ Hesabı Eşit Böl')),
                    ),
                  if (o['source'] == 'Masa' && orderDueCents(o) == 0)
                    OutlinedButton.icon(
                      onPressed: () => _closeTable(o),
                      icon: const Icon(Icons.done_all),
                      label: const Text('Masayı Kapat'),
                    ),
                ],
              ),
            OrderOperations(
              order: o,
              edit: _edit,
              printerName:
                  '${store.read().data['settings']?['printerName'] ?? ''}',
            ),
            if (closed)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Bu hesap kapalı. Ek ürün ve yeni ödeme eklenemez.',
                  style: TextStyle(color: Colors.teal),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _orders(Json db) {
    final all = asMaps(db['orders']).reversed.toList();
    final filtered = all.where((o) {
      final date =
          DateTime.tryParse('${o['createdAt']}')
              ?.toUtc()
              .add(const Duration(hours: 3))
              .toIso8601String()
              .substring(0, 10) ??
          '';
      final text =
          '${o['id']} ${displayOrderNumber(o)} ${o['numberDay'] ?? ''} ${o['table'] ?? ''} ${o['customer']} ${activeLines(o).map((l) => l['name']).join(' ')}'
              .toLowerCase();
      final staff = asMaps(
        o['batches'],
      ).map((b) => b['staff']).join(' ').toLowerCase();
      return (orderFilter == 'Tümü' || o['source'] == orderFilter) &&
          text.contains(orderSearch.toLowerCase()) &&
          staff.contains(orderStaff.toLowerCase()) &&
          (orderStatus.isEmpty ||
              orderStatus == 'Kapalı' && o['closed'] == true ||
              orderStatus == 'İptal' && o['cancelled'] == true ||
              orderStatus == 'Kalan' && orderDueCents(o) > 0 ||
              orderStatus == 'Ödendi' &&
                  orderDueCents(o) == 0 &&
                  o['cancelled'] != true ||
              o['serviceStatus'] == orderStatus) &&
          (orderFrom.isEmpty || date.compareTo(orderFrom) >= 0) &&
          (orderTo.isEmpty || date.compareTo(orderTo) <= 0);
    }).toList();
    final focused = selectedOrder == null
        ? null
        : all.where((o) => o['id'] == selectedOrder).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          'Tüm Siparişler',
          'Masa / Gel-Al / Online platform kayıtları.',
          action: FilledButton.icon(
            onPressed: () => _composer(),
            icon: const Icon(Icons.add),
            label: const Text('Sipariş Al'),
          ),
        ),
        OutlinedButton(
          onPressed: () async {
            final v = await askFields(context, 'Sipariş Filtreleri', [
              ('Sipariş / masa / müşteri / ürün ara', orderSearch),
              (
                'Durum: boş / Kalan / Ödendi / Kapalı / İptal / Hazır / Hazırlanıyor / Teslim Edildi',
                orderStatus,
              ),
              ('Siparişi alan personel', orderStaff),
              ('Başlangıç YYYY-MM-DD', orderFrom),
              ('Bitiş YYYY-MM-DD', orderTo),
            ]);
            if (v != null && mounted) {
              if (v
                      .skip(3)
                      .any(
                        (d) =>
                            d.isNotEmpty &&
                            (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d) ||
                                DateTime.tryParse(d) == null),
                      ) ||
                  v[3].isNotEmpty &&
                      v[4].isNotEmpty &&
                      v[3].compareTo(v[4]) > 0) {
                _notify('Tarih aralığı geçersiz', error: true);
                return;
              }
              setState(() {
                orderSearch = v[0];
                orderStatus = v[1];
                orderStaff = v[2];
                orderFrom = v[3];
                orderTo = v[4];
                selectedOrder = null;
              });
            }
          },
          child: Text('Sipariş Filtreleri · ${filtered.length} kayıt'),
        ),
        Wrap(
          spacing: 7,
          children: [
            for (final filter in [
              'Tümü',
              'Masa',
              'Gel-Al',
              'Yemeksepeti',
              'Trendyol Go',
            ])
              ChoiceChip(
                label: Text(filter),
                selected: orderFilter == filter,
                onSelected: (_) => setState(() => orderFilter = filter),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (focused != null) _orderDetail(focused),
        Card(
          child: Column(
            children: [
              if (filtered.isEmpty)
                const ListTile(title: Text('Sipariş bulunamadı')),
              for (final o in filtered)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cream,
                    child: Text('${o['table'] ?? '#'}'),
                  ),
                  title: Text('#${displayOrderNumber(o)} · ${o['source']}'),
                  subtitle: Text(
                    o['closed'] == true
                        ? 'Kapalı'
                        : (o['serviceStatus'] ?? 'Açık').toString(),
                  ),
                  trailing: Text(formatTry(orderTotalCents(o))),
                  onTap: () => setState(() => selectedOrder = o['id'] as int),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _online(Json db) => PlatformPanel(state: db, edit: _edit);

  Widget _payments(Json db) {
    final locals = asMaps(db['orders'])
        .where(
          (o) =>
              (o['source'] == 'Masa' || o['source'] == 'Gel-Al') &&
              orderDueCents(o) > 0,
        )
        .toList();
    final totalDue = locals.fold<int>(0, (s, o) => s + orderDueCents(o));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          'Kasa & Ödemeler',
          'Bütün ödemeler Kasa (PC) tarafından işlenir. Telefonlarda ödeme ekranı yoktur.',
        ),
        Row(
          children: [
            Expanded(
              child: _metric(
                'Açık Hesaplar',
                '${locals.length}',
                Icons.receipt_long,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metric(
                'Restoran Alacağı',
                formatTry(totalDue),
                Icons.payments,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _notice(
          'Kart tahsilatı bu sürümde banka POS terminaline otomatik aktarılmaz. Fiziksel mali fiş / ÖKC entegrasyonu yoktur.',
        ),
        const SizedBox(height: 13),
        Card(
          child: Column(
            children: [
              if (locals.isEmpty)
                const ListTile(title: Text('Açık ödeme bulunmuyor')),
              for (final o in locals)
                ListTile(
                  title: Text(
                    '#${displayOrderNumber(o)} · ${o['source']}${o['table'] == null ? '' : ' · Masa ${o['table']}'}',
                  ),
                  subtitle: Text('Toplam ${formatTry(orderTotalCents(o))}'),
                  trailing: FilledButton(
                    onPressed: () {
                      setState(() {
                        selectedOrder = o['id'] as int;
                        page = 'orders';
                      });
                    },
                    child: Text('Kalan ${formatTry(orderDueCents(o))}'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CashPanel(state: db, edit: _edit),
      ],
    );
  }

  Widget _printer(Json db) => PrinterPanel(state: db, edit: _edit);

  Widget _staff(Json db) => StaffPanel(state: db, edit: _edit);

  Widget _reports(Json db) => ReportsPanel(state: db, edit: _edit);

  Widget _wifi(Json db) {
    final url = lan.staffUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          'Personel Wi-Fi · Yerel Sunucu',
          'Windows Flutter programı laptop üzerinde SQLite ve HTTP sunucusunu başlatır. Personel Chrome QR ile bağlanır.',
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            lan.running
                                ? Icons.check_circle
                                : Icons.error_outline,
                            color: lan.running ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            lan.running
                                ? 'Local Server çalışıyor'
                                : 'Local Server kapalı',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Port: ${lan.port}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'SQLite: ${store.filePath}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(height: 16),
                      if (lan.addresses.isNotEmpty)
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue:
                              lan.selectedIp != null &&
                                  lan.addresses.contains(lan.selectedIp)
                              ? lan.selectedIp
                              : lan.addresses.first,
                          decoration: const InputDecoration(
                            labelText: 'Laptopun Wi-Fi IPv4 adresi',
                          ),
                          items: lan.addresses
                              .map(
                                (ip) => DropdownMenuItem(
                                  value: ip,
                                  child: Text(ip),
                                ),
                              )
                              .toList(),
                          onChanged: (ip) {
                            if (ip != null) lan.chooseIp(ip);
                          },
                        ),
                      if (lan.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            lan.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      if (!lan.available)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 11),
                          child: Text(
                            'Yerel ağ IPv4 bulunamadı. Telefon QR çalışmayabilir.',
                            style: TextStyle(color: Colors.deepOrange),
                          ),
                        ),
                      const SizedBox(height: 15),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => lan.discover(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('IP Yenile'),
                          ),
                          if (!lan.running)
                            FilledButton(
                              onPressed: () => lan.start(),
                              child: const Text('Sunucuyu Başlat'),
                            ),
                          if (lan.running)
                            OutlinedButton(
                              onPressed: () => lan.stop(),
                              child: const Text('Sunucuyu Durdur'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Bağlantı Mantığı',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '1. Laptop ve personel telefonları aynı Wi-Fi\n'
                        '2. Flutter uygulaması açık ve sunucu çalışır\n'
                        '3. Personel QR kodunu tarar, adını seçer\n'
                        '4. 5 masanın siparişleri ortak SQLite veritabanına kaydedilir\n'
                        '5. Kasa ve ödeme yalnızca laptopta',
                        style: TextStyle(height: 1.8, fontSize: 12),
                      ),
                      const SizedBox(height: 11),
                      const Text(
                        'Şimdilik şifre yok. Misafir Wi-Fi, router izolasyonu ve internet port yönlendirme kullanmayın.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(21),
                  child: Column(
                    children: [
                      const Text(
                        'PERSONEL GİRİŞ QR',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 17),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(color: const Color(0xffdce7da)),
                        ),
                        child: lan.running && lan.available
                            ? QrImageView(
                                data: url,
                                size: 215,
                                errorCorrectionLevel: QrErrorCorrectLevel.M,
                              )
                            : const SizedBox(
                                height: 215,
                                width: 215,
                                child: Center(
                                  child: Text(
                                    'Wi-Fi IP bekleniyor',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 13),
                      SelectableText(
                        lan.running ? url : 'Sunucu başlamadı',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 13),
                      FilledButton.icon(
                        onPressed: lan.running
                            ? () {
                                Clipboard.setData(ClipboardData(text: url));
                                _notify('Personel URL kopyalandı');
                              }
                            : null,
                        icon: const Icon(Icons.copy),
                        label: const Text('Bağlantıyı Kopyala'),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'Android Chrome · iPhone Safari',
                        style: TextStyle(
                          color: Color(0xff798e7b),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _notice(
          'Gerçek fiziksel Windows laptopta test edilmelidir. Bu uygulama dış internete açılmamalıdır. QR menü sipariş vermek için değil, personel uygulamasını açmak içindir.',
        ),
      ],
    );
  }

  Widget _settings(Json db) =>
      SettingsPanel(state: db, edit: _edit, store: store);

  Widget _notice(String text) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xfffff1d9),
      border: Border.all(color: const Color(0xfff0dbb2)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xff775624),
        fontSize: 12,
        height: 1.5,
      ),
    ),
  );
}

class _OrderComposer extends StatefulWidget {
  const _OrderComposer({
    required this.products,
    this.table,
    this.adding = false,
  });
  final List<Product> products;
  final int? table;
  final bool adding;

  @override
  State<_OrderComposer> createState() => _OrderComposerState();
}

class _OrderComposerState extends State<_OrderComposer> {
  final counts = <int, int>{};
  final notes = <int, String>{};
  Json pickupCustomer = {};
  final removed = <int, List<String>>{};
  String category = 'all', source = 'Masa', pickup = 'Tezgahtan';
  int? table;
  @override
  void initState() {
    super.initState();
    table = widget.table;
    if (widget.adding) source = widget.table == null ? 'Gel-Al' : 'Masa';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products
        .where((p) => (category == 'all' || p.category == category))
        .toList();
    final totalCents = counts.entries.fold<int>(0, (sum, e) {
      final p = widget.products.firstWhere((x) => x.id == e.key);
      return sum + cents(p.price) * e.value;
    });
    return Dialog(
      child: SizedBox(
        width: 820,
        height: 650,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.adding
                          ? 'Ek Sipariş · Kasa (PC)'
                          : 'Yeni Sipariş · Kasa (PC)',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!widget.adding)
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: source,
                        decoration: const InputDecoration(
                          labelText: 'Sipariş Türü',
                        ),
                        items: ['Masa', 'Gel-Al']
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => source = v ?? 'Masa'),
                      ),
                    ),
                  if (!widget.adding) const SizedBox(width: 12),
                  if (source == 'Masa')
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: table,
                        decoration: const InputDecoration(labelText: 'Masa'),
                        items: List.generate(
                          5,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('Masa ${i + 1}'),
                          ),
                        ),
                        onChanged: widget.adding
                            ? null
                            : (v) => setState(() => table = v),
                      ),
                    ),
                  if (source == 'Gel-Al')
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: pickup,
                        decoration: const InputDecoration(
                          labelText: 'Teslim Alma',
                        ),
                        items: ['Tezgahtan', 'Telefon']
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => pickup = v ?? 'Tezgahtan'),
                      ),
                    ),
                ],
              ),
              if (source == 'Gel-Al' && !widget.adding)
                OutlinedButton(
                  onPressed: () async {
                    final v = await askFields(context, 'Gel-Al Bilgileri', [
                      ('Ad', '${pickupCustomer['name'] ?? ''}'),
                      ('Telefon', '${pickupCustomer['phone'] ?? ''}'),
                      ('Teslim alma saati', '${pickupCustomer['time'] ?? ''}'),
                    ]);
                    if (v != null && mounted) {
                      setState(
                        () => pickupCustomer = {
                          'name': v[0],
                          'phone': v[1],
                          'time': v[2],
                        },
                      );
                    }
                  },
                  child: const Text('Gel-Al Müşteri / Saat Bilgisi'),
                ),
              const SizedBox(height: 15),
              const Text('Ürüne dokunun: not ve çıkarılan malzemeler.'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final x in [
                      ('all', 'Tümü'),
                      ('wrap', 'Dürümler'),
                      ('plate', 'Porsiyonlar'),
                      ('meze', 'Mezeler'),
                      ('fatte', 'Fatte'),
                      ('side', 'Diğer'),
                      ('salad', 'Salatalar'),
                      ('dessert', 'Tatlı'),
                      ('drink', 'İçecekler'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ChoiceChip(
                          label: Text(x.$2),
                          selected: category == x.$1,
                          onSelected: (_) => setState(() => category = x.$1),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final p = filtered[i], qty = counts[p.id] ?? 0;
                    return ListTile(
                      title: Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        p.price == null
                            ? 'Fiyat belirlenmedi'
                            : '${formatTry(cents(p.price))} · ${notes[p.id] ?? ''}',
                      ),
                      onTap: () async {
                        final v = await askFields(context, p.name, [
                          ('Ürün notu', notes[p.id] ?? ''),
                          (
                            'Çıkarılan malzemeler (virgülle)',
                            (removed[p.id] ?? []).join(', '),
                          ),
                        ]);
                        if (v != null && mounted) {
                          setState(() {
                            notes[p.id] = v[0];
                            removed[p.id] = v[1]
                                .split(',')
                                .map((s) => s.trim())
                                .where((s) => s.isNotEmpty)
                                .toList();
                          });
                        }
                      },
                      trailing: p.price == null
                          ? const Text(
                              'Fiyat yok',
                              style: TextStyle(color: Colors.deepOrange),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: qty > 0
                                      ? () => setState(() {
                                          if (qty == 1) {
                                            counts.remove(p.id);
                                          } else {
                                            counts[p.id] = qty - 1;
                                          }
                                        })
                                      : null,
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text(
                                  '$qty',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      setState(() => counts[p.id] = qty + 1),
                                  icon: const Icon(
                                    Icons.add_circle,
                                    color: emerald,
                                  ),
                                ),
                              ],
                            ),
                    );
                  },
                ),
              ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ürün: ${counts.values.fold<int>(0, (a, b) => a + b)} · Toplam: ${formatTry(totalCents)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Vazgeç'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed:
                        counts.isEmpty || (source == 'Masa' && table == null)
                        ? null
                        : () {
                            final lines = <Json>[];
                            for (final entry in counts.entries) {
                              final product = widget.products.firstWhere(
                                (p) => p.id == entry.key,
                              );
                              lines.add({
                                'productId': product.id,
                                'productKey': product.name,
                                'name': product.name,
                                'price': product.price,
                                'qty': entry.value,
                                'removed': removed[product.id] ?? <String>[],
                                'note': notes[product.id] ?? '',
                              });
                            }
                            Navigator.pop(
                              context,
                              OrderRequest(
                                source: source,
                                table: source == 'Masa' ? table : null,
                                pickupChannel: pickup,
                                lines: lines,
                                customer: pickupCustomer,
                              ),
                            );
                          },
                    icon: const Icon(Icons.save),
                    label: const Text('Siparişi Kaydet'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
