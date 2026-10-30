import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';

/// A colored band of a gauge, ending at [upTo].
class GaugeSegment {
  const GaugeSegment(this.upTo, this.color);
  final double upTo;
  final Color color;
}

/// 270 degree gauge. With [segments] the track shows threshold bands and the
/// value arc takes the color of the band the value falls into.
class GaugeChart extends StatelessWidget {
  const GaugeChart({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 100,
    this.label,
    this.unit = '',
    this.segments = const [],
    this.color,
    this.strokeWidth = 18,
    this.aspectRatio = 1.2,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 1000),
  });
  final double value;
  final double min;
  final double max;
  final String? label;
  final String unit;
  final List<GaugeSegment> segments;
  final Color? color;
  final double strokeWidth;
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
        builder: (p, _) => _GaugePainter(this, t, p),
      ),
    );
  }
}

/// Gauge Painter
class _GaugePainter extends CustomPainter {
  _GaugePainter(this.g, this.theme, this.progress);
  final GaugeChart g;
  final ChartTheme theme;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const start = 3 * math.pi / 4;
    const total = 3 * math.pi / 2;
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - g.strokeWidth / 2 - 6;
    if (r <= 0) return;
    final rect = Rect.fromCircle(center: c, radius: r);
    final span = g.max - g.min;
    double frac(double v) => ((v - g.min) / span).clamp(0.0, 1.0).toDouble();

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = g.strokeWidth;
    if (g.segments.isEmpty) {
      track
        ..color = theme.gridColor
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, total, false, track);
    } else {
      var lo = g.min;
      for (final s in g.segments) {
        track.color = s.color.faded(.3);
        canvas.drawArc(rect, start + total * frac(lo),
            total * (frac(s.upTo) - frac(lo)), false, track);
        lo = s.upTo;
      }
    }

    Color vc = g.color ?? theme.colorAt(0);
    for (final s in g.segments) {
      vc = s.color;
      if (g.value <= s.upTo) break;
    }
    final f = frac(g.value) * progress;
    if (f > 0) {
      canvas.drawArc(
          rect,
          start,
          total * f,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = g.strokeWidth
            ..strokeCap = StrokeCap.round
            ..color = vc);
    }

    /// Paint text
    paintText(
        canvas,
        '${formatNumber(g.value * progress)}${g.unit}',
        c,
        TextStyle(
            color: theme.textColor,
            fontSize: math.min(34.0, r * 0.38),
            fontWeight: FontWeight.bold));
    if (g.label != null) {
      paintText(canvas, g.label!, c + Offset(0, r * 0.32), theme.labelStyle);
    }
    final off = Offset(0, g.strokeWidth / 2 + 10);
    paintText(canvas, formatNumber(g.min),
        c + Offset.fromDirection(start, r) + off, theme.labelStyle);
    paintText(canvas, formatNumber(g.max),
        c + Offset.fromDirection(start + total, r) + off, theme.labelStyle);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
