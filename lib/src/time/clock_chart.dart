// Clock chart: a 24-hour (or any cyclic) profile around a clock face.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_canvas.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/legend.dart';
import '../core/plot_frame.dart';

/// A named series of one value per slot (usually 24 hours).
class ClockSeries {
  const ClockSeries(this.name, this.values, {this.color});
  final String name;
  final List<double> values;
  final Color? color;
}

/// How [ClockChart] draws the values.
enum ClockStyle { bars, line, area }

/// Clock chart: values for every slot of a day (24 by default) arranged
/// around a clock face, midnight at the top and time running clockwise. Shows
/// at a glance when things peak - traffic, sales, sleep, energy use. Add
/// several series to compare (weekday vs weekend).
///
/// Hover a slot for the values of every series.
class ClockChart extends StatelessWidget {
  const ClockChart({
    super.key,
    required this.series,
    this.labels,
    this.style = ClockStyle.bars,
    this.innerRadiusRatio = 0.22,
    this.labelEvery,
    this.markerIndex,
    this.showPeak = true,
    this.centerText,
    this.valueFormat,
    this.showLegend = true,
    this.aspectRatio = 1.1,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 1000),
  });
  final List<ClockSeries> series;

  /// Label per slot; default `0`, `1`, ... (hours for 24 slots).
  final List<String>? labels;
  final ClockStyle style;
  final double innerRadiusRatio;

  /// Show a label every n-th slot (default: about 8 labels around the clock).
  final int? labelEvery;

  /// Slot to mark with a hand, e.g. the current hour.
  final int? markerIndex;

  /// Write the highest value next to its slot.
  final bool showPeak;

  /// Text in the middle of the clock.
  final String? centerText;
  final String Function(double)? valueFormat;
  final bool showLegend;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return chartShell(
      theme: t,
      aspectRatio: aspectRatio,
      duration: animationDuration,
      legend: showLegend ? [for (var i = 0; i < series.length; i++) LegendItem(series[i].name, series[i].color ?? t.colorAt(i))] : null,
      builder: (p, ptr) => _ClockPainter(this, t, p, ptr),
    );
  }
}

class _ClockPainter extends CustomPainter {
  _ClockPainter(this.w, this.theme, this.progress, this.pointer);
  final ClockChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;
  static const double _start = -math.pi / 2; // slot 0 at 12 o'clock

  @override
  void paint(Canvas canvas, Size size) {
    if (w.series.isEmpty) return;
    final n = w.series.map((s) => s.values.length).reduce(math.max);
    if (n < 3) return;
    final fmt = w.valueFormat ?? formatNumber;
    final c = size.center(Offset.zero);
    final R = math.min(size.width, size.height) / 2 - 26;
    if (R < 40) return;
    final inner = R * w.innerRadiusRatio;
    final slot = 2 * math.pi / n;
    double v(ClockSeries s, int i) => i < s.values.length ? s.values[i] : 0;

    // ---- 1. radial scale: value -> radius
    var maxV = 0.0;
    for (final s in w.series) {
      for (final x in s.values) {
        maxV = math.max(maxV, x);
      }
    }
    final scale = NiceScale.compute(0, maxV <= 0 ? 1 : maxV, includeZero: true, maxTicks: 4);
    double radius(double value) => inner + value / scale.max * (R - inner);

    // ---- 2. clock face: rings with values, hour ticks and labels
    for (final t in scale.ticks) {
      canvas.drawCircle(c, radius(t), Paint()
        ..color = theme.gridColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
      if (t > 0) paintText(canvas, fmt(t), c + Offset(2, -radius(t)), theme.labelStyle.copyWith(fontSize: 9), align: Alignment.bottomLeft);
    }
    final every = w.labelEvery ?? math.max(1, (n / 8).round());
    for (var i = 0; i < n; i++) {
      final a = _start + i * slot;
      canvas.drawLine(c + Offset.fromDirection(a, inner), c + Offset.fromDirection(a, R), Paint()
        ..color = theme.gridColor.faded(.5)
        ..strokeWidth = .8);
      if (i % every == 0) {
        final mid = a; // label at the start of the slot (the hour mark)
        paintText(canvas, (w.labels != null && i < w.labels!.length) ? w.labels![i] : '$i', c + Offset.fromDirection(mid, R + 10),
            theme.labelStyle.copyWith(color: theme.textColor), align: Alignment(-math.cos(mid) * .6, -math.sin(mid) * .6));
      }
    }

    // ---- 3. hit-test the slot under the pointer
    int? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      final d = ptr - c;
      if (d.distance >= inner * .6 && d.distance <= R + 8) {
        hover = ((((math.atan2(d.dy, d.dx) - _start) % (2 * math.pi)) + 2 * math.pi) % (2 * math.pi) / slot).floor() % n;
      }
    }
    if (hover != null) {
      canvas.drawPath(sectorPath(c, inner, R, _start + hover * slot, slot), Paint()..color = theme.axisColor.faded(.14));
    }

    // ---- 4. data
    final m = w.series.length;
    for (var si = 0; si < m; si++) {
      final s = w.series[si];
      final color = s.color ?? theme.colorAt(si);
      switch (w.style) {
        case ClockStyle.bars:
          // series share each slot side by side
          final sub = slot * .8 / m;
          for (var i = 0; i < n; i++) {
            final a0 = _start + i * slot + slot * .1 + si * sub;
            canvas.drawPath(sectorPath(c, inner, inner + (radius(v(s, i)) - inner) * progress, a0, sub - .004), Paint()..color = color);
          }
        case ClockStyle.line:
        case ClockStyle.area:
          // points at slot centres, joined into a smooth closed curve
          final pts = [for (var i = 0; i < n; i++) c + Offset.fromDirection(_start + (i + .5) * slot, inner + (radius(v(s, i)) - inner) * progress)];
          final path = _closedCurve(pts);
          if (w.style == ClockStyle.area) canvas.drawPath(path, Paint()..color = color.faded(.22));
          canvas.drawPath(path, Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeJoin = StrokeJoin.round);
      }
    }
    canvas.drawCircle(c, inner, Paint()
      ..color = theme.surface
      ..style = PaintingStyle.fill);
    canvas.drawCircle(c, inner, Paint()
      ..color = theme.axisColor.faded(.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
    if (w.centerText != null) {
      paintText(canvas, w.centerText!, c, TextStyle(color: theme.textColor, fontSize: math.min(20.0, inner * .5), fontWeight: FontWeight.bold), maxWidth: inner * 1.8);
    }

    // ---- 5. peak label and marker hand
    if (w.showPeak && progress > .99) {
      var bestV = -1.0;
      var bi = 0;
      for (final s in w.series) {
        for (var i = 0; i < n; i++) {
          if (v(s, i) > bestV) {
            bestV = v(s, i);
            bi = i;
          }
        }
      }
      final a = _start + (bi + .5) * slot;
      paintText(canvas, fmt(bestV), c + Offset.fromDirection(a, radius(bestV) + 8), theme.labelStyle.copyWith(color: theme.textColor, fontWeight: FontWeight.bold),
          align: Alignment(-math.cos(a), -math.sin(a)));
    }
    if (w.markerIndex != null) {
      final a = _start + (w.markerIndex! + .5) * slot;
      canvas.drawLine(c, c + Offset.fromDirection(a, R), Paint()
        ..color = const Color(0xFFE53935)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round);
      canvas.drawCircle(c, 4, Paint()..color = const Color(0xFFE53935));
    }

    // ---- 6. tooltip
    if (hover != null && ptr != null) {
      paintTooltip(canvas, size, ptr, theme,
          title: (w.labels != null && hover < w.labels!.length) ? w.labels![hover] : 'Slot $hover',
          rows: [for (var si = 0; si < m; si++) TooltipRow('${w.series[si].name}: ${fmt(v(w.series[si], hover))}', color: w.series[si].color ?? theme.colorAt(si))]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Smooth closed curve through [pts] (Catmull-Rom converted to Beziers).
Path _closedCurve(List<Offset> pts) {
  final n = pts.length;
  final path = Path()..moveTo(pts[0].dx, pts[0].dy);
  for (var i = 0; i < n; i++) {
    final p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n];
    final c1 = p1 + (p2 - p0) / 6, c2 = p2 - (p3 - p1) / 6;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path..close();
}
