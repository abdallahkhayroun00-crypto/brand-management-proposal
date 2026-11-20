import 'operations.dart';
import 'pos_logic.dart';
import 'pos_store.dart';

enum TerminalStatus { approved, declined, cancelled, unknown, unavailable }

class TerminalReply {
  const TerminalReply(this.status, {this.transactionId, this.amountCents});
  final TerminalStatus status;
  final String? transactionId;
  final int? amountCents;
}

/// Implement using the vendor's authorized SDK. No network endpoint is guessed.
abstract interface class InposGateway {
  bool get ready;
  Future<TerminalReply> pay(String reference, int amountCents);
  Future<TerminalReply> inquire(String reference);
}

class UnavailableInpos implements InposGateway {
  @override
  bool get ready => false;
  @override
  Future<TerminalReply> pay(String reference, int amountCents) async =>
      const TerminalReply(TerminalStatus.unavailable);
  @override
  Future<TerminalReply> inquire(String reference) async =>
      const TerminalReply(TerminalStatus.unavailable);
}

/// Persist the reference before device I/O. Unknown outcomes are never resent.
class InposPayments {
  InposPayments(this.store, this.gateway);
  final PosStore store;
  final InposGateway gateway;
  Future<TerminalReply> pay(int orderId, int amount, String reference) async {
    if (!gateway.ready) return const TerminalReply(TerminalStatus.unavailable);
    store.command('start_$reference', {'orderId': orderId, 'amount': amount}, (
      s,
    ) {
      final o = mutableOrder(s, orderId);
      if (o == null) throw const FormatException('Sipariş yok');
      requireLocal(o);
      requireOpen(o);
      if (amount <= 0 ||
          amount > orderDueCents(o) ||
          asMaps(o['guestChecks']).isNotEmpty)
        throw const FormatException('Ödeme tutarı / kişi hesabı geçersiz');
      final attempts =
          s.putIfAbsent('terminalAttempts', () => <dynamic>[]) as List;
      if (attempts.whereType<Map>().any(
        (a) =>
            a['orderId'] == orderId &&
            ['waiting', 'unknown'].contains(a['status']),
      ))
        throw const FormatException(
          'Önce bekleyen terminal işlemini sorgulayın',
        );
      attempts.add({
        'reference': reference,
        'orderId': orderId,
        'amountCents': amount,
        'status': 'waiting',
      });
      o['terminalPending'] = reference;
      return {'ok': true};
    });
    // A retry must inquire, not call pay a second time with the same reference.
    final attempt = asMaps(
      store.read().data['terminalAttempts'],
    ).firstWhere((a) => a['reference'] == reference);
    if (attempt['dispatched'] == true) return reconcile(reference);
    final before = store.read(), next = copyJson(before.data);
    (next['terminalAttempts'] as List).cast<Map>().firstWhere(
      (a) => a['reference'] == reference,
    )['dispatched'] = true;
    if (!store.replace(next, before.revision).ok)
      throw const FormatException('Terminal durumu değişti');
    TerminalReply reply;
    try {
      reply = await gateway
          .pay(reference, amount)
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      reply = const TerminalReply(TerminalStatus.unknown);
    }
    return _apply(reference, reply);
  }

  Future<TerminalReply> reconcile(String reference) async {
    TerminalReply reply;
    try {
      reply = await gateway
          .inquire(reference)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      reply = const TerminalReply(TerminalStatus.unknown);
    }
    return _apply(reference, reply);
  }

  TerminalReply _apply(String reference, TerminalReply reply) {
    final snap = store.read(), s = copyJson(snap.data);
    final attempt = (s['terminalAttempts'] as List).cast<Map>().firstWhere(
      (a) => a['reference'] == reference,
    );
    if (attempt['status'] == 'approved')
      return TerminalReply(
        TerminalStatus.approved,
        transactionId: attempt['transactionId'] as String?,
        amountCents: attempt['amountCents'] as int,
      );
    final o = mutableOrder(s, attempt['orderId'] as int)!;
    if (reply.status == TerminalStatus.approved &&
        (reply.transactionId == null ||
            reply.transactionId!.isEmpty ||
            reply.amountCents != attempt['amountCents']))
      reply = const TerminalReply(TerminalStatus.unknown);
    if (reply.status == TerminalStatus.approved) {
      if (asMaps(s['terminalAttempts']).any(
        (a) =>
            a['reference'] != reference &&
            a['transactionId'] == reply.transactionId,
      ))
        throw const FormatException('Terminal işlemi zaten işlendi');
      o.remove('terminalPending');
      recordPayment(o, attempt['amountCents'] as int, 'Kart');
      ((o['payments'] as List).last as Map).addAll(<String, Object?>{
        'terminalReference': reference,
        'transactionId': reply.transactionId,
      });
      attempt['transactionId'] = reply.transactionId;
      finishPickupIfSettled(o);
    } else if ([
      TerminalStatus.declined,
      TerminalStatus.cancelled,
    ].contains(reply.status)) {
      o.remove('terminalPending');
    }
    attempt['status'] = reply.status == TerminalStatus.unavailable
        ? 'unknown'
        : reply.status.name;
    if (!store.replace(s, snap.revision).ok)
      throw const FormatException(
        'Terminal sonucu saklanamadı; referansı sorgulayın',
      );
    return reply;
  }
}
