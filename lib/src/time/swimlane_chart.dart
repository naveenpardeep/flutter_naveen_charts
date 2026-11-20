// Swimlane: work items on a shared date axis, grouped into lanes.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';
import 'time_utils.dart';

/// An item in a lane. With [end] it is a bar (a task); without it, a
/// diamond milestone.
class SwimlaneItem {
  const SwimlaneItem(this.lane, this.start, {this.end, this.label, this.color});

  /// Name of the lane (must appear in `SwimlaneChart.lanes`).
  final String lane;
  final DateTime start;
  final DateTime? end;
  final String? label;
  final Color? color;
  bool get isMilestone => end == null;
}

/// An item with the sub-row it was packed into.
class _Placed {
  _Placed(this.item, this.row, this.lane, this.index);
  final SwimlaneItem item;
  final int row, lane, index;
}

/// Swimlane chart: one horizontal lane per team / category on a shared time
/// axis. Tasks (bars) and milestones (diamonds) in the same lane that overlap
/// in time are stacked into sub-rows, so nothing is hidden. Lane height grows
/// with the number of sub-rows.
///
/// Hover an item for dates and duration.
class SwimlaneChart extends StatelessWidget {
  const SwimlaneChart({
    super.key,
    required this.lanes,
    required this.items,
    this.rowHeight = 26,
    this.showToday = false,
    this.today,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  /// Lane names, top to bottom.
  final List<String> lanes;
  final List<SwimlaneItem> items;

  /// Height of one sub-row.
  final double rowHeight;

  /// Draw a vertical line at [today].
  final bool showToday;

  /// Defaults to `DateTime.now()`.
  final DateTime? today;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    if (items.isEmpty) return const SizedBox.shrink();

    // ---- time range
    var lo = items.first.start, hi = items.first.end ?? items.first.start;
    for (final i in items) {
      if (i.start.isBefore(lo)) lo = i.start;
      final e = i.end ?? i.start;
      if (e.isAfter(hi)) hi = e;
    }
    if (!hi.isAfter(lo)) hi = lo.add(const Duration(days: 1));
    final span = hi.millisecondsSinceEpoch - lo.millisecondsSinceEpoch;
    lo = lo.subtract(Duration(milliseconds: (span * .02).round()));
    hi = hi.add(Duration(milliseconds: (span * .02).round()));
    final milestoneSpan = ((hi.millisecondsSinceEpoch - lo.millisecondsSinceEpoch) * .06).round();

    // ---- pack each lane greedily: an item goes into the first sub-row whose
    //      last item has already ended (milestones reserve a little room for their label)
    final placed = <_Placed>[];
    final rowsPerLane = List<int>.filled(lanes.length, 1);
    for (var l = 0; l < lanes.length; l++) {
      final inLane = [for (var k = 0; k < items.length; k++) if (items[k].lane == lanes[l]) k]
        ..sort((a, b) => items[a].start.compareTo(items[b].start));
      final rowEnd = <int>[]; // end time (ms) of the last item in each sub-row
      for (final k in inLane) {
        final it = items[k];
        final startMs = it.start.millisecondsSinceEpoch;
        final endMs = it.end?.millisecondsSinceEpoch ?? (startMs + milestoneSpan);
        var row = rowEnd.indexWhere((e) => startMs >= e);
        if (row < 0) {
          rowEnd.add(endMs);
          row = rowEnd.length - 1;
        } else {
          rowEnd[row] = endMs;
        }
        placed.add(_Placed(it, row, l, k));
      }
      rowsPerLane[l] = math.max(1, rowEnd.length);
    }
    final height = rowsPerLane.fold<double>(0, (a, r) => a + r * rowHeight + 14) + 34;
    return SizedBox(
      height: height,
      child: chartShellBox(t, animationDuration, (p, ptr) => _SwimlanePainter(this, placed, rowsPerLane, lo, hi, t, p, ptr)),
    );
  }
}

class _SwimlanePainter extends CustomPainter {
  _SwimlanePainter(this.w, this.placed, this.rowsPerLane, this.lo, this.hi, this.theme, this.progress, this.pointer);
  final SwimlaneChart w;
  final List<_Placed> placed;
  final List<int> rowsPerLane;
  final DateTime lo, hi;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final labelW = w.lanes.map((l) => measureText(l, theme.labelStyle).width).fold<double>(0, math.max) + 10;
    final plot = Rect.fromLTRB(labelW + 8, 4, size.width - 10, size.height - 26);
    if (plot.width < 40) return;
    double x(DateTime d) => plot.left + timeFraction(d, lo, hi) * plot.width;

    // ---- lane backgrounds and labels
    final laneTop = <double>[];
    var y = plot.top;
    for (var l = 0; l < w.lanes.length; l++) {
      final h = rowsPerLane[l] * w.rowHeight + 14;
      laneTop.add(y);
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, h), Paint()..color = theme.axisColor.faded(l.isEven ? .07 : .0));
      paintText(canvas, w.lanes[l], Offset(labelW, y + h / 2), theme.labelStyle.copyWith(color: theme.textColor, fontWeight: FontWeight.w600),
          align: Alignment.centerRight, maxWidth: labelW);
      y += h;
    }

    // ---- date axis with grid lines
    for (final t in niceTimeTicks(lo, hi)) {
      final tx = x(t.date);
      canvas.drawLine(Offset(tx, plot.top), Offset(tx, y), Paint()
        ..color = theme.gridColor
        ..strokeWidth = 1);
      paintText(canvas, t.label, Offset(tx, y + 6), theme.labelStyle, align: Alignment.topCenter);
    }
    if (w.showToday) {
      final td = w.today ?? DateTime.now();
      if (td.isAfter(lo) && td.isBefore(hi)) {
        canvas.drawLine(Offset(x(td), plot.top), Offset(x(td), y), Paint()
          ..color = const Color(0xFFE53935)
          ..strokeWidth = 1.6);
        paintText(canvas, 'Today', Offset(x(td), plot.top), theme.labelStyle.copyWith(color: const Color(0xFFE53935)), align: Alignment.topCenter);
      }
    }

    // ---- items
    Rect rectOf(_Placed p) {
      final top = laneTop[p.lane] + 7 + p.row * w.rowHeight;
      final x0 = x(p.item.start);
      final x1 = p.item.end == null ? x0 : x(p.item.end!);
      return p.item.isMilestone
          ? Rect.fromCenter(center: Offset(x0, top + w.rowHeight / 2), width: 14, height: 14)
          : Rect.fromLTRB(x0, top + 3, math.max(x1, x0 + 4), top + w.rowHeight - 3);
    }

    _Placed? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      for (final p in placed) {
        if (rectOf(p).inflate(3).contains(ptr)) hover = p;
      }
    }
    for (final p in placed) {
      final reveal = (progress * 1.5 - p.item.start.difference(lo).inMilliseconds / math.max(1, hi.difference(lo).inMilliseconds) * .5).clamp(0.0, 1.0).toDouble();
      if (reveal <= 0) continue;
      final color = p.item.color ?? theme.colorAt(p.lane);
      final r = rectOf(p);
      final hot = identical(p, hover);
      if (p.item.isMilestone) {
        // a diamond is a square rotated by 45 degrees
        final c = r.center, s = 8.0 * reveal;
        canvas.drawPath(
            Path()
              ..moveTo(c.dx, c.dy - s)
              ..lineTo(c.dx + s, c.dy)
              ..lineTo(c.dx, c.dy + s)
              ..lineTo(c.dx - s, c.dy)
              ..close(),
            Paint()..color = hot ? Color.lerp(color, Colors.white, .2)! : color);
        if (p.item.label != null && progress > .99) {
          paintText(canvas, p.item.label!, Offset(c.dx + 12, c.dy), theme.labelStyle.copyWith(color: theme.textColor), align: Alignment.centerLeft);
        }
      } else {
        final rr = RRect.fromRectAndRadius(Rect.fromLTRB(r.left, r.top, r.left + r.width * reveal, r.bottom), const Radius.circular(6));
        canvas.drawRRect(rr, Paint()..color = hot ? Color.lerp(color, Colors.white, .2)! : color);
        if (p.item.label != null && progress > .99 && r.width > 36) {
          paintText(canvas, p.item.label!, Offset(r.left + 7, r.center.dy), TextStyle(color: contrastOn(color), fontSize: 11, fontWeight: FontWeight.w600),
              align: Alignment.centerLeft, maxWidth: r.width - 12);
        }
      }
    }

    // ---- tooltip
    if (hover != null && ptr != null) {
      final it = hover.item;
      paintTooltip(canvas, size, ptr, theme, title: it.label ?? w.lanes[hover.lane], rows: [
        TooltipRow(w.lanes[hover.lane], color: it.color ?? theme.colorAt(hover.lane)),
        TooltipRow(it.end == null ? formatDate(it.start) : '${formatDate(it.start)} → ${formatDate(it.end!)}'),
        if (it.end != null) TooltipRow('${it.end!.difference(it.start).inDays} days'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
