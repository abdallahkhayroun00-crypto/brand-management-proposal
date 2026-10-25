import 'dart:async';
import 'package:flutter/foundation.dart';
import 'pos_store.dart';
import 'pos_logic.dart';
import 'platform_api.dart';
import 'platform_workflows.dart';
import 'order_actions.dart';

Json normalizeTgoMeal(Json raw, PlatformCredentials c) {
  if ('${raw['storeId']}' != c.field('storeId') ||
      '${raw['supplierId']}' != c.field('supplierId')) {
    throw const FormatException('Farklı restoran paketi reddedildi');
  }
  if (raw['deliveryType'] == 'STORE' && raw['storePickupSelected'] != true) {
    throw const FormatException('Restoran kurye teslimatı kapsam dışında');
  }
  final version = raw['packageModificationDate'] ?? raw['lastModifiedDate'];
  if (version is! int ||
      raw['totalPrice'] is! num ||
      raw['id'] is! String ||
      !remoteStates.contains(raw['packageStatus'])) {
    throw const FormatException('Meal sipariş modeli geçersiz');
  }
  final items = <Json>[];
  for (final line in asMaps(raw['lines'])) {
    final unit = line['unitSellingPrice'] ?? line['price'];
    if (unit is! num || !unit.isFinite || unit < 0) {
      throw const FormatException('Platform fiyatı geçersiz');
    }
    final variants = asMaps(line['modifierProducts']);
    for (final item in asMaps(
      line['items'],
    ).where((i) => i['isCancelled'] != true)) {
      items.add({
        'packageItemId': '${item['packageItemId']}',
        'localId': null,
        'productId': line['productId'],
        'name': line['name'],
        'quantity': 1,
        'unitSellingPrice': unit,
        'modifiers': [for (final m in variants) '${m['name']}'],
        'removed': [
          for (final r in asMaps(line['removedIngredients'])) '${r['name']}',
        ],
        'note': raw['customerNote'] ?? '',
      });
    }
  }
  return {
    'source': 'Trendyol Go',
    'integrationScope': c.scope,
    'packageId': raw['id'],
    'revision': version,
    'status': raw['packageStatus'],
    'createdAt': DateTime.fromMillisecondsSinceEpoch(
      raw['packageCreationDate'] as int? ?? version,
      isUtc: true,
    ).toIso8601String(),
    'orderId': raw['orderId'],
    'orderCode': raw['orderCode'],
    'storePickupSelected': raw['storePickupSelected'] == true,
    'paymentType': raw['payment']?['paymentType'],
    'collection': 'Pending',
    'orderTotal': raw['totalPrice'],
    'pinCode': raw['address']?['pinCode'],
    'callCenterPhone': raw['callCenterPhone'],
    'pickupEtaState': raw['pickupEtaState'],
    'appName': raw['userInformation']?['appName'],
    'items': items,
    'note': raw['customerNote'] ?? '',
  };
}

Json normalizeYsRestaurant(Json raw, PlatformCredentials c, int eventRevision) {
  if (raw['localInfo']?['platformKey'] != c.field('platformKey')) {
    throw const FormatException('Yemeksepeti platform kimliği eşleşmedi');
  }
  final pickup = raw['expeditionType'] == 'pickup';
  if (!pickup && raw['delivery']?['riderPickupTime'] == null) {
    throw const FormatException('Restoran kuryeli teslimat kapsam dışında');
  }
  final items = <Json>[];
  for (final product in asMaps(raw['products'])) {
    final qty = int.tryParse('${product['quantity']}'),
        paid = double.tryParse('${product['paidPrice']}');
    if (qty == null || qty < 1 || paid == null || !paid.isFinite || paid < 0) {
      throw const FormatException('Restoran ürün verisi geçersiz');
    }
    // paidPrice is the source total for this product quantity. Distribute cents
    // exactly; never re-price with a local menu or subtract discounts twice.
    final total = cents(paid);
    for (var i = 0; i < qty; i++) {
      items.add({
        'packageItemId': '${product['id']}:$i',
        'localId': null,
        'name': product['name'],
        'quantity': 1,
        'unitSellingPrice': fromCents(total ~/ qty + (i < total % qty ? 1 : 0)),
        'modifiers': [
          for (final t in asMaps(product['selectedToppings'])) '${t['name']}',
        ],
        'removed': [],
        'note': product['comment'] ?? '',
      });
    }
  }
  final total = double.tryParse('${raw['price']?['grandTotal']}');
  if (total == null ||
      raw['token'] is! String ||
      DateTime.tryParse('${raw['createdAt']}') == null) {
    throw const FormatException('Restoran sipariş modeli geçersiz');
  }
  return {
    'source': 'Yemeksepeti',
    'integrationScope': c.scope,
    'packageId': raw['token'],
    'revision': eventRevision,
    'status': c.values['directApproved'] == true ? 'Created' : 'Picking',
    'createdAt': raw['createdAt'],
    'orderCode': raw['code'],
    'orderTotal': total,
    'storePickupSelected': pickup,
    'collection': raw['payment']?['status'] == 'paid' ? 'Collected' : 'Pending',
    'paymentType': raw['payment']?['type'],
    'items': items,
    'note': raw['comments']?['customerComment'] ?? '',
  };
}

class PlatformRuntime extends ChangeNotifier {
  PlatformRuntime(this.store, this.vault, {ApiTransport? transport})
    : api = RestaurantApi(transport ?? NativeApiTransport());
  final PosStore store;
  final CredentialVault vault;
  final RestaurantApi api;
  final statuses = <String, String>{};
  Timer? timer;
  bool _busy = false, _disposed = false;
  bool edit(void Function(Json) f) {
    final snap = store.read(), next = copyJson(store.read().data);
    f(next);
    return store.replace(next, snap.revision).ok;
  }

  void start() {
    // A crash after a provider accepted but before SQLite commit must not result
    // in an automatic second POST. Require reconciliation for uncertain jobs.
    edit((s) {
      for (final j in orderOperations(
        s,
      ).where((j) => j['status'] == 'Gönderiliyor')) {
        finishOrderAction(
          s,
          '${j['id']}',
          'Belirsiz',
          error: 'Uygulama kapanmış; platformda doğrulayın',
        );
      }
    });
    timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(runOnce()),
    );
    unawaited(runOnce());
  }

  Future<void> testConnection(String source) async {
    try {
      final c = await vault.load(source);
      c.validate();
      if (!c.configured) throw const IntegrationFailure('API bilgileri eksik');
      if (c.mode == 'off') throw const IntegrationFailure('Bağlantı kapalı');
      if (source == 'Trendyol Go') {
        final now = DateTime.now().millisecondsSinceEpoch;
        await api.tgoPage(c, 0, now - 3600000, now);
      } else {
        await api.ysToken(c);
      }
      statuses[source] =
          '${c.mode.toUpperCase()} · API kimlik doğrulaması başarılı; uçtan uca sipariş testi bekliyor';
    } on IntegrationFailure catch (e) {
      statuses[source] = e.message;
    } catch (_) {
      statuses[source] = 'Bağlantı doğrulanamadı; ayarları ve ağı kontrol edin';
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> pollTgo(PlatformCredentials c) async {
    final state = store.read().data;
    final cursor = state['platformCursorScopes']?['Trendyol Go'] == c.scope
        ? (state['platformCursors']?['Trendyol Go'] as int?)
        : null;
    final end = DateTime.now().millisecondsSinceEpoch,
        start = (cursor ?? end - 24 * 3600000) - 60000;
    var page = 0;
    final packets = <Json>[];
    while (true) {
      final response = await api.tgoPage(c, page, start, end);
      if (response.data is! Map ||
          response.data['content'] is! List ||
          response.data['totalPages'] is! int) {
        throw const IntegrationFailure('Meal sayfalama yanıtı geçersiz');
      }
      for (final raw in asMaps(response.data['content'])) {
        packets.add(normalizeTgoMeal(raw, c));
      }
      page++;
      if (page >= (response.data['totalPages'] as int)) break;
      if (page >= 100) {
        throw const IntegrationFailure('Sayfalama sınırı; imleç ilerletilmedi');
      }
    }
    if (_disposed) return;
    edit((s) {
      for (final p in packets) {
        final o = importPlatform(s, p);
        if (o != null) {
          o['integrationMode'] = c.mode;
          o['sourceProgram'] = 'tgo-meal';
        }
      }
      final cursors =
          s.putIfAbsent('platformCursors', () => <String, dynamic>{}) as Map;
      cursors['Trendyol Go'] = end;
      (s.putIfAbsent('platformCursorScopes', () => <String, dynamic>{})
              as Map)['Trendyol Go'] =
          c.scope;
    });
  }

  Future<void> pollYsRelay(PlatformCredentials c) async {
    if (c.field('relayUrl').isEmpty || c.field('relayToken').isEmpty) {
      statuses[c.source] =
          'Webhook gateway ayarlanmamış; sipariş alma bağlı değil';
      return;
    }
    final state = store.read().data;
    final cursor = state['platformCursorScopes']?['Yemeksepeti'] == c.scope
        ? ((state['platformCursors']?['Yemeksepeti'] as int?) ?? 0)
        : 0;
    final url = Uri.parse(c.field('relayUrl'))
        .resolve('/v1/events')
        .replace(
          queryParameters: {
            'after': '$cursor',
            'remoteId': c.field('remoteId'),
          },
        );
    final reply = await api.transport.call(
      'GET',
      url,
      headers: {'Authorization': 'Bearer ${c.field('relayToken')}'},
    );
    checkReply(reply);
    if (reply.data is! Map || reply.data['events'] is! List) {
      throw const IntegrationFailure('Gateway yanıtı geçersiz');
    }
    final events = asMaps(reply.data['events']);
    if (_disposed) return;
    edit((s) {
      var last = cursor;
      for (final event in events) {
        if (event['id'] is! int ||
            (event['id'] as int) <= last ||
            event['remoteId'] != c.field('remoteId')) {
          throw const FormatException(
            'Gateway sıra / restoran kimliği geçersiz',
          );
        }
        if (event['kind'] == 'order') {
          final raw = Map<String, dynamic>.from(event['payload'] as Map);
          final p = normalizeYsRestaurant(raw, c, event['id'] as int);
          final o = importPlatform(s, p);
          if (o != null) {
            o['integrationMode'] = c.mode;
            o['sourceProgram'] = 'ys-restaurant';
            statuses[c.source] =
                '${c.mode.toUpperCase()} · Webhook kuyruğu alındı';
            o['providerRemoteOrderId'] = event['remoteOrderId'];
            o['providerCallbacks'] = raw['callbackUrls'];
            o['providerExpectedPickupAt'] =
                raw['delivery']?['riderPickupTime'] ??
                raw['pickup']?['pickupTime'];
          }
        } else if (event['kind'] == 'status') {
          final payload = event['payload'] as Map;
          final match = asMaps(s['orders'])
              .where(
                (o) =>
                    o['source'] == 'Yemeksepeti' &&
                    o['integrationScope'] == c.scope &&
                    o['providerRemoteOrderId'] == event['remoteOrderId'],
              )
              .firstOrNull;
          final o = match == null ? null : mutableOrder(s, match['id'] as int);
          if (o == null ||
              o['source'] != 'Yemeksepeti' ||
              o['integrationMode'] != c.mode) {
            throw const FormatException('Gateway sipariş eşleşmedi');
          }
          final next = {
            'ORDER_CANCELLED': 'Cancelled',
            'ORDER_ACCEPTED': 'Picking',
            'ORDER_PICKED_UP': 'Shipped',
          }[payload['status']];
          if (next != null && allowedRemote('${o['demoRemoteStatus']}', next)) {
            externalPlatformEvent(s, o['id'] as int, next);
          }
        } else {
          throw const FormatException('Gateway olay türü geçersiz');
        }
        last = event['id'] as int;
      }
      final cursors =
          s.putIfAbsent('platformCursors', () => <String, dynamic>{}) as Map;
      cursors['Yemeksepeti'] = last;
      (s.putIfAbsent('platformCursorScopes', () => <String, dynamic>{})
              as Map)['Yemeksepeti'] =
          c.scope;
      storeConfig(s, 'Yemeksepeti')['acceptFlow'] =
          c.values['directApproved'] == true ? 'direct' : 'indirect';
    });
  }

  Future<void> _dispatch(Json saved, PlatformCredentials c) async {
    if (_disposed) return;
    var shouldSend = false;
    edit((s) {
      final j = operationById(s, '${saved['id']}'),
          o = mutableOrder(s, j['orderId'] as int)!;
      if (j['status'] != 'Bekliyor') return;
      if (o['cancelled'] == true ||
          o['closed'] == true ||
          o['demoRemoteStatus'] != j['expected']) {
        finishOrderAction(
          s,
          '${j['id']}',
          'Hata',
          error: 'Sipariş durumu değişti; işlem gönderilmedi',
        );
        return;
      }
      j['status'] = 'Gönderiliyor';
      j['attempts'] = (j['attempts'] as int) + 1;
      shouldSend = true;
    });
    if (!shouldSend) return;
    final j = operationById(store.read().data, '${saved['id']}'),
        o = mutableOrder(store.read().data, j['orderId'] as int)!;
    try {
      if (j['mode'] == 'demo') {
        edit((s) => finishOrderAction(s, '${j['id']}', 'Simüle edildi'));
        return;
      }
      if (c.mode != j['mode'] ||
          o['integrationScope'] != c.scope ||
          !c.configured ||
          !c.confirmed) {
        throw const IntegrationFailure(
          'Ortam / hesap bilgileri eşleşmiyor; gönderilmedi',
        );
      }
      await api.action(c, o, j);
      if (!_disposed) {
        edit((s) => finishOrderAction(s, '${j['id']}', 'Başarılı'));
      }
    } on IntegrationFailure catch (e) {
      if (!_disposed) {
        edit(
          (s) => finishOrderAction(
            s,
            '${j['id']}',
            e.uncertain ? 'Belirsiz' : 'Hata',
            error: e.message,
            retryAt: e.retryAfter,
          ),
        );
      }
    } catch (_) {
      if (!_disposed) {
        edit(
          (s) => finishOrderAction(
            s,
            '${j['id']}',
            'Belirsiz',
            error: 'Sonuç bilinmiyor; platformda doğrulayın',
          ),
        );
      }
    }
  }

  Future<void> runOnce() async {
    if (_busy || _disposed) return;
    _busy = true;
    try {
      for (final source in platformSources) {
        if (_disposed) return;
        PlatformCredentials c;
        try {
          c = await vault.load(source);
        } catch (_) {
          statuses[source] = 'Güvenli anahtar deposu açılamadı';
          continue;
        }
        if (c.mode == 'off' || !c.configured || !c.confirmed) {
          statuses[source] = 'API bilgileri / resmi onay eksik · Bağlı değil';
        } else {
          try {
            c.validate();
            if (source == 'Trendyol Go') {
              await pollTgo(c);
              statuses[source] =
                  '${c.mode.toUpperCase()} · Sipariş sorgusu başarılı';
            } else {
              await pollYsRelay(c);
            }
          } on IntegrationFailure catch (e) {
            statuses[source] = e.message;
          } catch (_) {
            statuses[source] = 'Sipariş alma başarısız; imleç korundu';
          }
        }
        if (_disposed) return;
        for (final j in orderOperations(
          store.read().data,
        ).where((j) => j['source'] == source && j['status'] == 'Bekliyor')) {
          await _dispatch(j, c);
        }
      }
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    timer?.cancel();
    api.transport.close();
    super.dispose();
  }
}
