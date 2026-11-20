// Radial tree: the tree wrapped around a centre, depth = distance from centre.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_canvas.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import 'relation_utils.dart';

/// Radial tree of a [TreeNode] tree: the root is in the centre, every level is
/// a ring further out and the leaves are spread evenly around the circle.
/// Links are drawn as an arc along the parent's ring followed by a straight
/// radial segment to the child. Each top-level branch gets its own colour.
///
/// Compact for wide trees (file systems, taxonomies, org structures). Hover a
/// node to highlight its subtree.
class RadialTreeChart extends StatelessWidget {
  const RadialTreeChart({
    super.key,
    required this.root,
    this.colorBranches = true,
    this.showNodes = true,
    this.showInternalLabels = false,
    this.lineWidth = 1.6,
    this.startAngle = -math.pi / 2,
    this.aspectRatio = 1.2,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  /// Centre of the tree.
  final TreeNode root;
  final bool colorBranches;
  final bool showNodes;

  /// Also label inner nodes (leaves are always labelled).
  final bool showInternalLabels;
  final double lineWidth;

  /// Angle (radians, 0 = 3 o'clock) of the first leaf.
  final double startAngle;
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
        builder: (p, ptr) => _RadialTreePainter(this, t, p, ptr),
      ),
    );
  }
}

class _RadialTreePainter extends CustomPainter {
  _RadialTreePainter(this.w, this.theme, this.progress, this.pointer);
  final RadialTreeChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    // ---- 1. layout: pos (0..1 across leaves) becomes the angle,
    //         depth becomes the radius
    final root = layoutTree(w.root);
    final all = [root, ...root.descendants];
    final levels = math.max(1, w.root.depth - 1);
    final labels = [for (final n in all) if (n.node.isLeaf || w.showInternalLabels) n.node.label];
    final maxLabel = labels.map((s) => measureText(s, theme.labelStyle).width).fold<double>(0, math.max);
    final c = size.center(Offset.zero);
    // The labels sit outside the outermost ring, so they reduce its radius.
    final R = math.min(size.width / 2, size.height / 2) - math.min(maxLabel, size.shortestSide * .22) - 16;
    if (R < 30) return;
    double angleOf(TreeLayoutNode n) => w.startAngle + n.pos * 2 * math.pi;
    double radiusOf(TreeLayoutNode n) => levels == 0 ? 0 : n.depth / levels * R * progress;
    Offset at(TreeLayoutNode n) => c + Offset.fromDirection(angleOf(n), radiusOf(n));
    Color colorOf(TreeLayoutNode n) => n.node.color ?? ((w.colorBranches && n.branch >= 0) ? theme.colorAt(n.branch) : theme.axisColor);

    // ---- 2. guide rings
    for (var d = 1; d <= levels; d++) {
      canvas.drawCircle(c, d / levels * R * progress, Paint()
        ..color = theme.gridColor.faded(.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
    }

    // ---- 3. hit-test
    TreeLayoutNode? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      var best = 10.0;
      for (final n in all) {
        final d = (at(n) - ptr).distance;
        if (d < best) {
          best = d;
          hover = n;
        }
      }
    }
    final inSub = <TreeLayoutNode>{if (hover != null) hover, if (hover != null) ...hover.descendants};

    // ---- 4. links: arc along the parent's ring, then radial line to the child
    for (final n in all) {
      final parent = n.parent;
      if (parent == null) continue;
      final dim = hover != null && !inSub.contains(n);
      final rp = radiusOf(parent);
      final ap = angleOf(parent), an = angleOf(n);
      final path = Path()..moveTo(c.dx + math.cos(ap) * rp, c.dy + math.sin(ap) * rp);
      if (rp > 0) path.arcTo(Rect.fromCircle(center: c, radius: rp), ap, an - ap, false);
      final end = at(n);
      path.lineTo(end.dx, end.dy);
      canvas.drawPath(
          path,
          Paint()
            ..color = colorOf(n).faded(dim ? .2 : .85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = inSub.contains(n) ? w.lineWidth + 1.4 : w.lineWidth
            ..strokeCap = StrokeCap.round);
    }

    // ---- 5. nodes and labels (rotated to follow the radius, flipped on the
    //         left half so the text never reads upside down)
    for (final n in all) {
      final p = at(n);
      final dim = hover != null && !inSub.contains(n);
      if (w.showNodes) canvas.drawCircle(p, n.depth == 0 ? 6 : 3.2, Paint()..color = colorOf(n).faded(dim ? .3 : 1));
      if (progress > .99 && (n.node.isLeaf || w.showInternalLabels || n.depth == 0)) {
        final a = angleOf(n);
        final onLeft = math.cos(a) < -1e-6;
        final style = theme.labelStyle.copyWith(
            color: theme.textColor.faded(dim ? .35 : 1), fontWeight: (n.depth == 0 || identical(n, hover)) ? FontWeight.bold : FontWeight.normal);
        if (n.depth == 0) {
          paintText(canvas, n.node.label, p + const Offset(0, -10), style, align: Alignment.bottomCenter);
        } else {
          final labelPos = p + Offset.fromDirection(a, 8);
          paintRotatedText(canvas, n.node.label, labelPos, style, onLeft ? a + math.pi : a,
              align: onLeft ? Alignment.centerRight : Alignment.centerLeft, maxWidth: maxLabel + 4);
        }
      }
    }

    // ---- 6. tooltip
    if (hover != null && ptr != null) {
      paintTooltip(canvas, size, ptr, theme, title: hover.node.label, rows: [
        TooltipRow(hover.path, color: colorOf(hover)),
        if (hover.node.subtitle != null) TooltipRow(hover.node.subtitle!),
        if (!hover.node.isLeaf) TooltipRow('${hover.node.leafCount} leaves below'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
