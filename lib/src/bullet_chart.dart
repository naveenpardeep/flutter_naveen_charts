import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'core/chart_canvas.dart';
import 'core/chart_theme.dart';
import 'core/chart_utils.dart';

/// One KPI: [value] vs [target] over qualitative [ranges] (ascending ends,
/// e.g. [60, 80, 100] for poor / ok / good).
class BulletItem {
  const BulletItem(this.label,
      {required this.value, required this.target, required this.ranges, this.color});
  final String label;
  final double value;
  final double target;
  final List<double> ranges;
  final Color? color;
}

class BulletChart extends StatelessWidget {
  const BulletChart({
    super.key,
    required this.items,
    this.rowHeight = 52,
    this.valueFormat,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<BulletItem> items;
  final double rowHeight;
  final String Function(double)? valueFormat;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return SizedBox(
      height: items.length * rowHeight + 28,
      child: ChartCanvas(
        duration: animationDuration,
        builder: (p, ptr) => _BulletPainter(this, t, p, ptr),
      ),
    );
  }
}

class _BulletPainter extends CustomPainter {
  _BulletPainter(this.w, this.theme, this.progress, this.pointer);
  final BulletChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final items = w.items;
    if (items.isEmpty) return;
    var maxV = 0.0;
    for (final it in items) {
      maxV = math.max(maxV, math.max(it.value, it.target));
      if (it.ranges.isNotEmpty) maxV = math.max(maxV, it.ranges.last);
    }
    final scale = NiceScale.compute(0, maxV);
    final fmt = w.valueFormat ?? formatNumber;
    final labelW = items
        .map((i) => measureText(i.label, theme.labelStyle).width)
        .fold<double>(0, math.max);
    final plot = Rect.fromLTRB(labelW + 14, 4, size.width - 46, size.height - 22);
    if (plot.width <= 0) return;
    double sx(double v) => plot.left + v / scale.max * plot.width;
    final rowH = plot.height / items.length;

    for (final t in scale.ticks) {
      paintText(canvas, fmt(t), Offset(sx(t), plot.bottom + 6), theme.labelStyle,
          align: Alignment.topCenter);
    }
    int? hover;
    final ptr = pointer;
    if (ptr != null && plot.inflate(40).contains(ptr)) {
      hover = ((ptr.dy - plot.top) / rowH).floor().clamp(0, items.length - 1).toInt();
    }
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final cy = plot.top + (i + .5) * rowH;
      paintText(canvas, it.label, Offset(plot.left - 8, cy),
          theme.labelStyle.copyWith(color: theme.textColor),
          align: Alignment.centerRight, maxWidth: labelW + 2);
      final bandH = rowH * 0.6;
      final r = it.ranges;
      for (var k = r.length - 1; k >= 0; k--) {
        canvas.drawRect(
            Rect.fromLTRB(sx(0), cy - bandH / 2, sx(r[k]), cy + bandH / 2),
            Paint()..color = theme.textColor.faded(.07 + .08 * (r.length - 1 - k)));
      }
      final barH = rowH * 0.22;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(sx(0), cy - barH / 2, sx(it.value * progress), cy + barH / 2),
              const Radius.circular(2)),
          Paint()..color = it.color ?? theme.colorAt(0));
      final tx = sx(it.target);
      canvas.drawLine(Offset(tx, cy - rowH * .24), Offset(tx, cy + rowH * .24),
          Paint()
            ..color = theme.textColor
            ..strokeWidth = 3);
      paintText(canvas, fmt(it.value * progress), Offset(plot.right + 6, cy),
          theme.labelStyle.copyWith(color: theme.textColor, fontWeight: FontWeight.bold),
          align: Alignment.centerLeft);
    }
    if (hover != null && ptr != null && progress >= 1) {
      final it = items[hover];
      paintTooltip(canvas, size, ptr, theme, title: it.label, rows: [
        TooltipRow('Value: ${fmt(it.value)}', color: it.color ?? theme.colorAt(0)),
        TooltipRow('Target: ${fmt(it.target)}'),
        TooltipRow('${(it.value / it.target * 100).round()}% of target'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
