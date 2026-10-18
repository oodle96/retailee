import 'package:flutter/material.dart';

import '../business_types.dart';
import '../theme.dart';
import 'app_ui.dart';
import 'common.dart';

class BusinessProfileConfirmation extends StatefulWidget {
  final String title, summary;
  final List<String> activities;
  final bool manual;
  const BusinessProfileConfirmation({
    super.key,
    required this.title,
    required this.summary,
    required this.activities,
    required this.manual,
  });
  @override
  State<BusinessProfileConfirmation> createState() =>
      _BusinessProfileConfirmationState();
}

class _BusinessProfileConfirmationState
    extends State<BusinessProfileConfirmation> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => AppUi(
    child: AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      scrollable: true,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
            child: Icon(
              Icons.fact_check_outlined,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LocalText(
              widget.title,
              style: const TextStyle(
                fontSize: 20,
                height: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.manual) ...[
              const LocalText(
                'Gemini tidak tersedia di demo lokal. Profil ini memakai pilihanmu.',
                style: TextStyle(fontSize: 13, color: appSecondary),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: appCanvas,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.summary,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 15,
                      height: 1.5,
                      color: AppColors.ink,
                    ),
                    maxLines: _expanded || widget.summary.length <= 160
                        ? null
                        : 4,
                    overflow: _expanded || widget.summary.length <= 160
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                  ),
                  if (widget.summary.length > 160)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        icon: Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                        ),
                        label: LocalText(
                          _expanded ? 'Ringkas' : 'Baca selengkapnya',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final activity in widget.activities)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: LocalText(
                      businessActivityLabels[activity]!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const LocalText(
              'Foto, jurnal, dan saran akan mengikuti profil ini.',
              style: TextStyle(fontSize: 13, height: 1.4, color: appSecondary),
            ),
          ],
        ),
      ),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const LocalText('Ya, sesuai'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const LocalText('Ubah deskripsi'),
            ),
          ],
        ),
      ],
    ),
  );
}
