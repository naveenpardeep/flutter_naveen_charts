import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';

/// Five-number summary for one box.
class BoxPlotStats {
  const BoxPlotStats({
    required this.label,
    required this.min,
    required this.q1,
    required this.median,
    required this.q3,
    required this.max,
    this.mean,
    this.outliers = const [],
    this.color,
  });

  /// Computes quartiles (linear interpolation) and Tukey whiskers
  /// ([whisker] x IQR) from raw samples.
  factory BoxPlotStats.fromValues(String label, List<double> values,
      {double whisker = 1.5, Color? color}) {
    final s = [...values]..sort();
    if (s.isEmpty) {
      return BoxPlotStats(label: label, min: 0, q1: 0, median: 0, q3: 0, max: 0);
    }
    double q(double p) {
      final pos = (s.length - 1) * p;
      final lo = pos.floor(), hi = pos.ceil();
      return s[lo] + (s[hi] - s[lo]) * (pos - lo);
    }

    final q1 = q(.25), med = q(.5), q3 = q(.75);
    final iqr = q3 - q1;
    final loF = q1 - whisker * iqr, hiF = q3 + whisker * iqr;
    final inside = s.where((v) => v >= loF && v <= hiF).toList();
    return BoxPlotStats(
      label: label,
      min: inside.first,
      q1: q1,
      median: med,
      q3: q3,
      max: inside.last,
      mean: s.fold<double>(0, (a, b) => a + b) / s.length,
      outliers: s.where((v) => v < loF || v > hiF).toList(),
      color: color,
    );
  }

  final String label;
  final double min, q1, median, q3, max;
  final double? mean;
  final List<double> outliers;
  final Color? color;
}

class BoxPlotChart extends StatelessWidget {
  const BoxPlotChart({
    super.key,
    required this.data,
    this.showOutliers = true,
    this.showMean = true,
    this.boxWidthFactor = 0.5,
    this.yFormat,
    this.yAxisTitle,
    this.aspectRatio = 1.6,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<BoxPlotStats> data;
  final bool showOutliers;
  final bool showMean;
  final double boxWidthFactor;
  final String Function(double)? yFormat;
  final String? yAxisTitle;
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
        builder: (p, ptr) => _BoxPainter(this, t, p, ptr),
      ),
    );
  }
}

class _BoxPainter extends CustomPainter {
  _BoxPainter(this.w, this.theme, this.progress, this.pointer);
  final BoxPlotChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final d = w.data;
    if (d.isEmpty) return;
    var lo = double.infinity, hi = -double.infinity;
    for (final b in d) {
      lo = math.min(lo, b.min);
      hi = math.max(hi, b.max);
      if (w.showOutliers) {
        for (final o in b.outliers) {
          lo = math.min(lo, o);
          hi = math.max(hi, o);
        }
      }
    }
    final scale = NiceScale.compute(lo, hi);
    final fmt = w.yFormat ?? formatNumber;
    final labelW = scale.ticks
        .map((t) => measureText(fmt(t), theme.labelStyle).width)
        .fold<double>(0, math.max);
    final plot = Rect.fromLTRB(labelW + 12 + (w.yAxisTitle != null ? 16 : 0), 10,
        size.width - 12, size.height - 28);
    if (plot.width <= 0 || plot.height <= 0) return;
    double sy(double v) =>
        plot.bottom - (v - scale.min) / (scale.max - scale.min) * plot.height;
    final unit = plot.width / d.length;
    double cx(int i) => plot.left + (i + .5) * unit;

    final grid = Paint()
      ..color = theme.gridColor
      ..strokeWidth = 1;
    for (final t in scale.ticks) {
      canvas.drawLine(Offset(plot.left, sy(t)), Offset(plot.right, sy(t)), grid);
      paintText(canvas, fmt(t), Offset(plot.left - 6, sy(t)), theme.labelStyle,
          align: Alignment.centerRight);
    }
    if (w.yAxisTitle != null) {
      canvas.save();
      canvas.translate(8, plot.center.dy);
      canvas.rotate(-math.pi / 2);
      paintText(canvas, w.yAxisTitle!, Offset.zero,
          theme.labelStyle.copyWith(color: theme.textColor, fontWeight: FontWeight.w600));
      canvas.restore();
    }

    int? hover;
    final ptr = pointer;
    if (ptr != null && plot.contains(ptr)) {
      hover = ((ptr.dx - plot.left) / unit).floor().clamp(0, d.length - 1).toInt();
      canvas.drawRect(Rect.fromLTWH(plot.left + hover * unit, plot.top, unit, plot.height),
          Paint()..color = theme.axisColor.faded(.12));
    }

    final bw = math.min(unit * w.boxWidthFactor, 70.0);
    for (var i = 0; i < d.length; i++) {
      final b = d[i];
      final color = b.color ?? theme.colorAt(i);
      // animate by growing every statistic away from the median
      double g(double v) => sy(b.median + (v - b.median) * progress);
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawLine(Offset(cx(i), g(b.max)), Offset(cx(i), g(b.q3)), stroke);
      canvas.drawLine(Offset(cx(i), g(b.q1)), Offset(cx(i), g(b.min)), stroke);
      canvas.drawLine(Offset(cx(i) - bw / 4, g(b.max)), Offset(cx(i) + bw / 4, g(b.max)), stroke);
      canvas.drawLine(Offset(cx(i) - bw / 4, g(b.min)), Offset(cx(i) + bw / 4, g(b.min)), stroke);
      final box = RRect.fromRectAndRadius(
          Rect.fromLTRB(cx(i) - bw / 2, g(b.q3), cx(i) + bw / 2, g(b.q1)),
          const Radius.circular(3));
      canvas.drawRRect(box, Paint()..color = color.faded(.3));
      canvas.drawRRect(box, stroke);
      canvas.drawLine(Offset(cx(i) - bw / 2, g(b.median)), Offset(cx(i) + bw / 2, g(b.median)),
          stroke..strokeWidth = 3);
      if (w.showMean && b.mean != null) {
        final p = Offset(cx(i), g(b.mean!));
        canvas.drawCircle(p, 4, Paint()..color = theme.surface);
        canvas.drawCircle(p, 4, Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8);
      }
      if (w.showOutliers && progress > .99) {
        for (final o in b.outliers) {
          canvas.drawCircle(Offset(cx(i), sy(o)), 3,
              Paint()
                ..color = color
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5);
        }
      }
      paintText(canvas, b.label, Offset(cx(i), plot.bottom + 6), theme.labelStyle,
          align: Alignment.topCenter, maxWidth: unit);
    }

    if (hover != null && ptr != null && progress >= 1) {
      final b = d[hover];
      paintTooltip(canvas, size, ptr, theme, title: b.label, rows: [
        TooltipRow('Max     ${fmt(b.max)}'),
        TooltipRow('Q3       ${fmt(b.q3)}'),
        TooltipRow('Median ${fmt(b.median)}'),
        TooltipRow('Q1       ${fmt(b.q1)}'),
        TooltipRow('Min      ${fmt(b.min)}'),
        if (b.mean != null) TooltipRow('Mean   ${fmt(b.mean!)}'),
        if (b.outliers.isNotEmpty) TooltipRow('Outliers: ${b.outliers.length}'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
