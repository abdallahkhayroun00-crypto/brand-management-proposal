part of 'main.dart';

class _OrderComposer extends StatefulWidget {
  const _OrderComposer({
    required this.products,
    this.table,
    this.adding = false,
    this.pickupOnly = false,
    this.tableOrders = const {},
    this.onSubmit,
    this.refreshProducts,
    this.refreshTables,
  });
  final List<Product> products;
  final int? table;
  final bool adding, pickupOnly;
  final Map<int, Json> tableOrders;
  final bool Function(OrderRequest)? onSubmit;
  final List<Product> Function()? refreshProducts;
  final Map<int, Json> Function()? refreshTables;
  @override
  State<_OrderComposer> createState() => _OrderComposerState();
}

class _OrderComposerState extends State<_OrderComposer> {
  // Every cart row is independent: two wraps may have different notes.
  final List<Json> draft = [];
  Json pickupCustomer = {};
  String category = 'all', search = '', source = 'Masa', pickup = 'Tezgahtan';
  int? table;
  int nextLine = 0;
  String? saveError;
  late List<Product> products;
  late Map<int, Json> tableOrders;
  @override
  void initState() {
    super.initState();
    products = widget.products;
    tableOrders = widget.tableOrders;
    table = widget.table;
    if (widget.pickupOnly || (widget.adding && table == null))
      source = 'Gel-Al';
  }

  void add(Product p, {String note = '', String removed = ''}) {
    if (draft.length >= 200) {
      setState(
        () => saveError = 'Bir sipariş en fazla 200 ayrı satır içerebilir.',
      );
      return;
    }
    setState(
      () => draft.add({
        if (p.campaignData != null) ...copyJson(p.campaignData!),
        '_draftId': nextLine++,
        'productId': p.id,
        'productKey': p.name,
        'name': p.name,
        'price': p.price,
        'qty': 1,
        'note': note,
        'removed': removed
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
      }),
    );
  }

  Future<void> customize(Product p, [Json? line]) async {
    final original =
        line ??
        <String, dynamic>{
          if (p.campaignData != null) ...copyJson(p.campaignData!),
          'name': p.name,
          'price': p.price,
          'note': '',
          'removed': <String>[],
        };
    final result = await customizeLineDialog(
      context,
      original,
      description: p.descriptionTr ?? '',
    );
    if (result == null || !mounted) return;
    if (line == null) {
      if (result['qty'] == 0 || draft.length >= 200) return;
      add(p);
      setState(() => draft.last.addAll(result));
    } else
      setState(() {
        if (result['qty'] == 0)
          draft.remove(line);
        else
          line.addAll(result);
      });
  }

  Future<void> addCustomItem() async {
    if (draft.length >= 200) return;
    final result = await askFields(
      context,
      'Özel Ürün Ekle',
      [
        ('Ürün adı', ''),
        ('Birim fiyat (₺)', ''),
        ('Adet', '1'),
        ('Not', ''),
        ('İç menüye kaydet', 'Hayır'),
      ],
      choices: {
        4: ['Hayır', 'Evet'],
      },
    );
    if (result == null || !mounted) return;
    try {
      final qty = int.tryParse(result[2]);
      if (qty == null || qty < 1 || qty > 1000 || result[3].length > 500) {
        throw const FormatException('Adet veya not geçersiz.');
      }
      final item = <String, dynamic>{
        'customItem': true,
        'saveToMenu': result[4] == 'Evet',
        'name': result[0].trim(),
        'price': fromCents(parseMoney(result[1])),
        'qty': qty,
        'note': result[3],
        'removed': <String>[],
      };
      prepareInternalItem({}, {...item, 'saveToMenu': false});
      setState(() {
        draft.add({...item, '_draftId': nextLine++});
        saveError = null;
      });
    } on FormatException catch (e) {
      setState(() => saveError = e.message);
    }
  }

  Widget productList() {
    final visibleProducts = products
        .where(
          (p) =>
              p.active &&
              (category == 'all' || p.category == category) &&
              p.name.toLowerCase().contains(search.toLowerCase()),
        )
        .toList();
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Ürün ara',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => search = v),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final x in [
                ('campaign', 'Kampanyalar'),
                ('all', 'Tümü'),
                ('wrap', 'Dürümler'),
                ('plate', 'Porsiyonlar'),
                ('meze', 'Mezeler'),
                ('fatte', 'Fatte'),
                ('side', 'Diğer'),
                ('salad', 'Salatalar'),
                ('dessert', 'Tatlılar'),
                ('drink', 'İçecekler'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(x.$2),
                    selected: category == x.$1,
                    onSelected: (_) => setState(() => category = x.$1),
                  ),
                ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: addCustomItem,
            icon: const Icon(Icons.add),
            label: const Text('Özel Ürün Ekle'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: visibleProducts.length,
            itemBuilder: (context, i) {
              final p = visibleProducts[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (p.image != null)
                            SizedBox(
                              width: 46,
                              height: 46,
                              child: Image.network(
                                Uri.parse(
                                  'https://nohutfalafel.github.io/qr-menu/',
                                ).resolve(p.image!).toString(),
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.restaurant_menu),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            p.price == null
                                ? 'Fiyat yok'
                                : formatTry(cents(p.price)),
                          ),
                        ],
                      ),
                      if (p.descriptionTr?.isNotEmpty == true)
                        Text(
                          p.descriptionTr!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: p.price == null ? null : () => add(p),
                            icon: const Icon(Icons.add),
                            label: const Text('Ekle'),
                          ),
                          TextButton(
                            onPressed: p.price == null
                                ? null
                                : () => customize(p),
                            child: const Text('Not / Malzeme'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget cartList() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Sipariş Sepeti',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      const Text(
        'Aynı ürüne farklı notlar ekleyebilirsiniz.',
        style: TextStyle(fontSize: 12),
      ),
      Expanded(
        child: draft.isEmpty
            ? const Center(child: Text('Sepet boş'))
            : ListView(
                children: [
                  for (final line in draft)
                    Card(
                      key: ValueKey(line['_draftId']),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${line['name']}${line['_unavailable'] == true ? ' · Satış dışı, satırı kaldırın' : ''}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            for (final component in asMaps(line['components']))
                              Text(
                                component['name'].toString() +
                                    ' · ' +
                                    campaignComponentDetails(component),
                              ),
                            if ('${line['note']}'.isNotEmpty)
                              Text('Not: ${line['note']}'),
                            if ((line['removed'] as List).isNotEmpty)
                              Text(
                                'Çıkar: ${(line['removed'] as List).join(', ')}',
                              ),
                            Text(
                              formatTry(
                                cents(line['price']) * (line['qty'] as int),
                              ),
                            ),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                IconButton(
                                  tooltip: 'Adedi azalt',
                                  onPressed: () => setState(() {
                                    if (line['qty'] == 1) {
                                      draft.remove(line);
                                    } else {
                                      line['qty'] = (line['qty'] as int) - 1;
                                    }
                                  }),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text('${line['qty']}'),
                                IconButton(
                                  tooltip: 'Adedi artır',
                                  onPressed: (line['qty'] as int) >= 1000
                                      ? null
                                      : () => setState(
                                          () => line['qty'] =
                                              (line['qty'] as int) + 1,
                                        ),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                                IconButton(
                                  tooltip: 'Satır notunu düzenle',
                                  onPressed:
                                      line['_unavailable'] == true ||
                                          line['customItem'] == true
                                      ? null
                                      : () => customize(
                                          products.firstWhere(
                                            (p) => p.id == line['productId'],
                                          ),
                                          line,
                                        ),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Satırı kaldır',
                                  onPressed: () =>
                                      setState(() => draft.remove(line)),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final total = draft.fold<int>(
      0,
      (sum, line) => sum + cents(line['price']) * (line['qty'] as int),
    );
    return Dialog(
      child: SizedBox(
        width: (size.width - 48).clamp(280, 1100),
        height: (size.height - 48).clamp(350, 820),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.adding ? 'Ek Sipariş' : 'Yeni Sipariş',
                      style: const TextStyle(
                        fontSize: 21,
                        fontFamily: NohutBrand.headingFont,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (!widget.adding && !widget.pickupOnly)
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        initialValue: source,
                        decoration: const InputDecoration(
                          labelText: 'Sipariş türü',
                        ),
                        items: ['Masa', 'Gel-Al']
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => source = v!),
                      ),
                    ),
                  if (source == 'Masa')
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: table,
                        decoration: const InputDecoration(
                          labelText: 'Masa seçin',
                        ),
                        items: List.generate(
                          5,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(
                              'Masa ${i + 1} · ${tableOrders[i + 1] == null ? 'Boş' : 'Dolu · Ek sipariş #${displayOrderNumber(tableOrders[i + 1]!)}'}',
                            ),
                          ),
                        ),
                        onChanged: widget.adding
                            ? null
                            : (v) => setState(() => table = v),
                      ),
                    ),
                  if (source == 'Gel-Al')
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        initialValue: pickup,
                        decoration: const InputDecoration(
                          labelText: 'Teslim alma',
                        ),
                        items: ['Tezgahtan', 'Telefon']
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => pickup = v!),
                      ),
                    ),
                  if (source == 'Gel-Al' && !widget.adding)
                    TextButton(
                      onPressed: () async {
                        final v = await askFields(context, 'Gel-Al Bilgileri', [
                          ('Ad', '${pickupCustomer['name'] ?? ''}'),
                          ('Telefon', '${pickupCustomer['phone'] ?? ''}'),
                          (
                            'Teslim alma saati',
                            '${pickupCustomer['time'] ?? ''}',
                          ),
                        ]);
                        if (v != null && mounted)
                          setState(
                            () => pickupCustomer = {
                              'name': v[0],
                              'phone': v[1],
                              'time': v[2],
                            },
                          );
                      },
                      child: Text(
                        pickupCustomer.isEmpty
                            ? 'Müşteri / Saat Bilgisi'
                            : '${pickupCustomer['name']} · ${pickupCustomer['time']}',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => c.maxWidth >= 740
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 3, child: productList()),
                            const VerticalDivider(width: 24),
                            Expanded(flex: 2, child: cartList()),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(flex: 3, child: productList()),
                            const Divider(),
                            Expanded(flex: 2, child: cartList()),
                          ],
                        ),
                ),
              ),
              if (saveError != null) ...[
                Text(
                  saveError!,
                  style: const TextStyle(color: Color(0xff8c352e)),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    products = widget.refreshProducts?.call() ?? products;
                    tableOrders = widget.refreshTables?.call() ?? tableOrders;
                    for (final line in draft) {
                      if (line['customItem'] == true) continue;
                      final product = products
                          .where((p) => p.id == line['productId'])
                          .firstOrNull;
                      line['_unavailable'] =
                          product == null ||
                          !product.active ||
                          product.price == null;
                      if (product != null && product.price != null) {
                        if (product.campaignData != null) {
                          try {
                            line['components'] = mergeCampaignComponents(
                              asMaps(product.campaignData!['components']),
                              line['components'],
                            );
                          } on FormatException {
                            line['_unavailable'] = true;
                          }
                        }
                        line['basePrice'] = product.price;
                        line['price'] = fromCents(
                          cents(product.price) +
                              (line['adjustmentCents'] as int? ?? 0) +
                              componentExtraCents(line),
                        );
                        line['name'] = product.name;
                      }
                    }
                    saveError =
                        'Güncel fiyatlar ve masalar yüklendi. Sepeti kontrol edip kaydedin.';
                  }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Güncel Menü ve Masaları Al'),
                ),
              ],
              const Divider(),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    'Ürün: ${draft.fold<int>(0, (n, l) => n + (l['qty'] as int))} · Toplam ${formatTry(total)}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed:
                        draft.isEmpty ||
                            draft.any((l) => l['_unavailable'] == true) ||
                            (source == 'Masa' && table == null)
                        ? null
                        : () {
                            final request = OrderRequest(
                              source: source,
                              table: source == 'Masa' ? table : null,
                              pickupChannel: pickup,
                              customer: pickupCustomer,
                              expectedTableOrderId:
                                  tableOrders[table]?['id'] as int?,
                              lines: draft
                                  .map(
                                    (line) => Map<String, dynamic>.from(line)
                                      ..remove('_draftId')
                                      ..remove('_unavailable'),
                                  )
                                  .toList(),
                            );
                            if (widget.onSubmit?.call(request) ?? true) {
                              Navigator.pop(context, request);
                            } else {
                              setState(
                                () => saveError =
                                    'Kaydedilemedi. Güncel menü ve masaları alın; sepetiniz korunuyor.',
                              );
                            }
                          },
                    icon: const Icon(Icons.save),
                    label: const Text('Siparişi Kaydet'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
