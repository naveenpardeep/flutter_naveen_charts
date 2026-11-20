// Timeline: events along a date axis with cards that avoid overlapping.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';
import 'time_utils.dart';

/// One event on a [TimelineChart]. Give [end] to show a period instead of a
/// single moment.
class TimelineEvent {
  const TimelineEvent(this.date, this.title, {this.description, this.end, this.color});
  final DateTime date;
  final String title;
  final String? description;

  /// End of the period (draws a bar along the axis between [date] and [end]).
  final DateTime? end;
  final Color? color;
}

/// Timeline: events are placed on a date axis in proportion to their date
/// (or evenly, with [evenSpacing]). Cards alternate above and below the axis
/// (left and right when [vertical]) and are stacked in extra rows when they
/// would overlap. Events with an `end` also draw a duration bar on the axis.
///
/// Hover a card or marker for the full details.
class TimelineChart extends StatelessWidget {
  const TimelineChart({
    super.key,
    required this.events,
    this.vertical = false,
    this.evenSpacing = false,
    this.showTicks = true,
    this.maxCardWidth = 150,
    this.cardHeight = 46,
    this.dateFormat,
    this.aspectRatio,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<TimelineEvent> events;

  /// Run top to bottom instead of left to right.
  final bool vertical;

  /// Space events evenly in order instead of by date.
  final bool evenSpacing;

  /// Draw date labels along the axis (ignored with [evenSpacing]).
  final bool showTicks;

  /// Card size limits: width (height when [vertical] it is the across-size).
  final double maxCardWidth, cardHeight;

  /// Formats dates on cards and tooltips (default `Mar 5, 2026`).
  final String Function(DateTime)? dateFormat;

  /// Defaults to 1.8 (horizontal) or 0.85 (vertical).
  final double? aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return chartShell(
      theme: t,
      aspectRatio: aspectRatio ?? (vertical ? .85 : 1.8),
      duration: animationDuration,
      builder: (p, ptr) => _TimelinePainter(this, t, p, ptr),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter(this.w, this.theme, this.progress, this.pointer);
  final TimelineChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final ev = [...w.events]..sort((a, b) => a.date.compareTo(b.date));
    final n = ev.length;
    if (n == 0) return;
    final fmtDate = w.dateFormat ?? formatDate;
    final horizontal = !w.vertical;

    // ---- 1. time range (a little padding so end markers are not on the edge)
    var lo = ev.first.date, hi = ev.first.end ?? ev.first.date;
    for (final e in ev) {
      if (e.date.isBefore(lo)) lo = e.date;
      final end = e.end ?? e.date;
      if (end.isAfter(hi)) hi = end;
    }
    if (!hi.isAfter(lo)) hi = lo.add(const Duration(days: 1));
    final pad = Duration(milliseconds: ((hi.millisecondsSinceEpoch - lo.millisecondsSinceEpoch) * .03).round());
    lo = lo.subtract(pad);
    hi = hi.add(pad);

    // ---- 2. axis geometry. "along" runs with time, "cross" is perpendicular.
    final len = horizontal ? size.width : size.height;
    final cross = horizontal ? size.height : size.width;
    final a0 = 24.0, a1 = len - 24, axis = cross / 2;
    final gutter = horizontal ? 24.0 : 62.0; // room between axis and cards for tick labels
    double alongOf(int i) => w.evenSpacing ? a0 + (i + .5) / n * (a1 - a0) : a0 + timeFraction(ev[i].date, lo, hi) * (a1 - a0);
    Offset pt(double a, double c) => horizontal ? Offset(a, axis + c) : Offset(axis + c, a);

    // ---- 3. size every card, then place it: alternate sides, and push a card
    //         to the next row when it would overlap the previous one
    final titleStyle = TextStyle(color: theme.textColor, fontSize: 12, fontWeight: FontWeight.w700);
    final subStyle = theme.labelStyle.copyWith(fontSize: 10.5);
    String sub(TimelineEvent e) => e.description == null ? fmtDate(e.date) : '${formatShortDate(e.date)} · ${e.description}';
    final cardAcross = horizontal ? w.cardHeight : w.maxCardWidth;
    double cardAlong(TimelineEvent e) => horizontal
        ? (math.max(measureText(e.title, titleStyle).width, measureText(sub(e), subStyle).width) + 16).clamp(70.0, w.maxCardWidth).toDouble()
        : w.cardHeight;
    final maxLevels = math.max(1, ((cross / 2 - gutter) / (cardAcross + 8)).floor());
    final levelEnd = <int, List<double>>{-1: [], 1: []};
    final rects = <Rect>[];
    final sides = <int>[];
    for (var i = 0; i < n; i++) {
      final side = i.isEven ? 1 : -1; // +1 = below / right of the axis
      final ca = cardAlong(ev[i]);
      final start = (alongOf(i) - ca / 2).clamp(a0 - 12, math.max(a0 - 12, a1 + 12 - ca)).toDouble();
      final ends = levelEnd[side]!;
      var level = ends.indexWhere((e) => start >= e + 6);
      if (level < 0) {
        if (ends.length < maxLevels) {
          ends.add(0);
          level = ends.length - 1;
        } else {
          // no free row left: reuse the one that ends earliest (cards may overlap)
          level = ends.indexOf(ends.reduce(math.min));
        }
      }
      ends[level] = start + ca;
      final off = gutter + level * (cardAcross + 8);
      final c0 = side > 0 ? off : -off - cardAcross;
      rects.add(horizontal ? Rect.fromLTWH(start, axis + c0, ca, cardAcross) : Rect.fromLTWH(axis + c0, start, cardAcross, ca));
      sides.add(side);
    }

    // ---- 4. hit-test cards and markers
    int? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      for (var i = 0; i < n; i++) {
        if (rects[i].contains(ptr) || (pt(alongOf(i), 0) - ptr).distance < 9) hover = i;
      }
    }
    Color colorOf(int i) => ev[i].color ?? theme.colorAt(i);

    // ---- 5. axis line and ticks
    canvas.drawLine(pt(a0 - 12, 0), pt(a1 + 12, 0), Paint()
      ..color = theme.axisColor
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round);
    if (w.showTicks && !w.evenSpacing) {
      for (final t in niceTimeTicks(lo, hi)) {
        final a = a0 + timeFraction(t.date, lo, hi) * (a1 - a0);
        canvas.drawLine(pt(a, -4), pt(a, 4), Paint()
          ..color = theme.axisColor
          ..strokeWidth = 1.4);
        if (horizontal) {
          paintText(canvas, t.label, pt(a, 7), theme.labelStyle.copyWith(fontSize: 10), align: Alignment.topCenter);
        } else {
          paintText(canvas, t.label, pt(a, -8), theme.labelStyle.copyWith(fontSize: 10), align: Alignment.centerRight, maxWidth: gutter - 10);
        }
      }
    }

    // ---- 6. duration bars, stems, markers and cards (cards fade in one by one)
    for (var i = 0; i < n; i++) {
      final reveal = (progress * (n + 2) - i).clamp(0.0, 1.0).toDouble();
      if (reveal <= 0) continue;
      final color = colorOf(i);
      final a = alongOf(i);
      final active = hover == null || hover == i;
      final e = ev[i];
      if (e.end != null && !w.evenSpacing) {
        final b = a0 + timeFraction(e.end!, lo, hi) * (a1 - a0);
        canvas.drawLine(pt(a, 0), pt(b, 0), Paint()
          ..color = color.faded(.55 * reveal)
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round);
      }
      // stem from the marker to the card edge
      final r = rects[i];
      final edge = horizontal ? Offset(a, sides[i] > 0 ? r.top : r.bottom) : Offset(sides[i] > 0 ? r.left : r.right, a);
      canvas.drawLine(pt(a, 0), edge, Paint()
        ..color = color.faded(.7 * reveal)
        ..strokeWidth = 1.4);
      canvas.drawCircle(pt(a, 0), 6.5 * reveal, Paint()..color = theme.surface);
      canvas.drawCircle(pt(a, 0), 5 * reveal, Paint()..color = color);
      // card
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(8));
      canvas.drawRRect(rr, Paint()..color = theme.surface.faded(reveal));
      canvas.drawRRect(rr, Paint()
        ..color = color.faded((active ? 1 : .35) * reveal)
        ..style = PaintingStyle.stroke
        ..strokeWidth = hover == i ? 2.6 : 1.4);
      canvas.drawRect(Rect.fromLTWH(r.left + 1, r.top + 8, 3.5, r.height - 16), Paint()..color = color.faded(reveal)); // accent bar
      paintText(canvas, e.title, Offset(r.left + 11, r.top + r.height * .34), titleStyle.copyWith(color: theme.textColor.faded(reveal)),
          align: Alignment.centerLeft, maxWidth: r.width - 16);
      paintText(canvas, sub(e), Offset(r.left + 11, r.top + r.height * .72), subStyle.copyWith(color: theme.labelStyle.color!.faded(reveal)),
          align: Alignment.centerLeft, maxWidth: r.width - 16);
    }

    // ---- 7. tooltip
    if (hover != null && ptr != null) {
      final e = ev[hover];
      paintTooltip(canvas, size, ptr, theme, title: e.title, rows: [
        TooltipRow(e.end == null ? fmtDate(e.date) : '${fmtDate(e.date)} → ${fmtDate(e.end!)}', color: colorOf(hover)),
        if (e.end != null) TooltipRow('${e.end!.difference(e.date).inDays} days'),
        if (e.description != null) TooltipRow(e.description!),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
