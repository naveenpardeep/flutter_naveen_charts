// Horizon chart: many time series stacked in thin rows, with values folded into colour bands.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';

class HorizonSeries {
  const HorizonSeries(this.name, this.values);
  final String name;

  /// One value per x position (all series should have the same length).
  final List<double> values;
}

/// Horizon chart: a compact way to compare many time series. Each series is
/// one thin row. The value range above the [baseline] is cut into [bands]
/// layers that are folded on top of each other and drawn in darker and darker
/// shades, so a row only needs 1/[bands] of the height an area chart would.
/// Values below the baseline are folded the same way in a second colour (or
/// mirrored in the same row).
///
/// Hover to read every series at the same x position.
class HorizonChart extends StatelessWidget {
  const HorizonChart({
    super.key,
    required this.series,
    this.xLabels,
    this.bands = 3,
    this.baseline = 0,
    this.sharedScale = true,
    this.positiveColor = const Color(0xFF2B7BBA),
    this.negativeColor = const Color(0xFFD6604D),
    this.rowHeight = 34,
    this.valueFormat,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<HorizonSeries> series;

  /// Label per x position (dates, hours ...); used for axis labels and tooltips.
  final List<String>? xLabels;

  /// Number of folded layers (3 is the classic choice).
  final int bands;

  /// Values above are "positive", below are "negative".
  final double baseline;

  /// One colour scale for all rows (true) or each row scaled to its own range.
  final bool sharedScale;
  final Color positiveColor, negativeColor;
  final double rowHeight;
  final String Function(double)? valueFormat;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return SizedBox(
      height: series.length * rowHeight + 34,
      child: chartShellBox(t, animationDuration, (p, ptr) => _HorizonPainter(this, t, p, ptr)),
    );
  }
}

class _HorizonPainter extends CustomPainter {
  _HorizonPainter(this.w, this.theme, this.progress, this.pointer);
  final HorizonChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final rows = w.series.length;
    if (rows == 0) return;
    final m = w.series.map((s) => s.values.length).reduce(math.max);
    if (m < 2) return;
    final fmt = w.valueFormat ?? formatNumber;
    final labelW = w.series.map((s) => measureText(s.name, theme.labelStyle).width).fold<double>(0, math.max) + 10;
    final plot = Rect.fromLTRB(labelW + 8, 4, size.width - 12, size.height - 26);
    if (plot.width < 30) return;
    final rowH = plot.height / rows;
    double sx(int i) => plot.left + i / (m - 1) * plot.width;
    double val(HorizonSeries s, int i) => i < s.values.length ? s.values[i] : w.baseline;

    // ---- 1. largest distance from the baseline decides the band height
    double maxDev(HorizonSeries s) {
      var d = 0.0;
      for (final v in s.values) {
        d = math.max(d, (v - w.baseline).abs());
      }
      return d <= 0 ? 1 : d;
    }

    final globalDev = w.series.map(maxDev).reduce(math.max);

    // ---- 2. hit-test: nearest x position
    int? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1 && plot.inflate(4).contains(ptr)) {
      hover = (((ptr.dx - plot.left) / plot.width) * (m - 1)).round().clamp(0, m - 1).toInt();
    }

    // ---- 3. rows
    for (var r = 0; r < rows; r++) {
      final s = w.series[r];
      final top = plot.top + r * rowH, bottom = top + rowH;
      final bandVal = (w.sharedScale ? globalDev : maxDev(s)) / w.bands; // value covered by one layer
      canvas.drawRect(Rect.fromLTRB(plot.left, top, plot.right, bottom), Paint()..color = theme.axisColor.faded(r.isEven ? .06 : .0));
      paintText(canvas, s.name, Offset(labelW, top + rowH / 2), theme.labelStyle.copyWith(color: theme.textColor, fontWeight: FontWeight.w600),
          align: Alignment.centerRight, maxWidth: labelW);

      canvas.save();
      canvas.clipRect(Rect.fromLTRB(plot.left, top, plot.right, bottom));
      // Draw the layers from the lightest to the darkest. Layer k keeps only
      // the part of the value between k*bandVal and (k+1)*bandVal, scaled to
      // the full row height - that is the "fold".
      for (final positive in [true, false]) {
        final base = positive ? w.positiveColor : w.negativeColor;
        for (var k = 0; k < w.bands; k++) {
          final path = Path()..moveTo(sx(0), bottom);
          for (var i = 0; i < m; i++) {
            final dev = positive ? math.max(0.0, val(s, i) - w.baseline) : math.max(0.0, w.baseline - val(s, i));
            final h = (dev - k * bandVal).clamp(0.0, bandVal).toDouble() / bandVal * rowH * progress;
            path.lineTo(sx(i), bottom - h);
          }
          path
            ..lineTo(sx(m - 1), bottom)
            ..close();
          // lighter first, darker on top: 1/bands .. 1 of the full colour
          canvas.drawPath(path, Paint()..color = Color.lerp(theme.surface, base, (k + 1) / w.bands)!);
        }
      }
      canvas.restore();
      canvas.drawLine(Offset(plot.left, bottom), Offset(plot.right, bottom), Paint()
        ..color = theme.gridColor
        ..strokeWidth = 1);
    }

    // ---- 4. x labels
    if (w.xLabels != null) {
      final maxW = w.xLabels!.map((l) => measureText(l, theme.labelStyle).width).fold<double>(0, math.max);
      final every = math.max(1, ((maxW + 10) / (plot.width / (m - 1))).ceil());
      for (var i = 0; i < m && i < w.xLabels!.length; i += every) {
        paintText(canvas, w.xLabels![i], Offset(sx(i), plot.bottom + 6), theme.labelStyle, align: Alignment.topCenter);
      }
    }

    // ---- 5. guide and tooltip
    if (hover != null && ptr != null) {
      canvas.drawLine(Offset(sx(hover), plot.top), Offset(sx(hover), plot.bottom), Paint()
        ..color = theme.textColor.faded(.6)
        ..strokeWidth = 1);
      paintTooltip(canvas, size, ptr, theme, title: (w.xLabels != null && hover < w.xLabels!.length) ? w.xLabels![hover] : 'Position ${hover + 1}', rows: [
        for (final s in w.series)
          TooltipRow('${s.name}: ${fmt(val(s, hover))}', color: val(s, hover) >= w.baseline ? w.positiveColor : w.negativeColor),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
