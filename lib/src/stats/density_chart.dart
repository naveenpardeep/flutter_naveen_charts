import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/legend.dart';
import '../core/plot_frame.dart';
import '../core/stats.dart';

class DensitySeries {
  const DensitySeries(this.name, this.values, {this.color});
  final String name;
  final List<double> values;
  final Color? color;
}

/// Kernel density curves (optionally over a histogram and with a rug).
class DensityChart extends StatelessWidget {
  const DensityChart({
    super.key,
    required this.series,
    this.bandwidth,
    this.points = 120,
    this.fill = true,
    this.showHistogram = false,
    this.histogramBins = 20,
    this.showRug = false,
    this.xFormat,
    this.xTitle,
    this.yAxisTitle = 'Density',
    this.showLegend = true,
    this.aspectRatio = 1.6,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<DensitySeries> series;
  final double? bandwidth;
  final int points;
  final bool fill;
  final bool showHistogram;
  final int histogramBins;
  final bool showRug;
  final String Function(double)? xFormat;
  final String? xTitle, yAxisTitle;
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
      builder: (p, ptr) => _DensityPainter(this, t, p, ptr),
    );
  }
}

class _DensityPainter extends CustomPainter {
  _DensityPainter(this.w, this.theme, this.progress, this.pointer);
  final DensityChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final sorted = [for (final s in w.series) sortedCopy(s.values)];
    if (sorted.isEmpty || sorted.every((s) => s.isEmpty)) return;
    final hs = [for (final s in sorted) w.bandwidth ?? silverman(s)];
    var lo = double.infinity, hi = -double.infinity;
    for (var i = 0; i < sorted.length; i++) {
      if (sorted[i].isEmpty) continue;
      lo = math.min(lo, sorted[i].first - 2 * hs[i]);
      hi = math.max(hi, sorted[i].last + 2 * hs[i]);
    }
    final grid = [for (var k = 0; k < w.points; k++) lo + (hi - lo) * k / (w.points - 1)];
    final dens = [for (var i = 0; i < sorted.length; i++) kde(sorted[i], grid, hs[i])];
    var yMax = dens.expand((d) => d).fold<double>(0, math.max);
    final binW = (hi - lo) / w.histogramBins;
    final hist = <List<double>>[];
    if (w.showHistogram) {
      for (final s in sorted) {
        final c = List<double>.filled(w.histogramBins, 0);
        for (final v in s) {
          c[((v - lo) / binW).floor().clamp(0, w.histogramBins - 1).toInt()] += 1;
        }
        final d = [for (final x in c) s.isEmpty ? 0.0 : x / (s.length * binW)];
        hist.add(d);
        yMax = math.max(yMax, d.fold<double>(0, math.max));
      }
    }
    final f = paintFrame(canvas, size, theme,
        xLo: lo, xHi: hi, yLo: 0, yHi: yMax, includeZero: true, xFormat: w.xFormat, xTitle: w.xTitle, yTitle: w.yAxisTitle);
    if (f == null) return;
    canvas.save();
    canvas.clipRect(f.plot.inflate(1));
    for (var i = 0; i < sorted.length; i++) {
      final color = w.series[i].color ?? theme.colorAt(i);
      if (w.showHistogram) {
        for (var b = 0; b < w.histogramBins; b++) {
          final x0 = f.sx(lo + b * binW), x1 = f.sx(lo + (b + 1) * binW);
          canvas.drawRect(Rect.fromLTRB(x0 + 1, f.sy(hist[i][b] * progress), x1 - 1, f.sy(0)), Paint()..color = color.faded(.14));
        }
      }
      final pts = [for (var k = 0; k < w.points; k++) Offset(f.sx(grid[k]), f.sy(dens[i][k] * progress))];
      final line = buildLinePath(pts, curved: true);
      if (w.fill) {
        final area = Path.from(line)
          ..lineTo(pts.last.dx, f.sy(0))
          ..lineTo(pts.first.dx, f.sy(0))
          ..close();
        canvas.drawPath(area, Paint()..color = color.faded(.2));
      }
      canvas.drawPath(line, Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round);
      if (w.showRug) {
        for (final v in sorted[i]) {
          canvas.drawLine(Offset(f.sx(v), f.plot.bottom), Offset(f.sx(v), f.plot.bottom - 6),
              Paint()
                ..color = color.faded(.55)
                ..strokeWidth = 1);
        }
      }
    }
    canvas.restore();
    final ptr = pointer;
    if (ptr != null && progress >= 1 && f.plot.contains(ptr)) {
      final x = f.xAt(ptr.dx);
      final k = (((x - lo) / (hi - lo)) * (w.points - 1)).round().clamp(0, w.points - 1).toInt();
      canvas.drawLine(Offset(f.sx(grid[k]), f.plot.top), Offset(f.sx(grid[k]), f.plot.bottom),
          Paint()
            ..color = theme.axisColor.faded(.6)
            ..strokeWidth = 1);
      paintTooltip(canvas, size, ptr, theme, title: (w.xFormat ?? formatNumber)(grid[k]), rows: [
        for (var i = 0; i < sorted.length; i++)
          TooltipRow('${w.series[i].name}: ${formatNumber(dens[i][k])}', color: w.series[i].color ?? theme.colorAt(i)),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
