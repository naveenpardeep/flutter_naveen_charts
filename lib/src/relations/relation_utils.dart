// Shared building blocks for the "relations" charts: a tree data model, a
// reusable leaf-aligned tree layout and a few painting helpers.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_utils.dart';

/// A node of a tree used by [DendrogramChart], [RadialTreeChart], [OrgChart]
/// and [MindMapChart].
///
/// ```dart
/// const TreeNode('CEO', subtitle: 'Ada', children: [
///   TreeNode('CTO', subtitle: 'Linus'),
///   TreeNode('CFO', subtitle: 'Grace'),
/// ])
/// ```
class TreeNode {
  const TreeNode(
    this.label, {
    this.children = const [],
    this.subtitle,
    this.height = 0,
    this.color,
  });

  /// Main text of the node.
  final String label;

  /// Child nodes; an empty list makes this node a leaf.
  final List<TreeNode> children;

  /// Optional second line (role, description, ...). Used by the org chart,
  /// mind map and tooltips.
  final String? subtitle;

  /// Merge distance of an internal node. Only the dendrogram reads it: when
  /// any node has a height above zero the distance axis uses these values
  /// (leaves are always at 0); otherwise the subtree depth is used.
  final double height;

  /// Overrides the automatically assigned branch colour.
  final Color? color;

  /// True when the node has no children.
  bool get isLeaf => children.isEmpty;

  /// Number of leaves in this subtree (a leaf counts as 1).
  int get leafCount => isLeaf ? 1 : children.fold<int>(0, (a, c) => a + c.leafCount);

  /// Number of levels in this subtree (a leaf has depth 1).
  int get depth => isLeaf ? 1 : 1 + children.map((c) => c.depth).reduce(math.max);

  /// Total number of nodes in this subtree, including this one.
  int get size => 1 + children.fold<int>(0, (a, c) => a + c.size);
}

/// A [TreeNode] placed by [layoutTree].
class TreeLayoutNode {
  TreeLayoutNode(this.node, this.depth, this.parent, this.path, this.branch);

  /// The data node.
  final TreeNode node;

  /// Distance from the root (root = 0).
  final int depth;
  final TreeLayoutNode? parent;

  /// Labels from the root to this node joined with ` › `.
  final String path;

  /// Index of the root's child this node descends from (-1 for the root).
  /// Charts use it to colour whole branches the same.
  final int branch;
  final List<TreeLayoutNode> kids = [];

  /// Position across the "leaf axis", 0..1. Leaves are evenly spaced and
  /// internal nodes sit in the middle of their first and last child.
  double pos = 0;

  /// All nodes below this one (depth-first, not including this node).
  Iterable<TreeLayoutNode> get descendants sync* {
    for (final k in kids) {
      yield k;
      yield* k.descendants;
    }
  }
}

/// Lays a tree out along one axis: leaves are spaced evenly and every parent
/// is centred over its children (the classic "tidy" dendrogram layout).
TreeLayoutNode layoutTree(TreeNode root) {
  final leaves = root.leafCount;
  var nextLeaf = 0; // running index of the next leaf slot

  TreeLayoutNode build(TreeNode n, int depth, TreeLayoutNode? parent, String parentPath, int branch) {
    final path = parentPath.isEmpty ? n.label : '$parentPath › ${n.label}';
    final ln = TreeLayoutNode(n, depth, parent, path, branch);
    if (n.isLeaf) {
      // A leaf takes the next free slot, centred inside it.
      ln.pos = (nextLeaf++ + .5) / leaves;
    } else {
      for (var i = 0; i < n.children.length; i++) {
        // Children of the root start a new branch; deeper nodes inherit it.
        ln.kids.add(build(n.children[i], depth + 1, ln, path, depth == 0 ? i : branch));
      }
      // Centre the parent between its first and last child.
      ln.pos = (ln.kids.first.pos + ln.kids.last.pos) / 2;
    }
    return ln;
  }

  return build(root, 0, null, '', -1);
}

/// Paints [text] rotated by [angle] radians around [anchor]. [align] tells
/// which point of the (unrotated) text box sits on the anchor.
void paintRotatedText(Canvas canvas, String text, Offset anchor, TextStyle style, double angle,
    {Alignment align = Alignment.centerLeft, double maxWidth = double.infinity}) {
  canvas.save();
  canvas.translate(anchor.dx, anchor.dy); // move origin to the anchor ...
  canvas.rotate(angle); // ... then rotate around it
  paintText(canvas, text, Offset.zero, style, align: align, maxWidth: maxWidth);
  canvas.restore();
}

/// Ribbon between two arc segments of a circle of radius [r] around [c]:
/// follows the first segment (a0..a1), bends through the centre to the second
/// segment (b0..b1) and back. Used by the chord-style charts.
Path ribbonPath(Offset c, double r, double a0, double a1, double b0, double b1) {
  Offset pt(double a) => c + Offset.fromDirection(a, r);
  final rect = Rect.fromCircle(center: c, radius: r);
  final p = Path()..moveTo(pt(a0).dx, pt(a0).dy);
  p.arcTo(rect, a0, a1 - a0, false); // along the source arc
  p.quadraticBezierTo(c.dx, c.dy, pt(b0).dx, pt(b0).dy); // curve to the target
  p.arcTo(rect, b0, b1 - b0, false); // along the target arc
  p.quadraticBezierTo(c.dx, c.dy, pt(a0).dx, pt(a0).dy); // curve back
  p.close();
  return p;
}
