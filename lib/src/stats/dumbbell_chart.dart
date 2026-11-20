import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/legend.dart';
import '../core/plot_frame.dart';

class DumbbellItem {
  const DumbbellItem(this.label, this.start, this.end);
  final String label;
  final double start, end;
}

/// Dumbbell (dumbbell / connected dot) chart: change between two values.
class DumbbellChart extends StatelessWidget {
  const DumbbellChart({
    super.key,
    required this.items,
    this.startLabel = 'Before',
    this.endLabel = 'After',
    this.startColor = const Color(0xFF9E9E9E),
    this.endColor = const Color(0xFF4E79A7),
    this.dotRadius = 7,
    this.sortByGap = false,
    this.showValues = true,
    this.valueFormat,
    this.xTitle,
    this.rowHeight = 34,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<DumbbellItem> items;
  final String startLabel, endLabel;
  final Color startColor, endColor;
  final double dotRadius;

  /// Sort rows by the size of the change (largest first).
  final bool sortByGap;
  final bool showValues;
  final String Function(double)? valueFormat;
  final String? xTitle;
  final double rowHeight;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    final list = [...items];
    if (sortByGap) list.sort((a, b) => (b.end - b.start).abs().compareTo((a.end - a.start).abs()));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ChartLegend(theme: t, items: [LegendItem(startLabel, startColor), LegendItem(endLabel, endColor)]),
      ),
      SizedBox(
        height: list.length * rowHeight + 40,
        child: chartShellBox(t, animationDuration, (p, ptr) => _DumbbellPainter(this, list, t, p, ptr)),
      ),
    ]);
  }
}

class _DumbbellPainter extends CustomPainter {
  _DumbbellPainter(this.w, this.items, this.theme, this.progress, this.pointer);
  final DumbbellChart w;
  final List<DumbbellItem> items;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;
    var lo = double.infinity, hi = -double.infinity;
    for (final it in items) {
      lo = math.min(lo, math.min(it.start, it.end));
      hi = math.max(hi, math.max(it.start, it.end));
    }
    final fmt = w.valueFormat ?? formatNumber;
    final f = paintHFrame(canvas, size, theme,
        cats: [for (final it in items) it.label], lo: lo, hi: hi, xFormat: w.valueFormat, xTitle: w.xTitle);
    if (f == null) return;
    int? hover;
    final ptr = pointer;
    if (ptr != null && f.plot.inflate(8).contains(ptr)) {
      hover = f.rowAt(ptr);
      canvas.drawRect(Rect.fromLTWH(f.plot.left, f.plot.top + hover * f.band, f.plot.width, f.band),
          Paint()..color = theme.axisColor.faded(.12));
    }
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final y = f.cy(i);
      final xs = f.sx(it.start), xe = f.sx(it.start + (it.end - it.start) * progress);
      canvas.drawLine(Offset(xs, y), Offset(xe, y),
          Paint()
            ..color = theme.axisColor.faded(.8)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round);
      canvas.drawCircle(Offset(xs, y), w.dotRadius, Paint()..color = w.startColor);
      canvas.drawCircle(Offset(xe, y), w.dotRadius, Paint()..color = w.endColor);
      if (w.showValues && progress > .99) {
        final right = it.end >= it.start;
        paintText(canvas, fmt(it.start), Offset(xs + (right ? -w.dotRadius - 4 : w.dotRadius + 4), y), theme.labelStyle,
            align: right ? Alignment.centerRight : Alignment.centerLeft);
        paintText(canvas, fmt(it.end), Offset(xe + (right ? w.dotRadius + 4 : -w.dotRadius - 4), y), theme.labelStyle,
            align: right ? Alignment.centerLeft : Alignment.centerRight);
      }
    }
    if (hover != null && ptr != null && progress >= 1) {
      final it = items[hover];
      final d = it.end - it.start;
      paintTooltip(canvas, size, ptr, theme, title: it.label, rows: [
        TooltipRow('${w.startLabel}: ${fmt(it.start)}', color: w.startColor),
        TooltipRow('${w.endLabel}: ${fmt(it.end)}', color: w.endColor),
        TooltipRow('Change: ${d >= 0 ? '+' : ''}${fmt(d)}'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
