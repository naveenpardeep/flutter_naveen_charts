// Dependency wheel: a directed chord diagram built from a list of links.

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/chart_canvas.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../network_graph.dart' show NetworkNode, NetworkEdge;
import 'relation_utils.dart';

/// Dependency wheel: items are arcs on a circle and every dependency is a
/// ribbon from the item that depends (source) to the item it depends on
/// (target). The ribbon fades from the source colour to the target colour and
/// its width is the link weight. Arc length is the total of the item's
/// incoming and outgoing weight.
///
/// Compared with [ChordChart], which takes a matrix, this chart takes a plain
/// list of links, which is how dependency data usually arrives (packages,
/// modules, services, ...).
///
/// Hover an arc to isolate that item's links, or a ribbon for details.
class DependencyWheelChart extends StatelessWidget {
  const DependencyWheelChart({
    super.key,
    required this.nodes,
    required this.edges,
    this.padAngle = 0.05,
    this.arcWidth = 14,
    this.ribbonOpacity = 0.6,
    this.showLabels = true,
    this.valueFormat,
    this.aspectRatio = 1.1,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 1000),
  });

  /// Items on the wheel, in clockwise order starting at 12 o'clock.
  final List<NetworkNode> nodes;

  /// `source` depends on `target`; `weight` sets the ribbon width.
  final List<NetworkEdge> edges;

  /// Gap between arcs in radians.
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
        builder: (p, ptr) => _WheelPainter(this, t, p, ptr),
      ),
    );
  }
}

/// A link with its two arc segments (angles) once the wheel is laid out.
class _Rib {
  _Rib(this.src, this.dst, this.weight);
  final int src, dst;
  final double weight;
  double s0 = 0, s1 = 0; // segment on the source arc
  double t0 = 0, t1 = 0; // segment on the target arc
  late Path path;
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.w, this.theme, this.progress, this.pointer);
  final DependencyWheelChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;
  static const double _start = -math.pi / 2; // 12 o'clock

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.nodes.length;
    if (n == 0) return;
    final fmt = w.valueFormat ?? formatNumber;
    final index = {for (var i = 0; i < n; i++) w.nodes[i].id: i};
    Color colorOf(int i) => w.nodes[i].color ?? theme.colorAt(w.nodes[i].group + i);

    // ---- 1. keep valid links and total up the weight per node
    final ribs = <_Rib>[];
    for (final e in w.edges) {
      final a = index[e.source], b = index[e.target];
      if (a != null && b != null && a != b && e.weight > 0) ribs.add(_Rib(a, b, e.weight));
    }
    if (ribs.isEmpty) return;
    final total = List<double>.filled(n, 0), outSum = List<double>.filled(n, 0), inSum = List<double>.filled(n, 0);
    for (final r in ribs) {
      total[r.src] += r.weight;
      total[r.dst] += r.weight;
      outSum[r.src] += r.weight;
      inSum[r.dst] += r.weight;
    }
    final grand = total.fold<double>(0, (a, b) => a + b);

    // ---- 2. circle geometry
    final c = size.center(Offset.zero);
    final R = math.min(size.width, size.height) / 2 - (w.showLabels ? 50 : 10);
    if (R <= w.arcWidth + 8) return;
    final rr = R - w.arcWidth - 2; // ribbons end just inside the arcs
    final k = (2 * math.pi - n * w.padAngle) / grand; // radians per unit of weight

    // ---- 3. give every node an arc and split it into link segments:
    //         outgoing links first (ordered by target), then incoming ones
    final g0 = List<double>.filled(n, 0), g1 = List<double>.filled(n, 0);
    var cursor = _start;
    for (var i = 0; i < n; i++) {
      g0[i] = cursor;
      final outs = ribs.where((r) => r.src == i).toList()..sort((a, b) => a.dst.compareTo(b.dst));
      for (final r in outs) {
        r.s0 = cursor;
        cursor += r.weight * k;
        r.s1 = cursor;
      }
      final ins = ribs.where((r) => r.dst == i).toList()..sort((a, b) => a.src.compareTo(b.src));
      for (final r in ins) {
        r.t0 = cursor;
        cursor += r.weight * k;
        r.t1 = cursor;
      }
      g1[i] = cursor;
      cursor += w.padAngle;
    }
    for (final r in ribs) {
      r.path = ribbonPath(c, rr, r.s0, r.s1, r.t0, r.t1);
    }

    // ---- 4. hit-testing: arcs ring first, then ribbons inside it
    int? hNode;
    _Rib? hRib;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      final d = ptr - c;
      if (d.distance <= R && d.distance >= R - w.arcWidth) {
        var ang = math.atan2(d.dy, d.dx);
        if (ang < _start) ang += 2 * math.pi;
        for (var i = 0; i < n; i++) {
          if (ang >= g0[i] && ang <= g1[i]) hNode = i;
        }
      } else if (d.distance < rr) {
        for (final r in ribs) {
          if (r.path.contains(ptr)) hRib = r;
        }
      }
    }

    // ---- 5. ribbons: gradient from the source colour to the target colour
    for (final r in ribs) {
      final strong = identical(r, hRib) || (hNode != null && (r.src == hNode || r.dst == hNode));
      final dim = (hNode != null || hRib != null) && !strong;
      final a = c + Offset.fromDirection((r.s0 + r.s1) / 2, rr);
      final b = c + Offset.fromDirection((r.t0 + r.t1) / 2, rr);
      final alpha = (dim ? .08 : (strong ? .9 : w.ribbonOpacity)) * progress;
      canvas.drawPath(
          r.path,
          Paint()
            ..shader = ui.Gradient.linear(a, b, [colorOf(r.src).faded(alpha), colorOf(r.dst).faded(alpha)]));
    }

    // ---- 6. node arcs and labels
    for (var i = 0; i < n; i++) {
      if (g1[i] <= g0[i]) continue;
      canvas.drawPath(sectorPath(c, R - w.arcWidth, R, g0[i], (g1[i] - g0[i]) * progress), Paint()..color = colorOf(i));
      if (w.showLabels && progress > .99) {
        final mid = (g0[i] + g1[i]) / 2;
        paintText(canvas, w.nodes[i].label ?? w.nodes[i].id, c + Offset.fromDirection(mid, R + 10),
            theme.labelStyle.copyWith(color: theme.textColor), align: Alignment(-math.cos(mid), -math.sin(mid)));
      }
    }

    // ---- 7. tooltip
    if (ptr != null) {
      if (hNode != null) {
        paintTooltip(canvas, size, ptr, theme, title: w.nodes[hNode].label ?? w.nodes[hNode].id, rows: [
          TooltipRow('Depends on others: ${fmt(outSum[hNode])}', color: colorOf(hNode)),
          TooltipRow('Used by others: ${fmt(inSum[hNode])}'),
        ]);
      } else if (hRib != null) {
        final r = hRib;
        paintTooltip(canvas, size, ptr, theme,
            title: '${w.nodes[r.src].label ?? w.nodes[r.src].id} → ${w.nodes[r.dst].label ?? w.nodes[r.dst].id}',
            rows: [TooltipRow(fmt(r.weight), color: colorOf(r.src))]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
