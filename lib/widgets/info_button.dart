import 'package:flutter/material.dart';
import '../theme.dart';
import '../l10n/app_language.dart';

class InfoButton extends StatelessWidget {
  final String title;
  final String message;
  const InfoButton({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: title,
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    icon: const Icon(Icons.info_outline, size: 26),
    color: AppColors.primaryDark,
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: LocalText(title),
        content: SingleChildScrollView(
          child: LocalText(message, style: const TextStyle(fontSize: 18)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const LocalText('Mengerti', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    ),
  );
}

class InfoHeading extends StatelessWidget {
  final String title;
  final String message;
  final TextStyle? style;
  final IconData icon;
  const InfoHeading({
    super.key,
    required this.title,
    required this.message,
    this.style,
    this.icon = Icons.auto_stories_outlined,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, color: AppColors.primaryDark, size: 25),
          const SizedBox(width: 10),
          Expanded(
            child: LocalText(
              title,
              style:
                  style ??
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      LocalText(
        message,
        style: const TextStyle(fontSize: 16, height: 1.4, color: AppColors.ink),
      ),
    ],
  );
}
