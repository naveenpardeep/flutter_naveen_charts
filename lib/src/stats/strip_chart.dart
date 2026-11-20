import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';
import '../core/stats.dart';

class StripGroup {
  const StripGroup(this.label, this.values, {this.color});
  final String label;
  final List<double> values;
  final Color? color;
}

enum StripLayout {
  /// Random horizontal scatter (seeded).
  jitter,

  /// Non-overlapping dot swarm.
  beeswarm,
}

/// Strip / beeswarm chart: every observation as a dot, grouped by category.
class StripChart extends StatelessWidget {
  const StripChart({
    super.key,
    required this.groups,
    this.layout = StripLayout.beeswarm,
    this.pointRadius = 4,
    this.showMedian = true,
    this.showMean = false,
    this.widthFactor = 0.8,
    this.seed = 5,
    this.yFormat,
    this.yAxisTitle,
    this.aspectRatio = 1.6,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<StripGroup> groups;
  final StripLayout layout;
  final double pointRadius;
  final bool showMedian;
  final bool showMean;
  final double widthFactor;
  final int seed;
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
        builder: (p, ptr) => _StripPainter(this, t, p, ptr));
  }
}

List<double> _swarm(List<double> ysPx, double r, double maxOff) {
  final order = List<int>.generate(ysPx.length, (i) => i)..sort((a, b) => ysPx[a].compareTo(ysPx[b]));
  final off = List<double>.filled(ysPx.length, 0);
  final placed = <int>[];
  final minD = 2 * r * .95;
  for (final i in order) {
    var best = 0.0;
    var found = false;
    for (var k = 0; k < 80; k++) {
      final cand = ((k + 1) ~/ 2) * r * .9 * (k.isOdd ? 1 : -1);
      if (cand.abs() > maxOff) break;
      var ok = true;
      for (final j in placed.reversed) {
        final dy = ysPx[i] - ysPx[j];
        if (dy > minD) break;
        final dx = cand - off[j];
        if (dx * dx + dy * dy < minD * minD) {
          ok = false;
          break;
        }
      }
      if (ok) {
        best = cand;
        found = true;
        break;
      }
    }
    off[i] = found ? best : (i.isEven ? maxOff : -maxOff);
    placed.add(i);
  }
  return off;
}

class _StripPainter extends CustomPainter {
  _StripPainter(this.w, this.theme, this.progress, this.pointer);
  final StripChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.groups.length;
    if (n == 0) return;
    var lo = double.infinity, hi = -double.infinity;
    for (final g in w.groups) {
      for (final v in g.values) {
        lo = math.min(lo, v);
        hi = math.max(hi, v);
      }
    }
    if (!lo.isFinite) return;
    final fmt = w.yFormat ?? formatNumber;
    final f = paintFrame(canvas, size, theme,
        xLo: 0, xHi: 0, yLo: lo, yHi: hi, xCats: [for (final g in w.groups) g.label], yFormat: w.yFormat, yTitle: w.yAxisTitle);
    if (f == null) return;
    final unit = f.plot.width / (f.xHi - f.xLo);
    final half = unit * w.widthFactor / 2;
    int? hg, hi2;
    var best = w.pointRadius + 5;
    final ptr = pointer;
    final dots = <Offset>[];
    for (var gi = 0; gi < n; gi++) {
      final g = w.groups[gi];
      final color = g.color ?? theme.colorAt(gi);
      final cx = f.sx(gi.toDouble());
      final ys = [for (final v in g.values) f.sy(v)];
      final offs = w.layout == StripLayout.beeswarm
          ? _swarm(ys, w.pointRadius, half)
          : () {
              final rnd = math.Random(w.seed + gi);
              return [for (var i = 0; i < ys.length; i++) (rnd.nextDouble() * 2 - 1) * half * .85];
            }();
      for (var i = 0; i < ys.length; i++) {
        final c = Offset(cx + offs[i], ys[i]);
        canvas.drawCircle(c, w.pointRadius * progress, Paint()..color = color.faded(.78));
        canvas.drawCircle(c, w.pointRadius * progress, Paint()
          ..color = theme.surface
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8);
        if (ptr != null && progress >= 1 && (c - ptr).distance < best) {
          best = (c - ptr).distance;
          hg = gi;
          hi2 = i;
          dots.add(c);
        }
      }
      if (g.values.isNotEmpty) {
        final s = sortedCopy(g.values);
        if (w.showMedian) {
          final y = f.sy(quantile(s, .5));
          canvas.drawLine(Offset(cx - half, y), Offset(cx + half, y), Paint()
            ..color = theme.textColor
            ..strokeWidth = 2.4);
        }
        if (w.showMean) {
          final y = f.sy(mean(g.values));
          canvas.drawCircle(Offset(cx, y), 5, Paint()..color = theme.textColor);
          canvas.drawCircle(Offset(cx, y), 2.5, Paint()..color = theme.surface);
        }
      }
    }
    if (hg != null && hi2 != null && ptr != null && dots.isNotEmpty) {
      canvas.drawCircle(dots.last, w.pointRadius + 3, Paint()
        ..color = theme.textColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6);
      final g = w.groups[hg];
      final s = sortedCopy(g.values);
      paintTooltip(canvas, size, ptr, theme, title: g.label, rows: [
        TooltipRow('Value: ${fmt(g.values[hi2])}', color: g.color ?? theme.colorAt(hg)),
        TooltipRow('n = ${g.values.length}, median ${fmt(quantile(s, .5))}'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
