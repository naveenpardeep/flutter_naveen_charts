import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';

class PfColumn {
  const PfColumn(this.rising, this.low, this.high);

  /// true = column of X (rising), false = column of O (falling).
  final bool rising;

  /// Lowest and highest box index (inclusive); price = index * boxSize.
  final int low, high;
}

/// Point & figure columns from closing prices. A new column needs a move of
/// [reversal] boxes against the current one (3 by default).
List<PfColumn> pointFigureColumns(List<double> prices, double boxSize,
    {int reversal = 3}) {
  final cols = <PfColumn>[];
  if (prices.length < 2 || boxSize <= 0) return cols;
  int box(double p) => (p / boxSize).floor();
  final ref = box(prices.first);
  var dir = 0, low = ref, high = ref;
  for (final p in prices.skip(1)) {
    final b = box(p);
    if (dir == 0) {
      if (b > ref) {
        dir = 1;
        low = ref;
        high = b;
      } else if (b < ref) {
        dir = -1;
        high = ref;
        low = b;
      }
    } else if (dir == 1) {
      if (b > high) {
        high = b;
      } else if (high - b >= reversal) {
        cols.add(PfColumn(true, low, high));
        dir = -1;
        final newHigh = high - 1;
        high = newHigh;
        low = b;
      }
    } else {
      if (b < low) {
        low = b;
      } else if (b - low >= reversal) {
        cols.add(PfColumn(false, low, high));
        dir = 1;
        final newLow = low + 1;
        low = newLow;
        high = b;
      }
    }
  }
  if (dir != 0) cols.add(PfColumn(dir == 1, low, high));
  return cols;
}

/// Point & figure chart: columns of X (demand) and O (supply).
class PointFigureChart extends StatelessWidget {
  const PointFigureChart({
    super.key,
    required this.prices,
    this.boxSize,
    this.reversal = 3,
    this.xColor = const Color(0xFF26A69A),
    this.oColor = const Color(0xFFEF5350),
    this.showGrid = true,
    this.strokeWidth = 1.8,
    this.priceFormat,
    this.aspectRatio = 1.6,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  /// Closing prices in time order.
  final List<double> prices;

  /// Price per box; null picks about 30 boxes across the range.
  final double? boxSize;

  /// Boxes needed to start a new column.
  final int reversal;
  final Color xColor, oColor;
  final bool showGrid;
  final double strokeWidth;
  final String Function(double)? priceFormat;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    var size = boxSize;
    if (size == null && prices.length > 1) {
      size = NiceScale.compute(prices.reduce(math.min), prices.reduce(math.max),
              maxTicks: 30)
          .step;
    }
    final cols = pointFigureColumns(prices, size ?? 1, reversal: reversal);
    return chartShell(
        theme: t,
        aspectRatio: aspectRatio,
        duration: animationDuration,
        builder: (p, ptr) => _PfPainter(this, cols, size ?? 1, t, p, ptr));
  }
}

class _PfPainter extends CustomPainter {
  _PfPainter(
      this.w, this.cols, this.box, this.theme, this.progress, this.pointer);
  final PointFigureChart w;
  final List<PfColumn> cols;
  final double box;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    if (cols.isEmpty) return;
    final minB = cols.map((c) => c.low).reduce(math.min),
        maxB = cols.map((c) => c.high).reduce(math.max);
    final fmt = w.priceFormat ?? formatNumber;
    final f = paintFrame(canvas, size, theme,
        xLo: 0,
        xHi: cols.length.toDouble(),
        yLo: minB * box,
        yHi: (maxB + 1) * box,
        yFormat: w.priceFormat,
        yGrid: false,
        xFormat: (v) => '${v.round() + 1}',
        xTitle: 'Column (box ${fmt(box)}, reversal-box reversal)');
    if (f == null) return;
    final cw = f.sx(1) - f.sx(0), ch = (f.sy(0) - f.sy(box)).abs();
    final r = math.min(cw, ch) * .38;
    if (w.showGrid && maxB - minB < 80 && cols.length < 80) {
      final gp = Paint()
        ..color = theme.gridColor.faded(.6)
        ..strokeWidth = .6;
      for (var b = minB; b <= maxB + 1; b++) {
        canvas.drawLine(Offset(f.plot.left, f.sy(b * box)),
            Offset(f.plot.right, f.sy(b * box)), gp);
      }
      for (var c = 0; c <= cols.length; c++) {
        canvas.drawLine(Offset(f.sx(c.toDouble()), f.plot.top),
            Offset(f.sx(c.toDouble()), f.plot.bottom), gp);
      }
    }
    int? hc;
    final ptr = pointer;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(f.plot.left, f.plot.top,
        f.plot.left + f.plot.width * progress, f.plot.bottom));
    for (var c = 0; c < cols.length; c++) {
      final col = cols[c];
      final x = f.sx(c + .5);
      final p = Paint()
        ..color = col.rising ? w.xColor : w.oColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = w.strokeWidth;
      for (var b = col.low; b <= col.high; b++) {
        final y = f.sy((b + .5) * box);
        if (col.rising) {
          canvas.drawLine(Offset(x - r, y - r), Offset(x + r, y + r), p);
          canvas.drawLine(Offset(x - r, y + r), Offset(x + r, y - r), p);
        } else {
          canvas.drawCircle(Offset(x, y), r, p);
        }
      }
      if (ptr != null &&
          progress >= 1 &&
          ptr.dx >= f.sx(c.toDouble()) &&
          ptr.dx < f.sx(c + 1.0)) hc = c;
    }
    canvas.restore();
    if (hc != null && ptr != null) {
      final col = cols[hc];
      paintTooltip(canvas, size, ptr, theme, title: 'Column ${hc + 1}', rows: [
        TooltipRow(col.rising ? 'X (rising)' : 'O (falling)',
            color: col.rising ? w.xColor : w.oColor),
        TooltipRow('${fmt(col.low * box)} – ${fmt((col.high + 1) * box)}'),
        TooltipRow('${col.high - col.low + 1} boxes'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
