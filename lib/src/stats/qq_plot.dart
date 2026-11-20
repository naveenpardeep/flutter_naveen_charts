import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';
import '../core/stats.dart';

/// Quantile-quantile plot of [sample] against a normal distribution, or against
/// a second sample when [reference] is given. Points on the line mean the
/// distributions match.
class QQPlot extends StatelessWidget {
  const QQPlot({
    super.key,
    required this.sample,
    this.reference,
    this.color,
    this.pointRadius = 3.5,
    this.showLine = true,
    this.xTitle,
    this.yTitle,
    this.aspectRatio = 1.2,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<double> sample;

  /// null = theoretical standard normal quantiles on the x axis.
  final List<double>? reference;
  final Color? color;
  final double pointRadius;

  /// Reference line through the first and third quartiles.
  final bool showLine;
  final String? xTitle, yTitle;
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
        builder: (p, ptr) => _QQPainter(this, t, p, ptr));
  }
}

class _QQPainter extends CustomPainter {
  _QQPainter(this.w, this.theme, this.progress, this.pointer);
  final QQPlot w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final s = sortedCopy(w.sample);
    final n = s.length;
    if (n < 2) return;
    final ref = w.reference == null ? null : sortedCopy(w.reference!);
    double theo(double p) => ref == null ? normInv(p) : quantile(ref, p);
    final tx = [for (var i = 0; i < n; i++) theo((i + .5) / n)];
    final xLo = tx.reduce(math.min), xHi = tx.reduce(math.max);
    final padX = (xHi - xLo) * .06 + 1e-9, padY = (s.last - s.first) * .06 + 1e-9;
    final f = paintFrame(canvas, size, theme,
        xLo: xLo - padX, xHi: xHi + padX, yLo: s.first - padY, yHi: s.last + padY, xGrid: true,
        xTitle: w.xTitle ?? (ref == null ? 'Theoretical quantiles (normal)' : 'Reference quantiles'),
        yTitle: w.yTitle ?? 'Sample quantiles');
    if (f == null) return;
    canvas.save();
    canvas.clipRect(f.plot.inflate(2));
    if (w.showLine) {
      final x1 = theo(.25), x3 = theo(.75), y1 = quantile(s, .25), y3 = quantile(s, .75);
      if (x3 != x1) {
        final slope = (y3 - y1) / (x3 - x1), icpt = y1 - slope * x1;
        canvas.drawLine(Offset(f.xLo.isFinite ? f.plot.left : 0, f.sy(icpt + slope * f.xLo)),
            Offset(f.plot.left + f.plot.width * progress, f.sy(icpt + slope * (f.xLo + (f.xHi - f.xLo) * progress))),
            Paint()
              ..color = theme.colorAt(2)
              ..strokeWidth = 1.8);
      }
    }
    final color = w.color ?? theme.colorAt(0);
    int? hover;
    final ptr = pointer;
    var best = w.pointRadius + 8;
    for (var i = 0; i < n; i++) {
      final c = Offset(f.sx(tx[i]), f.sy(s[i]));
      canvas.drawCircle(c, w.pointRadius * progress, Paint()..color = color.faded(.75));
      if (ptr != null && progress >= 1 && (c - ptr).distance < best) {
        best = (c - ptr).distance;
        hover = i;
      }
    }
    canvas.restore();
    if (hover != null && ptr != null) {
      final c = Offset(f.sx(tx[hover]), f.sy(s[hover]));
      canvas.drawCircle(c, w.pointRadius + 3, Paint()
        ..color = theme.textColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6);
      paintTooltip(canvas, size, ptr, theme, title: 'Quantile ${((hover + .5) / n * 100).toStringAsFixed(1)}%', rows: [
        TooltipRow('Theoretical: ${formatNumber(tx[hover])}', color: color),
        TooltipRow('Sample: ${formatNumber(s[hover])}'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
