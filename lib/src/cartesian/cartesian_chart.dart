import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_canvas.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/legend.dart';
import 'models.dart';

/// The general x/y chart. Mix any [LineSeries], [AreaSeries], [BarSeries]
/// and [ScatterSeries] in one chart (combo charts).
class CartesianChart extends StatelessWidget {
  const CartesianChart({
    super.key,
    required this.series,
    this.xLabels,
    this.barMode = BarMode.grouped,
    this.aspectRatio = 1.6,
    this.showLegend = true,
    this.showGrid = true,
    this.interactive = true,
    this.yFormat,
    this.yMin,
    this.yMax,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  final List<CartesianSeries> series;

  /// Category names for x = 0, 1, 2 ... (switches the x axis to categories).
  final List<String>? xLabels;
  final BarMode barMode;
  final double aspectRatio;
  final bool showLegend;
  final bool showGrid;
  final bool interactive;
  final String Function(double)? yFormat;
  final double? yMin;
  final double? yMax;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (showLegend && series.length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChartLegend(theme: t, items: [
            for (var i = 0; i < series.length; i++)
              LegendItem(series[i].name, series[i].color ?? t.colorAt(i)),
          ]),
        ),
      AspectRatio(
        aspectRatio: aspectRatio,
        child: ChartCanvas(
          duration: animationDuration,
          interactive: interactive,
          builder: (p, ptr) => _CartesianPainter(
            series: series,
            xLabels: xLabels,
            theme: t,
            progress: p,
            pointer: ptr,
            barMode: barMode,
            showGrid: showGrid,
            yFormat: yFormat,
            yMin: yMin,
            yMax: yMax,
          ),
        ),
      ),
    ]);
  }
}

class _CartesianPainter extends CustomPainter {
  _CartesianPainter({
    required this.series,
    required this.xLabels,
    required this.theme,
    required this.progress,
    required this.pointer,
    required this.barMode,
    required this.showGrid,
    this.yFormat,
    this.yMin,
    this.yMax,
  });

  final List<CartesianSeries> series;
  final List<String>? xLabels;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;
  final BarMode barMode;
  final bool showGrid;
  final String Function(double)? yFormat;
  final double? yMin;
  final double? yMax;

  Color _color(int i) => series[i].color ?? theme.colorAt(i);

  @override
  void paint(Canvas canvas, Size size) {
    if (series.every((s) => s.points.isEmpty)) return;
    final stacked = barMode == BarMode.stacked;
    final hasBars = series.any((s) => s is BarSeries);
    final hasFill = series.any((s) => s is LineSeries && s.fill);

    // ---- data domain
    double xLo = double.infinity, xHi = -double.infinity;
    double yLo = double.infinity, yHi = -double.infinity;
    final posSum = <double, double>{};
    final negSum = <double, double>{};
    for (final s in series) {
      for (final p in s.points) {
        xLo = math.min(xLo, p.x);
        xHi = math.max(xHi, p.x);
        if (s is BarSeries && stacked) {
          if (p.y >= 0) {
            posSum[p.x] = (posSum[p.x] ?? 0) + p.y;
          } else {
            negSum[p.x] = (negSum[p.x] ?? 0) + p.y;
          }
        } else {
          yLo = math.min(yLo, p.y);
          yHi = math.max(yHi, p.y);
        }
      }
    }
    for (final v in posSum.values) {
      yHi = math.max(yHi, v);
    }
    for (final v in negSum.values) {
      yLo = math.min(yLo, v);
    }
    if (xLabels != null) {
      xLo = -0.5;
      xHi = xLabels!.length - 0.5;
    } else if (hasBars) {
      xLo -= 0.5;
      xHi += 0.5;
    } else if (xLo == xHi) {
      xLo -= 1;
      xHi += 1;
    }
    final scale = NiceScale.compute(yMin ?? yLo, yMax ?? yHi,
        includeZero: yMin == null && (hasBars || hasFill));

    // ---- layout
    final fmt = yFormat ?? formatNumber;
    final yTicks = scale.ticks;
    final yLabelW = yTicks
        .map((t) => measureText(fmt(t), theme.labelStyle).width)
        .fold<double>(0, math.max);
    final plot =
        Rect.fromLTRB(yLabelW + 12, 10, size.width - 12, size.height - 28);
    if (plot.width <= 0 || plot.height <= 0) return;
    double sx(double x) => plot.left + (x - xLo) / (xHi - xLo) * plot.width;
    double sy(double y) =>
        plot.bottom - (y - scale.min) / (scale.max - scale.min) * plot.height;

    // ---- grid & axes
    final gridPaint = Paint()
      ..color = theme.gridColor
      ..strokeWidth = 1;
    for (final t in yTicks) {
      final y = sy(t);
      if (showGrid) {
        canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      }
      paintText(canvas, fmt(t), Offset(plot.left - 6, y), theme.labelStyle,
          align: Alignment.centerRight);
    }
    final zeroY = sy(0).clamp(plot.top, plot.bottom).toDouble();
    canvas.drawLine(
        Offset(plot.left, zeroY),
        Offset(plot.right, zeroY),
        Paint()
          ..color = theme.axisColor
          ..strokeWidth = 1.2);

    if (xLabels != null) {
      final n = xLabels!.length;
      final maxW = xLabels!
          .map((l) => measureText(l, theme.labelStyle).width)
          .fold<double>(0, math.max);
      final unit = plot.width / n;
      final every = math.max(1, ((maxW + 8) / unit).ceil());
      for (var i = 0; i < n; i += every) {
        paintText(canvas, xLabels![i], Offset(sx(i.toDouble()), plot.bottom + 6),
            theme.labelStyle,
            align: Alignment.topCenter, maxWidth: unit * every);
      }
    } else {
      for (final t in NiceScale.compute(xLo, xHi, maxTicks: 6).ticks) {
        if (t < xLo - 1e-9 || t > xHi + 1e-9) continue;
        paintText(canvas, formatNumber(t), Offset(sx(t), plot.bottom + 6),
            theme.labelStyle,
            align: Alignment.topCenter);
      }
    }

    // ---- bars
    final bars = [
      for (var i = 0; i < series.length; i++)
        if (series[i] is BarSeries) i
    ];
    if (bars.isNotEmpty) {
      canvas.save();
      canvas.clipRect(plot.inflate(1));
      final unit = plot.width / (xHi - xLo);
      final groupW = unit * 0.72;
      final pos = <double, double>{};
      final neg = <double, double>{};
      for (var j = 0; j < bars.length; j++) {
        final si = bars[j];
        final paint = Paint()..color = _color(si);
        for (final p in series[si].points) {
          double y0, y1, left, width;
          if (stacked) {
            width = groupW;
            left = sx(p.x) - groupW / 2;
            if (p.y >= 0) {
              y0 = pos[p.x] ?? 0;
              y1 = y0 + p.y;
              pos[p.x] = y1;
            } else {
              y0 = neg[p.x] ?? 0;
              y1 = y0 + p.y;
              neg[p.x] = y1;
            }
          } else {
            width = groupW / bars.length;
            left = sx(p.x) - groupW / 2 + j * width;
            y0 = 0;
            y1 = p.y;
          }
          final a = sy(y0), b = sy(y0 + (y1 - y0) * progress);
          final rect = Rect.fromLTRB(
              left + 1, math.min(a, b), left + width - 1, math.max(a, b));
          final rad =
              stacked ? Radius.zero : Radius.circular(math.min(4.0, width / 2));
          final up = p.y >= 0;
          canvas.drawRRect(
              RRect.fromRectAndCorners(rect,
                  topLeft: up ? rad : Radius.zero,
                  topRight: up ? rad : Radius.zero,
                  bottomLeft: up ? Radius.zero : rad,
                  bottomRight: up ? Radius.zero : rad),
              paint);
        }
      }
      canvas.restore();
    }

    // ---- lines & areas
    final lineIdx = [
      for (var i = 0; i < series.length; i++)
        if (series[i] is LineSeries) i
    ];
    if (lineIdx.isNotEmpty) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(plot.left - 8, plot.top - 8,
          plot.left - 8 + (plot.width + 16) * progress, plot.bottom + 8));
      for (final si in lineIdx) {
        final s = series[si] as LineSeries;
        final color = _color(si);
        final pts = [...s.points]..sort((a, b) => a.x.compareTo(b.x));
        if (pts.isEmpty) continue;
        final o = [for (final p in pts) Offset(sx(p.x), sy(p.y))];
        final path = _buildPath(o, s.curved, s.stepped);
        if (s.fill) {
          final base = sy(0).clamp(plot.top, plot.bottom).toDouble();
          final area = Path.from(path)
            ..lineTo(o.last.dx, base)
            ..lineTo(o.first.dx, base)
            ..close();
          canvas.drawPath(
              area,
              Paint()
                ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.faded(.35), color.faded(.02)],
                ).createShader(plot));
        }
        canvas.drawPath(
            s.dashed ? dashPath(path) : path,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = s.strokeWidth
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round);
        if (s.showMarkers) {
          for (final pt in o) {
            canvas.drawCircle(pt, 4, Paint()..color = color);
            canvas.drawCircle(pt, 2, Paint()..color = theme.surface);
          }
        }
      }
      canvas.restore();
    }

    // ---- scatter / bubble
    for (var si = 0; si < series.length; si++) {
      final s = series[si];
      if (s is! ScatterSeries) continue;
      final color = _color(si);
      final maxSize =
          s.points.fold<double>(0, (m, p) => math.max(m, p.size ?? 0));
      for (final p in s.points) {
        final r = (p.size != null && maxSize > 0)
            ? 6 + 20 * math.sqrt(p.size! / maxSize)
            : s.markerSize;
        final c = Offset(sx(p.x), sy(p.y));
        canvas.drawCircle(
            c, r * progress, Paint()..color = color.faded(p.size != null ? .55 : .85));
        if (p.size != null) {
          canvas.drawCircle(
              c,
              r * progress,
              Paint()
                ..color = color
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5);
        }
      }
    }

    // ---- tooltip
    final ptr = pointer;
    if (ptr != null && progress >= 1 && plot.inflate(10).contains(ptr)) {
      _tooltip(canvas, size, plot, ptr, sx, sy, fmt);
    }
  }

  Path _buildPath(List<Offset> o, bool curved, bool stepped) {
    final p = Path()..moveTo(o.first.dx, o.first.dy);
    if (stepped) {
      for (var i = 1; i < o.length; i++) {
        p.lineTo(o[i].dx, o[i - 1].dy);
        p.lineTo(o[i].dx, o[i].dy);
      }
    } else if (curved && o.length > 2) {
      for (var i = 0; i < o.length - 1; i++) {
        final p0 = o[math.max(i - 1, 0)];
        final p1 = o[i];
        final p2 = o[i + 1];
        final p3 = o[math.min(i + 2, o.length - 1)];
        final c1 = p1 + (p2 - p0) / 6;
        final c2 = p2 - (p3 - p1) / 6;
        p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
      }
    } else {
      for (var i = 1; i < o.length; i++) {
        p.lineTo(o[i].dx, o[i].dy);
      }
    }
    return p;
  }

  void _tooltip(Canvas canvas, Size size, Rect plot, Offset ptr,
      double Function(double) sx, double Function(double) sy,
      String Function(double) fmt) {
    final cart = [
      for (var i = 0; i < series.length; i++)
        if (series[i] is! ScatterSeries) i
    ];
    if (cart.isNotEmpty) {
      final xs = <double>{
        for (final i in cart) for (final p in series[i].points) p.x
      };
      double? best;
      for (final x in xs) {
        if (best == null || (sx(x) - ptr.dx).abs() < (sx(best) - ptr.dx).abs()) {
          best = x;
        }
      }
      if (best == null) return;
      final bx = best;
      canvas.drawLine(
          Offset(sx(bx), plot.top),
          Offset(sx(bx), plot.bottom),
          Paint()
            ..color = theme.axisColor.faded(.6)
            ..strokeWidth = 1);
      final rows = <TooltipRow>[];
      for (final i in cart) {
        final s = series[i];
        for (final p in s.points) {
          if (p.x != bx) continue;
          rows.add(TooltipRow('${s.name}: ${fmt(p.y)}', color: _color(i)));
          if (s is LineSeries) {
            canvas.drawCircle(Offset(sx(bx), sy(p.y)), 5.5, Paint()..color = _color(i));
            canvas.drawCircle(Offset(sx(bx), sy(p.y)), 2.5, Paint()..color = theme.surface);
          }
          break;
        }
      }
      final idx = bx.round();
      final title = (xLabels != null && idx >= 0 && idx < xLabels!.length)
          ? xLabels![idx]
          : formatNumber(bx);
      paintTooltip(canvas, size, Offset(sx(bx), ptr.dy), theme,
          title: title, rows: rows);
      return;
    }
    // scatter-only: nearest point
    double bestD = 30;
    int? bi;
    DataPoint? bp;
    for (var i = 0; i < series.length; i++) {
      for (final p in series[i].points) {
        final d = (Offset(sx(p.x), sy(p.y)) - ptr).distance;
        if (d < bestD) {
          bestD = d;
          bi = i;
          bp = p;
        }
      }
    }
    if (bp == null || bi == null) return;
    final c = Offset(sx(bp.x), sy(bp.y));
    canvas.drawCircle(
        c,
        9,
        Paint()
          ..color = _color(bi)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    final extra = bp.size == null ? '' : '  size ${formatNumber(bp.size!)}';
    paintTooltip(canvas, size, c, theme, title: series[bi].name, rows: [
      TooltipRow('(${formatNumber(bp.x)}, ${fmt(bp.y)})$extra', color: _color(bi))
    ]);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
