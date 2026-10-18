import 'package:flutter/material.dart';

enum RetailScene { notebook, capture, shelf, receipts }

/// Original vector artwork: shop tools, drawn on a shared 240 × 180 grid.
class RetailArt extends StatelessWidget {
  final RetailScene scene;
  final double width;
  const RetailArt({super.key, required this.scene, this.width = 240});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: width,
      height: width * .75,
      child: CustomPaint(painter: RetailArtPainter(scene)),
    ),
  );
}

class RetailArtPainter extends CustomPainter {
  final RetailScene scene;
  const RetailArtPainter(this.scene);

  static const ink = Color(0xFF332D4C);
  static const paper = Color(0xFFFFFCF3);
  static const violet = Color(0xFF8373D5);
  static const pale = Color(0xFFE6E0F5);
  static const mint = Color(0xFFA8C9BB);
  static const ochre = Color(0xFFDCA958);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 240, size.height / 180);
    final fill = Paint()..isAntiAlias = true;
    final stroke = Paint()
      ..isAntiAlias = true
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void shape(Path path, Color color) {
      canvas.drawPath(path, fill..color = color);
      canvas.drawPath(path, stroke);
    }

    void box(
      double x,
      double y,
      double w,
      double h,
      Color color, [
      double radius = 3,
    ]) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        Radius.circular(radius),
      );
      canvas.drawRRect(rect, fill..color = color);
      canvas.drawRRect(rect, stroke);
    }

    void line(
      double x,
      double y,
      double x2,
      double y2, {
      Color color = ink,
      double weight = 2.5,
    }) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x2, y2),
        stroke
          ..color = color
          ..strokeWidth = weight,
      );
      stroke
        ..color = ink
        ..strokeWidth = 2.5;
    }

    void ellipse(double x, double y, double w, double h, Color color) {
      canvas.drawOval(Rect.fromLTWH(x, y, w, h), fill..color = color);
      canvas.drawOval(Rect.fromLTWH(x, y, w, h), stroke);
    }

    void ledger() {
      box(48, 30, 126, 126, violet, 5);
      box(42, 23, 126, 126, paper, 5);
      box(42, 23, 21, 126, pale, 5);
      line(63, 26, 63, 146);
      for (var i = 0; i < 6; i++) {
        final y = 38.0 + i * 19;
        canvas.drawPath(
          Path()
            ..moveTo(48, y)
            ..cubicTo(30, y - 8, 30, y + 10, 47, y + 7),
          stroke,
        );
      }
      line(76, 44, 123, 44, weight: 4);
      line(76, 58, 151, 58, color: violet, weight: 1.5);
      line(124, 65, 124, 132, color: mint, weight: 1.5);
      for (var i = 0; i < 4; i++) {
        final y = 76.0 + i * 18;
        line(75, y, 151, y, color: mint, weight: 1.5);
      }
      // Blank ruled columns deliberately avoid fabricated business figures.
      canvas.save();
      canvas.translate(189, 37);
      canvas.rotate(.24);
      box(0, 0, 12, 91, ochre, 2);
      box(0, 0, 12, 12, pale, 2);
      line(4, 17, 4, 83, color: paper, weight: 2);
      shape(
        Path()
          ..moveTo(0, 91)
          ..lineTo(6, 108)
          ..lineTo(12, 91)
          ..close(),
        paper,
      );
      shape(
        Path()
          ..moveTo(3.8, 102)
          ..lineTo(6, 108)
          ..lineTo(8.2, 102)
          ..close(),
        ink,
      );
      canvas.restore();
    }

    switch (scene) {
      case RetailScene.notebook:
        // A familiar warung ledger and pencil, without floating UI decorations.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(27, 151, 186, 8),
            const Radius.circular(4),
          ),
          fill..color = pale,
        );
        ledger();
      case RetailScene.capture:
        canvas.save();
        canvas.translate(15, 4);
        canvas.scale(.87);
        ledger();
        canvas.restore();
        stroke
          ..color = ink
          ..strokeWidth = 4;
        for (final p in [
          Path()
            ..moveTo(27, 53)
            ..lineTo(27, 18)
            ..lineTo(62, 18),
          Path()
            ..moveTo(179, 18)
            ..lineTo(214, 18)
            ..lineTo(214, 53),
          Path()
            ..moveTo(27, 124)
            ..lineTo(27, 158)
            ..lineTo(62, 158),
          Path()
            ..moveTo(179, 158)
            ..lineTo(214, 158)
            ..lineTo(214, 124),
        ]) {
          canvas.drawPath(p, stroke);
        }
        stroke
          ..color = ink
          ..strokeWidth = 2.5;
        box(174, 115, 42, 35, mint, 5);
        box(185, 110, 18, 8, mint, 2);
        ellipse(185, 123, 18, 18, paper);
        ellipse(191, 129, 6, 6, ink);
      case RetailScene.shelf:
        line(28, 160, 213, 160, color: pale, weight: 8);
        box(34, 37, 8, 119, violet, 2);
        box(198, 37, 8, 119, violet, 2);
        box(29, 101, 182, 9, paper, 2);
        box(29, 145, 182, 9, paper, 2);
        // Unbranded bottle, folded rice bag and two tins.
        shape(
          Path()
            ..moveTo(57, 99)
            ..lineTo(57, 70)
            ..quadraticBezierTo(57, 65, 64, 61)
            ..lineTo(64, 48)
            ..lineTo(75, 48)
            ..lineTo(75, 61)
            ..quadraticBezierTo(82, 65, 82, 70)
            ..lineTo(82, 99)
            ..close(),
          mint,
        );
        box(63, 44, 13, 7, violet, 2);
        box(58, 76, 23, 14, paper, 1);
        shape(
          Path()
            ..moveTo(98, 99)
            ..lineTo(102, 57)
            ..lineTo(134, 57)
            ..lineTo(141, 99)
            ..close(),
          paper,
        );
        box(102, 53, 32, 8, ochre, 1);
        canvas.drawPath(
          Path()
            ..moveTo(116, 85)
            ..quadraticBezierTo(109, 76, 117, 69)
            ..quadraticBezierTo(125, 76, 116, 85),
          stroke,
        );
        line(116, 85, 115, 92);
        box(155, 68, 28, 31, pale, 2);
        ellipse(155, 64, 28, 8, violet);
        line(162, 82, 176, 82, color: paper, weight: 4);
        box(51, 121, 30, 23, paper, 2);
        ellipse(51, 117, 30, 8, mint);
        // The open lower shelf is the empty-inventory metaphor.
        line(99, 133, 159, 133, color: pale, weight: 3);
      case RetailScene.receipts:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(44, 153, 155, 8),
            const Radius.circular(4),
          ),
          fill..color = pale,
        );
        canvas.save();
        canvas.translate(61, 25);
        canvas.rotate(-.10);
        box(0, 0, 96, 127, violet, 4);
        canvas.restore();
        shape(
          Path()
            ..moveTo(83, 22)
            ..lineTo(172, 22)
            ..lineTo(172, 149)
            ..lineTo(161, 142)
            ..lineTo(150, 149)
            ..lineTo(139, 142)
            ..lineTo(128, 149)
            ..lineTo(117, 142)
            ..lineTo(106, 149)
            ..lineTo(95, 142)
            ..lineTo(83, 149)
            ..close(),
          paper,
        );
        box(116, 15, 25, 18, mint, 4);
        line(99, 52, 155, 52, weight: 4);
        for (var i = 0; i < 3; i++) {
          final y = 72.0 + i * 18;
          line(99, y, 127, y, color: violet, weight: 2);
          line(142, y, 155, y, color: mint, weight: 2);
        }
        line(99, 126, 155, 126, weight: 2);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RetailArtPainter oldDelegate) =>
      oldDelegate.scene != scene;
}
