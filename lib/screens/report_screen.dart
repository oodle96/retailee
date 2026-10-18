import 'package:flutter/material.dart';

import '../models.dart';
import '../services/ledger.dart';
import '../services/store.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/retail_art.dart';
import '../widgets/report_graphics.dart';
import 'scan_screen.dart';
import 'operations_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _month = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = store.now;
    bool inPeriod(DateTime d) =>
        _month ? monthKey(d) == monthKey(now) : dayKey(d) == dayKey(now);
    final s = store.summary(inPeriod);
    final perf = store.productPerformance(inPeriod);
    final exps = store.expenses.where((e) => inPeriod(e.date)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final spending = <String, double>{};
    for (final e in exps.where((e) => e.type == ExpenseType.businessExpense)) {
      spending[e.category] = (spending[e.category] ?? 0) + e.amount;
    }
    final categories = spending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE9EAF2)),
          ),
        ),
        textTheme: base.textTheme.copyWith(
          bodyMedium: const TextStyle(
            fontSize: 15,
            height: 1.45,
            color: AppColors.ink,
          ),
          bodySmall: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: Color(0xFF65687B),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 52),
            foregroundColor: AppColors.primaryDark,
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            side: const BorderSide(color: Color(0xFFDAD4EF)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      child: Builder(
        builder: (context) => Material(
          color: const Color(0xFFF7F8FC),
          child: SafeArea(
            child: ListView(
              key: const PageStorageKey('report-overview'),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: const LocalText(
                          'Laporan',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                    const InfoButton(
                      title: 'Ringkasan usaha',
                      message:
                          'Dari catatan yang sudah kamu konfirmasi.\n\nRingkasan mengikuti pilihan periode. Grafik menunjukkan pendapatan 7 atau 30 hari terakhir.',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const LocalText('Hari ini'),
                      selected: !_month,
                      avatar: Icon(
                        Icons.today_outlined,
                        size: 18,
                        color: !_month ? Colors.white : AppColors.primaryDark,
                      ),
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: !_month ? Colors.white : AppColors.primaryDark,
                      ),
                      side: const BorderSide(color: Color(0xFFE4DFF4)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 9,
                      ),
                      onSelected: (_) => setState(() => _month = false),
                    ),
                    ChoiceChip(
                      label: Text(fmtMonth(now)),
                      selected: _month,
                      avatar: Icon(
                        Icons.date_range_outlined,
                        size: 18,
                        color: _month ? Colors.white : AppColors.primaryDark,
                      ),
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _month ? Colors.white : AppColors.primaryDark,
                      ),
                      side: const BorderSide(color: Color(0xFFE4DFF4)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 9,
                      ),
                      onSelected: (_) => setState(() => _month = true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ReportSummary(
                  summary: s,
                  period: _month ? fmtMonth(now) : fmtDate(now),
                  onCapture: () => startScan(
                    context,
                    store.serviceFirst
                        ? DocKind.serviceIncome
                        : store.products.isEmpty
                        ? DocKind.openingStock
                        : DocKind.dailySales,
                  ),
                  captureLabel: store.serviceFirst
                      ? 'Foto catatan layanan selesai'
                      : store.products.isEmpty
                      ? 'Catat stok awal dulu'
                      : 'Foto catatan penjualan',
                ),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: LocalText(
                    _month
                        ? 'Pendapatan 30 hari terakhir'
                        : 'Pendapatan 7 hari terakhir',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SalesTrend(
                  compact: true,
                  data: store.revenueTrend(_month ? 30 : 7),
                  recordedDays: store.sales
                      .map((sale) => dayKey(sale.date))
                      .toSet(),
                ),
                const SizedBox(height: 16),
                _details(
                  'Ke mana pendapatan usahamu?',
                  Icons.account_balance_wallet_outlined,
                  [MoneyBreakdown(summary: s)],
                ),
                const SizedBox(height: 12),
                _details(
                  'Produk / layanan penyumbang pendapatan',
                  Icons.bar_chart_rounded,
                  [
                    Text(
                      '${appTr(context, 'Periode')}: ${_month ? fmtMonth(now) : fmtDateLong(now)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF65687B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (perf.isEmpty)
                      const LocalText('Belum ada pendapatan di periode ini.'),
                    for (final p in perf)
                      RankedAmount(
                        label: p.name,
                        amount: p.revenue,
                        maximum: perf.fold<double>(
                          0,
                          (v, p) => p.revenue > v ? p.revenue : v,
                        ),
                        detail:
                            '${fmtQty(p.qty)} ${appTr(context, store.serviceFirst ? 'layanan selesai' : 'terjual')} · ${appTr(context, 'Laba kotor')}: ${p.profit == null ? appTr(context, 'Belum lengkap') : rp(p.profit!)}',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _details('Rincian perhitungan', Icons.calculate_outlined, [
                  _profitCard(s),
                ]),
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _details('Biaya terbesar di mana?', Icons.pie_chart_outline, [
                    for (final c in categories)
                      RankedAmount(
                        label: c.key,
                        amount: c.value,
                        maximum: categories.first.value,
                        color: AppColors.warn,
                      ),
                  ]),
                ],
                if (store.orders.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LocalText(
                            'Sisa tagihan seluruh pesanan: ${rp(store.orderReceivables)}',
                          ),
                          const SizedBox(height: 8),
                          LocalText(
                            'Uang muka pekerjaan belum selesai: ${rp(store.activeOrders.fold<double>(0, (a, o) => a + o.paid))}',
                          ),
                          const SizedBox(height: 8),
                          const LocalText(
                            'Tagihan dan uang muka mencakup semua tanggal. Pendapatan di atas mengikuti periode penyelesaian pekerjaan, bukan waktu pembayaran.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF65687B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                SectionHeader(
                  'Pengeluaran',
                  action: 'Foto struk',
                  onAction: () => startScan(context, DocKind.expenseReceipt),
                ),
                OutlinedButton.icon(
                  onPressed: () => _addExpense(context, store),
                  icon: const Icon(Icons.add),
                  label: const LocalText('Catat pengeluaran manual'),
                ),
                const SizedBox(height: 12),
                if (exps.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LocalText(
                      'Belum ada pengeluaran di periode ini.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF65687B)),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final e in exps)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  switch (e.type) {
                                    ExpenseType.businessExpense =>
                                      Icons.receipt_outlined,
                                    ExpenseType.personalWithdrawal =>
                                      Icons.person_outline,
                                    ExpenseType.inventoryPurchase =>
                                      Icons.inventory_2_outlined,
                                  },
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.description,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      LocalText(
                                        '${expenseTypeLabels[e.type]} · ${e.type == ExpenseType.businessExpense ? e.category : ''} · ${fmtDate(e.date)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF65687B),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        rp(e.amount),
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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

  Widget _details(String title, IconData icon, List<Widget> children) => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      key: PageStorageKey('report-$title'),
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: LocalText(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: children,
    ),
  );
  Widget _profitCard(PeriodSummary s) {
    final incomplete = s.hasSales && !s.cogsComplete;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const LocalText(
                  'Laba rugi sederhana',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                if (incomplete) Pill.warn('Belum lengkap'),
              ],
            ),
            const SizedBox(height: 12),
            const ExpansionTile(
              key: PageStorageKey('report-profit-explainer'),
              tilePadding: EdgeInsets.zero,
              title: LocalText(
                'Bagaimana laba dihitung?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LocalText(
                    'Laba kotor = pendapatan − biaya langsung, termasuk bahan yang dipakai. Estimasi laba bersih = laba kotor − biaya usaha. Biaya yang belum diketahui membuat laba belum lengkap, bukan nol.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              ],
            ),
            _line('Pendapatan', rp(s.revenue), bold: true),
            _line(
              'Biaya langsung',
              s.hasSales
                  ? (s.cogsComplete
                        ? '− ${rp(s.knownCogs)}'
                        : '− ≥ ${rp(s.knownCogs)}')
                  : '—',
            ),
            const Divider(height: 20),
            _line(
              'Laba kotor',
              s.grossProfit == null
                  ? (incomplete ? 'Belum lengkap' : '—')
                  : rp(s.grossProfit!),
              bold: true,
              color: AppColors.primary,
            ),
            _line(
              'Margin kotor',
              s.grossMarginPct == null
                  ? '—'
                  : '${s.grossMarginPct!.toStringAsFixed(2)}%',
            ),
            _line('Biaya usaha', '− ${rp(s.opex)}'),
            const Divider(height: 20),
            _line(
              'Estimasi laba bersih',
              s.netProfit == null
                  ? (incomplete ? 'Belum lengkap' : '—')
                  : rp(s.netProfit!),
              bold: true,
              big: true,
              color: (s.netProfit ?? 0) < 0 ? AppColors.danger : AppColors.ink,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _line(
                    'Ambil pribadi (tidak mengurangi laba)',
                    rp(s.personal),
                    small: true,
                  ),
                  _line(
                    'Belanja stok (masuk nilai persediaan)',
                    rp(s.inventoryPurchases),
                    small: true,
                  ),
                ],
              ),
            ),
            if (incomplete) ...[
              const SizedBox(height: 10),
              const LocalText(
                'Sebagian biaya langsung belum diketahui. Lengkapi biaya saat memeriksa catatan; laba belum dapat dipastikan.',
                style: TextStyle(
                  color: AppColors.warn,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OperationsScreen(initialIndex: 2),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const LocalText('Lengkapi harga modal'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line(
    String k,
    String v, {
    bool bold = false,
    bool big = false,
    bool small = false,
    Color? color,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LocalText(
          k,
          style: TextStyle(
            color: bold ? AppColors.ink : AppColors.muted,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            fontSize: 16,
          ),
        ),
        LocalText(
          v,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            fontSize: big ? 24 : 20,
            color: color,
          ),
        ),
      ],
    ),
  );

  Future<void> _addExpense(BuildContext context, AppStore store) async {
    final desc = TextEditingController();
    final amount = TextEditingController();
    var cat = 'Lainnya';
    var type = ExpenseType.businessExpense;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(20),
              children: [
                const InfoHeading(
                  title: 'Catat pengeluaran',
                  message:
                      'Belanja barang dagangan? Gunakan Restock di tab Stok atau Foto struk.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                SegmentedButton<ExpenseType>(
                  segments: const [
                    ButtonSegment(
                      value: ExpenseType.businessExpense,
                      label: LocalText('Biaya usaha'),
                    ),
                    ButtonSegment(
                      value: ExpenseType.personalWithdrawal,
                      label: LocalText('Pribadi'),
                    ),
                  ],
                  selected: {type},
                  onSelectionChanged: (v) => set(() => type = v.first),
                ),
                const SizedBox(height: 6),
                const SizedBox(height: 12),
                LabeledTextField(
                  controller: desc,
                  decoration: const InputDecoration(labelText: 'Keterangan'),
                ),
                const SizedBox(height: 10),
                LabeledTextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nominal',
                    prefixText: 'Rp ',
                  ),
                ),
                if (type == ExpenseType.businessExpense) ...[
                  const SizedBox(height: 10),
                  LabeledDropdown<String>(
                    initialValue: cat,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: [
                      for (final c in expenseCategories)
                        DropdownMenuItem(value: c, child: LocalText(c)),
                    ],
                    onChanged: (v) => cat = v ?? 'Lainnya',
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const LocalText('Simpan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final a = parseAmount(amount.text) ?? 0;
    if (ok == true && a > 0 && desc.text.trim().isNotEmpty) {
      await store.addExpenseManual(
        description: desc.text.trim(),
        category: type == ExpenseType.businessExpense ? cat : 'Pribadi',
        amount: a,
        type: type,
      );
      if (context.mounted) showMessage(context, 'Pengeluaran tercatat');
    } else if (ok == true && context.mounted) {
      showMessage(context, 'Isi keterangan dan nominal.', error: true);
    }
  }
}

class _ReportSummary extends StatelessWidget {
  final PeriodSummary summary;
  final String period, captureLabel;
  final VoidCallback onCapture;
  const _ReportSummary({
    required this.summary,
    required this.period,
    required this.captureLabel,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final incomplete = s.hasSales && !s.cogsComplete;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEEEAFE), Color(0xFFEAF4FF)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE0DCF3)),
        boxShadow: const [
          BoxShadow(color: Color(0xFFDFDDF0), offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LocalText(
                      'Ringkasan usaha',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      period,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF65687B),
                      ),
                    ),
                  ],
                ),
              ),
              const RetailArt(scene: RetailScene.receipts, width: 64),
            ],
          ),
          const SizedBox(height: 12),
          const LocalText(
            'Pendapatan',
            style: TextStyle(fontSize: 14, color: Color(0xFF65687B)),
          ),
          const SizedBox(height: 4),
          Text(
            rp(s.revenue),
            style: const TextStyle(
              fontSize: 32,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final cost = _metric('Biaya usaha', rp(s.opex));
              final profit = _metric(
                'Estimasi laba bersih',
                s.netProfit == null
                    ? (incomplete ? 'Belum lengkap' : '—')
                    : rp(s.netProfit!),
                color: (s.netProfit ?? 0) < 0
                    ? AppColors.danger
                    : AppColors.ink,
              );
              return MediaQuery.textScalerOf(context).scale(14) > 20
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [cost, const SizedBox(height: 14), profit],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cost),
                        const SizedBox(width: 16),
                        Expanded(child: profit),
                      ],
                    );
            },
          ),
          if (incomplete) ...[
            const SizedBox(height: 16),
            const LocalText(
              'Biaya langsung belum lengkap. Laba belum bisa dipastikan.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppColors.warn,
              ),
            ),
          ],
          if (!s.hasSales) ...[
            const SizedBox(height: 16),
            const LocalText(
              'Belum ada pendapatan di periode ini',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 5),
            const LocalText(
              'Catat penjualan atau selesaikan pekerjaan. Pendapatan muncul setelah dikonfirmasi.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF65687B),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.photo_camera_outlined, size: 20),
              label: LocalText(captureLabel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(String label, String value, {Color color = AppColors.ink}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalText(
            label,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF65687B),
            ),
          ),
          const SizedBox(height: 5),
          LocalText(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );
}
