import 'package:flutter/material.dart';

/// Static route sketch on the enterprise login promo panel.
class DeliveryRouteMapPainter extends CustomPainter {
  const DeliveryRouteMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = RRect.fromRectAndRadius(rect, const Radius.circular(14));
    canvas.drawRRect(
      radius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E5C9A), Color(0xFF143E70)],
        ).createShader(rect),
    );

    final path = Path()
      ..moveTo(size.width * 0.05, size.height * 0.68)
      ..quadraticBezierTo(
        size.width * 0.40,
        size.height * 0.02,
        size.width * 0.96,
        size.height * 0.34,
      );
    final stroke = Paint()
      ..color = const Color(0xFFB9DCFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + 8).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, next), stroke);
        distance += 13;
      }
    }

    _pin(canvas, Offset(size.width * 0.12, size.height * 0.60));
    _pin(canvas, Offset(size.width * 0.55, size.height * 0.38), filled: true);
    _pill(
      canvas,
      'Ahmed Khan (R-03): Stop 14/18',
      Offset(size.width * 0.04, size.height * 0.70),
      size.width * 0.48,
    );
    _pill(
      canvas,
      'Bilal Ahmed: Doorstep Invoice',
      Offset(size.width * 0.42, size.height * 0.08),
      size.width * 0.52,
    );
  }

  void _pin(Canvas canvas, Offset center, {bool filled = false}) {
    canvas.drawCircle(center, 7, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      3.5,
      Paint()
        ..color = filled ? const Color(0xFF1673D1) : const Color(0xFF102848),
    );
  }

  void _pill(Canvas canvas, String text, Offset origin, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: 'Noto Sans',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth - 22);
    final height = painter.height + 10;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(origin.dx, origin.dy, painter.width + 22, height),
      const Radius.circular(20),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xE6101C30));
    canvas.drawCircle(
      Offset(origin.dx + 9, origin.dy + height / 2),
      3,
      Paint()..color = const Color(0xFF7DFFC3),
    );
    painter.paint(canvas, Offset(origin.dx + 16, origin.dy + 5));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
