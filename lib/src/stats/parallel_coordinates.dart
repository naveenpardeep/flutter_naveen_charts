import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/legend.dart';
import '../core/plot_frame.dart';

/// Parallel coordinates: each row is a polyline across one axis per variable.
/// Hover a line to highlight it.
class ParallelCoordinatesChart extends StatelessWidget {
  const ParallelCoordinatesChart({
    super.key,
    required this.dimensions,
    required this.rows,
    this.groups,
    this.groupNames,
    this.invertedDimensions = const {},
    this.curved = false,
    this.lineOpacity = 0.45,
    this.lineWidth = 1.4,
    this.aspectRatio = 1.7,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 1000),
  });

  /// Axis names.
  final List<String> dimensions;

  /// One list of values per observation (one value per dimension).
  final List<List<double>> rows;
  final List<int>? groups;
  final List<String>? groupNames;

  /// Indexes of axes drawn high-to-low.
  final Set<int> invertedDimensions;
  final bool curved;
  final double lineOpacity;
  final double lineWidth;
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
      builder: (p, ptr) => _ParallelPainter(this, t, p, ptr),
    );
  }
}

class _ParallelPainter extends CustomPainter {
  _ParallelPainter(this.w, this.theme, this.progress, this.pointer);
  final ParallelCoordinatesChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.dimensions.length;
    if (n < 2 || w.rows.isEmpty) return;
    final lo = List<double>.filled(n, double.infinity), hi = List<double>.filled(n, -double.infinity);
    for (final r in w.rows) {
      for (var k = 0; k < n && k < r.length; k++) {
        lo[k] = math.min(lo[k], r[k]);
        hi[k] = math.max(hi[k], r[k]);
      }
    }
    for (var k = 0; k < n; k++) {
      if (!lo[k].isFinite) {
        lo[k] = 0;
        hi[k] = 1;
      }
      if (hi[k] - lo[k] < 1e-12) hi[k] = lo[k] + 1;
    }
    final plot = Rect.fromLTRB(28, 30, size.width - 28, size.height - 24);
    if (plot.width <= 20 || plot.height <= 20) return;
    double ax(int k) => plot.left + k / (n - 1) * plot.width;
    double ay(int k, double v) {
      final t = (v - lo[k]) / (hi[k] - lo[k]);
      return w.invertedDimensions.contains(k) ? plot.top + t * plot.height : plot.bottom - t * plot.height;
    }

    List<Offset> pts(int ri) => [for (var k = 0; k < n; k++) Offset(ax(k), ay(k, k < w.rows[ri].length ? w.rows[ri][k] : lo[k]))];
    Color colorOf(int ri) => w.groups != null && ri < w.groups!.length ? theme.colorAt(w.groups![ri]) : theme.colorAt(0);

    int? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1 && plot.inflate(10).contains(ptr)) {
      var best = 9.0;
      for (var ri = 0; ri < w.rows.length; ri++) {
        final p = pts(ri);
        for (var k = 0; k < n - 1; k++) {
          final d = distToSegment(ptr, p[k], p[k + 1]);
          if (d < best) {
            best = d;
            hover = ri;
          }
        }
      }
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, plot.left + plot.width * progress + 4, size.height));
    for (var ri = 0; ri < w.rows.length; ri++) {
      if (ri == hover) continue;
      canvas.drawPath(buildLinePath(pts(ri), curved: w.curved), Paint()
        ..color = colorOf(ri).faded(hover == null ? w.lineOpacity : .08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w.lineWidth);
    }
    if (hover != null) {
      canvas.drawPath(buildLinePath(pts(hover), curved: w.curved), Paint()
        ..color = colorOf(hover)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w.lineWidth + 2.2
        ..strokeJoin = StrokeJoin.round);
    }
    canvas.restore();
    final axis = Paint()
      ..color = theme.axisColor
      ..strokeWidth = 1.6;
    final ts = theme.labelStyle.copyWith(color: theme.textColor, fontWeight: FontWeight.w700);
    for (var k = 0; k < n; k++) {
      canvas.drawLine(Offset(ax(k), plot.top), Offset(ax(k), plot.bottom), axis);
      paintText(canvas, w.dimensions[k], Offset(ax(k), plot.top - 18), ts, align: Alignment.bottomCenter, maxWidth: plot.width / (n - 1) - 6);
      final top = w.invertedDimensions.contains(k) ? lo[k] : hi[k];
      final bottom = w.invertedDimensions.contains(k) ? hi[k] : lo[k];
      paintText(canvas, formatNumber(top), Offset(ax(k), plot.top - 3), theme.labelStyle, align: Alignment.bottomCenter);
      paintText(canvas, formatNumber(bottom), Offset(ax(k), plot.bottom + 4), theme.labelStyle, align: Alignment.topCenter);
    }
    if (hover != null && ptr != null) {
      final r = w.rows[hover];
      paintTooltip(canvas, size, ptr, theme, title: 'Row ${hover + 1}', rows: [
        for (var k = 0; k < n && k < r.length; k++) TooltipRow('${w.dimensions[k]}: ${formatNumber(r[k])}', color: k == 0 ? colorOf(hover) : null),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
