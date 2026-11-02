import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';

class SankeyNode {
  const SankeyNode(this.id, {this.label, this.color});
  final String id;
  final String? label;
  final Color? color;
}

class SankeyLink {
  const SankeyLink(this.source, this.target, this.value, {this.color});
  final String source;
  final String target;
  final double value;
  final Color? color;
}

/// Flow diagram. Columns are inferred from the links (longest path).
class SankeyChart extends StatelessWidget {
  const SankeyChart({
    super.key,
    required this.nodes,
    required this.links,
    this.nodeWidth = 14,
    this.nodePadding = 10,
    this.linkOpacity = 0.35,
    this.showLabels = true,
    this.valueFormat,
    this.aspectRatio = 1.5,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 1000),
  });
  final List<SankeyNode> nodes;
  final List<SankeyLink> links;
  final double nodeWidth;
  final double nodePadding;
  final double linkOpacity;
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
        builder: (p, ptr) => _SankeyPainter(this, t, p, ptr),
      ),
    );
  }
}

class _SankeyPainter extends CustomPainter {
  _SankeyPainter(this.w, this.theme, this.progress, this.pointer);
  final SankeyChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.nodes.length;
    if (n == 0) return;
    final idx = {for (var i = 0; i < n; i++) w.nodes[i].id: i};
    final ls = [
      for (final l in w.links)
        if (idx.containsKey(l.source) &&
            idx.containsKey(l.target) &&
            l.value > 0 &&
            l.source != l.target)
          l
    ];
    if (ls.isEmpty) return;
    final fmt = w.valueFormat ?? formatNumber;
    final si = [for (final l in ls) idx[l.source]!];
    final ti = [for (final l in ls) idx[l.target]!];

    final depth = List<int>.filled(n, 0);
    for (var it = 0; it < n; it++) {
      var changed = false;
      for (var k = 0; k < ls.length; k++) {
        final want = math.min(depth[si[k]] + 1, n - 1);
        if (depth[ti[k]] < want) {
          depth[ti[k]] = want;
          changed = true;
        }
      }
      if (!changed) break;
    }
    final inV = List<double>.filled(n, 0), outV = List<double>.filled(n, 0);
    for (var k = 0; k < ls.length; k++) {
      outV[si[k]] += ls[k].value;
      inV[ti[k]] += ls[k].value;
    }
    final val = [for (var i = 0; i < n; i++) math.max(inV[i], outV[i])];
    final maxD = depth.reduce(math.max);
    final cols = List.generate(maxD + 1, (_) => <int>[]);
    for (var i = 0; i < n; i++) {
      if (val[i] > 0) cols[depth[i]].add(i);
    }

    final plot = Rect.fromLTRB(
        4, 8, size.width - (w.showLabels ? 72 : 4), size.height - 8);
    if (plot.width <= 0 || plot.height <= 0) return;
    var ky = double.infinity;
    for (final col in cols) {
      if (col.isEmpty) continue;
      final sum = col.fold<double>(0, (a, i) => a + val[i]);
      ky = math.min(ky, (plot.height - w.nodePadding * (col.length - 1)) / sum);
    }
    if (!ky.isFinite || ky <= 0) return;

    final rect = List<Rect>.filled(n, Rect.zero);
    for (var d = 0; d <= maxD; d++) {
      final col = cols[d];
      if (col.isEmpty) continue;
      final totalH = col.fold<double>(0, (a, i) => a + val[i]) * ky +
          w.nodePadding * (col.length - 1);
      var y = plot.top + (plot.height - totalH) / 2;
      final x = plot.left +
          (maxD == 0 ? 0 : d * (plot.width - w.nodeWidth) / maxD);
      for (final i in col) {
        final h = val[i] * ky;
        rect[i] = Rect.fromLTWH(x, y, w.nodeWidth, h);
        y += h + w.nodePadding;
      }
    }

    final sY = List<double>.filled(ls.length, 0), tY = List<double>.filled(ls.length, 0);
    for (var i = 0; i < n; i++) {
      final outs = [
        for (var k = 0; k < ls.length; k++)
          if (si[k] == i) k
      ]..sort((a, b) => rect[ti[a]].top.compareTo(rect[ti[b]].top));
      var y = rect[i].top;
      for (final k in outs) {
        sY[k] = y;
        y += ls[k].value * ky;
      }
      final ins = [
        for (var k = 0; k < ls.length; k++)
          if (ti[k] == i) k
      ]..sort((a, b) => rect[si[a]].top.compareTo(rect[si[b]].top));
      y = rect[i].top;
      for (final k in ins) {
        tY[k] = y;
        y += ls[k].value * ky;
      }
    }

    Color nodeColor(int i) => w.nodes[i].color ?? theme.colorAt(i);
    String nodeLabel(int i) => w.nodes[i].label ?? w.nodes[i].id;
    final paths = <Path>[];
    for (var k = 0; k < ls.length; k++) {
      final x0 = rect[si[k]].right, x1 = rect[ti[k]].left;
      final h = ls[k].value * ky;
      final mx = (x0 + x1) / 2;
      paths.add(Path()
        ..moveTo(x0, sY[k])
        ..cubicTo(mx, sY[k], mx, tY[k], x1, tY[k])
        ..lineTo(x1, tY[k] + h)
        ..cubicTo(mx, tY[k] + h, mx, sY[k] + h, x0, sY[k] + h)
        ..close());
    }

    int? hLink, hNode;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      for (var i = 0; i < n; i++) {
        if (val[i] > 0 && rect[i].inflate(2).contains(ptr)) hNode = i;
      }
      if (hNode == null) {
        for (var k = 0; k < paths.length; k++) {
          if (paths[k].contains(ptr)) hLink = k;
        }
      }
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    for (var k = 0; k < ls.length; k++) {
      final connected = hNode != null && (si[k] == hNode || ti[k] == hNode);
      final strong = hLink == k || connected;
      final dim = (hLink != null || hNode != null) && !strong;
      final base = ls[k].color ?? nodeColor(si[k]);
      canvas.drawPath(paths[k],
          Paint()..color = base.faded(strong ? .7 : (dim ? w.linkOpacity * .4 : w.linkOpacity)));
    }
    for (var i = 0; i < n; i++) {
      if (val[i] <= 0) continue;
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect[i], const Radius.circular(2)),
          Paint()..color = nodeColor(i));
      if (w.showLabels && progress > .99) {
        paintText(canvas, nodeLabel(i), Offset(rect[i].right + 5, rect[i].center.dy),
            theme.labelStyle.copyWith(color: theme.textColor),
            align: Alignment.centerLeft, maxWidth: 66);
      }
    }
    canvas.restore();

    if (ptr != null) {
      if (hLink != null) {
        final k = hLink;
        final pct = ls[k].value / outV[si[k]] * 100;
        paintTooltip(canvas, size, ptr, theme,
            title: '${nodeLabel(si[k])} → ${nodeLabel(ti[k])}',
            rows: [TooltipRow('${fmt(ls[k].value)} (${pct.toStringAsFixed(0)}% of source)', color: nodeColor(si[k]))]);
      } else if (hNode != null) {
        paintTooltip(canvas, size, ptr, theme, title: nodeLabel(hNode), rows: [
          if (inV[hNode] > 0) TooltipRow('In: ${fmt(inV[hNode])}', color: nodeColor(hNode)),
          if (outV[hNode] > 0) TooltipRow('Out: ${fmt(outV[hNode])}', color: nodeColor(hNode)),
        ]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
