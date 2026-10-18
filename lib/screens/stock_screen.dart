import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/brand.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/app_ui.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/retail_art.dart';
import '../widgets/retail_glyph.dart';
import 'scan_screen.dart';

enum _Filter { all, low, noCost }

class StockScreen extends StatefulWidget {
  final bool embedded;
  const StockScreen({super.key, this.embedded = false});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  String _q = '';
  _Filter _filter = _Filter.all;
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final all = store.activeProducts;
    var list = all
        .where((p) => p.name.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    if (_filter == _Filter.low) list = list.where((p) => p.isLowStock).toList();
    if (_filter == _Filter.noCost) {
      list = list.where((p) => p.avgCost == null).toList();
    }
    final lowN = all.where((p) => p.isLowStock).length;
    final noCostN = all.where((p) => p.avgCost == null).length;
    return Theme(
      data: Theme.of(context).copyWith(
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE9EAF2)),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: widget.embedded
            ? null
            : AppBar(
                backgroundColor: const Color(0xFFF7F8FC),
                foregroundColor: AppColors.ink,
                title: const LocalText(
                  'Stok & bahan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addProduct(context),
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          elevation: 2,
          icon: const Icon(Icons.add),
          label: const LocalText(
            'Produk / bahan',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: CustomScrollView(
            key: const PageStorageKey('stock-products'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverList.list(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFEEEAFE), Color(0xFFE0F2FF)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE0DCF3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: LocalText(
                                  'Nilai stok',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF65687B),
                                  ),
                                ),
                              ),
                              const InfoButton(
                                title: 'Tentang stok',
                                message:
                                    'Nilai stok memakai harga modal yang diketahui. Produk tanpa harga modal belum dihitung.',
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      store.stockValue == null
                                          ? '≥ ${rp(store.stockValueKnown)}'
                                          : rp(store.stockValue!),
                                      style: const TextStyle(
                                        fontSize: 26,
                                        height: 1.2,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    LocalText(
                                      '${all.length} produk',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF65687B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              const RetaileeMark(size: 52),
                            ],
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: () =>
                                startScan(context, DocKind.openingStock),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            icon: const Icon(
                              Icons.photo_camera_outlined,
                              size: 21,
                            ),
                            label: const LocalText('Foto stok'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      key: const ValueKey('stock-search'),
                      controller: _search,
                      onChanged: (v) => setState(() => _q = v),
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.ink,
                      ),
                      decoration: InputDecoration(
                        labelText: appTr(context, 'Cari produk…'),
                        labelStyle: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF65687B),
                        ),
                        prefixIcon: const Icon(Icons.search, size: 22),
                        suffixIcon: _q.isEmpty
                            ? null
                            : IconButton(
                                tooltip: appTr(context, 'Hapus pencarian'),
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _q = '');
                                },
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE1DFEC),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip('Semua (${all.length})', _Filter.all),
                        _chip('Menipis ($lowN)', _Filter.low),
                        _chip('Modal kosong ($noCostN)', _Filter.noCost),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              if (all.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
                    child: EmptyState(
                      illustration: RetailScene.shelf,
                      icon: Icons.inventory_2_outlined,
                      title: 'Belum ada produk',
                      body:
                          'Foto catatan stok awal atau tambah produk satu per satu.',
                      action: FilledButton.icon(
                        onPressed: () =>
                            startScan(context, DocKind.openingStock),
                        icon: const Icon(Icons.photo_camera),
                        label: const LocalText('Foto catatan stok'),
                      ),
                    ),
                  ),
                )
              else if (list.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 112),
                    child: EmptyState(
                      icon: Icons.search_off,
                      title: 'Produk tidak ditemukan',
                      body: 'Coba nama lain atau pilih filter Semua.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
                  sliver: SliverList.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ProductCard(product: list[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, _Filter f) => ChoiceChip(
    key: ValueKey('stock-filter-${f.name}'),
    label: LocalText(label),
    selected: _filter == f,
    onSelected: (_) => setState(() => _filter = f),
    showCheckmark: false,
    selectedColor: AppColors.primary,
    backgroundColor: Colors.white,
    labelStyle: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: _filter == f ? Colors.white : AppColors.primaryDark,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    side: const BorderSide(color: Color(0xFFE1DFEC)),
  );

  Future<void> _addProduct(BuildContext context) async {
    final store = StoreScope.read(context);
    final xp = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StoreScope(store: store, child: const _ProductForm()),
    );
    if (xp != null && context.mounted) {
      showXpGain(context, xp, 'Produk ditambahkan');
    }
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});
  @override
  Widget build(BuildContext context) {
    final p = product;
    return Card(
      child: InkWell(
        key: ValueKey('stock-product-${p.id}'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(productId: p.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: 34,
                child: FittedBox(child: RetailGlyph.product(p.name)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked =
                        MediaQuery.textScalerOf(context).scale(16) > 24 ||
                        constraints.maxWidth < 220;
                    final quantity = Wrap(
                      spacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          fmtQty(p.qty),
                          style: TextStyle(
                            fontSize: 20,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: p.isLowStock
                                ? AppColors.danger
                                : AppColors.ink,
                          ),
                        ),
                        Text(
                          p.unit,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: Color(0xFF65687B),
                          ),
                        ),
                      ],
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                p.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (!stacked) ...[
                              const SizedBox(width: 8),
                              quantity,
                            ],
                          ],
                        ),
                        if (stacked) ...[const SizedBox(height: 4), quantity],
                        const SizedBox(height: 4),
                        LocalText(
                          '${p.materialOnly ? 'Bahan' : 'Jual ${rp(p.sellPrice)}'} · Modal ${p.avgCost == null ? '?' : rp(p.avgCost!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Color(0xFF65687B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (p.isLowStock)
                              Pill.danger(
                                'Stok menipis',
                                icon: Icons.trending_down,
                              ),
                            if (p.avgCost == null)
                              Pill.warn('Modal belum ada')
                            else if (p.marginPct != null && !p.materialOnly)
                              Pill.ok(
                                'Margin ${p.marginPct!.toStringAsFixed(0)}%',
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF777589),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductForm extends StatefulWidget {
  const _ProductForm();
  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _sell = TextEditingController();
  final _cost = TextEditingController();
  final _qty = TextEditingController(text: '0');
  final _min = TextEditingController(text: '5');
  String _unit = 'pcs';
  bool _materialOnly = false, _busy = false;
  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _materialOnly = StoreScope.read(context).serviceFirst;
    }
  }

  String? _error;
  double? _number(String s) => double.tryParse(s.trim().replaceAll(',', '.'));
  String? _validQty(String? s) {
    final n = _number(s ?? '');
    return n == null || !n.isFinite || n < 0 ? 'Isi angka ≥ 0' : null;
  }

  @override
  void dispose() {
    for (final c in [_name, _sell, _cost, _qty, _min]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppUi(
      child: Material(
        color: appCanvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Form(
              key: _form,
              child: ListView(
                shrinkWrap: true,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: LocalText(
                          'Tambah produk / bahan',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: appTr(context, 'Tutup'),
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppSection(
                    title: 'Detail produk / bahan',
                    children: [
                      CheckboxListTile(
                        secondary: const Icon(Icons.inventory_2_outlined),
                        contentPadding: EdgeInsets.zero,
                        title: const LocalText('Bahan baku / habis pakai'),
                        subtitle: const LocalText(
                          'Dipakai untuk layanan atau pesanan, tidak dijual langsung.',
                        ),
                        value: _materialOnly,
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => _materialOnly = v!),
                      ),

                      AppTextField(
                        controller: _name,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: _materialOnly
                              ? 'Nama bahan'
                              : 'Nama produk',
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Wajib diisi' : null,
                      ),

                      const SizedBox(height: 12),
                      AppDropdown<String>(
                        initialValue: _unit,
                        decoration: const InputDecoration(labelText: 'Satuan'),
                        items: [
                          for (final u in [
                            'pcs',
                            'pack',
                            'bks',
                            'btl',
                            'kg',
                            'gram',
                            'liter',
                            'ml',
                            'dus',
                            'sachet',
                            'porsi',
                            'pasang',
                            'meter',
                          ])
                            DropdownMenuItem(value: u, child: Text(u)),
                        ],
                        onChanged: (v) => _unit = v ?? 'pcs',
                      ),
                    ],
                  ),
                  AppSection(
                    title: 'Harga & modal',
                    children: [
                      AppTextField(
                        controller: _sell,
                        enabled: !_materialOnly,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Harga jual',
                          prefixText: 'Rp ',
                        ),
                        validator: (v) =>
                            !_materialOnly &&
                                ((parseAmount(v ?? '') ?? 0) <= 0 ||
                                    !(parseAmount(v ?? '') ?? double.nan)
                                        .isFinite)
                            ? 'Wajib'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _cost,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Modal (opsional)',
                          prefixText: 'Rp ',
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? null
                            : (parseAmount(v!) == null ||
                                      !parseAmount(v)!.isFinite ||
                                      parseAmount(v)! < 0
                                  ? 'Periksa modal'
                                  : null),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                  AppSection(
                    title: 'Stok awal & pengingat',
                    children: [
                      AppTextField(
                        controller: _qty,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stok awal',
                        ),
                        validator: _validQty,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _min,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Batas minimum',
                        ),
                        validator: _validQty,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                  if (_error != null)
                    LocalText(
                      _error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            if (!_form.currentState!.validate()) return;
                            setState(() {
                              _busy = true;
                              _error = null;
                            });
                            try {
                              final xp = await StoreScope.read(context)
                                  .addProductManual(
                                    name: _name.text,
                                    unit: _unit,
                                    category: 'Lainnya',
                                    sellPrice: _materialOnly
                                        ? 0
                                        : parseAmount(_sell.text)!,
                                    cost: parseAmount(_cost.text),
                                    qty: _number(_qty.text)!,
                                    minQty: _number(_min.text)!,
                                    materialOnly: _materialOnly,
                                  );
                              if (context.mounted) Navigator.pop(context, xp);
                            } catch (e) {
                              if (mounted) setState(() => _error = '$e');
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: LocalText(
                      _busy ? 'Menyimpan...' : 'Simpan produk / bahan',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProductDetailScreen extends StatelessWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = store.productById(productId);
    if (p == null) {
      return const AppFrame(
        title: 'Stok & bahan',
        body: Center(child: LocalText('Produk tidak ditemukan')),
      );
    }
    final mv = store.movementsFor(p.id);
    final sold7 = store.qtySoldSince(
      p.id,
      store.now.subtract(const Duration(days: 7)),
    );

    return AppFrame(
      title: p.name,
      actions: [
        IconButton(
          tooltip: appTr(context, 'Ubah produk'),
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _edit(context, store, p),
        ),
      ],
      body: ListView(
        key: const PageStorageKey('product-details'),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.isLowStock
                  ? AppColors.dangerSoft
                  : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LocalText(
                        'Stok saat ini',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LocalText(
                        '${fmtQty(p.qty)} ${p.unit}',
                        style: TextStyle(
                          fontSize: 28,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          color: p.isLowStock
                              ? AppColors.danger
                              : AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      LocalText(
                        'Minimum ${fmtQty(p.minQty)} · terjual ${fmtQty(sold7)} dlm 7 hari',
                        style: const TextStyle(fontSize: 13),
                      ),
                      if (p.isLowStock)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: LocalText(
                            'Stok menipis',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  p.isLowStock
                      ? Icons.trending_down
                      : Icons.inventory_2_outlined,
                  size: 32,
                  color: p.isLowStock ? AppColors.danger : AppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = MediaQuery.textScalerOf(context).scale(1) > 1.3
                  ? 1
                  : constraints.maxWidth >= 350
                  ? 3
                  : 2;
              final width =
                  (constraints.maxWidth - (columns - 1) * 8) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: width,
                    child: _stat('Harga jual', rp(p.sellPrice)),
                  ),
                  SizedBox(
                    width: width,
                    child: _stat(
                      'Modal rata²',
                      p.avgCost == null ? 'Belum ada' : rp(p.avgCost!),
                      warn: p.avgCost == null,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _stat(
                      'Margin',
                      p.marginPct == null
                          ? '—'
                          : '${p.marginPct!.toStringAsFixed(1)}%',
                    ),
                  ),
                ],
              );
            },
          ),
          if (p.avgCost == null) ...[
            const SizedBox(height: 12),
            AppEntryTile(
              leading: const Icon(Icons.price_change_outlined),
              title: const LocalText('Lengkapi harga modal'),
              subtitle: const LocalText('Supaya laba bisa dihitung · +20 XP'),
              onTap: () => _completeCost(context, store, p),
            ),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final actions = [
                FilledButton.icon(
                  onPressed: () => _restock(context, store, p),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const LocalText('Restock'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _adjust(context, store, p),
                  icon: const Icon(Icons.tune),
                  label: const LocalText('Sesuaikan'),
                ),
              ];
              if (MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
                  constraints.maxWidth < 300) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [actions[0], const SizedBox(height: 8), actions[1]],
                );
              }
              return Row(
                children: [
                  Expanded(child: actions[0]),
                  const SizedBox(width: 10),
                  Expanded(child: actions[1]),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const LocalText(
            'Riwayat pergerakan stok',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (mv.isEmpty)
            const AppSection(
              children: [
                LocalText(
                  'Belum ada pergerakan.',
                  style: TextStyle(fontSize: 14, color: appSecondary),
                ),
              ],
            ),
          for (final m in mv)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                leading: Icon(
                  m.qtyDelta > 0
                      ? Icons.south_west
                      : (m.qtyDelta < 0 ? Icons.north_east : Icons.edit_note),
                  color: m.qtyDelta > 0
                      ? AppColors.primary
                      : (m.qtyDelta < 0 ? AppColors.danger : AppColors.muted),
                ),
                title: LocalText(
                  m.sourceId == 'cost_completion'
                      ? 'Harga modal dilengkapi'
                      : movementLabels[m.type]!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: LocalText(
                  '${fmtDate(m.date)}${m.unitCost != null ? ' · modal ${rp(m.unitCost!)}' : ''}',
                ),
                trailing: Text(
                  m.qtyDelta == 0
                      ? '—'
                      : '${m.qtyDelta > 0 ? '+' : ''}${fmtQty(m.qtyDelta)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: m.qtyDelta > 0
                        ? AppColors.primary
                        : AppColors.danger,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, {bool warn = false}) => Material(
    color: warn ? AppColors.warnSoft : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: AppColors.line),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalText(
            label,
            style: const TextStyle(fontSize: 13, color: appSecondary),
          ),
          const SizedBox(height: 4),
          LocalText(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );

  Future<void> _restock(BuildContext context, AppStore store, Product p) async {
    final qty = TextEditingController();
    final cost = TextEditingController(
      text: p.avgCost == null ? '' : fmtNum(p.avgCost!),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AppDialog(
        scrollable: true,
        title: InfoHeading(
          title: 'Restock ${p.name}',
          message:
              'Modal rata-rata dihitung ulang otomatis (rata-rata tertimbang).',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: qty,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Jumlah (${p.unit})'),
            ),
            const SizedBox(height: 10),
            AppTextField(
              controller: cost,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Modal per unit',
                prefixText: 'Rp ',
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const LocalText('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(d, true),
            child: const LocalText('Simpan'),
          ),
        ],
      ),
    );
    final q = parseAmount(qty.text) ?? 0;
    if (ok == true && q > 0) {
      await store.restock(p, qty: q, unitCost: parseAmount(cost.text));
      if (context.mounted) showMessage(context, 'Stok ${p.name} +${fmtQty(q)}');
    }
  }

  Future<void> _adjust(BuildContext context, AppStore store, Product p) async {
    final c = TextEditingController(text: fmtQty(p.qty));
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AppDialog(
        scrollable: true,
        title: const LocalText('Sesuaikan stok'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LocalText(
              'Masukkan jumlah hasil hitung fisik di rak.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            AppTextField(
              controller: c,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Stok sebenarnya (${p.unit})',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const LocalText('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(d, true),
            child: const LocalText('Simpan'),
          ),
        ],
      ),
    );
    final v = parseAmount(c.text);
    if (ok == true && v != null && v >= 0) await store.adjustStock(p, v);
  }

  Future<void> _completeCost(
    BuildContext context,
    AppStore store,
    Product p,
  ) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AppDialog(
        scrollable: true,
        title: LocalText('Harga modal ${p.name}'),
        content: AppTextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Modal per unit',
            prefixText: 'Rp ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const LocalText('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(d, true),
            child: const LocalText('Simpan'),
          ),
        ],
      ),
    );
    final v = parseAmount(c.text);
    if (ok == true && v != null && v > 0) {
      final xp = await store.updateProduct(p, completeCost: v);
      if (context.mounted) {
        showXpGain(context, xp, 'Harga modal ${p.name} tersimpan');
      }
    }
  }

  Future<void> _edit(BuildContext context, AppStore store, Product p) async {
    final name = TextEditingController(text: p.name);
    final sell = TextEditingController(text: fmtNum(p.sellPrice));
    final min = TextEditingController(text: fmtQty(p.minQty));
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AppDialog(
        scrollable: true,
        title: const LocalText('Ubah produk'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            const SizedBox(height: 10),
            AppTextField(
              controller: sell,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Harga jual',
                prefixText: 'Rp ',
              ),
            ),
            const SizedBox(height: 10),
            AppTextField(
              controller: min,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Batas minimum'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const LocalText('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(d, true),
            child: const LocalText('Simpan'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await store.updateProduct(
        p,
        name: name.text,
        sellPrice: parseAmount(sell.text),
        minQty: parseAmount(min.text),
      );
    }
  }
}
