import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';

/// Heatmap of a [values] matrix (rows x columns).
class HeatmapChart extends StatelessWidget {
  const HeatmapChart({
    super.key,
    required this.values,
    this.rowLabels,
    this.colLabels,
    this.lowColor = const Color(0xFFE3F2FD),
    this.highColor = const Color(0xFF0D47A1),
    this.showValues = true,
    this.aspectRatio = 1.6,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 800),
  });
  final List<List<double>> values;
  final List<String>? rowLabels;
  final List<String>? colLabels;
  final Color lowColor;
  final Color highColor;
  final bool showValues;
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
        builder: (p, ptr) => _HeatPainter(this, t, p, ptr),
      ),
    );
  }
}

/// heat Painter
class _HeatPainter extends CustomPainter {
  _HeatPainter(this.w, this.theme, this.progress, this.pointer);
  final HeatmapChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final v = w.values;
    if (v.isEmpty || v.first.isEmpty) return;
    final rows = v.length, cols = v.first.length;
    var lo = double.infinity, hi = -double.infinity;
    for (final r in v) {
      for (final x in r) {
        lo = math.min(lo, x);
        hi = math.max(hi, x);
      }
    }
    final leftW = w.rowLabels == null
        ? 4.0
        : w.rowLabels!
                .map((l) => measureText(l, theme.labelStyle).width)
                .fold<double>(0, math.max) +
            10;
    final bottomH = w.colLabels == null ? 4.0 : 24.0;
    final plot = Rect.fromLTRB(leftW, 4, size.width - 4, size.height - bottomH);
    if (plot.width <= 0 || plot.height <= 0) return;
    final cw = plot.width / cols, ch = plot.height / rows;

    for (var r = 0; r < rows; r++) {
      if (w.rowLabels != null && r < w.rowLabels!.length) {
        paintText(canvas, w.rowLabels![r],
            Offset(plot.left - 6, plot.top + (r + .5) * ch), theme.labelStyle,
            align: Alignment.centerRight);
      }
      for (var c = 0; c < cols; c++) {
        final x = v[r][c];
        final t = hi == lo ? .5 : (x - lo) / (hi - lo);
        final color = Color.lerp(w.lowColor, w.highColor, t)!;
        final rect =
            Rect.fromLTWH(plot.left + c * cw, plot.top + r * ch, cw, ch)
                .deflate(1.5);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            Paint()..color = color.faded(progress));
        if (w.showValues && progress > .99 && cw > 26 && ch > 16) {
          paintText(
              canvas,
              formatNumber(x),
              rect.center,
              TextStyle(
                  fontSize: 11,
                  color: color.computeLuminance() > .5
                      ? Colors.black87
                      : Colors.white));
        }
      }
    }
    if (w.colLabels != null) {
      for (var c = 0; c < cols && c < w.colLabels!.length; c++) {
        paintText(
            canvas,
            w.colLabels![c],
            Offset(plot.left + (c + .5) * cw, plot.bottom + 6),
            theme.labelStyle,
            align: Alignment.topCenter,
            maxWidth: cw);
      }
    }

    final ptr = pointer;
    if (ptr != null && plot.contains(ptr) && progress >= 1) {
      final c = ((ptr.dx - plot.left) / cw).floor().clamp(0, cols - 1).toInt();
      final r = ((ptr.dy - plot.top) / ch).floor().clamp(0, rows - 1).toInt();
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(plot.left + c * cw, plot.top + r * ch, cw, ch)
                  .deflate(1.5),
              const Radius.circular(4)),
          Paint()
            ..color = theme.textColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      final rl = w.rowLabels != null && r < w.rowLabels!.length
          ? w.rowLabels![r]
          : 'Row ${r + 1}';
      final cl = w.colLabels != null && c < w.colLabels!.length
          ? w.colLabels![c]
          : 'Col ${c + 1}';
      paintTooltip(canvas, size, ptr, theme,
          title: '$rl · $cl', rows: [TooltipRow(formatNumber(v[r][c]))]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
