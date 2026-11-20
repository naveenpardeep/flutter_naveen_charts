// Mind map: a central idea with branches growing to the left and right.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_canvas.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import 'relation_utils.dart';

/// Mind map of a [TreeNode] tree. The root sits in the middle; its children
/// are split between the right and the left side (balanced by size) and every
/// branch fans out as smooth curves in its own colour. Branches get thinner
/// the deeper they go.
///
/// Tap a node with children to fold or unfold its branch; the map re-centres
/// and rescales to stay inside the view.
class MindMapChart extends StatefulWidget {
  const MindMapChart({
    super.key,
    required this.root,
    this.levelGap = 38,
    this.rowHeight = 34,
    this.collapsible = true,
    this.initialCollapseDepth,
    this.aspectRatio = 1.5,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  /// The central idea.
  final TreeNode root;

  /// Horizontal space between a node and the next level.
  final double levelGap;

  /// Vertical slot of one leaf.
  final double rowHeight;
  final bool collapsible;

  /// Fold nodes at this depth or deeper at start (root = 0).
  final int? initialCollapseDepth;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  State<MindMapChart> createState() => _MindMapChartState();
}

/// A node after layout; x / y are the centre in unscaled coordinates.
class _MM {
  _MM(this.node, this.side, this.depth, this.color, this.parent);
  final TreeNode node;
  final int side; // +1 right, -1 left, 0 root
  final int depth;
  final Color color;
  final _MM? parent;
  final List<_MM> kids = [];
  double w = 0, h = 28, x = 0, y = 0;
  bool collapsed = false;
  Rect get rect => Rect.fromCenter(center: Offset(x, y), width: w, height: h);
}

class _MindMapChartState extends State<MindMapChart> {
  final Set<TreeNode> _collapsed = Set<TreeNode>.identity();

  @override
  void initState() {
    super.initState();
    final d = widget.initialCollapseDepth;
    if (d != null) {
      void walk(TreeNode n, int depth) {
        if (!n.isLeaf && depth >= d) _collapsed.add(n);
        for (final c in n.children) {
          walk(c, depth + 1);
        }
      }

      walk(widget.root, 0);
    }
  }

  /// Builds the sub-layout of [n]. Leaves take the next row from [cursor];
  /// parents are centred on their children. x comes from the parent's edge.
  _MM _make(TreeNode n, int side, int depth, Color color, _MM parent, List<double> cursor, TextStyle style) {
    final m = _MM(n, side, depth, n.color ?? color, parent);
    m.w = measureText(n.label, style).width + 26;
    m.x = parent.x + side * (parent.w / 2 + widget.levelGap + m.w / 2);
    final open = !n.isLeaf && !_collapsed.contains(n);
    m.collapsed = !n.isLeaf && !open;
    if (!open) {
      m.y = cursor[0] + widget.rowHeight / 2;
      cursor[0] += widget.rowHeight;
    } else {
      for (final c in n.children) {
        m.kids.add(_make(c, side, depth + 1, m.color, m, cursor, style));
      }
      m.y = (m.kids.first.y + m.kids.last.y) / 2;
    }
    return m;
  }

  void _shift(_MM m, double dy) {
    m.y += dy;
    for (final k in m.kids) {
      _shift(k, dy);
    }
  }

  Iterable<_MM> _flatten(_MM m) sync* {
    yield m;
    for (final k in m.kids) {
      yield* _flatten(k);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? ChartTheme.of(context);
    final style = t.labelStyle.copyWith(fontSize: 12);
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);

        // ---- 1. root in the middle
        final root = _MM(widget.root, 0, 0, t.colorAt(0), null);
        root.w = measureText(widget.root.label, style.copyWith(fontSize: 14, fontWeight: FontWeight.bold)).width + 36;
        root.h = 40;

        // ---- 2. share the root's children between the two sides, always
        //         giving the next child to the side with fewer leaves
        final sideLists = <int, List<MapEntry<int, TreeNode>>>{1: [], -1: []};
        final sideLeaves = <int, int>{1: 0, -1: 0};
        final kids = widget.root.children;
        final closedRoot = _collapsed.contains(widget.root) || kids.isEmpty;
        if (!closedRoot) {
          for (var i = 0; i < kids.length; i++) {
            final side = sideLeaves[1]! <= sideLeaves[-1]! ? 1 : -1;
            sideLists[side]!.add(MapEntry(i, kids[i]));
            sideLeaves[side] = sideLeaves[side]! + kids[i].leafCount;
          }
        }

        // ---- 3. lay out each side and centre it vertically on the root
        for (final side in [1, -1]) {
          final cursor = [0.0];
          final tops = <_MM>[];
          for (final e in sideLists[side]!) {
            tops.add(_make(e.value, side, 1, t.colorAt(e.key + 1), root, cursor, style));
          }
          if (tops.isEmpty) continue;
          final mid = (tops.first.y + tops.last.y) / 2;
          for (final m in tops) {
            _shift(m, -mid);
          }
          root.kids.addAll(tops);
        }
        final all = _flatten(root).toList();

        // ---- 4. fit the bounding box into the view
        var minX = double.infinity, maxX = -double.infinity, minY = double.infinity, maxY = -double.infinity;
        for (final m in all) {
          minX = math.min(minX, m.x - m.w / 2);
          maxX = math.max(maxX, m.x + m.w / 2);
          minY = math.min(minY, m.y - m.h / 2);
          maxY = math.max(maxY, m.y + m.h / 2);
        }
        final s = math.min(1.0, math.min((size.width - 24) / (maxX - minX), (size.height - 24) / (maxY - minY)));
        final origin = Offset(size.width / 2 - (minX + maxX) / 2 * s, size.height / 2 - (minY + maxY) / 2 * s);

        return GestureDetector(
          onTapUp: widget.collapsible
              ? (d) {
                  final p = (d.localPosition - origin) / s;
                  for (final m in all.reversed) {
                    if (m.depth > 0 && !m.node.isLeaf && m.rect.contains(p)) {
                      setState(() {
                        if (!_collapsed.remove(m.node)) _collapsed.add(m.node);
                      });
                      break;
                    }
                  }
                }
              : null,
          child: ChartCanvas(
            duration: widget.animationDuration,
            builder: (p, ptr) => _MindMapPainter(widget, all, s, origin, t, p, ptr),
          ),
        );
      }),
    );
  }
}

class _MindMapPainter extends CustomPainter {
  _MindMapPainter(this.w, this.nodes, this.scale, this.origin, this.theme, this.progress, this.pointer);
  final MindMapChart w;
  final List<_MM> nodes;
  final double scale;
  final Offset origin;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final maxDepth = nodes.map((n) => n.depth).fold<int>(0, math.max);
    _MM? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      final p = (ptr - origin) / scale;
      for (final n in nodes) {
        if (n.rect.contains(p)) hover = n;
      }
    }
    double reveal(_MM n) => (progress * (maxDepth + 1) - n.depth).clamp(0.0, 1.0).toDouble();

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);

    // ---- branches: smooth S-curves from the parent's edge to the child's edge
    for (final n in nodes) {
      final parent = n.parent;
      if (parent == null) continue;
      final from = Offset(parent.x + n.side * parent.w / 2, parent.y);
      final to = Offset(n.x - n.side * n.w / 2, n.y);
      final mx = (from.dx + to.dx) / 2;
      canvas.drawPath(
          Path()
            ..moveTo(from.dx, from.dy)
            ..cubicTo(mx, from.dy, mx, to.dy, to.dx, to.dy),
          Paint()
            ..color = n.color.faded(.8 * reveal(n))
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.4, 4.2 - n.depth * .9)
            ..strokeCap = StrokeCap.round);
    }

    // ---- nodes
    for (final n in nodes) {
      final a = reveal(n);
      if (a <= 0) continue;
      final rr = RRect.fromRectAndRadius(n.rect, Radius.circular(n.h / 2));
      if (n.depth == 0) {
        canvas.drawRRect(rr, Paint()..color = n.color.faded(a));
        paintText(canvas, n.node.label, n.rect.center, TextStyle(color: contrastOn(n.color).faded(a), fontSize: 14, fontWeight: FontWeight.bold));
      } else {
        canvas.drawRRect(rr, Paint()..color = n.color.faded(.14 * a));
        canvas.drawRRect(rr, Paint()
          ..color = n.color.faded(a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = identical(n, hover) ? 3 : 1.6);
        paintText(canvas, n.node.label, n.rect.center, TextStyle(color: theme.textColor.faded(a), fontSize: 12, fontWeight: FontWeight.w600));
      }
      // A "+N" bubble marks a folded branch.
      if (n.collapsed && w.collapsible) {
        final c = Offset(n.x + n.side * (n.w / 2 + 12), n.y);
        canvas.drawCircle(c, 10, Paint()..color = theme.surface.faded(a));
        canvas.drawCircle(c, 10, Paint()
          ..color = n.color.faded(a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
        paintText(canvas, '+${n.node.size - 1}', c, TextStyle(color: theme.textColor.faded(a), fontSize: 9, fontWeight: FontWeight.bold));
      }
    }
    canvas.restore();

    // ---- tooltip
    if (hover != null && ptr != null) {
      final n = hover.node;
      paintTooltip(canvas, size, ptr, theme, title: n.label, rows: [
        if (n.subtitle != null) TooltipRow(n.subtitle!, color: hover.color),
        if (!n.isLeaf) TooltipRow('${n.size - 1} ideas below'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
