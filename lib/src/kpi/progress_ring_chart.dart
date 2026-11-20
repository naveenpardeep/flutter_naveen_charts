// Progress ring: a single KPI against its goal.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart3d.dart' show shade;
import '../core/chart_canvas.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../gauge_chart.dart' show GaugeSegment;

/// Progress ring: one number against its [max] (goal) as a ring, with the
/// value in the middle. Unlike [RadialBarChart] it shows a single KPI and
/// supports going past the goal (a second, darker lap), a segmented style,
/// colour [zones], and a small change-vs-previous line.
///
/// Typical uses: sales vs quota, steps vs daily goal, storage used.
class ProgressRingChart extends StatelessWidget {
  const ProgressRingChart({
    super.key,
    required this.value,
    this.max = 100,
    this.label,
    this.unit = '',
    this.previous,
    this.higherIsBetter = true,
    this.zones = const [],
    this.color,
    this.thickness = 16,
    this.segments = 0,
    this.showPercent = true,
    this.valueFormat,
    this.goodColor = const Color(0xFF2E7D32),
    this.badColor = const Color(0xFFC62828),
    this.aspectRatio = 1,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 1000),
  });

  /// Current value.
  final double value;

  /// The goal; the ring is full at this value.
  final double max;

  /// Caption inside the ring, under the value.
  final String? label;
  final String unit;

  /// Previous period's value; shows an up / down change under the ring text.
  final double? previous;

  /// Decides whether a rise in [previous] is drawn good (green) or bad (red).
  final bool higherIsBetter;

  /// Colour by value; the first zone whose `upTo` is at or above the value wins.
  final List<GaugeSegment> zones;

  /// Ring colour when no zone applies.
  final Color? color;
  final double thickness;

  /// 0 = continuous ring, n > 0 = n steps.
  final int segments;

  /// Show "72% of goal".
  final bool showPercent;
  final String Function(double)? valueFormat;
  final Color goodColor, badColor;
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
        interactive: false,
        builder: (p, ptr) => _RingPainter(this, t, p),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.w, this.theme, this.progress);
  final ProgressRingChart w;
  final ChartTheme theme;
  final double progress;
  static const double _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (w.max <= 0) return;
    final fmt = w.valueFormat ?? formatNumber;
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - w.thickness / 2 - 4;
    if (r < 20) return;
    final rect = Rect.fromCircle(center: c, radius: r);
    final frac = w.value / w.max;

    // ---- 1. colour: zone by value, otherwise the chosen colour
    Color color = w.color ?? theme.colorAt(0);
    for (final z in w.zones) {
      color = z.color;
      if (w.value <= z.upTo) break;
    }

    // ---- 2. track
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w.thickness
      ..color = theme.gridColor;
    Paint arc(Color col, {StrokeCap cap = StrokeCap.round}) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w.thickness
      ..strokeCap = cap
      ..color = col;

    if (w.segments > 0) {
      // ---- 3a. segmented: n steps with small gaps, filled up to the value
      final gap = .09;
      final each = 2 * math.pi / w.segments - gap;
      final filled = frac.clamp(0.0, 1.0) * w.segments * progress;
      for (var i = 0; i < w.segments; i++) {
        final a0 = _start + i * (each + gap) + gap / 2;
        canvas.drawArc(rect, a0, each, false, track..strokeCap = StrokeCap.butt);
        final a = (filled - i).clamp(0.0, 1.0).toDouble();
        if (a > 0) canvas.drawArc(rect, a0, each * a, false, arc(color, cap: StrokeCap.butt));
      }
    } else {
      // ---- 3b. continuous: full track, the value arc, and a darker second lap
      //          when the goal is exceeded
      canvas.drawCircle(c, r, track);
      final main = frac.clamp(0.0, 1.0).toDouble() * 2 * math.pi * progress;
      if (main > 0) canvas.drawArc(rect, _start, main, false, arc(color));
      if (frac > 1) {
        final over = (frac - 1).clamp(0.0, 1.0).toDouble() * 2 * math.pi * progress;
        canvas.drawArc(rect, _start, over, false, arc(shade(color, .68)));
      }
    }

    // ---- 4. text in the middle: value, caption, percentage, change
    final shown = w.value * progress;
    final fs = math.min(34.0, r * .42);
    final lines = <MapEntry<String, TextStyle>>[
      MapEntry('${fmt(shown)}${w.unit}', TextStyle(color: theme.textColor, fontSize: fs, fontWeight: FontWeight.bold)),
      if (w.label != null) MapEntry(w.label!, theme.labelStyle.copyWith(fontSize: math.min(13.0, fs * .42))),
      if (w.showPercent) MapEntry('${(frac * 100).round()}% of goal', theme.labelStyle.copyWith(fontSize: math.min(12.0, fs * .38))),
    ];
    double h(MapEntry<String, TextStyle> e) => (e.value.fontSize ?? 12) * 1.2;
    var total = lines.fold<double>(0, (a, e) => a + h(e));
    if (w.previous != null) total += 16;
    var y = c.dy - total / 2;
    for (final e in lines) {
      paintText(canvas, e.key, Offset(c.dx, y + h(e) / 2), e.value, maxWidth: r * 1.7);
      y += h(e);
    }
    if (w.previous != null && w.previous != 0) {
      final change = (w.value - w.previous!) / w.previous!.abs() * 100;
      final good = w.higherIsBetter ? change >= 0 : change <= 0;
      paintText(canvas, '${change >= 0 ? '▲' : '▼'} ${change.abs().toStringAsFixed(1)}%', Offset(c.dx, y + 8),
          TextStyle(color: good ? w.goodColor : w.badColor, fontSize: 12, fontWeight: FontWeight.w700));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
