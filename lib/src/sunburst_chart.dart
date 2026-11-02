import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';
import 'core/hierarchy.dart';

/// Multi-level donut for hierarchical data.
class SunburstChart extends StatelessWidget {
  const SunburstChart({
    super.key,
    required this.roots,
    this.holeRatio = 0.22,
    this.showLabels = true,
    this.centerLabel = 'Total',
    this.valueFormat,
    this.aspectRatio = 1.1,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<HierarchyNode> roots;
  final double holeRatio;
  final bool showLabels;
  final String centerLabel;
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
        builder: (p, ptr) => _SunburstPainter(this, t, p, ptr),
      ),
    );
  }
}

class _Arc {
  _Arc(this.node, this.r0, this.r1, this.a0, this.sweep, this.color, this.path, this.depth);
  final HierarchyNode node;
  final double r0, r1, a0, sweep;
  final Color color;
  final String path;
  final int depth;
}

class _SunburstPainter extends CustomPainter {
  _SunburstPainter(this.w, this.theme, this.progress, this.pointer);
  final SunburstChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;
  static const double _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final total = w.roots.fold<double>(0, (a, n) => a + n.total);
    if (total <= 0) return;
    final levels = w.roots.map((n) => n.depth).reduce(math.max);
    final c = size.center(Offset.zero);
    final R = math.min(size.width, size.height) / 2 - 6;
    if (R <= 0) return;
    final hole = R * w.holeRatio;
    final ringW = (R - hole) / levels;
    final fmt = w.valueFormat ?? formatNumber;

    final arcs = <_Arc>[];
    void walk(List<HierarchyNode> ns, double a0, double span, int depth,
        Color? inherited, String parent, double parentTotal) {
      var a = a0;
      for (var i = 0; i < ns.length; i++) {
        final n = ns[i];
        if (n.total <= 0) continue;
        final sweep = n.total / parentTotal * span;
        final color = n.color ?? inherited ?? theme.colorAt(i);
        final path = parent.isEmpty ? n.label : '$parent › ${n.label}';
        arcs.add(_Arc(n, hole + depth * ringW, hole + (depth + 1) * ringW, a, sweep,
            Color.lerp(color, Colors.white, .1 * depth)!, path, depth));
        if (n.children.isNotEmpty) walk(n.children, a, sweep, depth + 1, color, path, n.total);
        a += sweep;
      }
    }

    walk(w.roots, _start, 2 * math.pi, 0, null, '', total);

    _Arc? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      final d = ptr - c;
      final a = (math.atan2(d.dy, d.dx) - _start) % (2 * math.pi);
      for (final arc in arcs) {
        if (d.distance >= arc.r0 && d.distance < arc.r1) {
          final rel = arc.a0 - _start;
          if (a >= rel && a < rel + arc.sweep) hover = arc;
        }
      }
    }
    for (final arc in arcs) {
      final path = sectorPath(c, arc.r0 * progress, arc.r1 * progress, arc.a0, arc.sweep);
      canvas.drawPath(path, Paint()..color = identical(arc, hover) ? arc.color.faded(.8) : arc.color);
      canvas.drawPath(path, Paint()
        ..color = theme.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2);
      final mid = arc.a0 + arc.sweep / 2;
      final rm = (arc.r0 + arc.r1) / 2;
      if (w.showLabels && progress > .99 && rm * arc.sweep > 34 && ringW > 16) {
        paintText(canvas, arc.node.label, c + Offset.fromDirection(mid, rm),
            TextStyle(color: contrastOn(arc.color), fontSize: 10, fontWeight: FontWeight.w600),
            maxWidth: math.min(ringW * 2.2, rm * arc.sweep));
      }
    }
    final shown = hover?.node;
    paintText(canvas, shown != null ? fmt(shown.total) : fmt(total), c,
        TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
        maxWidth: hole * 1.8);
    paintText(canvas, shown?.label ?? w.centerLabel, c + const Offset(0, 16), theme.labelStyle,
        maxWidth: hole * 1.8);
    if (hover != null && ptr != null) {
      paintTooltip(canvas, size, ptr, theme, title: hover.path, rows: [
        TooltipRow('${fmt(hover.node.total)} (${(hover.node.total / total * 100).toStringAsFixed(1)}%)',
            color: hover.color)
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
