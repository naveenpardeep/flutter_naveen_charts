import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';

/// Chord diagram: `matrix[i][j]` is the flow from group i to group j.
/// Symmetric matrices give classic chords; asymmetric ones show direction
/// through different arc widths on each end.
class ChordChart extends StatelessWidget {
  const ChordChart({
    super.key,
    required this.labels,
    required this.matrix,
    this.colors,
    this.padAngle = 0.05,
    this.arcWidth = 14,
    this.ribbonOpacity = 0.55,
    this.showLabels = true,
    this.valueFormat,
    this.aspectRatio = 1.1,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 1000),
  });
  final List<String> labels;
  final List<List<double>> matrix;

  /// One colour per group (defaults to the theme palette).
  final List<Color>? colors;

  /// Gap between group arcs, in radians.
  final double padAngle;
  final double arcWidth;
  final double ribbonOpacity;
  final bool showLabels;
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
        builder: (p, ptr) => _ChordPainter(this, t, p, ptr),
      ),
    );
  }
}

class _Rib {
  _Rib(this.i, this.j, this.path, this.color);
  final int i, j;
  final Path path;
  final Color color;
}

class _ChordPainter extends CustomPainter {
  _ChordPainter(this.w, this.theme, this.progress, this.pointer);
  final ChordChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;
  static const double _start = -math.pi / 2;

  Color _c(int i) => (w.colors != null && i < w.colors!.length) ? w.colors![i] : theme.colorAt(i);

  Path _ribbon(Offset c, double r, double a0, double a1, double b0, double b1, bool self) {
    Offset pt(double a) => c + Offset.fromDirection(a, r);
    final rect = Rect.fromCircle(center: c, radius: r);
    final p = Path()..moveTo(pt(a0).dx, pt(a0).dy);
    p.arcTo(rect, a0, a1 - a0, false);
    if (self) {
      p.quadraticBezierTo(c.dx, c.dy, pt(a0).dx, pt(a0).dy);
    } else {
      p.quadraticBezierTo(c.dx, c.dy, pt(b0).dx, pt(b0).dy);
      p.arcTo(rect, b0, b1 - b0, false);
      p.quadraticBezierTo(c.dx, c.dy, pt(a0).dx, pt(a0).dy);
    }
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.labels.length;
    final m = w.matrix;
    if (n == 0 || m.length < n) return;
    double v(int i, int j) => j < m[i].length ? math.max(0.0, m[i][j]) : 0;
    final rowSum = [for (var i = 0; i < n; i++) [for (var j = 0; j < n; j++) v(i, j)].fold<double>(0, (a, b) => a + b)];
    final inSum = [for (var j = 0; j < n; j++) [for (var i = 0; i < n; i++) v(i, j)].fold<double>(0, (a, b) => a + b)];
    final total = rowSum.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    final fmt = w.valueFormat ?? formatNumber;
    final c = size.center(Offset.zero);
    final R = math.min(size.width, size.height) / 2 - (w.showLabels ? 48 : 10);
    if (R <= w.arcWidth + 6) return;
    final k = (2 * math.pi - n * w.padAngle) / total;

    final g0 = List<double>.filled(n, 0), g1 = List<double>.filled(n, 0);
    final s0 = List.generate(n, (_) => List<double>.filled(n, 0));
    final s1 = List.generate(n, (_) => List<double>.filled(n, 0));
    var a = _start;
    for (var i = 0; i < n; i++) {
      g0[i] = a;
      var x = a;
      for (var j = 0; j < n; j++) {
        s0[i][j] = x;
        x += v(i, j) * k;
        s1[i][j] = x;
      }
      g1[i] = x;
      a = x + w.padAngle;
    }

    final rr = R - w.arcWidth - 2;
    final ribs = <_Rib>[];
    for (var i = 0; i < n; i++) {
      for (var j = i; j < n; j++) {
        if (v(i, j) <= 0 && v(j, i) <= 0) continue;
        final src = v(i, j) >= v(j, i) ? i : j;
        ribs.add(_Rib(i, j, _ribbon(c, rr, s0[i][j], s1[i][j], s0[j][i], s1[j][i], i == j), _c(src)));
      }
    }

    int? hGroup;
    _Rib? hRib;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      final d = ptr - c;
      if (d.distance <= R && d.distance >= R - w.arcWidth) {
        var ang = math.atan2(d.dy, d.dx);
        if (ang < _start) ang += 2 * math.pi;
        for (var i = 0; i < n; i++) {
          if (ang >= g0[i] && ang <= g1[i]) hGroup = i;
        }
      } else if (d.distance < rr) {
        for (final r in ribs) {
          if (r.path.contains(ptr)) hRib = r;
        }
      }
    }

    for (final r in ribs) {
      double alpha = w.ribbonOpacity;
      if (hGroup != null) {
        alpha = (r.i == hGroup || r.j == hGroup) ? .85 : .08;
      } else if (hRib != null) {
        alpha = identical(r, hRib) ? .85 : .1;
      }
      canvas.drawPath(r.path, Paint()..color = r.color.faded(alpha * progress));
    }
    for (var i = 0; i < n; i++) {
      if (g1[i] <= g0[i]) continue;
      canvas.drawPath(sectorPath(c, R - w.arcWidth, R, g0[i], (g1[i] - g0[i]) * progress), Paint()..color = _c(i));
      if (w.showLabels && progress > .99) {
        final mid = (g0[i] + g1[i]) / 2;
        paintText(canvas, w.labels[i], c + Offset.fromDirection(mid, R + 10),
            theme.labelStyle.copyWith(color: theme.textColor),
            align: Alignment(-math.cos(mid), -math.sin(mid)));
      }
    }
    if (ptr != null) {
      if (hGroup != null) {
        paintTooltip(canvas, size, ptr, theme, title: w.labels[hGroup], rows: [
          TooltipRow('Out: ${fmt(rowSum[hGroup])}', color: _c(hGroup)),
          TooltipRow('In: ${fmt(inSum[hGroup])}'),
        ]);
      } else if (hRib != null) {
        final r = hRib;
        paintTooltip(canvas, size, ptr, theme,
            title: r.i == r.j ? w.labels[r.i] : '${w.labels[r.i]} ↔ ${w.labels[r.j]}',
            rows: [
              TooltipRow('${w.labels[r.i]} → ${w.labels[r.j]}: ${fmt(v(r.i, r.j))}', color: r.color),
              if (r.i != r.j) TooltipRow('${w.labels[r.j]} → ${w.labels[r.i]}: ${fmt(v(r.j, r.i))}'),
            ]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
