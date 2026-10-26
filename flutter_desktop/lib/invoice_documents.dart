import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'operations.dart';
import 'pos_logic.dart';

List<Json> invoiceDocuments(Json s) => asMaps(s['invoiceDocuments']);
List<Json> invoiceJobs(Json s) => asMaps(s['invoiceJobs']);
String invoiceOrderFingerprint(Json o) => sha256
    .convert(
      utf8.encode(
        jsonEncode({
          'source': o['source'],
          'scope': o['integrationScope'],
          'providerOrderId': o['platformSnapshot']?['orderId'],
          'totalCents': orderTotalCents(o),
          'lines': [
            for (final l in checkLines(o))
              {
                'name': l.line['name'],
                'qty': l.line['qty'],
                'unitCents': cents(l.line['price']),
              },
          ],
        }),
      ),
    )
    .toString();
Uri invoiceUri(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      uri.host == 'localhost' ||
      uri.host == '127.0.0.1' ||
      uri.host == '::1') {
    throw const FormatException(
      'Kalıcı, herkese erişilebilir HTTPS belge bağlantısı gerekli.',
    );
  }
  return uri;
}

/// Records a document already issued outside this app. This does not issue,
/// sign, validate, cancel or number a Turkish fiscal invoice.
Json registerInvoice(
  Json s,
  int orderId, {
  required String number,
  required String ettn,
  required int amountCents,
  required String issuedAt,
  required String url,
  required bool externallyIssued,
  required String provider,
}) {
  final o =
      mutableOrder(s, orderId) ??
      (throw const FormatException('Sipariş bulunamadı.'));
  if (!externallyIssued ||
      number.trim().isEmpty ||
      provider.trim().isEmpty ||
      !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(ettn.trim()) ||
      DateTime.tryParse(issuedAt) == null ||
      amountCents <= 0) {
    throw const FormatException(
      'Harici düzenlenmiş belge no, ETTN, sağlayıcı, tarih ve tutar gerekli.',
    );
  }
  if (o['cancelled'] == true) {
    throw const FormatException(
      'İptal sipariş için yeni belge eşlenmez. Mevcut belgenin yasal işlemleri sağlayıcıdan yapılır.',
    );
  }
  if (amountCents != orderTotalCents(o)) {
    throw const FormatException(
      'Belge tutarı restoran sipariş tutarıyla eşleşmiyor. Platform teslimat / hizmet bedeli eklenmez.',
    );
  }
  if (invoiceDocuments(s).any(
    (d) =>
        d['orderId'] == orderId ||
        '${d['ettn']}'.toLowerCase() == ettn.trim().toLowerCase(),
  )) {
    throw const FormatException(
      'Bu sipariş / ETTN zaten kayıtlı. İkinci satış faturası oluşturulmadı.',
    );
  }
  final validatedUrl = url.trim().isEmpty ? '' : invoiceUri(url).toString();
  final docs = s.putIfAbsent('invoiceDocuments', () => <dynamic>[]) as List;
  final record = <String, dynamic>{
    'id': 'DOC-${docs.length + 1}',
    'orderId': orderId,
    'source': o['source'],
    'number': number.trim(),
    'ettn': ettn.trim().toLowerCase(),
    'amountCents': amountCents,
    'issuedAt': issuedAt,
    'url': validatedUrl,
    'provider': provider.trim(),
    'registeredAt': utcNow(),
    'registeredBy': 'Kasa (PC)',
    'status': 'Harici belge kaydı · Kullanıcı beyanı',
    'orderRevision': o['platformRevision'],
    'orderFingerprint': invoiceOrderFingerprint(o),
    'orderTotalAtRegistration': orderTotalCents(o),
  };
  docs.add(record);
  return record;
}

Json queueInvoiceLink(
  Json s,
  String documentId, {
  required bool retentionConfirmed,
}) {
  final d =
      invoiceDocuments(s).where((d) => d['id'] == documentId).firstOrNull ??
      (throw const FormatException('Belge bulunamadı.'));
  final o = mutableOrder(s, d['orderId'] as int)!;
  if (o['source'] != 'Trendyol Go') {
    throw const FormatException(
      'Yemeksepeti fatura yükleme API sözleşmesi doğrulanmadı. Partner paneli üzerinden işlem yapılmalı.',
    );
  }
  if (!retentionConfirmed) {
    throw const FormatException(
      'Bağlantının 10 yıl erişilebilir tutulacağını doğrulayın.',
    );
  }
  invoiceUri('${d['url']}');
  if (!['stage', 'live'].contains(o['integrationMode']) ||
      '${o['integrationScope'] ?? ''}'.isEmpty) {
    throw const FormatException(
      'DEMO sipariş gerçek fatura API’sine gönderilemez.',
    );
  }
  if (o['cancelled'] == true ||
      o['demoRemoteStatus'] == 'Created' ||
      d['amountCents'] != orderTotalCents(o) ||
      d['orderFingerprint'] != invoiceOrderFingerprint(o)) {
    throw const FormatException(
      'Sipariş durumu / tutarı / revizyonu değişti. Harici belgeyi doğrulayın.',
    );
  }
  final target = '${o['platformSnapshot']?['orderId'] ?? ''}';
  if (!RegExp(r'^[A-Za-z0-9_-]{1,150}$').hasMatch(target)) {
    throw const FormatException(
      'Platform orderId eksik. Paket ID / yerel sipariş ID yerine kullanılmaz.',
    );
  }
  final existing = invoiceJobs(
    s,
  ).where((j) => j['documentId'] == documentId).firstOrNull;
  if (existing != null) return existing;
  final jobs = s.putIfAbsent('invoiceJobs', () => <dynamic>[]) as List;
  final j = <String, dynamic>{
    'id': 'INVLINK-${jobs.length + 1}',
    'documentId': documentId,
    'orderId': o['id'],
    'providerOrderId': target,
    'source': o['source'],
    'mode': o['integrationMode'],
    'scope': o['integrationScope'],
    'url': d['url'],
    'status': 'Bekliyor',
    'attempts': 0,
    'createdAt': utcNow(),
    'actor': 'Kasa (PC)',
    'retentionConfirmed': true,
    'orderRevision': o['platformRevision'],
    'orderFingerprint': invoiceOrderFingerprint(o),
  };
  jobs.add(j);
  return j;
}

Map<dynamic, dynamic> mutableInvoiceJob(Json s, String id) =>
    (s['invoiceJobs'] as List? ?? []).whereType<Map>().firstWhere(
      (j) => j['id'] == id,
    );
void retryInvoiceLink(Json s, String id) {
  final j = mutableInvoiceJob(s, id);
  if (j['status'] != 'Hata') {
    throw const FormatException(
      'Başarılı / belirsiz işlem yeniden gönderilemez.',
    );
  }
  final retry = DateTime.tryParse('${j['retryAt']}');
  if (retry != null && retry.isAfter(DateTime.now().toUtc())) {
    throw const FormatException('Platform bekleme süresi dolmadı.');
  }
  j['status'] = 'Bekliyor';
  j['error'] = '';
}

void reconcileInvoiceLink(
  Json s,
  String id, {
  required bool delivered,
  required String reason,
}) {
  final j = mutableInvoiceJob(s, id);
  if (j['status'] != 'Belirsiz' || reason.trim().isEmpty) {
    throw const FormatException(
      'Belirsiz işlem ve platform kontrol açıklaması gerekli.',
    );
  }
  j['status'] = delivered ? 'Başarılı (elle doğrulandı)' : 'Hata';
  j['error'] = delivered ? '' : 'Platformta bulunmadığı elle doğrulandı';
  (j.putIfAbsent('audit', () => <dynamic>[]) as List).add({
    'at': utcNow(),
    'actor': 'Kasa (PC)',
    'result': j['status'],
    'reason': reason.trim(),
  });
}
