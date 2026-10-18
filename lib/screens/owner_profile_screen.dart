import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/brand.dart';
import '../services/store.dart';
import 'business_setup_screen.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// Transparent view of owner_ai_profile + insight_feedback, with
/// correction and reset controls (PRD §10.1).
class OwnerProfileScreen extends StatelessWidget {
  const OwnerProfileScreen({super.key});

  static const _stageLabels = {
    1: 'Mengenal tujuanmu',
    2: 'Belajar dari data terverifikasi',
    3: 'Menyesuaikan dari masukanmu',
  };

  Widget _surface(Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE9EAF2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  );

  Widget _details(
    String key,
    String title,
    IconData icon,
    List<Widget> children, {
    int? count,
  }) => _surface(
    ExpansionTile(
      key: PageStorageKey(key),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: const Border(),
      collapsedShape: const Border(),
      leading: Icon(icon, color: AppColors.primary, size: 23),
      title: Row(
        children: [
          Expanded(
            child: LocalText(
              title,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
      children: children,
    ),
  );

  Widget _record({
    required String title,
    String? subtitle,
    required IconData icon,
    Widget? trailing,
    Color? color,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: color ?? AppColors.primary, size: 22),
    title: LocalText(
      title,
      style: const TextStyle(
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: subtitle == null
        ? null
        : LocalText(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF65687B),
            ),
          ),
    trailing: trailing,
  );

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final prof = store.profile;
    final appBar = AppBar(
      backgroundColor: const Color(0xFFF7F8FC),
      foregroundColor: AppColors.ink,
      title: const LocalText(
        'Yang dipelajari AI',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
    if (prof == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: appBar,
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RetaileeMark(size: 72),
              SizedBox(height: 20),
              LocalText('Profil belum ada'),
            ],
          ),
        ),
      );
    }
    final stage = store.personalizationStage;
    final rated = store.feedback.reversed.toList();
    final priority = store.business?.priority;
    final goal = priority != null && priority.isNotEmpty
        ? priority
        : ownerGoalLabels[prof.goal]!;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: appBar,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 22),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const RetaileeMark(size: 52),
                      const Spacer(),
                      const InfoButton(
                        title: 'Arahan yang mengenal usahamu',
                        message:
                            'Saran memakai catatan terkonfirmasi, pilihan dan masukanmu. Data tidak dibagikan ke usaha lain.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: const LocalText(
                      'Arahan yang mengenal usahamu',
                      style: TextStyle(
                        fontSize: 23,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LocalText(
                    'Tahap $stage dari 3 · ${_stageLabels[stage]}',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Semantics(
                    label: appTr(context, 'Tahap $stage dari 3'),
                    child: Row(
                      children: [
                        for (var i = 1; i <= 3; i++)
                          Expanded(
                            child: Container(
                              height: 7,
                              margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                              decoration: BoxDecoration(
                                color: i <= stage
                                    ? AppColors.primary
                                    : const Color(0xFFDAD5F1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _surface(
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BusinessSetupScreen(editing: true),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.track_changes_outlined,
                        color: AppColors.primary,
                        size: 26,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const LocalText(
                              'Tujuan usaha',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF65687B),
                              ),
                            ),
                            const SizedBox(height: 5),
                            LocalText(
                              goal,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            LocalText(
                              store.template.name,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF65687B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.edit_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (store.business?.type == null)
              _details(
                'owner-goals',
                'Ubah tujuan usaha',
                Icons.flag_outlined,
                [
                  for (final g in OwnerGoal.values)
                    Semantics(
                      checked: prof.goal == g,
                      inMutuallyExclusiveGroup: true,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () => store.setGoal(g),
                        leading: Icon(
                          prof.goal == g
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: prof.goal == g
                              ? AppColors.primary
                              : const Color(0xFF777589),
                        ),
                        title: LocalText(
                          ownerGoalLabels[g]!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: LocalText(
                          ownerGoalDescriptions[g]!,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: Color(0xFF65687B),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            _surface(
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LocalText(
                      'Gaya penjelasan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final style in ExplainStyle.values)
                          ChoiceChip(
                            key: ValueKey('owner-style-${style.name}'),
                            label: LocalText(
                              style == ExplainStyle.concise
                                  ? 'Singkat'
                                  : 'Detail',
                            ),
                            selected: prof.style == style,
                            showCheckmark: false,
                            selectedColor: AppColors.primary,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: prof.style == style
                                  ? Colors.white
                                  : AppColors.primaryDark,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            onSelected: (_) => store.setStyle(style),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LocalText(
                      prof.style == ExplainStyle.concise
                          ? 'Langsung ke inti saran.'
                          : 'Lebih banyak penjelasan.',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Color(0xFF65687B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _details(
              'owner-aliases',
              'Ejaan tulisan tangan yang dikenali',
              Icons.draw_outlined,
              [
                if (prof.aliases.isEmpty)
                  const LocalText(
                    'Belum ada. Saat kamu membetulkan nama produk di hasil scan, ejaannya akan diingat di sini.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Color(0xFF65687B),
                    ),
                  )
                else
                  for (final e in prof.aliases.entries)
                    _record(
                      title: '"${e.key}"',
                      subtitle:
                          '→ ${store.productById(e.value)?.name ?? '(produk dihapus)'}',
                      icon: Icons.draw_outlined,
                      trailing: IconButton(
                        key: ValueKey('forget-alias-${e.key}'),
                        tooltip: appTr(context, 'Lupakan'),
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => store.removeAlias(e.key),
                      ),
                    ),
              ],
              count: prof.aliases.length,
            ),
            _details(
              'owner-feedback',
              'Masukan untuk saran',
              Icons.thumb_up_alt_outlined,
              [
                for (final f in store.adviceFeedback.reversed.take(10))
                  _record(
                    title: 'Saran Gemini · ${_topicLabel(f['topic'])}',
                    subtitle: f['useful'] == true
                        ? 'Berguna'
                        : 'Kurangi saran sejenis',
                    icon: f['useful'] == true
                        ? Icons.thumb_up_alt
                        : Icons.thumb_down_alt,
                    color: f['useful'] == true
                        ? AppColors.primary
                        : AppColors.danger,
                  ),
                for (final f in rated.take(10))
                  _record(
                    title: _kindLabel(f.kind),
                    subtitle:
                        '${f.useful ? 'Berguna' : 'Tidak berguna — tidak ditampilkan lagi'} · ${fmtDate(f.at)}',
                    icon: f.useful ? Icons.thumb_up_alt : Icons.thumb_down_alt,
                    color: f.useful ? AppColors.primary : AppColors.danger,
                  ),
                if (rated.isEmpty && store.adviceFeedback.isEmpty)
                  const LocalText(
                    'Belum ada. Tandai saran di Beranda sebagai Berguna / Tidak berguna.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Color(0xFF65687B),
                    ),
                  )
                else ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => store.clearFeedback(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    label: const LocalText('Hapus semua'),
                  ),
                ],
              ],
              count: rated.length + store.adviceFeedback.length,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                minimumSize: const Size(0, 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const LocalText('Reset yang dipelajari?'),
                    content: const LocalText(
                      'Ejaan yang dikenali, masukan saran, dan misi yang dilewati akan dihapus. '
                      'Tujuan, gaya penjelasan, dan data usahamu tetap.',
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
                if (ok == true) {
                  await store.resetLearning();
                  if (context.mounted) {
                    showMessage(context, 'Yang dipelajari sudah direset.');
                  }
                }
              },

              icon: const Icon(Icons.restart_alt, size: 20),
              label: const LocalText('Reset yang dipelajari'),
            ),
            const SizedBox(height: 16),
            LocalText(
              'Terakhir diperbarui ${fmtDate(prof.updatedAt)} ${fmtTime(prof.updatedAt)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Color(0xFF65687B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _topicLabel(Object? topic) => switch (topic) {
    'orders' => 'Pesanan',
    'pricing' => 'Harga jual',
    'cashflow' => 'Arus kas',
    'stock' => 'Stok',
    'costs' => 'Biaya usaha',
    'habit' => 'Kebiasaan mencatat',
    'production' => 'Produksi',
    'waste' => 'Barang terbuang',
    'customers' => 'Pelanggan',
    _ => 'Saran usaha',
  };

  static String _kindLabel(InsightKind k) => switch (k) {
    InsightKind.onboarding => 'Saran memulai',
    InsightKind.lowStock => 'Stok menipis',
    InsightKind.missingCost => 'Harga modal kosong',
    InsightKind.marginRisk => 'Risiko margin',
    InsightKind.salesChange => 'Perubahan penjualan',
    InsightKind.topProduct => 'Produk terlaris',
    InsightKind.expense => 'Biaya',
    InsightKind.recordHabit => 'Kebiasaan mencatat',
  };
}
