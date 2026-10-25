import 'pos_logic.dart';
import 'operations.dart';

const pcActor = <String, dynamic>{'kind': 'pc', 'name': 'Kasa (PC)'};
List<Json> orderOperations(Json s) => asMaps(s['orderOperations']);
Json operationById(Json s, String id) => (s['orderOperations'] as List)
    .cast<Map>()
    .firstWhere((j) => j['id'] == id)
    .cast<String, dynamic>();

/// Actor is supplied by native PC code or the validated server session, never
/// accepted from a phone JSON body. Semantic keys dedupe across phone requests.
Json requestOrderAction(
  Json s,
  int id,
  String action,
  Json actor, {
  int preparation = 20,
  int reason = 621,
}) {
  if (!['ready', 'accept', 'reject'].contains(action) ||
      !['pc', 'staff'].contains(actor['kind'])) {
    throw const FormatException('İşlem geçersiz');
  }
  if (action != 'ready' && actor['kind'] != 'pc') {
    throw const FormatException('Kabul / ret yalnızca Kasa (PC)');
  }
  final o = mutableOrder(s, id) ?? (throw const FormatException('Sipariş yok'));
  final key = isPlatform(o)
      ? '$id:$action'
      : '$id:$action:${asMaps(o['batches']).length}';
  final previous = orderOperations(s).where((j) => j['key'] == key).firstOrNull;
  if (previous != null) {
    return {
      'ok': true,
      'operationId': previous['id'],
      'status': previous['status'],
      'duplicate': true,
    };
  }
  if (o['closed'] == true || o['cancelled'] == true) {
    throw const FormatException('Hesap kapalı / iptal');
  }
  if (!isPlatform(o)) {
    if (action != 'ready' || o['serviceStatus'] != 'Hazırlanıyor') {
      throw const FormatException('Sipariş hazırlanmıyor');
    }
    setLocalService(o, 'Hazır');
  } else {
    final expected = action == 'ready' ? 'Picking' : 'Created';
    if (o['demoRemoteStatus'] != expected) {
      throw const FormatException(
        'Önce PC kabulü / güncel durum kontrol edilmeli',
      );
    }
    if (action == 'accept' && (preparation < 1 || preparation > 180)) {
      throw const FormatException('Hazırlık 1–180 dakika');
    }
    if (action == 'reject' && ![621, 622, 623, 627].contains(reason)) {
      throw const FormatException('İptal nedeni geçersiz');
    }
    if (action == 'ready') {
      o['kitchenReady'] = true;
      o['serviceStatus'] = 'Hazır';
    }
  }
  final list = s.putIfAbsent('orderOperations', () => <dynamic>[]) as List;
  final opId = 'OP-${s['nextOperationId'] ?? 1}';
  s['nextOperationId'] = (s['nextOperationId'] as int? ?? 1) + 1;
  final mode = isPlatform(o) ? '${o['integrationMode'] ?? 'demo'}' : 'local';
  final job = <String, dynamic>{
    'id': opId,
    'key': key,
    'orderId': id,
    'source': o['source'],
    'action': action,
    'actor': actor,
    'at': utcNow(),
    'mode': mode,
    'status': mode == 'local' ? 'Yerel' : 'Bekliyor',
    'attempts': 0,
    'expected': o['demoRemoteStatus'],
    'preparationTime': preparation,
    'reasonId': reason,
    'error': '',
    'nextAttemptAt': null,
  };
  list.add(job);
  (o['events'] as List).add(
    '${job['at']} · ${actor['name']} · ${action == 'ready'
        ? 'Sipariş Hazır'
        : action == 'accept'
        ? 'Kabul Et'
        : 'Reddet'} · ${job['status']}',
  );
  (s.putIfAbsent('activity', () => <dynamic>[]) as List).add({
    'id': opId,
    'orderId': id,
    'action': action == 'ready'
        ? 'Sipariş Hazır'
        : action == 'accept'
        ? 'Kabul Et'
        : 'Reddet',
    'actor': actor,
    'at': job['at'],
    'platformSync': job['status'],
  });
  return {'ok': true, 'operationId': opId, 'status': job['status']};
}

void retryOrderAction(Json s, String id, Json actor) {
  final j = operationById(s, id);
  if (actor['kind'] != 'pc' && j['action'] != 'ready') {
    throw const FormatException('Bu işlem PC yetkisi gerektirir');
  }
  if (j['status'] != 'Hata') {
    throw const FormatException(
      'Belirsiz / tamamlanmış işlem tekrar gönderilemez',
    );
  }
  final next = DateTime.tryParse('${j['nextAttemptAt']}');
  if (next != null && next.isAfter(DateTime.now())) {
    throw const FormatException('Yeniden deneme süresini bekleyin');
  }
  final o = mutableOrder(s, j['orderId'] as int);
  if (o == null || o['cancelled'] == true || o['closed'] == true) {
    throw const FormatException('Sipariş artık uygun değil');
  }
  j['status'] = 'Bekliyor';
  j['retryActor'] = actor;
}

void finishOrderAction(
  Json s,
  String id,
  String status, {
  String error = '',
  DateTime? retryAt,
}) {
  final j = operationById(s, id),
      o = mutableOrder(s, operationById(s, id)['orderId'] as int)!;
  j['status'] = status;
  j['error'] = error;
  j['nextAttemptAt'] = retryAt?.toUtc().toIso8601String();
  j['updatedAt'] = utcNow();
  if (status == 'Başarılı' || status == 'Simüle edildi') {
    if (o['closed'] != true && o['cancelled'] != true) {
      if (j['action'] == 'accept' && o['demoRemoteStatus'] == 'Created') {
        o['demoRemoteStatus'] = 'Picking';
        o['serviceStatus'] = 'Hazırlanıyor';
        for (final b in asMaps(o['batches'])) {
          final jobs = s['printJobs'] as List;
          if (!asMaps(
            jobs,
          ).any((p) => p['orderId'] == o['id'] && p['batchId'] == b['id'])) {
            jobs.add({
              'orderId': o['id'],
              'batchId': b['id'],
              'state': 'Bekliyor',
              'created': nowTime(),
            });
          }
        }
      }
      if (j['action'] == 'ready' && o['demoRemoteStatus'] == 'Picking') {
        o['demoRemoteStatus'] = 'Invoiced';
      }
      if (j['action'] == 'reject') {
        o['cancelled'] = true;
        o['closed'] = true;
        o['demoRemoteStatus'] = 'UnSupplied';
      }
    }
  }
  for (final a in (s['activity'] as List? ?? []).cast<Map>().where(
    (a) => a['id'] == id,
  )) {
    a['platformSync'] = status;
    a['error'] = error;
  }
  (o['events'] as List).add(
    '${utcNow()} · ${j['actor']['name']} · Platform Senkronizasyonu: $status${error.isEmpty ? '' : ' · $error'}',
  );
}

Json staffProjection(Json s) => {
  'localMenu': asMaps(s['localMenu']),
  'orders': [
    for (final o in asMaps(s['orders']))
      {
        'id': o['id'],
        'source': o['source'],
        'table': o['table'],
        'closed': o['closed'],
        'cancelled': o['cancelled'],
        'serviceStatus': o['serviceStatus'],
        'demoRemoteStatus': o['demoRemoteStatus'],
        'kitchenReady': o['kitchenReady'] == true,
        'batches': [
          for (final b in asMaps(o['batches']))
            {
              'id': b['id'],
              'staff': b['staff'],
              'lines': [
                for (final l in asMaps(b['lines']))
                  if (l['voided'] != true && l['correction'] != true)
                    {
                      'name': l['name'],
                      'qty': l['qty'],
                      'note': l['note'],
                      'removed': l['removed'] ?? [],
                    },
              ],
            },
        ],
        'operations': [
          for (final j in orderOperations(s).where(
            (j) =>
                j['orderId'] == o['id'] &&
                j['action'] == 'ready' &&
                (isPlatform(o) ||
                    j['key'] ==
                        '${o['id']}:ready:${asMaps(o['batches']).length}'),
          ))
            {
              'id': j['id'],
              'status': j['status'],
              'error': j['error'],
              'actor': j['actor']['name'],
              'at': j['at'],
              'nextAttemptAt': j['nextAttemptAt'],
            },
        ],
      },
  ],
};
