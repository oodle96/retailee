import 'package:flutter/material.dart';
import '../theme.dart';
import 'brand.dart';
import 'common.dart';

class HomeCaptureCard extends StatefulWidget {
  final VoidCallback onCapture;
  const HomeCaptureCard({super.key, required this.onCapture});
  @override
  State<HomeCaptureCard> createState() => _HomeCaptureCardState();
}

class _HomeCaptureCardState extends State<HomeCaptureCard> {
  int _step = 0;
  int _wave = 0;
  bool _greeting = false;
  static const _steps = [
    (
      Icons.photo_camera_outlined,
      'Foto',
      'Foto catatan atau struk yang ingin kamu simpan.',
    ),
    (
      Icons.fact_check_outlined,
      'Periksa',
      'Periksa hasil bacaan AI. Kamu yang mengonfirmasi catatan.',
    ),
    (
      Icons.auto_awesome_outlined,
      'Arahan',
      'Saran Gemini memakai catatan terkonfirmasi dan profil usahamu.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final duration = reduced
        ? Duration.zero
        : const Duration(milliseconds: 220);
    final companion = Tooltip(
      message: appTr(context, 'Sapa Retailee'),
      child: Semantics(
        button: true,
        label: appTr(context, 'Sapa Retailee'),
        child: ExcludeSemantics(
          child: Material(
            color: const Color(0xFFC9E9FC),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() {
                _greeting = !_greeting;
                _wave++;
              }),
              child: SizedBox.square(
                dimension: 108,
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(_wave),
                    tween: Tween(begin: _wave == 0 ? 0 : -.16, end: 0),
                    duration: reduced
                        ? Duration.zero
                        : const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) =>
                        Transform.rotate(angle: value, child: child),
                    child: const RetaileeMark(size: 88),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    const title = LocalText(
      'Catatan kecil.\nLangkah besar.',
      style: TextStyle(
        fontSize: 27,
        height: 1.15,
        letterSpacing: -.6,
        fontWeight: FontWeight.w800,
        color: AppColors.primaryDark,
      ),
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE0F4FF), Color(0xFFEBE5FF)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD6E7F6)),
        boxShadow: const [
          BoxShadow(color: Color(0xFFD2DFF0), offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (MediaQuery.textScalerOf(context).scale(14) > 20)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [companion, const SizedBox(height: 16), title],
            )
          else
            Row(
              children: [
                const Expanded(child: title),
                const SizedBox(width: 8),
                companion,
              ],
            ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onCapture,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(48, 56),
              ),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const LocalText('Foto catatan'),
            ),
          ),
          const SizedBox(height: 18),
          const LocalText(
            'Kenali alurnya',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF535471),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _steps.length; i++)
                ChoiceChip(
                  label: LocalText(_steps[i].$2),
                  avatar: Icon(
                    _steps[i].$1,
                    size: 18,
                    color: _step == i ? Colors.white : AppColors.primaryDark,
                  ),
                  selected: _step == i,
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white.withValues(alpha: .65),
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _step == i ? Colors.white : AppColors.primaryDark,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 7,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (_) => setState(() {
                    _step = i;
                    _greeting = false;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: duration,
            child: Semantics(
              liveRegion: true,
              child: LocalText(
                _greeting
                    ? 'Aku bantu membaca. Kamu tetap yang memutuskan.'
                    : _steps[_step].$3,
                key: ValueKey((_step, _greeting)),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF535471),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
