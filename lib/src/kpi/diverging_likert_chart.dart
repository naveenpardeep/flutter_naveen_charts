// Diverging stacked bars for Likert (agree / disagree) survey results.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart3d.dart' show rampColor;
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/legend.dart';
import '../core/plot_frame.dart';

/// One survey question: [counts] has one number per response level.
class LikertQuestion {
  const LikertQuestion(this.label, this.counts);
  final String label;
  final List<double> counts;
}

/// Net agreement in percent: share of positive answers minus share of negative
/// ones. [neutralIndex] (the middle level of an odd scale) is left out; for
/// even scales pass -1 and the scale is split in half.
double likertNet(List<double> counts, {int? neutralIndex}) {
  final n = counts.length;
  final total = counts.fold<double>(0, (a, b) => a + b);
  if (total <= 0 || n < 2) return 0;
  final mid = neutralIndex ?? (n.isOdd ? n ~/ 2 : -1);
  var neg = 0.0, pos = 0.0;
  for (var i = 0; i < n; i++) {
    if (i == mid) continue;
    if (i < (mid >= 0 ? mid : n / 2)) {
      neg += counts[i];
    } else {
      pos += counts[i];
    }
  }
  return (pos - neg) / total * 100;
}

/// Diverging Likert chart: each question is a bar centred on zero. Negative
/// answers extend to the left, positive ones to the right and a neutral middle
/// answer is split over the centre line. This makes it easy to compare
/// agreement across questions at a glance, which plain stacked bars do not.
///
/// Rows can be sorted by net agreement and show it at the right edge. Hover a
/// segment for counts and percentages.
class DivergingLikertChart extends StatelessWidget {
  const DivergingLikertChart({
    super.key,
    required this.levels,
    required this.questions,
    this.colors,
    this.sortByNet = false,
    this.showPercent = true,
    this.showNet = true,
    this.rowHeight = 36,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  /// Response levels from most negative to most positive, e.g.
  /// `['Strongly disagree', ..., 'Strongly agree']`. An odd number means the
  /// middle one is neutral.
  final List<String> levels;
  final List<LikertQuestion> questions;

  /// One colour per level (default: red - grey - blue diverging scale).
  final List<Color>? colors;

  /// Order rows by net agreement (highest first).
  final bool sortByNet;

  /// Print the percentage inside wide segments.
  final bool showPercent;

  /// Print the net agreement at the right of each row.
  final bool showNet;
  final double rowHeight;
  final ChartTheme? theme;
  final Duration animationDuration;

  static const List<Color> _ramp = [Color(0xFFB2182B), Color(0xFFEF8A62), Color(0xFFD9D9D9), Color(0xFF67A9CF), Color(0xFF2166AC)];

  /// Colour of level [i] out of [n].
  Color colorAt(int i, int n) => (colors != null && i < colors!.length) ? colors![i] : rampColor(_ramp, n <= 1 ? .5 : i / (n - 1));

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    final rows = [...questions];
    if (sortByNet) {
      rows.sort((a, b) => likertNet(b.counts).compareTo(likertNet(a.counts)));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ChartLegend(theme: t, items: [for (var i = 0; i < levels.length; i++) LegendItem(levels[i], colorAt(i, levels.length))]),
      ),
      SizedBox(
        height: rows.length * rowHeight + 34,
        child: chartShellBox(t, animationDuration, (p, ptr) => _LikertPainter(this, rows, t, p, ptr)),
      ),
    ]);
  }
}

class _Seg {
  _Seg(this.row, this.level, this.rect, this.pct);
  final int row, level;
  final Rect rect;
  final double pct;
}

class _LikertPainter extends CustomPainter {
  _LikertPainter(this.w, this.rows, this.theme, this.progress, this.pointer);
  final DivergingLikertChart w;
  final List<LikertQuestion> rows;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.levels.length;
    if (n < 2 || rows.isEmpty) return;

    // ---- 1. percentages per level, and how far each side reaches
    final pcts = <List<double>>[];
    var reach = 0.0; // largest extent to either side, in percent
    final neutral = n.isOdd ? n ~/ 2 : -1;
    for (final q in rows) {
      final total = q.counts.fold<double>(0, (a, b) => a + b);
      final p = [for (var i = 0; i < n; i++) total <= 0 || i >= q.counts.length ? 0.0 : q.counts[i] / total * 100];
      pcts.add(p);
      final neutralHalf = neutral >= 0 ? p[neutral] / 2 : 0.0;
      final leftSum = [for (var i = 0; i < (neutral >= 0 ? neutral : n ~/ 2); i++) p[i]].fold<double>(0, (a, b) => a + b);
      final rightSum = [for (var i = (neutral >= 0 ? neutral + 1 : n ~/ 2); i < n; i++) p[i]].fold<double>(0, (a, b) => a + b);
      reach = math.max(reach, math.max(leftSum, rightSum) + neutralHalf);
    }
    final scale = NiceScale.compute(0, math.max(reach, 10.0), includeZero: true, maxTicks: 4);
    final M = scale.max; // axis runs from -M to +M percent

    // ---- 2. layout
    final labelW = math.min(130.0, rows.map((q) => measureText(q.label, theme.labelStyle).width).fold<double>(0, math.max) + 10);
    final netW = w.showNet ? 46.0 : 0.0;
    final plot = Rect.fromLTRB(labelW + 10, 4, size.width - netW - 8, size.height - 28);
    if (plot.width < 60) return;
    double sx(double pctFromCenter) => plot.center.dx + pctFromCenter / M * (plot.width / 2);
    final rowH = plot.height / rows.length;

    // ---- 3. grid and axis labels (always positive numbers)
    for (final t in scale.ticks) {
      for (final sign in t == 0 ? const [1] : const [-1, 1]) {
        canvas.drawLine(Offset(sx(sign * t), plot.top), Offset(sx(sign * t), plot.bottom), Paint()
          ..color = t == 0 ? theme.axisColor : theme.gridColor
          ..strokeWidth = t == 0 ? 1.6 : 1);
        paintText(canvas, '${formatNumber(t)}%', Offset(sx(sign * t), plot.bottom + 5), theme.labelStyle, align: Alignment.topCenter);
      }
    }

    // ---- 4. build the segments: negatives go left from the centre line (the
    //         level next to the middle first), positives go right; a neutral
    //         level straddles the centre
    final segs = <_Seg>[];
    for (var r = 0; r < rows.length; r++) {
      final p = pcts[r];
      final top = plot.top + r * rowH + rowH * .14, bottom = plot.top + (r + 1) * rowH - rowH * .14;
      var left = neutral >= 0 ? -p[neutral] / 2 : 0.0;
      var right = neutral >= 0 ? p[neutral] / 2 : 0.0;
      if (neutral >= 0) segs.add(_Seg(r, neutral, Rect.fromLTRB(sx(left), top, sx(right), bottom), p[neutral]));
      for (var i = (neutral >= 0 ? neutral : n ~/ 2) - 1; i >= 0; i--) {
        segs.add(_Seg(r, i, Rect.fromLTRB(sx(left - p[i]), top, sx(left), bottom), p[i]));
        left -= p[i];
      }
      for (var i = neutral >= 0 ? neutral + 1 : n ~/ 2; i < n; i++) {
        segs.add(_Seg(r, i, Rect.fromLTRB(sx(right), top, sx(right + p[i]), bottom), p[i]));
        right += p[i];
      }
    }

    // ---- 5. hit-test, then draw rows
    _Seg? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      for (final s in segs) {
        if (s.rect.contains(ptr)) hover = s;
      }
    }
    for (var r = 0; r < rows.length; r++) {
      paintText(canvas, rows[r].label, Offset(labelW, plot.top + (r + .5) * rowH), theme.labelStyle.copyWith(color: theme.textColor),
          align: Alignment.centerRight, maxWidth: labelW);
    }
    for (final s in segs) {
      if (s.rect.width <= 0) continue;
      // bars grow outwards from the centre line
      final cx = plot.center.dx;
      final grown = Rect.fromLTRB(cx + (s.rect.left - cx) * progress, s.rect.top, cx + (s.rect.right - cx) * progress, s.rect.bottom);
      final color = w.colorAt(s.level, n);
      canvas.drawRect(grown, Paint()..color = identical(s, hover) ? Color.lerp(color, Colors.white, .22)! : color);
      if (w.showPercent && progress > .99 && s.rect.width > 30) {
        paintText(canvas, '${s.pct.round()}%', s.rect.center, TextStyle(color: contrastOn(color), fontSize: 11, fontWeight: FontWeight.w600));
      }
    }

    // ---- 6. net agreement at the right edge
    if (w.showNet && progress > .99) {
      for (var r = 0; r < rows.length; r++) {
        final net = likertNet(rows[r].counts, neutralIndex: neutral);
        paintText(canvas, '${net >= 0 ? '+' : '−'}${net.abs().round()}%', Offset(size.width - 6, plot.top + (r + .5) * rowH),
            TextStyle(color: net >= 0 ? const Color(0xFF2166AC) : const Color(0xFFB2182B), fontSize: 12, fontWeight: FontWeight.w800),
            align: Alignment.centerRight);
      }
    }

    // ---- 7. tooltip: every level of the hovered row, hovered one first
    if (hover != null && ptr != null) {
      final h = hover;
      final q = rows[h.row];
      paintTooltip(canvas, size, ptr, theme, title: q.label, rows: [
        for (var i = 0; i < n; i++)
          TooltipRow('${w.levels[i]}: ${i < q.counts.length ? formatNumber(q.counts[i]) : 0} (${pcts[h.row][i].toStringAsFixed(0)}%)',
              color: w.colorAt(i, n)),
        TooltipRow('Net agreement: ${likertNet(q.counts, neutralIndex: neutral).toStringAsFixed(0)}%'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
