import 'order_reporting.dart';
import 'order_actions.dart';
import 'product_customization.dart';
import 'service_metrics.dart';
import 'simple_settings.dart';
import 'trendyol_go_readonly.dart';
import 'trendyol_go_ui.dart';
import 'sales_reports.dart';
import 'order_alerts.dart';
import 'card_terminal.dart';

import 'dart:async';

import 'receipt_printer.dart';
import 'qr_menu_sync.dart';

import 'dart:convert';
import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'brand.dart';
import 'payment_dialog.dart';
import 'floor_plan.dart';
import 'lan_server.dart';
import 'pos_logic.dart';
import 'campaign_menu.dart';
import 'pos_store.dart';
import 'operations.dart';
import 'operations_ui.dart';
import 'platform_ui.dart';
import 'platform_workflows.dart';

part 'order_composer.dart';

const dark = Color(0xff123e30);
const cream = Color(0xfff6f2e7);
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
    this.active = true,
    this.image,
    this.descriptionTr,
    this.displayNameAr,
    this.displayNameEn,
    this.campaignData,
  });
  final Json? campaignData;
  final int id;
  final String name;
  final String category;
  final double? price;
  final bool active;
  final String? image, descriptionTr, displayNameAr, displayNameEn;
}

class OrderRequest {
  const OrderRequest({
    required this.source,
    required this.table,
    required this.pickupChannel,
    required this.lines,
    this.customer = const {},
    this.expectedTableOrderId,
  });
  final String source;
  final int? table;
  final String pickupChannel;
  final List<Json> lines;
  final Json customer;
  final int? expectedTableOrderId;
}

class NohutFalafelApp extends StatelessWidget {
  const NohutFalafelApp({
    super.key,
    this.databaseFile,
    this.startServer = true,
    this.inposGateway,
  });
  final InposGateway? inposGateway;
  final String? databaseFile;
  final bool startServer;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Nohut Falafel · Yönetici Paneli',
    theme: NohutBrand.theme(),
    home: ManagerDesktop(
      databaseFile: databaseFile,
      startServer: startServer,
      inposGateway: inposGateway,
    ),
  );
}

class ManagerDesktop extends StatefulWidget {
  const ManagerDesktop({
    super.key,
    this.databaseFile,
    this.startServer = true,
    this.inposGateway,
  });
  final InposGateway? inposGateway;
  final String? databaseFile;
  final bool startServer;
  @override
  State<ManagerDesktop> createState() => _ManagerDesktopState();
}

class _ManagerDesktopState extends State<ManagerDesktop> {
  late final PosStore store;
  late final InposPayments inpos;
  bool terminalBusy = false;
  late final ReceiptPrinter receiptPrinter;
  late final PosLanServer lan;
  late final QrMenuAutoSync qrSync;
  late final TrendyolGoReadonly tgo;
  Timer? _midnightTimer;
  Timer? _serviceTimer;
  final Set<String> seenNotices = {};
  Json? latestNotice;
  bool orderModalOpen = false;
  String businessDay = istanbulDay(DateTime.now());
  List<Product> menu = const [];
  String page = 'dashboard';
  String localView = 'plan';
  int? selectedTable, selectedOrder;
  bool floorEditing = false;
  Map<int, Rect> draftFloor = {...floorDefaults};
  String orderFilter = 'Tümü';
  String orderSearch = '',
      orderStatus = '',
      orderStaff = '',
      orderFrom = istanbulDay(DateTime.now()),
      orderTo = istanbulDay(DateTime.now());

  static const sections = [
    ('dashboard', Icons.dashboard_outlined, 'Genel Bakış'),
    ('tables', Icons.table_restaurant_outlined, 'Masalar & Siparişler'),
    ('online', Icons.delivery_dining_outlined, 'Online Siparişler'),
    ('reviews', Icons.star_outline, 'Geri Bildirimler'),
    ('payments', Icons.point_of_sale_outlined, 'Kasa & Ödemeler'),
    ('reports', Icons.bar_chart_outlined, 'Raporlar'),
    ('settings', Icons.settings_outlined, 'Ayarlar'),
  ];

  @override
  void initState() {
    super.initState();
    store = PosStore(databaseFile: widget.databaseFile);
    final initial = store.read(), migrated = copyJson(initial.data);
    final settings =
        migrated.putIfAbsent('settings', () => <String, dynamic>{}) as Map;
    settings['receiptPolicy'] = 'onPayment';
    settings['autoPrint'] = false;
    store.replace(migrated, initial.revision);
    inpos = InposPayments(store, widget.inposGateway ?? UnavailableInpos());
    lan = PosLanServer(store);
    receiptPrinter = ReceiptPrinter(store);
    qrSync = QrMenuAutoSync(store);
    tgo = TrendyolGoReadonly(store, onNewOrders: (orders) {
      if (!mounted) return;
      final message = orders.length == 1
          ? "Trendyol Go · Yeni sipariş ${orders.single['orderNumber']}"
          : 'Trendyol Go · ${orders.length} yeni sipariş';
      _notify(message);
      if (store.read().data['settings']?['soundAlerts'] != false) {
        unawaited(playOrderAlert());
      }
    });
    if (widget.startServer) unawaited(tgo.start());
    _scheduleIstanbulMidnight();
    _serviceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    seenNotices.addAll(
      asMaps(store.read().data['staffNotices']).map((n) => '${n['id']}'),
    );
    store.addListener(_staffActivity);
    // Migration completes before the print worker can inspect old jobs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Menu initialization precedes staff order acceptance.
      unawaited(_startLan());
    });
  }

  /// Rolls daily dashboard and report filters over at 00:00 Europe/Istanbul,
  /// without deleting persisted orders, payments, or any unpaid table.
  void _scheduleIstanbulMidnight() {
    _midnightTimer?.cancel();
    final now = DateTime.now().toUtc();
    final midnight = nextIstanbulMidnightUtc(now);
    final delay = midnight.difference(now) + const Duration(milliseconds: 100);
    _midnightTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {
        businessDay = istanbulDay(DateTime.now());
        // Default order list begins with only the new day's orders.
        // All prior records remain available through the date filters.
        orderFrom = businessDay;
        orderTo = businessDay;
      });
      _scheduleIstanbulMidnight();
    });
  }

  Future<void> _startLan() async {
    await _loadMenu();
    if (mounted && widget.startServer) {
      try {
        await lan.start();
      } catch (e) {
        _notify('Yerel sunucu başlatılamadı: $e', error: true);
      }
      if (mounted) qrSync.start();
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
      // Safe first-upgrade fallback: do not show legacy Şambali ID 32
      // before the first website sync. An explicit CMS active:true restores it.
      final rawLocalMenu = next['localMenu'];
      if (rawLocalMenu is List) {
        for (final product in rawLocalMenu.whereType<Map>()) {
          if (product['id'] == 32 && product['active'] == null) {
            product['active'] = false;
          }
        }
      }
      // Keep intentional local 'not for sale' (null) prices intact.
      // The website sync supplies published prices when enabled.
      final printerSettings =
          next.putIfAbsent('settings', () => <String, dynamic>{}) as Map;
      printerSettings['receiptPolicy'] = 'onPayment';
      printerSettings['autoPrint'] = false;
      printerSettings['printerModel'] = 'XP-237B';
      if (printerSettings['receiptLayoutVersion'] != 2) {
        printerSettings['paperWidthMm'] = 56;
        printerSettings['receiptLayoutVersion'] = 2;
      }
      printerSettings.putIfAbsent('receiptMarginMm', () => 4);
      printerSettings.putIfAbsent('receiptOffsetMm', () => 0);
      printerSettings.putIfAbsent('receiptLogoMm', () => 18);
      printerSettings.putIfAbsent('printableWidthMm', () => 48);
      printerSettings['receiptScale'] = 'actual';
      if ('${printerSettings['printerName'] ?? ''}'.trim().isEmpty) {
        printerSettings['printerName'] = 'XP-237B';
      }
      printerSettings.putIfAbsent('autoPrint', () => true);
      printerSettings.putIfAbsent(
        'autoPrintEnabledAt',
        () => DateTime.now().toUtc().toIso8601String(),
      );
      seedPlatformMenu(next, asMaps(next['localMenu']));
      store.replace(next, snap.revision);
      receiptPrinter.start();
      if (mounted) setState(() => menu = products);
    } catch (e) {
      _notify('Menü dosyası okunamadı: $e', error: true);
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _serviceTimer?.cancel();
    tgo.dispose();
    qrSync.dispose();
    receiptPrinter.dispose();
    lan.dispose();
    store.removeListener(_staffActivity);
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
      if (next == 'online') onlineHistory = false;
      selectedOrder = null;
      if (next != 'tables') selectedTable = null;
      floorEditing = false;
    });
  }

  void _focusOrder(Json order) {
    setState(() {
      selectedOrder = order['id'] as int;
      selectedTable = order['table'] as int?;
      page = 'tables';
      orderFrom = orderTo = '${order['numberDay'] ?? ''}';
      orderFilter = 'Tümü';
      localView = order['source'] == 'Masa' ? 'plan' : 'pickup';
      orderSearch = orderStatus = orderStaff = '';
    });
    _showOrder(order['id'] as int);
  }

  List<Product> _currentProducts() =>
      orderingProducts(store.read().data)
          .where((p) => p['active'] != false)
          .map(
            (p) => Product(
              id: p['id'] as int,
              campaignData: p['campaignId'] != null ? p : null,
              name: p['name'] as String,
              category: p['category'] as String,
              price: (p['price'] as num?)?.toDouble(),
              image: p['image'] as String?,
              descriptionTr: (p['description'] as Map?)?['tr'] as String?,
            ),
          )
          .toList();

  Future<void> _composer({
    int? table,
    int? addToOrder,
    bool pickup = false,
  }) async {
    menu = _currentProducts();
    if (menu.isEmpty) {
      _notify('Menü yükleniyor veya okunamadı.', error: true);
      return;
    }
    int? created;
    bool saveRequest(OrderRequest request) => _edit((data) {
      validateCashierDraft(data, request.lines);
      if (addToOrder != null) {
        addOrderBatch(data, addToOrder, request.lines);
        created = addToOrder;
      } else {
        final occupied = request.source == 'Masa'
            ? activeTable(data, request.table!)
            : null;
        if (request.source == 'Masa' &&
            occupied?['id'] != request.expectedTableOrderId) {
          throw const FormatException(
            'Masa hesabı değişti. Güncel masayı kontrol edip yeniden sipariş açın.',
          );
        }
        if (occupied != null) {
          addOrderBatch(data, occupied['id'] as int, request.lines);
          created = occupied['id'] as int;
          return;
        }
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
    final request = await showDialog<OrderRequest>(
      context: context,
      builder: (ctx) => _OrderComposer(
        products: menu,
        onSubmit: saveRequest,
        refreshProducts: _currentProducts,
        refreshTables: () => {
          for (var n = 1; n <= 5; n++)
            if (activeTable(store.read().data, n) != null)
              n: activeTable(store.read().data, n)!,
        },
        table: table,
        adding: addToOrder != null,
        pickupOnly: pickup,
        tableOrders: {
          for (var n = 1; n <= 5; n++)
            if (activeTable(store.read().data, n) != null)
              n: activeTable(store.read().data, n)!,
        },
      ),
    );
    if (request == null) return;
    if (created != null) {
      final saved = mutableOrder(store.read().data, created!)!;
      _focusOrder(saved);
      _notify('Sipariş #${displayOrderNumber(saved)} kaydedildi.');
    }
  }

  void _staffActivity() {
    if (!mounted) return;
    final incoming = asMaps(store.read().data['staffNotices'])
        .where((n) => !seenNotices.contains('${n['id']}'))
        .toList();
    if (incoming.isEmpty) return;
    seenNotices.addAll(incoming.map((n) => '${n['id']}'));
    setState(() => latestNotice = incoming.last);
    if (store.read().data['settings']?['soundAlerts'] != false &&
        incoming.any(
          (n) => ['Yeni sipariş', 'Ek sipariş'].contains(n['action']),
        ))
      unawaited(playOrderAlert());
  }

  void _onTable(int table) {
    if (floorEditing) return;
    final order = activeTable(store.read().data, table);
    if (order == null) {
      unawaited(_composer(table: table));
      return;
    }
    setState(() {
      selectedTable = table;
      selectedOrder = order['id'] as int;
    });
    _showOrder(order['id'] as int);
  }

  void _showOrder(int id) {
    if (orderModalOpen) return;
    orderModalOpen = true;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 900,
          height: MediaQuery.sizeOf(ctx).height * .88,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Hesap ve Sipariş',
                        style: TextStyle(
                          fontFamily: NohutBrand.headingFont,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kapat',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: AnimatedBuilder(
                    animation: store,
                    builder: (_, __) {
                      final current = mutableOrder(store.read().data, id);
                      return current == null
                          ? const Text('Sipariş bulunamadı')
                          : _orderDetail(current);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() => orderModalOpen = false);
  }

  Future<void> _moveOrder(Json order) async {
    final values = await askFields(
      context,
      'Masayı Taşı',
      [('Yeni masa', '${order['table']}')],
      choices: {
        0: [for (var i = 1; i <= 5; i++) '$i'],
      },
    );
    if (values != null)
      _edit(
        (s) => moveLocalTable(
          s,
          mutableOrder(s, order['id'] as int)!,
          int.parse(values[0]),
          'Kasa (PC)',
        ),
      );
  }

  void _editProducts(Json order) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ürünleri Düzenle'),
        content: SizedBox(
          width: 560,
          child: AnimatedBuilder(
            animation: store,
            builder: (_, __) {
              final current = mutableOrder(
                store.read().data,
                order['id'] as int,
              );
              if (current == null || current['closed'] == true) {
                return const Text('Hesap artık düzenlenemiyor.');
              }
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final line in checkLines(current))
                      ListTile(
                        title: Text(
                          '${line.line['qty']} × ${line.line['name']}',
                        ),
                        subtitle: Text('${line.line['note'] ?? ''}'),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () async {
                          final original = jsonEncode(line.line);
                          final result = await customizeLineDialog(
                            ctx,
                            line.line,
                            description:
                                _currentProducts()
                                    .where(
                                      (p) => p.id == line.line['productId'],
                                    )
                                    .firstOrNull
                                    ?.descriptionTr ??
                                '',
                          );
                          if (result != null)
                            _edit((s) {
                              final target = mutableOrder(
                                s,
                                order['id'] as int,
                              );
                              if (target == null) {
                                throw const FormatException(
                                  'Sipariş artık yok.',
                                );
                              }
                              requireOpen(target);
                              final updated = checkLines(target)
                                  .where((entry) => entry.key == line.key)
                                  .firstOrNull;
                              if (updated == null ||
                                  jsonEncode(updated.line) != original) {
                                throw const FormatException(
                                  'Ürün başka bir cihazda değişti. Güncel satırı tekrar açın.',
                                );
                              }
                              editLocalLine(
                                target,
                                line.key,
                                result['qty'] as int,
                                '${result['note']}',
                                (result['removed'] as List).cast<String>(),
                                'Kasa (PC)',
                                adjustmentCents:
                                    result['adjustmentCents'] as int,
                                components: result['components'],
                              );
                            });
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectProductsToPay(Json order) async {
    final lines = checkLines(order)
        .where((line) => line.total > allocatedTo(order, line.key))
        .toList();
    if (lines.isEmpty) return;
    final shares = <String, int>{};
    final selected = await showDialog<Map<String, int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, change) {
          int left(CheckLine line) => line.total - allocatedTo(order, line.key);
          final total = shares.values.fold<int>(0, (a, b) => a + b);
          return AlertDialog(
            title: const Text('Ürün seçerek öde'),
            content: SizedBox(
              width: 480,
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final line in lines) ...[
                    CheckboxListTile(
                      value: shares.containsKey(line.key),
                      title: Text('${line.line['name']}'),
                      subtitle: Text('Dağıtılmamış ${formatTry(left(line))}'),
                      onChanged: (value) => change(() {
                        if (value == true) {
                          shares[line.key] = min(
                            left(line),
                            cents(line.line['price']),
                          );
                        } else {
                          shares.remove(line.key);
                        }
                      }),
                    ),
                    if (shares.containsKey(line.key))
                      ListTile(
                        title: Text(formatTry(shares[line.key]!)),
                        trailing: TextButton(
                          child: const Text('Adet / pay'),
                          onPressed: () async {
                            final result = await askFields(
                              context,
                              'Adet / pay',
                              [
                                (
                                  'Adet (ör. 1 veya 0,5)',
                                  (shares[line.key]! /
                                          cents(line.line['price']))
                                      .toStringAsFixed(3),
                                ),
                              ],
                            );
                            if (result == null || !context.mounted) return;
                            final units = double.tryParse(
                              result.first.replaceAll(',', '.'),
                            );
                            if (units == null ||
                                !units.isFinite ||
                                units <= 0 ||
                                units > line.line['qty'])
                              return;
                            final value = (cents(line.line['price']) * units)
                                .round();
                            if (value <= 0 || value > left(line)) return;
                            change(() => shares[line.key] = value);
                          },
                        ),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Vazgeç'),
              ),
              TextButton(
                onPressed: () => change(() {
                  for (final line in lines) {
                    shares[line.key] = left(line);
                  }
                }),
                child: const Text('Dağıtılmamış ürünleri seç'),
              ),
              FilledButton(
                onPressed: total == 0 || total > orderDueCents(order)
                    ? null
                    : () => Navigator.pop(
                        dialogContext,
                        Map<String, int>.of(shares),
                      ),
                child: Text('Öde · ${formatTry(total)}'),
              ),
            ],
          );
        },
      ),
    );
    if (selected != null && mounted) await _pay(order, productShares: selected);
  }

  Future<void> _pay(
    Json order, {
    int? guestId,
    String? guestName,
    int? maximumCents,
    Map<String, int>? productShares,
  }) async {
    if (order['source'] != 'Masa' && order['source'] != 'Gel-Al') return;
    final due =
        productShares?.values.fold<int>(0, (sum, value) => sum + value) ??
        maximumCents ??
        orderDueCents(order);
    final paymentSnapshot = jsonEncode(order);
    if (due <= 0) {
      _notify('Bu hesapta kalan ödeme bulunmuyor.');
      return;
    }
    final result = await showDialog<(int, String, int?, int?)>(
      context: context,
      builder: (ctx) => PaymentEntryDialog(
        dueCents: due,
        inposReady:
            inpos.gateway.ready && guestId == null && productShares == null,
        fixedAmount: productShares != null,
        orderNumber: displayOrderNumber(order),
        guestName: guestName ?? '',
      ),
    );
    if (!mounted) return;
    if (result == null) return;
    final (amountCents, methodName, receivedCents, mixedReceived) = result;
    if (methodName == 'inPOS m530') {
      if (terminalBusy) return;
      terminalBusy = true;
      _notify('inPOS sonucu bekleniyor; kartı cihazda okutun.');
      try {
        final reply = await inpos.pay(
          order['id'] as int,
          amountCents,
          'pos_${DateTime.now().microsecondsSinceEpoch}',
        );
        if (!mounted) return;
        if (reply.status == TerminalStatus.approved) {
          _notify('inPOS ödemesi onaylandı');
          await _offerReceipt(order['id'] as int);
        } else
          _notify(
            reply.status == TerminalStatus.unknown
                ? 'Sonuç belirsiz. Tekrar tahsil etmeyin; işlemi sorgulayın.'
                : 'inPOS: ${reply.status.name}',
            error: true,
          );
      } catch (e) {
        if (mounted) _notify('$e', error: true);
      } finally {
        terminalBusy = false;
      }
      return;
    }
    final confirmed = await confirmAction(
      context,
      'Ödemeyi Onayla',
      'Sipariş #${displayOrderNumber(order)} · ${guestName ?? ''}\nTutar: ${formatTry(amountCents)}\nYöntem: $methodName\n'
          '${methodName == 'Karışık'
              ? 'Nakit: ${formatTry(receivedCents!)} · Kart: ${formatTry(amountCents - receivedCents)}. Terminalde kart tahsilatını doğrulayın.'
              : receivedCents == null
              ? 'Banka terminalinde başarılı tahsilatı doğrulayın. Bu kayıt banka işlemi başlatmaz.'
              : 'Alınan: ${formatTry(receivedCents)} · Para üstü: ${formatTry(receivedCents - amountCents)}'}',
      confirm: methodName == 'Karışık'
          ? 'Nakit ve Kart Onaylandı · Kaydet'
          : methodName == 'Kart'
          ? 'Terminalde Onaylandı · Kaydet'
          : 'Nakdi Aldım · Kaydet',
    );
    if (!confirmed || !mounted) return;
    String? receipt;
    final ok = _edit((data) {
      final target = mutableOrder(data, order['id'] as int);
      if (target == null) throw const FormatException('Sipariş bulunamadı');
      if (guestId != null && amountCents > (maximumCents ?? 0)) {
        throw const FormatException('Kişi bakiyesi aşıldı');
      }
      if (jsonEncode(target) != paymentSnapshot) {
        throw const FormatException('Hesap değişti. Ödemeyi tekrar açın.');
      }
      if (productShares != null) {
        receipt = recordProductPayment(
          target,
          productShares,
          amountCents,
          methodName,
          cashCents: methodName == 'Karışık' ? receivedCents : null,
          receivedCents: methodName == 'Karışık'
              ? mixedReceived
              : receivedCents,
        );
      } else if (methodName == 'Karışık') {
        recordMixedPayment(
          target,
          amountCents,
          receivedCents!,
          guestId: guestId,
          receivedCents: mixedReceived,
        );
      } else
        recordPayment(
          target,
          amountCents,
          methodName,
          receivedCents: receivedCents,
          guestId: guestId,
        );
      finishPickupIfSettled(target);
      if (guestId != null) {
        final payments = target['payments'] as List;
        final latest = payments.last as Map;
        latest['guestCheckId'] = guestId;
        latest['guestName'] = guestName;
      }
    });
    if (ok) {
      _notify('Ödeme kaydedildi · ${formatTry(amountCents)}');
      if (!mounted) return;
      await _offerReceipt(order['id'] as int, receipt: receipt);
    }
  }

  Future<void> _offerReceipt(int orderId, {String? receipt}) async {
    if (!mounted) return;
    final print = await confirmAction(
      context,
      'Fiş yazdırılsın mı?',
      'Bu ödeme için hesap özeti yazdırabilirsiniz. Mali fiş inPOS cihazından alınır.',
      confirm: 'Evet · Yazdır',
    );
    if (print)
      _edit(
        (data) => queuePaymentReceipt(
          data,
          mutableOrder(data, orderId)!,
          requestId: 'pc_${DateTime.now().microsecondsSinceEpoch}',
          receipt: receipt,
        ),
      );
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
    animation: Listenable.merge([store, lan, tgo]),
    builder: (ctx, _) {
      final data = store.read().data;
      final width = MediaQuery.sizeOf(context).width;
      final condensed = width < 1050;
      return Scaffold(
        drawer: condensed ? Drawer(child: _sidebar(false)) : null,
        body: Row(
          children: [
            if (!condensed) SizedBox(width: 235, child: _sidebar(false)),
            Expanded(
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    height: 76,
                    padding: const EdgeInsets.symmetric(horizontal: 27),
                    child: Row(
                      children: [
                        if (condensed)
                          Builder(
                            builder: (ctx) => IconButton(
                              tooltip: 'Menüyü aç',
                              onPressed: () => Scaffold.of(ctx).openDrawer(),
                              icon: const Icon(Icons.menu),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'NOHUT FALAFEL / YÖNETİCİ',
                                style: TextStyle(
                                  color: Color(0xff526251),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sections.firstWhere((s) => s.$1 == page).$3,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontFamily: NohutBrand.headingFont,
                                  color: NohutBrand.green,
                                  fontWeight: FontWeight.w400,
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
                          lan.running ? 'Personel bağlı' : 'Bağlantı kapalı',
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
                  if (latestNotice != null)
                    MaterialBanner(
                      content: Text(
                        '${latestNotice!['staff']} · ${latestNotice!['action']} · ${latestNotice!['table'] == null ? 'Gel-Al' : 'Masa ${latestNotice!['table']}'}',
                      ),
                      leading: const Icon(
                        Icons.notifications_active,
                        color: dark,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              _showOrder(latestNotice!['orderId'] as int),
                          child: const Text('Siparişi Aç'),
                        ),
                        TextButton(
                          onPressed: () => setState(() => latestNotice = null),
                          child: const Text('Tamam'),
                        ),
                      ],
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
              Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: NohutBrand.cream,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/brand/nohut-logo.webp',
                  width: 46,
                  height: 46,
                  semanticLabel: 'Nohut Falafel',
                ),
              ),
              if (!condensed) ...[
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nohut Falafel',
                        style: TextStyle(
                          fontFamily: NohutBrand.headingFont,
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'İŞLETME PANELİ',
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
                      key: ValueKey('navigation-${item.$1}'),
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
                      onTap: () {
                        if (MediaQuery.sizeOf(context).width < 1050) {
                          Navigator.of(context).pop();
                        }
                        _switch(item.$1);
                      },
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
              'Nohut Falafel · Afiyet olsun',
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'plan', label: Text('Masa Planı')),
                  ButtonSegment(value: 'list', label: Text('Liste')),
                  ButtonSegment(value: 'pickup', label: Text('Gel-Al')),
                ],
                selected: {localView},
                onSelectionChanged: (value) => setState(() {
                  localView = value.single;
                  orderFilter = 'Tümü';
                }),
              ),
            ),
            const SizedBox(height: 16),
            if (localView == 'plan') _tables(db) else _orders(db),
          ],
        );
      case 'online':
        return _online(db);
      case 'reviews':
        return FeedbackPanel(orders: tgoOrders(db), integration: tgo);
      case 'payments':
        return _payments(db);
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
                      fontFamily: NohutBrand.headingFont,
                      fontWeight: FontWeight.w900,
                      color: dark,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff526251),
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
                    color: Color(0xff526251),
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
    final remoteToday = tgoOrders(db)
        .where((o) => onIstanbulDay(o['createdAt'], businessDay))
        .toList();
    final remoteValid = remoteToday
        .where(
          (o) =>
              o['testPackage'] != true &&
              !['Cancelled', 'UnSupplied'].contains(o['status']),
        )
        .toList();
    final remoteSales = remoteToday.where(tgoCountsAsSale).toList();
    final remoteAmount = remoteSales.fold<int>(
      0,
      (sum, o) => sum + (o['totalCents'] as int? ?? 0),
    );
    final todayOrders = orders
        .where(
          (o) =>
              onIstanbulDay(o['createdAt'], businessDay) &&
              o['cancelled'] != true &&
              o['demoRemoteStatus'] != 'Created',
        )
        .toList();
    // Use PAYMENT timestamps, not order creation dates. A table that
    // pays after midnight belongs to the new day's receipts.
    final todayNetReceipts = ledger(db)
        .where(
          (e) =>
              (e.source == 'Masa' || e.source == 'Gel-Al') &&
              onIstanbulDay(e.stamp, businessDay),
        )
        .fold<int>(0, (sum, entry) => sum + entry.amount);
    final active = orders
        .where((o) => o['closed'] != true && o['cancelled'] != true)
        .toList();
    final busy = List.generate(
      5,
      (i) => activeTable(db, i + 1),
    ).where((o) => o != null).length;
    final localReceipts = ledger(db).where(
      (entry) =>
          ['Masa', 'Gel-Al'].contains(entry.source) &&
          onIstanbulDay(entry.stamp, businessDay),
    );
    int receiptsFor(String method) => localReceipts
        .where((entry) => entry.method == method)
        .fold(0, (total, entry) => total + entry.amount);
    final sales = todayOrders
        .where((order) => !isPlatform(order))
        .fold<int>(0, (total, order) => total + orderTotalCents(order));
    final due = active
        .where((order) => !isPlatform(order))
        .fold<int>(0, (total, order) => total + orderDueCents(order));
    final pickups = active.where((order) => order['source'] == 'Gel-Al').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          'Bugün',
          businessDay,
          action: FilledButton.icon(
            onPressed: () => _composer(),
            icon: const Icon(Icons.add),
            label: const Text('Sipariş Al'),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in [
              ('Nakit', receiptsFor('Nakit'), Icons.payments_outlined),
              ('Kart', receiptsFor('Kart'), Icons.credit_card_outlined),
              (
                'Net Tahsilat',
                todayNetReceipts,
                Icons.account_balance_wallet_outlined,
              ),
              ('Satış', sales, Icons.receipt_long_outlined),
              ('Açık Bakiye', due, Icons.pending_actions_outlined),
            ])
              SizedBox(
                width: 184,
                child: _metric(metric.$1, formatTry(metric.$2), metric.$3),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Masa: $busy dolu · ${5 - busy} boş  |  Gel-Al: $pickups açık'),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final staffPanel = StaffMetrics(state: db, day: businessDay);
            final hasPlatformData =
                remoteToday.isNotEmpty || db['tgoSyncInfo'] != null;
            final platformPanel = Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.delivery_dining_outlined,
                          color: NohutBrand.green,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Trendyol Go',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: tgo.status.startsWith('Bağlı ·')
                            ? const Color(0xffe5ebdf)
                            : const Color(0xfff3e8d1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        child: Text(tgo.status),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 18,
                      runSpacing: 10,
                      children: [
                        for (final (label, value) in [
                          ('Sipariş', '${remoteValid.length}'),
                          ('Teslim', '${remoteSales.length}'),
                          ('Tamamlanan Satış', formatTry(remoteAmount)),
                        ])
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasPlatformData ? value : '—',
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  color: NohutBrand.green,
                                ),
                              ),
                              Text(
                                label,
                                style: const TextStyle(color: NohutBrand.muted),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _showTrendyolOrders,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Online Siparişleri Gör'),
                    ),
                  ],
                ),
              ),
            );
            if (constraints.maxWidth < 980) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  staffPanel,
                  const SizedBox(height: 10),
                  platformPanel,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: staffPanel),
                const SizedBox(width: 12),
                Expanded(flex: 4, child: platformPanel),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _tables(Json db) {
    final order = selectedOrder == null
        ? null
        : asMaps(db['orders'])
              .where((o) => o['id'] == selectedOrder)
              .firstOrNull;
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
                  if (!validFloorPlacement(draftFloor)) {
                    _notify(
                      'Masalar çakışamaz ve kapı açık kalmalı.',
                      error: true,
                    );
                    return;
                  }
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
            final next = {
              ...draftFloor,
              n: Rect.fromLTWH(left, top, r.width, r.height),
            };
            if (validFloorPlacement(next)) draftFloor = next;
          }),
        ),
        const SizedBox(height: 17),
        if (order != null && order['source'] == 'Masa')
          OutlinedButton(
            onPressed: () => _showOrder(order['id'] as int),
            child: Text('Masa ${order['table']} · Hesabı Aç'),
          ),
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
                        '${o['numberDay'] ?? ''} · ${closed
                            ? 'Kapalı'
                            : o['source'] == 'Gel-Al' && o['deliveredAt'] != null
                            ? 'Teslim Edildi'
                            : 'Açık'}',
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${line['name'] ?? line['productKey'] ?? 'Ürün'}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if ('${line['note'] ?? ''}'.isNotEmpty)
                            Text('Not: ${line['note']}'),
                          if ((line['removed'] as List? ?? []).isNotEmpty)
                            Text(
                              'Çıkar: ${(line['removed'] as List).join(', ')}',
                            ),
                        ],
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
            if (o['terminalPending'] != null) ...[
              const Text(
                'Terminal sonucu bekleniyor. Yeniden ödeme başlatmayın.',
              ),
              OutlinedButton(
                onPressed: !inpos.gateway.ready || terminalBusy
                    ? null
                    : () async {
                        terminalBusy = true;
                        try {
                          final reply = await inpos.reconcile(
                            '${o['terminalPending']}',
                          );
                          if (mounted) {
                            _notify('inPOS: ${reply.status.name}');
                            if (reply.status == TerminalStatus.approved)
                              await _offerReceipt(id);
                          }
                        } catch (e) {
                          if (mounted) _notify('$e', error: true);
                        } finally {
                          terminalBusy = false;
                        }
                      },
                child: const Text('Terminal Sonucunu Sorgula'),
              ),
            ],
            if (split.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                'Kişi Hesapları',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              for (final guest in split)
                Builder(
                  builder: (context) {
                    final allocated = asMaps(guest['allocations'])
                        .fold<int>(0, (sum, a) => sum + (a['cents'] as int));
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
                  if (orderDueCents(o) > 0 &&
                      checkLines(o)
                          .any((line) => line.total > allocatedTo(o, line.key)))
                    OutlinedButton.icon(
                      onPressed: () => _selectProductsToPay(o),
                      icon: const Icon(Icons.checklist),
                      label: const Text('Ürün seçerek öde'),
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
                  OutlinedButton.icon(
                    onPressed: () => _editProducts(o),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Ürünleri Düzenle'),
                  ),
                  if (o['source'] == 'Masa')
                    OutlinedButton.icon(
                      onPressed: () => _moveOrder(o),
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Masayı Taşı'),
                    ),
                  if (o['source'] == 'Masa' && orderDueCents(o) == 0)
                    OutlinedButton.icon(
                      onPressed: () => _closeTable(o),
                      icon: const Icon(Icons.done_all),
                      label: const Text('Masayı Kapat'),
                    ),
                ],
              ),

            if (!isPlatform(o))
              OutlinedButton.icon(
                onPressed: () async {
                  if (await confirmAction(
                    context,
                    'Siparişi kalıcı sil?',
                    '#${displayOrderNumber(o)} · Toplam ${formatTry(total)} · Tahsilat ${formatTry(paid)}\n'
                        'Sipariş, ödemeleri ve rapor tutarları aktif veritabanından kaldırılır. Son günlük numara yeniden kullanılabilir; diğer numaralar değişmez.',
                    confirm: 'Kalıcı Sil',
                  )) {
                    try {
                      store.deleteOrder(
                        o['id'] as int,
                        store.read().revision,
                        'delete_${DateTime.now().microsecondsSinceEpoch}',
                      );
                      if (mounted) Navigator.of(context).pop();
                    } catch (e) {
                      _notify('$e', error: true);
                    }
                  }
                },
                icon: const Icon(Icons.delete_forever),
                label: const Text('Kalıcı Sil'),
              ),
            OrderOperations(
              printSettings: store.read().data['settings'] as Map?,
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
    final all = asMaps(db['orders']).reversed
        .where(
          (o) =>
              !isPlatform(o) &&
              (localView != 'pickup' || o['source'] == 'Gel-Al'),
        )
        .toList();
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
      final staff = asMaps(o['batches'])
          .map((b) => b['staff'])
          .join(' ')
          .toLowerCase();
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
              o['source'] == 'Gel-Al' &&
                  orderStatus == 'Teslim Edildi' &&
                  o['deliveredAt'] != null) &&
          (orderFrom.isEmpty || date.compareTo(orderFrom) >= 0) &&
          (orderTo.isEmpty || date.compareTo(orderTo) <= 0);
    }).toList();
    final remoteFiltered = tgoOrders(db).where((o) {
      if (localView == 'pickup') return false;
      final day = '${o['numberDay'] ?? ''}';
      final search =
          '${o['orderNumber']} ${displayOrderNumber(o)} ${o['customerNote']} ${o['lines']}'
              .toLowerCase();
      return (orderFilter == 'Tümü' || orderFilter == 'Trendyol Go') &&
          (orderStaff.isEmpty) &&
          search.contains(orderSearch.toLowerCase()) &&
          (orderFrom.isEmpty || day.compareTo(orderFrom) >= 0) &&
          (orderTo.isEmpty || day.compareTo(orderTo) <= 0) &&
          (orderStatus.isEmpty || o['status'] == orderStatus);
    }).toList();
    final combined = <Json>[...filtered, ...remoteFiltered]
      ..sort((a, b) {
        final day = '${b['numberDay'] ?? ''}'.compareTo(
          '${a['numberDay'] ?? ''}',
        );
        if (day != 0) return day;
        return (b['dailyNumber'] as int? ?? 0).compareTo(
          a['dailyNumber'] as int? ?? 0,
        );
      });
    bool isRemote(Json order) => order['source'] == 'Trendyol Go';
    int total(Json order) => isRemote(order)
        ? order['totalCents'] as int? ?? 0
        : orderTotalCents(order);
    String remaining(Json order) =>
        isRemote(order) ? '—' : formatTry(orderDueCents(order));
    String orderStamp(Json order) => isRemote(order)
        ? '${order['numberDay']} · #${order['orderNumber']} · ${order['status']}'
        : '${order['numberDay'] ?? ''} · ${order['created'] ?? ''}';
    void openOrder(Json order) {
      if (isRemote(order)) {
        _showTrendyolOrders();
      } else {
        _showOrder(order['id'] as int);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          'Siparişler',
          'Varsayılan: Bugün ($businessDay). Geçmiş siparişler tarih filtresiyle açılır.',
          action: FilledButton.icon(
            onPressed: () => _composer(pickup: localView == 'pickup'),
            icon: const Icon(Icons.add),
            label: const Text('Sipariş Al'),
          ),
        ),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Sipariş, masa, müşteri veya ürün ara',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => orderSearch = v),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final status in [
              '',
              'Kalan',
              'Ödendi',
              if (localView == 'pickup') 'Teslim Edildi',
              'Kapalı',
            ])
              ChoiceChip(
                label: Text(status.isEmpty ? 'Tümü' : status),
                selected: orderStatus == status,
                onSelected: (_) => setState(() => orderStatus = status),
              ),
            TextButton(
              onPressed: () => setState(() {
                orderFrom = '';
                orderTo = '';
              }),
              child: const Text('Tüm Tarihler'),
            ),
          ],
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
              if (v.skip(3).any((d) => d.isNotEmpty && !validBusinessDate(d)) ||
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
          child: Text('Sipariş Filtreleri · ${combined.length} kayıt'),
        ),
        Wrap(
          spacing: 7,
          children: [
            for (final filter in [
              'Tümü',
              'Masa',
              'Gel-Al',
              if (localView != 'pickup') 'Trendyol Go',
            ])
              ChoiceChip(
                label: Text(filter),
                selected: orderFilter == filter,
                onSelected: (_) => setState(() {
                  orderFilter = filter;
                  selectedOrder = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),

        Card(
          child: combined.isEmpty
              ? const ListTile(title: Text('Sipariş bulunamadı'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 690;
                    if (compact) {
                      return Column(
                        children: [
                          for (final o in combined)
                            ListTile(
                              title: Text(
                                '#${displayOrderNumber(o)} · ${o['table'] == null ? o['source'] : "Masa ${o['table']}"}',
                              ),
                              subtitle: Text(orderStamp(o)),
                              trailing: Text(remaining(o)),
                              onTap: () => openOrder(o),
                            ),
                        ],
                      );
                    }
                    return SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        columnSpacing: 14,
                        horizontalMargin: 14,
                        columns: const [
                          DataColumn(label: Text('Sipariş')),
                          DataColumn(label: Text('Masa / Kaynak')),
                          DataColumn(label: Text('Zaman')),
                          DataColumn(numeric: true, label: Text('Toplam')),
                          DataColumn(numeric: true, label: Text('Kalan')),
                          DataColumn(label: Text('İşlem')),
                        ],
                        rows: [
                          for (final o in combined)
                            DataRow(
                              cells: [
                                DataCell(Text('#${displayOrderNumber(o)}')),
                                DataCell(
                                  Text(
                                    o['table'] == null
                                        ? '${o['source']}'
                                        : "Masa ${o['table']}",
                                  ),
                                ),
                                DataCell(Text(orderStamp(o))),
                                DataCell(Text(formatTry(total(o)))),
                                DataCell(Text(remaining(o))),
                                DataCell(
                                  TextButton(
                                    onPressed: () => openOrder(o),
                                    child: Text(
                                      isRemote(o)
                                          ? 'Platform Siparişi'
                                          : 'Hesabı Aç',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Json? platformDemo;
  String onlinePlatform = 'Trendyol Go';
  bool onlineHistory = false;

  void _showTrendyolOrders() => setState(() {
    page = 'online';
    onlinePlatform = 'Trendyol Go';
    onlineHistory = false;
  });

  Widget _online(Json db) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'Trendyol Go',
              label: Text('Trendyol Go'),
              icon: Icon(Icons.delivery_dining_outlined),
            ),
            ButtonSegment(value: 'Yemeksepeti', label: Text('Yemeksepeti')),
            ButtonSegment(value: 'Migros Yemek', label: Text('Migros Yemek')),
          ],
          selected: {onlinePlatform},
          onSelectionChanged: (value) =>
              setState(() => onlinePlatform = value.single),
        ),
        const SizedBox(height: 16),
        if (onlinePlatform == 'Trendyol Go')
          TgoOrdersPanel(
            orders: tgoOrders(db),
            integration: tgo,
            businessDay: businessDay,
            showHistory: onlineHistory,
            onPeriodChanged: () => setState(() => onlineHistory = !onlineHistory),
            autoKitchen: db['settings']?['tgoAutoKitchen'] == true,
            onAutoKitchenChanged: (value) {
              _edit((data) => (data['settings'] as Map)['tgoAutoKitchen'] = value);
            },
            onKitchenPrint: (order) {
              final key = tgoOrderKey(order);
              _edit((data) {
                for (final current in mutableTgoOrders(data)) {
                  if (tgoOrderKey(current) == key &&
                      current['kitchenPrintState'] == null &&
                      tgoKitchenActive(current)) {
                    current['kitchenPrintState'] = 'Bekliyor';
                  }
                }
              });
            },
          )
        else if (onlinePlatform == 'Migros Yemek')
          const MigrosOrdersPanel()
        else ...[
          _notice('Yemeksepeti · Bağlı değil'),
          const SizedBox(height: 12),
          _platformDemo(db),
        ],
      ],
    );
  }

  Widget _platformDemo(Json db) {
    platformDemo ??= {...emptyPosState(), 'localMenu': asMaps(db['localMenu'])};
    seedPlatformMenu(
      platformDemo!,
      asMaps(platformDemo!['localMenu'])
          .where((p) => p['active'] != false)
          .toList(),
    );
    return PlatformPanel(
      state: platformDemo!,
      fixedSource: 'Yemeksepeti',
      edit: (change) {
        try {
          final next = copyJson(platformDemo!);
          change(next);
          PosStore.validate(next);
          setState(() => platformDemo = next);
          return true;
        } catch (e) {
          _notify('$e', error: true);
          return false;
        }
      },
    );
  }

  Widget _payments(Json db) {
    final locals = asMaps(db['orders'])
        .where(
          (o) =>
              (o['source'] == 'Masa' || o['source'] == 'Gel-Al') &&
              o['closed'] != true &&
              o['cancelled'] != true &&
              orderDueCents(o) > 0,
        )
        .toList();
    final totalDue = locals.fold<int>(0, (s, o) => s + orderDueCents(o));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          'Kasa & Ödemeler',
          'Nakit, kart ve kişi hesaplarını tek yerden takip edin.',
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
                    onPressed: () => _focusOrder(o),
                    child: Text('Kalan ${formatTry(orderDueCents(o))}'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _staff(Json db) => StaffPanel(state: db, edit: _edit);

  Widget _reports(Json db) => SalesReports(
    key: ValueKey('daily-reports-$businessDay'),
    state: db,
    edit: _edit,
  );

  Widget _wifi(Json db) {
    final url = lan.staffUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          'Personel Bağlantısı',
          'Telefonları aynı Wi-Fi ağına bağlayın ve personel QR kodunu okutun.',
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
                          Expanded(
                            child: Text(
                              lan.running
                                  ? 'Personel bağlantısı hazır'
                                  : 'Personel bağlantısı kapalı',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
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
                          key: ValueKey(
                            '${lan.selectedIp}:${lan.addresses.join(',')}',
                          ),
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
                              onPressed: lan.starting
                                  ? null
                                  : () => lan.start(),
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
                        '2. Nohut programını açık tutun\n'
                        '3. Personel QR kodunu tarar, adını seçer\n'
                        '4. Siparişler telefon ve kasada birlikte görünür\n'
                        '5. Ödeme ve teslim durumunu aynı hesaptan takip edin',
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
                          color: Color(0xff526251),
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

  Widget _settings(Json db) => SimpleSettings(
    state: db,
    edit: _edit,
    store: store,
    qrSync: qrSync,
    tgoIntegration: tgo,
    staffPanel: _staff(db),
    wifiPanel: _wifi(db),
  );

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
