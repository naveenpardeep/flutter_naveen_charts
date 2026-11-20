import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_canvas.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';

/// One exclusive intersection: elements that belong to exactly [members].
class UpSetIntersection {
  const UpSetIntersection(this.members, this.size);
  final Set<int> members;
  final double size;
}

enum UpSetSort { size, degree }

/// UpSet plot: the scalable alternative to Venn diagrams for many sets.
/// Bars on top show intersection sizes, the dot matrix shows which sets are
/// involved and the left bars show set sizes.
class UpSetChart extends StatelessWidget {
  const UpSetChart({
    super.key,
    required this.setNames,
    required this.setSizes,
    required this.intersections,
    this.maxIntersections = 20,
    this.sortBy = UpSetSort.size,
    this.barColor,
    this.setBarColor,
    this.valueFormat,
    this.aspectRatio = 1.5,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  /// Builds the chart from raw elements; intersections are exclusive
  /// (an element counts once, in the exact combination of sets it belongs to).
  factory UpSetChart.fromSets({
    Key? key,
    required Map<String, Set<Object>> sets,
    int maxIntersections = 20,
    UpSetSort sortBy = UpSetSort.size,
    Color? barColor,
    Color? setBarColor,
    double aspectRatio = 1.5,
    ChartTheme? theme,
  }) {
    final names = sets.keys.toList()..sort((a, b) => sets[b]!.length.compareTo(sets[a]!.length));
    final all = <Object>{for (final s in sets.values) ...s};
    final counts = <int, int>{};
    for (final e in all) {
      var mask = 0;
      for (var i = 0; i < names.length; i++) {
        if (sets[names[i]]!.contains(e)) mask |= 1 << i;
      }
      counts[mask] = (counts[mask] ?? 0) + 1;
    }
    return UpSetChart(
      key: key,
      setNames: names,
      setSizes: [for (final n in names) sets[n]!.length.toDouble()],
      intersections: [
        for (final e in counts.entries)
          UpSetIntersection({for (var i = 0; i < names.length; i++) if (e.key & (1 << i) != 0) i}, e.value.toDouble())
      ],
      maxIntersections: maxIntersections,
      sortBy: sortBy,
      barColor: barColor,
      setBarColor: setBarColor,
      aspectRatio: aspectRatio,
      theme: theme,
    );
  }

  final List<String> setNames;
  final List<double> setSizes;
  final List<UpSetIntersection> intersections;
  final int maxIntersections;
  final UpSetSort sortBy;
  final Color? barColor, setBarColor;
  final String Function(double)? valueFormat;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    final list = [...intersections.where((i) => i.members.isNotEmpty && i.size > 0)];
    list.sort((a, b) {
      if (sortBy == UpSetSort.degree) {
        final c = a.members.length.compareTo(b.members.length);
        if (c != 0) return c;
      }
      return b.size.compareTo(a.size);
    });
    final shown = list.take(maxIntersections).toList();
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ChartCanvas(
        duration: animationDuration,
        builder: (p, ptr) => _UpSetPainter(this, shown, t, p, ptr),
      ),
    );
  }
}

class _UpSetPainter extends CustomPainter {
  _UpSetPainter(this.w, this.cols, this.theme, this.progress, this.pointer);
  final UpSetChart w;
  final List<UpSetIntersection> cols;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.setNames.length, m = cols.length;
    if (n == 0 || m == 0) return;
    final fmt = w.valueFormat ?? formatNumber;
    final nameW = w.setNames.map((s) => measureText(s, theme.labelStyle).width).fold<double>(0, math.max) + 8;
    final barsW = math.min(80.0, size.width * .2);
    final left = barsW + nameW + 8, right = size.width - 8;
    final topH = size.height * .44;
    final mTop = topH + 14, mBottom = size.height - 6;
    if (right - left < 30 || mBottom - mTop < n * 8) return;
    final colW = (right - left) / m, rowH = (mBottom - mTop) / n;
    final maxSize = cols.map((c) => c.size).reduce(math.max);
    final yScale = NiceScale.compute(0, maxSize, includeZero: true, maxTicks: 4);
    final barColor = w.barColor ?? theme.colorAt(0), setColor = w.setBarColor ?? theme.colorAt(0);
    final totalAll = cols.fold<double>(0, (a, c) => a + c.size);

    int? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1 && ptr.dx >= left && ptr.dx <= right && ptr.dy >= 0 && ptr.dy <= mBottom) {
      hover = ((ptr.dx - left) / colW).floor().clamp(0, m - 1).toInt();
      canvas.drawRect(Rect.fromLTRB(left + hover * colW, 0, left + (hover + 1) * colW, mBottom), Paint()..color = theme.axisColor.faded(.12));
    }

    // intersection bars
    final plotTop = 16.0, plotBottom = topH;
    double by(double v) => plotBottom - v / yScale.max * (plotBottom - plotTop);
    for (final t in yScale.ticks) {
      canvas.drawLine(Offset(left, by(t)), Offset(right, by(t)), Paint()
        ..color = theme.gridColor
        ..strokeWidth = 1);
      paintText(canvas, fmt(t), Offset(left - 4, by(t)), theme.labelStyle, align: Alignment.centerRight);
    }
    for (var c = 0; c < m; c++) {
      final x = left + (c + .5) * colW;
      final bw = colW * .62;
      final top = by(cols[c].size * progress);
      canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTRB(x - bw / 2, top, x + bw / 2, plotBottom), topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
          Paint()..color = hover == c ? Color.lerp(barColor, Colors.white, .2)! : barColor);
      if (progress > .99 && colW > 16) {
        paintText(canvas, fmt(cols[c].size), Offset(x, top - 2), theme.labelStyle, align: Alignment.bottomCenter);
      }
    }

    // matrix
    for (var r = 0; r < n; r++) {
      final cy = mTop + (r + .5) * rowH;
      if (r.isEven) canvas.drawRect(Rect.fromLTRB(barsW, mTop + r * rowH, right, mTop + (r + 1) * rowH), Paint()..color = theme.axisColor.faded(.07));
      paintText(canvas, w.setNames[r], Offset(barsW + nameW - 4, cy), theme.labelStyle.copyWith(color: theme.textColor), align: Alignment.centerRight);
      final sz = r < w.setSizes.length ? w.setSizes[r] : 0.0;
      final maxSet = w.setSizes.reduce(math.max);
      final len = maxSet <= 0 ? 0.0 : sz / maxSet * (barsW - 6) * progress;
      canvas.drawRect(Rect.fromLTRB(barsW - 4 - len, cy - rowH * .28, barsW - 4, cy + rowH * .28), Paint()..color = setColor.faded(.85));
    }
    final dot = math.min(colW, rowH) * .3;
    for (var c = 0; c < m; c++) {
      final x = left + (c + .5) * colW;
      final inSets = [for (var r = 0; r < n; r++) if (cols[c].members.contains(r)) r];
      for (var r = 0; r < n; r++) {
        final cy = mTop + (r + .5) * rowH;
        canvas.drawCircle(Offset(x, cy), dot, Paint()..color = cols[c].members.contains(r) ? theme.textColor : theme.gridColor);
      }
      if (inSets.length > 1) {
        canvas.drawLine(Offset(x, mTop + (inSets.first + .5) * rowH), Offset(x, mTop + (inSets.last + .5) * rowH), Paint()
          ..color = theme.textColor
          ..strokeWidth = dot * .6);
      }
    }
    if (hover != null && ptr != null) {
      final c = cols[hover];
      final names = [for (var r = 0; r < n; r++) if (c.members.contains(r)) w.setNames[r]];
      paintTooltip(canvas, size, ptr, theme, title: names.join(' ∩ '), rows: [
        TooltipRow('${fmt(c.size)} elements', color: barColor),
        TooltipRow('${(c.size / totalAll * 100).toStringAsFixed(1)}% of all'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
