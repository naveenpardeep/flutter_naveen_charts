import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';
import '../core/stats.dart';

/// One forecast interval: [lower]/[upper] hold one value per forecast step.
class FanBand {
  const FanBand(this.label, this.lower, this.upper);
  final String label;
  final List<double> lower, upper;
}

/// Fan chart: history followed by a forecast whose uncertainty widens into
/// nested bands (outermost band first).
class FanChart extends StatelessWidget {
  const FanChart({
    super.key,
    required this.history,
    required this.median,
    required this.bands,
    this.xLabels,
    this.historyColor,
    this.forecastColor,
    this.bandOpacity = 0.14,
    this.showMedian = true,
    this.showNowLine = true,
    this.yFormat,
    this.yAxisTitle,
    this.aspectRatio = 1.7,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 1000),
  });

  /// Builds symmetric bands from a per-step standard deviation [sigma].
  /// [levels] are coverage probabilities such as 0.95, 0.8, 0.5.
  factory FanChart.fromSigma({
    Key? key,
    required List<double> history,
    required List<double> median,
    required List<double> sigma,
    List<double> levels = const [0.95, 0.8, 0.5],
    List<String>? xLabels,
    Color? historyColor,
    Color? forecastColor,
    String Function(double)? yFormat,
    String? yAxisTitle,
    double aspectRatio = 1.7,
    ChartTheme? theme,
  }) {
    final sorted = [...levels]..sort((a, b) => b.compareTo(a));
    return FanChart(
      key: key,
      history: history,
      median: median,
      xLabels: xLabels,
      historyColor: historyColor,
      forecastColor: forecastColor,
      yFormat: yFormat,
      yAxisTitle: yAxisTitle,
      aspectRatio: aspectRatio,
      theme: theme,
      bands: [
        for (final lv in sorted)
          FanBand(
            '${(lv * 100).round()}%',
            [for (var i = 0; i < median.length; i++) median[i] - normInv(.5 + lv / 2) * (i < sigma.length ? sigma[i] : sigma.last)],
            [for (var i = 0; i < median.length; i++) median[i] + normInv(.5 + lv / 2) * (i < sigma.length ? sigma[i] : sigma.last)],
          ),
      ],
    );
  }

  final List<double> history;

  /// Forecast median / central path (one value per forecast step).
  final List<double> median;
  final List<FanBand> bands;

  /// Labels for history + forecast steps (optional).
  final List<String>? xLabels;
  final Color? historyColor, forecastColor;
  final double bandOpacity;
  final bool showMedian;
  final bool showNowLine;
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
        builder: (p, ptr) => _FanPainter(this, t, p, ptr));
  }
}

class _FanPainter extends CustomPainter {
  _FanPainter(this.w, this.theme, this.progress, this.pointer);
  final FanChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final h = w.history.length, m = w.median.length;
    if (h == 0) return;
    final total = h + m;
    var lo = w.history.reduce(math.min), hi = w.history.reduce(math.max);
    for (final v in w.median) {
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }
    for (final b in w.bands) {
      for (final v in [...b.lower, ...b.upper]) {
        lo = math.min(lo, v);
        hi = math.max(hi, v);
      }
    }
    final fmt = w.yFormat ?? formatNumber;
    final f = paintFrame(canvas, size, theme,
        xLo: 0, xHi: total - 1.0, yLo: lo, yHi: hi, xCats: w.xLabels != null && w.xLabels!.length >= total ? w.xLabels!.sublist(0, total) : null,
        catPadding: 0, yFormat: w.yFormat, yTitle: w.yAxisTitle);
    if (f == null) return;
    final hc = w.historyColor ?? theme.colorAt(0), fc = w.forecastColor ?? theme.colorAt(1);
    // forecast arrays start at the last history point, so the fan opens from "now"
    final lastH = w.history.last;
    double at(List<double> l, int i) => i < l.length ? l[i] : l.last;
    Offset pt(int idx, double v) => Offset(f.sx(idx.toDouble()), f.sy(v));

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(f.plot.left - 4, f.plot.top - 4, f.plot.left + f.plot.width * progress + 4, f.plot.bottom + 4));
    for (var k = 0; k < w.bands.length; k++) {
      final b = w.bands[k];
      if (m == 0) break;
      final up = [pt(h - 1, lastH), for (var i = 0; i < m; i++) pt(h + i, at(b.upper, i))];
      final lw = [pt(h - 1, lastH), for (var i = 0; i < m; i++) pt(h + i, at(b.lower, i))];
      final path = buildLinePath(up, curved: true);
      path.lineTo(lw.last.dx, lw.last.dy);
      path.extendWithPath(buildLinePath(lw.reversed.toList(), curved: true), Offset.zero);
      path.close();
      canvas.drawPath(path, Paint()..color = fc.faded(w.bandOpacity + k * w.bandOpacity * .7));
    }
    if (w.showMedian && m > 0) {
      final pts = [pt(h - 1, lastH), for (var i = 0; i < m; i++) pt(h + i, w.median[i])];
      canvas.drawPath(dashPath(buildLinePath(pts, curved: true), dash: 6, gap: 4), Paint()
        ..color = fc
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2);
    }
    canvas.drawPath(buildLinePath([for (var i = 0; i < h; i++) pt(i, w.history[i])], curved: true), Paint()
      ..color = hc
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round);
    canvas.restore();

    if (w.showNowLine && m > 0) {
      final x = f.sx(h - 1.0);
      canvas.drawPath(dashPath(Path()..moveTo(x, f.plot.top)..lineTo(x, f.plot.bottom), dash: 3, gap: 3), Paint()
        ..color = theme.axisColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
      paintText(canvas, 'Forecast →', Offset(x + 4, f.plot.top + 2), theme.labelStyle.copyWith(fontWeight: FontWeight.w600), align: Alignment.topLeft);
    }

    final ptr = pointer;
    if (ptr != null && progress >= 1 && f.plot.contains(ptr)) {
      final i = f.xAt(ptr.dx).round().clamp(0, total - 1).toInt();
      canvas.drawLine(Offset(f.sx(i.toDouble()), f.plot.top), Offset(f.sx(i.toDouble()), f.plot.bottom), Paint()
        ..color = theme.axisColor.faded(.7)
        ..strokeWidth = 1);
      final title = (w.xLabels != null && i < w.xLabels!.length) ? w.xLabels![i] : 'Step ${i + 1}';
      if (i < h) {
        paintTooltip(canvas, size, ptr, theme, title: title, rows: [TooltipRow('Actual: ${fmt(w.history[i])}', color: hc)]);
      } else {
        final j = i - h;
        paintTooltip(canvas, size, ptr, theme, title: title, rows: [
          TooltipRow('Median: ${fmt(w.median[j])}', color: fc),
          for (final b in w.bands) TooltipRow('${b.label}: ${fmt(at(b.lower, j))} – ${fmt(at(b.upper, j))}'),
        ]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
