import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'cartesian/models.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';
import 'core/legend.dart';

enum StreamBaseline {
  /// Layers centred around a straight axis.
  silhouette,

  /// d3-style "wiggle": minimises the slope of the layers.
  wiggle,
}

/// Streamgraph: stacked areas around a moving centre line.
/// Series values are taken by position (use `AreaSeries.fromValues`).
class StreamGraphChart extends StatelessWidget {
  const StreamGraphChart({
    super.key,
    required this.series,
    this.xLabels,
    this.baseline = StreamBaseline.wiggle,
    this.curved = true,
    this.showLegend = true,
    this.aspectRatio = 1.8,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 1000),
  });
  final List<AreaSeries> series;
  final List<String>? xLabels;
  final StreamBaseline baseline;
  final bool curved;
  final bool showLegend;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (showLegend && series.length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChartLegend(theme: t, items: [
            for (var i = 0; i < series.length; i++)
              LegendItem(series[i].name, series[i].color ?? t.colorAt(i)),
          ]),
        ),
      AspectRatio(
        aspectRatio: aspectRatio,
        child: ChartCanvas(
          duration: animationDuration,
          builder: (p, ptr) => _StreamPainter(this, t, p, ptr),
        ),
      ),
    ]);
  }
}

class _StreamPainter extends CustomPainter {
  _StreamPainter(this.w, this.theme, this.progress, this.pointer);
  final StreamGraphChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final k = w.series.length;
    if (k == 0) return;
    final m = w.series.map((s) => s.points.length).reduce(math.max);
    if (m < 2) return;
    double val(int i, int j) => j < w.series[i].points.length ? math.max(0.0, w.series[i].points[j].y) : 0;
    final totals = [for (var j = 0; j < m; j++) [for (var i = 0; i < k; i++) val(i, j)].fold<double>(0, (a, b) => a + b)];

    final base = List<double>.filled(m, 0);
    if (w.baseline == StreamBaseline.silhouette) {
      for (var j = 0; j < m; j++) {
        base[j] = -totals[j] / 2;
      }
    } else {
      var y = 0.0;
      for (var j = 1; j < m; j++) {
        var s1 = 0.0, s2 = 0.0;
        for (var i = 0; i < k; i++) {
          final vij = val(i, j);
          var s3 = (vij - val(i, j - 1)) / 2;
          for (var q = 0; q < i; q++) {
            s3 += val(q, j) - val(q, j - 1);
          }
          s1 += vij;
          s2 += s3 * vij;
        }
        base[j - 1] = y;
        if (s1 != 0) y -= s2 / s1;
      }
      base[m - 1] = y;
    }
    final lower = List.generate(k, (_) => List<double>.filled(m, 0));
    final upper = List.generate(k, (_) => List<double>.filled(m, 0));
    var minY = double.infinity, maxY = -double.infinity;
    for (var j = 0; j < m; j++) {
      var acc = base[j];
      for (var i = 0; i < k; i++) {
        lower[i][j] = acc;
        acc += val(i, j);
        upper[i][j] = acc;
      }
      minY = math.min(minY, base[j]);
      maxY = math.max(maxY, acc);
    }
    if (maxY - minY < 1e-9) return;
    final plot = Rect.fromLTRB(12, 10, size.width - 12, size.height - 28);
    if (plot.width <= 0 || plot.height <= 0) return;
    double sx(int j) => plot.left + j / (m - 1) * plot.width;
    double sy(double y) => plot.bottom - (y - minY) / (maxY - minY) * plot.height;

    if (w.xLabels != null) {
      final maxW = w.xLabels!.map((l) => measureText(l, theme.labelStyle).width).fold<double>(0, math.max);
      final every = math.max(1, ((maxW + 8) / (plot.width / (m - 1))).ceil());
      for (var j = 0; j < m && j < w.xLabels!.length; j += every) {
        paintText(canvas, w.xLabels![j], Offset(sx(j), plot.bottom + 6), theme.labelStyle, align: Alignment.topCenter);
      }
    }

    int? hLayer;
    int? hx;
    final ptr = pointer;
    if (ptr != null && progress >= 1 && plot.inflate(6).contains(ptr)) {
      var bj = 0;
      for (var j = 0; j < m; j++) {
        if ((sx(j) - ptr.dx).abs() < (sx(bj) - ptr.dx).abs()) bj = j;
      }
      hx = bj;
      final yd = minY + (plot.bottom - ptr.dy) / plot.height * (maxY - minY);
      for (var i = 0; i < k; i++) {
        if (yd >= lower[i][bj] && yd <= upper[i][bj]) hLayer = i;
      }
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, plot.left + plot.width * progress + 2, size.height));
    for (var i = 0; i < k; i++) {
      final up = [for (var j = 0; j < m; j++) Offset(sx(j), sy(upper[i][j]))];
      final lo = [for (var j = 0; j < m; j++) Offset(sx(j), sy(lower[i][j]))];
      final path = buildLinePath(up, curved: w.curved);
      path.lineTo(lo.last.dx, lo.last.dy);
      path.extendWithPath(buildLinePath(lo.reversed.toList(), curved: w.curved), Offset.zero);
      path.close();
      final color = w.series[i].color ?? theme.colorAt(i);
      canvas.drawPath(path, Paint()..color = color.faded(hLayer == null || hLayer == i ? .92 : .45));
      canvas.drawPath(path, Paint()
        ..color = theme.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8);
    }
    canvas.restore();

    if (hx != null && ptr != null) {
      canvas.drawLine(Offset(sx(hx), plot.top), Offset(sx(hx), plot.bottom),
          Paint()
            ..color = theme.textColor.faded(.4)
            ..strokeWidth = 1);
      paintTooltip(canvas, size, ptr, theme,
          title: (w.xLabels != null && hx < w.xLabels!.length) ? w.xLabels![hx] : null,
          rows: [
            if (hLayer != null)
              TooltipRow('${w.series[hLayer].name}: ${formatNumber(val(hLayer, hx))}',
                  color: w.series[hLayer].color ?? theme.colorAt(hLayer))
            else
              TooltipRow('Total: ${formatNumber(totals[hx])}'),
          ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
