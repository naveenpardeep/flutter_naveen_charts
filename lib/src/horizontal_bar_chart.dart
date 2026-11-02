import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'cartesian/models.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';
import 'core/legend.dart';

/// Horizontal bars: grouped, stacked, or diverging (use negative values, or
/// [HorizontalBarChart.pyramid] for a population-pyramid style chart).
class HorizontalBarChart extends StatelessWidget {
  const HorizontalBarChart({
    super.key,
    required this.categories,
    required this.series,
    this.stacked = false,
    this.showValueLabels = true,
    this.showLegend = true,
    this.valueFormat,
    this.title,
    this.barWidthFactor = 0.7,
    this.aspectRatio = 1.4,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  /// Two mirrored series (left values are drawn as negatives).
  factory HorizontalBarChart.pyramid({
    Key? key,
    required List<String> categories,
    required String leftName,
    required List<double> leftValues,
    required String rightName,
    required List<double> rightValues,
    double aspectRatio = 1.4,
    ChartTheme? theme,
  }) =>
      HorizontalBarChart(
        key: key,
        categories: categories,
        series: [
          BarSeries.fromValues(name: leftName, values: [for (final v in leftValues) -v.abs()]),
          BarSeries.fromValues(name: rightName, values: rightValues),
        ],
        valueFormat: (v) => formatNumber(v.abs()),
        showValueLabels: false,
        barWidthFactor: 0.8,
        aspectRatio: aspectRatio,
        theme: theme,
      );

  final List<String> categories;

  /// Series values map to categories by index (`BarSeries.fromValues`).
  final List<BarSeries> series;
  final bool stacked;
  final bool showValueLabels;
  final bool showLegend;
  final String Function(double)? valueFormat;
  final String? title;
  final double barWidthFactor;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (title != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(title!, style: Theme.of(context).textTheme.titleSmall),
        ),
      if (showLegend && series.length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChartLegend(theme: t, items: [
            for (var i = 0; i < series.length; i++)
              LegendItem(series[i].name, series[i].color ?? t.colorAt(i)),
          ]),
        ),
      AspectRatio(
        aspectRatio: aspectRatio,
        child: ChartCanvas(
          duration: animationDuration,
          builder: (p, ptr) => _HBarPainter(this, t, p, ptr),
        ),
      ),
    ]);
  }
}

class _HBarPainter extends CustomPainter {
  _HBarPainter(this.w, this.theme, this.progress, this.pointer);
  final HorizontalBarChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  double _v(BarSeries s, int i) => i < s.points.length ? s.points[i].y : 0;
  Color _c(int j) => w.series[j].color ?? theme.colorAt(j);

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.categories.length;
    if (n == 0 || w.series.isEmpty) return;
    double lo = 0, hi = 0;
    for (var i = 0; i < n; i++) {
      double pos = 0, neg = 0;
      for (final s in w.series) {
        final v = _v(s, i);
        if (w.stacked) {
          if (v >= 0) {
            pos += v;
          } else {
            neg += v;
          }
        } else {
          lo = math.min(lo, v);
          hi = math.max(hi, v);
        }
      }
      if (w.stacked) {
        hi = math.max(hi, pos);
        lo = math.min(lo, neg);
      }
    }
    final scale = NiceScale.compute(lo, hi, includeZero: true);
    final fmt = w.valueFormat ?? formatNumber;
    final labelW = w.categories
        .map((l) => measureText(l, theme.labelStyle).width)
        .fold<double>(0, math.max);
    final rightPad = w.showValueLabels && !w.stacked ? 40.0 : 16.0;
    final leftPad = labelW + 12 + (lo < 0 && w.showValueLabels && !w.stacked ? 30 : 0);
    final plot = Rect.fromLTRB(leftPad, 6, size.width - rightPad, size.height - 26);
    if (plot.width <= 0 || plot.height <= 0) return;
    double sx(double v) =>
        plot.left + (v - scale.min) / (scale.max - scale.min) * plot.width;
    final band = plot.height / n;

    final grid = Paint()
      ..color = theme.gridColor
      ..strokeWidth = 1;
    for (final t in scale.ticks) {
      canvas.drawLine(Offset(sx(t), plot.top), Offset(sx(t), plot.bottom), grid);
      paintText(canvas, fmt(t), Offset(sx(t), plot.bottom + 6), theme.labelStyle,
          align: Alignment.topCenter);
    }
    canvas.drawLine(Offset(sx(0), plot.top), Offset(sx(0), plot.bottom),
        Paint()
          ..color = theme.axisColor
          ..strokeWidth = 1.2);
    for (var i = 0; i < n; i++) {
      paintText(canvas, w.categories[i],
          Offset(plot.left - (lo < 0 && w.showValueLabels && !w.stacked ? 36 : 6), plot.top + (i + .5) * band),
          theme.labelStyle,
          align: Alignment.centerRight, maxWidth: labelW + 2);
    }

    int? hover;
    final ptr = pointer;
    if (ptr != null && plot.contains(ptr)) {
      hover = ((ptr.dy - plot.top) / band).floor().clamp(0, n - 1).toInt();
      canvas.drawRect(Rect.fromLTWH(plot.left, plot.top + hover * band, plot.width, band),
          Paint()..color = theme.axisColor.faded(.12));
    }

    final m = w.series.length;
    final groupH = band * w.barWidthFactor;
    for (var i = 0; i < n; i++) {
      final cy = plot.top + (i + .5) * band;
      double pos = 0, neg = 0;
      for (var j = 0; j < m; j++) {
        final v = _v(w.series[j], i);
        double x0, x1, top, h;
        if (w.stacked) {
          h = groupH;
          top = cy - groupH / 2;
          if (v >= 0) {
            x0 = pos;
            pos += v;
            x1 = pos;
          } else {
            x0 = neg;
            neg += v;
            x1 = neg;
          }
        } else {
          h = groupH / m;
          top = cy - groupH / 2 + j * h;
          x0 = 0;
          x1 = v;
        }
        final a = sx(x0), b = sx(x0 + (x1 - x0) * progress);
        final rect = Rect.fromLTRB(math.min(a, b), top + 1, math.max(a, b), top + h - 1);
        final rad = w.stacked ? Radius.zero : Radius.circular(math.min(4.0, h / 2));
        final right = v >= 0;
        canvas.drawRRect(
            RRect.fromRectAndCorners(rect,
                topRight: right ? rad : Radius.zero,
                bottomRight: right ? rad : Radius.zero,
                topLeft: right ? Radius.zero : rad,
                bottomLeft: right ? Radius.zero : rad),
            Paint()..color = _c(j));
        if (w.showValueLabels && progress > .99) {
          if (w.stacked) {
            if (rect.width > 28 && rect.height > 12) {
              paintText(canvas, fmt(v), rect.center,
                  TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: contrastOn(_c(j))));
            }
          } else {
            paintText(canvas, fmt(v),
                Offset(right ? rect.right + 4 : rect.left - 4, rect.center.dy),
                theme.labelStyle,
                align: right ? Alignment.centerLeft : Alignment.centerRight);
          }
        }
      }
    }

    if (hover != null && ptr != null && progress >= 1) {
      paintTooltip(canvas, size, ptr, theme, title: w.categories[hover], rows: [
        for (var j = 0; j < m; j++)
          TooltipRow('${w.series[j].name}: ${fmt(_v(w.series[j], hover))}', color: _c(j))
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
