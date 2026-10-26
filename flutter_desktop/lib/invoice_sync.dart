import 'dart:convert';
import 'dart:math';
import 'pos_store.dart';
import 'pos_logic.dart';
import 'operations.dart';
import 'platform_api.dart';
import 'invoice_documents.dart';

class InvoiceSync {
  InvoiceSync(this.store, this.api);
  final PosStore store;
  final RestaurantApi api;
  String token() => base64UrlEncode(
    List.generate(24, (_) => Random.secure().nextInt(256)),
  ).replaceAll('=', '');
  Future<void> runSource(PlatformCredentials credentials) async {
    if (!credentials.configured ||
        !credentials.confirmed ||
        credentials.mode == 'off') {
      return;
    }
    for (final saved in invoiceJobs(store.read().data).where(
      (j) => j['source'] == credentials.source && j['status'] == 'Bekliyor',
    )) {
      final claim = token(), id = '${saved['id']}';
      final result = store.command('invoice_claim_$claim', {'id': id}, (s) {
        final j = mutableInvoiceJob(s, id);
        if (j['status'] != 'Bekliyor') return {'send': false};
        final o = mutableOrder(s, j['orderId'] as int)!;
        if (!credentials.configured ||
            !credentials.confirmed ||
            credentials.mode == 'off') {
          return {'send': false};
        }
        if (credentials.scope != j['scope'] ||
            credentials.mode != j['mode'] ||
            o['integrationScope'] != credentials.scope ||
            o['cancelled'] == true ||
            invoiceOrderFingerprint(o) != j['orderFingerprint']) {
          j['status'] = 'Hata';
          j['error'] =
              'Hesap, ortam veya sipariş revizyonu değişti. Gönderilmedi.';
          return {'send': false};
        }
        j['status'] = 'Gönderiliyor';
        j['claim'] = claim;
        j['attempts'] = (j['attempts'] as int) + 1;
        return {
          'send': true,
          'providerOrderId': j['providerOrderId'],
          'url': j['url'],
        };
      });
      if (result['send'] != true) continue;
      var status = 'Başarılı', error = '';
      DateTime? retry;
      try {
        await api.sendInvoiceLink(
          credentials,
          '${result['providerOrderId']}',
          '${result['url']}',
        );
      } on IntegrationFailure catch (e) {
        status = e.uncertain ? 'Belirsiz' : 'Hata';
        error = e.message;
        retry = e.retryAfter;
      } catch (_) {
        status = 'Belirsiz';
        error = 'Platform sonucu bilinmiyor; tekrar göndermeden doğrulayın.';
      }
      store.command('invoice_result_$claim', {'id': id, 'status': status}, (s) {
        final j = mutableInvoiceJob(s, id);
        if (j['claim'] != claim || j['status'] != 'Gönderiliyor') return {};
        j['status'] = status;
        j['error'] = error;
        j['retryAt'] = retry?.toIso8601String();
        (j.putIfAbsent('audit', () => <dynamic>[]) as List).add({
          'at': utcNow(),
          'actor': 'Kasa (PC)',
          'result': status,
          'attempt': j['attempts'],
        });
        return {};
      });
    }
  }
}
