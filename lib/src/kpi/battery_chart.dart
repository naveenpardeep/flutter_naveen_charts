// Battery: a level shown as a battery icon (continuous or segmented).

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_canvas.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';

/// Battery chart: a level (0 .. [max]) drawn as a battery. The fill is red
/// when low, amber when medium and green when high - thresholds and colours
/// are configurable. Use [segments] for a cell style (5 bars like a phone) and
/// [charging] for a lightning bolt. Horizontal or [vertical].
///
/// Good for device status, remaining budget, capacity left, health points.
class BatteryChart extends StatelessWidget {
  const BatteryChart({
    super.key,
    required this.level,
    this.max = 100,
    this.segments = 0,
    this.vertical = false,
    this.charging = false,
    this.lowThreshold = 20,
    this.midThreshold = 50,
    this.lowColor = const Color(0xFFE53935),
    this.midColor = const Color(0xFFFFB300),
    this.highColor = const Color(0xFF43A047),
    this.showValue = true,
    this.valueFormat,
    this.label,
    this.aspectRatio,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  /// Current level.
  final double level;

  /// Level that counts as full.
  final double max;

  /// 0 = continuous fill; n > 0 splits the battery into n cells.
  final int segments;
  final bool vertical;

  /// Draw a lightning bolt over the battery.
  final bool charging;

  /// Percent (of [max]) at or below which the battery is "low" / "medium".
  final double lowThreshold, midThreshold;
  final Color lowColor, midColor, highColor;

  /// Print the percentage on the battery.
  final bool showValue;

  /// Formats the percentage text (default `85%`).
  final String Function(double percent)? valueFormat;

  /// Caption under the battery.
  final String? label;

  /// Defaults to 2.2 (horizontal) or 0.5 (vertical).
  final double? aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return AspectRatio(
      aspectRatio: aspectRatio ?? (vertical ? .5 : 2.2),
      child: ChartCanvas(
        duration: animationDuration,
        interactive: false,
        builder: (p, ptr) => _BatteryPainter(this, t, p),
      ),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  _BatteryPainter(this.w, this.theme, this.progress);
  final BatteryChart w;
  final ChartTheme theme;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (w.max <= 0) return;
    final frac = (w.level / w.max).clamp(0.0, 1.0).toDouble();
    final pct = frac * 100;
    final fmt = w.valueFormat ?? ((double v) => '${v.round()}%');
    final fillColor = pct <= w.lowThreshold ? w.lowColor : (pct <= w.midThreshold ? w.midColor : w.highColor);

    // ---- 1. draw the horizontal battery in a "logical" box; for the vertical
    //         version rotate the canvas so the same code serves both
    final labelH = w.label == null ? 0.0 : 20.0;
    final box = Size(w.vertical ? size.height - labelH : size.width, w.vertical ? size.width : size.height - labelH);
    canvas.save();
    if (w.vertical) {
      // rotate -90 degrees around the middle of the canvas, then swap sizes
      canvas.translate(size.width / 2, (size.height - labelH) / 2);
      canvas.rotate(-math.pi / 2);
      canvas.translate(-box.width / 2, -box.height / 2);
    }
    final nubW = box.height * .09;
    final bodyW = box.width - nubW - 4;
    final bodyH = math.min(box.height * .85, bodyW * .5);
    final body = Rect.fromLTWH(2, (box.height - bodyH) / 2, bodyW, bodyH);
    final radius = Radius.circular(bodyH * .18);

    // terminal nub on the right
    canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(body.right, body.center.dy - bodyH * .17, nubW, bodyH * .34), topRight: radius, bottomRight: radius),
        Paint()..color = theme.axisColor);
    // body outline
    final outer = RRect.fromRectAndRadius(body, radius);
    canvas.drawRRect(outer, Paint()..color = theme.surface);
    canvas.drawRRect(outer, Paint()
      ..color = theme.axisColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);

    // ---- 2. the fill, inset a little from the outline
    final inner = body.deflate(bodyH * .1 + 1.5);
    if (w.segments > 0) {
      // cells: full cells solid, the cell being filled shown at partial strength
      final gap = inner.width * .03;
      final cellW = (inner.width - gap * (w.segments - 1)) / w.segments;
      final filled = frac * w.segments * progress;
      for (var i = 0; i < w.segments; i++) {
        final cell = Rect.fromLTWH(inner.left + i * (cellW + gap), inner.top, cellW, inner.height);
        final a = (filled - i).clamp(0.0, 1.0).toDouble();
        canvas.drawRRect(RRect.fromRectAndRadius(cell, Radius.circular(inner.height * .12)), Paint()..color = theme.gridColor.faded(.5));
        if (a > 0) canvas.drawRRect(RRect.fromRectAndRadius(cell, Radius.circular(inner.height * .12)), Paint()..color = fillColor.faded(.35 + .65 * a));
      }
    } else {
      final fill = Rect.fromLTWH(inner.left, inner.top, inner.width * frac * progress, inner.height);
      canvas.drawRRect(RRect.fromRectAndRadius(fill, Radius.circular(inner.height * .16)), Paint()..color = fillColor);
    }
    canvas.restore();

    // ---- 3. text and bolt are drawn upright (outside the rotation)
    final center = w.vertical ? Offset(size.width / 2, (size.height - labelH) / 2) : Offset(body.center.dx, body.center.dy);
    final fillEdgeColor = frac > .5 && w.segments == 0 ? contrastOn(fillColor) : theme.textColor;
    if (w.showValue && progress > .5) {
      final fs = math.min(26.0, (w.vertical ? size.width : bodyH) * .42);
      paintText(canvas, fmt(pct * progress), center + Offset(w.charging ? fs * .5 : 0, 0), TextStyle(color: fillEdgeColor, fontSize: fs, fontWeight: FontWeight.w800));
    }
    if (w.charging) {
      final s = math.min(bodyH, w.vertical ? size.width : bodyH) * .42;
      final bc = center - Offset(w.showValue ? s * 1.1 : 0, 0);
      // lightning bolt polygon (relative to its centre)
      final pts = [const Offset(.15, -1), const Offset(-.55, .15), const Offset(-.05, .15), const Offset(-.2, 1), const Offset(.6, -.2), const Offset(.08, -.2)];
      final bolt = Path()..addPolygon([for (final p in pts) bc + p * (s * .55)], true);
      canvas.drawPath(bolt, Paint()..color = Colors.white);
      canvas.drawPath(bolt, Paint()
        ..color = theme.textColor.faded(.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round);
    }
    if (w.label != null) paintText(canvas, w.label!, Offset(size.width / 2, size.height - 9), theme.labelStyle.copyWith(color: theme.textColor), maxWidth: size.width);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
