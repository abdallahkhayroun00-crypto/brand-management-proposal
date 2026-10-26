import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/pos_store.dart';
import 'package:nohut_falafel_desktop/pos_logic.dart';
import 'package:nohut_falafel_desktop/operations.dart';
import 'package:nohut_falafel_desktop/lan_server.dart';
import 'package:nohut_falafel_desktop/staff_commands.dart';
import 'package:nohut_falafel_desktop/order_actions.dart';
import 'package:nohut_falafel_desktop/platform_workflows.dart';
import 'package:nohut_falafel_desktop/floor_plan.dart';

void main() {
  late Directory folder;
  late PosStore store;
  late StaffAuth auth;
  late DateTime now;
  setUp(() {
    folder = Directory.systemTemp.createTempSync('nohut-staff-auth-');
    store = PosStore(databaseFile: '${folder.path}/pos.sqlite3');
    now = DateTime.utc(2026, 10, 25, 10);
    auth = StaffAuth(store, clock: () => now);
    final s = store.read().data;
    s['localMenu'] = [
      {'id': 0, 'name': 'Falafel', 'price': 140, 'category': 'wrap'},
    ];
    seedPlatformMenu(s, asMaps(s['localMenu']));
    store.replace(s, 0);
  });
  tearDown(() {
    store.dispose();
    folder.deleteSync(recursive: true);
  });
  ActivatedSession activate(int id) =>
      auth.activate(auth.issue(id).token, 'Test Telefon');
  test('staff floor matches all five PC tables and follows saved layout', () {
    final s = store.read().data;
    s['floorPositions'] = {
      '3': {'x': .4, 'y': .5},
      '5': {'x': 3, 'y': -1},
    };
    final pc = positionsFromJson(s['floorPositions']);
    final phone = asMaps(staffProjection(s)['floorPlan']);
    expect(phone.map((p) => p['number']).toList(), [1, 2, 3, 4, 5]);
    for (final p in phone) {
      final r = pc[p['number']]!;
      expect(p['x'], closeTo(r.left, 1e-12));
      expect(p['y'], closeTo(r.top, 1e-12));
      expect(p['w'], closeTo(r.width, 1e-12));
      expect(p['h'], closeTo(r.height, 1e-12));
    }
  });
  test(
    'new local batch has independent readiness while retries stay idempotent',
    () {
      final session = activate(2);
      final result = submitStaffOrder(
        store,
        {
          'requestId': 'new_batch_order_1',
          'expectedRevision': store.read().revision,
          'source': 'Masa',
          'table': 1,
          'lines': [
            {'productId': 0, 'qty': 1},
          ],
        },
        principal: session.principal,
        auth: auth,
      );
      final id = result['orderId'] as int;
      final snapshot = store.read(), s = copyJson(snapshot.data);
      final first = requestOrderAction(s, id, 'ready', pcActor);
      expect(
        requestOrderAction(s, id, 'ready', pcActor)['operationId'],
        first['operationId'],
      );
      addOrderBatch(s, id, [
        {'name': 'Falafel', 'qty': 1, 'price': 140},
      ]);
      expect(mutableOrder(s, id)!['serviceStatus'], 'Hazırlanıyor');
      expect(
        (asMaps(staffProjection(s)['orders']).single['operations'] as List),
        isEmpty,
      );
      final second = requestOrderAction(
        s,
        id,
        'ready',
        session.principal.actor,
      );
      expect(second['operationId'], isNot(first['operationId']));
      expect(orderOperations(s), hasLength(2));
    },
  );
  test(
    'QR one-time, ten-minute expiry, renew invalidates old QR and sessions',
    () {
      final code = auth.issue(2),
          session = auth.activate(auth.issue(3).token, 'Diğer Telefon');
      now = now.add(const Duration(minutes: 11));
      expect(
        () => auth.activate(code.token, 'Telefon'),
        throwsA(isA<StaffUnauthorized>()),
      );
      final first = activate(2);
      expect(auth.authenticate(first.token).employeeId, 2);
      expect(() => auth.activate(auth.issue(2).token, 'X'), returnsNormally);
      final oldCode = auth.issue(2);
      final fresh = auth.issue(2, revokeSessions: true);
      expect(
        () => auth.activate(oldCode.token, 'Telefon'),
        throwsA(isA<StaffUnauthorized>()),
      );
      expect(
        () => auth.authenticate(first.token),
        throwsA(isA<StaffUnauthorized>()),
      );
      final newer = auth.activate(fresh.token, 'Telefon');
      expect(auth.authenticate(newer.token).name, 'Mehmet');
      expect(
        () => auth.activate(fresh.token, 'İkinci Telefon'),
        throwsA(isA<StaffUnauthorized>()),
      );
      expect(auth.authenticate(session.token).employeeId, 3);
    },
  );
  test(
    'multiple devices, individual revocation, access switch and inactive employee enforced',
    () {
      final a = activate(2), b = activate(2);
      expect(
        auth.sessions(2).where((s) => s['revoked_at'] == null),
        hasLength(2),
      );
      auth.revoke(a.principal.sessionId);
      expect(
        () => auth.authenticate(a.token),
        throwsA(isA<StaffUnauthorized>()),
      );
      expect(auth.authenticate(b.token).employeeId, 2);
      auth.disable(2);
      expect(
        () => auth.authenticate(b.token),
        throwsA(isA<StaffUnauthorized>()),
      );
      final c = activate(2);
      expect(auth.authenticate(c.token).employeeId, 2);
      final snapshot = store.read(), s = copyJson(snapshot.data);
      saveEmployee(s, 2, 'Mehmet', 'Personel', false);
      store.replace(s, snapshot.revision);
      expect(
        () => auth.authenticate(c.token),
        throwsA(isA<StaffUnauthorized>()),
      );
    },
  );
  test(
    'sessions persist across reopen, hashed tokens not in POS snapshots',
    () {
      final session = activate(2);
      expect(jsonEncode(store.read().data), isNot(contains(session.token)));
      final other = PosStore(databaseFile: store.filePath);
      try {
        expect(
          StaffAuth(
            other,
            clock: () => now,
          ).authenticate(session.token).employeeId,
          2,
        );
      } finally {
        other.dispose();
      }
      now = now.add(const Duration(days: 31));
      expect(
        () => auth.authenticate(session.token),
        throwsA(isA<StaffUnauthorized>()),
      );
    },
  );
  test(
    'actor comes from session; ready before PC acceptance fails; ready semantic dedup retains first worker',
    () {
      final s = store.read().data,
          o = importPlatform(
            store.read().data,
            platformFixture(store.read().data, 'Trendyol Go', 'card'),
          )!;
      s['orders'] = [o];
      s['nextId'] = 1201;
      store.replace(s, store.read().revision);
      final a = activate(2), b = activate(3);
      expect(
        () => submitStaffReady(store, auth, a.principal, {
          'requestId': 'ready_request_1',
          'orderId': 1200,
        }),
        throwsFormatException,
      );
      final snap = store.read(), next = copyJson(snap.data);
      externalPlatformEvent(next, 1200, 'Picking');
      store.replace(next, snap.revision);
      final first = submitStaffReady(store, auth, a.principal, {
        'requestId': 'ready_request_1',
        'orderId': 1200,
      });
      final second = submitStaffReady(store, auth, b.principal, {
        'requestId': 'ready_request_2',
        'orderId': 1200,
      });
      expect(first['operationId'], second['operationId']);
      final current = store.read().data;
      expect(orderOperations(current), hasLength(1));
      expect(orderOperations(current).single['actor']['name'], 'Mehmet');
      expect(mutableOrder(current, 1200)!['demoRemoteStatus'], 'Picking');
      expect(mutableOrder(current, 1200)!['kitchenReady'], true);
      expect(
        () => requestOrderAction(current, 1200, 'accept', a.principal.actor),
        throwsFormatException,
      );
      auth.revoke(a.principal.sessionId);
      expect(
        () => submitStaffReady(store, auth, a.principal, {
          'requestId': 'ready_request_1',
          'orderId': 1200,
        }),
        throwsA(isA<StaffUnauthorized>()),
      );
    },
  );
  test('lost-response order replay survives new session for same employee', () {
    final session = activate(2);
    final payload = <String, dynamic>{
      'requestId': 'same_order_request',
      'expectedRevision': store.read().revision,
      'source': 'Masa',
      'table': 1,
      'lines': [
        {'productId': 0, 'qty': 1},
      ],
    };
    final result = submitStaffOrder(
      store,
      payload,
      principal: session.principal,
      auth: auth,
    );
    final newSession = activate(2);
    expect(
      submitStaffOrder(
        store,
        payload,
        principal: newSession.principal,
        auth: auth,
      ),
      result,
    );
    expect(store.read().data['orders'], hasLength(1));
    expect(
      asMaps(
        asMaps(store.read().data['orders']).single['batches'],
      ).single['staff'],
      'Mehmet',
    );
  });
  test(
    'HTTP session cookies, CSRF, redaction, spoofing, PC-only routes and revocation',
    () async {
      final server = PosLanServer(
        store,
        port: 0,
        staffHtml: File('assets/staff.html').readAsStringSync(),
      );
      await server.start();
      final client = HttpClient();
      String? cookie, csrf;
      Future<(int, Json)> call(
        String method,
        String path, {
        Json? payload,
        bool useCsrf = true,
      }) async {
        final r = await client.openUrl(
          method,
          Uri.parse('http://127.0.0.1:${server.port}$path'),
        );
        if (cookie != null) r.cookies.add(Cookie('nf_session', cookie!));
        if (useCsrf && csrf != null) r.headers.set('X-CSRF-Token', csrf);
        if (payload != null) {
          r.headers.contentType = ContentType.json;
          r.write(jsonEncode(payload));
        }
        final reply = await r.close();
        if (reply.cookies.isNotEmpty) cookie = reply.cookies.single.value;
        final text = await reply.transform(utf8.decoder).join();
        return (
          reply.statusCode,
          Map<String, dynamic>.from(jsonDecode(text) as Map),
        );
      }

      try {
        expect((await call('GET', '/api/bootstrap')).$1, 401);
        expect((await call('GET', '/api/state')).$1, 401);
        final code = server.auth.issue(2),
            enrolled = await call(
              'POST',
              '/api/staff/enroll',
              payload: {'token': code.token, 'deviceName': 'Chrome'},
            );
        expect(enrolled.$1, 200);
        csrf = enrolled.$2['csrf'] as String;
        final boot = await call('GET', '/api/bootstrap');
        expect(boot.$1, 200);
        expect(boot.$2['staff']['name'], 'Mehmet');
        expect((boot.$2['state'] as Map).keys.toSet(), {
          'orders',
          'localMenu',
          'floorPlan',
        });
        expect(
          (await call(
            'POST',
            '/api/staff/orders',
            useCsrf: false,
            payload: {},
          )).$1,
          401,
        );
        expect(
          (await call('POST', '/api/staff/orders', payload: {'staffId': 1})).$1,
          403,
        );
        for (final route in [
          '/api/staff/accept',
          '/api/staff/reject',
          '/api/payments',
          '/api/settings',
          '/api/staff/enrollments',
        ]) {
          expect((await call('POST', route, payload: {})).$1, 403);
        }
        expect((await call('PUT', '/api/state', payload: {})).$1, 405);
        final order = await call(
          'POST',
          '/api/staff/orders',
          payload: {
            'requestId': 'http_staff_order',
            'expectedRevision': store.read().revision,
            'source': 'Masa',
            'table': 1,
            'lines': [
              {'productId': 0, 'qty': 1},
            ],
          },
        );
        expect(order.$1, 200);
        final ready = await call(
          'POST',
          '/api/staff/ready',
          payload: {'requestId': 'http_staff_ready', 'orderId': 1200},
        );
        expect(ready.$1, 200);
        final projected = (await call('GET', '/api/state')).$2['state'] as Map;
        final row = asMaps(projected['orders']).single;
        expect(row.containsKey('payments'), false);
        expect(row.containsKey('providerCallbacks'), false);
        expect(row['operations'][0]['actor'], 'Mehmet');
        server.auth.disable(2);
        expect((await call('GET', '/api/bootstrap')).$1, 401);
      } finally {
        client.close(force: true);
        await server.stop();
        server.dispose();
      }
    },
  );
}
