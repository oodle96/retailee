import 'package:flutter/material.dart';
import '../theme.dart';

enum RetailGlyphKind {
  shop,
  shelf,
  capture,
  report,
  tasks,
  bottle,
  packet,
  sack,
  box,
}

class RetailGlyph extends StatelessWidget {
  final RetailGlyphKind kind;
  final double size;
  final Color color;
  const RetailGlyph(
    this.kind, {
    super.key,
    this.size = 30,
    this.color = AppColors.primaryDark,
  });

  factory RetailGlyph.product(String name) {
    final n = name.toLowerCase();
    final kind =
        n.contains('aqua') || n.contains('pucuk') || n.contains('botol')
        ? RetailGlyphKind.bottle
        : n.contains('gula') || n.contains('beras')
        ? RetailGlyphKind.sack
        : n.contains('kopi') || n.contains('mie') || n.contains('sachet')
        ? RetailGlyphKind.packet
        : RetailGlyphKind.box;
    return RetailGlyph(kind, size: 48);
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _GlyphPainter(kind, color)),
    ),
  );
}

class _GlyphPainter extends CustomPainter {
  final RetailGlyphKind kind;
  final Color color;
  _GlyphPainter(this.kind, this.color);
  @override
  void paint(Canvas c, Size size) {
    c.scale(size.width / 32, size.height / 32);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    void path(List<Offset> points, {bool close = false}) {
      final v = Path()..addPolygon(points, close);
      c.drawPath(v, p);
    }

    void line(double x, double y, double a, double b) =>
        c.drawLine(Offset(x, y), Offset(a, b), p);
    void rect(double x, double y, double w, double h) => c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        const Radius.circular(2),
      ),
      p,
    );
    switch (kind) {
      case RetailGlyphKind.shop:
        path([
          const Offset(4, 13),
          const Offset(7, 5),
          const Offset(25, 5),
          const Offset(28, 13),
        ], close: true);
        line(12, 5, 11, 13);
        line(20, 5, 21, 13);
        rect(6, 14, 20, 14);
        rect(17, 20, 5, 8);
        line(10, 19, 13, 19);
        line(10, 22, 13, 22);
      case RetailGlyphKind.shelf:
        line(4, 4, 4, 28);
        line(28, 4, 28, 28);
        line(4, 15, 28, 15);
        line(4, 27, 28, 27);
        rect(8, 6, 6, 9);
        rect(18, 8, 6, 7);
        rect(8, 19, 7, 8);
        rect(19, 20, 5, 7);
      case RetailGlyphKind.capture:
        path([const Offset(3, 10), const Offset(3, 3), const Offset(10, 3)]);
        path([const Offset(22, 3), const Offset(29, 3), const Offset(29, 10)]);
        path([const Offset(3, 22), const Offset(3, 29), const Offset(10, 29)]);
        path([
          const Offset(22, 29),
          const Offset(29, 29),
          const Offset(29, 22),
        ]);
        rect(9, 8, 14, 16);
        line(12, 12, 20, 12);
        line(12, 16, 20, 16);
        line(12, 20, 17, 20);
      case RetailGlyphKind.report:
        rect(5, 3, 22, 26);
        line(10, 23, 10, 18);
        line(16, 23, 16, 13);
        line(22, 23, 22, 9);
        line(9, 7, 15, 7);
      case RetailGlyphKind.tasks:
        rect(6, 5, 21, 24);
        rect(12, 2, 9, 6);
        path([
          const Offset(10, 15),
          const Offset(12, 17),
          const Offset(16, 12),
        ]);
        line(19, 15, 23, 15);
        line(10, 23, 13, 23);
        line(18, 23, 23, 23);
      case RetailGlyphKind.bottle:
        rect(12, 2, 8, 4);
        path([
          const Offset(12, 6),
          const Offset(12, 10),
          const Offset(8, 14),
          const Offset(8, 29),
          const Offset(24, 29),
          const Offset(24, 14),
          const Offset(20, 10),
          const Offset(20, 6),
        ]);
        rect(8, 17, 16, 7);
        line(12, 14, 12, 16);
      case RetailGlyphKind.packet:
        path([
          const Offset(7, 3),
          const Offset(25, 3),
          const Offset(23, 16),
          const Offset(25, 29),
          const Offset(7, 29),
          const Offset(9, 16),
        ], close: true);
        line(8, 7, 24, 7);
        line(8, 25, 24, 25);
        c.drawOval(const Rect.fromLTWH(11, 12, 10, 8), p);
      case RetailGlyphKind.sack:
        rect(10, 3, 12, 4);
        path([
          const Offset(10, 7),
          const Offset(5, 27),
          const Offset(7, 29),
          const Offset(25, 29),
          const Offset(27, 27),
          const Offset(22, 7),
        ], close: true);
        c.drawPath(
          Path()
            ..moveTo(16, 23)
            ..quadraticBezierTo(9, 17, 16, 12)
            ..quadraticBezierTo(23, 17, 16, 23),
          p,
        );
      case RetailGlyphKind.box:
        path([
          const Offset(4, 10),
          const Offset(16, 4),
          const Offset(28, 10),
          const Offset(16, 16),
        ], close: true);
        path([
          const Offset(4, 10),
          const Offset(4, 24),
          const Offset(16, 30),
          const Offset(28, 24),
          const Offset(28, 10),
        ]);
        line(16, 16, 16, 30);
        line(10, 7, 22, 13);
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
