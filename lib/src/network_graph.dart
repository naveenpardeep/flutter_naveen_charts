import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';
import 'core/legend.dart';

class NetworkNode {
  const NetworkNode(this.id, {this.label, this.size = 1, this.group = 0, this.color});
  final String id;
  final String? label;

  /// Relative size (drives the circle radius).
  final double size;

  /// Nodes of the same group share a palette colour.
  final int group;
  final Color? color;
}

class NetworkEdge {
  const NetworkEdge(this.source, this.target, {this.weight = 1, this.color});
  final String source;
  final String target;
  final double weight;
  final Color? color;
}

/// Fruchterman-Reingold force layout in the unit square (deterministic per [seed]).
List<Offset> forceLayout(int n, List<int> src, List<int> dst, List<double> wt,
    {int iterations = 300, int seed = 7}) {
  if (n == 0) return [];
  if (n == 1) return [const Offset(.5, .5)];
  final rnd = math.Random(seed);
  final pos = [
    for (var i = 0; i < n; i++)
      Offset(.5 + .35 * math.cos(2 * math.pi * i / n) + (rnd.nextDouble() - .5) * .05,
          .5 + .35 * math.sin(2 * math.pi * i / n) + (rnd.nextDouble() - .5) * .05)
  ];
  final k = 0.9 * math.sqrt(1 / n);
  for (var it = 0; it < iterations; it++) {
    final temp = 0.1 * (1 - it / iterations) + 0.002;
    final disp = List<Offset>.filled(n, Offset.zero);
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final d = pos[i] - pos[j];
        final dist = math.max(d.distance, 0.001);
        final f = k * k / dist;
        final dir = d / dist;
        disp[i] += dir * f;
        disp[j] -= dir * f;
      }
    }
    for (var e = 0; e < src.length; e++) {
      final d = pos[src[e]] - pos[dst[e]];
      final dist = math.max(d.distance, 0.001);
      final f = dist * dist / k * wt[e].clamp(0.5, 2.0);
      final dir = d / dist;
      disp[src[e]] -= dir * f;
      disp[dst[e]] += dir * f;
    }
    for (var i = 0; i < n; i++) {
      disp[i] += (const Offset(.5, .5) - pos[i]) * 0.3;
      final len = disp[i].distance;
      if (len > 1e-9) pos[i] = pos[i] + disp[i] / len * math.min(len, temp);
    }
  }
  var minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity;
  for (final p in pos) {
    minX = math.min(minX, p.dx);
    maxX = math.max(maxX, p.dx);
    minY = math.min(minY, p.dy);
    maxY = math.max(maxY, p.dy);
  }
  final sx = maxX - minX < 1e-9 ? 1.0 : maxX - minX;
  final sy = maxY - minY < 1e-9 ? 1.0 : maxY - minY;
  return [for (final p in pos) Offset(.05 + .9 * (p.dx - minX) / sx, .05 + .9 * (p.dy - minY) / sy)];
}

/// Force-directed node-link graph. Drag nodes to rearrange them.
class NetworkGraph extends StatefulWidget {
  const NetworkGraph({
    super.key,
    required this.nodes,
    required this.edges,
    this.directed = false,
    this.showLabels = true,
    this.draggable = true,
    this.showLegend = false,
    this.groupNames,
    this.layoutIterations = 300,
    this.seed = 7,
    this.aspectRatio = 1.3,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<NetworkNode> nodes;
  final List<NetworkEdge> edges;
  final bool directed;
  final bool showLabels;

  /// Drag nodes with a finger / mouse (captures pan gestures on the chart).
  final bool draggable;
  final bool showLegend;
  final List<String>? groupNames;
  final int layoutIterations;
  final int seed;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  State<NetworkGraph> createState() => _NetworkGraphState();
}

Offset _toScreen(Offset p, Size s) =>
    Offset(28 + p.dx * (s.width - 56), 20 + p.dy * (s.height - 52));
Offset _fromScreen(Offset p, Size s) => Offset(
    ((p.dx - 28) / math.max(1, s.width - 56)).clamp(0.0, 1.0).toDouble(),
    ((p.dy - 20) / math.max(1, s.height - 52)).clamp(0.0, 1.0).toDouble());

class _NetworkGraphState extends State<NetworkGraph> {
  late List<Offset> _pos = _layout();
  int? _drag;

  List<Offset> _layout() {
    final idx = {for (var i = 0; i < widget.nodes.length; i++) widget.nodes[i].id: i};
    final s = <int>[], d = <int>[];
    final wt = <double>[];
    for (final e in widget.edges) {
      final a = idx[e.source], b = idx[e.target];
      if (a == null || b == null || a == b) continue;
      s.add(a);
      d.add(b);
      wt.add(e.weight);
    }
    return forceLayout(widget.nodes.length, s, d, wt,
        iterations: widget.layoutIterations, seed: widget.seed);
  }

  bool _same(NetworkGraph o) {
    if (o.nodes.length != widget.nodes.length || o.edges.length != widget.edges.length) return false;
    for (var i = 0; i < o.nodes.length; i++) {
      if (o.nodes[i].id != widget.nodes[i].id) return false;
    }
    for (var i = 0; i < o.edges.length; i++) {
      if (o.edges[i].source != widget.edges[i].source || o.edges[i].target != widget.edges[i].target) return false;
    }
    return o.seed == widget.seed;
  }

  @override
  void didUpdateWidget(NetworkGraph old) {
    super.didUpdateWidget(old);
    if (!_same(old)) _pos = _layout();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? ChartTheme.of(context);
    final groups = {for (final n in widget.nodes) n.group}.toList()..sort();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: LayoutBuilder(builder: (context, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          return GestureDetector(
            onPanStart: widget.draggable
                ? (d) {
                    int? best;
                    var bd = 22.0;
                    for (var i = 0; i < _pos.length; i++) {
                      final dist = (_toScreen(_pos[i], size) - d.localPosition).distance;
                      if (dist < bd) {
                        bd = dist;
                        best = i;
                      }
                    }
                    _drag = best;
                  }
                : null,
            onPanUpdate: widget.draggable
                ? (d) {
                    if (_drag == null) return;
                    setState(() => _pos[_drag!] = _fromScreen(d.localPosition, size));
                  }
                : null,
            onPanEnd: widget.draggable ? (_) => _drag = null : null,
            child: ChartCanvas(
              duration: widget.animationDuration,
              builder: (p, ptr) => _NetworkPainter(widget, t, p, ptr, _pos),
            ),
          );
        }),
      ),
      if (widget.showLegend && groups.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ChartLegend(theme: t, items: [
            for (final g in groups)
              LegendItem(
                  (widget.groupNames != null && g < widget.groupNames!.length) ? widget.groupNames![g] : 'Group $g',
                  t.colorAt(g)),
          ]),
        ),
    ]);
  }
}

class _NetworkPainter extends CustomPainter {
  _NetworkPainter(this.w, this.theme, this.progress, this.pointer, this.pos);
  final NetworkGraph w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;
  final List<Offset> pos;

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.nodes.length;
    if (n == 0 || pos.length != n) return;
    final idx = {for (var i = 0; i < n; i++) w.nodes[i].id: i};
    final maxSize = w.nodes.map((e) => e.size).reduce(math.max);
    double radius(int i) => 6 + 12 * math.sqrt(maxSize <= 0 ? 0 : w.nodes[i].size / maxSize);
    Color color(int i) => w.nodes[i].color ?? theme.colorAt(w.nodes[i].group);
    final scr = [for (final p in pos) _toScreen(p, size)];
    final deg = List<int>.filled(n, 0);
    final edges = <List<int>>[];
    final es = <NetworkEdge>[];
    for (final e in w.edges) {
      final a = idx[e.source], b = idx[e.target];
      if (a == null || b == null) continue;
      edges.add([a, b]);
      es.add(e);
      deg[a]++;
      deg[b]++;
    }
    final maxW = es.isEmpty ? 1.0 : es.map((e) => e.weight).reduce(math.max);

    int? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      for (var i = 0; i < n; i++) {
        if ((scr[i] - ptr).distance <= radius(i) + 4) hover = i;
      }
    }
    bool linked(int i) =>
        hover == null ||
        i == hover ||
        edges.any((e) => (e[0] == hover && e[1] == i) || (e[1] == hover && e[0] == i));

    for (var k = 0; k < edges.length; k++) {
      final a = edges[k][0], b = edges[k][1];
      final hot = hover != null && (a == hover || b == hover);
      final dim = hover != null && !hot;
      final base = es[k].color ?? theme.axisColor;
      final paint = Paint()
        ..color = base.faded(dim ? .12 : (hot ? .9 : .5)) 
        ..strokeWidth = 1 + 3 * (maxW <= 0 ? 0 : es[k].weight / maxW)
        ..strokeCap = StrokeCap.round;
      final p1 = scr[a], p2 = scr[b];
      canvas.drawLine(p1, p2, paint);
      if (w.directed) {
        final dir = (p2 - p1) / math.max(1.0, (p2 - p1).distance);
        final tip = p2 - dir * (radius(b) + 2);
        final left = Offset(-dir.dy, dir.dx);
        canvas.drawPath(
            Path()
              ..moveTo(tip.dx, tip.dy)
              ..lineTo(tip.dx - dir.dx * 9 + left.dx * 4.5, tip.dy - dir.dy * 9 + left.dy * 4.5)
              ..lineTo(tip.dx - dir.dx * 9 - left.dx * 4.5, tip.dy - dir.dy * 9 - left.dy * 4.5)
              ..close(),
            Paint()..color = paint.color);
      }
    }
    for (var i = 0; i < n; i++) {
      final r = radius(i) * progress;
      final fade = linked(i) ? 1.0 : .25;
      canvas.drawCircle(scr[i], r, Paint()..color = color(i).faded(fade));
      canvas.drawCircle(scr[i], r, Paint()
        ..color = theme.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      if (w.showLabels && progress > .99) {
        paintText(canvas, w.nodes[i].label ?? w.nodes[i].id, scr[i] + Offset(0, r + 2),
            theme.labelStyle.copyWith(color: theme.textColor.faded(fade)),
            align: Alignment.topCenter, maxWidth: 90);
      }
    }
    if (hover != null && ptr != null) {
      final nd = w.nodes[hover];
      paintTooltip(canvas, size, ptr, theme, title: nd.label ?? nd.id, rows: [
        TooltipRow('Connections: ${deg[hover]}', color: color(hover)),
        TooltipRow('Size: ${formatNumber(nd.size)}'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
