// Thermometer: a value shown as mercury rising in a glass tube.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_canvas.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';

/// A colour band of a [ThermometerChart]: the mercury takes the colour of the
/// first zone whose [upTo] is at or above the value.
class ThermometerZone {
  const ThermometerZone(this.upTo, this.color);
  final double upTo;
  final Color color;
}

/// Thermometer chart: a glass tube with a bulb and a scale. Mercury height
/// follows the value; its colour can change by [zones] (cold / normal / hot).
/// Add a [target] marker, and a second scale on the right with
/// [secondaryConvert] (for example Celsius on the left, Fahrenheit on the right).
///
/// Works for any "level" KPI - temperature, fundraising, stock, capacity.
/// Hover the tube to read the value at any height.
class ThermometerChart extends StatelessWidget {
  const ThermometerChart({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 100,
    this.unit = '',
    this.label,
    this.zones = const [],
    this.color,
    this.target,
    this.targetLabel,
    this.ticks = 6,
    this.minorTicks = 4,
    this.secondaryConvert,
    this.secondaryFormat,
    this.valueFormat,
    this.aspectRatio = 0.55,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 1100),
  });

  /// Current reading.
  final double value;

  /// Value at the bottom and at the top of the tube.
  final double min, max;

  /// Appended to the reading, e.g. `°C`.
  final String unit;

  /// Caption under the reading.
  final String? label;

  /// Colour bands (lowest first); falls back to [color].
  final List<ThermometerZone> zones;

  /// Mercury colour when no zone applies (default red).
  final Color? color;

  /// Optional goal, drawn as a marker across the tube.
  final double? target;
  final String? targetLabel;

  /// Approximate number of labelled ticks and unlabelled ticks between two of them.
  final int ticks, minorTicks;

  /// Converts a value for the scale on the right, e.g. `(c) => c * 9 / 5 + 32`.
  final double Function(double)? secondaryConvert;

  /// Formats the right-hand labels (default: the number, rounded).
  final String Function(double)? secondaryFormat;
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
        builder: (p, ptr) => _ThermoPainter(this, t, p, ptr),
      ),
    );
  }
}

class _ThermoPainter extends CustomPainter {
  _ThermoPainter(this.w, this.theme, this.progress, this.pointer);
  final ThermometerChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final span = w.max - w.min;
    if (span <= 0) return;
    final fmt = w.valueFormat ?? formatNumber;

    // ---- 1. geometry: a tube that ends in a bulb, text underneath
    final bulbR = math.min(size.width * .17, size.height * .1);
    final tubeW = bulbR * 1.0;
    final cx = size.width / 2;
    final bulbCy = size.height - 46 - bulbR;
    const tubeTop = 12.0;
    final innerW = tubeW - 8; // inside the glass wall
    final innerTop = tubeTop + tubeW / 2, innerBottom = bulbCy;
    if (innerBottom - innerTop < 30) return;
    double yOf(double v) => innerBottom - ((v - w.min) / span).clamp(0.0, 1.0).toDouble() * (innerBottom - innerTop);
    double valueAt(double y) => w.min + (innerBottom - y) / (innerBottom - innerTop) * span;

    // ---- 2. mercury colour: first matching zone, else the chosen colour
    Color mercury = w.color ?? const Color(0xFFE53935);
    for (final z in w.zones) {
      mercury = z.color;
      if (w.value <= z.upTo) break;
    }

    // ---- 3. glass: tube and bulb merged into one outline
    final glass = Path.combine(
      PathOperation.union,
      Path()..addRRect(RRect.fromLTRBR(cx - tubeW / 2, tubeTop, cx + tubeW / 2, bulbCy, Radius.circular(tubeW / 2))),
      Path()..addOval(Rect.fromCircle(center: Offset(cx, bulbCy), radius: bulbR)),
    );
    canvas.drawPath(glass, Paint()..color = theme.surface);
    canvas.drawPath(glass, Paint()..color = theme.gridColor.faded(.5));

    // ---- 4. mercury: a column from the bulb up to the (animated) value
    final shown = w.min + (w.value - w.min) * progress;
    final top = yOf(shown);
    canvas.drawCircle(Offset(cx, bulbCy), bulbR - 4, Paint()..color = mercury);
    canvas.drawRRect(
        RRect.fromLTRBAndCorners(cx - innerW / 2, top, cx + innerW / 2, bulbCy,
            topLeft: Radius.circular(innerW / 2), topRight: Radius.circular(innerW / 2)),
        Paint()..color = mercury);
    // a soft highlight makes it look like glass
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(cx - innerW * .32, top + 6, cx - innerW * .12, bulbCy - 4), const Radius.circular(3)),
        Paint()..color = Colors.white.withAlpha(70));
    canvas.drawPath(glass, Paint()
      ..color = theme.axisColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4);

    // ---- 5. scale: labelled major ticks and unlabelled minor ticks
    final scale = NiceScale.compute(w.min, w.max, maxTicks: w.ticks);
    final majors = [for (final t in scale.ticks) if (t >= w.min - 1e-9 && t <= w.max + 1e-9) t];
    final tickPaint = Paint()
      ..color = theme.axisColor
      ..strokeWidth = 1.4;
    final lx = cx - tubeW / 2 - 4, rx = cx + tubeW / 2 + 4;
    final conv = w.secondaryConvert;
    final fmt2 = w.secondaryFormat ?? ((double v) => v.round().toString());
    for (final t in majors) {
      final y = yOf(t);
      canvas.drawLine(Offset(lx, y), Offset(lx - 10, y), tickPaint);
      paintText(canvas, fmt(t), Offset(lx - 14, y), theme.labelStyle, align: Alignment.centerRight);
      if (conv != null) {
        canvas.drawLine(Offset(rx, y), Offset(rx + 10, y), tickPaint);
        paintText(canvas, fmt2(conv(t)), Offset(rx + 14, y), theme.labelStyle, align: Alignment.centerLeft);
      }
    }
    if (majors.length > 1 && w.minorTicks > 0) {
      final step = majors[1] - majors[0];
      for (final t in majors.skip(0)) {
        for (var k = 1; k <= w.minorTicks; k++) {
          final v = t + step * k / (w.minorTicks + 1);
          if (v >= w.min && v <= w.max) canvas.drawLine(Offset(lx, yOf(v)), Offset(lx - 5, yOf(v)), tickPaint..strokeWidth = 1);
        }
      }
    }

    // ---- 6. target marker across the tube
    if (w.target != null) {
      final y = yOf(w.target!);
      canvas.drawLine(Offset(cx - tubeW / 2 - 3, y), Offset(cx + tubeW / 2 + 3, y), Paint()
        ..color = theme.textColor
        ..strokeWidth = 3);
      if (conv == null) {
        paintText(canvas, w.targetLabel ?? 'Target', Offset(rx + 8, y), theme.labelStyle.copyWith(color: theme.textColor, fontWeight: FontWeight.w700),
            align: Alignment.centerLeft, maxWidth: size.width / 2 - tubeW / 2 - 12);
      }
    }

    // ---- 7. reading under the bulb
    paintText(canvas, '${fmt(shown)}${w.unit}', Offset(cx, size.height - 30),
        TextStyle(color: theme.textColor, fontSize: math.min(24.0, size.width * .18), fontWeight: FontWeight.bold));
    if (w.label != null) paintText(canvas, w.label!, Offset(cx, size.height - 10), theme.labelStyle, maxWidth: size.width - 8);

    // ---- 8. hover: read the scale at the pointer's height
    final ptr = pointer;
    if (ptr != null && progress >= 1 && (ptr.dx - cx).abs() < tubeW && ptr.dy >= innerTop && ptr.dy <= innerBottom) {
      canvas.drawLine(Offset(cx - tubeW, ptr.dy), Offset(cx + tubeW, ptr.dy), Paint()
        ..color = theme.textColor.faded(.6)
        ..strokeWidth = 1);
      paintTooltip(canvas, size, ptr, theme, title: '${fmt(valueAt(ptr.dy))}${w.unit}', rows: [
        TooltipRow('Reading: ${fmt(w.value)}${w.unit}', color: mercury),
        TooltipRow('${((w.value - w.min) / span * 100).toStringAsFixed(0)}% of the scale'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
