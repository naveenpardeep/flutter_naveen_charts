import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';

class RenkoBrick {
  const RenkoBrick(this.open, this.close);
  final double open, close;
  bool get up => close > open;
}

/// Converts a price series into Renko bricks of height [size]. A trend
/// continues with every [size] move; a reversal needs two bricks of movement.
List<RenkoBrick> renkoBricks(List<double> prices, double size) {
  final bricks = <RenkoBrick>[];
  if (prices.isEmpty || size <= 0) return bricks;
  var level = (prices.first / size).round() * size;
  var dir = 0;
  for (final p in prices.skip(1)) {
    for (var guard = 0; guard < 10000; guard++) {
      if (dir >= 0 && p >= level + size) {
        bricks.add(RenkoBrick(level, level + size));
        level += size;
        dir = 1;
      } else if (dir == 1 && p <= level - 2 * size) {
        bricks.add(RenkoBrick(level - size, level - 2 * size));
        level -= 2 * size;
        dir = -1;
      } else if (dir == 0 && p <= level - size) {
        bricks.add(RenkoBrick(level, level - size));
        level -= size;
        dir = -1;
      } else if (dir == -1 && p <= level - size) {
        bricks.add(RenkoBrick(level, level - size));
        level -= size;
      } else if (dir == -1 && p >= level + 2 * size) {
        bricks.add(RenkoBrick(level + size, level + 2 * size));
        level += 2 * size;
        dir = 1;
      } else {
        break;
      }
    }
  }
  return bricks;
}

/// Renko chart: price movement as equal-sized bricks, ignoring time.
class RenkoChart extends StatelessWidget {
  const RenkoChart({
    super.key,
    required this.prices,
    this.brickSize,
    this.upColor = const Color(0xFF26A69A),
    this.downColor = const Color(0xFFEF5350),
    this.hollowUp = false,
    this.brickGap = 1.5,
    this.priceFormat,
    this.aspectRatio = 1.6,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  /// Closing prices in time order.
  final List<double> prices;

  /// Brick height in price units; null picks about 20 bricks across the range.
  final double? brickSize;
  final Color upColor, downColor;

  /// Draw rising bricks as outlines.
  final bool hollowUp;
  final double brickGap;
  final String Function(double)? priceFormat;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    var size = brickSize;
    if (size == null && prices.length > 1) {
      size = NiceScale.compute(prices.reduce(math.min), prices.reduce(math.max), maxTicks: 20).step;
    }
    final bricks = renkoBricks(prices, size ?? 1);
    return chartShell(
        theme: t,
        aspectRatio: aspectRatio,
        duration: animationDuration,
        builder: (p, ptr) => _RenkoPainter(this, bricks, size ?? 1, t, p, ptr));
  }
}

class _RenkoPainter extends CustomPainter {
  _RenkoPainter(this.w, this.bricks, this.size0, this.theme, this.progress, this.pointer);
  final RenkoChart w;
  final List<RenkoBrick> bricks;
  final double size0;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    if (bricks.isEmpty) return;
    var lo = double.infinity, hi = -double.infinity;
    for (final b in bricks) {
      lo = math.min(lo, math.min(b.open, b.close));
      hi = math.max(hi, math.max(b.open, b.close));
    }
    final fmt = w.priceFormat ?? formatNumber;
    final f = paintFrame(canvas, size, theme,
        xLo: -.5, xHi: bricks.length - .5, yLo: lo, yHi: hi, yFormat: w.priceFormat,
        xFormat: (v) => '${v.round() + 1}', xTitle: 'Brick (size ${fmt(size0)})');
    if (f == null) return;
    final slot = f.plot.width / bricks.length;
    final bw = (slot - w.brickGap).clamp(1.0, 40.0).toDouble();
    int? hover;
    final ptr = pointer;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(f.plot.left, f.plot.top, f.plot.left + f.plot.width * progress, f.plot.bottom));
    for (var i = 0; i < bricks.length; i++) {
      final b = bricks[i];
      final x = f.sx(i.toDouble());
      final rect = Rect.fromLTRB(x - bw / 2, f.sy(math.max(b.open, b.close)), x + bw / 2, f.sy(math.min(b.open, b.close)));
      final color = b.up ? w.upColor : w.downColor;
      if (w.hollowUp && b.up) {
        canvas.drawRect(rect.deflate(.8), Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
      } else {
        canvas.drawRect(rect, Paint()..color = color);
      }
      if (ptr != null && progress >= 1 && rect.inflate(w.brickGap / 2).contains(ptr)) hover = i;
    }
    canvas.restore();
    if (hover != null && ptr != null) {
      final b = bricks[hover];
      paintTooltip(canvas, size, ptr, theme, title: 'Brick ${hover + 1}', rows: [
        TooltipRow(b.up ? 'Up' : 'Down', color: b.up ? w.upColor : w.downColor),
        TooltipRow('From ${fmt(b.open)} to ${fmt(b.close)}'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
