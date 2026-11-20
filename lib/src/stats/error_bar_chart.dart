import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/legend.dart';
import '../core/plot_frame.dart';

/// Values with uncertainty. Give symmetric [errors] or separate
/// [errorsLow] / [errorsHigh] (positive offsets from the value).
class ErrorBarSeries {
  const ErrorBarSeries({
    required this.name,
    required this.values,
    this.errors,
    this.errorsLow,
    this.errorsHigh,
    this.color,
  });
  final String name;
  final List<double> values;
  final List<double>? errors, errorsLow, errorsHigh;
  final Color? color;

  double low(int i) => ((errorsLow ?? errors) != null && i < (errorsLow ?? errors)!.length) ? (errorsLow ?? errors)![i].abs() : 0;
  double high(int i) => ((errorsHigh ?? errors) != null && i < (errorsHigh ?? errors)!.length) ? (errorsHigh ?? errors)![i].abs() : 0;
}

/// Points (or bars) with error whiskers, e.g. confidence intervals or std. dev.
class ErrorBarChart extends StatelessWidget {
  const ErrorBarChart({
    super.key,
    required this.labels,
    required this.series,
    this.asBars = false,
    this.capWidth = 10,
    this.dotRadius = 5,
    this.lineWidth = 2,
    this.showLegend = true,
    this.yFormat,
    this.yAxisTitle,
    this.aspectRatio = 1.6,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<String> labels;
  final List<ErrorBarSeries> series;

  /// Draw bars (from zero) instead of dots.
  final bool asBars;
  final double capWidth, dotRadius, lineWidth;
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
      legend: showLegend ? [for (var i = 0; i < series.length; i++) LegendItem(series[i].name, series[i].color ?? t.colorAt(i))] : null,
      builder: (p, ptr) => _ErrPainter(this, t, p, ptr),
    );
  }
}

class _ErrPainter extends CustomPainter {
  _ErrPainter(this.w, this.theme, this.progress, this.pointer);
  final ErrorBarChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.labels.length;
    if (n == 0 || w.series.isEmpty) return;
    var lo = double.infinity, hi = -double.infinity;
    for (final s in w.series) {
      for (var i = 0; i < math.min(n, s.values.length); i++) {
        lo = math.min(lo, s.values[i] - s.low(i));
        hi = math.max(hi, s.values[i] + s.high(i));
      }
    }
    if (!lo.isFinite) return;
    final fmt = w.yFormat ?? formatNumber;
    final f = paintFrame(canvas, size, theme,
        xLo: 0, xHi: 0, yLo: lo, yHi: hi, xCats: w.labels, includeZero: w.asBars, yFormat: w.yFormat, yTitle: w.yAxisTitle);
    if (f == null) return;
    final unit = f.plot.width / (f.xHi - f.xLo);
    final m = w.series.length;
    final slot = unit * .6 / m;
    int? hover;
    final ptr = pointer;
    if (ptr != null && f.plot.inflate(6).contains(ptr)) {
      hover = f.catAt(ptr, n);
      canvas.drawRect(Rect.fromLTWH(f.sx(hover - .5), f.plot.top, unit, f.plot.height), Paint()..color = theme.axisColor.faded(.12));
    }
    for (var j = 0; j < m; j++) {
      final s = w.series[j];
      final color = s.color ?? theme.colorAt(j);
      for (var i = 0; i < math.min(n, s.values.length); i++) {
        final x = f.sx(i.toDouble()) + (j - (m - 1) / 2) * slot;
        final v = s.values[i];
        final yv = f.sy(v);
        if (w.asBars) {
          final y0 = f.sy(0);
          final yEnd = y0 + (yv - y0) * progress;
          canvas.drawRect(Rect.fromLTRB(x - slot * .4, math.min(y0, yEnd), x + slot * .4, math.max(y0, yEnd)), Paint()..color = color.faded(.6));
        }
        final yl = f.sy(v - s.low(i) * progress), yh = f.sy(v + s.high(i) * progress);
        final p = Paint()
          ..color = w.asBars ? theme.textColor.faded(.85) : color
          ..strokeWidth = w.lineWidth
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(x, yl), Offset(x, yh), p);
        canvas.drawLine(Offset(x - w.capWidth / 2, yl), Offset(x + w.capWidth / 2, yl), p);
        canvas.drawLine(Offset(x - w.capWidth / 2, yh), Offset(x + w.capWidth / 2, yh), p);
        if (!w.asBars) {
          canvas.drawCircle(Offset(x, yv), w.dotRadius * progress, Paint()..color = color);
          canvas.drawCircle(Offset(x, yv), w.dotRadius * progress / 2.4, Paint()..color = theme.surface);
        }
      }
    }
    if (hover != null && ptr != null && progress >= 1) {
      paintTooltip(canvas, size, ptr, theme, title: w.labels[hover], rows: [
        for (var j = 0; j < m; j++)
          if (hover < w.series[j].values.length)
            TooltipRow(
                '${w.series[j].name}: ${fmt(w.series[j].values[hover])} (−${fmt(w.series[j].low(hover))} / +${fmt(w.series[j].high(hover))})',
                color: w.series[j].color ?? theme.colorAt(j)),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
