import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';

class Candle {
  const Candle({
    required this.label,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });
  final String label;
  final double open, high, low, close;
}

/// OHLC candlestick chart.
class CandlestickChart extends StatelessWidget {
  const CandlestickChart({
    super.key,
    required this.candles,
    this.upColor = const Color(0xFF26A69A),
    this.downColor = const Color(0xFFEF5350),
    this.aspectRatio = 1.6,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<Candle> candles;
  final Color upColor;
  final Color downColor;
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
        builder: (p, ptr) => _CandlePainter(this, t, p, ptr),
      ),
    );
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter(this.w, this.theme, this.progress, this.pointer);
  final CandlestickChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final cs = w.candles;
    if (cs.isEmpty) return;
    final lo = cs.map((c) => c.low).reduce(math.min);
    final hi = cs.map((c) => c.high).reduce(math.max);
    final scale = NiceScale.compute(lo, hi);
    final ticks = scale.ticks;
    final labelW = ticks
        .map((t) => measureText(formatNumber(t), theme.labelStyle).width)
        .fold<double>(0, math.max);
    final plot = Rect.fromLTRB(labelW + 12, 10, size.width - 12, size.height - 28);
    if (plot.width <= 0 || plot.height <= 0) return;
    double sy(double v) =>
        plot.bottom - (v - scale.min) / (scale.max - scale.min) * plot.height;
    final unit = plot.width / cs.length;
    double cx(int i) => plot.left + (i + .5) * unit;

    final grid = Paint()
      ..color = theme.gridColor
      ..strokeWidth = 1;
    for (final t in ticks) {
      canvas.drawLine(Offset(plot.left, sy(t)), Offset(plot.right, sy(t)), grid);
      paintText(canvas, formatNumber(t), Offset(plot.left - 6, sy(t)),
          theme.labelStyle,
          align: Alignment.centerRight);
    }
    final maxW = cs
        .map((c) => measureText(c.label, theme.labelStyle).width)
        .fold<double>(0, math.max);
    final every = math.max(1, ((maxW + 8) / unit).ceil());
    for (var i = 0; i < cs.length; i += every) {
      paintText(canvas, cs[i].label, Offset(cx(i), plot.bottom + 6),
          theme.labelStyle,
          align: Alignment.topCenter);
    }

    int? hover;
    final ptr = pointer;
    if (ptr != null && plot.inflate(6).contains(ptr)) {
      hover = ((ptr.dx - plot.left) / unit).floor().clamp(0, cs.length - 1).toInt();
      canvas.drawRect(
          Rect.fromLTWH(plot.left + hover * unit, plot.top, unit, plot.height),
          Paint()..color = theme.axisColor.faded(.15));
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(plot.left, plot.top - 4,
        plot.left + plot.width * progress, plot.bottom + 4));
    final bodyW = math.min(unit * 0.6, 28.0);
    for (var i = 0; i < cs.length; i++) {
      final c = cs[i];
      final color = c.close >= c.open ? w.upColor : w.downColor;
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(cx(i), sy(c.high)), Offset(cx(i), sy(c.low)), paint);
      final top = sy(math.max(c.open, c.close));
      final bottom = sy(math.min(c.open, c.close));
      canvas.drawRect(
          Rect.fromLTRB(cx(i) - bodyW / 2, top, cx(i) + bodyW / 2,
              math.max(bottom, top + 1)),
          paint..style = PaintingStyle.fill);
    }
    canvas.restore();

    if (hover != null && ptr != null && progress >= 1) {
      final c = cs[hover];
      paintTooltip(canvas, size, ptr, theme, title: c.label, rows: [
        TooltipRow('Open   ${formatNumber(c.open)}'),
        TooltipRow('High    ${formatNumber(c.high)}'),
        TooltipRow('Low     ${formatNumber(c.low)}'),
        TooltipRow('Close  ${formatNumber(c.close)}'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
