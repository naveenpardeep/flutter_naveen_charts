import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/legend.dart';
import '../core/plot_frame.dart';

/// Scatter-plot matrix (SPLOM): every variable against every other, with a
/// histogram on the diagonal. Hovering a point highlights the same
/// observation in every panel (linked brushing).
class ScatterMatrixChart extends StatelessWidget {
  const ScatterMatrixChart({
    super.key,
    required this.names,
    required this.columns,
    this.groups,
    this.groupNames,
    this.pointRadius = 2.6,
    this.showHistograms = true,
    this.bins = 12,
    this.aspectRatio = 1,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 800),
  });

  /// Variable names.
  final List<String> names;

  /// One list of observations per variable (all the same length).
  final List<List<double>> columns;

  /// Optional group index per observation (colours the points).
  final List<int>? groups;
  final List<String>? groupNames;
  final double pointRadius;
  final bool showHistograms;
  final int bins;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    final gs = groups == null ? <int>[] : ({...groups!}.toList()..sort());
    return chartShell(
      theme: t,
      aspectRatio: aspectRatio,
      duration: animationDuration,
      legend: [for (final g in gs) LegendItem((groupNames != null && g < groupNames!.length) ? groupNames![g] : 'Group $g', t.colorAt(g))],
      builder: (p, ptr) => _SplomPainter(this, t, p, ptr),
    );
  }
}

class _SplomPainter extends CustomPainter {
  _SplomPainter(this.w, this.theme, this.progress, this.pointer);
  final ScatterMatrixChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.names.length;
    if (n < 2 || w.columns.length < n) return;
    final rows = w.columns.take(n).map((c) => c.length).reduce(math.min);
    if (rows == 0) return;
    final lo = <double>[], hi = <double>[];
    for (var k = 0; k < n; k++) {
      var a = double.infinity, b = -double.infinity;
      for (var i = 0; i < rows; i++) {
        a = math.min(a, w.columns[k][i]);
        b = math.max(b, w.columns[k][i]);
      }
      final pad = (b - a) * .06 + 1e-9;
      lo.add(a - pad);
      hi.add(b + pad);
    }
    final area = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    final cw = area.width / n, ch = area.height / n;
    Rect cell(int r, int c) => Rect.fromLTWH(area.left + c * cw, area.top + r * ch, cw, ch).deflate(2);
    double px(int c, int cellC, int i) {
      final rc = cell(0, cellC);
      return rc.left + (w.columns[c][i] - lo[c]) / (hi[c] - lo[c]) * rc.width;
    }

    double py(int r, int cellR, int i) {
      final rc = cell(cellR, 0);
      return rc.bottom - (w.columns[r][i] - lo[r]) / (hi[r] - lo[r]) * rc.height;
    }

    Color colorOf(int i) => w.groups != null && i < w.groups!.length ? theme.colorAt(w.groups![i]) : theme.colorAt(0);
    final border = Paint()
      ..color = theme.gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final tiny = theme.labelStyle.copyWith(fontSize: 8.5);

    int? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      var best = 14.0;
      for (var r = 0; r < n; r++) {
        for (var c = 0; c < n; c++) {
          if (r == c || !cell(r, c).contains(ptr)) continue;
          for (var i = 0; i < rows; i++) {
            final d = (Offset(px(c, c, i), py(r, r, i)) - ptr).distance;
            if (d < best) {
              best = d;
              hover = i;
            }
          }
        }
      }
    }

    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final rc = cell(r, c);
        canvas.drawRect(rc, border);
        if (r == c) {
          if (w.showHistograms) {
            final counts = List<double>.filled(w.bins, 0);
            for (var i = 0; i < rows; i++) {
              counts[((w.columns[c][i] - lo[c]) / (hi[c] - lo[c]) * w.bins).floor().clamp(0, w.bins - 1).toInt()] += 1;
            }
            final mx = counts.reduce(math.max);
            final bw = rc.width / w.bins;
            for (var b = 0; b < w.bins; b++) {
              final h = counts[b] / mx * rc.height * .85 * progress;
              canvas.drawRect(Rect.fromLTWH(rc.left + b * bw + 1, rc.bottom - h, bw - 2, h), Paint()..color = theme.axisColor.faded(.45));
            }
          }
          paintText(canvas, w.names[c], Offset(rc.center.dx, rc.top + 5),
              theme.labelStyle.copyWith(color: theme.textColor, fontWeight: FontWeight.w700), align: Alignment.topCenter, maxWidth: rc.width - 4);
        } else {
          canvas.save();
          canvas.clipRect(rc);
          for (var i = 0; i < rows; i++) {
            canvas.drawCircle(Offset(px(c, c, i), py(r, r, i)), w.pointRadius * progress, Paint()..color = colorOf(i).faded(.6));
          }
          if (hover != null) {
            final o = Offset(px(c, c, hover), py(r, r, hover));
            canvas.drawCircle(o, w.pointRadius + 3, Paint()
              ..color = theme.textColor
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6);
          }
          canvas.restore();
        }
        if (r == n - 1) {
          paintText(canvas, formatNumber(lo[c]), Offset(rc.left + 2, rc.bottom - 1), tiny, align: Alignment.bottomLeft);
          paintText(canvas, formatNumber(hi[c]), Offset(rc.right - 2, rc.bottom - 1), tiny, align: Alignment.bottomRight);
        }
        if (c == 0 && r != c) {
          paintText(canvas, formatNumber(hi[r]), Offset(rc.left + 2, rc.top + 1), tiny, align: Alignment.topLeft);
        }
      }
    }
    if (hover != null && ptr != null) {
      paintTooltip(canvas, size, ptr, theme, title: 'Observation ${hover + 1}', rows: [
        for (var k = 0; k < n; k++) TooltipRow('${w.names[k]}: ${formatNumber(w.columns[k][hover])}', color: k == 0 ? colorOf(hover) : null),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
