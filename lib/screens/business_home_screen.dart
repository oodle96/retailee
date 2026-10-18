import 'dart:convert';
import 'package:flutter/material.dart';
import '../models.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/app_ui.dart';
import '../utils/format.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import 'business_setup_screen.dart';
import 'document_screen.dart';
import 'home_shell.dart';
import 'operations_screen.dart';
import 'owner_profile_screen.dart';
import 'scan_screen.dart';
import 'stock_screen.dart';
import 'language_setup_screen.dart';
import 'report_screen.dart';

Future<void> manualSales(BuildContext context, {bool goods = false}) async {
  final store = StoreScope.read(context);
  final service = store.serviceFirst && !goods;
  if (!service && store.sellableProducts.isEmpty) {
    showMessage(context, 'Tambahkan produk di Stok & bahan terlebih dahulu.');
    return;
  }
  final doc = await store.createDocument(
    service ? DocKind.serviceIncome : DocKind.dailySales,
  );
  await store.startManualDraft(doc.id);
  if (context.mounted) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DocumentScreen(docId: doc.id)),
    );
  }
}

Future<void> manualExpense(BuildContext context) {
  final store = StoreScope.read(context);
  return operationForm(
    context,
    'Catat biaya usaha',
    [
      const InputSpec('description', 'Keterangan'),
      const InputSpec('amount', 'Nominal (Rp)', numeric: true),
      const InputSpec('category', 'Kategori', initial: 'Lainnya'),
    ],
    (v) async {
      final amount = parseAmount(v['amount']!) ?? double.nan;
      if (!amount.isFinite || amount <= 0) {
        throw StateError('Nominal harus lebih dari nol.');
      }
      await store.addExpenseManual(
        description: v['description']!,
        category: v['category']!,
        amount: amount,
        type: ExpenseType.businessExpense,
      );
    },
    note:
        'Catat biaya umum. Biaya bahan dan biaya langsung yang sudah masuk layanan atau pesanan jangan dihitung dua kali.',
  );
}

class BusinessHomeScreen extends StatelessWidget {
  const BusinessHomeScreen({super.key});

  Widget _heading(String text, IconData icon) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 22, 4, 12),
    child: Row(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: LocalText(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _action(String title, IconData icon, VoidCallback onTap) => Material(
    color: const Color(0xFFEEEAFE),
    borderRadius: BorderRadius.circular(26),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFD9D2FB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.primaryDark, size: 28),
            ),
            const SizedBox(height: 14),
            LocalText(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _metric({
    required String label,
    required String value,
    required IconData icon,
    String? sub,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFEEEAFE),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFD9D2FB),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(icon, color: AppColors.primaryDark, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalText(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (sub != null) ...[
                const SizedBox(height: 6),
                LocalText(
                  sub,
                  style: const TextStyle(fontSize: 16, height: 1.35),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context),
        month = StoreScope.of(
          context,
        ).summaryForMonth(StoreScope.of(context).now);
    final late = store.activeOrders
        .where((o) => o.dueAt.isBefore(store.now))
        .length;
    final starter = store.hasGoods
        ? store.activeProducts.isEmpty
        : store.offerings.isEmpty;
    return ColoredBox(
      color: const Color(0xFF7466E5),
      child: Theme(
        data: Theme.of(context).copyWith(
          cardTheme: const CardThemeData(
            color: Color(0xFFEEEAFE),
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(28)),
            ),
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: store.syncCloud,
            child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEAFE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const RetaileeMark(size: 44),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store.business?.name ?? 'Usahamu',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: LocalText(
                              store.template.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFEEEAFE),
                        foregroundColor: AppColors.primaryDark,
                      ),
                      tooltip: appTr(context, 'Pengaturan usaha'),
                      onPressed: () => businessSettings(context),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.payments_outlined,
                            color: Colors.white,
                            size: 25,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: LocalText(
                              'Pendapatan bulan ini',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        rp(month.revenue),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      LocalText(
                        '${month.saleCount} penjualan / pekerjaan selesai',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(color: Color(0xFF8C7DC5), height: 1),
                      ),
                      const LocalText(
                        'Perkiraan untung bersih',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      LocalText(
                        month.netProfit == null
                            ? 'Belum lengkap'
                            : rp(month.netProfit!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      LocalText(
                        month.cogsComplete
                            ? 'Setelah biaya usaha ${rp(month.opex)}'
                            : 'Lengkapi biaya langsung, bahan atau harga modal',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                _heading('Mau catat apa?', Icons.add_circle_outline),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final action in <(String, IconData, VoidCallback)>[
                        if (store.hasGoods)
                          (
                            'Penjualan',
                            Icons.point_of_sale_rounded,
                            () => manualSales(context),
                          ),
                        (
                          'Pesanan baru',
                          Icons.assignment_outlined,
                          () => openOrderForm(context),
                        ),
                        (
                          'Biaya usaha',
                          Icons.account_balance_wallet_outlined,
                          () => manualExpense(context),
                        ),
                        (
                          store.hasGoods ? 'Stok & bahan' : 'Daftar layanan',
                          store.hasGoods
                              ? Icons.inventory_2_outlined
                              : Icons.design_services_outlined,
                          () => store.hasGoods
                              ? Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const StockScreen(),
                                  ),
                                )
                              : offeringForm(context),
                        ),
                        if (store.producesGoods)
                          (
                            'Produksi',
                            Icons.factory_outlined,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AppPage(
                                  appBar: AppBar(
                                    title: const LocalText('Produksi'),
                                  ),
                                  body: const ProductionScreen(),
                                ),
                              ),
                            ),
                          ),
                      ])
                        SizedBox(
                          width: constraints.maxWidth < 320
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 12) / 2,
                          child: _action(action.$1, action.$2, action.$3),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (starter)
                  Card(
                    color: AppColors.primarySoft,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LocalText(
                            store.template.firstAction,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LocalText(
                            store.hasGoods
                                ? 'Mulai dari produk dan bahan yang memang ada. Harga modal yang belum diketahui boleh dikosongkan.'
                                : 'Masukkan layanan, satuan harga dan biaya langsung jika sudah diketahui.',
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => store.hasGoods
                                ? Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const StockScreen(),
                                    ),
                                  )
                                : offeringForm(context),
                            child: LocalText(
                              store.hasGoods
                                  ? 'Catat produk & bahan'
                                  : 'Buat layanan',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                _heading('Yang perlu dipantau', Icons.space_dashboard_outlined),
                if (store.serviceFirst || store.orders.isNotEmpty) ...[
                  _metric(
                    label: 'Pesanan berjalan',
                    value: '${store.activeOrders.length}',
                    sub: '$late melewati jadwal / tenggat',
                    icon: Icons.assignment_outlined,
                  ),
                  _metric(
                    label: 'Sisa tagihan pesanan',
                    value: rp(store.orderReceivables),
                    sub: 'Uang muka dan pelunasan terpisah dari status kerja',
                    icon: Icons.receipt_long_outlined,
                  ),
                ],
                if (store.hasGoods)
                  _metric(
                    label: 'Produk / bahan menipis',
                    value:
                        '${store.activeProducts.where((p) => p.isLowStock).length}',
                    sub: 'Periksa stok dan kebutuhan barang',
                    icon: Icons.inventory_2_outlined,
                  ),
                const SizedBox(height: 8),
                _heading('Arahan untuk usahamu', Icons.auto_awesome_outlined),
                const BusinessAdvicePanel(),
                if (store.openDrafts.isNotEmpty)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.drafts_outlined),
                      title: LocalText(
                        '${store.openDrafts.length} draf belum selesai',
                      ),
                      subtitle: const LocalText(
                        'Periksa sebelum mengonfirmasi ke pembukuan.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DocumentScreen(docId: store.openDrafts.first.id),
                        ),
                      ),
                    ),
                  ),
                _heading('Kebiasaan usaha', Icons.emoji_events_outlined),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        XpBar(store: store),
                        TextButton.icon(
                          icon: const Icon(Icons.arrow_forward_rounded),
                          onPressed: () => HomeShell.goTo(context, 4),
                          label: const LocalText('Lihat misi sesuai usahamu'),
                        ),
                      ],
                    ),
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

class BusinessAdvicePanel extends StatelessWidget {
  const BusinessAdvicePanel({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context),
        advice = StoreScope.of(context).advice;
    final source = store.adviceContextSaved == null
        ? store.adviceContext
        : jsonDecode(store.adviceContextSaved!) as Map<String, dynamic>;
    final facts = {
      for (final f in source['facts'] as List) f['id'] as String: f as Map,
    };
    final visible =
        advice?.recommendations
            .where(
              (r) => !store.adviceFeedback.any(
                (f) => f['id'] == r['id'] && f['useful'] == false,
              ),
            )
            .toList() ??
        [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LocalText(
              store.business?.priority.isNotEmpty == true
                  ? 'Tujuan: ${store.business!.priority}'
                  : 'Tujuan: ${ownerGoalLabels[store.profile?.goal]}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const LocalText(
              'Gemini memakai jenis usaha, tujuan, ringkasan catatan terkonfirmasi dan masukanmu. Nama serta foto pelanggan tidak dikirim untuk saran ini.',
            ),
            if (advice == null)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: LocalText(
                  store.advisor == null
                      ? 'Kamu sedang memakai demo lokal. Arahan Gemini tersedia pada aplikasi yang terhubung dengan Google. Catatan usaha tetap bisa dipakai di demo ini.'
                      : 'Belum ada arahan Gemini. Minta arahan awal atau mulai mencatat terlebih dahulu.',
                ),
              ),
            if (advice != null) ...[
              const SizedBox(height: 12),
              Text(advice.intro),
              LocalText(
                'Model ${advice.model} · ${fmtDate(DateTime.parse(advice.generatedAt).toLocal())} ${fmtTime(DateTime.parse(advice.generatedAt).toLocal())}',
                style: const TextStyle(color: AppColors.ink, fontSize: 16),
              ),
              if (store.adviceStale)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LocalText(
                    'Catatan / pilihanmu berubah. Perbarui arahan agar memakai konteks terbaru.',
                    style: TextStyle(color: AppColors.warn),
                  ),
                ),
              for (final r in visible) ...[
                const Divider(height: 28),
                Text(
                  r['title'] as String,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(r['explanation'] as String),
                for (final id in r['factIds'] as List)
                  if (facts[id] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: LocalText(
                        '${facts[id]!['label']}: ${facts[id]!['value'] == null
                            ? 'belum diketahui'
                            : facts[id]!['unit'] == 'Rp'
                            ? rp(facts[id]!['value'] as num)
                            : '${facts[id]!['value']} ${appTr(context, facts[id]!['unit'] as String)}'}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    r['action'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () =>
                          adviceAction(context, r['topic'] as String),
                      child: const LocalText('Buka catatan terkait'),
                    ),
                    TextButton(
                      onPressed: () => store.rateBusinessAdvice(r, true),
                      child: const LocalText('Berguna'),
                    ),
                    TextButton(
                      onPressed: () => store.rateBusinessAdvice(r, false),
                      child: const LocalText('Tidak sesuai'),
                    ),
                  ],
                ),
              ],
              if (visible.isEmpty)
                const LocalText(
                  'Semua arahan disembunyikan berdasarkan masukanmu. Perbarui untuk arahan baru.',
                ),
            ],
            if (store.adviceError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: LocalText(
                  store.adviceError!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            const SizedBox(height: 14),
            if (store.advisor != null)
              FilledButton(
                onPressed: store.adviceBusy
                    ? null
                    : store.refreshBusinessAdvice,
                child: store.adviceBusy
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          LocalText('Meminta arahan...'),
                        ],
                      )
                    : LocalText(
                        advice == null
                            ? 'Minta arahan Gemini'
                            : 'Perbarui arahan Gemini',
                      ),
              ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OwnerProfileScreen()),
              ),
              child: const LocalText('Lihat & atur personalisasi'),
            ),
          ],
        ),
      ),
    );
  }
}

void adviceAction(BuildContext context, String topic) {
  if (topic == 'costs') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppPage(
          appBar: AppBar(title: const LocalText('Laporan')),
          body: const ReportScreen(),
        ),
      ),
    );
    return;
  }
  if (topic == 'habit') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppPage(
          appBar: AppBar(title: const LocalText('Foto catatan')),
          body: const ScanScreen(),
        ),
      ),
    );
    return;
  }
  if (topic == 'stock') {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StockScreen()),
    );
    return;
  }
  if (topic == 'production' || topic == 'waste') {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppPage(
          appBar: AppBar(title: const LocalText('Produksi & bahan')),
          body: const ProductionScreen(),
        ),
      ),
    );
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          OperationsScreen(initialIndex: topic == 'pricing' ? 1 : 0),
    ),
  );
}

void businessSettings(BuildContext context) {
  final store = StoreScope.read(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFFF7F8FC),
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (d) => FractionallySizedBox(
      heightFactor: .92,
      child: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: store,
          builder: (_, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: const LocalText(
                          'Pengaturan usaha',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: appTr(d, 'Tutup'),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFE9EAF2)),
                      ),
                      onPressed: () => Navigator.pop(d),
                      icon: const Icon(Icons.close_rounded, size: 22),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE9EAF2)),
              Expanded(
                child: ListView(
                  key: const PageStorageKey('business-settings'),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  children: [
                    _SettingsIdentity(store: store),
                    _settingsHeading('Usahamu'),
                    _SettingsAction(
                      leading: const Icon(Icons.storefront_outlined),
                      title: const LocalText('Profil & jenis usaha'),
                      subtitle: const LocalText(
                        'Jenis, satuan, tujuan, cara kerja',
                      ),
                      onTap: () {
                        Navigator.pop(d);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const BusinessSetupScreen(editing: true),
                          ),
                        );
                      },
                    ),
                    _SettingsAction(
                      leading: const Icon(Icons.tune),
                      title: const LocalText('Personalisasi & masukan'),
                      onTap: () {
                        Navigator.pop(d);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OwnerProfileScreen(),
                          ),
                        );
                      },
                    ),
                    _settingsHeading('Kegiatan usaha'),
                    _SettingsAction(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: const LocalText('Stok & alat usaha'),
                      onTap: () {
                        Navigator.pop(d);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OperationsScreen(),
                          ),
                        );
                      },
                    ),
                    _SettingsAction(
                      leading: const Icon(Icons.edit_note),
                      title: const LocalText('Catat manual'),
                      onTap: () {
                        Navigator.pop(d);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BusinessEntryScreen(),
                          ),
                        );
                      },
                    ),
                    _settingsHeading('Preferensi'),
                    _SettingsAction(
                      leading: const Icon(Icons.language_rounded),
                      title: const LocalText('Bahasa'),
                      subtitle: Text(
                        store.languageCode == 'en'
                            ? 'English'
                            : 'Bahasa Indonesia',
                      ),
                      onTap: () {
                        Navigator.pop(d);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const LanguageSetupScreen(editing: true),
                          ),
                        );
                      },
                    ),
                    _settingsHeading('Data & akun'),
                    _SettingsAction(
                      leading: const Icon(Icons.account_circle_outlined),
                      title: Text(
                        store.userName ?? appTr(context, 'Pemilik usaha'),
                      ),
                      subtitle: Text(
                        store.userEmail ?? appTr(context, 'Demo lokal'),
                      ),
                    ),
                    if (store.googleEnabled) ...[
                      _SettingsAction(
                        leading: const Icon(Icons.cloud_outlined),
                        title: LocalText(
                          store.syncing
                              ? 'Mengirim cadangan...'
                              : store.cloudPending
                              ? 'Cadangan tertunda'
                              : 'Cadangan Google',
                        ),
                        subtitle: LocalText(
                          store.syncError ??
                              (store.cloudPending
                                  ? 'Data lokal disimpan. Ketuk untuk mencoba lagi.'
                                  : 'Tidak ada perubahan tertunda.'),
                        ),
                        onTap: store.syncing ? null : store.syncCloud,
                      ),
                      _SettingsAction(
                        leading: const Icon(Icons.cloud_download_outlined),
                        title: const LocalText('Pulihkan cadangan cloud'),
                        subtitle: const LocalText(
                          'Data lokal akan diganti dengan cadangan cloud.',
                        ),
                        onTap: store.syncing
                            ? null
                            : () async {
                                if (!await confirmOperation(
                                  d,
                                  'Pulihkan cadangan?',
                                  'Data lokal termasuk perubahan yang belum dicadangkan akan diganti dengan cadangan cloud.',
                                )) {
                                  return;
                                }
                                try {
                                  await store.restoreCloud();
                                  if (d.mounted) Navigator.pop(d);
                                } catch (e) {
                                  if (d.mounted) {
                                    showMessage(d, '$e', error: true);
                                  }
                                }
                              },
                      ),
                    ],
                    _SettingsAction(
                      danger: true,
                      leading: const Icon(Icons.logout),
                      title: const LocalText('Keluar'),
                      onTap: () async {
                        try {
                          await store.signOut();
                          if (d.mounted) Navigator.pop(d);
                        } catch (e) {
                          if (d.mounted) showMessage(d, '$e', error: true);
                        }
                      },
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

Widget _settingsHeading(String label) => Padding(
  padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
  child: Semantics(
    header: true,
    child: LocalText(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF65687B),
      ),
    ),
  ),
);

class _SettingsIdentity extends StatelessWidget {
  final AppStore store;
  const _SettingsIdentity({required this.store});
  @override
  Widget build(BuildContext context) => Container(
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
    child: Row(
      children: [
        const RetaileeMark(size: 56),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store.business?.name ?? appTr(context, 'Usahamu'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 6),
              LocalText(
                store.template.name,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Color(0xFF65687B),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SettingsAction extends StatelessWidget {
  final Widget leading, title;
  final Widget? subtitle;
  final VoidCallback? onTap;
  final bool danger;
  const _SettingsAction({
    required this.leading,
    required this.title,
    this.subtitle,
    this.onTap,
    this.danger = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE9EAF2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: danger
                      ? const Color(0xFFFFEEEE)
                      : const Color(0xFFF0EDFC),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: IconTheme(
                  data: IconThemeData(
                    size: 22,
                    color: danger ? AppColors.danger : AppColors.primary,
                  ),
                  child: leading,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: danger ? AppColors.danger : AppColors.ink,
                      ),
                      child: title,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      DefaultTextStyle.merge(
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xFF65687B),
                        ),
                        child: subtitle!,
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFF777589),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class BusinessEntryScreen extends StatelessWidget {
  const BusinessEntryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return AppFrame(
      title: 'Catat kegiatan usaha',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AppHero(
              title: 'Catat kegiatan usaha',
              message: store.template.name,
              icon: Icons.edit_note_rounded,
            ),
            if (store.serviceFirst || store.mixedBusiness) ...[
              AppEntryTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: const LocalText('Layanan selesai'),
                subtitle: const LocalText(
                  'Isi manual, periksa lalu konfirmasi',
                ),
                onTap: () async {
                  final doc = await store.createDocument(DocKind.serviceIncome);
                  await store.startManualDraft(doc.id);
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DocumentScreen(docId: doc.id),
                      ),
                    );
                  }
                },
              ),
              AppEntryTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const LocalText('Foto catatan layanan selesai'),
                onTap: () => startScan(context, DocKind.serviceIncome),
              ),
            ],
            const SizedBox(height: 8),
            if (!store.serviceFirst || store.mixedBusiness) ...[
              AppEntryTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const LocalText('Penjualan barang / menu'),
                subtitle: const LocalText(
                  'Isi manual, periksa lalu konfirmasi',
                ),
                onTap: () => manualSales(context, goods: true),
              ),
              AppEntryTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const LocalText('Foto catatan penjualan'),
                onTap: () => startScan(context, DocKind.dailySales),
              ),
              AppEntryTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const LocalText('Foto stok barang / bahan'),
                onTap: () => startScan(context, DocKind.openingStock),
              ),
            ],
            AppEntryTile(
              leading: const Icon(Icons.assignment_outlined),
              title: const LocalText('Pesanan / layanan pelanggan'),
              subtitle: const LocalText(
                'Jadwal, pekerjaan, bahan dan pembayaran',
              ),
              onTap: () => openOrderForm(context),
            ),
            AppEntryTile(
              leading: const Icon(Icons.payments_outlined),
              title: const LocalText('Biaya usaha'),
              onTap: () => manualExpense(context),
            ),
            AppEntryTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const LocalText('Foto struk biaya'),
              onTap: () => startScan(context, DocKind.expenseReceipt),
            ),
            if (store.producesGoods)
              AppEntryTile(
                leading: const Icon(Icons.factory_outlined),
                title: const LocalText('Produksi & barang terbuang'),
                onTap: () => adviceAction(context, 'production'),
              ),
            if (store.openDrafts.isNotEmpty)
              const SectionHeader('Draf belum selesai'),
            for (final doc in store.openDrafts)
              AppEntryTile(
                leading: const Icon(Icons.description_outlined),
                title: LocalText(docKindLabels[doc.kind]!),
                subtitle: LocalText(
                  '${fmtDate(doc.date)} · ${doc.status.name}',
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DocumentScreen(docId: doc.id),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
