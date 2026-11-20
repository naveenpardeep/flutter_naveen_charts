import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_canvas.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/hierarchy.dart';

class _PC {
  _PC(this.node, this.r, this.color, this.depth, this.path);
  final HierarchyNode node;
  double r;
  double x = 0, y = 0;
  final Color color;
  final int depth;
  final String path;
  List<_PC> kids = [];
}

class _Drawn {
  _Drawn(this.pc, this.c, this.r);
  final _PC pc;
  final Offset c;
  final double r;
}

String _sig(List<HierarchyNode> ns) =>
    ns.map((n) => '${n.label}:${n.total}[${_sig(n.children)}]').join(',');

/// Circle packing of a [HierarchyNode] forest: circle area ~ value, children
/// nested inside their parent.
class CirclePackingChart extends StatefulWidget {
  const CirclePackingChart({
    super.key,
    required this.nodes,
    this.padding = 0.08,
    this.showLabels = true,
    this.valueFormat,
    this.aspectRatio = 1.2,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<HierarchyNode> nodes;

  /// Gap between circles as a share of the smaller radius.
  final double padding;
  final bool showLabels;
  final String Function(double)? valueFormat;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  State<CirclePackingChart> createState() => _CirclePackingChartState();
}

class _CirclePackingChartState extends State<CirclePackingChart> {
  String _key = '';
  _PC? _root;

  _PC _pack(HierarchyNode n, int depth, Color? inherited, int idx, String parent, ChartTheme theme) {
    final color = n.color ?? inherited ?? theme.colorAt(idx);
    final path = parent.isEmpty ? n.label : '$parent › ${n.label}';
    final kids = <_PC>[
      for (var i = 0; i < n.children.length; i++)
        if (n.children[i].total > 0) _pack(n.children[i], depth + 1, color, depth == 0 && inherited == null ? i : idx, path, theme)
    ];
    if (kids.isEmpty) return _PC(n, math.sqrt(math.max(n.total, 1e-9)), color, depth, path);
    _place(kids);
    return kids.length == 1 ? (_PC(n, kids[0].r * (1 + widget.padding), color, depth, path)..kids = kids) : _enclose(n, kids, color, depth, path);
  }

  void _place(List<_PC> kids) {
    kids.sort((a, b) => b.r.compareTo(a.r));
    final r0 = kids[0].r;
    for (var i = 1; i < kids.length; i++) {
      final c = kids[i];
      for (var s = 0; s < 8000; s++) {
        final ang = s * .4, rad = .02 * r0 * s;
        final x = rad * math.cos(ang), y = rad * math.sin(ang);
        var ok = true;
        for (var j = 0; j < i; j++) {
          final dx = x - kids[j].x, dy = y - kids[j].y;
          final need = kids[j].r + c.r + math.min(kids[j].r, c.r) * widget.padding;
          if (dx * dx + dy * dy < need * need) {
            ok = false;
            break;
          }
        }
        if (ok) {
          c.x = x;
          c.y = y;
          break;
        }
      }
    }
  }

  _PC _enclose(HierarchyNode n, List<_PC> kids, Color color, int depth, String path) {
    var sw = 0.0, cx = 0.0, cy = 0.0;
    for (final k in kids) {
      sw += k.r * k.r;
      cx += k.x * k.r * k.r;
      cy += k.y * k.r * k.r;
    }
    cx /= sw;
    cy /= sw;
    var big = 0.0;
    for (final k in kids) {
      k.x -= cx;
      k.y -= cy;
      big = math.max(big, math.sqrt(k.x * k.x + k.y * k.y) + k.r);
    }
    return _PC(n, big * (1 + widget.padding * .5), color, depth, path)..kids = kids;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? ChartTheme.of(context);
    final key = _sig(widget.nodes);
    if (key != _key || _root == null) {
      final top = <_PC>[
        for (var i = 0; i < widget.nodes.length; i++)
          if (widget.nodes[i].total > 0) _pack(widget.nodes[i], 0, null, i, '', t)
      ];
      if (top.isNotEmpty) _place(top);
      final virtual = HierarchyNode('root', children: widget.nodes);
      _root = top.isEmpty ? null : (top.length == 1 ? (_PC(virtual, top[0].r, t.colorAt(0), -1, '')..kids = top) : _enclose(virtual, top, t.colorAt(0), -1, ''));
      _key = key;
    }
    final root = _root;
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ChartCanvas(
        duration: widget.animationDuration,
        builder: (p, ptr) => _PackPainter(widget, root, t, p, ptr),
      ),
    );
  }
}

class _PackPainter extends CustomPainter {
  _PackPainter(this.w, this.root, this.theme, this.progress, this.pointer);
  final CirclePackingChart w;
  final _PC? root;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final root = this.root;
    if (root == null) return;
    final fmt = w.valueFormat ?? formatNumber;
    final s = math.min(size.width, size.height) / 2 / root.r * .97;
    final center = size.center(Offset.zero);
    final drawn = <_Drawn>[];
    void walk(_PC n, Offset c) {
      for (final k in n.kids) {
        final kc = c + Offset(k.x * s, k.y * s);
        drawn.add(_Drawn(k, kc, k.r * s));
        walk(k, kc);
      }
    }

    walk(root, center);
    _Drawn? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      for (final d in drawn) {
        if ((d.c - ptr).distance <= d.r) hover = d;
      }
    }
    final grand = root.node.total;
    for (final d in drawn) {
      final leaf = d.pc.kids.isEmpty;
      final r = d.r * progress;
      if (leaf) {
        final fill = Color.lerp(d.pc.color, Colors.white, .1 * math.min(d.pc.depth, 3))!;
        canvas.drawCircle(d.c, r, Paint()..color = identical(d, hover) ? shade2(fill) : fill);
      } else {
        canvas.drawCircle(d.c, r, Paint()..color = d.pc.color.faded(.13));
        canvas.drawCircle(d.c, r, Paint()
          ..color = d.pc.color.faded(.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
      }
      if (w.showLabels && leaf && progress > .99 && d.r >= 18) {
        final tc = contrastOn(d.pc.color);
        paintText(canvas, d.pc.node.label, d.c - Offset(0, d.r >= 28 ? 6 : 0),
            TextStyle(color: tc, fontSize: 11, fontWeight: FontWeight.bold), maxWidth: d.r * 1.8);
        if (d.r >= 28) {
          paintText(canvas, fmt(d.pc.node.total), d.c + const Offset(0, 8), TextStyle(color: tc.withAlpha(200), fontSize: 10), maxWidth: d.r * 1.8);
        }
      }
    }
    if (hover != null && ptr != null) {
      canvas.drawCircle(hover.c, hover.r, Paint()
        ..color = theme.textColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      paintTooltip(canvas, size, ptr, theme, title: hover.pc.path, rows: [
        TooltipRow('${fmt(hover.pc.node.total)} (${(hover.pc.node.total / grand * 100).toStringAsFixed(1)}%)', color: hover.pc.color),
      ]);
    }
  }

  Color shade2(Color c) => Color.lerp(c, Colors.white, .22)!;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
