import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart3d.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';
import 'core/legend.dart';

class Point3D {
  const Point3D(this.x, this.y, this.z, {this.size = 1, this.group = 0, this.label, this.color});
  final double x, y, z;

  /// Relative size (bubble radius).
  final double size;
  final int group;
  final String? label;
  final Color? color;
}

/// 3-D scatter / bubble plot inside a rotatable axis box. Drag to rotate.
class Scatter3DChart extends StatelessWidget {
  const Scatter3DChart({
    super.key,
    required this.points,
    this.groupNames,
    this.xTitle = 'X',
    this.yTitle = 'Y',
    this.zTitle = 'Z',
    this.pointRadius = 7,
    this.showDropLines = false,
    this.showLegend = true,
    this.rotatable = true,
    this.initialYaw = -0.7,
    this.initialPitch = 0.4,
    this.aspectRatio = 1.3,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<Point3D> points;
  final List<String>? groupNames;
  final String xTitle, yTitle, zTitle;
  final double pointRadius;
  final bool showDropLines;
  final bool showLegend;
  final bool rotatable;
  final double initialYaw, initialPitch;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    final groups = {for (final p in points) p.group}.toList()..sort();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Chart3DView(
        initialYaw: initialYaw,
        initialPitch: initialPitch,
        rotatable: rotatable,
        aspectRatio: aspectRatio,
        duration: animationDuration,
        builder: (p, ptr, yaw, pitch) => _Scatter3DPainter(this, t, p, ptr, yaw, pitch),
      ),
      if (showLegend && groups.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ChartLegend(theme: t, items: [
            for (final g in groups)
              LegendItem((groupNames != null && g < groupNames!.length) ? groupNames![g] : 'Group $g', t.colorAt(g)),
          ]),
        ),
    ]);
  }
}

class _SP {
  _SP(this.p, this.z, this.pos, this.r);
  final Point3D p;
  final double z;
  final Offset pos;
  final double r;
}

class _Scatter3DPainter extends CustomPainter {
  _Scatter3DPainter(this.w, this.theme, this.progress, this.pointer, this.yaw, this.pitch);
  final Scatter3DChart w;
  final ChartTheme theme;
  final double progress, yaw, pitch;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = w.points;
    if (pts.isEmpty) return;
    double lo(double Function(Point3D) f) => pts.map(f).reduce(math.min);
    double hi(double Function(Point3D) f) => pts.map(f).reduce(math.max);
    final xl = lo((p) => p.x), xh = hi((p) => p.x);
    final yl = lo((p) => p.y), yh = hi((p) => p.y);
    final zl = lo((p) => p.z), zh = hi((p) => p.z);
    double nrm(double v, double a, double b) => b == a ? 0 : -1 + 2 * (v - a) / (b - a);
    double den(double t, double a, double b) => a + (t + 1) / 2 * (b - a);
    final pr = Projector3D(yaw, pitch, Offset(size.width / 2, size.height * .53), math.min(size.width, size.height) / 3.0);
    Offset pp(double x, double y, double z) => pr.at(x, y, z);

    final line = Paint()
      ..color = theme.axisColor.faded(.7)
      ..strokeWidth = 1;
    final grid = Paint()
      ..color = theme.gridColor
      ..strokeWidth = 1;
    for (var k = 0; k <= 4; k++) {
      final t = -1 + k / 2;
      canvas.drawLine(pp(t, -1, -1), pp(t, -1, 1), grid);
      canvas.drawLine(pp(-1, -1, t), pp(1, -1, t), grid);
    }
    const c = [-1.0, 1.0];
    for (final a in c) {
      for (final b in c) {
        canvas.drawLine(pp(a, -1, b), pp(a, 1, b), line);
        canvas.drawLine(pp(-1, a, b), pp(1, a, b), line);
        canvas.drawLine(pp(a, b, -1), pp(a, b, 1), line);
      }
    }

    final zNear = pr.depth(0, -1, -1) < pr.depth(0, -1, 1) ? -1.0 : 1.0;
    final xNear = pr.depth(-1, -1, 0) < pr.depth(1, -1, 0) ? -1.0 : 1.0;
    Alignment side(Offset o) => o.dx < size.width / 2 ? Alignment.centerRight : Alignment.centerLeft;
    for (final t in const [-1.0, 0.0, 1.0]) {
      paintText(canvas, formatNumber(den(t, xl, xh)), pp(t, -1.06, zNear * 1.1), theme.labelStyle, align: Alignment.topCenter);
      final lz = pp(xNear * 1.1, -1.04, t);
      paintText(canvas, formatNumber(den(t, zl, zh)), lz, theme.labelStyle, align: side(lz));
      final ly = pp(-xNear * 1.08, t, zNear * 1.08);
      paintText(canvas, formatNumber(den(t, yl, yh)), ly, theme.labelStyle, align: side(ly));
    }
    final ts = theme.labelStyle.copyWith(color: theme.textColor, fontWeight: FontWeight.w700);
    paintText(canvas, w.xTitle, pp(0, -1.22, zNear * 1.25), ts, align: Alignment.topCenter);
    final tz = pp(xNear * 1.28, -1.12, 0);
    paintText(canvas, w.zTitle, tz, ts, align: side(tz));
    final ty = pp(-xNear * 1.15, 1.12, zNear * 1.15);
    paintText(canvas, w.yTitle, ty, ts, align: Alignment.bottomCenter);

    final maxSize = pts.map((p) => p.size).reduce(math.max);
    final sps = <_SP>[];
    for (final p in pts) {
      final r3 = pr.rotate(Vec3(nrm(p.x, xl, xh), nrm(p.y, yl, yh), nrm(p.z, zl, zh)));
      final r = w.pointRadius * (0.6 + 0.9 * math.sqrt(maxSize <= 0 ? 0 : p.size / maxSize)) * pr.depthScale(r3) * progress;
      sps.add(_SP(p, r3.z, pr.project(r3), r));
    }
    sps.sort((a, b) => b.z.compareTo(a.z));

    _SP? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      for (final s in sps) {
        if ((s.pos - ptr).distance <= s.r + 4) hover = s;
      }
    }
    if (w.showDropLines) {
      for (final s in sps) {
        final fl = pp(nrm(s.p.x, xl, xh), -1, nrm(s.p.z, zl, zh));
        canvas.drawLine(s.pos, fl, Paint()
          ..color = theme.axisColor.faded(.45)
          ..strokeWidth = 1);
      }
    }
    for (final s in sps) {
      final base = s.p.color ?? theme.colorAt(s.p.group);
      final hot = identical(s, hover);
      final fade = (1.0 - (s.z + 1.7) / 3.4 * .35).clamp(0.5, 1.0).toDouble();
      final rect = Rect.fromCircle(center: s.pos, radius: s.r);
      canvas.drawCircle(
          s.pos,
          s.r,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-.35, -.35),
              colors: [shade(base, 1.45).faded(fade), base.faded(fade), shade(base, .7).faded(fade)],
              stops: const [0, .55, 1],
            ).createShader(rect));
      if (hot) {
        canvas.drawCircle(s.pos, s.r + 3, Paint()
          ..color = theme.textColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
      }
    }
    if (hover != null && ptr != null) {
      final p = hover.p;
      paintTooltip(canvas, size, ptr, theme, title: p.label ?? (w.groupNames != null && p.group < w.groupNames!.length ? w.groupNames![p.group] : 'Point'), rows: [
        TooltipRow('${w.xTitle}: ${formatNumber(p.x)}', color: p.color ?? theme.colorAt(p.group)),
        TooltipRow('${w.yTitle}: ${formatNumber(p.y)}'),
        TooltipRow('${w.zTitle}: ${formatNumber(p.z)}'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
