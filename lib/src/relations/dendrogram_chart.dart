// Dendrogram: a tree with elbow connectors and aligned leaves.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';
import 'relation_utils.dart';

/// Direction a [DendrogramChart] grows in.
enum DendrogramOrientation {
  /// Root on the left, leaves on the right.
  horizontal,

  /// Root at the top, leaves at the bottom.
  vertical,
}

/// Dendrogram of a [TreeNode] tree, e.g. a hierarchical clustering or a
/// taxonomy. Leaves are lined up on one side and every parent sits in the
/// middle of its children, joined by right-angled connectors.
///
/// If any node has a `height` above zero the distance axis uses those values
/// (typical for clustering: the height is the merge distance) and an axis is
/// drawn; otherwise the subtree depth decides how far a node is from the
/// leaves. Branches under the same child of the root share a colour.
///
/// Hover a node to highlight its whole subtree.
class DendrogramChart extends StatelessWidget {
  const DendrogramChart({
    super.key,
    required this.root,
    this.orientation = DendrogramOrientation.horizontal,
    this.colorBranches = true,
    this.showNodes = true,
    this.showInternalLabels = false,
    this.lineWidth = 1.8,
    this.distanceFormat,
    this.aspectRatio = 1.5,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  /// Root of the tree.
  final TreeNode root;
  final DendrogramOrientation orientation;

  /// Give each top-level branch its own colour (otherwise all grey).
  final bool colorBranches;

  /// Draw a dot at every node.
  final bool showNodes;

  /// Also label internal nodes (leaves are always labelled).
  final bool showInternalLabels;
  final double lineWidth;
  final String Function(double)? distanceFormat;
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
      builder: (p, ptr) => _DendroPainter(this, t, p, ptr),
    );
  }
}

class _DendroPainter extends CustomPainter {
  _DendroPainter(this.w, this.theme, this.progress, this.pointer);
  final DendrogramChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    // ---- 1. lay the tree out and decide what the distance axis means
    final root = layoutTree(w.root);
    final all = [root, ...root.descendants];
    final horizontal = w.orientation == DendrogramOrientation.horizontal;
    final useHeights = all.any((n) => n.node.height > 0);
    // Distance of a node from the leaves: its merge height, or (without
    // heights) the number of levels below it.
    double dist(TreeLayoutNode n) => n.node.isLeaf ? 0 : (useHeights ? n.node.height : (n.node.depth - 1).toDouble());
    final maxDist = math.max(all.map(dist).reduce(math.max), 1e-9);
    final fmt = w.distanceFormat ?? formatNumber;

    // ---- 2. plot area: leave room for leaf labels (and the axis)
    final leafLabels = [for (final n in all) if (n.node.isLeaf || w.showInternalLabels) n.node.label];
    final maxLabel = leafLabels.map((s) => measureText(s, theme.labelStyle).width).fold<double>(0, math.max);
    final axisSpace = useHeights ? 24.0 : 0.0;
    final plot = horizontal
        ? Rect.fromLTRB(14, 12, size.width - maxLabel - 20, size.height - 10 - axisSpace)
        : Rect.fromLTRB(14 + axisSpace, 12, size.width - 14, size.height - math.min(maxLabel, 90.0) - 22);
    if (plot.width < 30 || plot.height < 30) return;

    // Map (position across leaves, distance from leaves) to the screen.
    Offset pt(double pos, double d) => horizontal
        ? Offset(plot.right - d / maxDist * plot.width, plot.top + pos * plot.height)
        : Offset(plot.left + pos * plot.width, plot.top + (maxDist - d) / maxDist * plot.height);
    Offset at(TreeLayoutNode n) => pt(n.pos, dist(n));

    // ---- 3. hit-test: nearest node within 9 px
    TreeLayoutNode? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      var best = 9.0;
      for (final n in all) {
        final d = (at(n) - ptr).distance;
        if (d < best) {
          best = d;
          hover = n;
        }
      }
    }
    final inSub = <TreeLayoutNode>{if (hover != null) hover, if (hover != null) ...hover.descendants};
    Color colorOf(TreeLayoutNode n) =>
        n.node.color ?? ((w.colorBranches && n.branch >= 0) ? theme.colorAt(n.branch) : theme.axisColor);

    // ---- 4. distance axis (only meaningful when real heights are given)
    if (useHeights) {
      final scale = NiceScale.compute(0, maxDist, maxTicks: 5, includeZero: true);
      for (final t in scale.ticks) {
        if (t > maxDist + 1e-9) continue;
        final p = pt(0, t);
        if (horizontal) {
          canvas.drawLine(Offset(p.dx, plot.top), Offset(p.dx, plot.bottom), Paint()
            ..color = theme.gridColor
            ..strokeWidth = 1);
          paintText(canvas, fmt(t), Offset(p.dx, plot.bottom + 6), theme.labelStyle, align: Alignment.topCenter);
        } else {
          canvas.drawLine(Offset(plot.left, p.dy), Offset(plot.right, p.dy), Paint()
            ..color = theme.gridColor
            ..strokeWidth = 1);
          paintText(canvas, fmt(t), Offset(plot.left - 6, p.dy), theme.labelStyle, align: Alignment.centerRight);
        }
      }
    }

    // ---- 5. connectors: a "bar" across the children plus a stub to each child
    canvas.save();
    canvas.clipRect(horizontal
        ? Rect.fromLTRB(0, 0, plot.left + (size.width - plot.left) * progress, size.height)
        : Rect.fromLTRB(0, 0, size.width, plot.top + (size.height - plot.top) * progress));
    for (final n in all) {
      if (n.kids.isEmpty) continue;
      final p = at(n);
      final kidPts = [for (final k in n.kids) at(k)];
      final dim = hover != null && !inSub.contains(n);
      final paint = Paint()
        ..color = colorOf(n.kids.first).faded(dim ? .25 : 1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = inSub.contains(n) ? w.lineWidth + 1.4 : w.lineWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      if (horizontal) {
        path.moveTo(p.dx, kidPts.first.dy);
        path.lineTo(p.dx, kidPts.last.dy); // the bar
        for (final kp in kidPts) {
          path.moveTo(p.dx, kp.dy);
          path.lineTo(kp.dx, kp.dy); // stub to the child
        }
      } else {
        path.moveTo(kidPts.first.dx, p.dy);
        path.lineTo(kidPts.last.dx, p.dy);
        for (final kp in kidPts) {
          path.moveTo(kp.dx, p.dy);
          path.lineTo(kp.dx, kp.dy);
        }
      }
      canvas.drawPath(path, paint);
    }
    // ---- 6. node dots and labels
    for (final n in all) {
      final p = at(n);
      final dim = hover != null && !inSub.contains(n);
      if (w.showNodes) canvas.drawCircle(p, n.node.isLeaf ? 3.2 : 2.6, Paint()..color = colorOf(n).faded(dim ? .3 : 1));
      if ((n.node.isLeaf || w.showInternalLabels) && progress > .99) {
        final style = theme.labelStyle.copyWith(color: theme.textColor.faded(dim ? .35 : 1), fontWeight: identical(n, hover) ? FontWeight.bold : FontWeight.normal);
        if (horizontal) {
          paintText(canvas, n.node.label, p + const Offset(7, 0), style, align: Alignment.centerLeft, maxWidth: maxLabel + 4);
        } else {
          paintRotatedText(canvas, n.node.label, p + const Offset(0, 7), style, math.pi / 2, maxWidth: 90);
        }
      }
    }
    canvas.restore();

    // ---- 7. tooltip
    if (hover != null && ptr != null) {
      paintTooltip(canvas, size, ptr, theme, title: hover.node.label, rows: [
        TooltipRow(hover.path, color: colorOf(hover)),
        if (hover.node.subtitle != null) TooltipRow(hover.node.subtitle!),
        if (!hover.node.isLeaf) TooltipRow('${hover.node.leafCount} leaves, ${useHeights ? 'height ${fmt(hover.node.height)}' : 'depth ${hover.node.depth - 1}'}'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
