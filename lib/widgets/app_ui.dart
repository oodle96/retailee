import 'package:flutter/material.dart';

import '../theme.dart';
import 'brand.dart';
import 'common.dart';

const appCanvas = Color(0xFFF7F8FC);
const appSecondary = Color(0xFF65687B);

class AppDialog extends StatelessWidget {
  final Widget? title, content;
  final List<Widget>? actions;
  final bool scrollable;
  const AppDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.scrollable = false,
  });
  @override
  Widget build(BuildContext context) => AppUi(
    child: AlertDialog(
      title: title,
      content: content,
      actions: actions,
      scrollable: scrollable,
    ),
  );
}

/// The compact visual treatment used by the remaining tools and document flows.
class AppUi extends StatelessWidget {
  final Widget child;
  const AppUi({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: appCanvas,
        textTheme: base.textTheme.merge(
          const TextTheme(
            bodyLarge: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              height: 1.4,
            ),
            bodyMedium: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 15,
              height: 1.4,
            ),
            bodySmall: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 13,
              height: 1.4,
            ),
            titleMedium: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            labelLarge: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: appCanvas,
          foregroundColor: AppColors.ink,
          titleTextStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.line),
          ),
        ),
        chipTheme: base.chipTheme.copyWith(
          labelStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            color: AppColors.primaryDark,
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          titleTextStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: appCanvas,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8F8FD),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 13,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB8B7C9)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorMaxLines: 3,
          helperMaxLines: 4,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            backgroundColor: AppColors.primaryDark,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            textStyle: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: child,
    );
  }
}

class AppFrame extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? leading, bottomBar;
  final List<Widget>? actions;
  const AppFrame({
    super.key,
    required this.title,
    required this.body,
    this.leading,
    this.actions,
    this.bottomBar,
  });
  @override
  Widget build(BuildContext context) => AppUi(
    child: Scaffold(
      appBar: AppBar(
        title: LocalText(title),
        leading: leading,
        actions: actions,
      ),
      body: body,
      bottomNavigationBar: bottomBar,
    ),
  );
}

class AppHero extends StatelessWidget {
  final String title, message;
  final IconData? icon;
  const AppHero({
    super.key,
    required this.title,
    required this.message,
    this.icon,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.primarySoft, AppColors.infoSoft],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: icon == null
              ? const RetaileeMark(size: 40)
              : Icon(icon, size: 28, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalText(
                title,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 5),
              LocalText(
                message,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class AppSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final bool expandable, open;
  const AppSection({
    super.key,
    this.title,
    required this.children,
    this.expandable = false,
    this.open = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.line),
      ),
      child: expandable
          ? ExpansionTile(
              key: PageStorageKey('app-section-$title'),
              initiallyExpanded: open,
              maintainState: true,
              shape: const Border(),
              collapsedShape: const Border(),
              title: LocalText(
                title!,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KeyedSubtree(
                  key: const PageStorageKey('section-fields'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null) ...[
                    LocalText(
                      title!,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  ...children,
                ],
              ),
            ),
    ),
  );
}

class AppTextField extends StatelessWidget {
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
  const AppTextField({
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
  Widget build(BuildContext context) => _AppLabel(
    label: decoration.labelText,
    child: TextFormField(
      key: PageStorageKey('text-${decoration.labelText}'),
      controller: controller,
      initialValue: initialValue,
      enabled: enabled,
      autofocus: autofocus,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontFamily: 'Roboto', fontSize: 16).merge(style),
      onChanged: onChanged,
      validator: validator == null
          ? null
          : (v) {
              final error = validator!(v);
              return error == null ? null : appTr(context, error);
            },
      decoration: decoration.copyWith(
        labelText: '',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: decoration.hintText == null
            ? null
            : appTr(context, decoration.hintText!),
        helperText: decoration.helperText == null
            ? null
            : appTr(context, decoration.helperText!),
        errorText: decoration.errorText == null
            ? null
            : appTr(context, decoration.errorText!),
      ),
    ),
  );
}

class AppDropdown<T> extends StatelessWidget {
  final T? initialValue;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final InputDecoration decoration;
  final bool isExpanded;
  const AppDropdown({
    super.key,
    this.initialValue,
    this.items,
    this.onChanged,
    this.validator,
    this.decoration = const InputDecoration(),
    this.isExpanded = true,
  });
  @override
  Widget build(BuildContext context) => _AppLabel(
    label: decoration.labelText,
    child: DropdownButtonFormField<T>(
      initialValue: initialValue,
      items: items,
      onChanged: onChanged,
      isExpanded: isExpanded,
      style: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 16,
        color: AppColors.ink,
      ),
      validator: validator == null
          ? null
          : (v) {
              final error = validator!(v);
              return error == null ? null : appTr(context, error);
            },
      decoration: decoration.copyWith(
        labelText: '',
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
    ),
  );
}

class _AppLabel extends StatelessWidget {
  final String? label;
  final Widget child;
  const _AppLabel({this.label, required this.child});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (label != null && label!.isNotEmpty) ...[
        LocalText(
          label!,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
      ],
      Semantics(
        label: label == null ? null : appTr(context, label!),
        child: child,
      ),
    ],
  );
}

class AppEntryTile extends StatelessWidget {
  final Widget title;
  final Widget? subtitle, leading;
  final VoidCallback? onTap;
  const AppEntryTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              if (leading != null) ...[
                IconTheme(
                  data: const IconThemeData(size: 24, color: AppColors.primary),
                  child: leading!,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle.merge(
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      child: title,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      DefaultTextStyle.merge(
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 13,
                          color: appSecondary,
                        ),
                        child: subtitle!,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: appSecondary,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AppFieldPair extends StatelessWidget {
  final Widget first, second;
  const AppFieldPair({super.key, required this.first, required this.second});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, const SizedBox(height: 12), second],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: 12),
          Expanded(child: second),
        ],
      );
    },
  );
}

class AppKeyValue extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? color;
  const AppKeyValue({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final labelWidget = LocalText(
          label,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            color: appSecondary,
          ),
        );
        final valueWidget = LocalText(
          value,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: bold ? 18 : 15,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        );
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelWidget, const SizedBox(height: 4), valueWidget],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: labelWidget),
            const SizedBox(width: 12),
            Flexible(child: valueWidget),
          ],
        );
      },
    ),
  );
}
