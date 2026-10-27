import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nohut_falafel_desktop/pos_logic.dart';
import 'package:nohut_falafel_desktop/pos_store.dart';
import 'package:nohut_falafel_desktop/operations.dart';
import 'package:nohut_falafel_desktop/platform_workflows.dart';
import 'package:nohut_falafel_desktop/staff_commands.dart';
import 'package:nohut_falafel_desktop/lan_server.dart';

final products = <Json>[
  {'id': 0, 'name': 'Falafel', 'price': 100.01, 'category': 'wrap'},
  {'id': 1, 'name': 'Ayran', 'price': 30, 'category': 'drink'},
];
Json line({int qty = 1, double price = 100.01}) => {
  'productId': 0,
  'name': 'Falafel',
  'price': price,
  'qty': qty,
  'removed': [],
  'note': '',
};
Json local(Json s, {int table = 1}) => newLocalOrder(
  state: s,
  source: 'Masa',
  table: table,
  productLines: [line()],
);
Json seeded() {
  final s = emptyPosState();
  s['localMenu'] = copyJson({'p': products})['p'];
  seedPlatformMenu(s, products);
  return s;
}

Json packet(Json s) => platformFixture(s, 'Trendyol Go', 'cod');
void ack(Json s, String type, Object target, Json payload) {
  final j = queuePlatform(s, type, 'Trendyol Go', target, payload);
  resolvePlatform(s, j['id'] as String);
  expect(j['status'], 'Tamamlandı', reason: '${j['error']}');
}

void main() {
  test(
    'equal split conserves cents and existing partial receipt maps to guests without double collection',
    () {
      final s = emptyPosState(), o = local(emptyPosState());
      splitEqually(o, 3);
      expect(
        asMaps(
          o['guestChecks'],
        ).map((g) => guestBalance(o, g['id'] as int)).toList(),
        [3334, 3334, 3333],
      );
      final other = local(s);
      recordPayment(other, 6000, 'Kart');
      addGuest(other, 'Ali');
      addGuest(other, 'Ayşe');
      allocateProduct(other, 1, '1:0', 6000);
      allocateProduct(other, 2, '1:0', 4001);
      expect(
        () => recordPayment(other, 4001, 'Kart', guestId: 2),
        throwsFormatException,
      );
      assignExistingPayment(other, 0, 1, 6000);
      expect(guestBalance(other, 1), 0);
      expect(orderPaidCents(other), 6000);
      recordPayment(other, 4001, 'Nakit', receivedCents: 5000, guestId: 2);
      expect(orderDueCents(other), 0);
      expect(() => refundPayment(other, 0, 1, 'İade'), throwsFormatException);
      assignExistingPayment(other, 0, 1, 5000);
      refundPayment(other, 0, 1000, 'Kısmi iade');
      expect(guestBalance(other, 1), 1000);
      PosStore.validate(s);
    },
  );
  test(
    'cash shift separates cash/card, refunds by event date, frozen close and later shift',
    () {
      final s = emptyPosState();
      openCash(s, 50000);
      final o = local(s);
      recordPayment(o, 7000, 'Nakit', receivedCents: 10000);
      recordPayment(o, 3001, 'Kart');
      expect(expectedCash(s, activeCash(s)!), 57000);
      refundPayment(o, 0, 2000, 'Müşteri iadesi');
      expect(expectedCash(s, activeCash(s)!), 55000);
      moveCash(s, -1000, 'Malzeme');
      expect(expectedCash(s, activeCash(s)!), 54000);
      closeCash(s, 53900);
      final closed = asMaps(cashBook(s)['sessions']).first;
      expect(closed['differenceCents'], -100);
      openCash(s, 10000);
      refundPayment(o, 0, 1000, 'Geç iade');
      expect(expectedCash(s, activeCash(s)!), 9000);
      expect(asMaps(cashBook(s)['sessions']).first['expectedCents'], 54000);
      expect(() => openCash(s, 0), throwsFormatException);
      expect(() => moveCash(s, -100000, 'Çıkış'), throwsFormatException);
      expect(() => moveCash(s, 100, ''), throwsFormatException);
      PosStore.validate(s);
    },
  );
  test(
    'product guest shares conserve every cent; mixed guest payment and refund enforce limits',
    () {
      final s = emptyPosState();
      final o = local(s);
      s['orders'] = [o];
      s['nextId'] = 1201;
      addGuest(o, 'Ali');
      addGuest(o, 'Ayşe');
      allocateProduct(o, 1, '1:0', 5001);
      allocateProduct(o, 2, '1:0', 5000);
      expect(allocatedTo(o, '1:0'), 10001);
      expect(() => allocateProduct(o, 2, '1:0', 5001), throwsFormatException);
      recordPayment(o, 3000, 'Nakit', receivedCents: 5000, guestId: 1);
      recordPayment(o, 2001, 'Kart', guestId: 1);
      expect(guestBalance(o, 1), 0);
      expect(
        () => recordPayment(o, 1, 'Kart', guestId: 1),
        throwsFormatException,
      );
      expect(() => recordPayment(o, 1, 'Kart'), throwsFormatException);
      expect(() => allocateProduct(o, 1, '1:0', 0), throwsFormatException);
      refundPayment(o, 1, 1000, 'Düzeltme');
      expect(guestBalance(o, 1), 1000);
      expect(
        () => refundPayment(o, 1, 1002, 'Düzeltme'),
        throwsFormatException,
      );
      PosStore.validate(s);
    },
  );
  test(
    'product cancellation guards allocation and payment, queues correction and frees fully cancelled table',
    () {
      final s = emptyPosState();
      final o = local(s);
      s['orders'] = [o];
      s['nextId'] = 1201;
      addGuest(o, 'Ali');
      allocateProduct(o, 1, '1:0', 10001);
      expect(
        () => cancelProduct(s, 1200, '1:0', 1, 'Bitti'),
        throwsFormatException,
      );
      allocateProduct(o, 1, '1:0', 0);
      resetGuests(o);
      recordPayment(o, 10001, 'Nakit', receivedCents: 10001);
      expect(
        () => cancelProduct(s, 1200, '1:0', 1, 'Bitti'),
        throwsFormatException,
      );
      refundPayment(o, 0, 10001, 'İptal öncesi iade');
      cancelLocalOrder(s, 1200, 'Müşteri vazgeçti');
      expect(activeTable(s, 1), null);
      expect(s['printJobs'], hasLength(2));
      expect(receiptText(s, asMaps(s['printJobs']).last), contains('İPTAL'));
      PosStore.validate(s);
    },
  );
  test('closed historical refund does not reoccupy a reused table', () {
    final s = emptyPosState();
    final o = local(s);
    s['orders'] = [o];
    s['nextId'] = 1201;
    recordPayment(o, 10001, 'Kart');
    closeLocalTable(o);
    final next = local(s);
    refundPayment(o, 0, 100, 'Geç düzeltme');
    expect(activeTable(s, 1)?['id'], next['id']);
    expect(
      () => newLocalOrder(
        state: s,
        source: 'Masa',
        table: 1,
        productLines: [line()],
      ),
      throwsFormatException,
    );
  });
  test(
    'pickup closes only after paid and served; local courier and invalid quantities rejected',
    () {
      final s = emptyPosState();
      final o = newLocalOrder(
        state: s,
        source: 'Gel-Al',
        pickupChannel: 'Telefon',
        productLines: [line()],
      );
      expect(() => closePickup(o), throwsFormatException);
      recordPayment(o, 10001, 'Kart');
      setLocalService(o, 'Hazır');
      setLocalService(o, 'Teslim Edildi');
      closePickup(o);
      expect(o['closed'], true);
      expect(
        () => addOrderBatch(s, o['id'] as int, [line()]),
        throwsFormatException,
      );
      expect(
        () => newLocalOrder(state: s, source: 'Kurye', productLines: [line()]),
        throwsFormatException,
      );
      expect(
        () => newLocalOrder(
          state: s,
          source: 'Masa',
          table: 6,
          productLines: [line()],
        ),
        throwsFormatException,
      );
      expect(
        () => newLocalOrder(
          state: s,
          source: 'Gel-Al',
          productLines: [line(qty: -1)],
        ),
        throwsFormatException,
      );
    },
  );
  test('staff admin preserves ID/history and blocks duplicate names', () {
    final s = emptyPosState();
    saveEmployee(s, null, 'Fatma', 'Personel', true);
    final p = asMaps(s['employees']).last;
    saveEmployee(s, p['id'] as int, 'Fatma Yeni', 'Yönetici', false);
    expect(asMaps(s['employees']).last['id'], p['id']);
    expect(asMaps(s['employees']).last['active'], false);
    expect(
      () => saveEmployee(s, null, 'Fatma Yeni', 'Personel', true),
      throwsFormatException,
    );
  });
  test('CSV preserves precision, escaping and formula safety', () {
    expect(csvCell('=HYPERLINK("x")'), '"\'=HYPERLINK(""x"")"');
    final text = ledgerCsv([
      const LedgerEntry(
        1,
        'Masa',
        'Nakit',
        'Tahsilat',
        12345,
        '2026-10-25T10:00:00Z',
        'Ali, "A"',
      ),
    ]);
    expect(text, contains('"12345"'));
    expect(text, contains('"Ali, ""A"""'));
    expect(text.startsWith('\uFEFF'), true);
  });
  test(
    'platform import idempotency, source revision and terminal no-reprint',
    () {
      final s = seeded(), p = packet(seeded());
      final o = importPlatform(s, p)!;
      expect(importPlatform(s, p), null);
      expect(s['orders'], hasLength(1));
      expect(s['printJobs'], isEmpty);
      final delivered = copyJson(p)
        ..['revision'] = 2
        ..['status'] = 'Delivered';
      importPlatform(s, delivered);
      expect(o['closed'], true);
      expect(s['printJobs'], isEmpty);
      expect(o['platformCollection'], 'Pending');
      expect(orderDueCents(o), 0);
      final old = copyJson(p)
        ..['revision'] = 3
        ..['status'] = 'Picking';
      expect(importPlatform(s, old), null);
      platformCollected(o);
      expect(o['payments'], hasLength(1));
      platformCollected(o);
      expect(o['payments'], hasLength(1));
      expect(() => recordPayment(o, 1, 'Kart'), throwsFormatException);
      PosStore.validate(s);
    },
  );
  test(
    'request remains pending; 429 backoff; retry; ack once creates kitchen job',
    () {
      final s = seeded(), o = importPlatform(seeded(), packet(seeded()))!;
      s['orders'] = [o];
      s['nextId'] = 1201;
      final j = queuePlatform(s, 'accept', 'Trendyol Go', o['id'], {
        'expected': 'Created',
        'preparationTime': 20,
      });
      expect(o['demoRemoteStatus'], 'Created');
      expect(
        () => queuePlatform(s, 'accept', 'Trendyol Go', o['id'], {}),
        throwsFormatException,
      );
      resolvePlatform(s, j['id'] as String, fail: true);
      expect(o['demoRemoteStatus'], 'Created');
      expect(() => retryPlatform(s, j['id'] as String), throwsFormatException);
      retryPlatform(
        s,
        j['id'] as String,
        now: DateTime.now().add(const Duration(seconds: 11)),
      );
      resolvePlatform(s, j['id'] as String);
      expect(o['demoRemoteStatus'], 'Picking');
      expect(s['printJobs'], hasLength(1));
      expect(
        () => resolvePlatform(s, j['id'] as String),
        throwsFormatException,
      );
    },
  );
  test(
    'stale status acknowledgement fails instead of reversing incoming event',
    () {
      final s = seeded(), o = importPlatform(seeded(), packet(seeded()))!;
      s['orders'] = [o];
      s['nextId'] = 1201;
      final j = queuePlatform(s, 'accept', 'Trendyol Go', o['id'], {
        'expected': 'Created',
        'preparationTime': 20,
      });
      externalPlatformEvent(s, o['id'] as int, 'Delivered');
      resolvePlatform(s, j['id'] as String);
      expect(j['status'], 'Hata');
      expect(o['demoRemoteStatus'], 'Delivered');
    },
  );
  test(
    'partial platform cancellation applies proportional discount; last item clears rounding remainder',
    () {
      final s = seeded(), o = importPlatform(seeded(), packet(seeded()))!;
      s['orders'] = [o];
      s['nextId'] = 1201;
      ack(s, 'accept', o['id'], {'expected': 'Created', 'preparationTime': 20});
      final original = orderTotalCents(o), items = checkLines(o);
      ack(s, 'cancel', o['id'], {
        'expected': 'Picking',
        'reasonId': 621,
        'itemIds': [items.first.line['packageItemId']],
      });
      expect(orderTotalCents(o), lessThan(original));
      expect(checkLines(o), hasLength(1));
      ack(s, 'cancel', o['id'], {
        'expected': 'Picking',
        'reasonId': 621,
        'itemIds': [items.last.line['packageItemId']],
      });
      expect(orderTotalCents(o), 0);
      expect(o['demoRemoteStatus'], 'UnSupplied');
      expect(s['printJobs'], hasLength(3));
      PosStore.validate(s);
    },
  );
  test(
    'menu price batch retains successful items and reports failures; YS writes gated',
    () {
      final s = seeded(),
          rows = asMaps(platformHub(seeded())['menu']['Trendyol Go']);
      final j = queuePlatform(s, 'price', 'Trendyol Go', 'bulk', {
        'partial': true,
        'items': [
          for (final m in rows) {'id': m['id'], 'price': 200},
        ],
      });
      resolvePlatform(s, j['id'] as String);
      expect(j['status'], 'Hata');
      expect(asMaps(platformHub(s)['menu']['Trendyol Go']).first['price'], 200);
      expect(asMaps(j['results']).last['status'], 'FAILED');
      for (final type in [
        'store',
        'hours',
        'price',
        'claim',
        'reply',
        'invoice',
        'cancel',
      ]) {
        expect(
          () => queuePlatform(s, type, 'Yemeksepeti', 'x', {}),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'overnight hours wrap week and reject overlapping next-day schedule',
    () {
      final hs = List.generate(
        7,
        (_) => <String, dynamic>{
          'start': '11:00',
          'end': '21:00',
          'closed': true,
        },
      );
      hs[6] = {'start': '23:00', 'end': '02:00', 'closed': false};
      expect(validateHours(hs)[0].single['end'], 120);
      hs[0] = {'start': '01:00', 'end': '04:00', 'closed': false};
      expect(() => validateHours(hs), throwsFormatException);
      hs[0] = {'start': '25:00', 'end': '04:00', 'closed': false};
      expect(() => validateHours(hs), throwsFormatException);
    },
  );
  test(
    'claim per-item objection is unresolved, expires, does not manufacture cash refund',
    () {
      final s = seeded(), o = importPlatform(seeded(), packet(seeded()))!;
      s['orders'] = [o];
      s['nextId'] = 1201;
      externalPlatformEvent(s, 1200, 'Delivered');
      sampleClaim(s, 1200, 'PAY_BACK');
      final c = (platformHub(s)['claims'] as List).single as Map,
          items = asMaps(c['items']);
      ack(s, 'claim', c['id'], {
        'decision': 'reject',
        'note': 'Ürün fotoğrafı yok',
        'itemIds': [items.first['id']],
      });
      expect(c['status'], 'WaitingInAction');
      ack(s, 'claim', c['id'], {
        'decision': 'accept',
        'note': 'Kısmi kabul',
        'itemIds': [items.last['id']],
      });
      expect(c['status'], 'Unresolved');
      expect(o['payments'], isEmpty);
      c['status'] = 'WaitingInAction';
      c['deadline'] = '2000-01-01T00:00:00Z';
      final j = queuePlatform(s, 'claim', 'Trendyol Go', c['id'], {
        'decision': 'accept',
        'note': 'x',
        'itemIds': [items.first['id']],
      });
      resolvePlatform(s, j['id'] as String);
      expect(j['status'], 'Hata');
    },
  );
  test(
    'review moderation gate and invoice HTTPS duplicate/delete workflow',
    () {
      final s = seeded(), o = importPlatform(seeded(), packet(seeded()))!;
      s['orders'] = [o];
      s['nextId'] = 1201;
      sampleReview(s, 'Trendyol Go');
      final r = asMaps(platformHub(s)['reviews']).single;
      ack(s, 'reply', r['id'], {'text': 'Teşekkürler'});
      expect(
        findRecord(s, 'reviews', r['id'])['replyStatus'],
        'WAITING_FOR_APPROVE',
      );
      storeConfig(s, 'Trendyol Go')['migrated'] = true;
      expect(() => sampleReview(s, 'Trendyol Go'), throwsFormatException);
      externalPlatformEvent(s, 1200, 'Picking');
      final bad = queuePlatform(s, 'invoice', 'Trendyol Go', 1200, {
        'url': 'http://example.com/invoice',
      });
      resolvePlatform(s, bad['id'] as String);
      expect(bad['status'], 'Hata');
      ack(s, 'invoice', 1200, {'url': 'https://example.com/invoice'});
      final duplicate = queuePlatform(s, 'invoice', 'Trendyol Go', 1200, {
        'url': 'https://example.com/other',
      });
      resolvePlatform(s, duplicate['id'] as String);
      expect(duplicate['status'], 'Hata');
      ack(
        s,
        'invoice-delete',
        asMaps(platformHub(s)['invoices']).single['id'],
        {},
      );
      ack(s, 'invoice', 1200, {'url': 'https://example.com/other'});
      expect(platformHub(s)['invoices'], hasLength(2));
    },
  );
  test(
    'finance example net subtracts cancellation and commission once; discount informational',
    () {
      final s = seeded(), o = importPlatform(seeded(), packet(seeded()))!;
      s['orders'] = [o];
      s['nextId'] = 1201;
      externalPlatformEvent(s, 1200, 'Delivered');
      sampleSettlement(s, 1200);
      final r = asMaps(platformHub(s)['settlements']).single;
      expect(
        cents(r['net']),
        cents(r['gross']) - cents(r['refund']) - cents(r['commission']),
      );
      expect(() => sampleSettlement(s, 1200), throwsFormatException);
      expect(o['platformCollection'], 'Pending');
    },
  );

  group('real SQLite and embedded HTTP', () {
    late Directory folder;
    late PosStore a, b;
    setUp(() {
      folder = Directory.systemTemp.createTempSync('nohut-migration-');
      final file = '${folder.path}/pos.sqlite3';
      a = PosStore(databaseFile: file);
      b = PosStore(databaseFile: file);
      a.replace(seeded(), a.read().revision);
    });
    tearDown(() {
      a.dispose();
      b.dispose();
      folder.deleteSync(recursive: true);
    });
    Json command(String id, int revision) => {
      'requestId': id,
      'expectedRevision': revision,
      'staffId': 2,
      'source': 'Masa',
      'table': 1,
      'lines': [
        {
          'productId': 0,
          'qty': 1,
          'price': 0.01,
          'removed': [],
          'note': 'Sos ayrı',
        },
      ],
    };
    test(
      'two SQLite connections CAS, rollback, durable idempotency and consistent WAL backup',
      () {
        final snap = a.read(),
            payload = command('request_0001', a.read().revision);
        final first = submitStaffOrder(a, payload);
        expect(first['orderId'], 1200);
        expect(submitStaffOrder(b, payload), first);
        expect(a.read().data['orders'], hasLength(1));
        expect(a.replace(snap.data, snap.revision).ok, false);
        final order = asMaps(a.read().data['orders']).single;
        expect(orderTotalCents(order), 10001);
        expect(asMaps(order['batches']).first['staff'], 'Mehmet');
        expect(
          () => submitStaffOrder(b, command('request_0002', snap.revision)),
          throwsA(isA<StaffConflict>()),
        );
        final before = a.read().revision;
        expect(
          () => a.command('request_fail', {}, (s) {
            s['orders'] = [];
            throw const FormatException('stop');
          }),
          throwsFormatException,
        );
        expect(a.read().revision, before);
        expect(a.read().data['orders'], hasLength(1));
        expect(
          () => submitStaffOrder(a, {...payload, 'table': 2}),
          throwsFormatException,
        );
        final backup = '${folder.path}/backup.sqlite3';
        a.backup(backup);
        final restored = PosStore(databaseFile: backup);
        expect(restored.read().revision, before);
        expect(restored.read().data['orders'], hasLength(1));
        restored.dispose();
      },
    );
    test(
      'inactive employee cannot submit; active table additions are merged; financial payload ignored',
      () {
        final first = submitStaffOrder(
          a,
          command('request_0001', a.read().revision),
        );
        submitStaffOrder(b, {
          ...command('request_0002', a.read().revision),
          'payments': [
            {'amount': 99999},
          ],
        });
        final order = asMaps(a.read().data['orders']).single;
        expect(order['id'], first['orderId']);
        expect(order['batches'], hasLength(2));
        expect(order['payments'], isEmpty);
        final snap = a.read(), s = copyJson(snap.data);
        saveEmployee(s, 2, 'Mehmet', 'Personel', false);
        a.replace(s, snap.revision);
        expect(
          () => submitStaffOrder(a, command('request_0003', a.read().revision)),
          throwsFormatException,
        );
      },
    );
    test(
      'simultaneous HTTP requests produce one commit and conflict, replay stays idempotent',
      () async {
        final server = PosLanServer(a, port: 0, staffHtml: '<h1>Personel</h1>');
        await server.start();
        expect(server.running, true, reason: server.error);
        final client = HttpClient();
        Future<(int, Json)> post(Json p) async {
          final req = await client.postUrl(
            Uri.parse('http://127.0.0.1:${server.port}/api/staff/orders'),
          );
          req.headers.contentType = ContentType.json;
          req.write(jsonEncode(p));
          final response = await req.close(),
              body = await response.transform(utf8.decoder).join();
          return (
            response.statusCode,
            Map<String, dynamic>.from(jsonDecode(body) as Map),
          );
        }

        try {
          final revision = a.read().revision,
              p = command('http_req_0001', a.read().revision);
          final results = await Future.wait([
            post(p),
            post(command('http_req_0002', revision)),
          ]);
          expect(results.map((r) => r.$1).toSet(), {200, 409});
          expect(a.read().data['orders'], hasLength(1));
          final winner = results[0].$1 == 200
              ? p
              : command('http_req_0002', revision);
          expect((await post(winner)).$1, 200);
          expect(a.read().data['orders'], hasLength(1));
          final put = await client.putUrl(
            Uri.parse('http://127.0.0.1:${server.port}/api/state'),
          );
          put.write('{}');
          final denied = await put.close();
          expect(denied.statusCode, 405);
          await denied.drain<void>();
          final get = await client.getUrl(
            Uri.parse('http://127.0.0.1:${server.port}/personel'),
          );
          expect(
            await (await get.close()).transform(utf8.decoder).join(),
            contains('Personel'),
          );
        } finally {
          client.close(force: true);
          await server.stop();
          server.dispose();
        }
      },
    );
  });
}
