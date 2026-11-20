// Adjacency matrix: every pair of nodes as a cell, coloured by link weight.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart3d.dart' show rampColor;
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';
import '../network_graph.dart' show NetworkNode, NetworkEdge;
import 'relation_utils.dart';

/// Row / column order of an [AdjacencyMatrixChart].
enum AdjacencyOrder {
  /// Keep the order of `nodes`.
  given,

  /// Alphabetical by label.
  name,

  /// Most connected first.
  degree,

  /// Group by `NetworkNode.group` - clusters show up as dense blocks.
  group,
}

/// Adjacency matrix: rows and columns are nodes, a filled cell means "row is
/// linked to column" and its colour shows the weight. Unlike a node-link
/// graph it stays readable for dense networks, and re-ordering the nodes
/// (see [order]) reveals clusters as solid blocks.
///
/// Hover a cell to highlight its row and column.
class AdjacencyMatrixChart extends StatelessWidget {
  const AdjacencyMatrixChart({
    super.key,
    required this.nodes,
    required this.edges,
    this.order = AdjacencyOrder.given,
    this.directed = false,
    this.showValues = false,
    this.showGroupBars = true,
    this.colors = const [Color(0xFFDCE9F7), Color(0xFF4E79A7), Color(0xFF08306B)],
    this.valueFormat,
    this.aspectRatio = 1.0,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 800),
  });

  /// Rows and columns.
  final List<NetworkNode> nodes;

  /// Links between node ids; `weight` decides the cell colour.
  final List<NetworkEdge> edges;
  final AdjacencyOrder order;

  /// false: a link fills both (a,b) and (b,a); true: only (source,target).
  final bool directed;

  /// Print the weight inside each filled cell (when cells are big enough).
  final bool showValues;

  /// Thin bars along the axes coloured by node group.
  final bool showGroupBars;

  /// Colour ramp from the lightest to the heaviest weight.
  final List<Color> colors;
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
      builder: (p, ptr) => _AdjPainter(this, t, p, ptr),
    );
  }
}

class _AdjPainter extends CustomPainter {
  _AdjPainter(this.w, this.theme, this.progress, this.pointer);
  final AdjacencyMatrixChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.nodes.length;
    if (n == 0) return;
    final fmt = w.valueFormat ?? formatNumber;
    final index = {for (var i = 0; i < n; i++) w.nodes[i].id: i};

    // ---- 1. weights per (row, column); undirected links are mirrored
    final m = List.generate(n, (_) => List<double>.filled(n, 0));
    final degree = List<int>.filled(n, 0);
    for (final e in w.edges) {
      final a = index[e.source], b = index[e.target];
      if (a == null || b == null) continue;
      m[a][b] += e.weight;
      if (!w.directed && a != b) m[b][a] += e.weight;
      degree[a]++;
      if (a != b) degree[b]++;
    }

    // ---- 2. order rows and columns the same way
    String label(int i) => w.nodes[i].label ?? w.nodes[i].id;
    final ord = List<int>.generate(n, (i) => i);
    switch (w.order) {
      case AdjacencyOrder.given:
        break;
      case AdjacencyOrder.name:
        ord.sort((a, b) => label(a).compareTo(label(b)));
      case AdjacencyOrder.degree:
        ord.sort((a, b) => degree[b].compareTo(degree[a]));
      case AdjacencyOrder.group:
        ord.sort((a, b) => w.nodes[a].group != w.nodes[b].group ? w.nodes[a].group.compareTo(w.nodes[b].group) : a.compareTo(b));
    }

    // ---- 3. geometry: labels left (horizontal) and top (vertical), then cells
    final labelW = math.min(90.0, ord.map((i) => measureText(label(i), theme.labelStyle).width).fold<double>(0, math.max) + 8);
    final bar = w.showGroupBars ? 7.0 : 0.0;
    final left = labelW + bar + 4, top = labelW + bar + 4;
    final cell = math.min((size.width - left - 4) / n, (size.height - top - 4) / n);
    if (cell < 3) return;
    final gx = (size.width - left - cell * n) / 2; // centre the grid horizontally
    final ox = left + math.max(0.0, gx), oy = top;
    Rect cellRect(int r, int c) => Rect.fromLTWH(ox + c * cell, oy + r * cell, cell, cell);
    Color groupColor(int node) => w.nodes[node].color ?? theme.colorAt(w.nodes[node].group);

    var maxW = 0.0;
    for (final row in m) {
      for (final v in row) {
        maxW = math.max(maxW, v);
      }
    }

    // ---- 4. hit-test: which cell is under the pointer
    int? hr, hc;
    final ptr = pointer;
    if (ptr != null && progress >= 1 && ptr.dx >= ox && ptr.dx < ox + cell * n && ptr.dy >= oy && ptr.dy < oy + cell * n) {
      hc = ((ptr.dx - ox) / cell).floor().clamp(0, n - 1).toInt();
      hr = ((ptr.dy - oy) / cell).floor().clamp(0, n - 1).toInt();
    }

    // ---- 5. cells
    final empty = Paint()..color = theme.gridColor.faded(.35);
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final rect = cellRect(r, c).deflate(cell > 8 ? .6 : 0);
        final v = m[ord[r]][ord[c]];
        if (v <= 0) {
          canvas.drawRect(rect, empty);
          continue;
        }
        final fill = rampColor(w.colors, maxW <= 0 ? 1 : v / maxW);
        // Cells fade in diagonally so the animation sweeps across the matrix.
        final a = (progress * 2 - (r + c) / (2.0 * n)).clamp(0.0, 1.0).toDouble();
        canvas.drawRect(rect, Paint()..color = fill.faded(a));
        if (w.showValues && cell > 22 && progress > .99) {
          paintText(canvas, fmt(v), rect.center, TextStyle(color: contrastOn(fill), fontSize: math.min(11.0, cell * .38)));
        }
      }
    }

    // ---- 6. highlight the hovered row and column
    if (hr != null && hc != null) {
      final band = Paint()..color = theme.textColor.faded(.1);
      canvas.drawRect(Rect.fromLTWH(ox, oy + hr * cell, cell * n, cell), band);
      canvas.drawRect(Rect.fromLTWH(ox + hc * cell, oy, cell, cell * n), band);
      canvas.drawRect(cellRect(hr, hc), Paint()
        ..color = theme.textColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }

    // ---- 7. labels, group bars and group separators
    for (var i = 0; i < n; i++) {
      final node = ord[i];
      final bold = hr == i || hc == i;
      final style = theme.labelStyle.copyWith(
          fontSize: math.min(11.5, math.max(8.0, cell * .6)),
          color: theme.textColor.faded(hr == null || bold ? 1 : .45),
          fontWeight: bold ? FontWeight.bold : FontWeight.normal);
      // Row label (left of the matrix).
      paintText(canvas, label(node), Offset(ox - bar - 5, oy + (i + .5) * cell), style, align: Alignment.centerRight, maxWidth: labelW);
      // Column label (above the matrix, reading bottom to top).
      paintRotatedText(canvas, label(node), Offset(ox + (i + .5) * cell, oy - bar - 5), style, -math.pi / 2, maxWidth: labelW);
      if (w.showGroupBars) {
        canvas.drawRect(Rect.fromLTWH(ox - bar, oy + i * cell, bar - 2, cell), Paint()..color = groupColor(node));
        canvas.drawRect(Rect.fromLTWH(ox + i * cell, oy - bar, cell, bar - 2), Paint()..color = groupColor(node));
      }
      // A line wherever the group changes makes the blocks easy to read.
      if (i > 0 && w.nodes[ord[i - 1]].group != w.nodes[node].group) {
        final sep = Paint()
          ..color = theme.textColor.faded(.5)
          ..strokeWidth = 1.2;
        canvas.drawLine(Offset(ox, oy + i * cell), Offset(ox + n * cell, oy + i * cell), sep);
        canvas.drawLine(Offset(ox + i * cell, oy), Offset(ox + i * cell, oy + n * cell), sep);
      }
    }

    // ---- 8. tooltip
    if (hr != null && hc != null && ptr != null) {
      final a = ord[hr], b = ord[hc];
      final v = m[a][b];
      paintTooltip(canvas, size, ptr, theme,
          title: '${label(a)} ${w.directed ? '→' : '↔'} ${label(b)}',
          rows: [
            TooltipRow(v > 0 ? 'Weight: ${fmt(v)}' : 'No link', color: v > 0 ? rampColor(w.colors, maxW <= 0 ? 1 : v / maxW) : null),
            if (w.directed && m[b][a] > 0) TooltipRow('Reverse: ${fmt(m[b][a])}'),
          ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
