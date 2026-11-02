import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';
import 'core/legend.dart';
import 'pie_chart.dart' show PieSlice;

/// Polar area ("Nightingale rose"): equal angles, radius shows the value.
class PolarAreaChart extends StatelessWidget {
  const PolarAreaChart({
    super.key,
    required this.slices,
    this.maxValue,
    this.rings = 4,
    this.areaProportional = true,
    this.showLabels = true,
    this.showLegend = false,
    this.aspectRatio = 1.1,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<PieSlice> slices;
  final double? maxValue;
  final int rings;

  /// true: wedge area is proportional to value; false: radius is.
  final bool areaProportional;
  final bool showLabels;
  final bool showLegend;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AspectRatio(
        aspectRatio: aspectRatio,
        child: ChartCanvas(
          duration: animationDuration,
          builder: (p, ptr) => _PolarPainter(this, t, p, ptr),
        ),
      ),
      if (showLegend)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ChartLegend(theme: t, items: [
            for (var i = 0; i < slices.length; i++)
              LegendItem(slices[i].label, slices[i].color ?? t.colorAt(i)),
          ]),
        ),
    ]);
  }
}

class _PolarPainter extends CustomPainter {
  _PolarPainter(this.w, this.theme, this.progress, this.pointer);
  final PolarAreaChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.slices.length;
    if (n == 0) return;
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - (w.showLabels ? 36 : 10);
    if (r <= 0) return;
    final dataMax = w.slices.map((s) => s.value).reduce(math.max);
    final maxV = w.maxValue ?? NiceScale.compute(0, dataMax <= 0 ? 1 : dataMax).max;
    double rad(double v) {
      final f = (v / maxV).clamp(0.0, 1.0).toDouble();
      return r * (w.areaProportional ? math.sqrt(f) : f);
    }

    final grid = Paint()
      ..color = theme.gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var k = 1; k <= w.rings; k++) {
      final v = maxV * k / w.rings;
      canvas.drawCircle(c, rad(v), grid);
      paintText(canvas, formatNumber(v), c + Offset(3, -rad(v)), theme.labelStyle,
          align: Alignment.topLeft);
    }
    final step = 2 * math.pi / n;
    const start = -math.pi / 2;
    int? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      final d = ptr - c;
      final a = (math.atan2(d.dy, d.dx) - start) % (2 * math.pi);
      final i = (a / step).floor().clamp(0, n - 1).toInt();
      if (d.distance <= rad(w.slices[i].value)) hover = i;
    }
    for (var i = 0; i < n; i++) {
      final s = w.slices[i];
      final color = s.color ?? theme.colorAt(i);
      final a0 = start + i * step;
      canvas.drawPath(sectorPath(c, 0, rad(s.value) * progress, a0 + .01, step - .02),
          Paint()..color = color.faded(hover == i ? 1 : .85));
      if (w.showLabels) {
        final mid = a0 + step / 2;
        paintText(canvas, s.label, c + Offset.fromDirection(mid, r + 10),
            theme.labelStyle.copyWith(color: theme.textColor),
            align: Alignment(-math.cos(mid), -math.sin(mid)));
      }
    }
    if (hover != null && ptr != null) {
      final s = w.slices[hover];
      paintTooltip(canvas, size, ptr, theme,
          rows: [TooltipRow('${s.label}: ${formatNumber(s.value)}', color: s.color ?? theme.colorAt(hover))]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
