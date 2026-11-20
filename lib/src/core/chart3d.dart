import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'chart_canvas.dart';

/// A point / vector in chart space (x right, y up, z into the screen).
class Vec3 {
  const Vec3(this.x, this.y, this.z);
  final double x, y, z;
}

/// Orbit camera: rotates around the origin and projects with perspective.
class Projector3D {
  Projector3D(this.yaw, this.pitch, this.center, this.scale, {this.distance = 5});
  final double yaw, pitch;
  final Offset center;
  final double scale;
  final double distance;
  late final double _cy = math.cos(yaw), _sy = math.sin(yaw);
  late final double _cp = math.cos(pitch), _sp = math.sin(pitch);

  Vec3 rotate(Vec3 p) {
    final x1 = p.x * _cy + p.z * _sy;
    final z1 = -p.x * _sy + p.z * _cy;
    final y2 = p.y * _cp + z1 * _sp;
    final z2 = -p.y * _sp + z1 * _cp;
    return Vec3(x1, y2, z2);
  }

  /// Screen position of an already rotated point.
  Offset project(Vec3 r) {
    final f = distance / (distance + r.z);
    return Offset(center.dx + r.x * scale * f, center.dy - r.y * scale * f);
  }

  /// Perspective factor (1 = at the origin plane, <1 further away).
  double depthScale(Vec3 r) => distance / (distance + r.z);

  Offset at(double x, double y, double z) => project(rotate(Vec3(x, y, z)));
  double depth(double x, double y, double z) => rotate(Vec3(x, y, z)).z;
}

/// Brightens (k > 1) or darkens (k < 1) a colour.
Color shade(Color c, double k) => k <= 1
    ? Color.lerp(Colors.black, c, k)!
    : Color.lerp(c, Colors.white, (k - 1).clamp(0.0, 1.0).toDouble())!;

/// Piecewise-linear colour ramp lookup, t in 0..1.
Color rampColor(List<Color> ramp, double t) {
  if (ramp.length == 1) return ramp.first;
  final x = t.clamp(0.0, 1.0).toDouble() * (ramp.length - 1);
  final i = math.min(x.floor(), ramp.length - 2);
  return Color.lerp(ramp[i], ramp[i + 1], x - i)!;
}

typedef Painter3DBuilder = CustomPainter Function(
    double progress, Offset? pointer, double yaw, double pitch);

/// Hosts a 3-D painter. Drag to rotate, double-tap to reset the view.
class Chart3DView extends StatefulWidget {
  const Chart3DView({
    super.key,
    required this.builder,
    this.initialYaw = -0.6,
    this.initialPitch = 0.45,
    this.minPitch = -1.4,
    this.maxPitch = 1.4,
    this.rotatable = true,
    this.aspectRatio = 1.3,
    this.duration = const Duration(milliseconds: 900),
  });
  final Painter3DBuilder builder;
  final double initialYaw, initialPitch, minPitch, maxPitch;
  final bool rotatable;
  final double aspectRatio;
  final Duration duration;

  @override
  State<Chart3DView> createState() => _Chart3DViewState();
}

class _Chart3DViewState extends State<Chart3DView> {
  late double _yaw = widget.initialYaw;
  late double _pitch = widget.initialPitch;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: GestureDetector(
        onDoubleTap: () => setState(() {
          _yaw = widget.initialYaw;
          _pitch = widget.initialPitch;
        }),
        onPanUpdate: widget.rotatable
            ? (d) => setState(() {
                  _yaw += d.delta.dx * 0.01;
                  _pitch = (_pitch + d.delta.dy * 0.01)
                      .clamp(widget.minPitch, widget.maxPitch)
                      .toDouble();
                })
            : null,
        child: ChartCanvas(
          duration: widget.duration,
          builder: (p, ptr) => widget.builder(p, ptr, _yaw, _pitch),
        ),
      ),
    );
  }
}
