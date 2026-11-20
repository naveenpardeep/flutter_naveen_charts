import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';
import 'core/legend.dart';

/// One column: its width is proportional to the sum of [values].
class MarimekkoColumn {
  const MarimekkoColumn(this.label, this.values);
  final String label;
  final List<double> values;
}

/// Marimekko / Mekko chart: 100 % stacked columns of variable width.
class MarimekkoChart extends StatelessWidget {
  const MarimekkoChart({
    super.key,
    required this.columns,
    required this.segmentNames,
    this.colors,
    this.gap = 2,
    this.showPercentLabels = true,
    this.showLegend = true,
    this.valueFormat,
    this.aspectRatio = 1.5,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<MarimekkoColumn> columns;
  final List<String> segmentNames;
  final List<Color>? colors;
  final double gap;
  final bool showPercentLabels;
  final bool showLegend;
  final String Function(double)? valueFormat;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    Color c(int i) => (colors != null && i < colors!.length) ? colors![i] : t.colorAt(i);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (showLegend)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChartLegend(theme: t, items: [
            for (var i = 0; i < segmentNames.length; i++) LegendItem(segmentNames[i], c(i)),
          ]),
        ),
      AspectRatio(
        aspectRatio: aspectRatio,
        child: ChartCanvas(
          duration: animationDuration,
          builder: (p, ptr) => _MekkoPainter(this, t, p, ptr, c),
        ),
      ),
    ]);
  }
}

class _MekkoPainter extends CustomPainter {
  _MekkoPainter(this.w, this.theme, this.progress, this.pointer, this.color);
  final MarimekkoChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;
  final Color Function(int) color;

  @override
  void paint(Canvas canvas, Size size) {
    final cols = w.columns;
    if (cols.isEmpty) return;
    final fmt = w.valueFormat ?? formatNumber;
    final totals = [for (final c in cols) c.values.fold<double>(0, (a, b) => a + math.max(0.0, b))];
    final grand = totals.fold<double>(0, (a, b) => a + b);
    if (grand <= 0) return;
    final plot = Rect.fromLTRB(38, 8, size.width - 8, size.height - 38);
    if (plot.width <= 0 || plot.height <= 0) return;
    final usable = plot.width - w.gap * (cols.length - 1);
    final grid = Paint()
      ..color = theme.gridColor
      ..strokeWidth = 1;
    for (final t in const [0, 25, 50, 75, 100]) {
      final y = plot.bottom - t / 100 * plot.height;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      paintText(canvas, '$t%', Offset(plot.left - 6, y), theme.labelStyle, align: Alignment.centerRight);
    }

    int? hc, hs;
    final ptr = pointer;
    var x = plot.left;
    final rects = <List<Rect>>[];
    for (var ci = 0; ci < cols.length; ci++) {
      final total = totals[ci];
      final cw = total / grand * usable;
      var y = plot.bottom;
      final row = <Rect>[];
      for (var si = 0; si < cols[ci].values.length; si++) {
        final v = math.max(0.0, cols[ci].values[si]);
        final frac = total == 0 ? 0.0 : v / total;
        final h = frac * plot.height * progress;
        final r = Rect.fromLTWH(x, y - h, cw, h);
        row.add(r);
        y -= h;
        if (ptr != null && progress >= 1 && r.contains(ptr)) {
          hc = ci;
          hs = si;
        }
      }
      rects.add(row);
      x += cw + w.gap;
    }
    for (var ci = 0; ci < cols.length; ci++) {
      for (var si = 0; si < rects[ci].length; si++) {
        final r = rects[ci][si];
        final fill = color(si);
        final hot = hc == ci && hs == si;
        canvas.drawRect(r.deflate(.5), Paint()..color = hot ? shadeUp(fill) : fill);
        final frac = totals[ci] == 0 ? 0.0 : cols[ci].values[si] / totals[ci];
        if (w.showPercentLabels && progress > .99 && r.width > 32 && r.height > 16) {
          paintText(canvas, '${(frac * 100).round()}%', r.center,
              TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: contrastOn(fill)));
        }
      }
      final cx = rects[ci].isEmpty ? 0.0 : rects[ci].first.center.dx;
      final cw = rects[ci].isEmpty ? 0.0 : rects[ci].first.width;
      paintText(canvas, cols[ci].label, Offset(cx, plot.bottom + 5), theme.labelStyle.copyWith(color: theme.textColor),
          align: Alignment.topCenter, maxWidth: math.max(cw, 24));
      paintText(canvas, '${(totals[ci] / grand * 100).round()}% of total', Offset(cx, plot.bottom + 19), theme.labelStyle.copyWith(fontSize: 9),
          align: Alignment.topCenter, maxWidth: math.max(cw, 24));
    }
    if (hc != null && hs != null && ptr != null) {
      final ci = hc, si = hs;
      final v = cols[ci].values[si];
      paintTooltip(canvas, size, ptr, theme, title: '${cols[ci].label} · ${si < w.segmentNames.length ? w.segmentNames[si] : 'Segment ${si + 1}'}', rows: [
        TooltipRow('Value: ${fmt(v)}', color: color(si)),
        TooltipRow('${(v / totals[ci] * 100).toStringAsFixed(1)}% of column'),
        TooltipRow('${(v / grand * 100).toStringAsFixed(1)}% of total'),
      ]);
    }
  }

  Color shadeUp(Color c) => Color.lerp(c, Colors.white, .22)!;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
