import 'package:flutter/material.dart';
import 'operations_ui.dart';
import 'pos_logic.dart';
import 'order_actions.dart';

class OrderActionLog extends StatelessWidget {
  const OrderActionLog({super.key, required this.state, required this.edit});
  final Json state;
  final EditState edit;
  @override
  Widget build(BuildContext context) => ExpansionTile(
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
            'Personel: ${j['actor']['name']} · Saat: ${j['at']}\nPlatform Senkronizasyonu: ${j['status']} · ${j['error']}\nDeneme: ${j['attempts']}',
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
