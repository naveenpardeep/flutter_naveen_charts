import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';

class ViolinData {
  const ViolinData(this.label, this.values, {this.color});
  final String label;
  final List<double> values;
  final Color? color;
}

/// Violin plot: a mirrored kernel density estimate per group, with an inner
/// box (Q1-Q3) and median marker.
class ViolinPlot extends StatelessWidget {
  const ViolinPlot({
    super.key,
    required this.data,
    this.bandwidth,
    this.points = 64,
    this.showBox = true,
    this.showMedian = true,
    this.widthFactor = 0.85,
    this.yFormat,
    this.yAxisTitle,
    this.aspectRatio = 1.6,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<ViolinData> data;

  /// KDE bandwidth; null uses Silverman's rule per group.
  final double? bandwidth;
  final int points;
  final bool showBox;
  final bool showMedian;
  final double widthFactor;
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
        builder: (p, ptr) => _ViolinPainter(this, t, p, ptr),
      ),
    );
  }
}

class _V {
  _V(this.ys, this.dens, this.q1, this.med, this.q3, this.mean, this.n, this.h);
  final List<double> ys, dens;
  final double q1, med, q3, mean, h;
  final int n;
}

class _ViolinPainter extends CustomPainter {
  _ViolinPainter(this.w, this.theme, this.progress, this.pointer);
  final ViolinPlot w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  _V? _stats(List<double> raw) {
    if (raw.isEmpty) return null;
    final s = [...raw]..sort();
    final n = s.length;
    double q(double p) {
      final pos = (n - 1) * p;
      final lo = pos.floor(), hi = pos.ceil();
      return s[lo] + (s[hi] - s[lo]) * (pos - lo);
    }

    final mean = s.fold<double>(0, (a, b) => a + b) / n;
    final sd = math.sqrt(s.fold<double>(0, (a, b) => a + (b - mean) * (b - mean)) / math.max(1, n - 1));
    final iqr = q(.75) - q(.25);
    var h = w.bandwidth ?? 0.9 * math.min(sd, iqr / 1.34 > 0 ? iqr / 1.34 : sd) * math.pow(n, -0.2);
    if (!h.isFinite || h <= 0) h = 1;
    final lo = s.first - 1.5 * h, hi = s.last + 1.5 * h;
    final ys = [for (var k = 0; k < w.points; k++) lo + (hi - lo) * k / (w.points - 1)];
    final norm = 1 / (n * h * math.sqrt(2 * math.pi));
    final dens = [
      for (final y in ys)
        s.fold<double>(0, (a, v) {
              final z = (y - v) / h;
              return a + math.exp(-0.5 * z * z);
            }) *
            norm
    ];
    return _V(ys, dens, q(.25), q(.5), q(.75), mean, n, h);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final vs = [for (final d in w.data) _stats(d.values)];
    if (vs.every((v) => v == null)) return;
    var lo = double.infinity, hi = -double.infinity, gMax = 0.0;
    for (final v in vs) {
      if (v == null) continue;
      lo = math.min(lo, v.ys.first);
      hi = math.max(hi, v.ys.last);
      gMax = math.max(gMax, v.dens.reduce(math.max));
    }
    final scale = NiceScale.compute(lo, hi);
    final fmt = w.yFormat ?? formatNumber;
    final labelW = scale.ticks
        .map((t) => measureText(fmt(t), theme.labelStyle).width)
        .fold<double>(0, math.max);
    final plot = Rect.fromLTRB(labelW + 12 + (w.yAxisTitle != null ? 16 : 0), 10, size.width - 12, size.height - 28);
    if (plot.width <= 0 || plot.height <= 0) return;
    double sy(double v) => plot.bottom - (v - scale.min) / (scale.max - scale.min) * plot.height;
    final unit = plot.width / w.data.length;
    double cx(int i) => plot.left + (i + .5) * unit;
    final halfW = unit * w.widthFactor / 2;

    final grid = Paint()
      ..color = theme.gridColor
      ..strokeWidth = 1;
    for (final t in scale.ticks) {
      canvas.drawLine(Offset(plot.left, sy(t)), Offset(plot.right, sy(t)), grid);
      paintText(canvas, fmt(t), Offset(plot.left - 6, sy(t)), theme.labelStyle, align: Alignment.centerRight);
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
      hover = ((ptr.dx - plot.left) / unit).floor().clamp(0, w.data.length - 1).toInt();
      canvas.drawRect(Rect.fromLTWH(plot.left + hover * unit, plot.top, unit, plot.height),
          Paint()..color = theme.axisColor.faded(.12));
    }

    for (var i = 0; i < w.data.length; i++) {
      paintText(canvas, w.data[i].label, Offset(cx(i), plot.bottom + 6), theme.labelStyle,
          align: Alignment.topCenter, maxWidth: unit);
      final v = vs[i];
      if (v == null) continue;
      final color = w.data[i].color ?? theme.colorAt(i);
      final right = [for (var k = 0; k < v.ys.length; k++) Offset(cx(i) + v.dens[k] / gMax * halfW * progress, sy(v.ys[k]))];
      final left = [for (var k = v.ys.length - 1; k >= 0; k--) Offset(cx(i) - v.dens[k] / gMax * halfW * progress, sy(v.ys[k]))];
      final path = buildLinePath([...right, ...left], curved: true)..close();
      canvas.drawPath(path, Paint()..color = color.faded(.4));
      canvas.drawPath(path, Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6);
      if (w.showBox && progress > .5) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTRB(cx(i) - 4, sy(v.q3), cx(i) + 4, sy(v.q1)), const Radius.circular(2)),
            Paint()..color = color);
      }
      if (w.showMedian && progress > .5) {
        canvas.drawCircle(Offset(cx(i), sy(v.med)), 3.5, Paint()..color = theme.surface);
      }
    }
    if (hover != null && ptr != null && progress >= 1) {
      final v = vs[hover];
      if (v != null) {
        paintTooltip(canvas, size, ptr, theme, title: w.data[hover].label, rows: [
          TooltipRow('n = ${v.n}'),
          TooltipRow('Median ${fmt(v.med)}'),
          TooltipRow('Q1–Q3  ${fmt(v.q1)} – ${fmt(v.q3)}'),
          TooltipRow('Mean   ${fmt(v.mean)}'),
        ]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
