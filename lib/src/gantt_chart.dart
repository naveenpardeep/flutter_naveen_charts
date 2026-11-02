import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';

class GanttTask {
  const GanttTask(this.label, this.start, this.end, {this.progress = 0, this.color});
  final String label;
  final DateTime start;
  final DateTime end;

  /// 0..1 completed share, drawn as a darker fill.
  final double progress;
  final Color? color;
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

/// Timeline / project schedule.
class GanttChart extends StatelessWidget {
  const GanttChart({
    super.key,
    required this.tasks,
    this.rowHeight = 34,
    this.showToday = true,
    this.today,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<GanttTask> tasks;
  final double rowHeight;
  final bool showToday;

  /// Defaults to `DateTime.now()`.
  final DateTime? today;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return SizedBox(
      height: tasks.length * rowHeight + 32,
      child: ChartCanvas(
        duration: animationDuration,
        builder: (p, ptr) => _GanttPainter(this, t, p, ptr, today ?? DateTime.now()),
      ),
    );
  }
}

class _GanttPainter extends CustomPainter {
  _GanttPainter(this.w, this.theme, this.progress, this.pointer, this.today);
  final GanttChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;
  final DateTime today;

  @override
  void paint(Canvas canvas, Size size) {
    final tasks = w.tasks;
    if (tasks.isEmpty) return;
    var minMs = tasks.first.start.millisecondsSinceEpoch;
    var maxMs = tasks.first.end.millisecondsSinceEpoch;
    for (final t in tasks) {
      minMs = math.min(minMs, t.start.millisecondsSinceEpoch);
      maxMs = math.max(maxMs, t.end.millisecondsSinceEpoch);
    }
    final padMs = math.max(86400000, ((maxMs - minMs) * 0.02).round());
    minMs -= padMs;
    maxMs += padMs;
    final labelW = tasks
        .map((t) => measureText(t.label, theme.labelStyle).width)
        .fold<double>(0, math.max);
    final plot = Rect.fromLTRB(labelW + 14, 4, size.width - 12, size.height - 24);
    if (plot.width <= 0) return;
    double sx(DateTime d) =>
        plot.left + (d.millisecondsSinceEpoch - minMs) / (maxMs - minMs) * plot.width;
    final rowH = plot.height / tasks.length;

    final totalDays = (maxMs - minMs) / 86400000;
    final step = const [1, 2, 5, 7, 14, 30, 60, 90, 180, 365]
        .firstWhere((s) => totalDays / s <= 8, orElse: () => 730);
    final first = DateTime.fromMillisecondsSinceEpoch(minMs);
    final grid = Paint()
      ..color = theme.gridColor
      ..strokeWidth = 1;
    for (var k = 0;; k++) {
      final d = DateTime(first.year, first.month, first.day + k * step);
      if (d.millisecondsSinceEpoch > maxMs) break;
      if (d.millisecondsSinceEpoch < minMs) continue;
      canvas.drawLine(Offset(sx(d), plot.top), Offset(sx(d), plot.bottom), grid);
      paintText(canvas, _fmtDate(d), Offset(sx(d), plot.bottom + 6), theme.labelStyle,
          align: Alignment.topCenter);
    }

    int? hover;
    final ptr = pointer;
    if (ptr != null && plot.inflate(6).contains(ptr)) {
      hover = ((ptr.dy - plot.top) / rowH).floor().clamp(0, tasks.length - 1).toInt();
    }
    for (var i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      final top = plot.top + i * rowH;
      if (i.isOdd || hover == i) {
        canvas.drawRect(Rect.fromLTWH(0, top, size.width, rowH),
            Paint()..color = theme.axisColor.faded(hover == i ? .16 : .06));
      }
      paintText(canvas, t.label, Offset(plot.left - 8, top + rowH / 2),
          theme.labelStyle.copyWith(color: theme.textColor),
          align: Alignment.centerRight, maxWidth: labelW + 2);
      final color = t.color ?? theme.colorAt(i);
      final x0 = sx(t.start);
      final x1 = math.max(sx(t.end), x0 + 4);
      final bar = Rect.fromLTRB(x0, top + rowH * .22, x0 + (x1 - x0) * progress, top + rowH * .78);
      final rr = RRect.fromRectAndRadius(bar, const Radius.circular(5));
      canvas.drawRRect(rr, Paint()..color = color.faded(.35));
      if (t.progress > 0) {
        final done = Rect.fromLTRB(bar.left, bar.top,
            bar.left + bar.width * t.progress.clamp(0.0, 1.0), bar.bottom);
        canvas.save();
        canvas.clipRRect(rr);
        canvas.drawRect(done, Paint()..color = color);
        canvas.restore();
      }
    }
    if (w.showToday && today.millisecondsSinceEpoch > minMs && today.millisecondsSinceEpoch < maxMs) {
      final x = sx(today);
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom),
          Paint()
            ..color = const Color(0xFFE53935)
            ..strokeWidth = 1.5);
      paintText(canvas, 'Today', Offset(x, plot.top), theme.labelStyle.copyWith(color: const Color(0xFFE53935)),
          align: Alignment.topCenter);
    }
    if (hover != null && ptr != null && progress >= 1) {
      final t = tasks[hover];
      paintTooltip(canvas, size, ptr, theme, title: t.label, rows: [
        TooltipRow('${_fmtDate(t.start)} – ${_fmtDate(t.end)}'),
        TooltipRow('${t.end.difference(t.start).inDays} days'),
        TooltipRow('${(t.progress * 100).round()}% complete', color: t.color ?? theme.colorAt(hover)),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
