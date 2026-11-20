import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';

class BumpSeries {
  const BumpSeries(this.name, this.values, {this.color});
  final String name;

  /// One value per period (scores, or ranks when `valuesAreRanks`).
  final List<double> values;
  final Color? color;
}

/// Bump chart: rank of each series over time.
class BumpChart extends StatelessWidget {
  const BumpChart({
    super.key,
    required this.periods,
    required this.series,
    this.valuesAreRanks = false,
    this.markerRadius = 11,
    this.lineWidth = 4,
    this.aspectRatio = 1.5,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 1000),
  });
  final List<String> periods;
  final List<BumpSeries> series;

  /// false: higher value = better rank (1 = best). true: values already are ranks.
  final bool valuesAreRanks;
  final double markerRadius;
  final double lineWidth;
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
        builder: (p, ptr) => _BumpPainter(this, t, p, ptr));
  }
}

class _BumpPainter extends CustomPainter {
  _BumpPainter(this.w, this.theme, this.progress, this.pointer);
  final BumpChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.series.length, np = w.periods.length;
    if (n == 0 || np == 0) return;
    double val(int s, int p) => p < w.series[s].values.length ? w.series[s].values[p] : 0;
    final ranks = List.generate(n, (_) => List<double>.filled(np, 0));
    for (var p = 0; p < np; p++) {
      for (var s = 0; s < n; s++) {
        if (w.valuesAreRanks) {
          ranks[s][p] = val(s, p);
        } else {
          var r = 1;
          for (var o = 0; o < n; o++) {
            if (val(o, p) > val(s, p) || (val(o, p) == val(s, p) && o < s)) r++;
          }
          ranks[s][p] = r.toDouble();
        }
      }
    }
    final names = [for (final s in w.series) s.name];
    final maxName = names.map((s) => measureText(s, theme.labelStyle).width).fold<double>(0, math.max);
    final plot = Rect.fromLTRB(maxName + 22 + w.markerRadius, 16 + w.markerRadius, size.width - maxName - 22 - w.markerRadius, size.height - 34);
    if (plot.width <= 20 || plot.height <= 20) return;
    double sx(int p) => np == 1 ? plot.center.dx : plot.left + p / (np - 1) * plot.width;
    final maxRank = ranks.expand((r) => r).reduce(math.max);
    double sy(double r) => maxRank <= 1 ? plot.center.dy : plot.top + (r - 1) / (maxRank - 1) * plot.height;

    for (var p = 0; p < np; p++) {
      paintText(canvas, w.periods[p], Offset(sx(p), plot.bottom + 12), theme.labelStyle, align: Alignment.topCenter);
      canvas.drawLine(Offset(sx(p), plot.top - 6), Offset(sx(p), plot.bottom + 6),
          Paint()
            ..color = theme.gridColor
            ..strokeWidth = 1);
    }
    int? hs, hp;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      var best = w.markerRadius + 6;
      for (var s = 0; s < n; s++) {
        for (var p = 0; p < np; p++) {
          final d = (Offset(sx(p), sy(ranks[s][p])) - ptr).distance;
          if (d < best) {
            best = d;
            hs = s;
            hp = p;
          }
        }
      }
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, plot.left + plot.width * progress + w.markerRadius + 2, size.height));
    for (var s = 0; s < n; s++) {
      final color = w.series[s].color ?? theme.colorAt(s);
      final fade = hs == null || hs == s ? 1.0 : .2;
      final path = Path()..moveTo(sx(0), sy(ranks[s][0]));
      for (var p = 1; p < np; p++) {
        final mx = (sx(p - 1) + sx(p)) / 2;
        path.cubicTo(mx, sy(ranks[s][p - 1]), mx, sy(ranks[s][p]), sx(p), sy(ranks[s][p]));
      }
      canvas.drawPath(path, Paint()
        ..color = color.faded(fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = hs == s ? w.lineWidth + 2 : w.lineWidth
        ..strokeCap = StrokeCap.round);
      for (var p = 0; p < np; p++) {
        final c = Offset(sx(p), sy(ranks[s][p]));
        canvas.drawCircle(c, w.markerRadius, Paint()..color = color.faded(fade));
        if (progress > .99) {
          paintText(canvas, ranks[s][p].round().toString(), c,
              TextStyle(color: contrastOn(color), fontSize: 10, fontWeight: FontWeight.bold));
        }
      }
    }
    canvas.restore();
    for (var s = 0; s < n; s++) {
      final fade = hs == null || hs == s ? 1.0 : .3;
      final st = theme.labelStyle.copyWith(color: theme.textColor.faded(fade), fontWeight: FontWeight.w600);
      paintText(canvas, names[s], Offset(sx(0) - w.markerRadius - 6, sy(ranks[s][0])), st, align: Alignment.centerRight);
      paintText(canvas, names[s], Offset(sx(np - 1) + w.markerRadius + 6, sy(ranks[s][np - 1])), st, align: Alignment.centerLeft);
    }
    if (hs != null && hp != null && ptr != null) {
      paintTooltip(canvas, size, ptr, theme, title: names[hs], rows: [
        TooltipRow('${w.periods[hp]}: rank ${ranks[hs][hp].round()}', color: w.series[hs].color ?? theme.colorAt(hs)),
        if (!w.valuesAreRanks) TooltipRow('Value: ${formatNumber(val(hs, hp))}'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
