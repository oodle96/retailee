import 'package:flutter/material.dart';
import '../models.dart';
import '../services/store.dart';
import '../widgets/home_capture_card.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import 'business_home_screen.dart';
import 'home_shell.dart';
import 'journal_screen.dart';
import 'business_setup_screen.dart';

const _canvas = Color(0xFFF7F8FC);
const _muted = Color(0xFF65687B);
const _border = Color(0xFFE9EAF2);

class CoreHomeScreen extends StatelessWidget {
  const CoreHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final recent =
        store.documents.where((d) => d.status != DocStatus.cancelled).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: _border),
          ),
        ),
        textTheme: base.textTheme.copyWith(
          bodyMedium: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: AppColors.ink,
          ),
          bodySmall: const TextStyle(fontSize: 13, height: 1.4, color: _muted),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 56),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      child: Builder(
        builder: (context) => ColoredBox(
          color: _canvas,
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: store.syncCloud,
              child: ListView(
                key: const PageStorageKey('home-overview'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  Row(
                    children: [
                      const RetaileeMark(size: 40),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const LocalText(
                              'Beranda',
                              style: TextStyle(fontSize: 12, color: _muted),
                            ),
                            Text(
                              store.business?.name ?? 'Retailee',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: appTr(context, 'Pengaturan usaha'),
                        style: IconButton.styleFrom(
                          side: const BorderSide(color: _border),
                          backgroundColor: Colors.white,
                        ),
                        onPressed: () => businessSettings(context),
                        icon: const Icon(Icons.settings_outlined, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  HomeCaptureCard(onCapture: () => HomeShell.goTo(context, 2)),
                  if (store.openDrafts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Material(
                      color: AppColors.warnSoft,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: const Icon(
                          Icons.fact_check_outlined,
                          color: AppColors.warn,
                        ),
                        title: Text(
                          '${store.openDrafts.length} ${appTr(context, 'draf belum selesai')}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: const LocalText(
                          'Periksa sebelum masuk jurnal',
                          style: TextStyle(fontSize: 13, color: AppColors.warn),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => HomeShell.goTo(context, 1),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  const _HomeHeading('Saran untuk usahamu'),
                  const SizedBox(height: 12),
                  const _HomeAdvice(),
                  const SizedBox(height: 16),
                  const _HomeSnapshot(),
                  if (store.totalXp > 0 || store.claimableCount > 0) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: const Color(0xFFFFF6D8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => HomeShell.goTo(context, 4),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.emoji_events_outlined,
                                    color: Color(0xFF7B551B),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: LocalText(
                                      'Langkah usahamu',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Level ${store.level} · ${store.totalXp} XP',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF7B551B),
                                ),
                              ),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                value: store.levelProgress,
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(4),
                                backgroundColor: const Color(0xFFEADDAC),
                                color: const Color(0xFF96701C),
                                semanticsLabel: appTr(context, 'Progres level'),
                                semanticsValue:
                                    '${(store.levelProgress * 100).round()}%',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (store.business?.understanding == null) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.tune,
                          size: 22,
                          color: AppColors.primary,
                        ),
                        title: const LocalText(
                          'Kenali cara kerja usahamu',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: const LocalText(
                          'Konfirmasi profil agar foto dan saran sesuai usahamu.',
                          style: TextStyle(fontSize: 13, color: _muted),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const BusinessSetupScreen(editing: true),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Builder(
                    builder: (context) {
                      const heading = _HomeHeading('Jurnal terbaru');
                      final action = TextButton(
                        onPressed: () => HomeShell.goTo(context, 1),
                        child: const LocalText('Buka jurnal'),
                      );
                      return MediaQuery.textScalerOf(context).scale(14) > 20
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [heading, action],
                            )
                          : Row(
                              children: [
                                const Expanded(child: heading),
                                action,
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 4),
                  if (recent.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: LocalText(
                          'Jurnal dimulai dari foto catatan pertamamu.',
                          style: TextStyle(fontSize: 14, color: _muted),
                        ),
                      ),
                    ),
                  for (final document in recent.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: JournalDocumentTile(document: document),
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

class _HomeSnapshot extends StatelessWidget {
  const _HomeSnapshot();
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final today = store.summaryForDay(store.now);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const PageStorageKey('home-snapshot'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        shape: const Border(),
        collapsedShape: const Border(),
        title: const LocalText(
          'Ringkasan hari ini',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${appTr(context, 'Pendapatan')} · ${rp(today.revenue)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fmtDate(store.now),
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final cost = _HomeMetric(
                label: 'Biaya usaha',
                value: rp(today.opex),
              );
              final profit = _HomeMetric(
                label: 'Perkiraan untung bersih',
                value: today.netProfit == null
                    ? appTr(context, 'Belum lengkap')
                    : rp(today.netProfit!),
              );
              return MediaQuery.textScalerOf(context).scale(14) > 20
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [cost, const SizedBox(height: 12), profit],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cost),
                        const SizedBox(width: 12),
                        Expanded(child: profit),
                      ],
                    );
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => HomeShell.goTo(context, 3),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const LocalText('Lihat laporan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeading extends StatelessWidget {
  final String title;
  const _HomeHeading(this.title);
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: LocalText(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
    ),
  );
}

class _HomeMetric extends StatelessWidget {
  final String label, value;
  const _HomeMetric({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LocalText(
        label,
        style: const TextStyle(fontSize: 13, color: _muted, height: 1.4),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

class _HomeAdvice extends StatelessWidget {
  const _HomeAdvice();
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final advice = store.advice;
    final visible =
        advice?.recommendations
            .where(
              (r) => !store.adviceFeedback.any(
                (f) => f['id'] == r['id'] && f['useful'] == false,
              ),
            )
            .toList() ??
        [];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFECFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4DEF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gemini',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LocalText(
            visible.isNotEmpty
                ? visible.first['title'] as String
                : advice != null
                ? 'Semua arahan disembunyikan berdasarkan masukanmu. Perbarui untuk arahan baru.'
                : store.advisor == null
                ? 'Demo lokal'
                : 'Belum ada arahan Gemini. Minta arahan awal atau mulai mencatat terlebih dahulu.',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          LocalText(
            visible.isNotEmpty
                ? visible.first['explanation'] as String
                : store.advisor == null
                ? 'Kamu sedang memakai demo lokal. Arahan Gemini tersedia pada aplikasi yang terhubung dengan Google. Catatan usaha tetap bisa dipakai di demo ini.'
                : 'Gemini memakai jenis usaha, tujuan, ringkasan catatan terkonfirmasi dan masukanmu. Nama serta foto pelanggan tidak dikirim untuk saran ini.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, height: 1.5, color: _muted),
          ),
          if (advice != null && store.adviceStale) ...[
            const SizedBox(height: 10),
            const LocalText(
              'Catatan / pilihanmu berubah. Perbarui arahan agar memakai konteks terbaru.',
              style: TextStyle(fontSize: 13, color: AppColors.warn),
            ),
          ],
          if (store.adviceError != null) ...[
            const SizedBox(height: 10),
            LocalText(
              store.adviceError!,
              style: const TextStyle(fontSize: 14, color: AppColors.danger),
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _showAdvice(context),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const LocalText('Lihat arahan'),
          ),
        ],
      ),
    );
  }

  void _showAdvice(BuildContext context) {
    final store = StoreScope.read(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: _canvas,
      builder: (context) => StoreScope(
        store: store,
        child: FractionallySizedBox(
          heightFactor: .88,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: _HomeHeading('Saran untuk usahamu'),
                      ),
                      IconButton(
                        tooltip: appTr(context, 'Tutup'),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: BusinessAdvicePanel(),
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
