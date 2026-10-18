import 'package:flutter/material.dart';

import '../models.dart';
import '../services/ledger.dart';
import '../services/store.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/brand.dart';
import 'home_shell.dart';
import 'owner_profile_screen.dart';
import 'scan_screen.dart';
import 'missions_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final today = store.summaryForDay(store.now);
    final month = store.summaryForMonth(store.now);
    final insights = store.insights;
    final missions = store.missions.where((m) => !m.claimed).toList()
      ..sort((a, b) => (b.verified ? 1 : 0).compareTo(a.verified ? 1 : 0));
    final low = store.activeProducts.where((p) => p.isLowStock).length;
    final drafts = store.openDrafts;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => store.refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _header(context, store),
            const SizedBox(height: 14),
            if (store.products.isEmpty)
              _setupCard(context)
            else
              _heroCard(context, store, today),
            if (drafts.isNotEmpty) ...[
              const SizedBox(height: 12),
              _draftBanner(context, drafts.length),
            ],
            if (store.products.isNotEmpty) ...[
              const SizedBox(height: 12),
              SectionHeader(
                'Rekomendasi untukmu',
                info: store.hiddenInsightCount > 0
                    ? '${store.hiddenInsightCount} saran disembunyikan karena kamu menandainya tidak berguna.'
                    : null,
                leading: const RetaileeMark(size: 32),
                action: insights.length > 1
                    ? 'Semua (${insights.length})'
                    : null,
                onAction: () => _showAllInsights(context),
              ),
              if (store.profile != null) _goalStrip(context, store),
              for (var k = 0; k < insights.length && k < 1; k++) ...[
                insightCardFor(context, store, insights[k], highlight: k == 0),
                const SizedBox(height: 10),
              ],
              const SectionHeader(
                'Ringkasan usaha',
                info:
                    'Angka dihitung otomatis dari data yang sudah kamu konfirmasi. AI tidak mengubah datamu.',
              ),
              Column(
                children: [
                  KpiTile(
                    label: 'Penjualan bulan ini',
                    value: rp(month.revenue),
                    sub: '${month.saleCount} catatan penjualan',
                    icon: Icons.payments_outlined,
                  ),
                  KpiTile(
                    label: 'Perkiraan untung bersih',
                    value: month.netProfit == null
                        ? (month.hasSales ? 'Belum lengkap' : '—')
                        : rp(month.netProfit!),
                    sub: month.hasSales && !month.cogsComplete
                        ? 'Ada produk tanpa harga modal'
                        : 'Biaya usaha ${rp(month.opex)}',
                    incomplete: month.hasSales && !month.cogsComplete,
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppColors.info,
                  ),
                  KpiTile(
                    label: 'Nilai stok',
                    value: store.stockValue == null
                        ? '≥ ${rp(store.stockValueKnown)}'
                        : rp(store.stockValue!),
                    sub: store.stockValue == null
                        ? 'Sebagian modal belum diketahui'
                        : '${store.activeProducts.length} produk',
                    incomplete: store.stockValue == null,
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.ai,
                  ),
                  KpiTile(
                    label: 'Stok menipis',
                    value: '$low produk',
                    sub: low == 0 ? 'Semua aman' : 'Perlu restock',
                    icon: Icons.warning_amber_rounded,
                    color: low == 0 ? AppColors.primary : AppColors.danger,
                  ),
                ],
              ),
            ],
            SectionHeader(
              'Progres & misi',
              action: 'Lihat misi',
              onAction: () => HomeShell.goTo(context, 4),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    XpBar(store: store),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _miniStat(
                          Icons.local_fire_department,
                          '${store.recordStreak} hari',
                          'Streak catat',
                          AppColors.danger,
                        ),
                        _miniStat(
                          Icons.verified_outlined,
                          '${store.verifiedRecordDays} hari',
                          'Data terverifikasi',
                          AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final m in missions.take(2)) ...[
              MissionTile(
                mission: m,
                onStart: () => startMission(context, m),
                startLabel: missionActionLabel(m),
                forYou: store.isGoalMission(m.id),
                onClaim: () async {
                  final xp = await store.claimMission(m.id);
                  if (context.mounted) {
                    showXpGain(context, xp, 'Misi selesai: ${m.title}');
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, AppStore store) {
    final h = store.now.hour;
    final greet = h < 11
        ? 'Selamat pagi'
        : h < 15
        ? 'Selamat siang'
        : h < 18
        ? 'Selamat sore'
        : 'Selamat malam';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalText(
                '$greet, ${store.business?.ownerName.isNotEmpty == true ? store.business!.ownerName : 'Juragan'}',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                store.business?.name ?? 'Retailee',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Profil & pengaturan',
          onPressed: () => _settings(context, store),
          icon: const Icon(Icons.person_outline),
        ),
      ],
    );
  }

  Widget _setupCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              RetaileeMark(size: 48),
              SizedBox(width: 12),
              LocalText(
                'Langkah 2 dari 2',
                style: TextStyle(
                  color: AppColors.info,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const LocalText(
            'Catat stok awal warungmu',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const LocalText(
            'Foto catatan stok di buku. AI membaca, kamu mengecek, lalu konfirmasi.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => startScan(context, DocKind.openingStock),
                  icon: const Icon(Icons.photo_camera),
                  label: const LocalText('Foto catatan'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                onPressed: () => HomeShell.goTo(context, 1),
                child: const LocalText('Manual'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroCard(BuildContext context, AppStore store, PeriodSummary t) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalText(
            'Penjualan hari ini · ${fmtDateLong(store.now)}',
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rp(t.revenue),
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          if (!t.hasSales)
            const LocalText(
              'Belum ada penjualan hari ini',
              style: TextStyle(color: AppColors.muted, fontSize: 16),
            ),
          const SizedBox(height: 14),
          Material(
            color: Colors.transparent,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const LocalText(
                'Lihat untung dan modal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _heroStat(
                      'Untung sebelum biaya',
                      t.grossProfit == null
                          ? (t.hasSales ? 'Belum lengkap' : '—')
                          : rp(t.grossProfit!),
                    ),
                    _heroStat(
                      'Margin',
                      t.grossMarginPct == null
                          ? '—'
                          : '${t.grossMarginPct!.toStringAsFixed(1)}%',
                    ),
                    _heroStat(
                      'Modal terjual',
                      t.hasSales
                          ? (t.cogsComplete
                                ? rp(t.knownCogs)
                                : '≥ ${rp(t.knownCogs)}')
                          : '—',
                    ),
                  ],
                ),
              ],
            ),
          ),
          ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                ),
                onPressed: () => startScan(context, DocKind.dailySales),
                icon: const Icon(Icons.photo_camera),
                label: const LocalText('Foto penjualan hari ini'),
              ),
            ),
          ],
          if (t.hasSales && !t.cogsComplete) ...[
            const SizedBox(height: 12),
            Pill.warn('Harga modal belum lengkap. Laba belum pasti.'),
          ],
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        LocalText(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        LocalText(
          value,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _draftBanner(BuildContext context, int n) => Material(
    color: AppColors.warnSoft,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => HomeShell.goTo(context, 2),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.pending_actions, color: AppColors.warn),
            const SizedBox(width: 10),
            Expanded(
              child: LocalText(
                '$n draf menunggu dicek & dikonfirmasi',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B4A00),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.warn),
          ],
        ),
      ),
    ),
  );

  Widget _miniStat(IconData icon, String value, String label, Color color) =>
      Expanded(
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalText(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  LocalText(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  void _showAllInsights(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final store = StoreScope.of(ctx);
        final list = store.insights;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .85,
          builder: (ctx, ctrl) => ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(16),
            children: [
              const Center(
                child: LocalText(
                  'Semua wawasan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 12),
              for (var k = 0; k < list.length; k++) ...[
                insightCardFor(
                  context,
                  store,
                  list[k],
                  highlight: k == 0,
                  beforeNavigate: () => Navigator.pop(ctx),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _goalStrip(BuildContext context, AppStore store) {
    final prof = store.profile!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.aiSoft,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const OwnerProfileScreen())),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.flag_circle, color: AppColors.ai, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: LocalText(
                    'Tujuanmu: ${ownerGoalLabels[prof.goal]}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF3F2C99),
                      fontSize: 16,
                    ),
                  ),
                ),
                LocalText(
                  'Tahap ${store.personalizationStage}/3',
                  style: const TextStyle(
                    color: AppColors.ai,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.ai, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickScenario(BuildContext context, AppStore store) async {
    final goal = await showDialog<OwnerGoal>(
      context: context,
      builder: (d) => SimpleDialog(
        title: const LocalText('Pilih skenario demo'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: LocalText(
              'Data sekarang di perangkat ini akan diganti dengan data contoh berlabel demo.',
              style: TextStyle(color: AppColors.muted, fontSize: 16),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(d, OwnerGoal.stockAvailability),
            child: const ListTile(
              leading: Icon(
                Icons.inventory_2_rounded,
                color: AppColors.primary,
              ),
              title: Text(
                'A · Warung Bu Sari',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: LocalText(
                'Tujuan: stok selalu tersedia · gaya singkat',
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(d, OwnerGoal.profitability),
            child: const ListTile(
              leading: Icon(Icons.trending_up_rounded, color: AppColors.info),
              title: Text(
                'B · Toko Pak Budi',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: LocalText(
                'Tujuan: untung lebih besar · gaya detail · ada riwayat masukan',
              ),
            ),
          ),
        ],
      ),
    );
    if (goal == null) return;
    await store.loadDemoScenario(goal);
    if (context.mounted) {
      showMessage(context, 'Skenario demo dimuat: ${store.business?.name}');
    }
  }

  void _settings(BuildContext context, AppStore store) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: AnimatedBuilder(
          animation: store,
          builder: (ctx, _) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(store.userName ?? ''),
                  subtitle: LocalText(
                    store.googleEnabled
                        ? store.userEmail ?? 'Akun Google'
                        : 'Akun demo · ${store.business?.city ?? ''}',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.auto_awesome, color: AppColors.ai),
                  title: const LocalText('Yang dipelajari AI'),
                  subtitle: const LocalText(
                    'Tujuan, gaya penjelasan, ejaan & masukan',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const OwnerProfileScreen(),
                      ),
                    );
                  },
                ),
                if (store.googleEnabled) ...[
                  ListTile(
                    leading: const Icon(Icons.cloud_outlined),
                    title: LocalText(
                      store.syncing
                          ? 'Mengirim cadangan...'
                          : store.cloudPending
                          ? 'Cadangan belum terkirim'
                          : 'Cadangan Google',
                    ),
                    subtitle: LocalText(
                      store.syncError ??
                          (store.cloudPending
                              ? 'Data lokal tersimpan. Ketuk untuk mencoba lagi.'
                              : 'Ketuk untuk memeriksa cadangan.'),
                    ),
                    onTap: store.syncing
                        ? null
                        : () async {
                            await store.syncCloud();
                            if (ctx.mounted) {
                              showMessage(
                                ctx,
                                store.syncError ??
                                    'Cadangan tidak memiliki perubahan tertunda.',
                                error: store.syncError != null,
                              );
                            }
                          },
                  ),
                  ListTile(
                    leading: const Icon(Icons.cloud_download_outlined),
                    title: const LocalText('Pulihkan cadangan Google'),
                    subtitle: const LocalText(
                      'Ganti data lokal dengan cadangan cloud terbaru',
                    ),
                    onTap: store.syncing
                        ? null
                        : () async {
                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (d) => AlertDialog(
                                title: const LocalText('Pulihkan dari cloud?'),
                                content: const LocalText(
                                  'Perubahan lokal yang belum dicadangkan akan diganti. Foto draf di perangkat perlu diambil ulang.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(d, false),
                                    child: const LocalText('Batal'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(d, true),
                                    child: const LocalText('Pulihkan'),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true) return;
                            try {
                              await store.restoreCloud();
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              if (ctx.mounted) {
                                showMessage(
                                  ctx,
                                  'Belum dapat dipulihkan. $e',
                                  error: true,
                                );
                              }
                            }
                          },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const LocalText('Keluar dari Google'),
                    subtitle: const LocalText(
                      'Data lokal tetap disimpan untuk akun ini',
                    ),
                    onTap: () async {
                      try {
                        await store.signOut();
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) {
                          showMessage(
                            ctx,
                            'Belum dapat keluar. $e',
                            error: true,
                          );
                        }
                      }
                    },
                  ),
                ],
                if (!store.googleEnabled)
                  ListTile(
                    leading: const Icon(Icons.theater_comedy_outlined),
                    title: const LocalText('Muat skenario demo'),
                    subtitle: const LocalText(
                      'Dua warung dengan tujuan berbeda',
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickScenario(context, store);
                    },
                  ),
                if (!store.googleEnabled)
                  ListTile(
                    leading: const Icon(Icons.science_outlined),
                    title: const LocalText('Simulasi gagal baca foto (sekali)'),
                    subtitle: const LocalText('Untuk mencoba alur pemulihan'),
                    onTap: () {
                      store.simulateNextFailure();
                      Navigator.pop(ctx);
                      showMessage(
                        context,
                        'Scan berikutnya akan disimulasikan gagal.',
                      );
                    },
                  ),
                if (!store.googleEnabled)
                  ListTile(
                    leading: const Icon(
                      Icons.restart_alt,
                      color: AppColors.danger,
                    ),
                    title: const LocalText(
                      'Reset data demo',
                      style: TextStyle(color: AppColors.danger),
                    ),
                    subtitle: const LocalText(
                      'Hapus semua data lokal & mulai dari awal',
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (d) => AlertDialog(
                          title: const LocalText('Reset semua data?'),
                          content: const LocalText(
                            'Semua produk, penjualan, biaya, dan XP di perangkat ini akan dihapus.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(d, false),
                              child: const LocalText('Batal'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.danger,
                                minimumSize: const Size(0, 44),
                              ),
                              onPressed: () => Navigator.pop(d, true),
                              child: const LocalText('Reset'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) await store.resetAll();
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Insight card wired to personalization: style, mission and feedback.
Widget insightCardFor(
  BuildContext context,
  AppStore store,
  Insight i, {
  bool highlight = false,
  VoidCallback? beforeNavigate,
}) {
  final (label, tab) = switch (i.kind) {
    InsightKind.onboarding => ('Catat stok awal', 2),
    InsightKind.lowStock => ('Periksa stok', 1),
    InsightKind.missingCost => ('Lengkapi harga modal', 1),
    InsightKind.marginRisk => ('Periksa harga produk', 1),
    InsightKind.recordHabit => ('Foto penjualan', 2),
    _ => ('Lihat laporan', 3),
  };
  return InsightCard(
    insight: i,
    actionLabel: label,
    onAction: () {
      beforeNavigate?.call();
      if (i.kind == InsightKind.onboarding ||
          i.kind == InsightKind.recordHabit) {
        startScan(
          context,
          i.kind == InsightKind.onboarding
              ? DocKind.openingStock
              : DocKind.dailySales,
        );
      } else {
        HomeShell.goTo(context, tab);
      }
    },
    highlight: highlight,
    concise: store.profile?.style == ExplainStyle.concise,
    rated: store.feedbackFor(i.id)?.useful,
    onRate: i.kind == InsightKind.onboarding
        ? null
        : (useful) async {
            await store.rateInsight(i, useful);
            if (context.mounted) {
              showMessage(
                context,
                useful
                    ? 'Terima kasih! Saran sejenis akan diprioritaskan.'
                    : 'Oke, saran ini tidak ditampilkan lagi.',
              );
            }
          },
    missionAccepted:
        i.missionId != null && store.isMissionAccepted(i.missionId!),
    onAcceptMission: i.missionId != null && i.missionId!.startsWith('restock_')
        ? () async {
            await store.acceptAiMission(i.missionId!);
            if (context.mounted) {
              showMessage(context, 'Misi ditambahkan. Cek tab Misi.');
            }
          }
        : null,
  );
}
