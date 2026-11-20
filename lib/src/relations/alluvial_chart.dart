// Alluvial diagram: how items move between categories across several stages.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';

/// A flow of [value] from category [from] in stage [stage] to category [to]
/// in stage `stage + 1`.
class AlluvialFlow {
  const AlluvialFlow(this.stage, this.from, this.to, this.value, {this.color});
  final int stage;
  final String from, to;
  final double value;

  /// Overrides the colour (default: colour of the source category).
  final Color? color;
}

/// Alluvial diagram: columns are stages (for example survey waves, school
/// years or funnel steps), blocks are categories and ribbons show how many
/// items moved from one category to the next.
///
/// Unlike [SankeyChart] the stages and the category order are given
/// explicitly, so the same category sits at the same place in every column.
class AlluvialChart extends StatelessWidget {
  const AlluvialChart({
    super.key,
    required this.stageTitles,
    required this.categories,
    required this.flows,
    this.nodeWidth = 14,
    this.nodePadding = 8,
    this.flowOpacity = 0.4,
    this.showLabels = true,
    this.valueFormat,
    this.aspectRatio = 1.6,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 1000),
  });

  /// One title per stage (drawn above the column).
  final List<String> stageTitles;

  /// Category names per stage, top to bottom: `categories[stage][i]`.
  final List<List<String>> categories;

  /// Flows between consecutive stages.
  final List<AlluvialFlow> flows;
  final double nodeWidth, nodePadding, flowOpacity;
  final bool showLabels;
  final String Function(double)? valueFormat;
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
      builder: (p, ptr) => _AlluvialPainter(this, t, p, ptr),
    );
  }
}

/// One category block of one stage, after layout.
class _Block {
  _Block(this.stage, this.index, this.label);
  final int stage, index;
  final String label;
  double inV = 0, outV = 0;
  Rect rect = Rect.zero;
  double get value => math.max(inV, outV);
}

class _AlluvialPainter extends CustomPainter {
  _AlluvialPainter(this.w, this.theme, this.progress, this.pointer);
  final AlluvialChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final stages = w.categories.length;
    if (stages < 2) return;
    final fmt = w.valueFormat ?? formatNumber;

    // ---- 1. blocks and a colour per category label (same label = same colour)
    final blocks = <List<_Block>>[
      for (var s = 0; s < stages; s++) [for (var i = 0; i < w.categories[s].length; i++) _Block(s, i, w.categories[s][i])]
    ];
    final colors = <String, Color>{};
    for (final stage in w.categories) {
      for (final label in stage) {
        colors.putIfAbsent(label, () => theme.colorAt(colors.length));
      }
    }
    _Block? find(int stage, String label) {
      if (stage < 0 || stage >= stages) return null;
      for (final b in blocks[stage]) {
        if (b.label == label) return b;
      }
      return null;
    }

    // ---- 2. resolve flows and accumulate block sizes
    final fl = <_ResolvedFlow>[];
    for (final f in w.flows) {
      final a = find(f.stage, f.from), b = find(f.stage + 1, f.to);
      if (a == null || b == null || f.value <= 0) continue;
      a.outV += f.value;
      b.inV += f.value;
      fl.add(_ResolvedFlow(f, a, b));
    }
    if (fl.isEmpty) return;

    // ---- 3. vertical scale: the tightest stage decides pixels per unit
    final plot = Rect.fromLTRB(6, 26, size.width - (w.showLabels ? 70 : 6), size.height - 8);
    if (plot.width <= 40 || plot.height <= 40) return;
    var ky = double.infinity;
    for (final col in blocks) {
      final used = col.where((b) => b.value > 0).toList();
      if (used.isEmpty) continue;
      final sum = used.fold<double>(0, (a, b) => a + b.value);
      ky = math.min(ky, (plot.height - w.nodePadding * (used.length - 1)) / sum);
    }
    if (!ky.isFinite || ky <= 0) return;

    // ---- 4. place blocks: columns evenly spaced, each column centred vertically
    for (var s = 0; s < stages; s++) {
      final used = blocks[s].where((b) => b.value > 0).toList();
      final totalH = used.fold<double>(0, (a, b) => a + b.value) * ky + w.nodePadding * math.max(0, used.length - 1);
      var y = plot.top + (plot.height - totalH) / 2;
      final x = plot.left + s * (plot.width - w.nodeWidth) / (stages - 1);
      for (final b in used) {
        b.rect = Rect.fromLTWH(x, y, w.nodeWidth, b.value * ky);
        y += b.rect.height + w.nodePadding;
      }
    }

    // ---- 5. ribbon offsets: inside a block, flows are stacked in the order of
    //         the block at the other end, which avoids needless crossings
    final srcY = <_ResolvedFlow, double>{}, dstY = <_ResolvedFlow, double>{};
    for (final col in blocks) {
      for (final b in col) {
        final outs = fl.where((f) => identical(f.a, b)).toList()..sort((x, y) => x.b.index.compareTo(y.b.index));
        var y = b.rect.top;
        for (final f in outs) {
          srcY[f] = y;
          y += f.flow.value * ky;
        }
        final ins = fl.where((f) => identical(f.b, b)).toList()..sort((x, y) => x.a.index.compareTo(y.a.index));
        y = b.rect.top;
        for (final f in ins) {
          dstY[f] = y;
          y += f.flow.value * ky;
        }
      }
    }
    final paths = <_ResolvedFlow, Path>{};
    for (final f in fl) {
      final x0 = f.a.rect.right, x1 = f.b.rect.left, h = f.flow.value * ky, mx = (x0 + x1) / 2;
      // A band: top edge as an S-curve, straight down, bottom edge back.
      paths[f] = Path()
        ..moveTo(x0, srcY[f]!)
        ..cubicTo(mx, srcY[f]!, mx, dstY[f]!, x1, dstY[f]!)
        ..lineTo(x1, dstY[f]! + h)
        ..cubicTo(mx, dstY[f]! + h, mx, srcY[f]! + h, x0, srcY[f]! + h)
        ..close();
    }

    // ---- 6. hit-test (blocks win over ribbons)
    _Block? hBlock;
    _ResolvedFlow? hFlow;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      for (final col in blocks) {
        for (final b in col) {
          if (b.value > 0 && b.rect.inflate(2).contains(ptr)) hBlock = b;
        }
      }
      if (hBlock == null) {
        for (final f in fl) {
          if (paths[f]!.contains(ptr)) hFlow = f;
        }
      }
    }

    // ---- 7. draw (clipped left to right to animate)
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    for (final f in fl) {
      final touches = hBlock != null && (identical(f.a, hBlock) || identical(f.b, hBlock));
      final strong = touches || identical(f, hFlow);
      final dim = (hBlock != null || hFlow != null) && !strong;
      final base = f.flow.color ?? colors[f.a.label]!;
      canvas.drawPath(paths[f]!, Paint()..color = base.faded(strong ? .7 : (dim ? w.flowOpacity * .35 : w.flowOpacity)));
    }
    for (final col in blocks) {
      for (final b in col) {
        if (b.value <= 0) continue;
        canvas.drawRRect(RRect.fromRectAndRadius(b.rect, const Radius.circular(2)), Paint()..color = colors[b.label]!);
        if (w.showLabels && progress > .99) {
          // Last column: label on the right; others also on the right (over the ribbons).
          paintText(canvas, b.label, Offset(b.rect.right + 5, b.rect.center.dy), theme.labelStyle.copyWith(color: theme.textColor),
              align: Alignment.centerLeft, maxWidth: 64);
        }
      }
    }
    canvas.restore();
    for (var s = 0; s < stages && s < w.stageTitles.length; s++) {
      paintText(canvas, w.stageTitles[s], Offset(plot.left + s * (plot.width - w.nodeWidth) / (stages - 1) + w.nodeWidth / 2, 6),
          theme.labelStyle.copyWith(color: theme.textColor, fontWeight: FontWeight.w700), align: Alignment.topCenter);
    }

    // ---- 8. tooltip
    if (ptr != null) {
      if (hBlock != null) {
        paintTooltip(canvas, size, ptr, theme, title: hBlock.label, rows: [
          TooltipRow('${hBlock.stage < w.stageTitles.length ? w.stageTitles[hBlock.stage] : 'Stage ${hBlock.stage + 1}'}', color: colors[hBlock.label]),
          TooltipRow('Total: ${fmt(hBlock.value)}'),
          if (hBlock.inV > 0) TooltipRow('Came in: ${fmt(hBlock.inV)}'),
          if (hBlock.outV > 0) TooltipRow('Went out: ${fmt(hBlock.outV)}'),
        ]);
      } else if (hFlow != null) {
        final f = hFlow;
        paintTooltip(canvas, size, ptr, theme, title: '${f.a.label} → ${f.b.label}', rows: [
          TooltipRow(fmt(f.flow.value), color: f.flow.color ?? colors[f.a.label]),
          TooltipRow('${(f.flow.value / f.a.outV * 100).toStringAsFixed(0)}% of ${f.a.label}'),
        ]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// A flow whose end blocks have been looked up.
class _ResolvedFlow {
  _ResolvedFlow(this.flow, this.a, this.b);
  final AlluvialFlow flow;
  final _Block a, b;
}
