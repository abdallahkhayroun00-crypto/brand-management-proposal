import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as paths;

import 'pos_logic.dart';
import 'order_reporting.dart';
import 'pos_store.dart';

// Official MEAL GET API ONLY. Never mutates Trendyol Go orders/menu/status.
class TgoCredentials {
  const TgoCredentials(
    this.supplierId,
    this.apiKey,
    this.apiSecret,
    this.email,
  );
  final String supplierId, apiKey, apiSecret, email;
  bool get valid =>
      RegExp(r'^[0-9]+$').hasMatch(supplierId) &&
      apiKey.isNotEmpty &&
      apiSecret.isNotEmpty &&
      email.contains('@');
}

final class _DataBlob extends Struct {
  @Uint32()
  external int length;
  external Pointer<Uint8> bytes;
}

typedef _DpapiNative = Int32 Function(
  Pointer<_DataBlob>, Pointer<Void>, Pointer<_DataBlob>, Pointer<Void>,
  Pointer<Void>, Uint32, Pointer<_DataBlob>,
);
typedef _DpapiDart = int Function(
  Pointer<_DataBlob>, Pointer<Void>, Pointer<_DataBlob>, Pointer<Void>,
  Pointer<Void>, int, Pointer<_DataBlob>,
);

Uint8List _protectForCurrentUser(List<int> data, {required bool decrypt}) {
  if (!Platform.isWindows) {
    throw const FormatException('Windows güvenli kasa gerekli.');
  }
  final crypt32 = DynamicLibrary.open('crypt32.dll');
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final transform = crypt32.lookupFunction<_DpapiNative, _DpapiDart>(
    decrypt ? 'CryptUnprotectData' : 'CryptProtectData',
  );
  final localFree = kernel32.lookupFunction<Pointer<Void> Function(Pointer<Void>),
      Pointer<Void> Function(Pointer<Void>)>('LocalFree');
  final input = calloc<_DataBlob>();
  final output = calloc<_DataBlob>();
  final source = calloc<Uint8>(data.length);
  try {
    source.asTypedList(data.length).setAll(0, data);
    input.ref
      ..length = data.length
      ..bytes = source;
    // Current user scope, with system prompts disabled.
    if (transform(input, nullptr, nullptr, nullptr, nullptr, 1, output) == 0) {
      throw const FormatException('Windows güvenli kasa işlemi başarısız.');
    }
    return Uint8List.fromList(output.ref.bytes.asTypedList(output.ref.length));
  } finally {
    if (output.ref.bytes != nullptr) {
      output.ref.bytes.asTypedList(output.ref.length).fillRange(0, output.ref.length, 0);
      localFree(output.ref.bytes.cast<Void>());
    }
    source.asTypedList(data.length).fillRange(0, data.length, 0);
    calloc.free(source);
    calloc.free(output);
    calloc.free(input);
  }
}

class TgoWindowsVault {
  TgoWindowsVault(String databasePath, {File? credentialFile})
    : file = credentialFile ?? File(
        paths.join(
          Platform.environment['APPDATA'] ?? paths.dirname(databasePath),
          'NohutFalafel',
          'trendyol-go-credentials.dpapi',
        ),
      );
  final File file;

  Future<TgoCredentials?> load() async {
    if (!await file.exists()) return null;
    final ciphertext = base64Decode((await file.readAsString()).trim());
    final clear = _protectForCurrentUser(ciphertext, decrypt: true);
    try {
      final fields = jsonDecode(utf8.decode(clear)) as Map;
      return TgoCredentials(
        fields['supplierId'] as String,
        fields['apiKey'] as String,
        fields['apiSecret'] as String,
        fields['email'] as String,
      );
    } finally {
      clear.fillRange(0, clear.length, 0);
    }
  }

  Future<void> save(TgoCredentials value) async {
    if (!value.valid) {
      throw const FormatException('Satıcı ID, API Key, API Secret ve e-posta gerekli.');
    }
    final clear = utf8.encode(jsonEncode({
      'supplierId': value.supplierId,
      'apiKey': value.apiKey,
      'apiSecret': value.apiSecret,
      'email': value.email,
    }));
    final String encrypted;
    try {
      encrypted = base64Encode(_protectForCurrentUser(clear, decrypt: false));
    } finally {
      clear.fillRange(0, clear.length, 0);
    }
    await file.parent.create(recursive: true);
    final staging = await file.parent.createTemp('.trendyol-go-');
    try {
      final pending = File(paths.join(staging.path, 'credentials.dpapi'));
      await pending.writeAsString(encrypted, flush: true);
      await pending.rename(file.path);
    } finally {
      await staging.delete(recursive: true);
    }
  }
}

int tgoCents(Object? v) =>
    ((v is num ? v : num.tryParse('$v') ?? 0) * 100).round();
String tgoTime(Object? v) {
  final n = v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  return n <= 0
      ? DateTime.now().toUtc().toIso8601String()
      : DateTime.fromMillisecondsSinceEpoch(n, isUtc: true).toIso8601String();
}

List<Json> tgoOrders(Json s) => asMaps(s['trendyolGoOrders']);

Iterable<Json> mutableTgoOrders(Json state) {
  final orders = state['trendyolGoOrders'];
  return orders is List ? orders.whereType<Json>() : const <Json>[];
}

/// Only fully delivered, non-test packages count as completed sales.
bool tgoCountsAsSale(Json o) =>
    o['testPackage'] != true && o['status'] == 'Delivered';
Json normalizeTgoPackage(Json p) {
  final id = '${p['id'] ?? ''}',
      number = '${p['orderNumber'] ?? p['orderId'] ?? ''}';
  if (id.isEmpty || number.isEmpty)
    throw const FormatException('Geçersiz platform paketi.');
  final lines = <Json>[];
  for (final l in asMaps(p['lines'])) {
    final items = asMaps(l['items']);
    final qty = items.isEmpty
        ? 1
        : items.where((e) => e['isCancelled'] != true).length;
    if (qty <= 0) continue;
    lines.add({
      'name': '${l['name'] ?? ''}',
      'qty': qty,
      'unitPriceCents': tgoCents(l['unitSellingPrice'] ?? l['price']),
      'options': [
        for (final m in asMaps(l['modifierProducts'])) '${m['name'] ?? ''}',
      ],
    });
  }
  final payment = p['payment'] is Map
      ? p['payment'] as Map
      : <String, dynamic>{};
  return {
    'source': 'Trendyol Go',
    'supplierId': '${p['supplierId'] ?? ''}',
    'storeId': '${p['storeId'] ?? ''}',
    'packageId': id,
    'orderNumber': number,
    'orderCode': '${p['orderCode'] ?? ''}',
    'status': '${p['packageStatus'] ?? ''}',
    'createdAt': tgoTime(p['packageCreationDate']),
    'modifiedAt': tgoTime(
      p['packageModificationDate'] ?? p['lastModifiedDate'],
    ),
    'totalCents': tgoCents(p['totalPrice']),
    'paymentType': '${payment['paymentType'] ?? ''}',
    'customerNote': '${p['customerNote'] ?? ''}',
    'cancelReason': '${p['cancelInfo'] is Map ? (p['cancelInfo'] as Map)['reason'] ?? '' : ''}',
    'courierNearby': p['isCourierNearby'] == true,
    if (p['estimatedPickupTimeMin'] is num && (p['estimatedPickupTimeMin'] as num) > 0)
      'courierEtaFrom': tgoTime(p['estimatedPickupTimeMin']),
    if (p['estimatedPickupTimeMax'] is num && (p['estimatedPickupTimeMax'] as num) > 0)
      'courierEtaTo': tgoTime(p['estimatedPickupTimeMax']),
    'pickup': p['storePickupSelected'] == true,
    'testPackage': p['testPackage'] == true,
    'lines': lines,
  };
}

String tgoOrderKey(Json order) =>
    '${order['supplierId']}:${order['storeId']}:${order['orderNumber']}';

bool tgoKitchenActive(Json order) =>
    order['testPackage'] != true &&
    const ['Created', 'Picking', 'Invoiced'].contains(order['status']);

String tgoKitchenTicket(Json order) {
  final note = '${order['customerNote'] ?? ''}'.trim();
  return [
    'TRENDYOL GO / MUTFAK',
    'Sipariş: ${order['orderNumber']}',
    if ('${order['orderCode'] ?? ''}'.isNotEmpty) 'Kod: ${order['orderCode']}',
    istanbulStamp(order['createdAt']),
    order['pickup'] == true ? 'Gel-Al' : 'Paket Servis',
    '------------------------',
    for (final line in asMaps(order['lines'])) ...[
      '${line['qty']} × ${line['name']}',
      if (line['options'] case final List options when options.isNotEmpty)
        '  ${options.join(', ')}',
    ],
    if (note.isNotEmpty) 'Not: $note',
  ].join('\n');
}

class TrendyolGoReadonly extends ChangeNotifier {
  TrendyolGoReadonly(this.store, {this.onNewOrders})
    : vault = TgoWindowsVault(store.filePath);

  final void Function(List<Json>)? onNewOrders;
  static const liveSyncEnabled = bool.fromEnvironment(
    'NOHUT_TRENDYOL_LIVE_SYNC',
    defaultValue: true,
  );
  static const pausedStatus = 'Senkronizasyon geçici olarak kapalı';
  final PosStore store;
  final TgoWindowsVault vault;
  TgoCredentials? credentials;
  Timer? _timer;
  bool syncing = false, _closed = false;
  String status = liveSyncEnabled ? 'Bağlı değil' : pausedStatus;
  String lastSync = '', error = '';
  Future<void> start() async {
    try {
      credentials = await vault.load();
      if (liveSyncEnabled) {
        status = credentials == null ? 'API bilgileri bekleniyor' : 'Hazır';
      }
    } catch (_) {
      status = 'Güvenli kasa okunamadı';
    }
    if (_closed) return;
    notifyListeners();
    if (!liveSyncEnabled) return;
    if (credentials?.valid == true) unawaited(sync());
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (credentials?.valid == true) unawaited(sync());
    });
  }

  Future<void> save(TgoCredentials c) async {
    await vault.save(c);
    credentials = c;
    status = liveSyncEnabled ? 'Kaydedildi' : pausedStatus;
    error = '';
    if (_closed) return;
    notifyListeners();
    if (liveSyncEnabled) unawaited(sync());
  }

  Future<HttpClientRequest> _authorizedGet(
    HttpClient client, Uri uri, TgoCredentials account,
  ) async {
    final request = await client.getUrl(uri);
    request.followRedirects = false;
    final auth = base64Encode(utf8.encode('${account.apiKey}:${account.apiSecret}'));
    request.headers
      ..set(HttpHeaders.authorizationHeader, 'Basic $auth')
      ..set(HttpHeaders.userAgentHeader, '${account.supplierId} - SelfIntegration')
      ..set('x-agentname', 'NohutFalafelPOS')
      ..set('x-executor-user', account.email)
      ..set(HttpHeaders.acceptHeader, 'application/json');
    return request;
  }

  Future<({List<Json> reviews, bool hasNextPage})> readReviews(
    String storeId, int page,
  ) async {
    final account = credentials;
    if (!liveSyncEnabled || account == null || !account.valid) {
      throw const FormatException('Önce Trendyol Go API bilgilerini kaydedin.');
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(storeId)) {
      throw const FormatException('Geçerli bir şube ID girin.');
    }
    final uri = Uri(
      scheme: 'https', host: 'api.tgoapis.com',
      pathSegments: [
        'integrator', 'review', 'meal', 'suppliers', account.supplierId,
        'stores', storeId, 'reviews', 'filter',
      ],
      queryParameters: {'page': '$page', 'size': '20'},
    );
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await _authorizedGet(client, uri, account);
      final response = await request.close().timeout(const Duration(seconds: 20));
      final body = await utf8.decoder.bind(response).join().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode == 404 ||
          response.statusCode == 403 && body.contains('endpoint.not-available.error')) {
        throw const FormatException(
          'Bu şube için yorum servisi kullanılamıyor. Yorumları GO Yemek panelinden kontrol edin.',
        );
      }
      if (response.statusCode != 200) {
        throw FormatException('Trendyol yorum servisi HTTP ${response.statusCode}.');
      }
      final payload = jsonDecode(body);
      final List items;
      if (payload is List) {
        items = payload;
      } else if (payload is Map && payload['content'] is List) {
        items = payload['content'] as List;
      } else if (payload is Map && payload['reviewId'] != null) {
        items = [payload];
      } else {
        throw const FormatException('Yorum servisi beklenmeyen bir yanıt verdi.');
      }
      final pages = payload is Map ? payload['totalPages'] : null;
      return (
        reviews: items.whereType<Map>().map(Json.from).toList(),
        hasNextPage: pages is num ? page + 1 < pages : items.length == 20,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> sync() async {
    if (!liveSyncEnabled || _closed || syncing || credentials?.valid != true) return;
    syncing = true;
    status = 'Senkronize ediliyor';
    error = '';
    notifyListeners();
    try {
      final c = credentials!, meta = store.read().data['tgoSyncInfo'];
      final last = meta is Map
          ? DateTime.tryParse('${meta['lastSync'] ?? ''}')
          : null;
      final end = DateTime.now().toUtc();
      final start = end.subtract(
        last == null ? const Duration(days: 7) : const Duration(hours: 24),
      );
      final fresh = <Json>[];
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12);
      try {
        for (var page = 0; page < 10; page++) {
          final uri = Uri.https(
            'api.tgoapis.com',
            '/integrator/order/meal/suppliers/' + c.supplierId + '/packages',
            {
              'page': '$page',
              'size': '50',
              'packageModificationStartDate': '${start.millisecondsSinceEpoch}',
              'packageModificationEndDate': '${end.millisecondsSinceEpoch}',
            },
          );
          final req = await _authorizedGet(client, uri, c);
          final res = await req.close().timeout(const Duration(seconds: 20));
          if (res.statusCode != 200) {
            throw FormatException('Trendyol API HTTP ${res.statusCode}');
          }
          final payload = await utf8.decoder.bind(res).join().timeout(
            const Duration(seconds: 20),
          );
          final result = jsonDecode(payload);
          if (result is! Map || result['content'] is! List) {
            throw const FormatException('Sipariş yanıtı geçersiz.');
          }
          final packages = result['content'] as List;
          for (final raw in packages) {
            if (raw is Map) fresh.add(normalizeTgoPackage(Json.from(raw)));
          }
          final pages = (result['totalPages'] as num?)?.toInt();
          if (pages != null ? page + 1 >= pages : packages.length < 50) break;
          if (page == 9)
            throw const FormatException('API sayfa sınırı; veri kısmi.');
        }
      } finally {
        client.close(force: true);
      }
      if (_closed) return;
      var saved = false;
      var newOrders = <Json>[];
      for (var i = 0; i < 4 && !saved; i++) {
        final snapshot = store.read(), next = copyJson(snapshot.data);
        final merged = {for (final o in tgoOrders(next)) tgoOrderKey(o): o};
        final previouslyKnown = merged.keys.toSet();
        final sameAccount = meta is Map && meta['supplierId'] == c.supplierId;
        final autoKitchen = next['settings']?['tgoAutoKitchen'] == true;
        for (final o in fresh) {
          final key = tgoOrderKey(o);
          final prior = merged[key];
          // Do not allocate a different display number when platform status changes.
          merged[key] = {
            ...o,
            if (prior?['dailyNumber'] is int) 'dailyNumber': prior!['dailyNumber'],
            if (prior?['numberDay'] is String) 'numberDay': prior!['numberDay'],
            if (prior?['kitchenPrintState'] is String)
              'kitchenPrintState': prior!['kitchenPrintState'],
          };
        }
        newOrders = [
          if (last != null && sameAccount)
            for (final entry in merged.entries)
              if (!previouslyKnown.contains(entry.key) &&
                  tgoKitchenActive(entry.value) &&
                  onIstanbulDay(entry.value['createdAt'], istanbulDay(end)))
                entry.value,
        ];
        if (autoKitchen) {
          for (final order in newOrders) {
            order['kitchenPrintState'] = 'Bekliyor';
          }
        }
        next['trendyolGoOrders'] = merged.values.toList();
        assignDailyNumbers(next);
        next['tgoSyncInfo'] = {
          'supplierId': c.supplierId,
          'lastSync': end.toIso8601String(),
        };
        saved = store.replace(next, snapshot.revision).ok;
      }
      if (!saved)
        throw const FormatException('Veritabanı güncellemesi çakıştı.');
      lastSync = DateTime.now().toLocal().toIso8601String();
      status = 'Bağlı · Salt okunur';
      if (newOrders.isNotEmpty) onNewOrders?.call(newOrders);
    } on FormatException catch (e) {
      error = e.message;
      status = 'Bağlantı hatası';
    } catch (_) {
      error = 'Ağ veya yetki hatası. Ayarları kontrol edin.';
      status = 'Bağlantı hatası';
    } finally {
      syncing = false;
      if (!_closed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _closed = true;
    _timer?.cancel();
    super.dispose();
  }
}
