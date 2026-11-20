// Arc diagram: nodes on a line, links drawn as arcs above it.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';
import '../network_graph.dart' show NetworkNode, NetworkEdge;
import 'relation_utils.dart';

/// How [ArcDiagram] orders its nodes along the line.
enum ArcNodeOrder {
  /// Keep the order of `nodes`.
  given,

  /// Most connected first - reveals hubs.
  degree,

  /// Group by `NetworkNode.group`, then keep the given order - reveals clusters.
  group,

  /// Alphabetical by label.
  name,
}

/// Arc diagram: nodes sit on a horizontal line and every link is a
/// half-ellipse above it. Arc width follows the edge weight. Good for showing
/// clusters and long-range links in a sequence (chapters, time, genome...).
///
/// Hover a node to light up its links, or hover an arc for details.
class ArcDiagram extends StatelessWidget {
  const ArcDiagram({
    super.key,
    required this.nodes,
    required this.edges,
    this.order = ArcNodeOrder.given,
    this.directed = false,
    this.showLabels = true,
    this.rotateLabels = true,
    this.minArcWidth = 1,
    this.maxArcWidth = 7,
    this.arcOpacity = 0.55,
    this.aspectRatio = 1.8,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  /// The nodes (reuses the node type of [NetworkGraph]).
  final List<NetworkNode> nodes;

  /// Links between node ids; `weight` sets the arc thickness.
  final List<NetworkEdge> edges;

  /// Node order along the line.
  final ArcNodeOrder order;

  /// Draw an arrow head at the target end of each arc.
  final bool directed;
  final bool showLabels;

  /// Write labels vertically (saves width when there are many nodes).
  final bool rotateLabels;

  /// Arc thickness range in pixels (lightest and heaviest edge).
  final double minArcWidth, maxArcWidth;
  final double arcOpacity;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return chartShell(
      theme: t,
      aspectRatio: aspectRatio,
      duration: animationDuration,
      builder: (p, ptr) => _ArcPainter(this, t, p, ptr),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.w, this.theme, this.progress, this.pointer);
  final ArcDiagram w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.nodes.length;
    if (n == 0) return;

    // ---- 1. decide the order of the nodes on the line
    final degree = List<int>.filled(n, 0);
    final index = {for (var i = 0; i < n; i++) w.nodes[i].id: i};
    for (final e in w.edges) {
      final a = index[e.source], b = index[e.target];
      if (a != null && b != null) {
        degree[a]++;
        degree[b]++;
      }
    }
    final order = List<int>.generate(n, (i) => i);
    switch (w.order) {
      case ArcNodeOrder.given:
        break;
      case ArcNodeOrder.degree:
        order.sort((a, b) => degree[b].compareTo(degree[a]));
      case ArcNodeOrder.group:
        order.sort((a, b) => w.nodes[a].group != w.nodes[b].group ? w.nodes[a].group.compareTo(w.nodes[b].group) : a.compareTo(b));
      case ArcNodeOrder.name:
        order.sort((a, b) => (w.nodes[a].label ?? w.nodes[a].id).compareTo(w.nodes[b].label ?? w.nodes[b].id));
    }
    final slot = List<int>.filled(n, 0); // node index -> position on the line
    for (var k = 0; k < n; k++) {
      slot[order[k]] = k;
    }

    // ---- 2. geometry of the line and the labels underneath
    final labels = [for (final i in order) w.nodes[i].label ?? w.nodes[i].id];
    final labelH = !w.showLabels
        ? 0.0
        : (w.rotateLabels ? math.min(80.0, labels.map((s) => measureText(s, theme.labelStyle).width).fold<double>(0, math.max) + 8) : 22.0);
    final left = 20.0, right = size.width - 20, top = 10.0;
    final baseline = size.height - labelH - 14;
    if (right - left < 40 || baseline - top < 30) return;
    double nx(int node) => left + (slot[node] + .5) / n * (right - left);

    // ---- 3. resolve the edges and scale arc widths / heights
    final es = <List<int>>[]; // [source node, target node, edge index]
    for (var k = 0; k < w.edges.length; k++) {
      final a = index[w.edges[k].source], b = index[w.edges[k].target];
      if (a != null && b != null && a != b) es.add([a, b, k]);
    }
    if (es.isEmpty && n < 2) return;
    final maxW = es.isEmpty ? 1.0 : es.map((e) => w.edges[e[2]].weight).reduce(math.max);
    final minW = es.isEmpty ? 0.0 : es.map((e) => w.edges[e[2]].weight).reduce(math.min);
    double widthOf(double weight) => maxW == minW
        ? (w.minArcWidth + w.maxArcWidth) / 2
        : w.minArcWidth + (w.maxArcWidth - w.minArcWidth) * (weight - minW) / (maxW - minW);
    // The widest arc would be a half circle of radius (right-left)/2; squash
    // every arc vertically if that would not fit above the baseline.
    final maxRx = es.isEmpty ? 1.0 : es.map((e) => (nx(e[0]) - nx(e[1])).abs() / 2).reduce(math.max);
    final yScale = math.min(1.0, (baseline - top - 6) / math.max(maxRx, 1));

    Color colorOf(int node) => w.nodes[node].color ?? theme.colorAt(w.nodes[node].group);
    Rect ovalOf(List<int> e) {
      final x1 = nx(e[0]), x2 = nx(e[1]);
      final rx = (x1 - x2).abs() / 2;
      return Rect.fromCenter(center: Offset((x1 + x2) / 2, baseline), width: rx * 2, height: rx * 2 * yScale);
    }

    // ---- 4. hit-testing: nodes first, then arcs
    int? hNode;
    int? hEdge;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      for (var i = 0; i < n; i++) {
        if ((Offset(nx(i), baseline) - ptr).distance <= 9) hNode = i;
      }
      if (hNode == null) {
        var best = 7.0;
        for (var k = 0; k < es.length; k++) {
          final oval = ovalOf(es[k]);
          if (ptr.dy > baseline + 4) continue;
          // Normalised distance from the ellipse outline, scaled back to pixels.
          final u = (ptr.dx - oval.center.dx) / (oval.width / 2), v = (ptr.dy - baseline) / (oval.height / 2);
          final d = ((math.sqrt(u * u + v * v) - 1).abs()) * (oval.width / 2 + oval.height / 2) / 2;
          if (d < best) {
            best = d;
            hEdge = k;
          }
        }
      }
    }

    // ---- 5. draw arcs (heaviest first so thin ones stay visible)
    final drawOrder = List<int>.generate(es.length, (k) => k)
      ..sort((a, b) => w.edges[es[b][2]].weight.compareTo(w.edges[es[a][2]].weight));
    for (final k in drawOrder) {
      final e = es[k];
      final edge = w.edges[e[2]];
      final connected = hNode != null && (e[0] == hNode || e[1] == hNode);
      final strong = connected || hEdge == k;
      final dim = (hNode != null || hEdge != null) && !strong;
      final color = edge.color ?? colorOf(e[0]);
      // The arc is the upper half of an ellipse: from angle pi to 2*pi.
      final left2right = nx(e[0]) <= nx(e[1]);
      final oval = ovalOf(e);
      canvas.drawArc(
          Rect.fromCenter(center: oval.center, width: oval.width, height: oval.height),
          math.pi,
          math.pi * progress, // animate the arc being drawn
          false,
          Paint()
            ..color = color.faded(dim ? .1 : (strong ? .95 : w.arcOpacity))
            ..style = PaintingStyle.stroke
            ..strokeWidth = widthOf(edge.weight) * (strong ? 1.25 : 1)
            ..strokeCap = StrokeCap.round);
      if (w.directed && progress > .99) {
        // Small arrow head just above the target node, pointing down.
        final tx = nx(e[1]);
        final dir = left2right ? 1.0 : -1.0;
        canvas.drawPath(
            Path()
              ..moveTo(tx, baseline - 9)
              ..lineTo(tx - 4 * dir - 2, baseline - 18)
              ..lineTo(tx - 4 * dir + 6, baseline - 16)
              ..close(),
            Paint()..color = color.faded(dim ? .15 : .9));
      }
    }

    // ---- 6. nodes and labels
    canvas.drawLine(Offset(left, baseline), Offset(right, baseline), Paint()
      ..color = theme.axisColor
      ..strokeWidth = 1.2);
    for (var i = 0; i < n; i++) {
      final active = hNode == null || hNode == i || es.any((e) => (e[0] == hNode && e[1] == i) || (e[1] == hNode && e[0] == i));
      final r = (4 + 5 * math.sqrt(degree[i].toDouble() / math.max(1, degree.reduce(math.max)))) * progress;
      canvas.drawCircle(Offset(nx(i), baseline), r, Paint()..color = colorOf(i).faded(active ? 1 : .3));
      if (w.showLabels && progress > .99) {
        final style = theme.labelStyle.copyWith(color: theme.textColor.faded(active ? 1 : .35));
        final label = w.nodes[i].label ?? w.nodes[i].id;
        if (w.rotateLabels) {
          paintRotatedText(canvas, label, Offset(nx(i), baseline + 10), style, math.pi / 2, maxWidth: labelH);
        } else {
          paintText(canvas, label, Offset(nx(i), baseline + 10), style, align: Alignment.topCenter, maxWidth: (right - left) / n);
        }
      }
    }

    // ---- 7. tooltip
    if (ptr != null) {
      if (hNode != null) {
        final nd = w.nodes[hNode];
        paintTooltip(canvas, size, ptr, theme, title: nd.label ?? nd.id, rows: [
          TooltipRow('Connections: ${degree[hNode]}', color: colorOf(hNode)),
        ]);
      } else if (hEdge != null) {
        final e = es[hEdge];
        final edge = w.edges[e[2]];
        paintTooltip(canvas, size, ptr, theme,
            title: '${w.nodes[e[0]].label ?? w.nodes[e[0]].id} ${w.directed ? '→' : '↔'} ${w.nodes[e[1]].label ?? w.nodes[e[1]].id}',
            rows: [TooltipRow('Weight: ${formatNumber(edge.weight)}', color: edge.color ?? colorOf(e[0]))]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
