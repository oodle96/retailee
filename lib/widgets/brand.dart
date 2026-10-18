import 'package:flutter/material.dart';

import '../theme.dart';
import '../l10n/app_language.dart';

/// Editable vector adaptation of the owner's approved storefront identity.
class RetaileeMark extends StatelessWidget {
  final double size;
  const RetaileeMark({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) => Semantics(
    label: appTr(context, 'Retailee, pendamping warungmu'),
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _StorefrontPainter()),
    ),
  );
}

class RetaileeWordmark extends StatelessWidget {
  final Color? color;
  const RetaileeWordmark({super.key, this.color});
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: 'Retail',
          style: TextStyle(color: color ?? AppColors.primaryDark),
        ),
        TextSpan(
          text: 'ee',
          style: TextStyle(color: color ?? AppColors.primary),
        ),
      ],
    ),
    style: const TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w900,
      letterSpacing: -1,
    ),
  );
}

class _StorefrontPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64, size.height / 64);
    final fill = Paint()..isAntiAlias = true;
    final outline = Paint()
      ..isAntiAlias = true
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round;
    void shape(Path path, Color color) {
      canvas.drawPath(path, fill..color = color);
      canvas.drawPath(path, outline);
    }

    final wall = RRect.fromRectAndRadius(
      const Rect.fromLTWH(12, 25, 40, 30),
      const Radius.circular(4),
    );
    canvas.drawRRect(wall, fill..color = const Color(0xFFFFFCF3));
    canvas.drawRRect(wall, outline);
    shape(
      Path()
        ..moveTo(12, 11)
        ..lineTo(52, 11)
        ..lineTo(58, 26)
        ..lineTo(6, 26)
        ..close(),
      AppColors.primary,
    );
    shape(
      Path()
        ..moveTo(22, 11)
        ..lineTo(32, 11)
        ..lineTo(32, 26)
        ..lineTo(19, 26)
        ..close(),
      const Color(0xFFFFFCF3),
    );
    shape(
      Path()
        ..moveTo(42, 11)
        ..lineTo(52, 11)
        ..lineTo(58, 26)
        ..lineTo(45, 26)
        ..close(),
      const Color(0xFFFFFCF3),
    );
    for (var i = 0; i < 4; i++) {
      final x = 6.0 + i * 13;
      shape(
        Path()
          ..moveTo(x, 26)
          ..lineTo(x + 13, 26)
          ..lineTo(x + 13, 29)
          ..quadraticBezierTo(x + 6.5, 38, x, 29)
          ..close(),
        i.isEven ? AppColors.primary : const Color(0xFFFFFCF3),
      );
    }
    // Two eyes and a small smile retain the supplied storefront character.
    canvas.drawCircle(
      const Offset(25, 42),
      1.8,
      fill..color = AppColors.primaryDark,
    );
    canvas.drawCircle(const Offset(39, 42), 1.8, fill);
    canvas.drawPath(
      Path()
        ..moveTo(28, 47)
        ..quadraticBezierTo(32, 51, 36, 47),
      outline..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ScanProgress extends StatelessWidget {
  final int step;
  const ScanProgress({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Ambil foto',
      'AI membaca',
      'Periksa',
      'Konfirmasi',
      'Selesai',
    ];
    return Semantics(
      label: '${step + 1} / 5: ${appTr(context, labels[step])}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i == 4 ? 0 : 4),
                      decoration: BoxDecoration(
                        color: i <= step ? AppColors.primary : AppColors.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            LocalText(
              '${step + 1} / 5   ${appTr(context, labels[step])}',
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
