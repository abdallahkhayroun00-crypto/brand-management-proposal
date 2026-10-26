import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'operations.dart';
import 'pos_logic.dart';

/// An operator-supplied original, not a receipt recreated from order JSON.
void attachPlatformReceipt(
  Json state,
  int orderId,
  Uint8List bytes, {
  required String fileName,
  required bool matchesOrder,
}) {
  final order = mutableOrder(state, orderId);
  if (order == null || !isPlatform(order) || !matchesOrder) {
    throw const FormatException(
      'Platform fişi ve sipariş eşleşmesi doğrulanmalı.',
    );
  }
  if (bytes.length < 8 ||
      bytes.length > 5 * 1024 * 1024 ||
      ascii.decode(bytes.take(5).toList(), allowInvalid: true) != '%PDF-') {
    throw const FormatException('En fazla 5 MB orijinal PDF fişi seçin.');
  }
  final jobs = state.putIfAbsent('printJobs', () => <dynamic>[]) as List;
  final job = jobs
      .whereType<Map>()
      .where((j) => j['orderId'] == orderId && j['batchId'] == 1)
      .firstOrNull;
  if (job == null) {
    throw const FormatException('Sipariş yazdırma işi bulunamadı.');
  }
  if ([
        'İşaretlendi',
        'Simüle edildi',
        'Sürücüye Gönderildi',
        'Gönderiliyor',
        'Belirsiz',
      ].contains(job['state']) ||
      job['platformReceipt'] != null) {
    throw const FormatException(
      'Mevcut / tamamlanmış fiş değiştirilemez veya tekrar basılamaz.',
    );
  }
  job['platformReceipt'] = {
    'bytes': base64Encode(bytes),
    'sha256': sha256.convert(bytes).toString(),
    'fileName': fileName,
    'source': order['source'],
    'externalOrderId':
        order['platformSnapshot']?['orderId'] ?? order['platformPackageId'],
    'attachedAt': utcNow(),
    'actor': 'Kasa (PC)',
    'provenance': 'Platform panelinden indirildi · Kullanıcı beyanı',
  };
  job['state'] = 'Bekliyor';
}

Uint8List originalPlatformReceipt(Json job) {
  final receipt = job['platformReceipt'];
  if (receipt is! Map) {
    throw const FormatException(
      'Platformun orijinal fişi henüz alınmadı. Nohut fişi üretilmez.',
    );
  }
  final bytes = base64Decode('${receipt['bytes']}');
  if (sha256.convert(bytes).toString() != receipt['sha256']) {
    throw const FormatException('Orijinal fiş bütünlük kontrolü başarısız.');
  }
  return bytes;
}
