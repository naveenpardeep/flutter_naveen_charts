import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart3d.dart' show rampColor;
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';

const List<Color> _seq = [Color(0xFFFFF7BC), Color(0xFFFEC44F), Color(0xFFD95F0E), Color(0xFF7F2704)];

/// Hexagonal binning of a scatter: colour shows how many points fall in each hex.
class HexbinChart extends StatelessWidget {
  const HexbinChart({
    super.key,
    required this.points,
    this.binRadius = 14,
    this.colors = _seq,
    this.showColorBar = true,
    this.xFormat,
    this.yFormat,
    this.xTitle,
    this.yTitle,
    this.aspectRatio = 1.4,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 800),
  });

  /// Points as `Offset(x, y)` in data coordinates.
  final List<Offset> points;

  /// Hexagon radius in logical pixels.
  final double binRadius;
  final List<Color> colors;
  final bool showColorBar;
  final String Function(double)? xFormat, yFormat;
  final String? xTitle, yTitle;
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
        builder: (p, ptr) => _HexPainter(this, t, p, ptr));
  }
}

List<int> _hexRound(double x, double y, double r) {
  final q = (math.sqrt(3) / 3 * x - y / 3) / r;
  final rr = (2 / 3 * y) / r;
  var rx = q.round(), rz = rr.round(), ry = (-q - rr).round();
  final dx = (rx - q).abs(), dy = (ry - (-q - rr)).abs(), dz = (rz - rr).abs();
  if (dx > dy && dx > dz) {
    rx = -ry - rz;
  } else if (dy > dz) {
    ry = -rx - rz;
  } else {
    rz = -rx - ry;
  }
  return [rx, rz];
}

class _HexPainter extends CustomPainter {
  _HexPainter(this.w, this.theme, this.progress, this.pointer);
  final HexbinChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = w.points;
    if (pts.isEmpty) return;
    var xl = double.infinity, xh = -double.infinity, yl = double.infinity, yh = -double.infinity;
    for (final p in pts) {
      xl = math.min(xl, p.dx);
      xh = math.max(xh, p.dx);
      yl = math.min(yl, p.dy);
      yh = math.max(yh, p.dy);
    }
    final px = (xh - xl) * .04 + 1e-9, py = (yh - yl) * .04 + 1e-9;
    final f = paintFrame(canvas, size, theme,
        xLo: xl - px, xHi: xh + px, yLo: yl - py, yHi: yh + py, xFormat: w.xFormat, yFormat: w.yFormat,
        xTitle: w.xTitle, yTitle: w.yTitle, rightPad: w.showColorBar ? 48 : 12);
    if (f == null) return;
    final r = w.binRadius;
    final counts = <int, int>{};
    int key(int q, int rr) => (q + 4096) * 8192 + (rr + 4096);
    for (final p in pts) {
      final c = _hexRound(f.sx(p.dx) - f.plot.left, f.sy(p.dy) - f.plot.top, r);
      counts[key(c[0], c[1])] = (counts[key(c[0], c[1])] ?? 0) + 1;
    }
    final maxC = counts.values.fold<int>(1, math.max);
    Offset center(int q, int rr) =>
        Offset(f.plot.left + r * math.sqrt(3) * (q + rr / 2), f.plot.top + r * 1.5 * rr);
    Path hex(Offset c, double rad) {
      final path = Path();
      for (var k = 0; k < 6; k++) {
        final a = math.pi / 180 * (60 * k - 30);
        final o = c + Offset(math.cos(a), math.sin(a)) * rad;
        if (k == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      return path..close();
    }

    canvas.save();
    canvas.clipRect(f.plot);
    for (final e in counts.entries) {
      final q = e.key ~/ 8192 - 4096, rr = e.key % 8192 - 4096;
      final color = rampColor(w.colors, maxC <= 1 ? 1 : (e.value - 1) / (maxC - 1));
      canvas.drawPath(hex(center(q, rr), r * .97 * progress), Paint()..color = color);
    }
    final ptr = pointer;
    if (ptr != null && progress >= 1 && f.plot.contains(ptr)) {
      final c = _hexRound(ptr.dx - f.plot.left, ptr.dy - f.plot.top, r);
      final cnt = counts[key(c[0], c[1])];
      if (cnt != null) {
        canvas.drawPath(hex(center(c[0], c[1]), r * .97), Paint()
          ..color = theme.textColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
      }
    }
    canvas.restore();
    if (w.showColorBar) {
      final bar = Rect.fromLTWH(size.width - 34, f.plot.top, 10, f.plot.height);
      canvas.drawRect(bar, Paint()
        ..shader = LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: w.colors).createShader(bar));
      paintText(canvas, '$maxC', Offset(bar.left - 2, bar.top - 3), theme.labelStyle, align: Alignment.bottomLeft);
      paintText(canvas, '1', Offset(bar.left - 2, bar.bottom + 3), theme.labelStyle, align: Alignment.topLeft);
    }
    if (ptr != null && progress >= 1 && f.plot.contains(ptr)) {
      final c = _hexRound(ptr.dx - f.plot.left, ptr.dy - f.plot.top, r);
      final cnt = counts[key(c[0], c[1])];
      if (cnt != null) {
        paintTooltip(canvas, size, ptr, theme, title: 'Hex bin', rows: [
          TooltipRow('$cnt points (${(cnt / pts.length * 100).toStringAsFixed(1)}%)',
              color: rampColor(w.colors, maxC <= 1 ? 1 : (cnt - 1) / (maxC - 1))),
        ]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
