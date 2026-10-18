import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../business_types.dart';
import '../models.dart';
import '../widgets/brand.dart';
import '../widgets/app_ui.dart';
import '../operations_models.dart';
import '../services/store.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/business_icons.dart';
import 'stock_screen.dart';

double quantity(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.')) ?? double.nan;
Future<bool> confirmOperation(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: LocalText(title),
        content: LocalText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const LocalText('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const LocalText('Konfirmasi'),
          ),
        ],
      ),
    ) ??
    false;

class InputSpec {
  final String key, label, initial;
  final bool optional, numeric;
  const InputSpec(
    this.key,
    this.label, {
    this.initial = '',
    this.optional = false,
    this.numeric = false,
  });
}

Future<void> operationForm(
  BuildContext context,
  String title,
  List<InputSpec> fields,
  Future<void> Function(Map<String, String>) save, {
  String? note,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _OperationForm(title: title, fields: fields, save: save, note: note),
);

class _OperationForm extends StatefulWidget {
  final String title;
  final List<InputSpec> fields;
  final Future<void> Function(Map<String, String>) save;
  final String? note;
  const _OperationForm({
    required this.title,
    required this.fields,
    required this.save,
    this.note,
  });
  @override
  State<_OperationForm> createState() => _OperationFormState();
}

class _OperationFormState extends State<_OperationForm> {
  late final _controllers = {
    for (final f in widget.fields)
      f.key: TextEditingController(text: f.initial),
  };
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppUi(
    child: AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit_note_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: LocalText(widget.title)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.note != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.infoSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: LocalText(
                        widget.note!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                for (final f in widget.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: AppTextField(
                      controller: _controllers[f.key],
                      enabled: !_busy,
                      maxLength: 160,
                      keyboardType: f.numeric
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                      decoration: InputDecoration(
                        labelText: f.label,
                        counterText: '',
                      ),
                      validator: (v) => !f.optional && (v ?? '').trim().isEmpty
                          ? 'Wajib diisi'
                          : null,
                    ),
                  ),
                if (_error != null)
                  LocalText(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const LocalText('Batal'),
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
                    await widget.save({
                      for (final e in _controllers.entries) e.key: e.value.text,
                    });
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) setState(() => _error = '$e');
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: LocalText(_busy ? 'Menyimpan...' : 'Simpan'),
        ),
      ],
    ),
  );
}

Future<void> offeringForm(BuildContext context, {Offering? offering}) {
  final store = StoreScope.read(context);
  return operationForm(
    context,
    offering == null ? 'Tambah layanan' : 'Ubah layanan',
    [
      InputSpec('name', 'Nama layanan', initial: offering?.name ?? ''),
      InputSpec(
        'unit',
        'Satuan harga',
        initial:
            offering?.unit ??
            store.business?.pricingUnit ??
            store.template.unit,
      ),
      InputSpec(
        'price',
        'Harga per satuan (Rp)',
        numeric: true,
        initial: offering == null ? '' : fmtNum(offering.price),
      ),
      InputSpec(
        'cost',
        'Biaya langsung per satuan (opsional)',
        numeric: true,
        optional: true,
        initial: offering?.directCost == null
            ? ''
            : fmtNum(offering!.directCost!),
      ),
    ],
    (v) async {
      final price = parseAmount(v['price']!) ?? double.nan;
      final cost = v['cost']!.trim().isEmpty
          ? null
          : parseAmount(v['cost']!) ?? double.nan;
      if (offering == null) {
        await store.addOffering(v['name']!, v['unit']!, price, cost);
      } else {
        await store.editOffering(offering, v['name']!, v['unit']!, price, cost);
      }
    },
    note:
        'Biaya langsung di luar bahan yang dipilih pada pesanan dan biaya umum yang dicatat terpisah. Kosong = belum diketahui; isi 0 hanya jika memang tidak ada.',
  );
}

class OperationsScreen extends StatelessWidget {
  final int? initialIndex;
  const OperationsScreen({super.key, this.initialIndex});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return DefaultTabController(
      key: ValueKey(store.businessType),
      initialIndex: initialIndex ?? (store.serviceFirst ? 0 : 2),
      length: store.producesGoods ? 4 : 3,
      animationDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F8FC),
          foregroundColor: AppColors.ink,
          title: const LocalText(
            'Kelola usaha',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF65687B),
            labelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            tabs: [
              const Tab(child: LocalText('Pesanan')),
              const Tab(child: LocalText('Layanan')),
              const Tab(child: LocalText('Stok & bahan')),
              if (store.producesGoods) const Tab(child: LocalText('Produksi')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _KeepToolPage(child: _OrdersList()),
            _KeepToolPage(child: _OfferingsList()),
            const _KeepToolPage(child: StockScreen(embedded: true)),
            if (store.producesGoods)
              const _KeepToolPage(child: ProductionScreen()),
          ],
        ),
      ),
    );
  }
}

class _KeepToolPage extends StatefulWidget {
  final Widget child;
  const _KeepToolPage({required this.child});
  @override
  State<_KeepToolPage> createState() => _KeepToolPageState();
}

class _KeepToolPageState extends State<_KeepToolPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _OrdersList extends StatefulWidget {
  @override
  State<_OrdersList> createState() => _OrdersListState();
}

class _OrdersListState extends State<_OrdersList> {
  bool _history = false;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final orders =
        store.orders
            .where((o) => _history || (!o.completed && !o.cancelled))
            .toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final active = store.activeOrders;
    final late = active.where((o) => o.dueAt.isBefore(store.now)).length;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openOrderForm(context),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add),
        label: const LocalText(
          'Pesanan',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        key: const PageStorageKey('orders-list'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEEEAFE), Color(0xFFE0F2FF)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE0DCF3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: LocalText(
                        'Sisa tagihan',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF65687B),
                        ),
                      ),
                    ),
                    const InfoButton(
                      title: 'Tentang pesanan',
                      message:
                          'Sisa tagihan mencakup pesanan yang belum lunas, termasuk yang telah selesai. Pesanan dibatalkan tidak dihitung.',
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        rp(store.orderReceivables),
                        style: const TextStyle(
                          fontSize: 26,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const RetaileeMark(size: 40),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    LocalText(
                      '${active.length} pesanan aktif',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    if (late > 0)
                      LocalText(
                        '$late lewat tenggat',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final history in [false, true])
                ChoiceChip(
                  key: ValueKey('orders-history-$history'),
                  label: LocalText(history ? 'Tampilkan riwayat' : 'Aktif'),
                  selected: _history == history,
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _history == history
                        ? Colors.white
                        : AppColors.primaryDark,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  side: const BorderSide(color: Color(0xFFE1DFEC)),
                  onSelected: (_) => setState(() => _history = history),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (orders.isEmpty)
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: EmptyState(
                icon: Icons.assignment_outlined,
                title: store.orders.isEmpty
                    ? 'Pesanan pertama dimulai di sini'
                    : 'Tidak ada pesanan aktif',
                body: store.orders.isEmpty
                    ? 'Tambahkan layanan, lalu gunakan tombol Pesanan untuk mencatat pelanggan dan tenggatnya.'
                    : 'Pesanan selesai atau dibatalkan bisa dilihat di riwayat.',
              ),
            ),
          for (final order in orders) _CompactOrderCard(order: order),
        ],
      ),
    );
  }
}

class _CompactOrderCard extends StatelessWidget {
  final WorkOrder order;
  const _CompactOrderCard({required this.order});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final late =
        !order.completed && !order.cancelled && order.dueAt.isBefore(store.now);
    final statusColor = order.cancelled
        ? const Color(0xFF65687B)
        : order.completed
        ? AppColors.positive
        : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE9EAF2)),
        ),
        child: InkWell(
          key: ValueKey('order-card-${order.id}'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(orderId: order.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      businessTypeIcon(store.businessType),
                      color: AppColors.primary,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.title,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            order.customer,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Color(0xFF65687B),
                            ),
                          ),
                        ],
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
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: LocalText(
                        order.cancelled
                            ? 'Dibatalkan'
                            : order.completed
                            ? 'Selesai'
                            : order.status,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                    LocalText(
                      '${late ? 'Tenggat lewat · ' : ''}${fmtDate(order.dueAt)} ${fmtTime(order.dueAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: late
                            ? AppColors.danger
                            : const Color(0xFF65687B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      LocalText(
                        'Total ${rp(order.total)}',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Color(0xFF65687B),
                        ),
                      ),
                      if (!order.cancelled)
                        LocalText(
                          order.outstanding > 0
                              ? 'Sisa ${rp(order.outstanding)}'
                              : 'Lunas',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: order.outstanding > 0
                                ? AppColors.ink
                                : AppColors.positive,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfferingsList extends StatefulWidget {
  @override
  State<_OfferingsList> createState() => _OfferingsListState();
}

class _OfferingsListState extends State<_OfferingsList> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() => setState(_search.clear);

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final query = _search.text.trim().toLowerCase();
    final services = store.offerings
        .where((s) => s.name.toLowerCase().contains(query))
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => offeringForm(context),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add),
        label: const LocalText(
          'Tambah layanan',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        key: const PageStorageKey('services-list'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primarySoft, AppColors.infoSoft],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE0DCF3)),
            ),
            child: Row(
              children: [
                const ExcludeSemantics(child: RetaileeMark(size: 44)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LocalText(
                        'Daftar layanan',
                        style: TextStyle(
                          fontSize: 19,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LocalText(
                        '${store.offerings.length} layanan tersedia',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                if (store.template.services.isNotEmpty)
                  InfoButton(
                    title: 'Inspirasi layanan',
                    message: store.template.services
                        .map((service) => appTr(context, service))
                        .join(', '),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (store.offerings.isNotEmpty) ...[
            TextField(
              key: const ValueKey('services-search'),
              controller: _search,
              style: const TextStyle(fontSize: 16),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: appTr(context, 'Cari layanan'),
                prefixIcon: const Icon(Icons.search_rounded, size: 22),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: appTr(context, 'Hapus pencarian'),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: _clearSearch,
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (store.offerings.isEmpty)
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: const EmptyState(
                icon: Icons.design_services_outlined,
                title: 'Buat daftar layananmu',
                body:
                    'Gunakan tombol Tambah layanan untuk menambah nama, satuan dan harga. Kamu yang menentukan layanan yang dijual.',
              ),
            )
          else if (services.isEmpty)
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.search_off_rounded,
                      size: 32,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                    const LocalText(
                      'Layanan tidak ditemukan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const LocalText(
                      'Coba nama lain atau hapus pencarian untuk melihat semua layanan.',
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: _clearSearch,
                      child: const LocalText(
                        'Lihat semua layanan',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          for (final service in services)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppColors.line),
                ),
                child: InkWell(
                  key: ValueKey('service-card-${service.id}'),
                  onTap: () => offeringForm(context, offering: service),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            businessTypeIcon(store.businessType),
                            size: 28,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                service.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 5,
                                runSpacing: 2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    rp(service.price),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      height: 1.3,
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '/ ${service.unit}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: Color(0xFF65687B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              LocalText(
                                'Biaya langsung: ${service.directCost == null ? 'belum diketahui' : rp(service.directCost!)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: service.directCost == null
                                      ? AppColors.warn
                                      : const Color(0xFF65687B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.edit_outlined,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> openOrderForm(BuildContext context) async {
  if (StoreScope.read(context).offerings.isEmpty) {
    showMessage(context, 'Buat layanan terlebih dahulu.');
    await offeringForm(context);
    if (!context.mounted || StoreScope.read(context).offerings.isEmpty) return;
  }
  if (context.mounted) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrderFormScreen()),
    );
  }
}

class OrderFormScreen extends StatefulWidget {
  final String? orderId;
  const OrderFormScreen({super.key, this.orderId});
  @override
  State<OrderFormScreen> createState() => _OrderFormState();
}

class _OrderFormState extends State<OrderFormScreen> {
  final _form = GlobalKey<FormState>();
  final _customer = TextEditingController(),
      _qty = TextEditingController(text: '1'),
      _price = TextEditingController();
  final _cost = TextEditingController(),
      _asset = TextEditingController(),
      _condition = TextEditingController();
  final _treatment = TextEditingController(),
      _staff = TextEditingController(),
      _duration = TextEditingController(text: '60');
  Offering? _offering;
  DateTime? _due;
  List<MaterialUse> _materials = [];
  Uint8List? _photo;
  bool _busy = false;
  bool _initialized = false;
  WorkOrder? _editing;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final store = StoreScope.read(context);
    final o = store.orders.where((o) => o.id == widget.orderId).firstOrNull;
    _editing = o;
    if (o == null) return;
    _offering = store.offerings.where((s) => s.id == o.offeringId).firstOrNull;
    _customer.text = o.customer;
    _qty.text = '${o.qty}'.replaceAll('.', ',');
    _price.text = fmtNum(o.unitPrice);
    _cost.text = o.directCost == null ? '' : fmtNum(o.directCost!);
    _asset.text = o.asset;
    _condition.text = o.condition;
    _treatment.text = o.treatment;
    _staff.text = o.staff;
    _duration.text = '${o.durationMinutes}';
    _due = o.dueAt;
    _materials = List.of(o.materials);
  }

  @override
  void dispose() {
    for (final c in [
      _customer,
      _qty,
      _price,
      _cost,
      _asset,
      _condition,
      _treatment,
      _staff,
      _duration,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
    bool numeric = false,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LocalText(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: appTr(context, label),
          child: TextFormField(
            key: PageStorageKey('order-field-$label'),
            controller: c,
            maxLength: 160,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              counterText: '',
              hintText: hint != null
                  ? appTr(context, hint)
                  : required
                  ? appTr(context, 'Wajib diisi')
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              filled: true,
              fillColor: const Color(0xFFF8F8FD),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: numeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            validator: (v) => required && (v ?? '').trim().isEmpty
                ? appTr(context, 'Wajib diisi')
                : null,
          ),
        ),
      ],
    ),
  );

  Widget _section(
    String title,
    IconData icon,
    List<Widget> children, {
    bool expandable = false,
    bool open = false,
  }) {
    final heading = LocalText(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: expandable
            ? ExpansionTile(
                key: PageStorageKey('order-section-$title'),
                initiallyExpanded: open,
                maintainState: true,
                shape: const Border(),
                collapsedShape: const Border(),
                leading: Icon(icon, color: AppColors.primary, size: 22),
                title: heading,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              )
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: AppColors.primary, size: 22),
                        const SizedBox(width: 8),
                        Expanded(child: heading),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...children,
                  ],
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final beauty = _editing == null
        ? store.businessType == BusinessType.beauty
        : _editing!.stages.first == 'Dijadwalkan';
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FD),
        foregroundColor: AppColors.ink,
        title: LocalText(
          _editing == null ? 'Pesanan baru' : 'Ubah pesanan',
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_qty, _price]),
                builder: (context, _) {
                  final total =
                      quantity(_qty.text) *
                      (parseAmount(_price.text) ?? double.nan);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        const LocalText(
                          'Total pesanan',
                          style: TextStyle(fontSize: 14),
                        ),
                        Text(
                          total.isFinite && total >= 0 ? rp(total) : '—',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: _busy
                    ? null
                    : () async {
                        if (!_form.currentState!.validate()) return;
                        if (_offering == null || _due == null) {
                          showMessage(
                            context,
                            'Pilih layanan dan jadwal.',
                            error: true,
                          );
                          return;
                        }
                        if (!await confirmOperation(
                          context,
                          'Simpan pesanan?',
                          'Periksa jumlah, harga, jadwal, bahan, dan kondisi barang sebelum menyimpan.',
                        )) {
                          return;
                        }
                        if (!mounted) return;
                        setState(() => _busy = true);
                        try {
                          if (_editing != null) {
                            await store.updateOrder(
                              _editing!,
                              offering: _offering!,
                              qty: quantity(_qty.text),
                              unitPrice: parseAmount(_price.text) ?? double.nan,
                              customer: _customer.text,
                              dueAt: _due!,
                              asset: _asset.text,
                              condition: _condition.text,
                              treatment: _treatment.text,
                              staff: _staff.text,
                              directCost: _cost.text.trim().isEmpty
                                  ? null
                                  : parseAmount(_cost.text) ?? double.nan,
                              durationMinutes: beauty
                                  ? int.tryParse(_duration.text) ?? 0
                                  : 60,
                              materials: _materials,
                            );
                          } else {
                            await store.createOrder(
                              offering: _offering!,
                              qty: quantity(_qty.text),
                              unitPrice: parseAmount(_price.text) ?? double.nan,
                              customer: _customer.text,
                              dueAt: _due!,
                              asset: _asset.text,
                              condition: _condition.text,
                              treatment: _treatment.text,
                              staff: _staff.text,
                              directCost: _cost.text.trim().isEmpty
                                  ? null
                                  : parseAmount(_cost.text) ?? double.nan,
                              durationMinutes: beauty
                                  ? int.tryParse(_duration.text) ?? 0
                                  : 60,
                              materials: _materials,
                              photo: _photo,
                            );
                          }
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            showMessage(context, '$e', error: true);
                          }
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: LocalText(_busy ? 'Menyimpan...' : 'Simpan pesanan'),
              ),
            ],
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          key: const PageStorageKey('order-form'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primarySoft, AppColors.infoSoft],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.assignment_outlined,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LocalText(
                          'Siapkan pesananmu',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const LocalText(
                          'Isi detail utama, lalu tambahkan kebutuhan pekerjaan.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _section('Pelanggan & layanan', Icons.design_services_outlined, [
              _field(_customer, 'Nama / kode pelanggan', required: true),
              LabeledDropdown<Offering>(
                decoration: const InputDecoration(labelText: 'Layanan'),
                initialValue: _offering,
                isExpanded: true,
                items: [
                  for (final s in store.offerings)
                    DropdownMenuItem(
                      value: s,
                      child: Text(s.name, style: const TextStyle(fontSize: 16)),
                    ),
                ],
                onChanged: (s) => setState(() {
                  _offering = s;
                  _price.text = fmtNum(s!.price);
                  _cost.text = s.directCost == null
                      ? ''
                      : fmtNum(s.directCost!);
                }),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final qty = _field(
                    _qty,
                    'Jumlah (${_offering?.unit ?? store.template.unit})',
                    required: true,
                    numeric: true,
                    hint: 'Contoh: 1,5',
                  );
                  final price = _field(
                    _price,
                    'Harga per satuan (Rp)',
                    required: true,
                    numeric: true,
                  );
                  if (MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
                      constraints.maxWidth < 330) {
                    return Column(children: [qty, price]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: qty),
                      const SizedBox(width: 12),
                      Expanded(child: price),
                    ],
                  );
                },
              ),
            ]),
            _section(
              beauty ? 'Jadwal & staf' : 'Tenggat pekerjaan',
              Icons.event_outlined,
              [
                if (beauty) ...[
                  _field(_staff, 'Staf yang melayani', required: true),
                  _field(
                    _duration,
                    'Durasi layanan (menit)',
                    required: true,
                    numeric: true,
                  ),
                ],
                OutlinedButton.icon(
                  icon: const Icon(Icons.event_outlined),
                  label: LocalText(
                    _due == null
                        ? (beauty
                              ? 'Pilih jadwal layanan'
                              : 'Pilih tenggat selesai')
                        : '${fmtDate(_due!)} ${fmtTime(_due!)}',
                  ),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: store.now,
                      firstDate: store.now.subtract(const Duration(days: 365)),
                      lastDate: store.now.add(const Duration(days: 730)),
                    );
                    if (d == null || !context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(store.now),
                    );
                    if (time != null && mounted) {
                      setState(
                        () => _due = DateTime(
                          d.year,
                          d.month,
                          d.day,
                          time.hour,
                          time.minute,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            _section(
              'Rincian pekerjaan',
              Icons.assignment_outlined,
              [
                _field(_asset, 'Barang / lingkup pekerjaan'),
                _field(_condition, 'Kondisi awal / diagnosis'),
                _field(_treatment, 'Treatment / pekerjaan yang disepakati'),
                if (!beauty) _field(_staff, 'Petugas (opsional)'),
                if (store.googleEnabled && _editing == null) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: LocalText(
                      _photo == null
                          ? 'Lampirkan foto kondisi barang'
                          : 'Ganti foto kondisi barang',
                    ),
                    onPressed: () async {
                      try {
                        final f = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1800,
                          imageQuality: 80,
                        );
                        if (f != null) {
                          final bytes = await f.readAsBytes();
                          if (mounted) setState(() => _photo = bytes);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          showMessage(context, '$e', error: true);
                        }
                      }
                    },
                  ),
                  if (_photo != null)
                    Image.memory(
                      _photo!,
                      height: 150,
                      errorBuilder: (_, _, _) =>
                          const LocalText('Format pratinjau belum didukung.'),
                    ),
                ],
              ],
              expandable: true,
              open: _editing != null,
            ),
            _section('Biaya & bahan', Icons.inventory_2_outlined, [
              _field(
                _cost,
                'Biaya langsung/unit di luar bahan (opsional)',
                numeric: true,
              ),
              const LocalText(
                'Kosong = biaya belum diketahui. Biaya bahan dipilih terpisah; biaya umum dicatat sebagai pengeluaran.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const LocalText(
                'Bahan / suku cadang yang akan digunakan',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const LocalText(
                'Harga pelanggan di atas harus sudah mencakup tagihan bahan. Stok bahan dipotong saat pesanan selesai.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              KeyedSubtree(
                key: const PageStorageKey('order-material-picker'),
                child: MaterialPicker(
                  initial: _materials,
                  onChanged: (v) => _materials = v,
                ),
              ),
            ], expandable: true),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: LocalText(
                'Pesanan belum menjadi pendapatan sampai kamu mengonfirmasi tahap terakhir. Uang muka dicatat melalui detail pesanan.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MaterialPicker extends StatefulWidget {
  final void Function(List<MaterialUse>) onChanged;
  final List<MaterialUse> initial;
  const MaterialPicker({
    super.key,
    required this.onChanged,
    this.initial = const [],
  });
  @override
  State<MaterialPicker> createState() => _MaterialPickerState();
}

class _MaterialPickerState extends State<MaterialPicker> {
  late final List<MaterialUse> _lines = List.of(widget.initial);
  String? _product;
  final _qty = TextEditingController(text: '1');
  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Column(
      children: [
        for (var i = 0; i < _lines.length; i++)
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            contentPadding: EdgeInsets.zero,
            title: Text(
              store.productById(_lines[i].productId)?.name ?? 'Bahan',
            ),
            subtitle: LocalText(
              '${fmtQty(_lines[i].qty)} ${store.productById(_lines[i].productId)?.unit ?? ''}',
            ),
            trailing: IconButton(
              tooltip: appTr(context, 'Hapus bahan'),
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _lines.removeAt(i);
                widget.onChanged(List.of(_lines));
              }),
            ),
          ),
        if (store.activeProducts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: LocalText(
              'Tambahkan bahan di Stok & bahan jika diperlukan.',
            ),
          )
        else ...[
          LabeledDropdown<String>(
            initialValue: _product,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Pilih bahan (opsional)',
            ),
            items: [
              for (final p in store.activeProducts)
                DropdownMenuItem(
                  value: p.id,
                  child: LocalText('${p.name} (${p.unit})'),
                ),
            ],
            onChanged: (v) => _product = v,
          ),
          const SizedBox(height: 8),
          LabeledTextField(
            controller: _qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Jumlah bahan; contoh 0,25',
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const LocalText('Tambahkan bahan'),
            onPressed: () {
              final q = quantity(_qty.text);
              if (_product == null || !q.isFinite || q <= 0) {
                showMessage(
                  context,
                  'Pilih bahan dan jumlah positif.',
                  error: true,
                );
                return;
              }
              setState(() {
                _lines.add(MaterialUse(_product!, q));
                widget.onChanged(List.of(_lines));
              });
            },
          ),
        ],
      ],
    );
  }
}

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailState();
}

class _OrderDetailState extends State<OrderDetailScreen> {
  bool _busy = false;
  Future<Uint8List>? _photo;
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _surface(Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE9EAF2)),
      ),
      child: child,
    ),
  );
  Widget _details(
    String key,
    String title,
    List<Widget> children, {
    bool open = false,
  }) => _surface(
    ExpansionTile(
      key: PageStorageKey(key),
      initiallyExpanded: open,
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: LocalText(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      children: children,
    ),
  );
  Widget _metric(String label, String value, {bool warning = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LocalText(
        label,
        style: const TextStyle(
          fontSize: 12,
          height: 1.4,
          color: Color(0xFF65687B),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 18,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: warning ? AppColors.warn : AppColors.ink,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final order = store.orders.where((o) => o.id == widget.orderId).firstOrNull;
    if (order == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F8FC),
          foregroundColor: AppColors.ink,
          title: const LocalText(
            'Detail pesanan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
        body: const Center(child: LocalText('Pesanan tidak ditemukan.')),
      );
    }
    if (order.photoDocumentId != null &&
        store.google?.auth.currentUser != null) {
      _photo ??= store.google!.downloadPhoto(
        store.google!.auth.currentUser!.uid,
        order.photoDocumentId!,
      );
    }
    final active = !order.cancelled && !order.completed;
    final late = active && order.dueAt.isBefore(store.now);
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme.copyWith(
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            height: 1.45,
          ),
        ),
        listTileTheme: base.listTileTheme.copyWith(
          titleTextStyle: base.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          subtitleTextStyle: base.textTheme.bodySmall?.copyWith(
            fontSize: 13,
            height: 1.45,
            color: const Color(0xFF65687B),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F8FC),
          foregroundColor: AppColors.ink,
          title: const LocalText(
            'Detail pesanan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
        bottomNavigationBar: !active
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: _busy
                        ? null
                        : () async {
                            final finalStep =
                                order.stage + 1 == order.stages.length - 1;
                            if (await confirmOperation(
                              context,
                              finalStep
                                  ? 'Selesaikan & catat pendapatan?'
                                  : 'Lanjutkan tahap?',
                              finalStep
                                  ? 'Pendapatan ${rp(order.total)} akan dicatat sekali. Bahan yang dipilih dipotong dari stok; pembayaran tetap dicatat terpisah.'
                                  : 'Tahap berikutnya: ${order.stages[order.stage + 1]}',
                            )) {
                              await _run(() => store.advanceOrder(order));
                            }
                          },
                    child: LocalText(
                      _busy
                          ? 'Menyimpan...'
                          : 'Lanjut: ${order.stages[order.stage + 1]}',
                    ),
                  ),
                ),
              ),
        body: ListView(
          key: const PageStorageKey('order-details'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEEEAFE), Color(0xFFE0F2FF)],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE0DCF3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        businessTypeIcon(store.businessType),
                        color: AppColors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                order.title,
                                style: const TextStyle(
                                  fontSize: 19,
                                  height: 1.3,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.customer,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF65687B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      LocalText(
                        order.cancelled
                            ? 'Dibatalkan'
                            : order.completed
                            ? 'Selesai'
                            : order.status,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      LocalText(
                        '${late ? 'Tenggat lewat · ' : ''}${fmtDate(order.dueAt)} ${fmtTime(order.dueAt)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: late
                              ? AppColors.danger
                              : const Color(0xFF65687B),
                        ),
                      ),
                    ],
                  ),
                  if (!order.cancelled) ...[
                    const SizedBox(height: 12),
                    LocalText(
                      'Tahap ${order.stage + 1} dari ${order.stages.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF65687B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (var i = 0; i < order.stages.length; i++)
                          Expanded(
                            child: Container(
                              height: 5,
                              margin: EdgeInsets.only(
                                right: i < order.stages.length - 1 ? 5 : 0,
                              ),
                              decoration: BoxDecoration(
                                color: i <= order.stage
                                    ? AppColors.primary
                                    : const Color(0xFFDAD5F1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            _surface(
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _metric('Total pesanan', rp(order.total)),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: Color(0xFFE9EAF2)),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _metric('Sudah dibayar', rp(order.paid)),
                        ),
                        if (!order.cancelled) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: _metric(
                              'Sisa pembayaran',
                              rp(order.outstanding),
                              warning: order.outstanding > 0,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!order.cancelled && order.outstanding > 0.001)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        onPressed: _busy
                            ? null
                            : () => operationForm(
                                context,
                                'Catat pembayaran',
                                [
                                  InputSpec(
                                    'amount',
                                    'Nominal (Rp)',
                                    numeric: true,
                                    initial: fmtNum(order.outstanding),
                                  ),
                                  InputSpec(
                                    'method',
                                    'Metode',
                                    initial: appTr(context, 'Tunai'),
                                  ),
                                ],
                                (v) => store.recordPayment(
                                  order,
                                  parseAmount(v['amount']!) ?? double.nan,
                                  v['method']!,
                                ),
                                note:
                                    'Catat hanya uang yang sudah benar-benar diterima. Ini tidak memindahkan uang.',
                              ),
                        child: const LocalText('Catat pembayaran / uang muka'),
                      ),
                  ],
                ),
              ),
            ),
            if (active) ...[
              if (order.stages.contains('Menunggu persetujuan'))
                CheckboxListTile(
                  secondary: const Icon(Icons.verified_outlined),
                  contentPadding: EdgeInsets.zero,
                  title: const LocalText(
                    'Persetujuan pelanggan sudah diterima',
                  ),
                  value: order.approved,
                  onChanged: _busy || order.approved
                      ? null
                      : (_) async {
                          if (await confirmOperation(
                            context,
                            'Catat persetujuan?',
                            'Konfirmasikan hanya setelah pelanggan menyetujui pekerjaan dan harganya.',
                          )) {
                            await _run(() => store.approveOrder(order));
                          }
                        },
                ),

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                onPressed: _busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderFormScreen(orderId: order.id),
                        ),
                      ),
                icon: const Icon(Icons.edit_outlined),
                label: const LocalText('Ubah detail / biaya / jadwal'),
              ),

              const SizedBox(height: 14),
            ],
            _details('order-job-details', 'Rincian pekerjaan', [
              LocalText(
                '${fmtQty(order.qty)} ${order.unit} × ${rp(order.unitPrice)} = ${rp(order.total)}',
              ),
              const SizedBox(height: 6),
              LocalText(
                'Biaya langsung/unit: ${order.directCost == null ? 'belum diketahui' : rp(order.directCost!)}',
              ),
              if (order.staff.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LocalText('Staf: ${order.staff}'),
                ),
              if (order.asset.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.shopping_bag_outlined),
                  contentPadding: EdgeInsets.zero,
                  title: const LocalText('Barang / lingkup'),
                  subtitle: Text(order.asset),
                ),
              if (order.condition.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.search_outlined),
                  contentPadding: EdgeInsets.zero,
                  title: const LocalText('Kondisi / diagnosis'),
                  subtitle: Text(order.condition),
                ),
              if (order.treatment.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.task_alt_outlined),
                  contentPadding: EdgeInsets.zero,
                  title: const LocalText('Pekerjaan disepakati'),
                  subtitle: Text(order.treatment),
                ),
            ], open: true),
            if (_photo != null)
              _details('order-photo', 'Foto barang', [
                if (_photo != null)
                  FutureBuilder<Uint8List>(
                    future: _photo,
                    builder: (_, snapshot) => snapshot.hasData
                        ? Image.memory(
                            snapshot.data!,
                            height: 220,
                            errorBuilder: (_, _, _) =>
                                const LocalText('Pratinjau tidak tersedia.'),
                          )
                        : snapshot.hasError
                        ? TextButton(
                            onPressed: () => setState(() => _photo = null),
                            child: const LocalText(
                              'Foto belum tersedia. Coba lagi',
                            ),
                          )
                        : const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                  ),
              ]),
            if (order.materials.isNotEmpty)
              _details('order-materials', 'Bahan yang digunakan', [
                for (final m in order.materials)
                  ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      store.productById(m.productId)?.name ?? 'Bahan',
                    ),
                    subtitle: LocalText(
                      '${fmtQty(m.qty)} ${store.productById(m.productId)?.unit ?? ''}',
                    ),
                  ),
              ]),
            _details('order-payments', 'Riwayat pembayaran', [
              if (order.payments.isEmpty)
                const LocalText('Belum ada pembayaran tercatat.'),
              for (final p in order.payments.reversed)
                ListTile(
                  leading: Icon(
                    p.amount < 0
                        ? Icons.undo_outlined
                        : Icons.payments_outlined,
                  ),
                  contentPadding: EdgeInsets.zero,
                  title: LocalText('${rp(p.amount)} · ${p.method}'),
                  subtitle: LocalText('${fmtDate(p.at)} ${fmtTime(p.at)}'),
                ),
            ]),
            if (active)
              _details('order-extra-actions', 'Tindakan lainnya', [
                if (!order.cancelled && !order.completed && order.paid > 0)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => operationForm(
                            context,
                            'Catat pengembalian',
                            [
                              InputSpec(
                                'amount',
                                'Nominal dikembalikan (Rp)',
                                numeric: true,
                                initial: fmtNum(order.paid),
                              ),
                            ],
                            (v) => store.recordPayment(
                              order,
                              parseAmount(v['amount']!) ?? double.nan,
                              'Pengembalian',
                              refund: true,
                            ),
                            note:
                                'Catat setelah uang benar-benar dikembalikan. Ini tidak memindahkan uang.',
                          ),
                    child: const LocalText('Catat pengembalian uang muka'),
                  ),
                if (!order.cancelled && !order.completed)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            if (await confirmOperation(
                              context,
                              'Batalkan pesanan?',
                              'Pesanan tetap disimpan dalam riwayat. Uang muka harus sudah dikembalikan.',
                            )) {
                              await _run(() => store.cancelOrder(order));
                            }
                          },
                    child: const LocalText('Batalkan pesanan'),
                  ),
              ]),
          ],
        ),
      ),
    );
  }
}

class ProductionScreen extends StatelessWidget {
  const ProductionScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return AppUi(
      child: ColoredBox(
        color: appCanvas,
        child: ListView(
          key: const PageStorageKey('production-list'),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const AppHero(
              title: 'Produksi',
              message:
                  'Catat produk hasil dan bahan baku di Stok & bahan. Buat resep, lalu konfirmasikan batch yang benar-benar diproduksi.',
              icon: Icons.factory_outlined,
            ),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecipeFormScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const LocalText('Buat resep / daftar bahan'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => wasteForm(context),
              icon: const Icon(Icons.delete_outline),
              label: const LocalText('Catat bahan / barang terbuang'),
            ),
            const SizedBox(height: 16),
            if (store.recipes.isEmpty)
              const AppSection(
                children: [
                  EmptyState(
                    icon: Icons.factory_outlined,
                    title: 'Siapkan resep pertamamu',
                    body:
                        'Pilih produk hasil dan bahan yang dipakai. Catat batch setelah produksi selesai.',
                  ),
                ],
              ),
            for (final recipe in store.recipes)
              AppSection(
                title: recipe.name,
                children: [
                  LocalText(
                    'Hasil ${fmtQty(recipe.yieldQty)} ${store.productById(recipe.outputProductId)?.unit ?? ''} ${store.productById(recipe.outputProductId)?.name ?? ''}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final m in recipe.ingredients)
                    LocalText(
                      '• ${store.productById(m.productId)?.name}: ${fmtQty(m.qty)} ${store.productById(m.productId)?.unit}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  const SizedBox(height: 8),
                  LocalText(
                    'Biaya tambahan/batch: ${recipe.extraCost == null ? 'belum diketahui' : rp(recipe.extraCost!)}',
                    style: const TextStyle(fontSize: 14, color: appSecondary),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () {
                      final id = newId('batch');
                      operationForm(
                        context,
                        'Konfirmasi produksi',
                        [
                          const InputSpec(
                            'qty',
                            'Jumlah batch; contoh 1 atau 0,5',
                            initial: '1',
                            numeric: true,
                          ),
                        ],
                        (v) => store.produce(recipe, quantity(v['qty']!), id),
                        note:
                            'Bahan akan dipotong dan stok hasil ditambah. Konfirmasikan hanya batch yang benar-benar diproduksi.',
                      );
                    },

                    icon: const Icon(Icons.check_circle_outline),
                    label: const LocalText('Catat batch produksi'),
                  ),
                ],
              ),
            AppSection(
              title: 'Riwayat produksi',
              expandable: true,
              children: [
                if (store.productionRecords.isEmpty)
                  const LocalText(
                    'Belum ada produksi tercatat.',
                    style: TextStyle(fontSize: 14),
                  ),
                for (final r in store.productionRecords.reversed.take(20))
                  ListTile(
                    leading: const Icon(Icons.factory_outlined),
                    contentPadding: EdgeInsets.zero,
                    title: LocalText(
                      '${store.recipes.where((recipe) => recipe.id == r.recipeId).firstOrNull?.name ?? 'Produksi'} · ${fmtQty(r.outputQty)} unit',
                    ),
                    subtitle: LocalText(
                      '${fmtDate(r.at)} · biaya ${r.totalCost == null ? 'belum lengkap' : rp(r.totalCost!)}',
                    ),
                  ),
              ],
            ),
            AppSection(
              title: 'Barang terbuang',
              expandable: true,
              children: [
                if (store.wasteRecords.isEmpty)
                  const LocalText(
                    'Belum ada barang terbuang tercatat.',
                    style: TextStyle(fontSize: 14),
                  ),
                for (final w in store.wasteRecords.reversed.take(20))
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    contentPadding: EdgeInsets.zero,
                    title: LocalText(
                      '${store.productById(w.productId)?.name} · ${fmtQty(w.qty)}',
                    ),
                    subtitle: LocalText(
                      '${w.reason} · ${w.cost == null ? 'biaya belum diketahui' : rp(w.cost!)}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> wasteForm(BuildContext context) async {
  final store = StoreScope.read(context);
  if (store.activeProducts.isEmpty) {
    showMessage(context, 'Tambahkan produk atau bahan terlebih dahulu.');
    return;
  }
  final product = await showDialog<Product>(
    context: context,
    builder: (d) => SimpleDialog(
      backgroundColor: Colors.white,
      title: const LocalText('Pilih barang terbuang'),
      children: [
        for (final p in store.activeProducts)
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            onPressed: () => Navigator.pop(d, p),
            child: LocalText(
              '${p.name} (${p.unit})',
              style: const TextStyle(fontSize: 16),
            ),
          ),
      ],
    ),
  );
  if (product == null || !context.mounted) return;
  await operationForm(
    context,
    'Catat ${product.name} terbuang',
    [
      InputSpec('qty', 'Jumlah (${product.unit})', numeric: true),
      const InputSpec('reason', 'Alasan'),
    ],
    (v) => store.recordWaste(product, quantity(v['qty']!), v['reason']!),
    note:
        'Stok dipotong. Nilai modal yang diketahui dicatat sebagai biaya barang terbuang.',
  );
}

class RecipeFormScreen extends StatefulWidget {
  const RecipeFormScreen({super.key});
  @override
  State<RecipeFormScreen> createState() => _RecipeFormState();
}

class _RecipeFormState extends State<RecipeFormScreen> {
  final _name = TextEditingController(),
      _yield = TextEditingController(text: '1'),
      _cost = TextEditingController();
  String? _output;
  List<MaterialUse> _materials = [];
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    _yield.dispose();
    _cost.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return AppFrame(
      title: 'Resep / daftar bahan',
      bottomBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    if (_output == null) {
                      showMessage(
                        context,
                        'Pilih produk hasil dari stok.',
                        error: true,
                      );
                      return;
                    }
                    setState(() => _busy = true);
                    try {
                      await store.addRecipe(
                        _name.text,
                        store.productById(_output)!,
                        quantity(_yield.text),
                        _materials,
                        _cost.text.trim().isEmpty
                            ? null
                            : parseAmount(_cost.text) ?? double.nan,
                      );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        showMessage(context, '$e', error: true);
                      }
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: LocalText(_busy ? 'Menyimpan...' : 'Simpan resep'),
          ),
        ),
      ),
      body: ListView(
        key: const PageStorageKey('recipe-form'),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const AppHero(
            title: 'Buat resep',
            message:
                'Pilih produk hasil dan bahan yang dipakai. Catat batch setelah produksi selesai.',
            icon: Icons.menu_book_outlined,
          ),
          AppSection(
            title: 'Produk hasil',
            children: [
              AppTextField(
                controller: _name,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Nama resep / produk',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              AppDropdown<String>(
                isExpanded: true,
                initialValue: _output,
                decoration: const InputDecoration(labelText: 'Produk hasil'),
                items: [
                  for (final p in store.activeProducts)
                    DropdownMenuItem(
                      value: p.id,
                      child: LocalText('${p.name} (${p.unit})'),
                    ),
                ],
                onChanged: (v) => _output = v,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _yield,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Jumlah hasil per batch',
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
          AppSection(
            title: 'Bahan per batch',
            children: [MaterialPicker(onChanged: (v) => _materials = v)],
          ),
          AppSection(
            title: 'Biaya tambahan',
            children: [
              AppTextField(
                controller: _cost,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Biaya langsung tambahan per batch (opsional)',
                ),
              ),
              const SizedBox(height: 10),
              const LocalText(
                'Di luar bahan dan biaya umum. Kosong = belum diketahui; isi 0 jika memang tidak ada.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
