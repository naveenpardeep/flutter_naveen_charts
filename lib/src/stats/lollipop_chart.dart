import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../cartesian/models.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/legend.dart';
import '../core/plot_frame.dart';

/// Lollipop chart: a stem and a dot per value (grouped when several series).
class LollipopChart extends StatelessWidget {
  const LollipopChart({
    super.key,
    required this.labels,
    required this.series,
    this.dotRadius = 6,
    this.stemWidth = 2,
    this.baseline = 0,
    this.showValueLabels = false,
    this.showLegend = true,
    this.yFormat,
    this.yAxisTitle,
    this.aspectRatio = 1.6,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<String> labels;
  final List<BarSeries> series;
  final double dotRadius;
  final double stemWidth;

  /// Stems start here (default 0).
  final double baseline;
  final bool showValueLabels;
  final bool showLegend;
  final String Function(double)? yFormat;
  final String? yAxisTitle;
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
          ? [for (var i = 0; i < series.length; i++) LegendItem(series[i].name, series[i].color ?? t.colorAt(i))]
          : null,
      builder: (p, ptr) => _LollipopPainter(this, t, p, ptr),
    );
  }
}

class _LollipopPainter extends CustomPainter {
  _LollipopPainter(this.w, this.theme, this.progress, this.pointer);
  final LollipopChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  double _v(BarSeries s, int i) => i < s.points.length ? s.points[i].y : w.baseline;

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.labels.length;
    if (n == 0 || w.series.isEmpty) return;
    var lo = w.baseline, hi = w.baseline;
    for (final s in w.series) {
      for (final p in s.points) {
        lo = math.min(lo, p.y);
        hi = math.max(hi, p.y);
      }
    }
    final fmt = w.yFormat ?? formatNumber;
    final f = paintFrame(canvas, size, theme,
        xLo: 0, xHi: 0, yLo: lo, yHi: hi, xCats: w.labels, yFormat: w.yFormat, yTitle: w.yAxisTitle);
    if (f == null) return;
    final unit = f.plot.width / (f.xHi - f.xLo);
    final m = w.series.length;
    final slot = unit * .6 / m;
    int? hover;
    final ptr = pointer;
    if (ptr != null && f.plot.inflate(6).contains(ptr)) {
      hover = f.catAt(ptr, n);
      canvas.drawRect(Rect.fromLTWH(f.sx(hover - .5), f.plot.top, unit, f.plot.height),
          Paint()..color = theme.axisColor.faded(.12));
    }
    for (var j = 0; j < m; j++) {
      final color = w.series[j].color ?? theme.colorAt(j);
      for (var i = 0; i < n; i++) {
        final x = f.sx(i.toDouble()) + (j - (m - 1) / 2) * slot;
        final v = _v(w.series[j], i);
        final y0 = f.sy(w.baseline), y1 = f.sy(w.baseline + (v - w.baseline) * progress);
        canvas.drawLine(Offset(x, y0), Offset(x, y1),
            Paint()
              ..color = color.faded(.7)
              ..strokeWidth = w.stemWidth
              ..strokeCap = StrokeCap.round);
        canvas.drawCircle(Offset(x, y1), w.dotRadius + (hover == i ? 2 : 0), Paint()..color = color);
        canvas.drawCircle(Offset(x, y1), w.dotRadius / 2.4, Paint()..color = theme.surface);
        if (w.showValueLabels && progress > .99) {
          paintText(canvas, fmt(v), Offset(x, v >= w.baseline ? y1 - w.dotRadius - 3 : y1 + w.dotRadius + 3),
              theme.labelStyle, align: v >= w.baseline ? Alignment.bottomCenter : Alignment.topCenter);
        }
      }
    }
    if (hover != null && ptr != null && progress >= 1) {
      paintTooltip(canvas, size, ptr, theme, title: w.labels[hover], rows: [
        for (var j = 0; j < m; j++)
          TooltipRow('${w.series[j].name}: ${fmt(_v(w.series[j], hover))}', color: w.series[j].color ?? theme.colorAt(j)),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
