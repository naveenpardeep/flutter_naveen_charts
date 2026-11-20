import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/legend.dart';
import '../core/plot_frame.dart';
import '../pie_chart.dart' show PieSlice;

/// Concentric pies: every ring is its own full circle (inner ring first).
/// Slices with the same label share a colour across rings.
class NestedPieChart extends StatelessWidget {
  const NestedPieChart({
    super.key,
    required this.rings,
    this.ringNames,
    this.holeRatio = 0.25,
    this.ringGap = 3,
    this.showPercent = true,
    this.showLegend = true,
    this.valueFormat,
    this.aspectRatio = 1.3,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<List<PieSlice>> rings;

  /// Optional ring titles shown in tooltips (inner to outer).
  final List<String>? ringNames;
  final double holeRatio;
  final double ringGap;
  final bool showPercent;
  final bool showLegend;
  final String Function(double)? valueFormat;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    final colors = _colors(t);
    return chartShell(
      theme: t,
      aspectRatio: aspectRatio,
      duration: animationDuration,
      legend: showLegend ? [for (final e in colors.entries) LegendItem(e.key, e.value)] : null,
      builder: (p, ptr) => _NestedPainter(this, colors, t, p, ptr),
    );
  }

  Map<String, Color> _colors(ChartTheme t) {
    final m = <String, Color>{};
    for (final ring in rings) {
      for (final s in ring) {
        m.putIfAbsent(s.label, () => s.color ?? t.colorAt(m.length));
      }
    }
    return m;
  }
}

class _NestedPainter extends CustomPainter {
  _NestedPainter(this.w, this.colors, this.theme, this.progress, this.pointer);
  final NestedPieChart w;
  final Map<String, Color> colors;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;
  static const double _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.rings.length;
    if (n == 0) return;
    final fmt = w.valueFormat ?? formatNumber;
    final c = size.center(Offset.zero);
    final R = math.min(size.width, size.height) / 2 - 6;
    if (R <= 10) return;
    final hole = R * w.holeRatio;
    final rw = (R - hole) / n;

    int? hr, hs;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      final d = ptr - c;
      final ring = ((d.distance - hole) / rw).floor();
      if (ring >= 0 && ring < n && d.distance <= R) {
        final tot = w.rings[ring].fold<double>(0, (a, s) => a + math.max(0.0, s.value));
        final ang = (math.atan2(d.dy, d.dx) - _start) % (2 * math.pi);
        var acc = 0.0;
        for (var i = 0; i < w.rings[ring].length; i++) {
          final full = math.max(0.0, w.rings[ring][i].value) / tot * 2 * math.pi;
          if (ang >= acc && ang < acc + full) {
            hr = ring;
            hs = i;
            break;
          }
          acc += full;
        }
      }
    }
    for (var k = 0; k < n; k++) {
      final slices = w.rings[k];
      final tot = slices.fold<double>(0, (a, s) => a + math.max(0.0, s.value));
      if (tot <= 0) continue;
      final r0 = hole + k * rw + (k == 0 ? 0 : w.ringGap / 2), r1 = hole + (k + 1) * rw - w.ringGap / 2;
      var a = _start;
      for (var i = 0; i < slices.length; i++) {
        final full = math.max(0.0, slices[i].value) / tot * 2 * math.pi;
        final sweep = full * progress;
        final color = colors[slices[i].label] ?? theme.colorAt(i);
        final hot = hr == k && hs == i;
        final path = sectorPath(c, r0, r1, a + .004, math.max(0.0, sweep - .008));
        canvas.drawPath(path, Paint()..color = hot ? Color.lerp(color, Colors.white, .22)! : color);
        if (w.showPercent && progress > .99 && full > .32) {
          paintText(canvas, '${(slices[i].value / tot * 100).round()}%', c + Offset.fromDirection(a + full / 2, (r0 + r1) / 2),
              TextStyle(color: contrastOn(color), fontSize: 10.5, fontWeight: FontWeight.bold));
        }
        a += sweep;
      }
    }
    if (hr != null && hs != null && ptr != null) {
      final ring = w.rings[hr];
      final tot = ring.fold<double>(0, (a, s) => a + math.max(0.0, s.value));
      final s = ring[hs];
      paintTooltip(canvas, size, ptr,
          theme,
          title: (w.ringNames != null && hr < w.ringNames!.length) ? w.ringNames![hr] : 'Ring ${hr + 1}',
          rows: [TooltipRow('${s.label}: ${fmt(s.value)} (${(s.value / tot * 100).toStringAsFixed(1)}%)', color: colors[s.label])]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
