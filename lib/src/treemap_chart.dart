import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';
import 'core/hierarchy.dart';

/// Squarified treemap of a [HierarchyNode] forest (any depth).
class TreemapChart extends StatelessWidget {
  const TreemapChart({
    super.key,
    required this.nodes,
    this.padding = 3,
    this.showValues = true,
    this.cornerRadius = 4,
    this.valueFormat,
    this.aspectRatio = 1.5,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 700),
  });
  final List<HierarchyNode> nodes;
  final double padding;
  final bool showValues;
  final double cornerRadius;
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
        builder: (p, ptr) => _TreemapPainter(this, t, p, ptr),
      ),
    );
  }
}

/// Squarified layout: [values] must be sorted descending and positive.
List<Rect> squarify(List<double> values, Rect r) {
  final total = values.fold<double>(0, (a, b) => a + b);
  final out = List<Rect>.filled(values.length, Rect.zero);
  if (total <= 0 || r.width <= 0 || r.height <= 0) return out;
  final scale = r.width * r.height / total;
  final areas = [for (final v in values) v * scale];
  var rect = r;
  var i = 0;
  double worst(List<double> row, double w) {
    final s = row.fold<double>(0, (a, b) => a + b);
    final rmax = row.reduce(math.max), rmin = row.reduce(math.min);
    return math.max(w * w * rmax / (s * s), s * s / (w * w * rmin));
  }

  while (i < areas.length) {
    final w = math.min(rect.width, rect.height);
    var row = <double>[areas[i]];
    var j = i + 1;
    while (j < areas.length) {
      final cand = [...row, areas[j]];
      if (worst(cand, w) <= worst(row, w)) {
        row = cand;
        j++;
      } else {
        break;
      }
    }
    final s = row.fold<double>(0, (a, b) => a + b);
    if (rect.width >= rect.height) {
      final colW = s / rect.height;
      var y = rect.top;
      for (var k = 0; k < row.length; k++) {
        final h = row[k] / colW;
        out[i + k] = Rect.fromLTWH(rect.left, y, colW, h);
        y += h;
      }
      rect = Rect.fromLTRB(rect.left + colW, rect.top, rect.right, rect.bottom);
    } else {
      final rowH = s / rect.width;
      var x = rect.left;
      for (var k = 0; k < row.length; k++) {
        final wk = row[k] / rowH;
        out[i + k] = Rect.fromLTWH(x, rect.top, wk, rowH);
        x += wk;
      }
      rect = Rect.fromLTRB(rect.left, rect.top + rowH, rect.right, rect.bottom);
    }
    i += row.length;
  }
  return out;
}

class _Tile {
  _Tile(this.rect, this.node, this.color, this.path, this.leaf, this.depth);
  final Rect rect;
  final HierarchyNode node;
  final Color color;
  final String path;
  final bool leaf;
  final int depth;
}

class _TreemapPainter extends CustomPainter {
  _TreemapPainter(this.w, this.theme, this.progress, this.pointer);
  final TreemapChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  void _layout(List<HierarchyNode> nodes, Rect rect, int depth, String parent,
      Color? inherited, List<_Tile> out) {
    final list = nodes.where((n) => n.total > 0).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    if (list.isEmpty) return;
    final rects = squarify([for (final n in list) n.total], rect);
    for (var i = 0; i < list.length; i++) {
      final n = list[i];
      final r = rects[i];
      final path = parent.isEmpty ? n.label : '$parent › ${n.label}';
      final color = n.color ?? inherited ?? theme.colorAt(i);
      if (n.children.isEmpty) {
        out.add(_Tile(r, n, color, path, true, depth));
      } else {
        out.add(_Tile(r, n, color, path, false, depth));
        final header = (r.height > 44 && r.width > 56) ? 16.0 : 0.0;
        final inner = Rect.fromLTRB(r.left + w.padding, r.top + w.padding + header,
            r.right - w.padding, r.bottom - w.padding);
        if (inner.width > 4 && inner.height > 4) {
          _layout(n.children, inner, depth + 1, path, color, out);
        }
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final tiles = <_Tile>[];
    _layout(w.nodes, Offset.zero & size, 0, '', null, tiles);
    if (tiles.isEmpty) return;
    final grand = w.nodes.fold<double>(0, (a, n) => a + n.total);
    final fmt = w.valueFormat ?? formatNumber;

    _Tile? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      for (final t in tiles) {
        if (t.rect.contains(ptr)) hover = t;
      }
    }

    for (final t in tiles) {
      final r = t.rect.deflate(1);
      final rr = RRect.fromRectAndRadius(r, Radius.circular(w.cornerRadius));
      if (t.leaf) {
        final fill = Color.lerp(t.color, Colors.white, 0.12 * math.min(t.depth, 3))!;
        canvas.drawRRect(rr, Paint()..color = fill.faded(progress));
        if (progress > .99 && r.width > 40 && r.height > 22) {
          final tc = contrastOn(fill);
          paintText(canvas, t.node.label, r.topLeft + const Offset(6, 5),
              TextStyle(color: tc, fontSize: 11, fontWeight: FontWeight.bold),
              align: Alignment.topLeft, maxWidth: r.width - 10);
          if (w.showValues && r.height > 38) {
            paintText(canvas, fmt(t.node.total), r.topLeft + const Offset(6, 20),
                TextStyle(color: tc.withAlpha(200), fontSize: 10),
                align: Alignment.topLeft, maxWidth: r.width - 10);
          }
        }
      } else {
        canvas.drawRRect(rr, Paint()..color = t.color.faded(.16 * progress));
        canvas.drawRRect(rr, Paint()
          ..color = t.color.faded(.8 * progress)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
        if (progress > .99 && r.height > 44 && r.width > 56) {
          paintText(canvas, t.node.label, r.topLeft + const Offset(6, 3),
              TextStyle(color: theme.textColor, fontSize: 11, fontWeight: FontWeight.bold),
              align: Alignment.topLeft, maxWidth: r.width - 10);
        }
      }
    }
    if (hover != null && ptr != null) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(hover.rect.deflate(1), Radius.circular(w.cornerRadius)),
          Paint()
            ..color = theme.textColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      paintTooltip(canvas, size, ptr, theme, title: hover.path, rows: [
        TooltipRow('${fmt(hover.node.total)} (${(hover.node.total / grand * 100).toStringAsFixed(1)}%)',
            color: hover.color),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
