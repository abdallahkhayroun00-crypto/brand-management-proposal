import 'package:flutter/material.dart';
import 'operations_ui.dart';
import 'pos_logic.dart';

class PaymentEntryDialog extends StatefulWidget {
  const PaymentEntryDialog({
    super.key,
    required this.dueCents,
    required this.orderNumber,
    this.guestName = '',
    this.inposReady = false,
    this.fixedAmount = false,
  });
  final bool inposReady, fixedAmount;
  final int dueCents;
  final String orderNumber, guestName;
  @override
  State<PaymentEntryDialog> createState() => _PaymentEntryDialogState();
}

class _PaymentEntryDialogState extends State<PaymentEntryDialog> {
  late final amount = TextEditingController(
    text: (widget.dueCents / 100).toStringAsFixed(2),
  );
  late final received = TextEditingController(
    text: (widget.dueCents / 100).toStringAsFixed(2),
  );
  final cashPart = TextEditingController();
  String method = 'Nakit';
  String? error;
  @override
  void dispose() {
    cashPart.dispose();
    amount.dispose();
    received.dispose();
    super.dispose();
  }

  String get change {
    try {
      final n = parseMoney(method == 'Karışık' ? cashPart.text : amount.text),
          r = parseMoney(received.text);
      return r < n ? 'Alınan nakit yetersiz' : 'Para üstü: ${formatTry(r - n)}';
    } on FormatException {
      return 'Tutarları girin';
    }
  }

  int get cardCents {
    try {
      final card = parseMoney(amount.text) - parseMoney(cashPart.text);
      return card < 0 ? 0 : card;
    } on FormatException {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Ödeme · #${widget.orderNumber} ${widget.guestName}'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Kalan ${formatTry(widget.dueCents)} · Kısmi veya Nakit + Kart ödeme alabilirsiniz.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: method,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Yöntem'),
              items: [
                'Nakit',
                'Kart',
                'Karışık',
                if (widget.inposReady) 'inPOS m530',
              ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (m) => setState(() {
                method = m!;
                error = null;
              }),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('payment-amount'),
              controller: amount,
              readOnly: widget.fixedAmount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Tutar (₺)'),
              onChanged: (_) => setState(() => error = null),
            ),
            if (method == 'Karışık')
              TextField(
                controller: cashPart,
                onChanged: (_) => setState(() => error = null),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Nakit kısmı (₺) · kalan Kart',
                ),
              ),
            if (method == 'Karışık') Text('Kart: ${formatTry(cardCents)}'),
            if (method == 'Nakit' || method == 'Karışık') ...[
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('payment-received'),
                controller: received,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Alınan nakit (₺)',
                ),
                onChanged: (_) => setState(() => error = null),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final option in [0, 100, 200, 500])
                    OutlinedButton(
                      onPressed: () => setState(() {
                        received.text = option == 0
                            ? (method == 'Karışık'
                                  ? cashPart.text
                                  : amount.text)
                            : '$option';
                        error = null;
                      }),
                      child: Text(option == 0 ? 'Tam tutar' : '$option TL'),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  change,
                  key: const ValueKey('payment-change'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            if (method != 'Nakit') ...[
              const SizedBox(height: 12),
              Text(
                method == 'inPOS m530'
                    ? 'Tutar eşleştirilmiş inPOS cihazına gönderilir. Ödeme yalnızca cihaz onayından sonra kaydedilir.'
                    : 'Banka terminalinde başarılı tahsilatı ayrıca doğrulayın. Bu ekran bankaya işlem göndermez.',
                style: const TextStyle(color: Color(0xff775624)),
              ),
            ],
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  key: const ValueKey('payment-error'),
                  style: const TextStyle(color: Color(0xff8c352e)),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Vazgeç'),
      ),
      FilledButton(
        onPressed: () {
          try {
            final n = parseMoney(amount.text),
                r = method == 'Nakit'
                    ? parseMoney(received.text)
                    : method == 'Karışık'
                    ? parseMoney(cashPart.text)
                    : null;
            if (n <= 0 || n > widget.dueCents)
              throw const FormatException(
                'Tutar kalan bakiyeyi aşamaz ve sıfır olamaz.',
              );
            if (method == 'Karışık' && (r == null || r <= 0 || r >= n))
              throw const FormatException(
                'Nakit kısmı toplamdan küçük ve sıfırdan büyük olmalı',
              );
            if (method == 'Nakit' && r != null && r < n)
              throw const FormatException('Alınan nakit tutarı yetersiz.');
            final mixedReceived = method == 'Karışık'
                ? parseMoney(received.text)
                : null;
            if (mixedReceived != null && mixedReceived < r!) {
              throw const FormatException('Alınan nakit yetersiz.');
            }
            Navigator.pop(context, (n, method, r, mixedReceived));
          } on FormatException catch (e) {
            setState(() => error = e.message);
          }
        },
        child: const Text('Ödemeyi Gözden Geçir'),
      ),
    ],
  );
}
