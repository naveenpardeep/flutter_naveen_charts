// Organisation chart: boxes with title and subtitle in a top-down tree.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_canvas.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import 'relation_utils.dart';

/// Org chart of a [TreeNode] tree: each node is a card (label = name or role,
/// subtitle = description) with elbow connectors to its children. Parents are
/// centred above their subtree, and the whole chart is scaled down to fit.
///
/// Tap a card that has children to collapse or expand it (a badge shows how
/// many nodes are hidden). Set [initialCollapseDepth] to start with only the
/// top levels open.
class OrgChart extends StatefulWidget {
  const OrgChart({
    super.key,
    required this.root,
    this.nodeWidth = 132,
    this.nodeHeight = 50,
    this.hGap = 16,
    this.vGap = 30,
    this.collapsible = true,
    this.initialCollapseDepth,
    this.cornerRadius = 8,
    this.aspectRatio = 1.5,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 800),
  });

  /// Top of the hierarchy.
  final TreeNode root;

  /// Size of a card in logical pixels (before the fit-to-view scaling).
  final double nodeWidth, nodeHeight;

  /// Horizontal gap between sibling subtrees and vertical gap between levels.
  final double hGap, vGap;

  /// Let the user tap cards to collapse / expand their subtree.
  final bool collapsible;

  /// Collapse every node at this depth or deeper at start (root = depth 0).
  final int? initialCollapseDepth;
  final double cornerRadius;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  State<OrgChart> createState() => _OrgChartState();
}

/// A card after layout (coordinates are unscaled).
class _OrgBox {
  _OrgBox(this.node, this.depth, this.branch);
  final TreeNode node;
  final int depth, branch;
  final List<_OrgBox> kids = [];
  Rect rect = Rect.zero;
  bool collapsed = false;
}

class _OrgChartState extends State<OrgChart> {
  /// Nodes whose children are hidden (compared by identity).
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

  bool _isClosed(TreeNode n) => n.isLeaf || _collapsed.contains(n);

  /// Width of the subtree below [n]: a closed node is one card wide, an open
  /// one is as wide as its children side by side (but never narrower than a card).
  double _width(TreeNode n, Map<TreeNode, double> memo) {
    final cached = memo[n];
    if (cached != null) return cached;
    double result;
    if (_isClosed(n)) {
      result = widget.nodeWidth;
    } else {
      final kids = n.children.fold<double>(0, (a, c) => a + _width(c, memo)) + widget.hGap * (n.children.length - 1);
      result = math.max(widget.nodeWidth, kids);
    }
    memo[n] = result; // store after the recursion, never while computing
    return result;
  }

  /// Places [n] and its open descendants. [x0] is the left edge of the slot
  /// reserved for this subtree.
  _OrgBox _place(TreeNode n, double x0, int depth, int branch, Map<TreeNode, double> memo, List<_OrgBox> out) {
    final slot = memo[n]!;
    final box = _OrgBox(n, depth, branch);
    out.add(box);
    final y = depth * (widget.nodeHeight + widget.vGap);
    if (_isClosed(n)) {
      box.collapsed = !n.isLeaf;
      box.rect = Rect.fromLTWH(x0 + (slot - widget.nodeWidth) / 2, y, widget.nodeWidth, widget.nodeHeight);
    } else {
      final childrenWidth = n.children.fold<double>(0, (a, c) => a + memo[c]!) + widget.hGap * (n.children.length - 1);
      var x = x0 + (slot - childrenWidth) / 2; // centre the children block in the slot
      for (var i = 0; i < n.children.length; i++) {
        box.kids.add(_place(n.children[i], x, depth + 1, depth == 0 ? i + 1 : branch, memo, out));
        x += memo[n.children[i]]! + widget.hGap;
      }
      // The parent sits above the middle of its first and last child.
      final cx = (box.kids.first.rect.center.dx + box.kids.last.rect.center.dx) / 2;
      box.rect = Rect.fromLTWH(cx - widget.nodeWidth / 2, y, widget.nodeWidth, widget.nodeHeight);
    }
    return box;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? ChartTheme.of(context);
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        // Layout is recomputed on every build so collapsing is instant.
        final memo = Map<TreeNode, double>.identity();
        _width(widget.root, memo);
        final boxes = <_OrgBox>[];
        _place(widget.root, 0, 0, 0, memo, boxes);
        final totalW = memo[widget.root]!;
        final levels = boxes.map((b) => b.depth).reduce(math.max) + 1;
        final totalH = levels * widget.nodeHeight + (levels - 1) * widget.vGap;
        // Shrink (never enlarge) so the whole chart fits.
        final s = math.min(1.0, math.min((size.width - 16) / totalW, (size.height - 16) / totalH));
        final origin = Offset((size.width - totalW * s) / 2, 8);
        return GestureDetector(
          onTapUp: widget.collapsible
              ? (d) {
                  final p = (d.localPosition - origin) / s; // back to unscaled coordinates
                  for (final b in boxes.reversed) {
                    if (b.rect.contains(p) && !b.node.isLeaf) {
                      setState(() {
                        if (!_collapsed.remove(b.node)) _collapsed.add(b.node);
                      });
                      break;
                    }
                  }
                }
              : null,
          child: ChartCanvas(
            duration: widget.animationDuration,
            builder: (p, ptr) => _OrgPainter(widget, boxes, levels, s, origin, t, p, ptr),
          ),
        );
      }),
    );
  }
}

class _OrgPainter extends CustomPainter {
  _OrgPainter(this.w, this.boxes, this.levels, this.scale, this.origin, this.theme, this.progress, this.pointer);
  final OrgChart w;
  final List<_OrgBox> boxes;
  final int levels;
  final double scale;
  final Offset origin;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    // Hit-test in unscaled chart coordinates.
    _OrgBox? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      final p = (ptr - origin) / scale;
      for (final b in boxes) {
        if (b.rect.contains(p)) hover = b;
      }
    }
    // A level fades in after the one above it.
    double reveal(_OrgBox b) => (progress * levels - b.depth).clamp(0.0, 1.0).toDouble();

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);

    // ---- connectors: down from the parent, across, down into each child
    final line = Paint()
      ..color = theme.axisColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final links = Path();
    for (final b in boxes) {
      if (b.kids.isEmpty) continue;
      final from = Offset(b.rect.center.dx, b.rect.bottom);
      final midY = from.dy + w.vGap / 2;
      links.moveTo(from.dx, from.dy);
      links.lineTo(from.dx, midY);
      for (final k in b.kids) {
        links.moveTo(from.dx, midY);
        links.lineTo(k.rect.center.dx, midY);
        links.lineTo(k.rect.center.dx, k.rect.top);
      }
    }
    canvas.drawPath(links, line);

    // ---- cards
    for (final b in boxes) {
      final a = reveal(b);
      if (a <= 0) continue;
      final accent = b.node.color ?? theme.colorAt(b.branch);
      final r = b.rect;
      final rr = RRect.fromRectAndRadius(r, Radius.circular(w.cornerRadius));
      canvas.drawRRect(rr, Paint()..color = theme.surface.faded(a));
      canvas.drawRRect(rr, Paint()
        ..color = accent.faded(a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = identical(b, hover) ? 3 : 1.6);
      // Coloured strip along the top edge.
      canvas.save();
      canvas.clipRRect(rr);
      canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 5), Paint()..color = accent.faded(a));
      canvas.restore();
      final hasSub = b.node.subtitle != null;
      paintText(canvas, b.node.label, Offset(r.center.dx, r.center.dy + (hasSub ? -7 : 2)),
          TextStyle(color: theme.textColor.faded(a), fontSize: 12, fontWeight: FontWeight.w700), maxWidth: r.width - 12);
      if (hasSub) {
        paintText(canvas, b.node.subtitle!, Offset(r.center.dx, r.center.dy + 9),
            theme.labelStyle.copyWith(color: theme.labelStyle.color!.faded(a), fontSize: 10.5), maxWidth: r.width - 12);
      }
      // Collapse badge: "-" when open, "+N" when N nodes are hidden.
      if (w.collapsible && !b.node.isLeaf) {
        final c = Offset(r.center.dx, r.bottom);
        canvas.drawCircle(c, 9, Paint()..color = theme.surface.faded(a));
        canvas.drawCircle(c, 9, Paint()
          ..color = accent.faded(a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
        paintText(canvas, b.collapsed ? '+${b.node.size - 1}' : '−', c,
            TextStyle(color: theme.textColor.faded(a), fontSize: b.collapsed ? 8.5 : 12, fontWeight: FontWeight.bold));
      }
    }
    canvas.restore();

    // ---- tooltip (screen coordinates)
    if (hover != null && ptr != null) {
      final n = hover.node;
      paintTooltip(canvas, size, ptr, theme, title: n.label, rows: [
        if (n.subtitle != null) TooltipRow(n.subtitle!, color: n.color ?? theme.colorAt(hover.branch)),
        TooltipRow('Direct reports: ${n.children.length}'),
        if (!n.isLeaf) TooltipRow('Whole team: ${n.size - 1}'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
