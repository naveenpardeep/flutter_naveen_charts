import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';
import '../core/stats.dart';

class RidgeData {
  const RidgeData(this.label, this.values, {this.color});
  final String label;
  final List<double> values;
  final Color? color;
}

/// Ridgeline ("joy") plot: overlapping density curves, one row per group.
class RidgelineChart extends StatelessWidget {
  const RidgelineChart({
    super.key,
    required this.data,
    this.overlap = 0.6,
    this.bandwidth,
    this.points = 100,
    this.showMedian = true,
    this.xFormat,
    this.xTitle,
    this.rowHeight = 46,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 1000),
  });
  final List<RidgeData> data;

  /// How far each ridge may rise into the row above (0 = no overlap).
  final double overlap;
  final double? bandwidth;
  final int points;
  final bool showMedian;
  final String Function(double)? xFormat;
  final String? xTitle;
  final double rowHeight;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return SizedBox(
      height: data.length * rowHeight + 60,
      child: chartShellBox(t, animationDuration, (p, ptr) => _RidgePainter(this, t, p, ptr)),
    );
  }
}

class _RidgePainter extends CustomPainter {
  _RidgePainter(this.w, this.theme, this.progress, this.pointer);
  final RidgelineChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.data.length;
    if (n == 0) return;
    final sorted = [for (final d in w.data) sortedCopy(d.values)];
    if (sorted.every((s) => s.isEmpty)) return;
    final hs = [for (final s in sorted) w.bandwidth ?? silverman(s)];
    var lo = double.infinity, hi = -double.infinity;
    for (var i = 0; i < n; i++) {
      if (sorted[i].isEmpty) continue;
      lo = math.min(lo, sorted[i].first - 1.5 * hs[i]);
      hi = math.max(hi, sorted[i].last + 1.5 * hs[i]);
    }
    final xs = NiceScale.compute(lo, hi, maxTicks: 6);
    final labelW = w.data.map((d) => measureText(d.label, theme.labelStyle).width).fold<double>(0, math.max);
    final plot = Rect.fromLTRB(labelW + 14, 8, size.width - 14, size.height - 28 - (w.xTitle != null ? 16 : 0));
    if (plot.width <= 20 || plot.height <= 20) return;
    double sx(double v) => plot.left + (v - xs.min) / (xs.max - xs.min) * plot.width;
    final grid = Paint()
      ..color = theme.gridColor
      ..strokeWidth = 1;
    final fx = w.xFormat ?? formatNumber;
    for (final t in xs.ticks) {
      canvas.drawLine(Offset(sx(t), plot.top), Offset(sx(t), plot.bottom), grid);
      paintText(canvas, fx(t), Offset(sx(t), plot.bottom + 6), theme.labelStyle, align: Alignment.topCenter);
    }
    if (w.xTitle != null) {
      paintText(canvas, w.xTitle!, Offset(plot.center.dx, size.height - 2),
          theme.labelStyle.copyWith(color: theme.textColor, fontWeight: FontWeight.w600), align: Alignment.bottomCenter);
    }
    final spacing = plot.height / (n + w.overlap);
    final amp = spacing * (1 + w.overlap);
    final grid2 = [for (var k = 0; k < w.points; k++) xs.min + (xs.max - xs.min) * k / (w.points - 1)];
    final dens = [for (var i = 0; i < n; i++) kde(sorted[i], grid2, hs[i])];
    final gMax = dens.expand((d) => d).fold<double>(0, math.max);
    if (gMax <= 0) return;
    int? hover;
    final ptr = pointer;
    if (ptr != null && plot.inflate(6).contains(ptr)) {
      hover = ((ptr.dy - plot.top - amp) / spacing).round().clamp(0, n - 1).toInt();
    }
    for (var i = 0; i < n; i++) {
      final base = plot.top + amp + i * spacing;
      final color = w.data[i].color ?? theme.colorAt(i);
      paintText(canvas, w.data[i].label, Offset(plot.left - 8, base - 2), theme.labelStyle.copyWith(color: theme.textColor),
          align: Alignment.bottomRight, maxWidth: labelW + 2);
      final pts = [for (var k = 0; k < w.points; k++) Offset(sx(grid2[k]), base - dens[i][k] / gMax * amp * progress)];
      final fill = buildLinePath(pts, curved: true)
        ..lineTo(pts.last.dx, base)
        ..lineTo(pts.first.dx, base)
        ..close();
      canvas.drawPath(fill, Paint()..color = color.faded(hover == i ? .9 : .72));
      canvas.drawPath(buildLinePath(pts, curved: true), Paint()
        ..color = theme.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6);
      canvas.drawLine(Offset(plot.left, base), Offset(plot.right, base), Paint()
        ..color = color.faded(.5)
        ..strokeWidth = 1);
      if (w.showMedian && sorted[i].isNotEmpty && progress > .8) {
        final mx = sx(quantile(sorted[i], .5));
        canvas.drawLine(Offset(mx, base), Offset(mx, base - 8), Paint()
          ..color = theme.textColor
          ..strokeWidth = 2);
      }
    }
    if (hover != null && ptr != null && progress >= 1 && sorted[hover].isNotEmpty) {
      final s = sorted[hover];
      paintTooltip(canvas, size, ptr, theme, title: w.data[hover].label, rows: [
        TooltipRow('n = ${s.length}', color: w.data[hover].color ?? theme.colorAt(hover)),
        TooltipRow('Median ${fx(quantile(s, .5))}'),
        TooltipRow('Mean   ${fx(mean(s))}'),
        TooltipRow('SD       ${fx(stdDev(s))}'),
      ]);
    }
  }

  String fx(double v) => (w.xFormat ?? formatNumber)(v);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
