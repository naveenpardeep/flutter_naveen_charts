// Polar line chart: cyclic series (months, weekdays) as closed curves.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/legend.dart';
import '../core/plot_frame.dart';

/// One closed curve of a [PolarLineChart].
class PolarSeries {
  const PolarSeries(this.name, this.values, {this.color});
  final String name;
  final List<double> values;
  final Color? color;
}

/// Polar line chart for cyclic data: one point per label (months, weekdays,
/// compass directions ...) placed around a circle with the radius showing the
/// value, joined into a smooth closed curve. Overlay several years or
/// scenarios to compare their seasonal shape. Unlike [RadarChart] the curve is
/// smooth, the labels are positions in a cycle and the centre value can be
/// set (see [minValue]).
///
/// Hover a position to read all series.
class PolarLineChart extends StatelessWidget {
  const PolarLineChart({
    super.key,
    required this.labels,
    required this.series,
    this.curved = true,
    this.fill = false,
    this.showMarkers = true,
    this.minValue,
    this.maxValue,
    this.rings = 4,
    this.valueFormat,
    this.showLegend = true,
    this.aspectRatio = 1.1,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 1000),
  });

  /// Names of the positions around the circle, clockwise from 12 o'clock.
  final List<String> labels;
  final List<PolarSeries> series;

  /// Smooth curves (false draws straight segments).
  final bool curved;

  /// Fill the inside of each curve.
  final bool fill;
  final bool showMarkers;

  /// Value at the centre / at the outer ring (default: nice bounds of the data).
  final double? minValue, maxValue;

  /// Number of concentric guide rings.
  final int rings;
  final String Function(double)? valueFormat;
  final bool showLegend;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return chartShell(
      theme: t,
      aspectRatio: aspectRatio,
      duration: animationDuration,
      legend: showLegend
          ? [
              for (var i = 0; i < series.length; i++)
                LegendItem(series[i].name, series[i].color ?? t.colorAt(i))
            ]
          : null,
      builder: (p, ptr) => _PolarLinePainter(this, t, p, ptr),
    );
  }
}

class _PolarLinePainter extends CustomPainter {
  _PolarLinePainter(this.w, this.theme, this.progress, this.pointer);
  final PolarLineChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;
  static const double _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.labels.length;
    if (n < 3 || w.series.isEmpty) return;
    final fmt = w.valueFormat ?? formatNumber;
    final c = size.center(Offset.zero);
    final maxLabel = w.labels
        .map((l) => measureText(l, theme.labelStyle).width)
        .fold<double>(0, math.max);
    final R = math.min(size.width / 2 - maxLabel - 14, size.height / 2 - 24);
    if (R < 40) return;
    final slot = 2 * math.pi / n;
    double v(PolarSeries s, int i) =>
        i < s.values.length ? s.values[i] : (w.minValue ?? 0);

    // ---- 1. radial scale between the centre value and the outer ring
    var lo = double.infinity, hi = -double.infinity;
    for (final s in w.series) {
      for (final x in s.values) {
        lo = math.min(lo, x);
        hi = math.max(hi, x);
      }
    }
    final scale = NiceScale.compute(w.minValue ?? lo, w.maxValue ?? hi,
        maxTicks: w.rings + 1);
    final cMin = w.minValue ?? scale.min, cMax = w.maxValue ?? scale.max;
    double radius(double value) =>
        ((value - cMin) / (cMax - cMin)).clamp(0.0, 1.0).toDouble() * R;

    // ---- 2. guide rings (with values) and spokes (with labels)
    for (var k = 1; k <= w.rings; k++) {
      final value = cMin + (cMax - cMin) * k / w.rings;
      canvas.drawCircle(
          c,
          radius(value),
          Paint()
            ..color = theme.gridColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      paintText(canvas, fmt(value), c + Offset(3, -radius(value)),
          theme.labelStyle.copyWith(fontSize: 9),
          align: Alignment.bottomLeft);
    }
    for (var i = 0; i < n; i++) {
      final a = _start + i * slot;
      canvas.drawLine(
          c,
          c + Offset.fromDirection(a, R),
          Paint()
            ..color = theme.gridColor.faded(.6)
            ..strokeWidth = 1);
      paintText(canvas, w.labels[i], c + Offset.fromDirection(a, R + 8),
          theme.labelStyle.copyWith(color: theme.textColor),
          align: Alignment(-math.cos(a), -math.sin(a)));
    }

    // ---- 3. nearest position under the pointer
    int? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1 && (ptr - c).distance <= R + 10) {
      final d = ptr - c;
      final a =
          (((math.atan2(d.dy, d.dx) - _start) % (2 * math.pi)) + 2 * math.pi) %
              (2 * math.pi);
      hover = (a / slot).round() % n;
      canvas.drawLine(
          c,
          c + Offset.fromDirection(_start + hover * slot, R),
          Paint()
            ..color = theme.axisColor
            ..strokeWidth = 1.4);
    }

    // ---- 4. curves
    for (var si = 0; si < w.series.length; si++) {
      final s = w.series[si];
      final color = s.color ?? theme.colorAt(si);
      final pts = [
        for (var i = 0; i < n; i++)
          c +
              Offset.fromDirection(
                  _start + i * slot, radius(cMin + (v(s, i) - cMin) * progress))
      ];
      final path = w.curved ? _closed(pts) : (Path()..addPolygon(pts, true));
      if (w.fill) canvas.drawPath(path, Paint()..color = color.faded(.18));
      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeJoin = StrokeJoin.round);
      if (w.showMarkers) {
        for (final p in pts) {
          canvas.drawCircle(p, 3.4, Paint()..color = color);
        }
      }
    }

    // ---- 5. tooltip
    if (hover != null && ptr != null) {
      paintTooltip(canvas, size, ptr, theme, title: w.labels[hover], rows: [
        for (var si = 0; si < w.series.length; si++)
          TooltipRow('${w.series[si].name}: ${fmt(v(w.series[si], hover))}',
              color: w.series[si].color ?? theme.colorAt(si)),
      ]);
    }
  }

  /// Smooth closed curve through [pts] (Catmull-Rom turned into Beziers).
  Path _closed(List<Offset> pts) {
    final n = pts.length;
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < n; i++) {
      final p0 = pts[(i - 1 + n) % n],
          p1 = pts[i],
          p2 = pts[(i + 1) % n],
          p3 = pts[(i + 2) % n];
      final c1 = p1 + (p2 - p0) / 6, c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
