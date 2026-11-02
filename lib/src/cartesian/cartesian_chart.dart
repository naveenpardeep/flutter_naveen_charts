import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../core/chart_canvas.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/legend.dart';
import 'models.dart';

/// The general x/y chart. Mix any [LineSeries], [AreaSeries], [BarSeries]
/// and [ScatterSeries]; put series on a second y axis with
/// `secondaryAxis: true`; enable zoom/pan with `options.zoomable`.
class CartesianChart extends StatefulWidget {
  const CartesianChart({
    super.key,
    required this.series,
    this.xLabels,
    this.barMode = BarMode.grouped,
    this.options = const CartesianOptions(),
    this.aspectRatio = 1.6,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  final List<CartesianSeries> series;

  /// Category names for x = 0, 1, 2 ... (switches the x axis to categories).
  final List<String>? xLabels;
  final BarMode barMode;
  final CartesianOptions options;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  State<CartesianChart> createState() => _CartesianChartState();
}

class _CartesianChartState extends State<CartesianChart> {
  double _start = 0, _span = 1, _s0 = 1, _anchor = 0;

  void _setView(double start, double span) {
    final sp = span.clamp(1 / widget.options.maxZoom, 1.0).toDouble();
    final st = start.clamp(0.0, 1 - sp).toDouble();
    setState(() {
      _start = st;
      _span = sp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.options;
    final t = widget.theme ?? ChartTheme.of(context);
    final canvas = ChartCanvas(
      duration: widget.animationDuration,
      interactive: o.interactive,
      builder: (p, ptr) => _CartesianPainter(
        series: widget.series,
        xLabels: widget.xLabels,
        theme: t,
        progress: p,
        pointer: ptr,
        barMode: widget.barMode,
        o: o,
        viewStart: _start,
        viewSpan: _span,
      ),
    );
    Widget body = canvas;
    if (o.zoomable) {
      body = LayoutBuilder(builder: (context, c) {
        final w = math.max(1.0, c.maxWidth);
        return Listener(
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) {
              final f = e.scrollDelta.dy > 0 ? 1.15 : 1 / 1.15;
              final fx = e.localPosition.dx / w;
              final anchor = _start + fx * _span;
              final span =
                  (_span * f).clamp(1 / o.maxZoom, 1.0).toDouble();
              _setView(anchor - fx * span, span);
            }
          },
          child: GestureDetector(
            onDoubleTap: () => _setView(0, 1),
            onScaleStart: (d) {
              _s0 = _span;
              _anchor = _start + d.localFocalPoint.dx / w * _span;
            },
            onScaleUpdate: (d) {
              final span =
                  (_s0 / d.scale).clamp(1 / o.maxZoom, 1.0).toDouble();
              _setView(_anchor - d.localFocalPoint.dx / w * span, span);
            },
            child: canvas,
          ),
        );
      });
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (o.title != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(o.title!, style: Theme.of(context).textTheme.titleSmall),
        ),
      if (o.showLegend && widget.series.length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChartLegend(theme: t, items: [
            for (var i = 0; i < widget.series.length; i++)
              LegendItem(
                  widget.series[i].name +
                      (widget.series[i].secondaryAxis &&
                              widget.series[i] is! BarSeries
                          ? ' (right)'
                          : ''),
                  widget.series[i].color ?? t.colorAt(i)),
          ]),
        ),
      AspectRatio(aspectRatio: widget.aspectRatio, child: body),
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
    required this.o,
    required this.viewStart,
    required this.viewSpan,
  });

  final List<CartesianSeries> series;
  final List<String>? xLabels;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;
  final BarMode barMode;
  final CartesianOptions o;
  final double viewStart, viewSpan;

  Color _color(int i) => series[i].color ?? theme.colorAt(i);
  bool _isSec(CartesianSeries s) =>
      s.secondaryAxis && s is! BarSeries && s.points.isNotEmpty;

  void _line(Canvas c, Offset a, Offset b, Paint p, bool dashed) {
    if (dashed) {
      c.drawPath(dashPath(Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy), dash: 3, gap: 3), p..style = PaintingStyle.stroke);
    } else {
      c.drawLine(a, b, p);
    }
  }

  void _rotText(Canvas c, String t, Offset at, double angle, TextStyle s) {
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(angle);
    paintText(c, t, Offset.zero, s);
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (series.every((s) => s.points.isEmpty)) return;
    final stacked = barMode == BarMode.stacked;
    final hasBars = series.any((s) => s is BarSeries);
    final hasFill = series.any((s) => s is LineSeries && s.fill && !_isSec(s));
    final hasFill2 = series.any((s) => s is LineSeries && s.fill && _isSec(s));
    final hasSec = series.any(_isSec);

    // ---- data domain
    double xLo = double.infinity, xHi = -double.infinity;
    final yLo = [double.infinity, double.infinity];
    final yHi = [-double.infinity, -double.infinity];
    final posSum = <double, double>{};
    final negSum = <double, double>{};
    for (final s in series) {
      final k = _isSec(s) ? 1 : 0;
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
          yLo[k] = math.min(yLo[k], p.y);
          yHi[k] = math.max(yHi[k], p.y);
        }
      }
    }
    for (final v in posSum.values) {
      yHi[0] = math.max(yHi[0], v);
    }
    for (final v in negSum.values) {
      yLo[0] = math.min(yLo[0], v);
    }
    for (var k = 0; k < 2; k++) {
      if (!yLo[k].isFinite) yLo[k] = yHi[k].isFinite ? yHi[k] : 0;
      if (!yHi[k].isFinite) yHi[k] = yLo[k];
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
    final s1 = NiceScale.compute(o.yMin ?? yLo[0], o.yMax ?? yHi[0],
        includeZero: o.yMin == null && (hasBars || hasFill));
    final s2 = hasSec
        ? NiceScale.compute(o.secondaryYMin ?? yLo[1], o.secondaryYMax ?? yHi[1],
            includeZero: o.secondaryYMin == null && hasFill2)
        : null;

    // ---- layout
    final f1 = o.yFormat ?? formatNumber;
    final f2 = o.secondaryYFormat ?? formatNumber;
    double labelW(NiceScale s, String Function(double) f) => s.ticks
        .map((t) => measureText(f(t), theme.labelStyle).width)
        .fold<double>(0, math.max);
    final leftPad = labelW(s1, f1) + 12 + (o.yAxisTitle != null ? 16 : 0);
    final rightPad = 12 +
        (s2 != null
            ? labelW(s2, f2) + 8 + (o.secondaryAxisTitle != null ? 16 : 0)
            : 0);
    final bottomPad = 28 + (o.xAxisTitle != null ? 16 : 0);
    final plot = Rect.fromLTRB(
        leftPad, 10, size.width - rightPad, size.height - bottomPad);
    if (plot.width <= 0 || plot.height <= 0) return;

    final full = xHi - xLo;
    final vLo = xLo + viewStart * full;
    final vHi = vLo + viewSpan * full;
    double sx(double x) => plot.left + (x - vLo) / (vHi - vLo) * plot.width;
    double sy1(double y) =>
        plot.bottom - (y - s1.min) / (s1.max - s1.min) * plot.height;
    double sy2(double y) => s2 == null
        ? sy1(y)
        : plot.bottom - (y - s2.min) / (s2.max - s2.min) * plot.height;
    double Function(double) syOf(CartesianSeries s) => _isSec(s) ? sy2 : sy1;

    // ---- horizontal grid & y labels
    final gridPaint = Paint()
      ..color = theme.gridColor
      ..strokeWidth = 1;
    final hGrid = o.gridMode == GridMode.horizontal || o.gridMode == GridMode.both;
    final vGrid = o.gridMode == GridMode.vertical || o.gridMode == GridMode.both;
    for (final t in s1.ticks) {
      final y = sy1(t);
      if (hGrid) _line(canvas, Offset(plot.left, y), Offset(plot.right, y), gridPaint, o.dashedGrid);
      paintText(canvas, f1(t), Offset(plot.left - 6, y), theme.labelStyle,
          align: Alignment.centerRight);
    }
    if (s2 != null) {
      final c2 = series.indexWhere(_isSec);
      final style = theme.labelStyle.copyWith(color: _color(c2));
      for (final t in s2.ticks) {
        paintText(canvas, f2(t), Offset(plot.right + 6, sy2(t)), style,
            align: Alignment.centerLeft);
      }
      canvas.drawLine(Offset(plot.right, plot.top), Offset(plot.right, plot.bottom),
          Paint()
            ..color = _color(c2).faded(.6)
            ..strokeWidth = 1.2);
    }
    final zeroY = sy1(0).clamp(plot.top, plot.bottom).toDouble();
    canvas.drawLine(Offset(plot.left, zeroY), Offset(plot.right, zeroY),
        Paint()
          ..color = theme.axisColor
          ..strokeWidth = 1.2);

    // ---- x labels (+ vertical grid)
    final xTicks = <MapEntry<double, String>>[];
    if (xLabels != null) {
      final n = xLabels!.length;
      final first = math.max(0, (vLo - 1e-9).ceil());
      final last = math.min(n - 1, (vHi + 1e-9).floor());
      final maxW = xLabels!
          .map((l) => measureText(l, theme.labelStyle).width)
          .fold<double>(0, math.max);
      final unit = plot.width / (vHi - vLo);
      final every = math.max(1, ((maxW + 8) / unit).ceil());
      for (var i = (first / every).ceil() * every; i <= last; i += every) {
        xTicks.add(MapEntry(i.toDouble(), xLabels![i]));
      }
    } else {
      final xf = o.xFormat ?? formatNumber;
      for (final t in NiceScale.compute(vLo, vHi, maxTicks: 6).ticks) {
        if (t >= vLo - 1e-9 && t <= vHi + 1e-9) xTicks.add(MapEntry(t, xf(t)));
      }
    }
    for (final e in xTicks) {
      if (vGrid) {
        _line(canvas, Offset(sx(e.key), plot.top), Offset(sx(e.key), plot.bottom), gridPaint, o.dashedGrid);
      }
      paintText(canvas, e.value, Offset(sx(e.key), plot.bottom + 6),
          theme.labelStyle,
          align: Alignment.topCenter);
    }

    // ---- axis titles
    final titleStyle = theme.labelStyle
        .copyWith(color: theme.textColor, fontWeight: FontWeight.w600);
    if (o.xAxisTitle != null) {
      paintText(canvas, o.xAxisTitle!, Offset(plot.center.dx, size.height - 2),
          titleStyle, align: Alignment.bottomCenter);
    }
    if (o.yAxisTitle != null) {
      _rotText(canvas, o.yAxisTitle!, Offset(8, plot.center.dy), -math.pi / 2, titleStyle);
    }
    if (o.secondaryAxisTitle != null && s2 != null) {
      _rotText(canvas, o.secondaryAxisTitle!, Offset(size.width - 8, plot.center.dy), math.pi / 2, titleStyle);
    }

    // ---- reference lines
    for (final r in o.referenceLines) {
      final y = sy1(r.value);
      if (y < plot.top || y > plot.bottom) continue;
      final c = r.color ?? theme.colorAt(2);
      _line(canvas, Offset(plot.left, y), Offset(plot.right, y),
          Paint()
            ..color = c
            ..strokeWidth = 1.5,
          r.dashed);
      if (r.label != null) {
        paintText(canvas, r.label!, Offset(plot.right - 4, y - 2),
            theme.labelStyle.copyWith(color: c, fontWeight: FontWeight.w600),
            align: Alignment.bottomRight);
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
      final unit = plot.width / (vHi - vLo);
      final groupW = unit * o.barWidthFactor;
      final pos = <double, double>{};
      final neg = <double, double>{};
      for (var j = 0; j < bars.length; j++) {
        final si = bars[j];
        final bs = series[si] as BarSeries;
        final paint = Paint()..color = _color(si);
        for (final p in bs.points) {
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
          if (left + width < plot.left || left > plot.right) continue;
          final a = sy1(y0), b = sy1(y0 + (y1 - y0) * progress);
          final rect = Rect.fromLTRB(
              left + 1, math.min(a, b), left + width - 1, math.max(a, b));
          final rad = stacked
              ? Radius.zero
              : Radius.circular(math.min(bs.cornerRadius, width / 2));
          final up = p.y >= 0;
          canvas.drawRRect(
              RRect.fromRectAndCorners(rect,
                  topLeft: up ? rad : Radius.zero,
                  topRight: up ? rad : Radius.zero,
                  bottomLeft: up ? Radius.zero : rad,
                  bottomRight: up ? Radius.zero : rad),
              paint);
          if (o.showValueLabels && progress > .99) {
            if (stacked) {
              if (rect.height > 14 && rect.width > 22) {
                paintText(canvas, f1(p.y), rect.center,
                    TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: contrastOn(_color(si))));
              }
            } else {
              paintText(canvas, f1(p.y),
                  Offset(rect.center.dx, up ? rect.top - 2 : rect.bottom + 2),
                  theme.labelStyle,
                  align: up ? Alignment.bottomCenter : Alignment.topCenter);
            }
          }
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
        final syS = syOf(s);
        final color = _color(si);
        final pts = [...s.points]..sort((a, b) => a.x.compareTo(b.x));
        if (pts.isEmpty) continue;
        final off = [for (final p in pts) Offset(sx(p.x), syS(p.y))];
        final path = buildLinePath(off, curved: s.curved, stepped: s.stepped);
        if (s.fill) {
          final base = syS(0).clamp(plot.top, plot.bottom).toDouble();
          final area = Path.from(path)
            ..lineTo(off.last.dx, base)
            ..lineTo(off.first.dx, base)
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
          for (final pt in off) {
            if (pt.dx < plot.left - 8 || pt.dx > plot.right + 8) continue;
            canvas.drawCircle(pt, s.markerRadius, Paint()..color = color);
            canvas.drawCircle(pt, s.markerRadius / 2, Paint()..color = theme.surface);
          }
        }
      }
      canvas.restore();
    }

    // ---- scatter / bubble
    canvas.save();
    canvas.clipRect(plot.inflate(30));
    for (var si = 0; si < series.length; si++) {
      final s = series[si];
      if (s is! ScatterSeries) continue;
      final syS = syOf(s);
      final color = _color(si);
      final maxSize =
          s.points.fold<double>(0, (m, p) => math.max(m, p.size ?? 0));
      for (final p in s.points) {
        final r = (p.size != null && maxSize > 0)
            ? 6 + (s.maxBubbleRadius - 6) * math.sqrt(p.size! / maxSize)
            : s.markerSize;
        final c = Offset(sx(p.x), syS(p.y));
        if (c.dx < plot.left - r || c.dx > plot.right + r) continue;
        canvas.drawCircle(c, r * progress,
            Paint()..color = color.faded(p.size != null ? .55 : .85));
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
    canvas.restore();

    // ---- tooltip
    final ptr = pointer;
    if (ptr != null && progress >= 1 && plot.inflate(10).contains(ptr)) {
      _tooltip(canvas, size, plot, ptr, sx, syOf, f1, f2);
    }
  }

  void _tooltip(
      Canvas canvas,
      Size size,
      Rect plot,
      Offset ptr,
      double Function(double) sx,
      double Function(double) Function(CartesianSeries) syOf,
      String Function(double) f1,
      String Function(double) f2) {
    String fmtFor(CartesianSeries s, double v) => _isSec(s) ? f2(v) : f1(v);
    final cart = [
      for (var i = 0; i < series.length; i++)
        if (series[i] is! ScatterSeries) i
    ];
    if (cart.isNotEmpty) {
      final xs = <double>{
        for (final i in cart)
          for (final p in series[i].points)
            if (sx(p.x) >= plot.left - 1 && sx(p.x) <= plot.right + 1) p.x
      };
      double? best;
      for (final x in xs) {
        if (best == null || (sx(x) - ptr.dx).abs() < (sx(best) - ptr.dx).abs()) {
          best = x;
        }
      }
      if (best != null) {
        final bx = best;
        canvas.drawLine(Offset(sx(bx), plot.top), Offset(sx(bx), plot.bottom),
            Paint()
              ..color = theme.axisColor.faded(.6)
              ..strokeWidth = 1);
        final rows = <TooltipRow>[];
        for (final i in cart) {
          final s = series[i];
          for (final p in s.points) {
            if (p.x != bx) continue;
            rows.add(TooltipRow('${s.name}: ${fmtFor(s, p.y)}', color: _color(i)));
            if (s is LineSeries) {
              final c = Offset(sx(bx), syOf(s)(p.y));
              canvas.drawCircle(c, 5.5, Paint()..color = _color(i));
              canvas.drawCircle(c, 2.5, Paint()..color = theme.surface);
            }
            break;
          }
        }
        final idx = bx.round();
        final title = (xLabels != null && idx >= 0 && idx < xLabels!.length)
            ? xLabels![idx]
            : (o.xFormat ?? formatNumber)(bx);
        paintTooltip(canvas, size, Offset(sx(bx), ptr.dy), theme,
            title: title, rows: rows);
        return;
      }
    }
    // scatter: nearest point
    double bestD = 30;
    int? bi;
    DataPoint? bp;
    for (var i = 0; i < series.length; i++) {
      if (series[i] is! ScatterSeries) continue;
      final syS = syOf(series[i]);
      for (final p in series[i].points) {
        final d = (Offset(sx(p.x), syS(p.y)) - ptr).distance;
        if (d < bestD) {
          bestD = d;
          bi = i;
          bp = p;
        }
      }
    }
    if (bp == null || bi == null) return;
    final c = Offset(sx(bp.x), syOf(series[bi])(bp.y));
    canvas.drawCircle(c, 9,
        Paint()
          ..color = _color(bi)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    final extra = bp.size == null ? '' : '  size ${formatNumber(bp.size!)}';
    paintTooltip(canvas, size, c, theme, title: series[bi].name, rows: [
      TooltipRow('(${formatNumber(bp.x)}, ${fmtFor(series[bi], bp.y)})$extra',
          color: _color(bi))
    ]);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
