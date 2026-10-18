import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/brand.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'scan_screen.dart';
import 'stock_screen.dart';
import 'operations_screen.dart';

String missionActionLabel(Mission mission) => switch (mission.id) {
  'starter_stock' => 'Foto stok awal',
  'starter_first_sale' || 'daily_sales' => 'Foto penjualan',
  'daily_expense' => 'Foto biaya usaha',
  'daily_costs' => 'Lengkapi harga modal',
  'starter_services' => 'Tambah layanan',
  'starter_order' || 'daily_orders' => 'Catat pesanan',
  'daily_completion' || 'daily_payment' => 'Buka pesanan',
  'starter_recipe' || 'daily_production' => 'Buka produksi',
  _ => 'Buka produk',
};

void startMission(BuildContext context, Mission mission) {
  final store = StoreScope.read(context);
  if (mission.fromAi) {
    final accepted = store.acceptedMissions
        .where((m) => m.id == mission.id)
        .firstOrNull;
    if (accepted != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(productId: accepted.productId),
        ),
      );
      return;
    }
  }
  switch (mission.id) {
    case 'starter_services':
      offeringForm(context);
    case 'starter_order':
    case 'daily_orders':
      openOrderForm(context);
    case 'daily_completion':
    case 'daily_payment':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const OperationsScreen(initialIndex: 0),
        ),
      );
    case 'starter_recipe':
    case 'daily_production':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AppPage(
            appBar: AppBar(title: const LocalText('Produksi')),
            body: const ProductionScreen(),
          ),
        ),
      );
    case 'daily_costs':
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const OperationsScreen(initialIndex: 2),
        ),
      );
    case 'starter_stock':
      startScan(context, DocKind.openingStock);
    case 'starter_first_sale':
    case 'daily_sales':
      startScan(
        context,
        store.products.isEmpty ? DocKind.openingStock : DocKind.dailySales,
      );
    case 'daily_expense':
      startScan(context, DocKind.expenseReceipt);
    default:
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const OperationsScreen(initialIndex: 2),
        ),
      );
  }
}

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});
  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  int _filter = 0;
  final Set<String> _claiming = {};

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final missions = store.missions;
    final ready = missions.where((m) => !m.claimed && m.verified).toList();
    final starter = missions
        .where((m) => m.id.startsWith('starter_') && !m.claimed && !m.verified)
        .toList();
    final daily = missions
        .where((m) => m.id.startsWith('daily_') && !m.claimed && !m.verified)
        .toList();
    final ai = missions
        .where((m) => m.fromAi && !m.claimed && !m.verified)
        .toList();
    final done = missions.where((m) => m.claimed).toList();
    final history = store.xpEvents.reversed.take(10).toList();
    final base = Theme.of(context);

    Widget tile(Mission m) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _MissionCard(
        key: ValueKey(m.id),
        mission: m,
        forYou: store.isGoalMission(m.id),
        busy: _claiming.contains(m.id),
        startLabel: missionActionLabel(m),
        onStart: () => startMission(context, m),
        onSkip: m.id.startsWith('daily_')
            ? () async {
                await store.skipMission(m.id);
                if (context.mounted) {
                  showMessage(context, 'Misi dilewati untuk hari ini.');
                }
              }
            : null,
        onClaim: () async {
          if (_claiming.contains(m.id)) return;
          setState(() => _claiming.add(m.id));
          final previousLevel = store.level;
          try {
            final xp = await store.claimMission(m.id);
            if (context.mounted) {
              showXpGain(context, xp, 'Misi terverifikasi: ${m.title}');
              if (xp > 0 && store.level > previousLevel) {
                await _levelUp(context, store.level, xp);
              }
            }
          } finally {
            if (mounted) setState(() => _claiming.remove(m.id));
          }
        },
      ),
    );

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
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            fontSize: 15,
            height: 1.45,
          ),
          bodySmall: base.textTheme.bodySmall?.copyWith(
            fontSize: 13,
            height: 1.4,
            color: const Color(0xFF65687B),
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
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: Builder(
        builder: (context) => Material(
          color: const Color(0xFFF7F8FC),
          child: SafeArea(
            child: ListView(
              key: const PageStorageKey('missions-progress'),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: const LocalText(
                          'Misi',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                    const InfoButton(
                      title: 'Tentang misi',
                      message:
                          'Kebiasaan kecil untuk usaha yang lebih rapi. XP diberikan setelah misi terbukti dari catatan usahamu.',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFEEEAFE), Color(0xFFE0F2FF)],
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
                                  'Langkah usahamu',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF65687B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                LocalText(
                                  'Level ${store.level}',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                LocalText(
                                  levelTitle(store.level),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const RetaileeMark(size: 68),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${store.totalXp} XP',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: store.levelProgress,
                        minHeight: 9,
                        borderRadius: BorderRadius.circular(5),
                        color: AppColors.primary,
                        backgroundColor: const Color(0xFFDAD5F1),
                        semanticsLabel: appTr(context, 'Progres level'),
                        semanticsValue:
                            '${(store.levelProgress * 100).round()}%',
                      ),
                      const SizedBox(height: 8),
                      LocalText(
                        '${store.xpToNext} XP lagi ke level ${store.level + 1}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF65687B),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1, color: Color(0xFFDAD5F1)),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _stat(
                            Icons.local_fire_department_outlined,
                            '${store.recordStreak}',
                            'hari streak',
                          ),
                          _stat(
                            Icons.fact_check_outlined,
                            '${store.verifiedRecordDays}',
                            'hari tercatat',
                          ),
                          _stat(
                            Icons.flag_outlined,
                            '${done.length}',
                            'misi selesai',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (store.business?.priority.isNotEmpty == true ||
                    store.profile != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.my_location_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LocalText(
                          'Tujuan: ${store.business?.priority.isNotEmpty == true ? store.business!.priority : ownerGoalLabels[store.profile?.goal]}',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF65687B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < 3; i++)
                      ChoiceChip(
                        label: LocalText(
                          ['Aktif', 'Siap diklaim', 'Selesai'][i],
                        ),
                        selected: _filter == i,
                        showCheckmark: false,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _filter == i
                              ? Colors.white
                              : AppColors.primaryDark,
                        ),
                        side: const BorderSide(color: Color(0xFFE4DFF4)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 9,
                        ),
                        onSelected: (_) => setState(() => _filter = i),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_filter == 0 || _filter == 1) ...[
                  if (ready.isNotEmpty) ...[
                    _heading('Sudah terbukti · klaim hadiahmu'),
                    ...ready.map(tile),
                  ] else if (_filter == 1)
                    _empty('Belum ada misi yang siap diklaim.'),
                ],
                if (_filter == 0) ...[
                  if (ai.isNotEmpty) ...[
                    _heading('Misi dari wawasan AI'),
                    ...ai.map(tile),
                  ],
                  if (daily.isNotEmpty) ...[
                    _heading('Misi harian'),
                    ...daily.map(tile),
                  ],
                  if (starter.isNotEmpty) ...[
                    _heading('Misi pemula'),
                    ...starter.map(tile),
                  ],
                  if (ready.isEmpty &&
                      ai.isEmpty &&
                      daily.isEmpty &&
                      starter.isEmpty)
                    _empty('Tidak ada misi aktif saat ini.'),
                ],
                if (_filter == 2) ...[
                  if (done.isEmpty)
                    _empty('Belum ada misi yang sudah diklaim.')
                  else
                    ...done.map(tile),
                ],
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      key: const PageStorageKey('missions-xp-history'),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: const Icon(
                        Icons.history_rounded,
                        color: AppColors.primary,
                      ),
                      title: const LocalText(
                        'Riwayat XP',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      children: [
                        for (final e in history)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.stars_outlined,
                                  size: 20,
                                  color: AppColors.warn,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      LocalText(
                                        e.label,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${fmtDate(e.at)} · ${fmtTime(e.at)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF65687B),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '+${e.xp} XP',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.warn,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      header: true,
      child: LocalText(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
    ),
  );

  Widget _empty(String text) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: LocalText(
        text,
        style: const TextStyle(fontSize: 15, color: Color(0xFF65687B)),
      ),
    ),
  );

  Widget _stat(IconData icon, String value, String label) => Expanded(
    child: Column(
      children: [
        Icon(icon, size: 21, color: AppColors.primary),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 3),
        LocalText(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: Color(0xFF65687B),
          ),
        ),
      ],
    ),
  );

  Future<void> _levelUp(BuildContext context, int level, int xp) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: const Color(0xFF211B32),
        builder: (context) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 64,
                  color: AppColors.accent,
                ),
                const SizedBox(height: 16),
                const LocalText(
                  'Naik level!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Level $level · +$xp XP',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 12),
                const LocalText(
                  'Progres ini berasal dari catatan yang sudah terverifikasi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: const Color(0xFF4A3000),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const LocalText('Lanjutkan'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _MissionCard extends StatelessWidget {
  final Mission mission;
  final String startLabel;
  final bool forYou, busy;
  final VoidCallback onStart, onClaim;
  final VoidCallback? onSkip;
  const _MissionCard({
    super.key,
    required this.mission,
    required this.startLabel,
    required this.forYou,
    required this.busy,
    required this.onStart,
    required this.onClaim,
    this.onSkip,
  });
  @override
  Widget build(BuildContext context) {
    final m = mission;
    final ready = m.verified && !m.claimed;
    return Card(
      color: ready ? const Color(0xFFFFF7DA) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 8,
              children: [
                Icon(
                  ready
                      ? Icons.verified_outlined
                      : m.claimed
                      ? Icons.check_circle_outline
                      : Icons.flag_outlined,
                  size: 24,
                  color: ready ? AppColors.warn : AppColors.primary,
                ),
                Text(
                  '${m.xp} XP',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ready ? AppColors.warn : AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (m.fromAi) ...[
              const LocalText(
                'Misi AI',
                style: TextStyle(fontSize: 13, color: AppColors.primary),
              ),
              const SizedBox(height: 6),
            ],
            LocalText(
              m.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            LocalText(
              m.description,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Color(0xFF65687B),
              ),
            ),
            if (forYou && !m.claimed) ...[
              const SizedBox(height: 8),
              const LocalText(
                'Sesuai tujuanmu',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (m.claimed)
              const LocalText(
                'XP sudah diklaim',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.positive,
                ),
              )
            else if (ready)
              FilledButton.icon(
                onPressed: busy ? null : onClaim,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: const Color(0xFF4A3000),
                ),
                icon: const Icon(Icons.verified_outlined, size: 20),
                label: LocalText(
                  busy ? 'Memproses...' : 'Terverifikasi · Klaim XP',
                ),
              )
            else ...[
              LocalText(
                '${(m.progress * 100).round()}% dari target terverifikasi',
                style: const TextStyle(fontSize: 12, color: Color(0xFF65687B)),
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: m.progress,
                minHeight: 6,
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: AppColors.line,
                semanticsValue: '${(m.progress * 100).round()}%',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: LocalText(startLabel),
              ),
              if (onSkip != null)
                TextButton(
                  onPressed: onSkip,
                  child: const LocalText('Lewati hari ini'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
