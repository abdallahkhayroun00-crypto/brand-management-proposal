import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:nohut_falafel_desktop/pos_store.dart';
import 'package:nohut_falafel_desktop/pos_logic.dart';
import 'package:nohut_falafel_desktop/operations.dart';
import 'package:nohut_falafel_desktop/platform_workflows.dart';
import 'package:nohut_falafel_desktop/platform_api.dart';
import 'package:nohut_falafel_desktop/ticket_document.dart';
import 'package:nohut_falafel_desktop/ticket_pdf.dart';
import 'package:nohut_falafel_desktop/print_service.dart';
import 'package:nohut_falafel_desktop/invoice_documents.dart';
import 'package:nohut_falafel_desktop/invoice_sync.dart';
import 'package:nohut_falafel_desktop/platform_runtime.dart';
import 'package:nohut_falafel_desktop/platform_receipt.dart';

class FakePrinter implements PrinterGateway {
  int calls = 0;
  Future<bool> Function()? result;
  @override
  Future<bool> send(
    PrintableTicket document,
    String printerUrl,
    String name,
  ) async {
    calls++;
    return result == null ? true : result!();
  }
}

class InvoiceTransport extends ApiTransport {
  final calls = <Json>[];
  Future<ApiReply> Function()? result;
  @override
  Future<ApiReply> call(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    Object? body,
    bool form = false,
  }) async {
    calls.add({
      'method': method,
      'url': url.toString(),
      'headers': headers,
      'body': body,
    });
    return result == null ? const ApiReply(201, null) : result!();
  }
}

class NoSecrets implements SecretStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

PlatformCredentials credentials({
  String supplier = '123',
  String mode = 'stage',
}) => PlatformCredentials('Trendyol Go', {
  'mode': mode,
  'programConfirmed': true,
  'supplierId': supplier,
  'storeId': '456',
  'apiKey': 'TEST_KEY',
  'apiSecret': 'TEST_SECRET',
  'executorEmail': 'test@example.invalid',
});
Json localState() {
  final s = emptyPosState();
  newLocalOrder(
    state: s,
    source: 'Masa',
    table: 4,
    productLines: [
      {
        'name': 'Falafel Dürüm',
        'qty': 2,
        'price': 140,
        'removed': ['Soğan'],
        'note': 'Acısız · Sos ayrı',
      },
    ],
  );
  s['settings'] = {
    'printerMode': 'windows',
    'printerCount': 1,
    'printerUrl': 'TEST_USB_DRIVER',
  };
  return s;
}

Json remoteState(PlatformCredentials c) {
  final s = emptyPosState();
  s['localMenu'] = [
    {'id': 0, 'name': 'Falafel', 'price': 140, 'category': 'wrap'},
  ];
  seedPlatformMenu(s, asMaps(s['localMenu']));
  final packet = platformFixture(s, 'Trendyol Go', 'card');
  packet['orderId'] = 'REMOTE_ORDER_901';
  packet['integrationScope'] = c.scope;
  packet['status'] = 'Picking';
  final o = importPlatform(s, packet)!;
  o['integrationMode'] = c.mode;
  return s;
}

Json record(
  Json s, {
  String url = 'https://invoice.example.invalid/archived/document.pdf',
}) => registerInvoice(
  s,
  asMaps(s['orders']).first['id'] as int,
  number: 'NF2026000000001',
  ettn: '12345678-1234-4234-8234-123456789012',
  amountCents: orderTotalCents(asMaps(s['orders']).first),
  issuedAt: '2026-10-26',
  url: url,
  externallyIssued: true,
  provider: 'Test external provider',
);
Future<PrintableTicket> fakeRender(TicketDocument _) async => PrintableTicket(
  Uint8List.fromList([1, 2, 3]),
  const PdfPageFormat(227, 500),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'platform receipts retain original bytes, forbid replacement and reject local receipt generation',
    () async {
      final s = remoteState(credentials()), o = asMaps(s['orders']).first;
      final bytes = Uint8List.fromList(
        utf8.encode('%PDF-1.7\nfixture original bytes'),
      );
      final id = o['id'] as int;
      expect(
        () => attachPlatformReceipt(
          s,
          id,
          bytes,
          fileName: 'original.pdf',
          matchesOrder: false,
        ),
        throwsFormatException,
      );
      attachPlatformReceipt(
        s,
        id,
        bytes,
        fileName: 'original.pdf',
        matchesOrder: true,
      );
      final j = asMaps(s['printJobs']).first;
      expect(originalPlatformReceipt(j), bytes);
      expect(
        () => attachPlatformReceipt(
          s,
          id,
          bytes,
          fileName: 'second.pdf',
          matchesOrder: true,
        ),
        throwsFormatException,
      );
      await expectLater(
        TicketPdf.build(kitchenTicket(s, j)),
        throwsFormatException,
      );
      j['platformReceipt']['bytes'] = base64Encode([1, 2, 3]);
      expect(() => originalPlatformReceipt(j), throwsFormatException);
    },
  );
  test('platform dispatch without original PDF never enters driver', () async {
    final dir = Directory.systemTemp.createTempSync('nohut-platform-receipt-');
    final store = PosStore(databaseFile: '${dir.path}/db.sqlite3');
    addTearDown(() {
      store.dispose();
      dir.deleteSync(recursive: true);
    });
    final s = remoteState(credentials());
    s['settings'] = {'printerMode': 'windows', 'printerUrl': 'TEST_USB'};
    store.replace(s, 0);
    final gateway = FakePrinter();
    await expectLater(
      PrintService(
        store,
        gateway: gateway,
        render: fakeRender,
      ).print(printJobKey(asMaps(s['printJobs']).first)),
      throwsFormatException,
    );
    expect(gateway.calls, 0);
    expect(
      asMaps(store.read().data['printJobs']).first['state'],
      isNot('Gönderiliyor'),
    );
  });
  test(
    'invoice content fingerprint permits status updates but blocks price changes',
    () async {
      final dir = Directory.systemTemp.createTempSync('nohut-invoice-content-'),
          store = PosStore(databaseFile: '${dir.path}/db.sqlite3');
      addTearDown(() {
        store.dispose();
        dir.deleteSync(recursive: true);
      });
      final c = credentials(), s = remoteState(c), d = record(s);
      queueInvoiceLink(s, '${d['id']}', retentionConfirmed: true);
      final o = mutableOrder(s, d['orderId'] as int)!;
      o['platformRevision'] = (o['platformRevision'] as int) + 1;
      o['demoRemoteStatus'] = 'Delivered';
      store.replace(s, 0);
      final transport = InvoiceTransport();
      await InvoiceSync(store, RestaurantApi(transport)).runSource(c);
      expect(transport.calls, hasLength(1));
      expect(invoiceJobs(store.read().data).single['status'], 'Başarılı');
      final changed = remoteState(c), changedDoc = record(changed);
      queueInvoiceLink(
        changed,
        '${changedDoc['id']}',
        retentionConfirmed: true,
      );
      mutableOrder(
        changed,
        changedDoc['orderId'] as int,
      )!['platformSnapshot']['orderTotal'] = 1;
      store.replace(changed, store.read().revision);
      transport.calls.clear();
      await InvoiceSync(store, RestaurantApi(transport)).runSource(c);
      expect(transport.calls, isEmpty);
      expect(invoiceJobs(store.read().data).single['status'], 'Hata');
    },
  );
  test(
    'interrupted invoice dispatch becomes uncertain after restart and is never auto-replayed',
    () async {
      final dir = Directory.systemTemp.createTempSync('nohut-invoice-restart-'),
          file = '${dir.path}/db.sqlite3';
      var store = PosStore(databaseFile: file);
      final c = credentials(),
          s = remoteState(c),
          d = record(s),
          job = queueInvoiceLink(s, '${d['id']}', retentionConfirmed: true);
      mutableInvoiceJob(s, '${job['id']}')['status'] = 'Gönderiliyor';
      store.replace(s, 0);
      store.dispose();
      store = PosStore(databaseFile: file);
      final transport = InvoiceTransport(),
          runtime = PlatformRuntime(
            store,
            CredentialVault(NoSecrets()),
            transport: transport,
          );
      runtime.start();
      await Future<void>.delayed(Duration.zero);
      expect(invoiceJobs(store.read().data).single['status'], 'Belirsiz');
      await runtime.invoiceSync.runSource(c);
      expect(transport.calls, isEmpty);
      runtime.dispose();
      store.dispose();
      dir.deleteSync(recursive: true);
    },
  );
  test(
    'new, added and correction tickets are immutable snapshots; kitchen omits customer/payment data',
    () {
      final dir = Directory.systemTemp.createTempSync('nohut-tickets-'),
          store = PosStore(databaseFile: '${dir.path}/db.sqlite3');
      addTearDown(() {
        store.dispose();
        dir.deleteSync(recursive: true);
      });
      final s = localState(), o = mutableOrder(s, 1200)!;
      o['customer'] = {'name': 'PRIVATE_CUSTOMER', 'phone': 'PRIVATE_PHONE'};
      expect(store.replace(s, 0).ok, isTrue);
      final next = store.read().data;
      addOrderBatch(next, 1200, [
        {
          'name': 'Büyük Ayran',
          'qty': 2,
          'price': 40,
          'removed': [],
          'note': '',
        },
        {'name': 'Şalgam', 'qty': 1, 'price': 35, 'removed': [], 'note': ''},
      ]);
      cancelProduct(next, 1200, '1:0', 1, 'Müşteri iptali');
      expect(store.replace(next, 1).ok, isTrue);
      final saved = store.read().data, jobs = asMaps(saved['printJobs']);
      final initial = kitchenTicket(saved, jobs[0]),
          addition = kitchenTicket(saved, jobs[1]),
          correction = kitchenTicket(saved, jobs[2]);
      expect(initial.lines.single.quantity, 2);
      expect(initial.totalCents, 28000);
      expect(addition.kind, TicketKind.addition);
      expect(addition.reference, '#1200-1');
      expect(addition.totalCents, 11500);
      expect(addition.quantity, 3);
      expect(
        addition.lines.map((l) => l.name),
        isNot(contains('Falafel Dürüm')),
      );
      expect(correction.kind, TicketKind.correction);
      expect(correction.lines.single.quantity, 1);
      expect(jsonEncode(initial.toJson()), isNot(contains('PRIVATE_')));
      expect(initial.payments, isEmpty);
      expect(billDocument(mutableOrder(saved, 1200)!).totalCents, 25500);
    },
  );
  test(
    '80 mm PDF embeds Turkish fonts and uses finite roll height; long orders split without duplicating lines',
    () async {
      final s = localState(),
          ticket = kitchenTicket(s, asMaps(s['printJobs']).first);
      final pdf = await TicketPdf.render(ticket);
      expect(ascii.decode(pdf.bytes.take(4).toList()), '%PDF');
      expect(pdf.format.width, closeTo(80 * PdfPageFormat.mm, .01));
      expect(pdf.format.height.isFinite, isTrue);
      expect(pdf.format.height, greaterThan(200));
      final longer = TicketDocument.fromJson({
        ...ticket.toJson(),
        'lines': List.generate(
          45,
          (i) => TicketLine(
            name: 'Ürün $i',
            quantity: 1,
            amountCents: 100,
            note: 'Çıkar: Soğan · Acısız',
          ).toJson(),
        ),
        'totalCents': 4500,
      });
      final bytes = await TicketPdf.build(longer);
      expect(bytes.length, greaterThan(pdf.bytes.length));
    },
  );
  test(
    'one printer claim blocks another store and completed ticket cannot be replayed',
    () async {
      final dir = Directory.systemTemp.createTempSync('nohut-print-'),
          file = '${dir.path}/db.sqlite3';
      final a = PosStore(databaseFile: file), b = PosStore(databaseFile: file);
      addTearDown(() {
        a.dispose();
        b.dispose();
        dir.deleteSync(recursive: true);
      });
      a.replace(localState(), 0);
      final pending = Completer<bool>(), entered = Completer<void>();
      final gateway = FakePrinter()
        ..result = () {
          entered.complete();
          return pending.future;
        };
      final one = PrintService(a, gateway: gateway, render: fakeRender),
          otherGateway = FakePrinter(),
          two = PrintService(b, gateway: otherGateway, render: fakeRender);
      final future = one.print('1200:1');
      await entered.future;
      await expectLater(two.print('1200:1'), throwsFormatException);
      expect(
        () => two.reconcile('1200:1', outputExists: false, reason: 'Too early'),
        throwsFormatException,
      );
      expect(otherGateway.calls, 0);
      pending.complete(true);
      expect(await future, 'Sürücüye Gönderildi');
      await expectLater(two.print('1200:1'), throwsFormatException);
      expect(gateway.calls, 1);
      final j = asMaps(a.read().data['printJobs']).single;
      expect(j['attempts'], 1);
      expect('${j['pdfSha256']}', hasLength(64));
    },
  );
  test(
    'unknown printer result survives reopen and requires explicit reconciliation before retry',
    () async {
      final dir = Directory.systemTemp.createTempSync('nohut-unknown-print-'),
          file = '${dir.path}/db.sqlite3';
      var store = PosStore(databaseFile: file);
      store.replace(localState(), 0);
      final gateway = FakePrinter()
        ..result = () async => throw TimeoutException('test');
      expect(
        await PrintService(
          store,
          gateway: gateway,
          render: fakeRender,
        ).print('1200:1'),
        'Belirsiz',
      );
      store.dispose();
      store = PosStore(databaseFile: file);
      addTearDown(() {
        store.dispose();
        dir.deleteSync(recursive: true);
      });
      final successful = FakePrinter(),
          service = PrintService(
            store,
            gateway: successful,
            render: fakeRender,
          );
      await expectLater(service.print('1200:1'), throwsFormatException);
      expect(successful.calls, 0);
      expect(
        () => service.reconcile('1200:1', outputExists: false, reason: ''),
        throwsFormatException,
      );
      service.reconcile(
        '1200:1',
        outputExists: false,
        reason: 'Windows kuyruğu ve kâğıt kontrol edildi; çıktı yok.',
      );
      expect(await service.print('1200:1'), 'Sürücüye Gönderildi');
      expect(successful.calls, 1);
    },
  );
  test(
    'PDF failure never enters the driver; cancellation is retryable without marking output complete',
    () async {
      final dir = Directory.systemTemp.createTempSync('nohut-print-cancel-'),
          store = PosStore(databaseFile: '${dir.path}/db.sqlite3');
      addTearDown(() {
        store.dispose();
        dir.deleteSync(recursive: true);
      });
      store.replace(localState(), 0);
      final gateway = FakePrinter()..result = () async => false;
      expect(
        await PrintService(
          store,
          gateway: gateway,
          render: (_) async => throw const FormatException('test'),
        ).print('1200:1'),
        'Hata',
      );
      expect(gateway.calls, 0);
      expect(
        await PrintService(
          store,
          gateway: gateway,
          render: fakeRender,
        ).print('1200:1'),
        'Bekliyor',
      );
      expect(gateway.calls, 1);
    },
  );
  test(
    'external document registration validates amount, ETTN, issuance attestation and duplicate order',
    () {
      final s = localState();
      expect(
        () => registerInvoice(
          s,
          1200,
          number: 'X',
          ettn: 'not-a-uuid',
          amountCents: 28000,
          issuedAt: '2026-10-26',
          url: '',
          externallyIssued: true,
          provider: 'Test',
        ),
        throwsFormatException,
      );
      expect(
        () => registerInvoice(
          s,
          1200,
          number: 'X',
          ettn: '12345678-1234-4234-8234-123456789012',
          amountCents: 1,
          issuedAt: '2026-10-26',
          url: '',
          externallyIssued: true,
          provider: 'Test',
        ),
        throwsFormatException,
      );
      record(s);
      expect(() => record(s), throwsFormatException);
      expect(invoiceDocuments(s), hasLength(1));
      expect(asMaps(s['orders']).first['payments'], isEmpty);
    },
  );
  test(
    'Meal invoice upload uses remote orderId and channel 4, persists success and never repeats',
    () async {
      final dir = Directory.systemTemp.createTempSync('nohut-invoice-'),
          store = PosStore(databaseFile: '${dir.path}/db.sqlite3');
      addTearDown(() {
        store.dispose();
        dir.deleteSync(recursive: true);
      });
      final c = credentials(), s = remoteState(c), d = record(s);
      final job = queueInvoiceLink(s, '${d['id']}', retentionConfirmed: true);
      expect(
        queueInvoiceLink(s, '${d['id']}', retentionConfirmed: true)['id'],
        job['id'],
      );
      expect(invoiceJobs(s), hasLength(1));
      store.replace(s, 0);
      final transport = InvoiceTransport(),
          sync = InvoiceSync(store, RestaurantApi(transport));
      await sync.runSource(c);
      await sync.runSource(c);
      expect(transport.calls, hasLength(1));
      expect(transport.calls.single['method'], 'POST');
      expect(
        transport.calls.single['url'],
        'https://stageapi.tgoapis.com/integrator/invoice/meal/suppliers/123/supplier-invoice-links/4/REMOTE_ORDER_901',
      );
      expect(transport.calls.single['body'], {'invoiceLink': d['url']});
      expect(invoiceJobs(store.read().data).single['status'], 'Başarılı');
      expect(jsonEncode(store.read().data), isNot(contains('TEST_SECRET')));
    },
  );
  test(
    'invoice safeguards block demo, missing remote ID, missing retention and changed account',
    () async {
      final c = credentials(), s = remoteState(c), d = record(s);
      expect(
        () => queueInvoiceLink(s, '${d['id']}', retentionConfirmed: false),
        throwsFormatException,
      );
      final o = mutableOrder(s, d['orderId'] as int)!;
      o['integrationMode'] = 'demo';
      expect(
        () => queueInvoiceLink(s, '${d['id']}', retentionConfirmed: true),
        throwsFormatException,
      );
      o['integrationMode'] = 'stage';
      (o['platformSnapshot'] as Map).remove('orderId');
      expect(
        () => queueInvoiceLink(s, '${d['id']}', retentionConfirmed: true),
        throwsFormatException,
      );
      (o['platformSnapshot'] as Map)['orderId'] = 'REMOTE_ORDER_901';
      queueInvoiceLink(s, '${d['id']}', retentionConfirmed: true);
      final dir = Directory.systemTemp.createTempSync('nohut-scope-invoice-'),
          store = PosStore(databaseFile: '${dir.path}/db.sqlite3');
      addTearDown(() {
        store.dispose();
        dir.deleteSync(recursive: true);
      });
      store.replace(s, 0);
      final transport = InvoiceTransport();
      await InvoiceSync(
        store,
        RestaurantApi(transport),
      ).runSource(credentials(supplier: '999'));
      expect(transport.calls, isEmpty);
      expect(invoiceJobs(store.read().data).single['status'], 'Hata');
    },
  );
  test(
    'invoice 503 is uncertain; 429 requires timed explicit retry; Yemeksepeti has no invented route',
    () async {
      final dir = Directory.systemTemp.createTempSync('nohut-retry-invoice-'),
          store = PosStore(databaseFile: '${dir.path}/db.sqlite3');
      addTearDown(() {
        store.dispose();
        dir.deleteSync(recursive: true);
      });
      final c = credentials(),
          s = remoteState(c),
          d = record(s),
          j = queueInvoiceLink(s, '${d['id']}', retentionConfirmed: true);
      store.replace(s, 0);
      final transport = InvoiceTransport()
        ..result = () async => const ApiReply(503, {});
      final sync = InvoiceSync(store, RestaurantApi(transport));
      await sync.runSource(c);
      await sync.runSource(c);
      expect(transport.calls, hasLength(1));
      expect(invoiceJobs(store.read().data).single['status'], 'Belirsiz');
      expect(
        () => retryInvoiceLink(store.read().data, '${j['id']}'),
        throwsFormatException,
      );
      final next = store.read();
      final changed = next.data;
      reconcileInvoiceLink(
        changed,
        '${j['id']}',
        delivered: false,
        reason: 'Partner paneli / destek doğrulaması',
      );
      store.replace(changed, next.revision);
      final retry = store.read();
      retryInvoiceLink(retry.data, '${j['id']}');
      store.replace(retry.data, retry.revision);
      transport.result = () async => ApiReply(
        429,
        {},
        retryAfter: DateTime.now().toUtc().add(const Duration(minutes: 1)),
      );
      await sync.runSource(c);
      expect(invoiceJobs(store.read().data).single['status'], 'Hata');
      expect(
        () => retryInvoiceLink(store.read().data, '${j['id']}'),
        throwsFormatException,
      );
      await expectLater(
        RestaurantApi(transport).sendInvoiceLink(
          PlatformCredentials('Yemeksepeti', {'mode': 'off'}),
          'X',
          'https://example.invalid/doc.pdf',
        ),
        throwsA(isA<IntegrationFailure>()),
      );
      expect(transport.calls, hasLength(2));
    },
  );
}
