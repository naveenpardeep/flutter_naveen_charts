import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';

/// A delta step, or (with [isTotal]) a bar showing the running total.
class WaterfallStep {
  const WaterfallStep(this.label, this.value, {this.isTotal = false});
  final String label;
  final double value;
  final bool isTotal;
}

class WaterfallChart extends StatelessWidget {
  const WaterfallChart({
    super.key,
    required this.steps,
    this.positiveColor = const Color(0xFF43A047),
    this.negativeColor = const Color(0xFFE53935),
    this.totalColor = const Color(0xFF4E79A7),
    this.showConnectors = true,
    this.showValueLabels = true,
    this.valueFormat,
    this.aspectRatio = 1.6,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<WaterfallStep> steps;
  final Color positiveColor, negativeColor, totalColor;
  final bool showConnectors;
  final bool showValueLabels;
  final String Function(double)? valueFormat;
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
        builder: (p, ptr) => _WaterfallPainter(this, t, p, ptr),
      ),
    );
  }
}

class _WaterfallPainter extends CustomPainter {
  _WaterfallPainter(this.w, this.theme, this.progress, this.pointer);
  final WaterfallChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final steps = w.steps;
    if (steps.isEmpty) return;
    final starts = <double>[], ends = <double>[];
    var run = 0.0;
    for (final s in steps) {
      if (s.isTotal) {
        starts.add(0);
        ends.add(run);
      } else {
        starts.add(run);
        run += s.value;
        ends.add(run);
      }
    }
    var lo = 0.0, hi = 0.0;
    for (var i = 0; i < steps.length; i++) {
      lo = math.min(lo, math.min(starts[i], ends[i]));
      hi = math.max(hi, math.max(starts[i], ends[i]));
    }
    final scale = NiceScale.compute(lo, hi, includeZero: true);
    final fmt = w.valueFormat ?? formatNumber;
    final labelW = scale.ticks
        .map((t) => measureText(fmt(t), theme.labelStyle).width)
        .fold<double>(0, math.max);
    final plot = Rect.fromLTRB(labelW + 12, 16, size.width - 12, size.height - 28);
    if (plot.width <= 0 || plot.height <= 0) return;
    double sy(double v) =>
        plot.bottom - (v - scale.min) / (scale.max - scale.min) * plot.height;
    final unit = plot.width / steps.length;
    double cx(int i) => plot.left + (i + .5) * unit;
    final bw = unit * 0.6;

    final grid = Paint()
      ..color = theme.gridColor
      ..strokeWidth = 1;
    for (final t in scale.ticks) {
      canvas.drawLine(Offset(plot.left, sy(t)), Offset(plot.right, sy(t)), grid);
      paintText(canvas, fmt(t), Offset(plot.left - 6, sy(t)), theme.labelStyle,
          align: Alignment.centerRight);
    }
    canvas.drawLine(Offset(plot.left, sy(0)), Offset(plot.right, sy(0)),
        Paint()
          ..color = theme.axisColor
          ..strokeWidth = 1.2);

    int? hover;
    final ptr = pointer;
    if (ptr != null && plot.contains(ptr)) {
      hover = ((ptr.dx - plot.left) / unit).floor().clamp(0, steps.length - 1).toInt();
      canvas.drawRect(Rect.fromLTWH(plot.left + hover * unit, plot.top, unit, plot.height),
          Paint()..color = theme.axisColor.faded(.12));
    }

    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      final color = s.isTotal ? w.totalColor : (s.value >= 0 ? w.positiveColor : w.negativeColor);
      final a = sy(starts[i]);
      final b = sy(starts[i] + (ends[i] - starts[i]) * progress);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(cx(i) - bw / 2, math.min(a, b), cx(i) + bw / 2, math.max(a, b) + 0.5),
              const Radius.circular(3)),
          Paint()..color = color);
      if (w.showConnectors && i < steps.length - 1 && progress > .99) {
        _dash(canvas, Offset(cx(i) + bw / 2, sy(ends[i])), Offset(cx(i + 1) - bw / 2, sy(ends[i])));
      }
      if (w.showValueLabels && progress > .99) {
        final up = s.isTotal || s.value >= 0;
        final text = s.isTotal ? fmt(ends[i]) : '${s.value >= 0 ? '+' : ''}${fmt(s.value)}';
        paintText(canvas, text, Offset(cx(i), up ? math.min(a, b) - 3 : math.max(a, b) + 3),
            theme.labelStyle.copyWith(color: theme.textColor, fontWeight: FontWeight.w600),
            align: up ? Alignment.bottomCenter : Alignment.topCenter);
      }
      paintText(canvas, s.label, Offset(cx(i), plot.bottom + 6), theme.labelStyle,
          align: Alignment.topCenter, maxWidth: unit);
    }

    if (hover != null && ptr != null && progress >= 1) {
      final s = steps[hover];
      paintTooltip(canvas, size, ptr, theme, title: s.label, rows: [
        if (!s.isTotal) TooltipRow('Change: ${s.value >= 0 ? '+' : ''}${fmt(s.value)}'),
        TooltipRow('Running total: ${fmt(ends[hover])}'),
      ]);
    }
  }

  void _dash(Canvas c, Offset a, Offset b) {
    c.drawPath(
        dashPath(Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy), dash: 3, gap: 3),
        Paint()
          ..color = theme.axisColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
