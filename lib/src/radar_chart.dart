import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';
import 'core/legend.dart';

class RadarSeries {
  const RadarSeries({required this.name, required this.values, this.color});
  final String name;
  final List<double> values;
  final Color? color;
}

/// Radar / spider chart with one value per axis per series.
class RadarChart extends StatelessWidget {
  const RadarChart({
    super.key,
    required this.axes,
    required this.series,
    this.maxValue,
    this.rings = 5,
    this.filled = true,
    this.showLegend = true,
    this.aspectRatio = 1.1,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<String> axes;
  final List<RadarSeries> series;
  final double? maxValue;
  final int rings;
  final bool filled;
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
          builder: (p, ptr) =>
              _RadarPainter(axes, series, maxValue, rings, filled, t, p, ptr),
        ),
      ),
      if (showLegend && series.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ChartLegend(theme: t, items: [
            for (var i = 0; i < series.length; i++)
              LegendItem(series[i].name, series[i].color ?? t.colorAt(i)),
          ]),
        ),
    ]);
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.axes, this.series, this.maxValue, this.rings, this.filled,
      this.theme, this.progress, this.pointer);
  final List<String> axes;
  final List<RadarSeries> series;
  final double? maxValue;
  final int rings;
  final bool filled;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final n = axes.length;
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 34;
    if (n < 3 || r <= 0) return;
    var dataMax = 0.0;
    for (final s in series) {
      for (final v in s.values) {
        dataMax = math.max(dataMax, v);
      }
    }
    final maxV = maxValue ?? NiceScale.compute(0, dataMax == 0 ? 1 : dataMax).max;
    double ang(int i) => -math.pi / 2 + 2 * math.pi * i / n;
    Offset pt(int i, double f) => c + Offset.fromDirection(ang(i), r * f);

    final grid = Paint()
      ..color = theme.gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var k = 1; k <= rings; k++) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = pt(i, k / rings);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, grid);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(c, pt(i, 1), grid);
      final a = ang(i);
      paintText(canvas, axes[i], pt(i, 1) + Offset.fromDirection(a, 10),
          theme.labelStyle.copyWith(color: theme.textColor),
          align: Alignment(-math.cos(a), -math.sin(a)));
    }

    int? hs;
    int? hi;
    double best = 22;
    for (var si = 0; si < series.length; si++) {
      final s = series[si];
      final color = s.color ?? theme.colorAt(si);
      final pts = <Offset>[];
      for (var i = 0; i < n; i++) {
        final v = i < s.values.length ? s.values[i] : 0.0;
        pts.add(pt(i, ((v / maxV).clamp(0.0, 1.0) * progress).toDouble()));
      }
      final path = Path()..addPolygon(pts, true);
      if (filled) canvas.drawPath(path, Paint()..color = color.faded(.22));
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeJoin = StrokeJoin.round);
      for (var i = 0; i < n; i++) {
        canvas.drawCircle(pts[i], 3.5, Paint()..color = color);
        final ptr = pointer;
        if (ptr != null && (pts[i] - ptr).distance < best) {
          best = (pts[i] - ptr).distance;
          hs = si;
          hi = i;
        }
      }
    }
    if (hs != null && hi != null && pointer != null && progress >= 1) {
      final s = series[hs];
      final v = hi < s.values.length ? s.values[hi] : 0.0;
      paintTooltip(canvas, size, pointer!, theme,
          title: axes[hi],
          rows: [TooltipRow('${s.name}: ${formatNumber(v)}', color: s.color ?? theme.colorAt(hs))]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
