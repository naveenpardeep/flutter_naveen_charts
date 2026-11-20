import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart3d.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';
import 'core/legend.dart';
import 'pie_chart.dart' show PieSlice;

/// Tilted, extruded pie. Drag horizontally to spin it, vertically to tilt it.
class Pie3DChart extends StatelessWidget {
  const Pie3DChart({
    super.key,
    required this.slices,
    this.thickness = 0.22,
    this.explodeOnHover = true,
    this.showPercent = true,
    this.showLegend = true,
    this.rotatable = true,
    this.initialAngle = -math.pi / 2,
    this.initialTilt = 0.9,
    this.aspectRatio = 1.5,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<PieSlice> slices;

  /// Extrusion height as a share of the radius.
  final double thickness;
  final bool explodeOnHover;
  final bool showPercent;
  final bool showLegend;
  final bool rotatable;

  /// Start angle of the first slice (radians).
  final double initialAngle;

  /// Camera elevation in radians (0.25 = almost flat on, 1.5 = top-down).
  final double initialTilt;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Chart3DView(
        initialYaw: initialAngle,
        initialPitch: initialTilt,
        minPitch: 0.25,
        maxPitch: 1.5,
        rotatable: rotatable,
        aspectRatio: aspectRatio,
        duration: animationDuration,
        builder: (p, ptr, yaw, pitch) => _Pie3DPainter(this, t, p, ptr, yaw, pitch),
      ),
      if (showLegend)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ChartLegend(theme: t, items: [
            for (var i = 0; i < slices.length; i++) LegendItem(slices[i].label, slices[i].color ?? t.colorAt(i)),
          ]),
        ),
    ]);
  }
}

class _Pie3DPainter extends CustomPainter {
  _Pie3DPainter(this.w, this.theme, this.progress, this.pointer, this.start, this.tilt);
  final Pie3DChart w;
  final ChartTheme theme;
  final double progress, start, tilt;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final total = w.slices.fold<double>(0, (a, s) => a + math.max(0.0, s.value));
    if (total <= 0) return;
    final elev = tilt.clamp(0.25, 1.5).toDouble();
    final se = math.sin(elev), ce = math.cos(elev);
    final r = math.min(size.width / 2 - 14, (size.height - 20) / (2 * se + w.thickness * ce));
    if (r <= 4) return;
    final ry = r * se;
    final h = w.thickness * r * ce + 1;
    final c = Offset(size.width / 2, size.height / 2 - h / 2);
    Offset pt(double a, double rad, [Offset shift = Offset.zero]) =>
        Offset(c.dx + math.cos(a) * r * rad, c.dy + math.sin(a) * ry * rad) + shift;

    int? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      final ux = (ptr.dx - c.dx) / r, uy = (ptr.dy - c.dy) / ry;
      if (ux * ux + uy * uy <= 1) {
        final a = (math.atan2(uy, ux) - start) % (2 * math.pi);
        var acc = 0.0;
        for (var i = 0; i < w.slices.length; i++) {
          final full = math.max(0.0, w.slices[i].value) / total * 2 * math.pi;
          if (a >= acc && a < acc + full) {
            hover = i;
            break;
          }
          acc += full;
        }
      }
    }

    final angles = <List<double>>[];
    var a = start;
    for (final s in w.slices) {
      final sweep = math.max(0.0, s.value) / total * 2 * math.pi * progress;
      angles.add([a, a + sweep]);
      a += sweep;
    }
    Offset shiftOf(int i) {
      if (!w.explodeOnHover || hover != i) return Offset.zero;
      final mid = (angles[i][0] + angles[i][1]) / 2;
      return Offset(math.cos(mid) * r * .08, math.sin(mid) * ry * .08);
    }

    Color col(int i) => w.slices[i].color ?? theme.colorAt(i);
    List<Offset> arc(double a0, double a1, double rad, Offset shift) {
      final steps = math.max(2, ((a1 - a0).abs() / .05).ceil());
      return [for (var k = 0; k <= steps; k++) pt(a0 + (a1 - a0) * k / steps, rad, shift)];
    }

    // side walls first, then the top faces cover whatever is hidden
    for (var i = 0; i < w.slices.length; i++) {
      final a0 = angles[i][0], a1 = angles[i][1];
      if (a1 - a0 < 1e-4) continue;
      final top = arc(a0, a1, 1, shiftOf(i));
      final path = Path()..moveTo(top.first.dx, top.first.dy);
      for (final p in top.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      for (final p in top.reversed) {
        path.lineTo(p.dx, p.dy + h);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = shade(col(i), .62));
    }
    for (var i = 0; i < w.slices.length; i++) {
      final a0 = angles[i][0], a1 = angles[i][1];
      if (a1 - a0 < 1e-4) continue;
      final sh = shiftOf(i);
      final rim = arc(a0, a1, 1, sh);
      final path = Path()..moveTo(c.dx + sh.dx, c.dy + sh.dy);
      for (final p in rim) {
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = hover == i ? shade(col(i), 1.12) : col(i));
      canvas.drawPath(path, Paint()
        ..color = theme.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4);
      final sweep = a1 - a0;
      if (w.showPercent && progress > .99 && sweep > .3) {
        paintText(canvas, '${(math.max(0.0, w.slices[i].value) / total * 100).round()}%', pt((a0 + a1) / 2, .6, sh),
            const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold));
      }
    }
    if (hover != null && ptr != null) {
      final s = w.slices[hover];
      paintTooltip(canvas, size, ptr, theme, rows: [
        TooltipRow('${s.label}: ${formatNumber(s.value)} (${(s.value / total * 100).toStringAsFixed(1)}%)', color: col(hover)),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
