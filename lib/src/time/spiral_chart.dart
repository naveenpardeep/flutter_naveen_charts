// Spiral plot: a long time series wound around a spiral to expose cycles.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart3d.dart' show rampColor;
import '../core/chart_canvas.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';

/// How [SpiralChart] draws each value.
enum SpiralStyle {
  /// Radial bars whose length follows the value.
  bars,

  /// Equal-sized cells coloured by value (a "heat spiral").
  heat,
}

/// Spiral chart: values are laid out in time order along a spiral that makes
/// one full turn every [period] points (12 for months, 24 for hours, 7 for
/// weekdays ...). Points at the same angle belong to the same phase of the
/// cycle, so seasonality appears as a pattern that repeats along a radius
/// while a trend appears as growth from turn to turn.
///
/// Hover a point for its label and value.
class SpiralChart extends StatelessWidget {
  const SpiralChart({
    super.key,
    required this.values,
    required this.period,
    this.labels,
    this.phaseLabels,
    this.style = SpiralStyle.bars,
    this.colors = const [Color(0xFF9ECAE1), Color(0xFF3182BD), Color(0xFFE6550D), Color(0xFFA63603)],
    this.innerRadiusRatio = 0.18,
    this.valueFormat,
    this.aspectRatio = 1.1,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 1400),
  });

  /// The series in time order.
  final List<double> values;

  /// Number of points per turn (the length of one cycle).
  final int period;

  /// Label for every point (shown in the tooltip), e.g. `Mar 2024`.
  final List<String>? labels;

  /// Names of the positions inside a cycle, drawn around the outside, e.g.
  /// the twelve month names. Length should equal [period].
  final List<String>? phaseLabels;
  final SpiralStyle style;

  /// Colour ramp from the lowest to the highest value.
  final List<Color> colors;

  /// Radius of the empty hole in the middle, as a share of the full radius.
  final double innerRadiusRatio;
  final String Function(double)? valueFormat;
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
        builder: (p, ptr) => _SpiralPainter(this, t, p, ptr),
      ),
    );
  }
}

class _SpiralPainter extends CustomPainter {
  _SpiralPainter(this.w, this.theme, this.progress, this.pointer);
  final SpiralChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;
  static const double _start = -math.pi / 2; // first phase at 12 o'clock

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.values.length, period = w.period;
    if (n == 0 || period < 2) return;
    final fmt = w.valueFormat ?? formatNumber;

    // ---- 1. geometry: every turn moves outwards by `ringW`
    final c = size.center(Offset.zero);
    final labelRoom = w.phaseLabels == null ? 8.0 : 30.0;
    final outer = math.min(size.width, size.height) / 2 - labelRoom;
    final inner = outer * w.innerRadiusRatio;
    final turns = n / period;
    final ringW = (outer - inner) / math.max(turns, 1.0);
    if (outer < 40) return;
    var lo = w.values.reduce(math.min), hi = w.values.reduce(math.max);
    if (hi - lo < 1e-12) hi = lo + 1;
    final slot = 2 * math.pi / period; // angle of one point

    // radius at which point i starts (grows continuously with i)
    double baseR(int i) => inner + i / period * ringW;
    double angle(int i) => _start + (i % period) * slot;

    // ---- 2. guide: faint radial lines per phase and labels outside
    for (var k = 0; k < period; k++) {
      final a = _start + k * slot;
      canvas.drawLine(c + Offset.fromDirection(a, inner), c + Offset.fromDirection(a, outer), Paint()
        ..color = theme.gridColor.faded(.6)
        ..strokeWidth = 1);
      if (w.phaseLabels != null && k < w.phaseLabels!.length) {
        final mid = a + slot / 2;
        paintText(canvas, w.phaseLabels![k], c + Offset.fromDirection(mid, outer + 8), theme.labelStyle,
            align: Alignment(-math.cos(mid), -math.sin(mid)));
      }
    }

    // ---- 3. hit-test: which point is under the pointer?
    int? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      final d = ptr - c;
      var a = math.atan2(d.dy, d.dx) - _start;
      a = (a % (2 * math.pi) + 2 * math.pi) % (2 * math.pi);
      final phase = (a / slot).floor() % period;
      // the turn follows from the radius
      final turn = ((d.distance - inner) / ringW - phase / period).round();
      final i = turn * period + phase;
      if (i >= 0 && i < n && d.distance >= inner - 4 && d.distance <= outer + 4) hover = i;
    }

    // ---- 4. draw the points (the spiral grows as the animation advances)
    final visible = (n * progress).ceil();
    for (var i = 0; i < visible; i++) {
      final t = (w.values[i] - lo) / (hi - lo);
      final color = rampColor(w.colors, t);
      final r0 = baseR(i);
      final a0 = angle(i);
      // heat: a cell as wide as one turn; bars: length follows the value
      final r1 = w.style == SpiralStyle.heat ? r0 + ringW * .92 : r0 + ringW * (.15 + .85 * t);
      canvas.drawPath(sectorPath(c, r0, r1, a0 + .004, slot - .008), Paint()..color = identical(i, hover) ? Color.lerp(color, Colors.white, .25)! : color);
    }
    canvas.drawCircle(c, inner, Paint()
      ..color = theme.axisColor.faded(.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    // ---- 5. tooltip
    if (hover != null && ptr != null) {
      final i = hover;
      paintTooltip(canvas, size, ptr, theme,
          title: (w.labels != null && i < w.labels!.length) ? w.labels![i] : 'Point ${i + 1}',
          rows: [
            TooltipRow(fmt(w.values[i]), color: rampColor(w.colors, (w.values[i] - lo) / (hi - lo))),
            TooltipRow('Turn ${i ~/ period + 1}, position ${i % period + 1} of $period'),
          ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
