import 'package:flutter/material.dart';

import '../models.dart';
import '../services/store.dart';
import '../theme.dart';
import 'retail_art.dart';
import 'info_button.dart';
import '../l10n/app_language.dart';
export 'info_button.dart';
export '../l10n/app_language.dart';

class PageSurface extends StatelessWidget {
  final Widget child;
  const PageSurface({super.key, required this.child});
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.canvas,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Material(color: AppColors.bg, child: child),
      ),
    ),
  );
}

class ActionTile extends StatelessWidget {
  final Widget title;
  final Widget? subtitle, leading;
  final VoidCallback? onTap;
  const ActionTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leading: leading == null
          ? null
          : Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFD9D2FB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: leading,
            ),
      title: DefaultTextStyle.merge(
        style: const TextStyle(fontWeight: FontWeight.w800),
        child: title,
      ),
      subtitle: subtitle,
      trailing: const Icon(Icons.arrow_forward_rounded, size: 22),
      onTap: onTap,
    ),
  );
}

class AppPage extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body, floatingActionButton;
  const AppPage({super.key, this.appBar, this.body, this.floatingActionButton});
  @override
  Widget build(BuildContext context) {
    final nested = Scaffold.maybeOf(context) != null && appBar == null;
    return Scaffold(
      backgroundColor: nested ? AppColors.bg : AppColors.canvas,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: body == null
          ? null
          : nested
          ? body
          : PageSurface(child: body!),
    );
  }
}

IconData _fieldIcon(String label) {
  final text = label.toLowerCase();
  if (text.contains('nama') || text.contains('pelanggan')) {
    return Icons.badge_outlined;
  }
  if (text.contains('harga') ||
      text.contains('modal') ||
      text.contains('biaya') ||
      text.contains('nominal')) {
    return Icons.payments_outlined;
  }
  if (text.contains('jumlah') ||
      text.contains('stok') ||
      text.contains('minimum')) {
    return Icons.numbers_rounded;
  }
  if (text.contains('satuan')) return Icons.straighten_rounded;
  if (text.contains('produk') || text.contains('bahan')) {
    return Icons.inventory_2_outlined;
  }
  if (text.contains('layanan') || text.contains('pekerjaan')) {
    return Icons.design_services_outlined;
  }
  return Icons.edit_note_rounded;
}

class _FieldLabel extends StatelessWidget {
  final String? label;
  final Widget child;
  const _FieldLabel({required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    if (label == null || label!.isEmpty) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_fieldIcon(label!), size: 22, color: AppColors.primaryDark),
            const SizedBox(width: 8),
            Expanded(
              child: LocalText(
                label!,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Semantics(label: appTr(context, label!), child: child),
      ],
    );
  }
}

class LabeledTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final InputDecoration decoration;
  final bool? enabled;
  final bool autofocus;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  const LabeledTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.decoration = const InputDecoration(),
    this.enabled,
    this.autofocus = false,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.onChanged,
    this.validator,
  });
  @override
  Widget build(BuildContext context) => _FieldLabel(
    label: decoration.labelText,
    child: TextFormField(
      controller: controller,
      initialValue: initialValue,
      enabled: enabled,
      autofocus: autofocus,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: style,
      onChanged: onChanged,
      validator: validator == null
          ? null
          : (value) {
              final error = validator!(value);
              return error == null ? null : appTr(context, error);
            },
      decoration: decoration.copyWith(
        hintText: decoration.hintText == null
            ? null
            : appTr(context, decoration.hintText!),
        errorText: decoration.errorText == null
            ? null
            : appTr(context, decoration.errorText!),
        helperText: decoration.helperText == null
            ? null
            : appTr(context, decoration.helperText!),
        labelText: decoration.labelText == null ? null : '',
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
    ),
  );
}

class LabeledDropdown<T> extends StatelessWidget {
  final T? initialValue;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final InputDecoration decoration;
  final bool isExpanded;
  const LabeledDropdown({
    super.key,
    this.initialValue,
    this.items,
    this.onChanged,
    this.validator,
    this.decoration = const InputDecoration(),
    this.isExpanded = true,
  });
  @override
  Widget build(BuildContext context) => _FieldLabel(
    label: decoration.labelText,
    child: DropdownButtonFormField<T>(
      initialValue: initialValue,
      items: items,
      onChanged: onChanged,
      validator: validator == null
          ? null
          : (value) {
              final error = validator!(value);
              return error == null ? null : appTr(context, error);
            },
      isExpanded: isExpanded,
      decoration: decoration.copyWith(
        hintText: decoration.hintText == null
            ? null
            : appTr(context, decoration.hintText!),
        errorText: decoration.errorText == null
            ? null
            : appTr(context, decoration.errorText!),
        labelText: decoration.labelText == null ? null : '',
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
    ),
  );
}

/// Gives every widget access to the single AppStore.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
    : super(notifier: store);
  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget? leading;
  final String? info;
  const SectionHeader(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.leading,
    this.info,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(
            child: LocalText(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
          if (info != null) InfoButton(title: title, message: info!),
          if (action != null && onAction == null)
            Flexible(
              child: LocalText(
                action!,
                style: const TextStyle(fontSize: 16, color: AppColors.muted),
              ),
            ),
          if (action != null && onAction != null)
            Flexible(
              child: TextButton(
                onPressed: onAction,
                child: LocalText(
                  action!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;
  final IconData? icon;
  const Pill(
    this.text, {
    super.key,
    required this.color,
    required this.bg,
    this.icon,
  });
  factory Pill.warn(String t, {IconData? icon}) => Pill(
    t,
    color: AppColors.warn,
    bg: AppColors.warnSoft,
    icon: icon ?? Icons.info_outline,
  );
  factory Pill.danger(String t, {IconData? icon}) =>
      Pill(t, color: AppColors.danger, bg: AppColors.dangerSoft, icon: icon);
  factory Pill.ok(String t, {IconData? icon}) =>
      Pill(t, color: AppColors.primary, bg: AppColors.primarySoft, icon: icon);
  factory Pill.ai(String t) => Pill(
    t,
    color: AppColors.ai,
    bg: AppColors.aiSoft,
    icon: Icons.auto_awesome,
  );
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: LocalText(
              text,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color color;
  final bool incomplete;
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.sub,
    this.color = AppColors.primary,
    this.incomplete = false,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  incomplete ? Icons.error_outline : icon,
                  size: 20,
                  color: incomplete ? AppColors.warn : AppColors.muted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocalText(
                      label,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (sub != null)
                      LocalText(
                        sub!,
                        style: TextStyle(
                          fontSize: 16,
                          color: incomplete ? AppColors.warn : AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class XpBar extends StatelessWidget {
  final AppStore store;
  final bool dark;
  const XpBar({super.key, required this.store, this.dark = false});
  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.ink;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFFFFC94D), AppColors.accent],
            ),
          ),
          child: LocalText(
            '${store.level}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Color(0xFF5A3A00),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  LocalText(
                    'Level ${store.level} · ${levelTitle(store.level)}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: fg),
                  ),
                  LocalText(
                    '${store.totalXp} XP',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: fg,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: store.levelProgress,
                  minHeight: 8,
                  backgroundColor: dark ? Colors.white24 : AppColors.line,
                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                ),
              ),
              const SizedBox(height: 4),
              LocalText(
                '${store.xpToNext} XP lagi ke level ${store.level + 1}',
                style: TextStyle(fontSize: 16, color: fg),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String levelTitle(int level) {
  const titles = [
    'Pemula',
    'Pencatat Rajin',
    'Juragan Muda',
    'Juragan',
    'Pilot Warung',
    'Master Warung',
  ];
  return titles[(level - 1).clamp(0, titles.length - 1)];
}

class InsightCard extends StatelessWidget {
  final Insight insight;
  final VoidCallback? onAction;
  final String? actionLabel;
  final VoidCallback? onAcceptMission;
  final bool missionAccepted;
  final bool concise; // owner's explanation style (PRD §10.1)
  final bool highlight; // top "Rekomendasi untukmu" card
  final bool? rated; // true useful, false not useful, null unrated
  final ValueChanged<bool>? onRate;
  const InsightCard({
    super.key,
    required this.insight,
    this.onAction,
    this.actionLabel,
    this.onAcceptMission,
    this.missionAccepted = false,
    this.concise = false,
    this.highlight = false,
    this.rated,
    this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final (color, bg, label) = switch (insight.priority) {
      InsightPriority.high => (
        AppColors.danger,
        AppColors.dangerSoft,
        'Penting',
      ),
      InsightPriority.medium => (
        AppColors.warn,
        AppColors.warnSoft,
        'Perlu dicek',
      ),
      InsightPriority.low => (AppColors.info, AppColors.infoSoft, 'Info'),
    };
    return Card(
      color: highlight ? AppColors.infoSoft : Colors.white,
      shape: highlight
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.sky),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (highlight) Pill.ai('Untukmu'),
                Pill(label, color: color, bg: bg),
                Pill(
                  insight.category,
                  color: AppColors.muted,
                  bg: AppColors.bg,
                ),
              ],
            ),
            const SizedBox(height: 10),
            LocalText(
              insight.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: !concise,
              title: const LocalText(
                'Mengapa saran ini?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              children: [
                for (final e in insight.evidence)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(
                            Icons.bar_chart_rounded,
                            size: 14,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: LocalText(
                            e,
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (insight.caveat != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LocalText(
                      'Catatan: ${insight.caveat}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LocalText(
                      insight.action,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (onAction != null) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: LocalText(actionLabel!),
              ),
            ],
            if (insight.whyForYou != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.person_pin_outlined,
                    size: 16,
                    color: AppColors.ai,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: LocalText(
                      insight.whyForYou!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.ai,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (onAcceptMission != null || onRate != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (onRate != null) ...[
                    _rateButton(
                      Icons.thumb_up_alt_outlined,
                      Icons.thumb_up_alt,
                      'Berguna',
                      true,
                    ),
                    const SizedBox(width: 4),
                    _rateButton(
                      Icons.thumb_down_alt_outlined,
                      Icons.thumb_down_alt,
                      'Tidak',
                      false,
                    ),
                  ],
                  if (onAcceptMission != null)
                    missionAccepted
                        ? Pill.ok('Misi aktif', icon: Icons.flag)
                        : TextButton.icon(
                            onPressed: onAcceptMission,
                            icon: const Icon(Icons.flag_outlined, size: 18),
                            label: const LocalText('Jadikan misi'),
                          ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rateButton(IconData icon, IconData active, String label, bool value) {
    final sel = rated == value;
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: sel
            ? (value ? AppColors.primary : AppColors.danger)
            : AppColors.muted,
        backgroundColor: sel
            ? (value ? AppColors.primarySoft : AppColors.dangerSoft)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(48, 48),
      ),
      onPressed: () => onRate!(value),
      icon: Icon(sel ? active : icon, size: 18),
      label: LocalText(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class MissionTile extends StatelessWidget {
  final Mission mission;
  final VoidCallback? onClaim;
  final VoidCallback? onSkip;
  final VoidCallback? onStart;
  final String startLabel;
  final bool forYou; // relevant to the owner's goal
  const MissionTile({
    super.key,
    required this.mission,
    this.onClaim,
    this.onSkip,
    this.onStart,
    this.startLabel = 'Kerjakan misi',
    this.forYou = false,
  });
  @override
  Widget build(BuildContext context) {
    final m = mission;
    final done = m.claimed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: LocalText(
                    m.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? AppColors.muted : AppColors.ink,
                    ),
                  ),
                ),
                LocalText(
                  '+${m.xp} XP',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.warn,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            LocalText(
              m.description,
              style: const TextStyle(fontSize: 16, color: AppColors.muted),
            ),
            if (forYou && !done)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: LocalText(
                  'Sesuai tujuanmu',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.ai,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (!done && !m.verified && onStart != null)
              OutlinedButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: LocalText(startLabel),
              ),
            if (!done && !m.verified)
              LocalText(
                '${(m.progress * 100).round()}% dari target terverifikasi',
                style: const TextStyle(fontSize: 16, color: AppColors.muted),
              ),
            if (!done && !m.verified)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: Semantics(
                      container: true,
                      child: LinearProgressIndicator(
                        value: m.progress,
                        minHeight: 6,
                        backgroundColor: AppColors.line,
                        valueColor: AlwaysStoppedAnimation(
                          m.fromAi ? AppColors.ai : AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                  if (onSkip != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        foregroundColor: AppColors.muted,
                      ),
                      onPressed: onSkip,
                      child: const LocalText('Lewati hari ini'),
                    ),
                ],
              ),
            if (!done && m.verified)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: AppColors.accent,
                    foregroundColor: const Color(0xFF4A3000),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: onClaim,
                  icon: const Icon(Icons.verified, size: 18),
                  label: const LocalText('Terverifikasi · Klaim XP'),
                ),
              ),
            if (done)
              const LocalText(
                'XP sudah diklaim',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  final RetailScene? illustration;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.illustration,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (illustration != null)
            RetailArt(scene: illustration!, width: 180)
          else
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
          const SizedBox(height: 14),
          LocalText(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          LocalText(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

void showXpGain(BuildContext context, int xp, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 3),
      content: Row(
        children: [
          if (xp > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: LocalText(
                '+$xp XP',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF4A3000),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: LocalText(message)),
        ],
      ),
    ),
  );
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: error ? AppColors.danger : AppColors.ink,
        content: LocalText(message),
      ),
    );
}

