import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';

class DepthLevel {
  const DepthLevel(this.price, this.size);
  final double price, size;
}

/// Order-book depth chart: cumulative bid (left) and ask (right) volume.
class DepthChart extends StatelessWidget {
  const DepthChart({
    super.key,
    required this.bids,
    required this.asks,
    this.bidColor = const Color(0xFF26A69A),
    this.askColor = const Color(0xFFEF5350),
    this.fillOpacity = 0.25,
    this.showMidPrice = true,
    this.showSpread = true,
    this.priceFormat,
    this.sizeFormat,
    this.aspectRatio = 1.8,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  /// Bid levels (any order; sorted internally).
  final List<DepthLevel> bids;

  /// Ask levels (any order; sorted internally).
  final List<DepthLevel> asks;
  final Color bidColor, askColor;
  final double fillOpacity;
  final bool showMidPrice;
  final bool showSpread;
  final String Function(double)? priceFormat, sizeFormat;
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
        builder: (p, ptr) => _DepthPainter(this, t, p, ptr));
  }
}

class _DepthPainter extends CustomPainter {
  _DepthPainter(this.w, this.theme, this.progress, this.pointer);
  final DepthChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final bids = [...w.bids]..sort((a, b) => b.price.compareTo(a.price)); // best (highest) first
    final asks = [...w.asks]..sort((a, b) => a.price.compareTo(b.price)); // best (lowest) first
    if (bids.isEmpty || asks.isEmpty) return;
    final cb = <double>[], ca = <double>[];
    var run = 0.0;
    for (final b in bids) {
      run += b.size;
      cb.add(run);
    }
    run = 0;
    for (final a in asks) {
      run += a.size;
      ca.add(run);
    }
    final maxCum = math.max(cb.last, ca.last);
    final xLo = bids.last.price, xHi = asks.last.price;
    final bestBid = bids.first.price, bestAsk = asks.first.price;
    final mid = (bestBid + bestAsk) / 2;
    final pf = w.priceFormat ?? formatNumber, sf = w.sizeFormat ?? formatNumber;
    final f = paintFrame(canvas, size, theme,
        xLo: xLo, xHi: xHi, yLo: 0, yHi: maxCum, includeZero: true, xFormat: w.priceFormat, yFormat: w.sizeFormat,
        xTitle: 'Price', yTitle: 'Cumulative size');
    if (f == null) return;
    double sy(double v) => f.sy(v * progress);

    void side(List<DepthLevel> lv, List<double> cum, Color color) {
      final path = Path()..moveTo(f.sx(lv.first.price), f.sy(0));
      path.lineTo(f.sx(lv.first.price), sy(cum.first));
      for (var i = 1; i < lv.length; i++) {
        path.lineTo(f.sx(lv[i].price), sy(cum[i - 1]));
        path.lineTo(f.sx(lv[i].price), sy(cum[i]));
      }
      final line = Path.from(path);
      path
        ..lineTo(f.sx(lv.last.price), f.sy(0))
        ..close();
      canvas.drawPath(path, Paint()..color = color.faded(w.fillOpacity));
      canvas.drawPath(line, Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round);
    }

    canvas.save();
    canvas.clipRect(f.plot.inflate(1));
    side(bids, cb, w.bidColor);
    side(asks, ca, w.askColor);
    if (w.showSpread) {
      canvas.drawRect(Rect.fromLTRB(f.sx(bestBid), f.plot.top, f.sx(bestAsk), f.plot.bottom),
          Paint()..color = theme.axisColor.faded(.1));
    }
    if (w.showMidPrice) {
      canvas.drawPath(
          dashPath(Path()
            ..moveTo(f.sx(mid), f.plot.top)
            ..lineTo(f.sx(mid), f.plot.bottom)),
          Paint()
            ..color = theme.textColor.faded(.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
    }
    canvas.restore();
    if (w.showMidPrice) {
      paintText(canvas, 'Mid ${pf(mid)}', Offset(f.sx(mid), f.plot.top + 2),
          theme.labelStyle.copyWith(color: theme.textColor, fontWeight: FontWeight.w600), align: Alignment.topCenter);
      if (w.showSpread) {
        paintText(canvas, 'Spread ${pf(bestAsk - bestBid)}', Offset(f.sx(mid), f.plot.top + 16), theme.labelStyle,
            align: Alignment.topCenter);
      }
    }

    final ptr = pointer;
    if (ptr != null && progress >= 1 && f.plot.contains(ptr)) {
      final x = f.xAt(ptr.dx);
      double? cumAt;
      Color? color;
      if (x <= bestBid) {
        cumAt = bids.where((b) => b.price >= x).fold<double>(0, (a, b) => a + b.size);
        color = w.bidColor;
      } else if (x >= bestAsk) {
        cumAt = asks.where((a) => a.price <= x).fold<double>(0, (s, a) => s + a.size);
        color = w.askColor;
      }
      canvas.drawLine(Offset(ptr.dx, f.plot.top), Offset(ptr.dx, f.plot.bottom), Paint()
        ..color = theme.axisColor.faded(.7)
        ..strokeWidth = 1);
      if (cumAt != null && color != null) {
        canvas.drawCircle(Offset(ptr.dx, f.sy(cumAt)), 4.5, Paint()..color = color);
        final off = (x - mid) / mid * 100;
        paintTooltip(canvas, size, ptr, theme, title: 'Price ${pf(x)}', rows: [
          TooltipRow('${x <= bestBid ? 'Bids' : 'Asks'}: ${sf(cumAt)}', color: color),
          TooltipRow('${off >= 0 ? '+' : ''}${off.toStringAsFixed(2)}% from mid'),
        ]);
      } else {
        paintTooltip(canvas, size, ptr, theme, title: 'Price ${pf(x)}', rows: [const TooltipRow('Inside the spread')]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
