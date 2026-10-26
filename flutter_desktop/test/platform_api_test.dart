import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/platform_api.dart';
import 'package:nohut_falafel_desktop/platform_runtime.dart';
import 'package:nohut_falafel_desktop/pos_store.dart';
import 'package:nohut_falafel_desktop/pos_logic.dart';
import 'package:nohut_falafel_desktop/order_actions.dart';
import 'package:nohut_falafel_desktop/platform_workflows.dart';

class MemorySecrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class RecordedCall {
  RecordedCall(this.method, this.url, this.headers, this.body, this.form);
  final String method;
  final Uri url;
  final Map<String, String> headers;
  final Object? body;
  final bool form;
}

class TestTransport extends ApiTransport {
  final calls = <RecordedCall>[];
  Future<ApiReply> Function(RecordedCall)? respond;
  @override
  Future<ApiReply> call(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    Object? body,
    bool form = false,
  }) async {
    final c = RecordedCall(method, url, headers, body, form);
    calls.add(c);
    return await (respond?.call(c) ?? Future.value(const ApiReply(200, {})));
  }
}

PlatformCredentials tgo() => PlatformCredentials('Trendyol Go', {
  'mode': 'stage',
  'programConfirmed': true,
  'supplierId': '123',
  'storeId': '456',
  'apiKey': 'TEST_API_KEY',
  'apiSecret': 'TEST_API_SECRET',
  'executorEmail': 'test@example.invalid',
});
PlatformCredentials ys() => PlatformCredentials('Yemeksepeti', {
  'mode': 'stage',
  'programConfirmed': true,
  'username': 'TEST_API_USER',
  'password': 'TEST_PASSWORD',
  'chainCode': 'TEST_CHAIN',
  'remoteId': 'TEST_VENDOR',
  'platformKey': 'TEST_YS_PROGRAM',
  'directApproved': true,
  'preparedApproved': true,
});
Json rawTgo({
  String id = 'package-a',
  int version = 100,
  String status = 'Created',
}) => {
  'id': id,
  'supplierId': 123,
  'storeId': 456,
  'packageModificationDate': version,
  'packageCreationDate': 50,
  'packageStatus': status,
  'deliveryType': 'GO',
  'storePickupSelected': false,
  'totalPrice': 270.01,
  'payment': {'paymentType': 'PAY_WITH_CARD'},
  'lines': [
    {
      'productId': 99,
      'name': 'Platform Falafel',
      'unitSellingPrice': 150.5,
      'items': [
        {'packageItemId': '$id-1', 'isCancelled': false},
        {'packageItemId': '$id-2', 'isCancelled': false},
      ],
      'modifierProducts': [
        {'name': 'Acılı Sos'},
      ],
      'removedIngredients': [
        {'name': 'Soğan'},
      ],
    },
  ],
  'userInformation': {'appName': 'UberEats'},
  'address': {'pinCode': 'TEST_PIN'},
  'customerNote': 'Sos ayrı',
};
Json rawYs() => {
  'token': 'YS-ORDER-TOKEN',
  'code': 'TEST-01',
  'createdAt': '2026-10-25T10:00:00Z',
  'localInfo': {'platformKey': 'TEST_YS_PROGRAM'},
  'expeditionType': 'delivery',
  'delivery': {'riderPickupTime': '2026-10-25T10:20:00Z'},
  'payment': {'status': 'pending', 'type': 'platform'},
  'price': {'grandTotal': '100.01'},
  'products': [
    {
      'id': 'P1',
      'name': 'Falafel',
      'quantity': '3',
      'paidPrice': '100.01',
      'selectedToppings': [],
    },
  ],
  'callbackUrls': {
    'orderAcceptedUrl':
        'https://integration-middleware.stg.restaurant-partners.com/v2/order/status/YS-ORDER-TOKEN',
    'orderPreparedUrl':
        'https://integration-middleware.stg.restaurant-partners.com/v2/orders/YS-ORDER-TOKEN/preparation-completed',
    'orderRejectedUrl':
        'https://integration-middleware.stg.restaurant-partners.com/v2/order/status/YS-ORDER-TOKEN',
  },
};
void main() {
  test(
    'vault keeps secret configuration outside POS snapshot and off requires no account',
    () async {
      final secret = MemorySecrets(), vault = CredentialVault(MemorySecrets());
      final v = CredentialVault(secret);
      await v.save(tgo());
      expect((await v.load('Trendyol Go')).field('apiKey'), 'TEST_API_KEY');
      expect((await vault.load('Yemeksepeti')).mode, 'off');
      await v.remove('Trendyol Go');
      expect((await v.load('Trendyol Go')).configured, false);
      expect(
        () => PlatformCredentials('Trendyol Go', {'mode': 'live'}).validate(),
        throwsFormatException,
      );
      expect(
        () => PlatformCredentials('Yemeksepeti', {
          'mode': 'off',
          'relayUrl': 'http://localhost:8787',
        }).validate(),
        throwsFormatException,
      );
    },
  );
  test(
    'TGO uses Meal API, Basic auth, required headers, store scope and paging',
    () async {
      final transport = TestTransport()
        ..respond = (c) async =>
            const ApiReply(200, {'content': [], 'totalPages': 1});
      await RestaurantApi(transport).tgoPage(tgo(), 2, 100, 200);
      final c = transport.calls.single;
      expect(c.method, 'GET');
      expect(c.url.host, 'stageapi.tgoapis.com');
      expect(c.url.path, '/integrator/order/meal/suppliers/123/packages');
      expect(c.url.queryParameters['storeId'], '456');
      expect(c.url.queryParameters['size'], '50');
      expect(c.url.queryParameters['page'], '2');
      expect(
        c.headers['Authorization'],
        'Basic ${base64Encode(utf8.encode('TEST_API_KEY:TEST_API_SECRET'))}',
      );
      expect(c.headers['User-Agent'], '123 - SelfIntegration');
      expect(c.headers['x-executor-user'], 'test@example.invalid');
    },
  );
  test(
    'TGO normalization preserves net total, source unit prices, IDs and Uber app name without invented collection',
    () {
      final p = normalizeTgoMeal(rawTgo(), tgo());
      expect(p['orderTotal'], 270.01);
      expect(p['items'], hasLength(2));
      expect(asMaps(p['items']).first['unitSellingPrice'], 150.5);
      expect(p['collection'], 'Pending');
      expect(p['appName'], 'UberEats');
      expect(
        () => normalizeTgoMeal({...rawTgo(), 'storeId': 999}, tgo()),
        throwsFormatException,
      );
      expect(
        () => normalizeTgoMeal({...rawTgo(), 'deliveryType': 'STORE'}, tgo()),
        throwsFormatException,
      );
    },
  );
  test(
    'YS prepared callback is source-supplied, authenticated, scope-gated and never picked-up substitution',
    () async {
      final transport = TestTransport()
        ..respond = (c) async => c.url.path == '/v2/login'
            ? const ApiReply(200, {
                'access_token': 'TEST_BEARER',
                'expires_in': 3600,
              })
            : const ApiReply(200, {'code': 'OK'});
      final api = RestaurantApi(transport),
          order = <String, dynamic>{
            'id': 1200,
            'platformPackageId': 'YS-ORDER-TOKEN',
            'providerCallbacks': rawYs()['callbackUrls'],
          };
      await api.action(ys(), order, {'action': 'ready'});
      await api.action(ys(), order, {'action': 'ready'});
      expect(
        transport.calls.where((c) => c.url.path == '/v2/login'),
        hasLength(1),
      );
      expect(
        transport.calls.last.url.path,
        '/v2/orders/YS-ORDER-TOKEN/preparation-completed',
      );
      expect(transport.calls.last.body, null);
      expect(
        transport.calls.last.headers['Authorization'],
        'Bearer TEST_BEARER',
      );
      expect(transport.calls.first.form, true);
      expect(
        () => api.ysCallback(ys(), {
          ...order,
          'providerCallbacks': {
            'orderPreparedUrl':
                'https://attacker.invalid/v2/orders/YS-ORDER-TOKEN/preparation-completed',
          },
        }, 'ready'),
        throwsA(isA<IntegrationFailure>()),
      );
      expect(
        () =>
            api.ysCallback(ys(), {...order, 'providerCallbacks': {}}, 'ready'),
        throwsA(isA<IntegrationFailure>()),
      );
      expect(
        () => api.ysCallback(
          PlatformCredentials('Yemeksepeti', {
            ...ys().values,
            'preparedApproved': false,
          }),
          order,
          'ready',
        ),
        throwsA(isA<IntegrationFailure>()),
      );
    },
  );
  test(
    'TGO unverified mutation contract sends no guessed Grocery request',
    () async {
      final t = TestTransport();
      expect(
        RestaurantApi(t).action(tgo(), {}, {'action': 'ready'}),
        throwsA(isA<IntegrationFailure>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(t.calls, isEmpty);
    },
  );
  test(
    'YS normalization conserves cents and indirect accepted flow, rejects other program or own courier',
    () {
      final p = normalizeYsRestaurant(rawYs(), ys(), 7);
      expect(p['status'], 'Created');
      expect(
        asMaps(p['items']).map((l) => cents(l['unitSellingPrice'])).toList(),
        [3334, 3334, 3333],
      );
      final indirect = PlatformCredentials('Yemeksepeti', {
        ...ys().values,
        'directApproved': false,
      });
      expect(normalizeYsRestaurant(rawYs(), indirect, 7)['status'], 'Picking');
      expect(
        () => normalizeYsRestaurant(
          {
            ...rawYs(),
            'localInfo': {'platformKey': 'OTHER'},
          },
          ys(),
          7,
        ),
        throwsFormatException,
      );
      expect(
        () => normalizeYsRestaurant(
          {
            ...rawYs(),
            'delivery': {'riderPickupTime': null},
          },
          ys(),
          7,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'HTTP error messages do not retain provider-echoed secrets, 429 backoff and uncertain 500',
    () {
      try {
        checkReply(ApiReply(401, {'error': 'TEST_PASSWORD'}));
        fail('must fail');
      } on IntegrationFailure catch (e) {
        expect(e.message, isNot(contains('TEST_PASSWORD')));
        expect(e.uncertain, false);
      }
      try {
        checkReply(const ApiReply(429, {}), mutation: true);
        fail('must fail');
      } on IntegrationFailure catch (e) {
        expect(e.retryAfter, isNotNull);
        expect(e.uncertain, false);
      }
      try {
        checkReply(const ApiReply(500, {}), mutation: true);
        fail('must fail');
      } on IntegrationFailure catch (e) {
        expect(e.uncertain, true);
      }
    },
  );
  group('durable runtime', () {
    late Directory folder;
    late PosStore store;
    late MemorySecrets secrets;
    late TestTransport transport;
    late PlatformRuntime runtime;
    setUp(() {
      folder = Directory.systemTemp.createTempSync('nohut-runtime-');
      store = PosStore(databaseFile: '${folder.path}/pos.sqlite3');
      secrets = MemorySecrets();
      transport = TestTransport();
      runtime = PlatformRuntime(
        store,
        CredentialVault(secrets),
        transport: transport,
      );
    });
    tearDown(() {
      runtime.dispose();
      store.dispose();
      folder.deleteSync(recursive: true);
    });
    test(
      'environment/account scopes isolate imports, polling cursors and pending writes',
      () async {
        final stage = ys();
        final other = PlatformCredentials('Yemeksepeti', {
          ...stage.values,
          'remoteId': 'OTHER_VENDOR',
        });
        final s = store.read().data;
        final o = importPlatform(s, normalizeYsRestaurant(rawYs(), stage, 1))!;
        o['integrationMode'] = 'stage';
        o['demoRemoteStatus'] = 'Picking';
        o['providerCallbacks'] = rawYs()['callbackUrls'];
        requestOrderAction(s, o['id'] as int, 'ready', pcActor);
        importPlatform(s, normalizeYsRestaurant(rawYs(), other, 1));
        expect(s['orders'], hasLength(2));
        s['platformCursors'] = {'Yemeksepeti': 999};
        s['platformCursorScopes'] = {'Yemeksepeti': stage.scope};
        store.replace(s, store.read().revision);
        final relay = PlatformCredentials('Yemeksepeti', {
          ...other.values,
          'relayUrl': 'https://gateway.example.invalid',
          'relayToken': 'TEST_RELAY',
        });
        transport.respond = (call) async => const ApiReply(200, {'events': []});
        await runtime.pollYsRelay(relay);
        expect(transport.calls.single.url.queryParameters['after'], '0');
        transport.calls.clear();
        await runtime.vault.save(other);
        await runtime.runOnce();
        expect(transport.calls, isEmpty);
        expect(orderOperations(store.read().data).single['status'], 'Hata');
      },
    );
    test(
      'demo ready never sends network requests and legacy simulation cannot alter live orders',
      () async {
        final s = store.read().data;
        seedPlatformMenu(s, [
          {'id': 0, 'name': 'Falafel', 'price': 140, 'category': 'wrap'},
        ]);
        final o = importPlatform(s, platformFixture(s, 'Trendyol Go', 'card'))!;
        externalPlatformEvent(s, o['id'] as int, 'Picking');
        requestOrderAction(s, o['id'] as int, 'ready', pcActor);
        store.replace(s, store.read().revision);
        await runtime.runOnce();
        expect(transport.calls, isEmpty);
        expect(
          orderOperations(store.read().data).single['status'],
          'Simüle edildi',
        );
        final live = store.read().data;
        mutableOrder(live, o['id'] as int)!['integrationMode'] = 'live';
        expect(
          () => queuePlatform(live, 'cancel', 'Trendyol Go', o['id'], {}),
          throwsFormatException,
        );
      },
    );
    test(
      'TGO pages commit together and cursor advances only after all pages import',
      () async {
        final c = tgo();
        transport.respond = (call) async => ApiReply(200, {
          'content': [
            rawTgo(
              id: 'pkg-${call.url.queryParameters['page']}',
              version: 100 + int.parse(call.url.queryParameters['page']!),
            ),
          ],
          'totalPages': 2,
        });
        await runtime.pollTgo(c);
        expect(store.read().data['orders'], hasLength(2));
        expect(store.read().data['platformCursors']['Trendyol Go'], isA<int>());
        final snapshot = store.read();
        transport.respond = (call) async =>
            call.url.queryParameters['page'] == '1'
            ? const ApiReply(429, {})
            : ApiReply(200, {
                'content': [rawTgo(id: 'new-order', version: 999)],
                'totalPages': 2,
              });
        expect(runtime.pollTgo(c), throwsA(isA<IntegrationFailure>()));
        await Future<void>.delayed(Duration.zero);
        expect(store.read().revision, snapshot.revision);
        expect(store.read().data['orders'], hasLength(2));
      },
    );
    test('provider timeout becomes uncertain and is not retried', () async {
      final c = ys();
      await runtime.vault.save(c);
      final s = store.read().data,
          packet = normalizeYsRestaurant(rawYs(), c, 1);
      final o = importPlatform(s, packet)!;
      o['integrationMode'] = 'stage';
      o['providerCallbacks'] = rawYs()['callbackUrls'];
      o['demoRemoteStatus'] = 'Picking';
      requestOrderAction(s, o['id'] as int, 'ready', {
        'kind': 'staff',
        'id': 2,
        'name': 'Mehmet',
      });
      store.replace(s, store.read().revision);
      transport.respond = (call) async {
        if (call.url.path == '/v2/login') {
          return const ApiReply(200, {
            'access_token': 'TEST_BEARER',
            'expires_in': 3600,
          });
        }
        throw TimeoutException('test timeout');
      };
      await runtime.runOnce();
      expect(orderOperations(store.read().data).single['status'], 'Belirsiz');
      final sent = transport.calls.length;
      await runtime.runOnce();
      expect(transport.calls.length, sent);
      expect(
        () => retryOrderAction(store.read().data, 'OP-1', pcActor),
        throwsFormatException,
      );
      expect(jsonEncode(store.read().data), isNot(contains('TEST_PASSWORD')));
    });
    test(
      'provider success and 429 are recorded separately from local kitchen readiness',
      () async {
        final c = ys();
        await runtime.vault.save(c);
        final s = store.read().data;
        final o = importPlatform(s, normalizeYsRestaurant(rawYs(), c, 1))!;
        o['integrationMode'] = 'stage';
        o['providerCallbacks'] = rawYs()['callbackUrls'];
        o['demoRemoteStatus'] = 'Picking';
        requestOrderAction(s, o['id'] as int, 'ready', {
          'kind': 'staff',
          'id': 3,
          'name': 'Abdallah',
        });
        store.replace(s, store.read().revision);
        transport.respond = (call) async => call.url.path == '/v2/login'
            ? const ApiReply(200, {
                'access_token': 'TEST_BEARER',
                'expires_in': 3600,
              })
            : const ApiReply(429, {});
        await runtime.runOnce();
        expect(orderOperations(store.read().data).single['status'], 'Hata');
        expect(
          mutableOrder(store.read().data, 1200)!['demoRemoteStatus'],
          'Picking',
        );
        final snap = store.read(), next = copyJson(snap.data);
        operationById(next, 'OP-1')['nextAttemptAt'] = null;
        retryOrderAction(next, 'OP-1', pcActor);
        store.replace(next, snap.revision);
        transport.respond = (call) async => const ApiReply(200, {'code': 'OK'});
        await runtime.runOnce();
        final done = store.read().data;
        expect(orderOperations(done).single['status'], 'Başarılı');
        expect(mutableOrder(done, 1200)!['demoRemoteStatus'], 'Invoiced');
        expect(asMaps(done['activity']).single['actor']['name'], 'Abdallah');
        expect(asMaps(done['activity']).single['platformSync'], 'Başarılı');
        final count = transport.calls.length;
        await runtime.runOnce();
        expect(transport.calls.length, count);
      },
    );
    test(
      'duplicate gateway order event is idempotent and source callbacks remain off phone projection',
      () async {
        final c = PlatformCredentials('Yemeksepeti', {
          ...ys().values,
          'relayUrl': 'https://gateway.example.invalid',
          'relayToken': 'TEST_RELAY_TOKEN',
        });
        transport.respond = (call) async => ApiReply(200, {
          'events': [
            {
              'id': 1,
              'remoteId': 'TEST_VENDOR',
              'remoteOrderId': 'NF-STABLE',
              'kind': 'order',
              'payload': rawYs(),
            },
          ],
        });
        await runtime.pollYsRelay(c);
        expect(store.read().data['orders'], hasLength(1));
        final order = asMaps(store.read().data['orders']).single;
        expect(order['providerRemoteOrderId'], 'NF-STABLE');
        expect(
          jsonEncode(staffProjection(store.read().data)),
          isNot(contains('orderPreparedUrl')),
        );
      },
    );
    test(
      'crash recovery does not auto replay a job persisted as sending',
      () async {
        final s = store.read().data;
        s['orders'] = [];
        s['orderOperations'] = [
          {
            'id': 'OP-1',
            'key': '1200:ready',
            'orderId': 1200,
            'status': 'Gönderiliyor',
            'action': 'ready',
            'source': 'Yemeksepeti',
            'actor': pcActor,
          },
        ];
        s['orders'] = [
          {
            'id': 1200,
            'source': 'Gel-Al',
            'table': null,
            'batches': [],
            'payments': [],
            'events': [],
          },
        ];
        s['nextId'] = 1201;
        store.replace(s, store.read().revision);
        runtime.start();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(orderOperations(store.read().data).single['status'], 'Belirsiz');
        expect(transport.calls, isEmpty);
      },
    );
  });
}
