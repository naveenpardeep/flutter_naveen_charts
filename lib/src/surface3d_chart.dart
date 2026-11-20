import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart3d.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';

const List<Color> _defaultRamp = [
  Color(0xFF2C3E9E),
  Color(0xFF2E86C1),
  Color(0xFF27AE60),
  Color(0xFFF1C40F),
  Color(0xFFE74C3C),
];

/// 3-D surface plot: `values[row][col]` (row = z, col = x). Drag to rotate.
class Surface3DChart extends StatelessWidget {
  const Surface3DChart({
    super.key,
    required this.values,
    this.xLabels,
    this.zLabels,
    this.colors = _defaultRamp,
    this.showWireframe = true,
    this.showColorBar = true,
    this.valueFormat,
    this.rotatable = true,
    this.initialYaw = -0.7,
    this.initialPitch = 0.55,
    this.aspectRatio = 1.3,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 1000),
  });
  final List<List<double>> values;
  final List<String>? xLabels;
  final List<String>? zLabels;

  /// Colour ramp from the lowest to the highest value.
  final List<Color> colors;
  final bool showWireframe;
  final bool showColorBar;
  final String Function(double)? valueFormat;
  final bool rotatable;
  final double initialYaw, initialPitch;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return Chart3DView(
      initialYaw: initialYaw,
      initialPitch: initialPitch,
      rotatable: rotatable,
      aspectRatio: aspectRatio,
      duration: animationDuration,
      builder: (p, ptr, yaw, pitch) => _SurfacePainter(this, t, p, ptr, yaw, pitch),
    );
  }
}

class _Quad {
  _Quad(this.path, this.depth, this.color, this.i, this.j);
  final Path path;
  final double depth;
  final Color color;
  final int i, j;
}

class _SurfacePainter extends CustomPainter {
  _SurfacePainter(this.w, this.theme, this.progress, this.pointer, this.yaw, this.pitch);
  final Surface3DChart w;
  final ChartTheme theme;
  final double progress, yaw, pitch;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final nz = w.values.length;
    if (nz < 2) return;
    final nx = w.values.first.length;
    if (nx < 2) return;
    var lo = double.infinity, hi = -double.infinity;
    for (final r in w.values) {
      for (final v in r) {
        lo = math.min(lo, v);
        hi = math.max(hi, v);
      }
    }
    final span = hi - lo < 1e-9 ? 1.0 : hi - lo;
    final fmt = w.valueFormat ?? formatNumber;
    final barW = w.showColorBar ? 44.0 : 0.0;
    final pr = Projector3D(yaw, pitch, Offset((size.width - barW) / 2, size.height * .56), math.min(size.width - barW, size.height) / 3.0);
    double v(int i, int j) => i < w.values[j].length ? w.values[j][i] : lo;
    double gx(int i) => -1 + 2 * i / (nx - 1);
    double gz(int j) => -1 + 2 * j / (nz - 1);
    double gy(double val) => -0.6 + (val - lo) / span * 1.2 * progress;
    Vec3 vert(int i, int j) => Vec3(gx(i), gy(v(i, j)), gz(j));

    // floor
    const y0 = -0.6;
    final floor = Path()
      ..moveTo(pr.at(-1, y0, -1).dx, pr.at(-1, y0, -1).dy)
      ..lineTo(pr.at(1, y0, -1).dx, pr.at(1, y0, -1).dy)
      ..lineTo(pr.at(1, y0, 1).dx, pr.at(1, y0, 1).dy)
      ..lineTo(pr.at(-1, y0, 1).dx, pr.at(-1, y0, 1).dy)
      ..close();
    canvas.drawPath(floor, Paint()..color = theme.gridColor.faded(.3));
    canvas.drawPath(floor, Paint()
      ..color = theme.axisColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    final quads = <_Quad>[];
    for (var j = 0; j < nz - 1; j++) {
      for (var i = 0; i < nx - 1; i++) {
        final a = vert(i, j), b = vert(i + 1, j), c = vert(i + 1, j + 1), d = vert(i, j + 1);
        final e1 = Vec3(b.x - a.x, b.y - a.y, b.z - a.z), e2 = Vec3(d.x - a.x, d.y - a.y, d.z - a.z);
        final nxv = e1.y * e2.z - e1.z * e2.y, nyv = e1.z * e2.x - e1.x * e2.z, nzv = e1.x * e2.y - e1.y * e2.x;
        final len = math.sqrt(nxv * nxv + nyv * nyv + nzv * nzv);
        final k = 0.72 + 0.4 * (len == 0 ? 1 : (nyv / len).abs());
        final avg = (v(i, j) + v(i + 1, j) + v(i + 1, j + 1) + v(i, j + 1)) / 4;
        final base = rampColor(w.colors, (avg - lo) / span);
        final ra = pr.rotate(a), rb = pr.rotate(b), rc = pr.rotate(c), rd = pr.rotate(d);
        final path = Path();
        for (var q = 0; q < 4; q++) {
          final o = pr.project([ra, rb, rc, rd][q]);
          if (q == 0) {
            path.moveTo(o.dx, o.dy);
          } else {
            path.lineTo(o.dx, o.dy);
          }
        }
        path.close();
        quads.add(_Quad(path, (ra.z + rb.z + rc.z + rd.z) / 4, shade(base, k), i, j));
      }
    }
    quads.sort((a, b) => b.depth.compareTo(a.depth));

    _Quad? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      for (final q in quads) {
        if (q.path.contains(ptr)) hover = q;
      }
    }
    final wire = Paint()
      ..color = Colors.black.withAlpha(w.showWireframe ? 55 : 0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7;
    for (final q in quads) {
      canvas.drawPath(q.path, Paint()..color = identical(q, hover) ? shade(q.color, 1.2) : q.color);
      canvas.drawPath(q.path, wire);
    }

    // axis labels
    final zNear = pr.depth(0, y0, -1) < pr.depth(0, y0, 1) ? -1.0 : 1.0;
    final xNear = pr.depth(-1, y0, 0) < pr.depth(1, y0, 0) ? -1.0 : 1.0;
    final everyX = math.max(1, (nx / 6).ceil()), everyZ = math.max(1, (nz / 6).ceil());
    for (var i = 0; i < nx; i += everyX) {
      paintText(canvas, (w.xLabels != null && i < w.xLabels!.length) ? w.xLabels![i] : '$i',
          pr.at(gx(i), y0 - .03, zNear * 1.12), theme.labelStyle, align: Alignment.topCenter);
    }
    for (var j = 0; j < nz; j += everyZ) {
      final lp = pr.at(xNear * 1.12, y0 - .03, gz(j));
      paintText(canvas, (w.zLabels != null && j < w.zLabels!.length) ? w.zLabels![j] : '$j', lp, theme.labelStyle,
          align: lp.dx < (size.width - barW) / 2 ? Alignment.centerRight : Alignment.centerLeft);
    }

    if (w.showColorBar) {
      final bar = Rect.fromLTWH(size.width - 34, 24, 10, size.height - 64);
      canvas.drawRect(
          bar,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: w.colors,
            ).createShader(bar));
      paintText(canvas, fmt(hi), Offset(bar.left - 2, bar.top - 4), theme.labelStyle, align: Alignment.bottomLeft);
      paintText(canvas, fmt(lo), Offset(bar.left - 2, bar.bottom + 4), theme.labelStyle, align: Alignment.topLeft);
    }

    if (hover != null && ptr != null) {
      final i = hover.i, j = hover.j;
      final avg = (v(i, j) + v(i + 1, j) + v(i + 1, j + 1) + v(i, j + 1)) / 4;
      paintTooltip(canvas, size, ptr, theme, title: 'x ${(w.xLabels != null && i < w.xLabels!.length) ? w.xLabels![i] : i} · z ${(w.zLabels != null && j < w.zLabels!.length) ? w.zLabels![j] : j}', rows: [
        TooltipRow('Value: ${fmt(avg)}', color: hover.color),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
