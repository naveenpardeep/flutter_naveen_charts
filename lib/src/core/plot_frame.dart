import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'chart_canvas.dart';
import 'chart_theme.dart';
import 'chart_utils.dart';
import 'legend.dart';

/// Geometry of a drawn x/y frame (see [paintFrame]).
class PlotFrame {
  PlotFrame(this.plot, this.xLo, this.xHi, this.y);
  final Rect plot;
  final double xLo, xHi;
  final NiceScale y;
  double sx(double x) => plot.left + (x - xLo) / (xHi - xLo) * plot.width;
  double sy(double v) => plot.bottom - (v - y.min) / (y.max - y.min) * plot.height;
  double xAt(double px) => xLo + (px - plot.left) / plot.width * (xHi - xLo);
  double yAt(double py) => y.min + (plot.bottom - py) / plot.height * (y.max - y.min);
  int catAt(Offset p, int n) => xAt(p.dx).round().clamp(0, n - 1).toInt();
}

/// Paints grid, tick labels and axis titles, and returns the geometry.
/// With [xCats] the x axis is categorical (positions 0..n-1).
PlotFrame? paintFrame(
  Canvas canvas,
  Size size,
  ChartTheme theme, {
  required double xLo,
  required double xHi,
  required double yLo,
  required double yHi,
  List<String>? xCats,
  double catPadding = 0.5,
  bool includeZero = false,
  String Function(double)? yFormat,
  String Function(double)? xFormat,
  String? xTitle,
  String? yTitle,
  bool xGrid = false,
  bool yGrid = true,
  double rightPad = 12,
  double topPad = 10,
}) {
  final ys = NiceScale.compute(yLo, yHi, includeZero: includeZero);
  final fy = yFormat ?? formatNumber;
  final labelW = ys.ticks
      .map((t) => measureText(fy(t), theme.labelStyle).width)
      .fold<double>(0, math.max);
  final plot = Rect.fromLTRB(labelW + 12 + (yTitle != null ? 16 : 0), topPad,
      size.width - rightPad, size.height - 28 - (xTitle != null ? 16 : 0));
  if (plot.width <= 20 || plot.height <= 20) return null;
  var x0 = xLo, x1 = xHi;
  if (xCats != null) {
    final pad = (catPadding == 0 && xCats.length == 1) ? 0.5 : catPadding;
    x0 = -pad;
    x1 = xCats.length - 1 + pad;
  }
  if (x1 - x0 < 1e-12) {
    x0 -= 1;
    x1 += 1;
  }
  final f = PlotFrame(plot, x0, x1, ys);
  final grid = Paint()
    ..color = theme.gridColor
    ..strokeWidth = 1;
  for (final t in ys.ticks) {
    if (yGrid) canvas.drawLine(Offset(plot.left, f.sy(t)), Offset(plot.right, f.sy(t)), grid);
    paintText(canvas, fy(t), Offset(plot.left - 6, f.sy(t)), theme.labelStyle, align: Alignment.centerRight);
  }
  final axis = Paint()
    ..color = theme.axisColor
    ..strokeWidth = 1.2;
  canvas.drawLine(Offset(plot.left, plot.bottom), Offset(plot.right, plot.bottom), axis);
  if (ys.min < 0 && ys.max > 0) {
    canvas.drawLine(Offset(plot.left, f.sy(0)), Offset(plot.right, f.sy(0)), axis);
  }
  if (xCats != null) {
    final n = xCats.length;
    final maxW = xCats.map((l) => measureText(l, theme.labelStyle).width).fold<double>(0, math.max);
    final unit = plot.width / (x1 - x0);
    final every = math.max(1, ((maxW + 8) / unit).ceil());
    for (var i = 0; i < n; i += every) {
      if (xGrid) canvas.drawLine(Offset(f.sx(i.toDouble()), plot.top), Offset(f.sx(i.toDouble()), plot.bottom), grid);
      paintText(canvas, xCats[i], Offset(f.sx(i.toDouble()), plot.bottom + 6), theme.labelStyle,
          align: Alignment.topCenter, maxWidth: unit * every);
    }
  } else {
    final fx = xFormat ?? formatNumber;
    for (final t in NiceScale.compute(x0, x1, maxTicks: 6).ticks) {
      if (t < x0 - 1e-9 || t > x1 + 1e-9) continue;
      if (xGrid) canvas.drawLine(Offset(f.sx(t), plot.top), Offset(f.sx(t), plot.bottom), grid);
      paintText(canvas, fx(t), Offset(f.sx(t), plot.bottom + 6), theme.labelStyle, align: Alignment.topCenter);
    }
  }
  final ts = theme.labelStyle.copyWith(color: theme.textColor, fontWeight: FontWeight.w600);
  if (xTitle != null) {
    paintText(canvas, xTitle, Offset(plot.center.dx, size.height - 2), ts, align: Alignment.bottomCenter);
  }
  if (yTitle != null) {
    canvas.save();
    canvas.translate(8, plot.center.dy);
    canvas.rotate(-math.pi / 2);
    paintText(canvas, yTitle, Offset.zero, ts);
    canvas.restore();
  }
  return f;
}

/// Geometry for charts with categories down the y axis and numbers along x.
class HFrame {
  HFrame(this.plot, this.x, this.n);
  final Rect plot;
  final NiceScale x;
  final int n;
  double sx(double v) => plot.left + (v - x.min) / (x.max - x.min) * plot.width;
  double get band => plot.height / n;
  double cy(int i) => plot.top + (i + .5) * band;
  int rowAt(Offset p) => ((p.dy - plot.top) / band).floor().clamp(0, n - 1).toInt();
}

HFrame? paintHFrame(Canvas canvas, Size size, ChartTheme theme,
    {required List<String> cats,
    required double lo,
    required double hi,
    bool includeZero = false,
    String Function(double)? xFormat,
    String? xTitle}) {
  final n = cats.length;
  if (n == 0) return null;
  final xs = NiceScale.compute(lo, hi, includeZero: includeZero);
  final fx = xFormat ?? formatNumber;
  final labelW = cats.map((l) => measureText(l, theme.labelStyle).width).fold<double>(0, math.max);
  final plot = Rect.fromLTRB(labelW + 14, 8, size.width - 16, size.height - 26 - (xTitle != null ? 16 : 0));
  if (plot.width <= 20 || plot.height <= 20) return null;
  final f = HFrame(plot, xs, n);
  final grid = Paint()
    ..color = theme.gridColor
    ..strokeWidth = 1;
  for (final t in xs.ticks) {
    canvas.drawLine(Offset(f.sx(t), plot.top), Offset(f.sx(t), plot.bottom), grid);
    paintText(canvas, fx(t), Offset(f.sx(t), plot.bottom + 6), theme.labelStyle, align: Alignment.topCenter);
  }
  for (var i = 0; i < n; i++) {
    paintText(canvas, cats[i], Offset(plot.left - 8, f.cy(i)), theme.labelStyle.copyWith(color: theme.textColor),
        align: Alignment.centerRight, maxWidth: labelW + 2);
  }
  if (xTitle != null) {
    paintText(canvas, xTitle, Offset(plot.center.dx, size.height - 2),
        theme.labelStyle.copyWith(color: theme.textColor, fontWeight: FontWeight.w600),
        align: Alignment.bottomCenter);
  }
  return f;
}

/// Distance from [p] to the segment [a]-[b].
double distToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 == 0) return (p - a).distance;
  final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(0.0, 1.0).toDouble();
  return (p - (a + ab * t)).distance;
}

/// Chart widget scaffold: optional legend above an animated, interactive canvas.
Widget chartShell({
  required ChartTheme theme,
  required double aspectRatio,
  required Duration duration,
  required PainterBuilder builder,
  List<LegendItem>? legend,
  bool interactive = true,
}) {
  return Column(mainAxisSize: MainAxisSize.min, children: [
    if (legend != null && legend.length > 1)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ChartLegend(theme: theme, items: legend),
      ),
    AspectRatio(
      aspectRatio: aspectRatio,
      child: ChartCanvas(duration: duration, interactive: interactive, builder: builder),
    ),
  ]);
}

/// Canvas without an aspect ratio, for charts that size themselves (e.g. by row count).
Widget chartShellBox(ChartTheme theme, Duration duration, PainterBuilder builder) =>
    ChartCanvas(duration: duration, builder: builder);
