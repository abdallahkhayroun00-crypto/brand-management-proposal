import 'pos_logic.dart';
import 'pos_store.dart';
import 'order_actions.dart';

class StaffConflict implements Exception {
  const StaffConflict();
}

/// Server owns prices, active-worker checks, table merging and kitchen jobs.
/// Phones submit intentions; no employee endpoint accepts financial state.
Json submitStaffOrder(
  PosStore store,
  Json payload, {
  StaffPrincipal? principal,
  StaffAuth? auth,
}) {
  final id = payload['requestId'];
  if (id is! String) throw const FormatException('İstek kimliği gerekli');
  if (principal != null) auth!.validatePrincipal(principal);
  final commandId = principal == null ? id : auth!.commandKey(principal, id);
  final authoritative = {
    ...payload,
    if (principal != null) 'staffId': principal.employeeId,
  };
  return store.command(commandId, authoritative, (s) {
    if (principal != null) auth!.validatePrincipal(principal);
    if (payload['expectedRevision'] != store.read().revision) {
      throw const StaffConflict();
    }
    final staff = asMaps(s['employees'])
        .where(
          (e) => e['id'] == authoritative['staffId'] && e['active'] == true,
        )
        .firstOrNull;
    if (staff == null) throw const FormatException('Aktif personel seçin');
    final source = payload['source'];
    if (!['Masa', 'Gel-Al'].contains(source)) {
      throw const FormatException('Telefon siparişleri Gel-Al; kurye yok');
    }
    final table = payload['table'];
    if (source == 'Masa' && (table is! int || table < 1 || table > 5)) {
      throw const FormatException('Masa 1–5');
    }
    if (payload['lines'] is! List ||
        (payload['lines'] as List).isEmpty ||
        (payload['lines'] as List).length > 200) {
      throw const FormatException('Ürün seçin');
    }
    if (asMaps(payload['lines']).length != (payload['lines'] as List).length) {
      throw const FormatException('Geçersiz ürün satırı');
    }
    final lines = <Json>[];
    for (final row in asMaps(payload['lines'])) {
      final p = asMaps(s['localMenu'])
          .where((p) => p['id'] == row['productId'] && p['price'] is num)
          .firstOrNull;
      if (p == null ||
          row['qty'] is! int ||
          (row['qty'] as int) < 1 ||
          (row['qty'] as int) > 1000 ||
          (row['removed'] != null &&
              (row['removed'] is! List ||
                  (row['removed'] as List).any((v) => v is! String)))) {
        throw const FormatException('Ürün / adet / malzeme geçersiz');
      }
      if ((row['note'] != null && row['note'] is! String) ||
          '${row['note'] ?? ''}'.length > 500) {
        throw const FormatException('Not çok uzun');
      }
      lines.add({
        'productId': p['id'],
        'productKey': p['name'],
        'name': p['name'],
        'price': p['price'],
        'qty': row['qty'],
        'removed': row['removed'] ?? [],
        'note': row['note'] ?? '',
      });
    }
    final existing = source == 'Masa' ? activeTable(s, table as int) : null;
    Json order;
    if (existing != null) {
      addOrderBatch(s, existing['id'] as int, lines);
      order = mutableOrder(s, existing['id'] as int)!;
      final batch = (order['batches'] as List).last as Map;
      batch['staff'] = staff['name'];
      batch['staffId'] = staff['id'];
    } else {
      order = newLocalOrder(
        state: s,
        source: '$source',
        table: source == 'Masa' ? table as int : null,
        productLines: lines,
        cashier: '${staff['name']}',
        pickupChannel: '${payload['pickupChannel'] ?? 'Tezgahtan'}',
      );
      ((order['batches'] as List).first as Map)['staffId'] = staff['id'];
      final customer = payload['customer'];
      if (source == 'Gel-Al' && customer is Map) {
        for (final field in ['name', 'phone', 'time']) {
          if (customer[field] != null &&
              (customer[field] is! String ||
                  (customer[field] as String).length > 200)) {
            throw const FormatException('Müşteri bilgisi geçersiz');
          }
        }
        order['customer'] = {
          for (final field in ['name', 'phone', 'time'])
            field: customer[field] ?? '',
        };
      }
    }
    (s.putIfAbsent('activity', () => <dynamic>[]) as List).add({
      'id': commandId,
      'orderId': order['id'],
      'action': existing == null ? 'Sipariş Al' : 'Ek Sipariş',
      'actor':
          principal?.actor ??
          {'kind': 'staff', 'id': staff['id'], 'name': staff['name']},
      'at': DateTime.now().toUtc().toIso8601String(),
      'platformSync': 'Yerel',
    });
    return {'ok': true, 'orderId': order['id'], 'requestId': id};
  });
}

Json submitStaffReady(
  PosStore store,
  StaffAuth auth,
  StaffPrincipal p,
  Json payload,
) {
  auth.validatePrincipal(p);
  final id = payload['requestId'];
  if (id is! String || payload['orderId'] is! int) {
    throw const FormatException('İstek / sipariş gerekli');
  }
  return store.command(auth.commandKey(p, id), payload, (s) {
    auth.validatePrincipal(p);
    return requestOrderAction(s, payload['orderId'] as int, 'ready', p.actor);
  });
}

Json submitStaffRetry(
  PosStore store,
  StaffAuth auth,
  StaffPrincipal p,
  Json payload,
) {
  auth.validatePrincipal(p);
  final id = payload['requestId'];
  if (id is! String || payload['operationId'] is! String) {
    throw const FormatException('İşlem gerekli');
  }
  return store.command(auth.commandKey(p, id), payload, (s) {
    auth.validatePrincipal(p);
    retryOrderAction(s, payload['operationId'] as String, p.actor);
    return {'ok': true, 'operationId': payload['operationId']};
  });
}
