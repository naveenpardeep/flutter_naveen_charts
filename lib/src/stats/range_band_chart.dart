import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/legend.dart';
import '../core/plot_frame.dart';

/// A line with a shaded min/max (or confidence) band. [low2]/[high2] add an
/// inner band (e.g. 50 % inside 95 %).
class RangeBandSeries {
  const RangeBandSeries({
    required this.name,
    required this.mid,
    required this.low,
    required this.high,
    this.low2,
    this.high2,
    this.color,
    this.curved = true,
  });
  final String name;
  final List<double> mid, low, high;
  final List<double>? low2, high2;
  final Color? color;
  final bool curved;
}

class RangeBandChart extends StatelessWidget {
  const RangeBandChart({
    super.key,
    required this.series,
    this.xLabels,
    this.lineWidth = 2.5,
    this.bandOpacity = 0.2,
    this.showLegend = true,
    this.yFormat,
    this.xTitle,
    this.yAxisTitle,
    this.aspectRatio = 1.6,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 1000),
  });
  final List<RangeBandSeries> series;
  final List<String>? xLabels;
  final double lineWidth;
  final double bandOpacity;
  final bool showLegend;
  final String Function(double)? yFormat;
  final String? xTitle, yAxisTitle;
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
      builder: (p, ptr) => _BandPainter(this, t, p, ptr),
    );
  }
}

class _BandPainter extends CustomPainter {
  _BandPainter(this.w, this.theme, this.progress, this.pointer);
  final RangeBandChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    if (w.series.isEmpty) return;
    final n = w.series.map((s) => s.mid.length).reduce(math.max);
    if (n == 0) return;
    var lo = double.infinity, hi = -double.infinity;
    for (final s in w.series) {
      for (final v in [...s.low, ...s.mid]) {
        lo = math.min(lo, v);
      }
      for (final v in [...s.high, ...s.mid]) {
        hi = math.max(hi, v);
      }
    }
    final fmt = w.yFormat ?? formatNumber;
    final f = paintFrame(canvas, size, theme,
        xLo: 0, xHi: n - 1.0, yLo: lo, yHi: hi,
        xCats: w.xLabels, catPadding: 0, yFormat: w.yFormat, xTitle: w.xTitle, yTitle: w.yAxisTitle);
    if (f == null) return;
    double at(List<double> l, int i) => i < l.length ? l[i] : l.last;

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(f.plot.left - 4, f.plot.top - 4, f.plot.left + f.plot.width * progress + 4, f.plot.bottom + 4));
    for (var si = 0; si < w.series.length; si++) {
      final s = w.series[si];
      final color = s.color ?? theme.colorAt(si);
      void band(List<double> l, List<double> h, double opacity) {
        final up = [for (var i = 0; i < n; i++) Offset(f.sx(i.toDouble()), f.sy(at(h, i)))];
        final lw = [for (var i = 0; i < n; i++) Offset(f.sx(i.toDouble()), f.sy(at(l, i)))];
        final path = buildLinePath(up, curved: s.curved);
        path.lineTo(lw.last.dx, lw.last.dy);
        path.extendWithPath(buildLinePath(lw.reversed.toList(), curved: s.curved), Offset.zero);
        path.close();
        canvas.drawPath(path, Paint()..color = color.faded(opacity));
      }

      band(s.low, s.high, w.bandOpacity);
      if (s.low2 != null && s.high2 != null) band(s.low2!, s.high2!, w.bandOpacity * 1.6);
      final mid = [for (var i = 0; i < n; i++) Offset(f.sx(i.toDouble()), f.sy(at(s.mid, i)))];
      canvas.drawPath(buildLinePath(mid, curved: s.curved), Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w.lineWidth
        ..strokeCap = StrokeCap.round);
    }
    canvas.restore();

    final ptr = pointer;
    if (ptr != null && progress >= 1 && f.plot.inflate(8).contains(ptr)) {
      final i = f.xAt(ptr.dx).round().clamp(0, n - 1).toInt();
      canvas.drawLine(Offset(f.sx(i.toDouble()), f.plot.top), Offset(f.sx(i.toDouble()), f.plot.bottom),
          Paint()
            ..color = theme.axisColor.faded(.6)
            ..strokeWidth = 1);
      paintTooltip(canvas, size, Offset(f.sx(i.toDouble()), ptr.dy), theme,
          title: (w.xLabels != null && i < w.xLabels!.length) ? w.xLabels![i] : formatNumber(i.toDouble()),
          rows: [
            for (var si = 0; si < w.series.length; si++)
              TooltipRow(
                  '${w.series[si].name}: ${fmt(at(w.series[si].mid, i))}  [${fmt(at(w.series[si].low, i))} – ${fmt(at(w.series[si].high, i))}]',
                  color: w.series[si].color ?? theme.colorAt(si)),
          ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
