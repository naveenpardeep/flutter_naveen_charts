import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart3d.dart' show rampColor;
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';

const List<Color> _ramp = [Color(0xFF2C3E9E), Color(0xFF2E86C1), Color(0xFF27AE60), Color(0xFFF1C40F), Color(0xFFE74C3C)];

/// Contour plot of a scalar field: `values[row][col]`, row 0 at [yMin].
/// Draws filled bands plus iso-lines (marching squares).
class ContourChart extends StatelessWidget {
  const ContourChart({
    super.key,
    required this.values,
    this.xMin = 0,
    this.xMax = 1,
    this.yMin = 0,
    this.yMax = 1,
    this.levels = 8,
    this.levelValues,
    this.filled = true,
    this.showLines = true,
    this.colors = _ramp,
    this.lineColor,
    this.showColorBar = true,
    this.valueFormat,
    this.xTitle,
    this.yTitle,
    this.aspectRatio = 1.3,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<List<double>> values;
  final double xMin, xMax, yMin, yMax;

  /// Number of evenly spaced iso-levels (ignored when [levelValues] is set).
  final int levels;
  final List<double>? levelValues;
  final bool filled;
  final bool showLines;
  final List<Color> colors;
  final Color? lineColor;
  final bool showColorBar;
  final String Function(double)? valueFormat;
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
        builder: (p, ptr) => _ContourPainter(this, t, p, ptr));
  }
}

class _ContourPainter extends CustomPainter {
  _ContourPainter(this.w, this.theme, this.progress, this.pointer);
  final ContourChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final rows = w.values.length;
    if (rows < 2) return;
    final cols = w.values.first.length;
    if (cols < 2) return;
    var lo = double.infinity, hi = -double.infinity;
    for (final r in w.values) {
      for (final v in r) {
        lo = math.min(lo, v);
        hi = math.max(hi, v);
      }
    }
    final span = hi - lo < 1e-12 ? 1.0 : hi - lo;
    final levels = w.levelValues ?? [for (var k = 1; k <= w.levels; k++) lo + span * k / (w.levels + 1)];
    final fmt = w.valueFormat ?? formatNumber;
    final f = paintFrame(canvas, size, theme,
        xLo: w.xMin, xHi: w.xMax, yLo: w.yMin, yHi: w.yMax, xTitle: w.xTitle, yTitle: w.yTitle,
        rightPad: w.showColorBar ? 52 : 12);
    if (f == null) return;
    double gx(int c) => w.xMin + (w.xMax - w.xMin) * c / (cols - 1);
    double gy(int r) => w.yMin + (w.yMax - w.yMin) * r / (rows - 1);
    double v(int r, int c) => c < w.values[r].length ? w.values[r][c] : lo;
    int band(double val) => levels.where((l) => val >= l).length;

    canvas.save();
    canvas.clipRect(f.plot);
    if (w.filled) {
      for (var r = 0; r < rows - 1; r++) {
        for (var c = 0; c < cols - 1; c++) {
          final avg = (v(r, c) + v(r + 1, c) + v(r, c + 1) + v(r + 1, c + 1)) / 4;
          final color = rampColor(w.colors, levels.isEmpty ? (avg - lo) / span : band(avg) / levels.length);
          canvas.drawRect(
              Rect.fromLTRB(f.sx(gx(c)), f.sy(gy(r + 1)), f.sx(gx(c + 1)), f.sy(gy(r))).inflate(.4),
              Paint()..color = color.faded(progress));
        }
      }
    }
    if (w.showLines && progress > .3) {
      final path = Path();
      Offset ip(Offset a, Offset b, double va, double vb, double thr) {
        final t = vb == va ? .5 : (thr - va) / (vb - va);
        return a + (b - a) * t;
      }

      for (final thr in levels) {
        for (var r = 0; r < rows - 1; r++) {
          for (var c = 0; c < cols - 1; c++) {
            final vbl = v(r, c), vbr = v(r, c + 1), vtr = v(r + 1, c + 1), vtl = v(r + 1, c);
            final idx = (vtl >= thr ? 8 : 0) | (vtr >= thr ? 4 : 0) | (vbr >= thr ? 2 : 0) | (vbl >= thr ? 1 : 0);
            if (idx == 0 || idx == 15) continue;
            final bl = Offset(f.sx(gx(c)), f.sy(gy(r))), br = Offset(f.sx(gx(c + 1)), f.sy(gy(r)));
            final tr = Offset(f.sx(gx(c + 1)), f.sy(gy(r + 1))), tl = Offset(f.sx(gx(c)), f.sy(gy(r + 1)));
            Offset top() => ip(tl, tr, vtl, vtr, thr);
            Offset right() => ip(br, tr, vbr, vtr, thr);
            Offset bottom() => ip(bl, br, vbl, vbr, thr);
            Offset left() => ip(bl, tl, vbl, vtl, thr);
            void seg(Offset a, Offset b) {
              path.moveTo(a.dx, a.dy);
              path.lineTo(b.dx, b.dy);
            }

            final center = (vbl + vbr + vtr + vtl) / 4 >= thr;
            switch (idx) {
              case 1:
              case 14:
                seg(left(), bottom());
              case 2:
              case 13:
                seg(bottom(), right());
              case 3:
              case 12:
                seg(left(), right());
              case 4:
              case 11:
                seg(top(), right());
              case 5:
                if (center) {
                  seg(top(), left());
                  seg(bottom(), right());
                } else {
                  seg(top(), right());
                  seg(left(), bottom());
                }
              case 6:
              case 9:
                seg(top(), bottom());
              case 7:
              case 8:
                seg(top(), left());
              case 10:
                if (center) {
                  seg(top(), right());
                  seg(left(), bottom());
                } else {
                  seg(top(), left());
                  seg(bottom(), right());
                }
            }
          }
        }
      }
      canvas.drawPath(path, Paint()
        ..color = (w.lineColor ?? (w.filled ? Colors.black.withAlpha(110) : theme.textColor.faded(.7)))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
    }
    canvas.restore();

    if (w.showColorBar) {
      final bar = Rect.fromLTWH(size.width - 40, f.plot.top, 10, f.plot.height);
      canvas.drawRect(bar, Paint()
        ..shader = LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: w.colors).createShader(bar));
      paintText(canvas, fmt(hi), Offset(bar.left - 2, bar.top - 3), theme.labelStyle, align: Alignment.bottomLeft);
      paintText(canvas, fmt(lo), Offset(bar.left - 2, bar.bottom + 3), theme.labelStyle, align: Alignment.topLeft);
    }
    final ptr = pointer;
    if (ptr != null && progress >= 1 && f.plot.contains(ptr)) {
      final x = f.xAt(ptr.dx), y = f.yAt(ptr.dy);
      final c = ((x - w.xMin) / (w.xMax - w.xMin) * (cols - 1)).round(), r = ((y - w.yMin) / (w.yMax - w.yMin) * (rows - 1)).round();
      if (c >= 0 && c < cols && r >= 0 && r < rows) {
        paintTooltip(canvas, size, ptr, theme,
            title: '(${formatNumber(gx(c))}, ${formatNumber(gy(r))})', rows: [TooltipRow('Value: ${fmt(v(r, c))}')]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
