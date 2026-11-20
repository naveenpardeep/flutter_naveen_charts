import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_canvas.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/hierarchy.dart';

/// Icicle (partition) chart: each level of the hierarchy is a row (or column)
/// of rectangles whose length is proportional to the value.
class IcicleChart extends StatelessWidget {
  const IcicleChart({
    super.key,
    required this.nodes,
    this.horizontal = false,
    this.gap = 1.5,
    this.cornerRadius = 3,
    this.showLabels = true,
    this.valueFormat,
    this.aspectRatio = 1.7,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 800),
  });
  final List<HierarchyNode> nodes;

  /// Levels run left to right instead of top to bottom.
  final bool horizontal;
  final double gap;
  final double cornerRadius;
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
        builder: (p, ptr) => _IciclePainter(this, t, p, ptr),
      ),
    );
  }
}

class _Cell {
  _Cell(this.node, this.rect, this.color, this.path, this.depth);
  final HierarchyNode node;
  final Rect rect;
  final Color color;
  final String path;
  final int depth;
}

class _IciclePainter extends CustomPainter {
  _IciclePainter(this.w, this.theme, this.progress, this.pointer);
  final IcicleChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final total = w.nodes.fold<double>(0, (a, n) => a + n.total);
    if (total <= 0) return;
    final levels = w.nodes.map((n) => n.depth).reduce(math.max);
    final box = Offset.zero & size;
    final bw = box.width / levels, bh = box.height / levels;
    Rect rectFor(double a0, double a1, int depth) => w.horizontal
        ? Rect.fromLTRB(depth * bw, a0 * box.height, (depth + 1) * bw, a1 * box.height)
        : Rect.fromLTRB(a0 * box.width, depth * bh, a1 * box.width, (depth + 1) * bh);
    final cells = <_Cell>[];
    void walk(List<HierarchyNode> ns, double a0, double span, int depth, Color? inherited, String parent, double parentTotal) {
      var a = a0;
      for (var i = 0; i < ns.length; i++) {
        final n = ns[i];
        if (n.total <= 0) continue;
        final len = n.total / parentTotal * span;
        final color = n.color ?? inherited ?? theme.colorAt(i);
        final path = parent.isEmpty ? n.label : '$parent › ${n.label}';
        cells.add(_Cell(n, rectFor(a, a + len, depth), color, path, depth));
        if (n.children.isNotEmpty) walk(n.children, a, len, depth + 1, color, path, n.total);
        a += len;
      }
    }

    walk(w.nodes, 0, 1, 0, null, '', total);
    final fmt = w.valueFormat ?? formatNumber;
    _Cell? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      for (final c in cells) {
        if (c.rect.contains(ptr)) hover = c;
      }
    }
    for (final c in cells) {
      final rr = RRect.fromRectAndRadius(c.rect.deflate(w.gap / 2), Radius.circular(w.cornerRadius));
      final fill = Color.lerp(c.color, Colors.white, .1 * c.depth)!;
      final reveal = (progress * levels - c.depth).clamp(0.0, 1.0).toDouble();
      canvas.drawRRect(rr, Paint()..color = (identical(c, hover) ? Color.lerp(fill, Colors.white, .2)! : fill).faded(reveal));
      if (w.showLabels && progress > .99) {
        final fits = w.horizontal ? c.rect.height > 16 && c.rect.width > 34 : c.rect.width > 34 && c.rect.height > 16;
        if (fits) {
          paintText(canvas, c.node.label, c.rect.topLeft + const Offset(6, 4), TextStyle(color: contrastOn(fill), fontSize: 11, fontWeight: FontWeight.w600),
              align: Alignment.topLeft, maxWidth: c.rect.width - 10);
        }
      }
    }
    if (hover != null && ptr != null) {
      paintTooltip(canvas, size, ptr, theme, title: hover.path, rows: [
        TooltipRow('${fmt(hover.node.total)} (${(hover.node.total / total * 100).toStringAsFixed(1)}%)', color: hover.color),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
