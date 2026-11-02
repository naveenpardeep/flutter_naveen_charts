import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';

class RadialBarItem {
  const RadialBarItem(this.label, this.value, {this.color});
  final String label;
  final double value;
  final Color? color;
}

/// Concentric progress rings ("activity rings", radial bars).
class RadialBarChart extends StatelessWidget {
  const RadialBarChart({
    super.key,
    required this.items,
    this.maxValue = 100,
    this.startAngle = -math.pi / 2,
    this.sweepAngle = 3 * math.pi / 2,
    this.ringWidth = 14,
    this.ringGap = 6,
    this.centerText,
    this.showLabels = true,
    this.valueFormat,
    this.aspectRatio = 1.2,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 1000),
  });
  final List<RadialBarItem> items;
  final double maxValue;
  final double startAngle;
  final double sweepAngle;
  final double ringWidth;
  final double ringGap;
  final String? centerText;
  final bool showLabels;
  final String Function(double)? valueFormat;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ChartCanvas(
        duration: animationDuration,
        builder: (p, ptr) => _RadialPainter(this, t, p, ptr),
      ),
    );
  }
}

class _RadialPainter extends CustomPainter {
  _RadialPainter(this.w, this.theme, this.progress, this.pointer);
  final RadialBarChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = math.min(size.width, size.height) / 2 - 8;
    final fmt = w.valueFormat ?? formatNumber;
    final labelsFit = w.sweepAngle < 2 * math.pi - 0.2;
    int? hover;
    final ptr = pointer;
    for (var i = 0; i < w.items.length; i++) {
      final radius = outer - i * (w.ringWidth + w.ringGap) - w.ringWidth / 2;
      if (radius <= w.ringWidth / 2) break;
      final it = w.items[i];
      final color = it.color ?? theme.colorAt(i);
      final rect = Rect.fromCircle(center: c, radius: radius);
      canvas.drawArc(rect, w.startAngle, w.sweepAngle, false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w.ringWidth
            ..strokeCap = StrokeCap.round
            ..color = theme.gridColor);
      final f = (it.value / w.maxValue).clamp(0.0, 1.0).toDouble();
      if (f > 0) {
        canvas.drawArc(rect, w.startAngle, w.sweepAngle * f * progress, false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = w.ringWidth
              ..strokeCap = StrokeCap.round
              ..color = color);
      }
      if (w.showLabels && labelsFit && progress > .99) {
        paintText(canvas, '${it.label}  ${fmt(it.value)}',
            Offset(c.dx - 8, c.dy - radius), theme.labelStyle.copyWith(color: theme.textColor),
            align: Alignment.centerRight);
      }
      if (ptr != null && ((ptr - c).distance - radius).abs() <= (w.ringWidth + w.ringGap) / 2) {
        hover = i;
      }
    }
    if (w.centerText != null) {
      paintText(canvas, w.centerText!, c,
          TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold));
    }
    if (hover != null && ptr != null && progress >= 1) {
      final it = w.items[hover];
      paintTooltip(canvas, size, ptr, theme, rows: [
        TooltipRow('${it.label}: ${fmt(it.value)} / ${fmt(w.maxValue)}', color: it.color ?? theme.colorAt(hover))
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
