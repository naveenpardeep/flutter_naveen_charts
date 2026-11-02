import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';

const _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// GitHub-style contribution calendar: one column per week, one row per day.
class CalendarHeatmap extends StatelessWidget {
  const CalendarHeatmap({
    super.key,
    required this.data,
    this.endDate,
    this.weeks = 26,
    this.lowColor = const Color(0xFFC6E48B),
    this.highColor = const Color(0xFF196127),
    this.emptyColor,
    this.showMonthLabels = true,
    this.showDayLabels = true,
    this.cellGap = 2,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 800),
  });

  /// Value per day (the time of day is ignored).
  final Map<DateTime, double> data;

  /// Last day shown; defaults to the latest key in [data] (or today).
  final DateTime? endDate;
  final int weeks;
  final Color lowColor;
  final Color highColor;

  /// Cells without data; defaults to the theme grid color.
  final Color? emptyColor;
  final bool showMonthLabels;
  final bool showDayLabels;
  final double cellGap;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    DateTime end = endDate ?? DateTime.now();
    if (endDate == null && data.isNotEmpty) {
      end = data.keys.reduce((a, b) => a.isAfter(b) ? a : b);
    }
    return AspectRatio(
      aspectRatio: (weeks + (showDayLabels ? 3 : 1)) / (showMonthLabels ? 8.6 : 7.4),
      child: ChartCanvas(
        duration: animationDuration,
        builder: (p, ptr) =>
            _CalPainter(this, t, p, ptr, DateTime(end.year, end.month, end.day)),
      ),
    );
  }
}

class _CalPainter extends CustomPainter {
  _CalPainter(this.w, this.theme, this.progress, this.pointer, this.end);
  final CalendarHeatmap w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;
  final DateTime end;

  int _key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  @override
  void paint(Canvas canvas, Size size) {
    final values = <int, double>{for (final e in w.data.entries) _key(e.key): e.value};
    var lo = double.infinity, hi = -double.infinity;
    for (final v in values.values) {
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }
    final leftW = w.showDayLabels ? 26.0 : 2.0;
    final topH = w.showMonthLabels ? 16.0 : 2.0;
    final cell = math.min((size.width - leftW) / w.weeks, (size.height - topH) / 7);
    if (cell <= 2) return;
    final start = DateTime(end.year, end.month, end.day - end.weekday % 7 - (w.weeks - 1) * 7);
    final empty = w.emptyColor ?? theme.gridColor;

    if (w.showDayLabels) {
      const names = {1: 'Mon', 3: 'Wed', 5: 'Fri'};
      names.forEach((row, name) {
        paintText(canvas, name, Offset(leftW - 4, topH + (row + .5) * cell),
            theme.labelStyle.copyWith(fontSize: 9), align: Alignment.centerRight);
      });
    }
    int lastMonth = -1;
    DateTime? hoverDate;
    final ptr = pointer;
    for (var col = 0; col < w.weeks; col++) {
      for (var row = 0; row < 7; row++) {
        final d = DateTime(start.year, start.month, start.day + col * 7 + row);
        if (d.isAfter(end)) continue;
        if (row == 0 && w.showMonthLabels && d.month != lastMonth) {
          paintText(canvas, _mon[d.month - 1], Offset(leftW + col * cell, 2),
              theme.labelStyle.copyWith(fontSize: 10), align: Alignment.topLeft);
          lastMonth = d.month;
        }
        final rect = Rect.fromLTWH(leftW + col * cell, topH + row * cell, cell, cell)
            .deflate(w.cellGap / 2);
        final v = values[_key(d)];
        Color color = empty;
        if (v != null) {
          final t = hi == lo ? 1.0 : (v - lo) / (hi - lo);
          color = Color.lerp(w.lowColor, w.highColor, t)!;
        }
        canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(cell * .18)),
            Paint()..color = color.faded(progress));
        if (ptr != null && rect.inflate(w.cellGap / 2).contains(ptr)) hoverDate = d;
      }
    }
    if (hoverDate != null && ptr != null && progress >= 1) {
      final v = values[_key(hoverDate)];
      paintTooltip(canvas, size, ptr, theme,
          title: '${_mon[hoverDate.month - 1]} ${hoverDate.day}, ${hoverDate.year}',
          rows: [TooltipRow(v == null ? 'No data' : formatNumber(v))]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
