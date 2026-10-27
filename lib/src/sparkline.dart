import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';

/// Tiny inline trend line, e.g. inside list tiles or table cells.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.color,
    this.width = 120,
    this.height = 36,
    this.strokeWidth = 2,
    this.fill = true,
    this.theme,
  });
  final List<double> values;
  final Color? color;
  final double width;
  final double height;
  final double strokeWidth;
  final bool fill;
  final ChartTheme? theme;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    final c = color ?? t.colorAt(0);
    return SizedBox(
      width: width,
      height: height,
      child: ChartCanvas(
        interactive: false,
        duration: const Duration(milliseconds: 700),
        builder: (p, _) => _SparkPainter(values, c, strokeWidth, fill, p),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.v, this.color, this.sw, this.fill, this.progress);
  final List<double> v;
  final Color color;
  final double sw;
  final bool fill;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
    final lo = v.reduce(math.min), hi = v.reduce(math.max);
    final span = hi == lo ? 1.0 : hi - lo;
    const pad = 4.0;
    Offset pt(int i) => Offset(
        pad + i / (v.length - 1) * (size.width - 2 * pad),
        size.height - pad - (v[i] - lo) / span * (size.height - 2 * pad));
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < v.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    if (fill) {
      final area = Path.from(path)
        ..lineTo(pt(v.length - 1).dx, size.height)
        ..lineTo(pt(0).dx, size.height)
        ..close();
      canvas.drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.faded(.3), color.faded(0)],
            ).createShader(Offset.zero & size));
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round);
    canvas.restore();
    if (progress > .99) {
      canvas.drawCircle(pt(v.length - 1), sw + 1.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
