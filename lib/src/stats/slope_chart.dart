import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/plot_frame.dart';

class SlopeItem {
  const SlopeItem(this.label, this.left, this.right, {this.color});
  final String label;
  final double left, right;
  final Color? color;
}

/// Slope chart: how each item moves between two points in time or states.
class SlopeChart extends StatelessWidget {
  const SlopeChart({
    super.key,
    required this.items,
    this.leftTitle = 'Before',
    this.rightTitle = 'After',
    this.colorByDirection = true,
    this.upColor = const Color(0xFF43A047),
    this.downColor = const Color(0xFFE53935),
    this.flatColor = const Color(0xFF9E9E9E),
    this.valueFormat,
    this.aspectRatio = 0.9,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<SlopeItem> items;
  final String leftTitle, rightTitle;

  /// Green when rising, red when falling (otherwise palette colours).
  final bool colorByDirection;
  final Color upColor, downColor, flatColor;
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
        builder: (p, ptr) => _SlopePainter(this, t, p, ptr));
  }
}

List<double> spreadLabels(List<double> ys, double gap, double hi) {
  final idx = List<int>.generate(ys.length, (i) => i)..sort((a, b) => ys[a].compareTo(ys[b]));
  final out = List<double>.of(ys);
  for (var k = 1; k < idx.length; k++) {
    if (out[idx[k]] - out[idx[k - 1]] < gap) out[idx[k]] = out[idx[k - 1]] + gap;
  }
  if (idx.isNotEmpty && out[idx.last] > hi) {
    final shift = out[idx.last] - hi;
    for (final i in idx) {
      out[i] -= shift;
    }
  }
  return out;
}

class _SlopePainter extends CustomPainter {
  _SlopePainter(this.w, this.theme, this.progress, this.pointer);
  final SlopeChart w;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final items = w.items;
    if (items.isEmpty) return;
    final fmt = w.valueFormat ?? formatNumber;
    final lt = [for (final i in items) '${i.label}  ${fmt(i.left)}'];
    final rt = [for (final i in items) '${fmt(i.right)}  ${i.label}'];
    double maxW(List<String> l) => l.map((s) => measureText(s, theme.labelStyle).width).fold<double>(0, math.max);
    final xL = maxW(lt) + 18, xR = size.width - maxW(rt) - 18;
    if (xR - xL < 40) return;
    var lo = double.infinity, hi = -double.infinity;
    for (final i in items) {
      lo = math.min(lo, math.min(i.left, i.right));
      hi = math.max(hi, math.max(i.left, i.right));
    }
    if (hi == lo) hi = lo + 1;
    final top = 34.0, bottom = size.height - 14;
    double sy(double v) => bottom - (v - lo) / (hi - lo) * (bottom - top);
    final labelL = spreadLabels([for (final i in items) sy(i.left)], 14, bottom);
    final labelR = spreadLabels([for (final i in items) sy(i.right)], 14, bottom);
    final ts = theme.labelStyle.copyWith(color: theme.textColor, fontWeight: FontWeight.w700);
    paintText(canvas, w.leftTitle, Offset(xL, 8), ts, align: Alignment.topCenter);
    paintText(canvas, w.rightTitle, Offset(xR, 8), ts, align: Alignment.topCenter);
    final axis = Paint()
      ..color = theme.gridColor
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(xL, top - 8), Offset(xL, bottom + 4), axis);
    canvas.drawLine(Offset(xR, top - 8), Offset(xR, bottom + 4), axis);

    int? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      var best = 12.0;
      for (var i = 0; i < items.length; i++) {
        final d = distToSegment(ptr, Offset(xL, sy(items[i].left)), Offset(xR, sy(items[i].right)));
        if (d < best) {
          best = d;
          hover = i;
        }
      }
    }
    Color colorOf(int i) {
      final it = items[i];
      if (it.color != null) return it.color!;
      if (!w.colorByDirection) return theme.colorAt(i);
      return it.right > it.left ? w.upColor : (it.right < it.left ? w.downColor : w.flatColor);
    }

    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final c = colorOf(i);
      final dim = hover != null && hover != i;
      final a = Offset(xL, sy(it.left));
      final b = Offset(xL + (xR - xL) * progress, sy(it.left) + (sy(it.right) - sy(it.left)) * progress);
      canvas.drawLine(a, b, Paint()
        ..color = c.faded(dim ? .2 : 1)
        ..strokeWidth = hover == i ? 3.5 : 2.2
        ..strokeCap = StrokeCap.round);
      canvas.drawCircle(a, 4, Paint()..color = c.faded(dim ? .2 : 1));
      canvas.drawCircle(b, 4, Paint()..color = c.faded(dim ? .2 : 1));
      final ls = theme.labelStyle.copyWith(color: theme.textColor.faded(dim ? .3 : 1));
      paintText(canvas, lt[i], Offset(xL - 8, labelL[i]), ls, align: Alignment.centerRight);
      if (progress > .99) paintText(canvas, rt[i], Offset(xR + 8, labelR[i]), ls, align: Alignment.centerLeft);
    }
    if (hover != null && ptr != null) {
      final it = items[hover];
      final d = it.right - it.left;
      paintTooltip(canvas, size, ptr, theme, title: it.label, rows: [
        TooltipRow('${w.leftTitle}: ${fmt(it.left)}', color: colorOf(hover)),
        TooltipRow('${w.rightTitle}: ${fmt(it.right)}'),
        TooltipRow('Change: ${d >= 0 ? '+' : ''}${fmt(d)}'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
