import 'order_reporting.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'floor_plan.dart';
import 'lan_server.dart';
import 'pos_logic.dart';
import 'pos_store.dart';
import 'operations.dart';
import 'operations_ui.dart';
import 'platform_workflows.dart';
import 'staff_qr_ui.dart';
import 'platform_api.dart';
import 'platform_runtime.dart';
import 'settings_workspace.dart';
import 'reports_workspace.dart';
import 'cash_workspace.dart';
import 'staff_directory.dart';
import 'print_service.dart';
import 'documents_workspace.dart';
import 'dashboard_insights.dart';
import 'platform_ui.dart';
import 'order_action_ui.dart';
import 'order_workspace.dart';
import 'printer_workspace.dart';

const dark = Color(0xff183b2c);
const cream = Color(0xfff6f6f2);
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
    this.secretStore,
  });
  final String? databaseFile;
  final bool startServer;
  final SecretStore? secretStore;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Nohut Falafel · Yönetici Paneli',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: dark, surface: cream),
      scaffoldBackgroundColor: cream,
      dividerColor: const Color(0xffe3e9e6),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          side: const BorderSide(color: Color(0xffd8e2dc)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      fontFamily: 'Segoe UI',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 13, color: Color(0xff213429)),
        bodyLarge: TextStyle(fontSize: 14, color: Color(0xff213429)),
        labelLarge: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: const BorderSide(color: Color(0xffe1e8df)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    ),
    home: ManagerDesktop(
      databaseFile: databaseFile,
      startServer: startServer,
      secretStore: secretStore,
    ),
  );
}

class ManagerDesktop extends StatefulWidget {
  const ManagerDesktop({
    super.key,
    this.databaseFile,
    this.startServer = true,
    this.secretStore,
  });
  final String? databaseFile;
  final bool startServer;
  final SecretStore? secretStore;
  @override
  State<ManagerDesktop> createState() => _ManagerDesktopState();
}

class _ManagerDesktopState extends State<ManagerDesktop> {
  late final PosStore store;
  late final AutomaticKitchenPrinter automaticPrinter;
  late final PosLanServer lan;
  late final PlatformRuntime runtime;
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
    ('documents', Icons.description_outlined, 'Fiş & Fatura'),
    ('staff', Icons.qr_code_rounded, 'Personel & QR'),
    ('reports', Icons.bar_chart_outlined, 'Raporlar'),
    ('settings', Icons.settings_outlined, 'Ayarlar'),
  ];

  @override
  void initState() {
    super.initState();
    store = PosStore(databaseFile: widget.databaseFile);
    lan = PosLanServer(store);
    automaticPrinter = AutomaticKitchenPrinter(store);
    automaticPrinter.start();
    runtime = PlatformRuntime(
      store,
      CredentialVault(widget.secretStore ?? WindowsSecretStore()),
    );
    store.addListener(_onStoreChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Menu initialization precedes staff order acceptance.
      unawaited(_startLan());
    });
  }

  void _onStoreChange() {
    if (widget.startServer) unawaited(runtime.runOnce());
  }

  Future<void> _startLan() async {
    await _loadMenu();
    if (mounted && widget.startServer) {
      await lan.start();
      runtime.start();
    }
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
      final settings =
          next.putIfAbsent('settings', () => <String, dynamic>{}) as Map;
      settings['printerModel'] = 'XP-237B';
      settings['paperWidthMm'] = 58;
      settings['printableWidthMm'] = 48;
      settings['receiptScale'] = 'shrink';
      settings.putIfAbsent('autoPrint', () => true);
      settings.putIfAbsent(
        'autoPrintEnabledAt',
        () => DateTime.now().toUtc().toIso8601String(),
      );
      seedPlatformMenu(next, asMaps(next['localMenu']));
      store.replace(next, snap.revision);
      if (mounted) setState(() => menu = products);
    } catch (e) {
      _notify('Menü dosyası okunamadı: $e', error: true);
    }
  }

  @override
  void dispose() {
    automaticPrinter.dispose();
    runtime.dispose();
    store.removeListener(_onStoreChange);
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
      _notify(
        'Sipariş SQLite veritabanına kaydedildi · #${displayOrderNumber(mutableOrder(store.read().data, created!)!)}',
      );
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
            SizedBox(width: condensed ? 74 : 255, child: _sidebar(condensed)),
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
                              ? 'Telefon bağlantısı açık'
                              : 'Telefon bağlantısı kapalı',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: lan.running ? emerald : Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 14),
                        OutlinedButton.icon(
                          onPressed: () => setState(() => page = 'staff'),
                          icon: const Icon(Icons.qr_code_rounded, size: 18),
                          label: const Text('Personel QR'),
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
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child:
                          [
                            'tables',
                            'orders',
                            'printer',
                            'settings',
                            'reports',
                            'payments',
                            'online',
                            'documents',
                          ].contains(page)
                          ? _page(data)
                          : SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1400,
                                ),
                                child: _page(data),
                              ),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/brand-logo.jpeg',
                  width: 45,
                  height: 45,
                  fit: BoxFit.cover,
                ),
              ),
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
                        'İŞLETME SİSTEMİ',
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
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: FilledButton(
                  onPressed: () => _composer(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xffdcead8),
                    foregroundColor: dark,
                  ),
                  child: Text(condensed ? '+' : '+ Sipariş Al'),
                ),
              ),
              for (final item in sections) ...[
                if (!condensed && ['dashboard', 'staff'].contains(item.$1))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 15, 14, 10),
                    child: Text(
                      item.$1 == 'dashboard' ? 'GÜNLÜK İŞLEMLER' : 'İŞLETME',
                      style: const TextStyle(
                        color: Color(0xff87ac94),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
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
            ],
          ),
        ),
        if (!condensed)
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 24),
            child: Text(
              'Kasa (PC)\nNohut Falafel',
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
      case 'documents':
        return DocumentsWorkspace(
          state: db,
          edit: _edit,
          runtime: runtime,
          onOrder: (id) => setState(() {
            selectedOrder = id;
            page = 'orders';
          }),
          onPrinter: () => _switch('printer'),
        );
      case 'staff':
        return _staff(db);
      case 'reports':
        return _reports(db);
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
    VoidCallback? onTap,
  }) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      hoverColor: const Color(0xffedf5e9),
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
                if (onTap != null)
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: Color(0xff9aac9d),
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
                      'Restoranın siparişleri, masaları ve ekibi tek yerde.',
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
                  onTap: () => _switch('orders'),
                ),
                _metric(
                  'Dolu Masa',
                  '$busy / 5',
                  Icons.table_restaurant_outlined,
                  onTap: () => _switch('tables'),
                ),
                _metric(
                  'Restoran Tahsilatı · Demo',
                  formatTry(cash),
                  Icons.payments_outlined,
                  onTap: () => _switch('payments'),
                ),
                _metric(
                  'Yazdırma Bekleyen',
                  '${asMaps(db['printJobs']).where((j) => !printCompleted(j)).length}',
                  Icons.print_outlined,
                  onTap: () => _switch('printer'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 15),
        DashboardInsights(
          state: db,
          onSource: (source) => setState(() {
            orderFilter = source;
            orderSearch = orderStatus = orderStaff = orderFrom = orderTo = '';
            selectedOrder = null;
            page = 'orders';
          }),
          onReport: () => _switch('reports'),
        ),
        const SizedBox(height: 18),
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
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: RestaurantFloorPlan(
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
                      draftFloor[n] = Rect.fromLTWH(
                        left,
                        top,
                        r.width,
                        r.height,
                      );
                    }),
                  ),
                ),
                if (order != null &&
                    order['source'] == 'Masa' &&
                    !floorEditing) ...[
                  const SizedBox(width: 16),
                  SizedBox(
                    width: c.maxWidth < 1100 ? 420 : 500,
                    child: _orderDetail(order),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _orderDetail(Json o) => OrderWorkspace(
    key: ValueKey(o['id']),
    order: o,
    edit: _edit,
    onAdd: () =>
        _composer(table: o['table'] as int?, addToOrder: o['id'] as int),
    onPay: () => _pay(o),
    onClose: () => _closeTable(o),
    onGuestPay: (guest) => _pay(
      o,
      guestId: guest['id'] as int,
      guestName: '${guest['name']}',
      maximumCents: guestBalance(o, guest['id'] as int),
    ),
  );

  Widget _online(Json db) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child: PlatformPanel(
          state: db,
          edit: _edit,
          onDocuments: () => _switch('documents'),
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Platform İşlem Kaydı'),
              content: SizedBox(
                width: 1000,
                height: 500,
                child: SingleChildScrollView(
                  child: ListenableBuilder(
                    listenable: store,
                    builder: (context, _) => OrderActionLog(
                      state: store.read().data,
                      edit: _edit,
                      initiallyExpanded: true,
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Kapat'),
                ),
              ],
            ),
          ),
          icon: const Icon(Icons.history, size: 18),
          label: const Text('İşlem Kaydı / Platform Senkronizasyonu'),
        ),
      ),
    ],
  );

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
    final chosen = focused ?? filtered.firstOrNull;
    if (selectedOrder == null && chosen != null) {
      final initialId = chosen['id'] as int;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && page == 'orders' && selectedOrder == null) {
          setState(() => selectedOrder = initialId);
        }
      });
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          'Tüm Siparişler',
          'Siparişi seçin; ürünler, kişi payları ve tahsilatlar sağda açılır.',
          action: FilledButton.icon(
            onPressed: () => _composer(),
            icon: const Icon(Icons.add),
            label: const Text('Sipariş Al'),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Sipariş, masa, müşteri veya ürün ara…',
                ),
                onChanged: (v) => setState(() {
                  orderSearch = v;
                  selectedOrder = null;
                }),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<String>(
                initialValue: orderStatus,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Durum'),
                items: [
                  for (final value in [
                    '',
                    'Kalan',
                    'Ödendi',
                    'Kapalı',
                    'İptal',
                    'Hazır',
                    'Hazırlanıyor',
                    'Teslim Edildi',
                  ])
                    DropdownMenuItem(
                      value: value,
                      child: Text(value.isEmpty ? 'Tüm Durumlar' : value),
                    ),
                ],
                onChanged: (v) => setState(() {
                  orderStatus = v ?? '';
                  selectedOrder = null;
                }),
              ),
            ),
            IconButton(
              tooltip: 'Tarih / Personel Filtreleri',
              icon: const Icon(Icons.tune),
              onPressed: () async {
                final v = await askFields(context, 'Tarih / Personel', [
                  ('Personel', orderStaff),
                  ('Başlangıç YYYY-MM-DD', orderFrom),
                  ('Bitiş YYYY-MM-DD', orderTo),
                ]);
                if (v != null && mounted) {
                  if (v
                          .skip(1)
                          .any(
                            (d) =>
                                d.isNotEmpty &&
                                (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d) ||
                                    DateTime.tryParse(d) == null),
                          ) ||
                      v[1].isNotEmpty &&
                          v[2].isNotEmpty &&
                          v[1].compareTo(v[2]) > 0) {
                    _notify('Tarih aralığı geçersiz', error: true);
                    return;
                  }
                  setState(() {
                    orderStaff = v[0];
                    orderFrom = v[1];
                    orderTo = v[2];
                    selectedOrder = null;
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in [
                'Tümü',
                'Masa',
                'Gel-Al',
                'Yemeksepeti',
                'Trendyol Go',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: orderFilter == filter,
                    onSelected: (_) => setState(() {
                      orderFilter = filter;
                      selectedOrder = null;
                    }),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 300,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Siparişler',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Text(
                              '${filtered.length} kayıt',
                              style: const TextStyle(color: Color(0xff7c8b80)),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(child: Text('Sipariş bulunamadı.'))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, i) {
                                  final order = filtered[i];
                                  return ListTile(
                                    key: ValueKey('order-row-${order['id']}'),
                                    selected: chosen?['id'] == order['id'],
                                    selectedTileColor: const Color(0xffedf5e9),
                                    leading: CircleAvatar(
                                      backgroundColor: cream,
                                      child: Text('${order['table'] ?? '#'}'),
                                    ),
                                    title: Text(
                                      '#${displayOrderNumber(order)} · ${order['source']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${order['closed'] == true ? 'Kapalı' : order['serviceStatus'] ?? order['demoRemoteStatus'] ?? 'Açık'} · ${formatTry(orderTotalCents(order))}',
                                    ),
                                    onTap: () => setState(
                                      () => selectedOrder = order['id'] as int,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: chosen == null
                    ? const Card(
                        child: Center(
                          child: Text('Sipariş detayları burada açılır.'),
                        ),
                      )
                    : _orderDetail(chosen),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _payments(Json db) => CashWorkspace(
    state: db,
    edit: _edit,
    onOrder: (id) => setState(() {
      selectedOrder = id;
      page = 'orders';
    }),
  );

  Widget _printer(Json db) =>
      PrinterWorkspace(state: db, edit: _edit, service: PrintService(store));

  Widget _staff(Json db) => StaffQrPanel(
    server: lan,
    editor: StaffDirectory(state: db, edit: _edit),
  );

  Widget _reports(Json db) => ReportsWorkspace(
    state: db,
    edit: _edit,
    onOrder: (id) => setState(() {
      selectedOrder = id;
      page = 'orders';
    }),
  );

  Widget _settings(Json db) => SettingsWorkspace(
    state: db,
    edit: _edit,
    store: store,
    runtime: runtime,
    onStaff: () => _switch('staff'),
    onPrinter: () => _switch('printer'),
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
  final searchController = TextEditingController();
  final counts = <int, int>{};
  final notes = <int, String>{};
  final removed = <int, List<String>>{};
  Json pickupCustomer = {};
  String category = 'wrap', source = 'Masa', pickup = 'Tezgahtan', search = '';
  int? table;
  static const categories = {
    'wrap': 'Dürümler',
    'plate': 'Porsiyonlar',
    'drink': 'İçecekler',
    'meze': 'Mezeler',
    'fatte': 'Fatte',
    'side': 'Yan Ürünler',
    'salad': 'Salatalar',
    'dessert': 'Tatlılar',
  };
  IconData icon(String category) => switch (category) {
    'wrap' => Icons.lunch_dining_rounded,
    'plate' => Icons.dinner_dining_rounded,
    'drink' => Icons.local_drink_rounded,
    'dessert' => Icons.cake_outlined,
    'salad' => Icons.eco_outlined,
    _ => Icons.restaurant_menu_rounded,
  };
  @override
  void initState() {
    super.initState();
    table = widget.table;
    if (widget.adding) source = widget.table == null ? 'Gel-Al' : 'Masa';
    if (!widget.products.any((p) => p.category == category) &&
        widget.products.isNotEmpty) {
      category = widget.products.first.category;
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  int get total => counts.entries.fold(
    0,
    (sum, e) =>
        sum +
        cents(widget.products.firstWhere((p) => p.id == e.key).price) * e.value,
  );
  int get quantity => counts.values.fold(0, (a, b) => a + b);
  String searchKey(String value) => value
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('\u0307', '');
  void change(Product p, int delta) {
    if (p.price == null) return;
    setState(() {
      final n = ((counts[p.id] ?? 0) + delta).clamp(0, 1000);
      if (n == 0) {
        counts.remove(p.id);
        notes.remove(p.id);
        removed.remove(p.id);
      } else {
        counts[p.id] = n;
      }
    });
  }

  Future<void> customize(Product p) async {
    final v = await askFields(context, '${p.name} · Not / Malzeme', [
      ('Ürün notu', notes[p.id] ?? ''),
      ('Çıkarılacak malzemeler (virgülle)', (removed[p.id] ?? []).join(', ')),
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
  }

  void save() {
    if (counts.isEmpty || (source == 'Masa' && table == null)) return;
    Navigator.pop(
      context,
      OrderRequest(
        source: source,
        table: source == 'Masa' ? table : null,
        pickupChannel: pickup,
        customer: pickupCustomer,
        lines: [
          for (final e in counts.entries)
            (() {
              final p = widget.products.firstWhere((p) => p.id == e.key);
              return <String, dynamic>{
                'productId': p.id,
                'productKey': p.name,
                'name': p.name,
                'price': p.price,
                'qty': e.value,
                'removed': removed[p.id] ?? <String>[],
                'note': notes[p.id] ?? '',
              };
            })(),
        ],
      ),
    );
  }

  Widget categoryButton(String id, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 7, right: 7),
    child: ChoiceChip(
      key: ValueKey('category-$id'),
      showCheckmark: false,
      avatar: Icon(
        icon(id),
        size: 18,
        color: category == id ? Colors.white : dark,
      ),
      label: Text(label),
      selected: category == id && search.isEmpty,
      selectedColor: dark,
      labelStyle: TextStyle(
        color: category == id && search.isEmpty ? Colors.white : dark,
        fontWeight: FontWeight.w700,
      ),
      onSelected: (_) => setState(() {
        category = id;
        search = '';
        searchController.clear();
      }),
    ),
  );
  Widget basket() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xffe4e9e3)),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.shopping_bag_outlined),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Sipariş Sepeti',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '$quantity ürün',
              style: const TextStyle(color: Color(0xff7c8b80)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          source == 'Masa'
              ? (table == null
                    ? 'Önce masa seçin'
                    : 'Masa $table${widget.adding ? ' · Ek Sipariş' : ''}')
              : 'Gel-Al · $pickup',
          style: const TextStyle(color: emerald, fontWeight: FontWeight.w700),
        ),
        const Divider(height: 24),
        Expanded(
          child: counts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 46,
                        color: Color(0xffa6bca8),
                      ),
                      SizedBox(height: 14),
                      Text('Sepet henüz boş'),
                      SizedBox(height: 6),
                      Text(
                        'Ürün kartına dokunarak ekleyin.',
                        style: TextStyle(
                          color: Color(0xff7c8b80),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  children: [
                    for (final entry in counts.entries)
                      (() {
                        final p = widget.products.firstWhere(
                          (p) => p.id == entry.key,
                        );
                        return Container(
                          key: ValueKey('basket-${p.id}'),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0xffedf0ea)),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                formatTry(cents(p.price) * entry.value),
                                style: const TextStyle(
                                  color: emerald,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if ((notes[p.id] ?? '').isNotEmpty)
                                Text(
                                  notes[p.id]!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xff7c8b80),
                                  ),
                                ),
                              if ((removed[p.id] ?? []).isNotEmpty)
                                Text(
                                  'Çıkar: ${removed[p.id]!.join(', ')}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () => customize(p),
                                      child: const Text('Not / Malzeme'),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '${p.name} azalt',
                                    onPressed: () => change(p, -1),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                  Text(
                                    '${entry.value}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '${p.name} artır',
                                    onPressed: () => change(p, 1),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      })(),
                  ],
                ),
        ),
        const Divider(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('TOPLAM', style: TextStyle(fontWeight: FontWeight.w700)),
            Text(
              formatTry(total),
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const ValueKey('save-order'),
          onPressed: counts.isEmpty || (source == 'Masa' && table == null)
              ? null
              : save,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Siparişi Kaydet'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ctrl + Enter ile kaydet',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Color(0xff7c8b80)),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final available = widget.products.map((p) => p.category).toSet();
    final labels = {
      ...categories,
      for (final id in available)
        if (!categories.containsKey(id)) id: id,
    };
    final filtered = widget.products
        .where(
          (p) => search.trim().isEmpty
              ? p.category == category
              : searchKey(p.name).contains(searchKey(search.trim())),
        )
        .toList();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): save,
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: cream,
        child: SizedBox(
          width: 1220,
          height: MediaQuery.sizeOf(context).height * .89,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.restaurant_menu_rounded, color: emerald),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.adding ? 'Ek Sipariş' : 'Sipariş Al',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kapat',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (widget.adding)
                  Text(
                    source == 'Masa'
                        ? 'Masa $table · Mevcut hesaba ürün ekle'
                        : 'Gel-Al · Mevcut siparişe ürün ekle',
                    style: const TextStyle(
                      color: emerald,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final type in ['Masa', 'Gel-Al'])
                        ChoiceChip(
                          label: Text(type),
                          selected: source == type,
                          onSelected: (_) => setState(() => source = type),
                        ),
                      const SizedBox(width: 8),
                      if (source == 'Masa')
                        for (var n = 1; n <= 5; n++)
                          ChoiceChip(
                            key: ValueKey('select-table-$n'),
                            label: Text('Masa $n'),
                            selected: table == n,
                            onSelected: (_) => setState(() => table = n),
                          ),
                      if (source == 'Gel-Al') ...[
                        for (final channel in ['Tezgahtan', 'Telefon'])
                          ChoiceChip(
                            label: Text(channel),
                            selected: pickup == channel,
                            onSelected: (_) => setState(() => pickup = channel),
                          ),
                        TextButton.icon(
                          onPressed: () async {
                            final v = await askFields(
                              context,
                              'Gel-Al Bilgileri',
                              [
                                ('Ad', '${pickupCustomer['name'] ?? ''}'),
                                ('Telefon', '${pickupCustomer['phone'] ?? ''}'),
                                (
                                  'Teslim alma saati',
                                  '${pickupCustomer['time'] ?? ''}',
                                ),
                              ],
                            );
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
                          icon: const Icon(Icons.person_outline, size: 18),
                          label: const Text('Müşteri Bilgisi'),
                        ),
                      ],
                    ],
                  ),
                const SizedBox(height: 18),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 1000;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (wide) ...[
                            SizedBox(
                              width: 142,
                              child: ListView(
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 14),
                                    child: Text(
                                      'MENÜ',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xff7c8b80),
                                        letterSpacing: 1.3,
                                      ),
                                    ),
                                  ),
                                  for (final e in labels.entries)
                                    if (available.contains(e.key))
                                      categoryButton(e.key, e.value),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  key: const ValueKey('catalog-search'),
                                  controller: searchController,
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.search),
                                    hintText: 'Ürün ara…',
                                  ),
                                  onChanged: (v) => setState(() => search = v),
                                ),
                                const SizedBox(height: 12),
                                if (!wide)
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        for (final e in labels.entries)
                                          if (available.contains(e.key))
                                            categoryButton(e.key, e.value),
                                      ],
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    search.isEmpty
                                        ? '${labels[category]} · ${filtered.length} ürün'
                                        : '${filtered.length} arama sonucu',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: filtered.isEmpty
                                      ? const Center(
                                          child: Text('Ürün bulunamadı.'),
                                        )
                                      : GridView.builder(
                                          gridDelegate:
                                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                                maxCrossAxisExtent: 220,
                                                mainAxisExtent: 164,
                                                crossAxisSpacing: 12,
                                                mainAxisSpacing: 12,
                                              ),
                                          itemCount: filtered.length,
                                          itemBuilder: (context, i) {
                                            final p = filtered[i],
                                                qty = counts[p.id] ?? 0;
                                            return Material(
                                              color: qty > 0
                                                  ? const Color(0xfff1f7eb)
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              child: InkWell(
                                                key: ValueKey(
                                                  'product-${p.id}',
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                onTap: p.price == null
                                                    ? null
                                                    : () => change(p, 1),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    15,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: qty > 0
                                                          ? const Color(
                                                              0xff9eb99f,
                                                            )
                                                          : const Color(
                                                              0xffe4e9e3,
                                                            ),
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            icon(p.category),
                                                            color: emerald,
                                                          ),
                                                          const Spacer(),
                                                          if (qty > 0)
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical: 4,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color:
                                                                    const Color(
                                                                      0xffdcead8,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      99,
                                                                    ),
                                                              ),
                                                              child: Text(
                                                                'Sepette $qty',
                                                                style: const TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      Expanded(
                                                        child: Text(
                                                          p.name,
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                fontSize: 14,
                                                              ),
                                                        ),
                                                      ),
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              p.price == null
                                                                  ? 'Fiyat belirlenmedi'
                                                                  : formatTry(
                                                                      cents(
                                                                        p.price,
                                                                      ),
                                                                    ),
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                fontSize:
                                                                    p.price ==
                                                                        null
                                                                    ? 11
                                                                    : 14,
                                                                color:
                                                                    p.price ==
                                                                        null
                                                                    ? Colors
                                                                          .deepOrange
                                                                    : dark,
                                                              ),
                                                            ),
                                                          ),
                                                          Icon(
                                                            p.price == null
                                                                ? Icons.block
                                                                : Icons
                                                                      .add_circle_rounded,
                                                            color:
                                                                p.price == null
                                                                ? Colors.grey
                                                                : emerald,
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: c.maxWidth < 900 ? 280 : 320,
                            child: basket(),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
