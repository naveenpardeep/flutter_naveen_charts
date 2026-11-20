import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/legend.dart';
import '../core/plot_frame.dart';
import '../core/stats.dart';

class EcdfSeries {
  const EcdfSeries(this.name, this.values, {this.color});
  final String name;
  final List<double> values;
  final Color? color;
}

/// Empirical cumulative distribution function (step curves).
class EcdfChart extends StatelessWidget {
  const EcdfChart({
    super.key,
    required this.series,
    this.complementary = false,
    this.showPoints = false,
    this.xFormat,
    this.xTitle,
    this.showLegend = true,
    this.aspectRatio = 1.6,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<EcdfSeries> series;

  /// Plot 1 - F(x) (survival curve) instead of F(x).
  final bool complementary;
  final bool showPoints;
  final String Function(double)? xFormat;
  final String? xTitle;
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
      legend: showLegend ? [for (var i = 0; i < series.length; i++) LegendItem(series[i].name, series[i].color ?? t.colorAt(i))] : null,
      builder: (p, ptr) => _EcdfPainter(this, t, p, ptr),
    );
  }
}

class _EcdfPainter extends CustomPainter {
  _EcdfPainter(this.w, this.theme, this.progress, this.pointer);
  final EcdfChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  double _f(List<double> s, double x) {
    // share of values <= x (binary search)
    var lo = 0, hi = s.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (s[mid] <= x) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final p = s.isEmpty ? 0.0 : lo / s.length;
    return w.complementary ? 1 - p : p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sorted = [for (final s in w.series) sortedCopy(s.values)];
    if (sorted.isEmpty || sorted.every((s) => s.isEmpty)) return;
    var lo = double.infinity, hi = -double.infinity;
    for (final s in sorted) {
      if (s.isEmpty) continue;
      lo = math.min(lo, s.first);
      hi = math.max(hi, s.last);
    }
    final pad = (hi - lo) * .04 + 1e-9;
    lo -= pad;
    hi += pad;
    String pct(double v) => '${(v * 100).round()}%';
    final f = paintFrame(canvas, size, theme,
        xLo: lo, xHi: hi, yLo: 0, yHi: 1, includeZero: true, yFormat: pct, xFormat: w.xFormat, xTitle: w.xTitle,
        yTitle: w.complementary ? '1 − F(x)' : 'F(x)');
    if (f == null) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(f.plot.left - 2, f.plot.top - 4, f.plot.left + f.plot.width * progress + 2, f.plot.bottom + 4));
    for (var i = 0; i < sorted.length; i++) {
      final s = sorted[i];
      if (s.isEmpty) continue;
      final color = w.series[i].color ?? theme.colorAt(i);
      final path = Path()..moveTo(f.sx(lo), f.sy(w.complementary ? 1 : 0));
      var prev = w.complementary ? 1.0 : 0.0;
      for (var k = 0; k < s.length; k++) {
        final level = w.complementary ? 1 - (k + 1) / s.length : (k + 1) / s.length;
        path.lineTo(f.sx(s[k]), f.sy(prev));
        path.lineTo(f.sx(s[k]), f.sy(level));
        prev = level;
      }
      path.lineTo(f.sx(hi), f.sy(prev));
      canvas.drawPath(path, Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round);
      if (w.showPoints) {
        for (var k = 0; k < s.length; k++) {
          final level = w.complementary ? 1 - (k + 1) / s.length : (k + 1) / s.length;
          canvas.drawCircle(Offset(f.sx(s[k]), f.sy(level)), 2.6, Paint()..color = color);
        }
      }
    }
    canvas.restore();
    final ptr = pointer;
    if (ptr != null && progress >= 1 && f.plot.contains(ptr)) {
      final x = f.xAt(ptr.dx);
      canvas.drawLine(Offset(ptr.dx, f.plot.top), Offset(ptr.dx, f.plot.bottom),
          Paint()
            ..color = theme.axisColor.faded(.6)
            ..strokeWidth = 1);
      paintTooltip(canvas, size, ptr, theme, title: 'x = ${(w.xFormat ?? formatNumber)(x)}', rows: [
        for (var i = 0; i < sorted.length; i++)
          TooltipRow('${w.series[i].name}: ${(_f(sorted[i], x) * 100).toStringAsFixed(1)}%', color: w.series[i].color ?? theme.colorAt(i)),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
