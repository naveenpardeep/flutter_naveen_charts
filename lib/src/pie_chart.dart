import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';
import 'core/legend.dart';

class PieSlice {
  const PieSlice(this.label, this.value, {this.color});
  final String label;
  final double value;
  final Color? color;
}

/// Pie chart; set [donut] for a ring with optional [centerText].
class PieChart extends StatelessWidget {
  const PieChart({
    super.key,
    required this.slices,
    this.donut = false,
    this.holeRatio = 0.6,
    this.centerText,
    this.showPercent = true,
    this.showLegend = true,
    this.aspectRatio = 1.4,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<PieSlice> slices;
  final bool donut;
  final double holeRatio;
  final String? centerText;
  final bool showPercent;
  final bool showLegend;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AspectRatio(
        aspectRatio: aspectRatio,
        child: ChartCanvas(
          duration: animationDuration,
          builder: (p, ptr) => _PiePainter(slices, donut ? holeRatio : 0,
              centerText, showPercent, t, p, ptr),
        ),
      ),
      if (showLegend)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ChartLegend(theme: t, items: [
            for (var i = 0; i < slices.length; i++)
              LegendItem(slices[i].label, slices[i].color ?? t.colorAt(i)),
          ]),
        ),
    ]);
  }
}

/// Shortcut for `PieChart(donut: true)`.
class DonutChart extends StatelessWidget {
  const DonutChart(
      {super.key, required this.slices, this.centerText, this.theme});
  final List<PieSlice> slices;
  final String? centerText;
  final ChartTheme? theme;
  @override
  Widget build(BuildContext context) =>
      PieChart(slices: slices, donut: true, centerText: centerText, theme: theme);
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.slices, this.hole, this.centerText, this.showPercent,
      this.theme, this.progress, this.pointer);
  final List<PieSlice> slices;
  final double hole;
  final String? centerText;
  final bool showPercent;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;
  static const double _start = -math.pi / 2;

  Path _sector(Offset c, double r0, double r1, double a0, double sweep) {
    final p = Path()..arcTo(Rect.fromCircle(center: c, radius: r1), a0, sweep, true);
    if (r0 > 0) {
      p.arcTo(Rect.fromCircle(center: c, radius: r0), a0 + sweep, -sweep, false);
    } else {
      p.lineTo(c.dx, c.dy);
    }
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (a, s) => a + math.max(0, s.value));
    if (total <= 0) return;
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 12;
    if (r <= 0) return;
    final r0 = r * hole;

    int? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      final d = ptr - c;
      if (d.distance <= r && d.distance >= r0) {
        final a = (math.atan2(d.dy, d.dx) - _start) % (2 * math.pi);
        double acc = 0;
        for (var i = 0; i < slices.length; i++) {
          final full = math.max(0, slices[i].value) / total * 2 * math.pi;
          if (a >= acc && a < acc + full) {
            hover = i;
            break;
          }
          acc += full;
        }
      }
    }

    double a0 = _start;
    final gap = slices.length > 1 ? 0.02 : 0.0;
    for (var i = 0; i < slices.length; i++) {
      final v = math.max(0.0, slices[i].value);
      final full = v / total * 2 * math.pi;
      final sweep = full * progress;
      final mid = a0 + sweep / 2;
      final shift = hover == i ? Offset.fromDirection(mid, 7) : Offset.zero;
      final color = slices[i].color ?? theme.colorAt(i);
      canvas.drawPath(
          _sector(c + shift, r0, r, a0 + gap / 2, math.max(0.0, sweep - gap)),
          Paint()..color = color);
      if (showPercent && progress > 0.99 && full > 0.3) {
        paintText(
            canvas,
            '${(v / total * 100).round()}%',
            c + shift + Offset.fromDirection(mid, (r0 + r) / 2),
            const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold));
      }
      a0 += sweep;
    }

    if (r0 > 0 && centerText != null) {
      paintText(canvas, centerText!, c,
          TextStyle(color: theme.textColor, fontSize: 20, fontWeight: FontWeight.bold),
          maxWidth: r0 * 1.8);
    }
    if (hover != null && ptr != null) {
      final s = slices[hover];
      paintTooltip(canvas, size, ptr, theme, rows: [
        TooltipRow(
            '${s.label}: ${formatNumber(s.value)} (${(s.value / total * 100).toStringAsFixed(1)}%)',
            color: s.color ?? theme.colorAt(hover))
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
