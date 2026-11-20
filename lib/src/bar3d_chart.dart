import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart3d.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';
import 'core/legend.dart';

/// 3-D bar chart: [values] is `[series][category]`. Drag to rotate.
class Bar3DChart extends StatelessWidget {
  const Bar3DChart({
    super.key,
    required this.categories,
    required this.seriesNames,
    required this.values,
    this.colors,
    this.barSize = 0.6,
    this.showValueLabels = false,
    this.showLegend = true,
    this.valueFormat,
    this.rotatable = true,
    this.initialYaw = -0.6,
    this.initialPitch = 0.45,
    this.aspectRatio = 1.3,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<String> categories;
  final List<String> seriesNames;
  final List<List<double>> values;
  final List<Color>? colors;

  /// Share of each grid cell covered by a bar (0..1).
  final double barSize;
  final bool showValueLabels;
  final bool showLegend;
  final String Function(double)? valueFormat;
  final bool rotatable;
  final double initialYaw, initialPitch;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    Color c(int j) => (colors != null && j < colors!.length) ? colors![j] : t.colorAt(j);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Chart3DView(
        initialYaw: initialYaw,
        initialPitch: initialPitch,
        rotatable: rotatable,
        aspectRatio: aspectRatio,
        duration: animationDuration,
        builder: (p, ptr, yaw, pitch) => _Bar3DPainter(this, t, p, ptr, yaw, pitch, c),
      ),
      if (showLegend && values.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ChartLegend(theme: t, items: [
            for (var j = 0; j < values.length; j++)
              LegendItem(j < seriesNames.length ? seriesNames[j] : 'Series ${j + 1}', c(j)),
          ]),
        ),
    ]);
  }
}

class _Poly {
  _Poly(this.path, this.depth, this.k);
  final Path path;
  final double depth, k;
}

class _Box {
  _Box(this.j, this.i, this.depth, this.polys, this.top);
  final int j, i;
  final double depth;
  final List<_Poly> polys;
  final Offset top;
}

class _Bar3DPainter extends CustomPainter {
  _Bar3DPainter(this.w, this.theme, this.progress, this.pointer, this.yaw, this.pitch, this.color);
  final Bar3DChart w;
  final ChartTheme theme;
  final double progress, yaw, pitch;
  final Offset? pointer;
  final Color Function(int) color;

  @override
  void paint(Canvas canvas, Size size) {
    final nz = w.values.length, nx = w.categories.length;
    if (nz == 0 || nx == 0) return;
    var maxV = 0.0;
    for (final row in w.values) {
      for (final v in row) {
        maxV = math.max(maxV, v);
      }
    }
    final scale = NiceScale.compute(0, maxV <= 0 ? 1 : maxV);
    final fmt = w.valueFormat ?? formatNumber;
    final pr = Projector3D(yaw, pitch, Offset(size.width / 2, size.height * .56), math.min(size.width, size.height) / 3.1);
    const y0 = -0.6, hMax = 1.2;
    Offset pp(double x, double y, double z) => pr.at(x, y, z);
    Path poly(List<Vec3> pts) {
      final p = Path();
      for (var i = 0; i < pts.length; i++) {
        final o = pr.at(pts[i].x, pts[i].y, pts[i].z);
        if (i == 0) {
          p.moveTo(o.dx, o.dy);
        } else {
          p.lineTo(o.dx, o.dy);
        }
      }
      return p..close();
    }

    // back walls (the two planes behind the scene)
    const cs = [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]];
    var back = 0;
    var bz = -double.infinity;
    for (var k = 0; k < 4; k++) {
      final z = pr.depth(cs[k][0], y0, cs[k][1]);
      if (z > bz) {
        bz = z;
        back = k;
      }
    }
    final bx0 = cs[back][0], bz0 = cs[back][1];
    final wall = Paint()..color = theme.gridColor.faded(.22);
    final wallLine = Paint()
      ..color = theme.gridColor
      ..strokeWidth = 1;
    canvas.drawPath(poly([Vec3(-1, y0, -1), Vec3(1, y0, -1), Vec3(1, y0, 1), Vec3(-1, y0, 1)]), Paint()..color = theme.gridColor.faded(.35));
    canvas.drawPath(poly([Vec3(bx0, y0, -1), Vec3(bx0, y0, 1), Vec3(bx0, y0 + hMax, 1), Vec3(bx0, y0 + hMax, -1)]), wall);
    canvas.drawPath(poly([Vec3(-1, y0, bz0), Vec3(1, y0, bz0), Vec3(1, y0 + hMax, bz0), Vec3(-1, y0 + hMax, bz0)]), wall);
    for (final t in scale.ticks) {
      final y = y0 + t / scale.max * hMax;
      canvas.drawLine(pp(bx0, y, -1), pp(bx0, y, 1), wallLine);
      canvas.drawLine(pp(-1, y, bz0), pp(1, y, bz0), wallLine);
      final lp = pp(bx0 * 1.06, y, bz0 * 1.06);
      paintText(canvas, fmt(t), lp, theme.labelStyle,
          align: lp.dx < size.width / 2 ? Alignment.centerRight : Alignment.centerLeft);
    }
    for (var i = 0; i <= nx; i++) {
      final x = -1 + 2 * i / nx;
      canvas.drawLine(pp(x, y0, -1), pp(x, y0, 1), wallLine);
    }
    for (var j = 0; j <= nz; j++) {
      final z = -1 + 2 * j / nz;
      canvas.drawLine(pp(-1, y0, z), pp(1, y0, z), wallLine);
    }

    // axis labels on the nearest floor edges
    final zNear = pr.depth(0, y0, -1) < pr.depth(0, y0, 1) ? -1.0 : 1.0;
    final xNear = pr.depth(-1, y0, 0) < pr.depth(1, y0, 0) ? -1.0 : 1.0;
    for (var i = 0; i < nx; i++) {
      paintText(canvas, w.categories[i], pp(-1 + (i + .5) * 2 / nx, y0 - .02, zNear * 1.12), theme.labelStyle,
          align: Alignment.topCenter, maxWidth: 70);
    }
    for (var j = 0; j < nz; j++) {
      final lp = pp(xNear * 1.1, y0, -1 + (j + .5) * 2 / nz);
      paintText(canvas, j < w.seriesNames.length ? w.seriesNames[j] : '${j + 1}', lp, theme.labelStyle,
          align: lp.dx < size.width / 2 ? Alignment.centerRight : Alignment.centerLeft, maxWidth: 70);
    }

    // bars
    final bw = 2 / nx * w.barSize, bd = 2 / nz * w.barSize;
    final boxes = <_Box>[];
    for (var j = 0; j < nz; j++) {
      for (var i = 0; i < nx; i++) {
        final v = i < w.values[j].length ? math.max(0.0, w.values[j][i]) : 0.0;
        final h = v / scale.max * hMax * progress;
        if (h < 1e-4) continue;
        final cx = -1 + (i + .5) * 2 / nx, cz = -1 + (j + .5) * 2 / nz;
        final xa = cx - bw / 2, xb = cx + bw / 2, za = cz - bd / 2, zb = cz + bd / 2;
        final ya = y0, yb = y0 + h;
        List<Vec3> f(List<List<double>> p) => [for (final q in p) Vec3(q[0], q[1], q[2])];
        final faces = <List<Object>>[
          [f([[xa, yb, za], [xb, yb, za], [xb, yb, zb], [xa, yb, zb]]), 1.12],
          [f([[xa, ya, za], [xb, ya, za], [xb, yb, za], [xa, yb, za]]), .86],
          [f([[xa, ya, zb], [xb, ya, zb], [xb, yb, zb], [xa, yb, zb]]), .86],
          [f([[xa, ya, za], [xa, ya, zb], [xa, yb, zb], [xa, yb, za]]), .68],
          [f([[xb, ya, za], [xb, ya, zb], [xb, yb, zb], [xb, yb, za]]), .68],
        ];
        final polys = <_Poly>[];
        for (final fc in faces) {
          final pts = fc[0] as List<Vec3>;
          var dz = 0.0;
          for (final p in pts) {
            dz += pr.rotate(p).z;
          }
          polys.add(_Poly(poly(pts), dz / pts.length, fc[1] as double));
        }
        polys.sort((a, b) => b.depth.compareTo(a.depth));
        boxes.add(_Box(j, i, pr.depth(cx, (ya + yb) / 2, cz), polys, pp(cx, yb, cz)));
      }
    }
    boxes.sort((a, b) => b.depth.compareTo(a.depth));

    _Box? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      for (final b in boxes) {
        if (b.polys.any((p) => p.path.contains(ptr))) hover = b;
      }
    }
    for (final b in boxes) {
      final base = color(b.j);
      final hot = identical(b, hover);
      for (final p in b.polys) {
        canvas.drawPath(p.path, Paint()..color = shade(base, p.k * (hot ? 1.14 : 1)));
        canvas.drawPath(p.path, Paint()
          ..color = Colors.black.withAlpha(30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8);
      }
      if (w.showValueLabels && progress > .99) {
        paintText(canvas, fmt(w.values[b.j][b.i]), b.top + const Offset(0, -3), theme.labelStyle.copyWith(color: theme.textColor, fontWeight: FontWeight.w600),
            align: Alignment.bottomCenter);
      }
    }
    if (hover != null && ptr != null) {
      final j = hover.j, i = hover.i;
      paintTooltip(canvas, size, ptr, theme,
          title: '${j < w.seriesNames.length ? w.seriesNames[j] : 'Series ${j + 1}'} · ${w.categories[i]}',
          rows: [TooltipRow(fmt(w.values[j][i]), color: color(j))]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
