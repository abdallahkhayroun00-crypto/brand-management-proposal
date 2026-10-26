import 'package:flutter/material.dart';
import 'operations_ui.dart';
import 'pos_logic.dart';
import 'order_actions.dart';
import 'workspace_ui.dart';

class OrderActionLog extends StatelessWidget {
  const OrderActionLog({
    super.key,
    required this.state,
    required this.edit,
    this.initiallyExpanded = false,
  });
  final Json state;
  final EditState edit;
  final bool initiallyExpanded;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    initiallyExpanded: initiallyExpanded,
    title: const Text('Sipariş İşlem Kaydı / Platform Senkronizasyonu'),
    children: [
      for (final j in orderOperations(state).reversed)
        ListTile(
          title: Text(
            '${j['source']} #${j['orderId']} · ${j['action'] == 'ready'
                ? 'Sipariş Hazır'
                : j['action'] == 'accept'
                ? 'Kabul Et'
                : 'Reddet'}',
          ),
          subtitle: Text(
            'Personel: ${j['actor']['name']} · Saat: ${istanbulTime(j['at'])}\nPlatform Senkronizasyonu: ${j['status']} · ${j['error']}\nDeneme: ${j['attempts']}',
          ),
          trailing: j['status'] == 'Hata'
              ? OutlinedButton(
                  onPressed: () =>
                      edit((s) => retryOrderAction(s, '${j['id']}', pcActor)),
                  child: const Text('Yeniden Dene'),
                )
              : null,
        ),
    ],
  );
}
