import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'cartesian/models.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';
import 'core/legend.dart';

/// Stacked areas; set [percent] for a 100% stacked chart.
/// Series values are taken by position (use `AreaSeries.fromValues`).
class StackedAreaChart extends StatelessWidget {
  const StackedAreaChart({
    super.key,
    required this.series,
    this.xLabels,
    this.percent = false,
    this.curved = true,
    this.showLegend = true,
    this.yFormat,
    this.aspectRatio = 1.6,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<AreaSeries> series;
  final List<String>? xLabels;
  final bool percent;
  final bool curved;
  final bool showLegend;
  final String Function(double)? yFormat;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
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
          builder: (p, ptr) => _StackedPainter(this, t, p, ptr),
        ),
      ),
    ]);
  }
}

class _StackedPainter extends CustomPainter {
  _StackedPainter(this.w, this.theme, this.progress, this.pointer);
  final StackedAreaChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final m = w.series.length;
    if (m == 0) return;
    final n = w.series.map((s) => s.points.length).reduce(math.max);
    if (n == 0) return;
    double raw(int j, int i) =>
        i < w.series[j].points.length ? math.max(0.0, w.series[j].points[i].y) : 0;
    final totals = [for (var i = 0; i < n; i++) [for (var j = 0; j < m; j++) raw(j, i)].fold<double>(0, (a, b) => a + b)];
    double val(int j, int i) =>
        w.percent ? (totals[i] == 0 ? 0 : raw(j, i) / totals[i] * 100) : raw(j, i);
    final cum = List.generate(m, (_) => List<double>.filled(n, 0));
    for (var i = 0; i < n; i++) {
      var acc = 0.0;
      for (var j = 0; j < m; j++) {
        acc += val(j, i);
        cum[j][i] = acc;
      }
    }
    final top = w.percent ? 100.0 : totals.reduce(math.max);
    final scale = NiceScale.compute(0, top <= 0 ? 1 : top, includeZero: true);
    final fmt = w.yFormat ?? (w.percent ? (double v) => '${formatNumber(v)}%' : formatNumber);
    final labelW = scale.ticks
        .map((t) => measureText(fmt(t), theme.labelStyle).width)
        .fold<double>(0, math.max);
    final plot = Rect.fromLTRB(labelW + 12, 10, size.width - 14, size.height - 28);
    if (plot.width <= 0 || plot.height <= 0) return;
    double sx(int i) => plot.left + (n == 1 ? .5 : i / (n - 1)) * plot.width;
    double sy(double v) =>
        plot.bottom - (v - scale.min) / (scale.max - scale.min) * plot.height;

    final grid = Paint()
      ..color = theme.gridColor
      ..strokeWidth = 1;
    for (final t in scale.ticks) {
      canvas.drawLine(Offset(plot.left, sy(t)), Offset(plot.right, sy(t)), grid);
      paintText(canvas, fmt(t), Offset(plot.left - 6, sy(t)), theme.labelStyle,
          align: Alignment.centerRight);
    }
    if (w.xLabels != null) {
      final maxW = w.xLabels!
          .map((l) => measureText(l, theme.labelStyle).width)
          .fold<double>(0, math.max);
      final unit = plot.width / math.max(1, n - 1);
      final every = math.max(1, ((maxW + 8) / unit).ceil());
      for (var i = 0; i < n && i < w.xLabels!.length; i += every) {
        paintText(canvas, w.xLabels![i], Offset(sx(i), plot.bottom + 6), theme.labelStyle,
            align: Alignment.topCenter);
      }
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, plot.left + plot.width * progress + 2, size.height));
    for (var j = 0; j < m; j++) {
      final upper = [for (var i = 0; i < n; i++) Offset(sx(i), sy(cum[j][i]))];
      final lower = [for (var i = 0; i < n; i++) Offset(sx(i), sy(j == 0 ? 0 : cum[j - 1][i]))];
      final path = buildLinePath(upper, curved: w.curved);
      path.lineTo(lower.last.dx, lower.last.dy);
      path.extendWithPath(buildLinePath(lower.reversed.toList(), curved: w.curved), Offset.zero);
      path.close();
      final color = w.series[j].color ?? theme.colorAt(j);
      canvas.drawPath(path, Paint()..color = color.faded(.8));
      canvas.drawPath(
          buildLinePath(upper, curved: w.curved),
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
    canvas.restore();

    final ptr = pointer;
    if (ptr != null && progress >= 1 && plot.inflate(8).contains(ptr)) {
      var bi = 0;
      for (var i = 0; i < n; i++) {
        if ((sx(i) - ptr.dx).abs() < (sx(bi) - ptr.dx).abs()) bi = i;
      }
      canvas.drawLine(Offset(sx(bi), plot.top), Offset(sx(bi), plot.bottom),
          Paint()
            ..color = theme.textColor.faded(.5)
            ..strokeWidth = 1);
      paintTooltip(canvas, size, Offset(sx(bi), ptr.dy), theme,
          title: (w.xLabels != null && bi < w.xLabels!.length) ? w.xLabels![bi] : null,
          rows: [
            for (var j = m - 1; j >= 0; j--)
              TooltipRow(
                  '${w.series[j].name}: ${formatNumber(raw(j, bi))}${w.percent ? ' (${val(j, bi).toStringAsFixed(0)}%)' : ''}',
                  color: w.series[j].color ?? theme.colorAt(j)),
            TooltipRow('Total: ${formatNumber(totals[bi])}'),
          ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
