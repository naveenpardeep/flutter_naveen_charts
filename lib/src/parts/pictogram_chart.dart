import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';

class PictogramItem {
  const PictogramItem(this.label, this.value, {this.color, this.icon});
  final String label;
  final double value;
  final Color? color;

  /// Falls back to the chart's default icon.
  final IconData? icon;
}

/// Pictogram (isotype) chart: each icon stands for [unitValue]; the last
/// icon is partially filled for fractions.
class PictogramChart extends StatelessWidget {
  const PictogramChart({
    super.key,
    required this.items,
    this.unitValue = 1,
    this.icon = Icons.person,
    this.rowHeight = 44,
    this.iconGap = 3,
    this.showValues = true,
    this.valueFormat,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<PictogramItem> items;

  /// What one icon represents (e.g. 10 = ten people per icon).
  final double unitValue;
  final IconData icon;
  final double rowHeight;
  final double iconGap;
  final bool showValues;
  final String Function(double)? valueFormat;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        height: items.length * rowHeight + 8,
        child: chartShellBox(t, animationDuration, (p, ptr) => _PictoPainter(this, t, p, ptr)),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: t.axisColor),
          const SizedBox(width: 4),
          Text('= ${formatNumber(unitValue)}', style: t.labelStyle),
        ]),
      ),
    ]);
  }
}

class _PictoPainter extends CustomPainter {
  _PictoPainter(this.w, this.theme, this.progress, this.pointer);
  final PictogramChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  TextPainter _glyph(IconData icon, double fs, Color color) => TextPainter(
      text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(fontSize: fs, fontFamily: icon.fontFamily, package: icon.fontPackage, color: color)),
      textDirection: TextDirection.ltr)
    ..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final items = w.items;
    if (items.isEmpty || w.unitValue <= 0) return;
    final fmt = w.valueFormat ?? formatNumber;
    final counts = [for (final i in items) (math.max(0.0, i.value) / w.unitValue).ceil()];
    final maxCount = counts.reduce(math.max);
    final labelW = items.map((i) => measureText(i.label, theme.labelStyle).width).fold<double>(0, math.max);
    final valueW = w.showValues ? items.map((i) => measureText(fmt(i.value), theme.labelStyle).width).fold<double>(0, math.max) + 10 : 0;
    final avail = size.width - labelW - 18 - valueW;
    if (avail <= 20 || maxCount == 0) return;
    final iconSize = math.min(w.rowHeight * .78, avail / maxCount - w.iconGap);
    if (iconSize < 5) return;
    int? hover;
    final ptr = pointer;
    if (ptr != null && ptr.dy >= 0 && ptr.dy <= items.length * w.rowHeight) {
      hover = (ptr.dy / w.rowHeight).floor().clamp(0, items.length - 1).toInt();
      canvas.drawRect(Rect.fromLTWH(0, hover * w.rowHeight, size.width, w.rowHeight), Paint()..color = theme.axisColor.faded(.1));
    }
    for (var r = 0; r < items.length; r++) {
      final it = items[r];
      final cy = (r + .5) * w.rowHeight;
      paintText(canvas, it.label, Offset(labelW, cy), theme.labelStyle.copyWith(color: theme.textColor), align: Alignment.centerRight);
      final color = it.color ?? theme.colorAt(r);
      final ic = it.icon ?? w.icon;
      final solid = _glyph(ic, iconSize, color), faded = _glyph(ic, iconSize, color.faded(.2));
      final x0 = labelW + 12;
      for (var k = 0; k < counts[r]; k++) {
        final t = (progress * maxCount - k).clamp(0.0, 1.0).toDouble();
        if (t <= 0) continue;
        final frac = (it.value / w.unitValue - k).clamp(0.0, 1.0).toDouble();
        final x = x0 + k * (iconSize + w.iconGap);
        final o = Offset(x + (iconSize - solid.width) / 2, cy - solid.height / 2);
        canvas.save();
        canvas.translate(x + iconSize / 2, cy);
        canvas.scale(t);
        canvas.translate(-(x + iconSize / 2), -cy);
        if (frac < 1) faded.paint(canvas, o);
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(o.dx, o.dy, solid.width * frac, solid.height));
        solid.paint(canvas, o);
        canvas.restore();
        canvas.restore();
      }
      if (w.showValues) {
        paintText(canvas, fmt(it.value * progress), Offset(size.width - 4, cy),
            theme.labelStyle.copyWith(color: theme.textColor, fontWeight: FontWeight.bold), align: Alignment.centerRight);
      }
    }
    if (hover != null && ptr != null && progress >= 1) {
      final it = items[hover];
      paintTooltip(canvas, size, ptr, theme, title: it.label, rows: [
        TooltipRow('${fmt(it.value)} = ${(it.value / w.unitValue).toStringAsFixed(1)} icons', color: it.color ?? theme.colorAt(hover)),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
