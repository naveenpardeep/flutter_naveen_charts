import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';

class KagiLine {
  const KagiLine(this.start, this.end, this.thick);
  final double start, end;

  /// Thick ("yang") lines mark demand, thin ("yin") lines mark supply.
  final bool thick;
  bool get up => end > start;
}

/// Builds Kagi lines: price runs vertically and turns when it reverses by
/// at least [reversal]. A line turns thick when it breaks the previous
/// shoulder and thin when it breaks the previous waist.
List<KagiLine> kagiLines(List<double> prices, double reversal) {
  final raw = <List<double>>[]; // start, end, dir
  if (prices.length < 2 || reversal <= 0) return [];
  var start = prices.first, end = prices.first;
  var dir = 0;
  for (final p in prices.skip(1)) {
    if (dir == 0) {
      if ((p - start).abs() >= reversal) {
        dir = p > start ? 1 : -1;
        end = p;
      }
    } else if (dir == 1) {
      if (p > end) {
        end = p;
      } else if (end - p >= reversal) {
        raw.add([start, end, 1]);
        start = end;
        end = p;
        dir = -1;
      }
    } else {
      if (p < end) {
        end = p;
      } else if (p - end >= reversal) {
        raw.add([start, end, -1]);
        start = end;
        end = p;
        dir = 1;
      }
    }
  }
  if (dir != 0) raw.add([start, end, dir.toDouble()]);
  final out = <KagiLine>[];
  var thick = raw.isNotEmpty && raw.first[2] > 0;
  for (var i = 0; i < raw.length; i++) {
    if (i >= 2) {
      if (raw[i][2] > 0 && raw[i][1] > raw[i - 2][1]) thick = true;
      if (raw[i][2] < 0 && raw[i][1] < raw[i - 2][1]) thick = false;
    }
    out.add(KagiLine(raw[i][0], raw[i][1], thick));
  }
  return out;
}

/// Kagi chart: trend changes without a time axis.
class KagiChart extends StatelessWidget {
  const KagiChart({
    super.key,
    required this.prices,
    this.reversalAmount,
    this.reversalPercent = 4,
    this.thickColor = const Color(0xFF26A69A),
    this.thinColor = const Color(0xFFEF5350),
    this.thickWidth = 4,
    this.thinWidth = 1.6,
    this.priceFormat,
    this.aspectRatio = 1.6,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  /// Closing prices in time order.
  final List<double> prices;

  /// Reversal size in price units (overrides [reversalPercent]).
  final double? reversalAmount;

  /// Reversal size as a percentage of the first price.
  final double reversalPercent;
  final Color thickColor, thinColor;
  final double thickWidth, thinWidth;
  final String Function(double)? priceFormat;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    final rev = reversalAmount ?? (prices.isEmpty ? 1.0 : prices.first.abs() * reversalPercent / 100);
    final lines = kagiLines(prices, rev);
    return chartShell(
        theme: t,
        aspectRatio: aspectRatio,
        duration: animationDuration,
        builder: (p, ptr) => _KagiPainter(this, lines, rev, t, p, ptr));
  }
}

class _KagiPainter extends CustomPainter {
  _KagiPainter(this.w, this.lines, this.rev, this.theme, this.progress, this.pointer);
  final KagiChart w;
  final List<KagiLine> lines;
  final double rev;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty) return;
    var lo = double.infinity, hi = -double.infinity;
    for (final l in lines) {
      lo = math.min(lo, math.min(l.start, l.end));
      hi = math.max(hi, math.max(l.start, l.end));
    }
    final fmt = w.priceFormat ?? formatNumber;
    final f = paintFrame(canvas, size, theme,
        xLo: -.5, xHi: lines.length - .5, yLo: lo, yHi: hi, yFormat: w.priceFormat,
        xFormat: (v) => '${v.round() + 1}', xTitle: 'Line (reversal ${fmt(rev)})');
    if (f == null) return;
    int? hover;
    final ptr = pointer;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(f.plot.left, f.plot.top - 4, f.plot.left + f.plot.width * progress, f.plot.bottom + 4));
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      final x = f.sx(i.toDouble());
      final color = l.thick ? w.thickColor : w.thinColor;
      final p = Paint()
        ..color = color
        ..strokeWidth = l.thick ? w.thickWidth : w.thinWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawLine(Offset(x, f.sy(l.start)), Offset(x, f.sy(l.end)), p);
      if (i + 1 < lines.length) {
        final nx = f.sx(i + 1.0);
        final next = lines[i + 1];
        canvas.drawLine(Offset(x, f.sy(l.end)), Offset(nx, f.sy(l.end)), Paint()
          ..color = (next.thick ? w.thickColor : w.thinColor)
          ..strokeWidth = next.thick ? w.thickWidth : w.thinWidth);
      }
      if (ptr != null && progress >= 1) {
        final d = distToSegment(ptr, Offset(x, f.sy(l.start)), Offset(x, f.sy(l.end)));
        if (d < 8) hover = i;
      }
    }
    canvas.restore();
    if (hover != null && ptr != null) {
      final l = lines[hover];
      paintTooltip(canvas, size, ptr, theme, title: 'Line ${hover + 1}', rows: [
        TooltipRow(l.thick ? 'Thick (yang)' : 'Thin (yin)', color: l.thick ? w.thickColor : w.thinColor),
        TooltipRow('${l.up ? 'Up' : 'Down'}: ${fmt(l.start)} → ${fmt(l.end)}'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
