import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/legend.dart';
import '../core/plot_frame.dart';
import '../pie_chart.dart' show PieSlice;

enum WaffleShape { square, roundedSquare, circle }

/// Splits [cells] between [values] (largest-remainder method) so that the
/// counts add up to the share of [total] that the values cover.
List<int> waffleAllocate(List<double> values, double total, int cells) {
  final n = values.length;
  final out = List<int>.filled(n, 0);
  if (total <= 0 || cells <= 0 || n == 0) return out;
  final sum = values.fold<double>(0, (a, b) => a + math.max(0.0, b));
  final target = math.min(cells, (math.min(sum, total) / total * cells).round());
  final exact = [for (final v in values) math.max(0.0, v) / total * cells];
  var used = 0;
  for (var i = 0; i < n; i++) {
    out[i] = exact[i].floor();
    used += out[i];
  }
  final order = List<int>.generate(n, (i) => i)
    ..sort((a, b) => (exact[b] - exact[b].floor()).compareTo(exact[a] - exact[a].floor()));
  var k = 0;
  while (used < target) {
    out[order[k % n]]++;
    used++;
    k++;
  }
  return out;
}

/// Waffle chart: a grid of cells (100 by default, so each cell is 1 %).
class WaffleChart extends StatelessWidget {
  const WaffleChart({
    super.key,
    required this.slices,
    this.rows = 10,
    this.columns = 10,
    this.total,
    this.shape = WaffleShape.roundedSquare,
    this.gap = 3,
    this.fillFromBottom = true,
    this.byColumns = false,
    this.emptyColor,
    this.showLegend = true,
    this.valueFormat,
    this.aspectRatio = 1.2,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 1000),
  });
  final List<PieSlice> slices;
  final int rows, columns;

  /// Value that fills the whole grid (defaults to the sum of the slices).
  final double? total;
  final WaffleShape shape;
  final double gap;
  final bool fillFromBottom;

  /// Fill column by column instead of row by row.
  final bool byColumns;
  final Color? emptyColor;
  final bool showLegend;
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
      legend: showLegend ? [for (var i = 0; i < slices.length; i++) LegendItem(slices[i].label, slices[i].color ?? t.colorAt(i))] : null,
      builder: (p, ptr) => _WafflePainter(this, t, p, ptr),
    );
  }
}

class _WafflePainter extends CustomPainter {
  _WafflePainter(this.w, this.theme, this.progress, this.pointer);
  final WaffleChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final rows = w.rows, cols = w.columns, cells = rows * cols;
    if (cells <= 0 || w.slices.isEmpty) return;
    final sum = w.slices.fold<double>(0, (a, s) => a + math.max(0.0, s.value));
    final total = w.total ?? sum;
    if (total <= 0) return;
    final fmt = w.valueFormat ?? formatNumber;
    final counts = waffleAllocate([for (final s in w.slices) s.value], total, cells);
    final owner = List<int>.filled(cells, -1);
    var k = 0;
    for (var i = 0; i < counts.length; i++) {
      for (var c = 0; c < counts[i] && k < cells; c++) {
        owner[k++] = i;
      }
    }
    final cell = math.min(size.width / cols, size.height / rows);
    final gw = cell * cols, gh = cell * rows;
    final ox = (size.width - gw) / 2, oy = (size.height - gh) / 2;
    int col(int idx) => w.byColumns ? idx ~/ rows : idx % cols;
    int rowIdx(int idx) => w.byColumns ? idx % rows : idx ~/ cols;
    int rowOnScreen(int idx) => w.fillFromBottom ? rows - 1 - rowIdx(idx) : rowIdx(idx);
    Rect rectOf(int idx) => Rect.fromLTWH(ox + col(idx) * cell, oy + rowOnScreen(idx) * cell, cell, cell).deflate(w.gap / 2);

    int? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1 && ptr.dx >= ox && ptr.dx < ox + gw && ptr.dy >= oy && ptr.dy < oy + gh) {
      final c = ((ptr.dx - ox) / cell).floor().clamp(0, cols - 1).toInt();
      final sr = ((ptr.dy - oy) / cell).floor().clamp(0, rows - 1).toInt();
      final r = w.fillFromBottom ? rows - 1 - sr : sr;
      hover = w.byColumns ? c * rows + r : r * cols + c;
    }
    final hoverOwner = hover == null ? null : owner[hover];
    final empty = w.emptyColor ?? theme.gridColor.faded(.7);
    for (var idx = 0; idx < cells; idx++) {
      final t = (progress * cells - idx).clamp(0.0, 1.0).toDouble();
      if (t <= 0) continue;
      final base = rectOf(idx);
      final r = Rect.fromCenter(center: base.center, width: base.width * t, height: base.height * t);
      final o = owner[idx];
      var color = o >= 0 ? (w.slices[o].color ?? theme.colorAt(o)) : empty;
      if (hoverOwner != null && hoverOwner != o) color = color.faded(.3);
      final paint = Paint()..color = color;
      switch (w.shape) {
        case WaffleShape.square:
          canvas.drawRect(r, paint);
        case WaffleShape.roundedSquare:
          canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(cell * .2)), paint);
        case WaffleShape.circle:
          canvas.drawCircle(r.center, r.shortestSide / 2, paint);
      }
    }
    if (hover != null && ptr != null) {
      final o = owner[hover];
      if (o >= 0) {
        final s = w.slices[o];
        paintTooltip(canvas, size, ptr, theme, title: s.label, rows: [
          TooltipRow('${fmt(s.value)} (${(s.value / total * 100).toStringAsFixed(1)}%)', color: s.color ?? theme.colorAt(o)),
          TooltipRow('${counts[o]} of $cells cells'),
        ]);
      } else {
        paintTooltip(canvas, size, ptr, theme, rows: [TooltipRow('Remaining: ${fmt(math.max(0.0, total - sum))}')]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
