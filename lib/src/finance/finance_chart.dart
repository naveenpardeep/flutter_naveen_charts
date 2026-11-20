import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../candlestick_chart.dart' show Candle;
import '../core/chart_canvas.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../core/finance.dart';

enum FinanceChartType {
  candlestick,
  hollowCandlestick,
  ohlc,
  heikinAshi,
  line,
  area,
}

enum FinanceOverlayKind { sma, ema, bollinger }

/// An indicator drawn on top of the price: SMA, EMA or Bollinger bands.
class FinanceOverlay {
  const FinanceOverlay.sma(this.period, {this.color, this.width = 1.6})
      : kind = FinanceOverlayKind.sma,
        multiplier = 2;
  const FinanceOverlay.ema(this.period, {this.color, this.width = 1.6})
      : kind = FinanceOverlayKind.ema,
        multiplier = 2;
  const FinanceOverlay.bollinger({this.period = 20, this.multiplier = 2, this.color, this.width = 1.2})
      : kind = FinanceOverlayKind.bollinger;
  final FinanceOverlayKind kind;
  final int period;

  /// Standard-deviation multiplier (Bollinger).
  final double multiplier;
  final Color? color;
  final double width;

  String get label => switch (kind) {
        FinanceOverlayKind.sma => 'SMA $period',
        FinanceOverlayKind.ema => 'EMA $period',
        FinanceOverlayKind.bollinger => 'BB $period, ${multiplier.toStringAsFixed(multiplier == multiplier.roundToDouble() ? 0 : 1)}σ',
      };
}

enum FinancePanelKind { rsi, macd }

/// An indicator sub-panel drawn under the price: RSI or MACD.
class FinancePanel {
  const FinancePanel.rsi({this.period = 14, this.overbought = 70, this.oversold = 30, this.color, this.weight = 1.1})
      : kind = FinancePanelKind.rsi,
        fast = 12,
        slow = 26,
        signal = 9;
  const FinancePanel.macd({this.fast = 12, this.slow = 26, this.signal = 9, this.color, this.weight = 1.1})
      : kind = FinancePanelKind.macd,
        period = 14,
        overbought = 70,
        oversold = 30;
  final FinancePanelKind kind;
  final int period, fast, slow, signal;
  final double overbought, oversold;
  final Color? color;

  /// Relative height of the panel (price pane = 3.6).
  final double weight;

  String get label => kind == FinancePanelKind.rsi ? 'RSI $period' : 'MACD $fast, $slow, $signal';
}

/// Full-featured market chart: candlesticks, hollow candles, OHLC bars,
/// Heikin-Ashi, line or area, with SMA / EMA / Bollinger overlays, a volume
/// pane, RSI / MACD panels, crosshair, last-price tag, log scale and
/// pinch / drag / wheel zoom (double-tap resets).
class FinanceChart extends StatefulWidget {
  const FinanceChart({
    super.key,
    required this.candles,
    this.type = FinanceChartType.candlestick,
    this.overlays = const [],
    this.panels = const [],
    this.showVolume = false,
    this.upColor = const Color(0xFF26A69A),
    this.downColor = const Color(0xFFEF5350),
    this.lineColor,
    this.showLastPrice = true,
    this.showCrosshair = true,
    this.logScale = false,
    this.priceFormat,
    this.volumeFormat,
    this.zoomable = true,
    this.visibleBars,
    this.maxZoom = 20,
    this.title,
    this.aspectRatio = 1.4,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });
  final List<Candle> candles;
  final FinanceChartType type;
  final List<FinanceOverlay> overlays;
  final List<FinancePanel> panels;
  final bool showVolume;
  final Color upColor, downColor;

  /// Colour of the line / area types (defaults to the theme's first colour).
  final Color? lineColor;
  final bool showLastPrice;
  final bool showCrosshair;
  final bool logScale;
  final String Function(double)? priceFormat;
  final String Function(double)? volumeFormat;
  final bool zoomable;

  /// Bars shown initially (most recent); null shows everything.
  final int? visibleBars;
  final double maxZoom;
  final String? title;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  @override
  State<FinanceChart> createState() => _FinanceChartState();
}

class _FinanceChartState extends State<FinanceChart> {
  late double _start, _span;
  double _s0 = 1, _anchor = 0;

  void _reset() {
    final n = widget.candles.length;
    final vb = widget.visibleBars;
    _span = (vb == null || n == 0 || vb >= n) ? 1.0 : vb / n;
    _start = 1 - _span;
  }

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(FinanceChart old) {
    super.didUpdateWidget(old);
    if (old.candles.length != widget.candles.length || old.visibleBars != widget.visibleBars) _reset();
  }

  double get _minSpan {
    final n = math.max(1, widget.candles.length);
    return math.max(1 / widget.maxZoom, math.min(5, n) / n);
  }

  void _setView(double start, double span) {
    final sp = span.clamp(_minSpan, 1.0).toDouble();
    final st = start.clamp(0.0, 1 - sp).toDouble();
    setState(() {
      _start = st;
      _span = sp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? ChartTheme.of(context);
    final canvas = ChartCanvas(
      duration: widget.animationDuration,
      builder: (p, ptr) => _FinancePainter(widget, t, p, ptr, _start, _span),
    );
    Widget body = canvas;
    if (widget.zoomable) {
      body = LayoutBuilder(builder: (context, c) {
        final w = math.max(1.0, c.maxWidth);
        return Listener(
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) {
              final f = e.scrollDelta.dy > 0 ? 1.15 : 1 / 1.15;
              final fx = e.localPosition.dx / w;
              final anchor = _start + fx * _span;
              final span = (_span * f).clamp(_minSpan, 1.0).toDouble();
              _setView(anchor - fx * span, span);
            }
          },
          child: GestureDetector(
            onDoubleTap: () => setState(_reset),
            onScaleStart: (d) {
              _s0 = _span;
              _anchor = _start + d.localFocalPoint.dx / w * _span;
            },
            onScaleUpdate: (d) {
              final span = (_s0 / d.scale).clamp(_minSpan, 1.0).toDouble();
              _setView(_anchor - d.localFocalPoint.dx / w * span, span);
            },
            child: canvas,
          ),
        );
      });
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (widget.title != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(widget.title!, style: Theme.of(context).textTheme.titleSmall),
        ),
      AspectRatio(aspectRatio: widget.aspectRatio, child: body),
    ]);
  }
}

/// `FinanceChart(type: FinanceChartType.ohlc)` with a shorter name.
class OhlcChart extends StatelessWidget {
  const OhlcChart({super.key, required this.candles, this.overlays = const [], this.panels = const [], this.showVolume = false, this.theme, this.aspectRatio = 1.4});
  final List<Candle> candles;
  final List<FinanceOverlay> overlays;
  final List<FinancePanel> panels;
  final bool showVolume;
  final ChartTheme? theme;
  final double aspectRatio;
  @override
  Widget build(BuildContext context) => FinanceChart(
      candles: candles, type: FinanceChartType.ohlc, overlays: overlays, panels: panels, showVolume: showVolume, theme: theme, aspectRatio: aspectRatio);
}

/// `FinanceChart(type: FinanceChartType.heikinAshi)` with a shorter name.
class HeikinAshiChart extends StatelessWidget {
  const HeikinAshiChart({super.key, required this.candles, this.overlays = const [], this.panels = const [], this.showVolume = false, this.theme, this.aspectRatio = 1.4});
  final List<Candle> candles;
  final List<FinanceOverlay> overlays;
  final List<FinancePanel> panels;
  final bool showVolume;
  final ChartTheme? theme;
  final double aspectRatio;
  @override
  Widget build(BuildContext context) => FinanceChart(
      candles: candles, type: FinanceChartType.heikinAshi, overlays: overlays, panels: panels, showVolume: showVolume, theme: theme, aspectRatio: aspectRatio);
}

class _Ov {
  _Ov(this.o, this.color, this.values, [this.upper, this.lower]);
  final FinanceOverlay o;
  final Color color;
  final List<double> values;
  final List<double>? upper, lower;
}

class _Pane {
  _Pane(this.rect, this.valueAt, this.format);
  final Rect rect;
  final double Function(double y) valueAt;
  final String Function(double) format;
}

class _FinancePainter extends CustomPainter {
  _FinancePainter(this.w, this.theme, this.progress, this.pointer, this.viewStart, this.viewSpan);
  final FinanceChart w;
  final ChartTheme theme;
  final double progress, viewStart, viewSpan;
  final Offset? pointer;

  void _dash(Canvas c, Offset a, Offset b, Paint p) {
    c.drawPath(dashPath(Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy), dash: 4, gap: 3), p..style = PaintingStyle.stroke);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final src = w.candles;
    final n = src.length;
    if (n == 0) return;
    final draw = w.type == FinanceChartType.heikinAshi ? heikinAshi(src) : src;
    final closes = [for (final c in src) c.close];
    final fmt = w.priceFormat ?? formatNumber;
    final vfmt = w.volumeFormat ?? formatNumber;

    // ---- indicators
    final ovs = <_Ov>[];
    for (var k = 0; k < w.overlays.length; k++) {
      final o = w.overlays[k];
      final color = o.color ?? theme.colorAt(1 + k);
      switch (o.kind) {
        case FinanceOverlayKind.sma:
          ovs.add(_Ov(o, color, sma(closes, o.period)));
        case FinanceOverlayKind.ema:
          ovs.add(_Ov(o, color, ema(closes, o.period)));
        case FinanceOverlayKind.bollinger:
          final b = bollinger(closes, o.period, o.multiplier);
          ovs.add(_Ov(o, color, b.mid, b.upper, b.lower));
      }
    }
    final rsiVals = <int, List<double>>{};
    final macdVals = <int, Macd>{};
    for (var k = 0; k < w.panels.length; k++) {
      final p = w.panels[k];
      if (p.kind == FinancePanelKind.rsi) {
        rsiVals[k] = rsi(closes, p.period);
      } else {
        macdVals[k] = macd(closes, p.fast, p.slow, p.signal);
      }
    }

    // ---- visible window
    final xStart = viewStart * n, vis = viewSpan * n;
    final first = xStart.floor().clamp(0, n - 1).toInt();
    final last = ((xStart + vis).ceil() - 1).clamp(first, n - 1).toInt();

    var lo = double.infinity, hi = -double.infinity;
    for (var i = first; i <= last; i++) {
      if (w.type == FinanceChartType.line || w.type == FinanceChartType.area) {
        lo = math.min(lo, draw[i].close);
        hi = math.max(hi, draw[i].close);
      } else {
        lo = math.min(lo, draw[i].low);
        hi = math.max(hi, draw[i].high);
      }
      for (final ov in ovs) {
        for (final list in [ov.values, ov.upper, ov.lower]) {
          if (list != null && !list[i].isNaN) {
            lo = math.min(lo, list[i]);
            hi = math.max(hi, list[i]);
          }
        }
      }
    }
    final scale = NiceScale.compute(lo, hi, maxTicks: 6);
    final lastClose = src.last.close;
    final labelW = [...scale.ticks.map(fmt), fmt(lastClose)]
        .map((s) => measureText(s, theme.labelStyle).width)
        .fold<double>(0, math.max);

    final left = 8.0, right = size.width - labelW - 16, top = 8.0, bottom = size.height - 22;
    if (right - left < 40 || bottom - top < 60) return;

    // ---- panes
    final weights = <double>[(w.showVolume || w.panels.isNotEmpty) ? 3.6 : 1.0];
    if (w.showVolume) weights.add(.9);
    for (final p in w.panels) {
      weights.add(p.weight);
    }
    const gap = 6.0;
    final avail = bottom - top - gap * (weights.length - 1);
    final totalW = weights.fold<double>(0, (a, b) => a + b);
    final rects = <Rect>[];
    var y = top;
    for (final wt in weights) {
      final h = avail * wt / totalW;
      rects.add(Rect.fromLTRB(left, y, right, y + h));
      y += h + gap;
    }

    final slot = (right - left) / vis;
    double cx(int i) => left + (i + .5 - xStart) * slot;
    final main = rects[0];
    final smin = math.max(scale.min, lo * .5);
    final logOn = w.logScale && smin > 0;
    final la = logOn ? math.log(smin) : 0.0, lb = logOn ? math.log(scale.max) : 1.0;
    double py(double v) => logOn
        ? main.bottom - (math.log(math.max(v, smin)) - la) / (lb - la) * main.height
        : main.bottom - (v - scale.min) / (scale.max - scale.min) * main.height;
    double mainAt(double yy) {
      final t = (main.bottom - yy) / main.height;
      return logOn ? math.exp(la + t * (lb - la)) : scale.min + t * (scale.max - scale.min);
    }

    final panes = <_Pane>[_Pane(main, mainAt, fmt)];
    final grid = Paint()
      ..color = theme.gridColor
      ..strokeWidth = 1;
    final border = Paint()
      ..color = theme.gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final t in scale.ticks) {
      final yy = py(t);
      if (yy < main.top - 1 || yy > main.bottom + 1) continue;
      canvas.drawLine(Offset(left, yy), Offset(right, yy), grid);
      paintText(canvas, fmt(t), Offset(right + 6, yy), theme.labelStyle, align: Alignment.centerLeft);
    }
    canvas.drawRect(main, border);

    // ---- price series
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(left, main.top - 1, left + (right - left) * progress, main.bottom + 1));
    final bodyW = (slot * .7).clamp(1.0, 22.0).toDouble();
    final isLine = w.type == FinanceChartType.line || w.type == FinanceChartType.area;
    if (isLine) {
      final pts = [for (var i = first; i <= last; i++) Offset(cx(i), py(draw[i].close))];
      final path = buildLinePath(pts);
      final color = w.lineColor ?? theme.colorAt(0);
      if (w.type == FinanceChartType.area && pts.length > 1) {
        final area = Path.from(path)
          ..lineTo(pts.last.dx, main.bottom)
          ..lineTo(pts.first.dx, main.bottom)
          ..close();
        canvas.drawPath(area, Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.faded(.35), color.faded(.02)]).createShader(main));
      }
      canvas.drawPath(path, Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round);
    } else {
      for (var i = first; i <= last; i++) {
        final c = draw[i];
        final up = c.close >= c.open;
        final color = up ? w.upColor : w.downColor;
        final x = cx(i);
        final stroke = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = w.type == FinanceChartType.ohlc ? math.max(1.2, math.min(2.2, slot * .12)) : 1.3;
        canvas.drawLine(Offset(x, py(c.high)), Offset(x, py(c.low)), stroke);
        if (w.type == FinanceChartType.ohlc) {
          canvas.drawLine(Offset(x - bodyW / 2, py(c.open)), Offset(x, py(c.open)), stroke);
          canvas.drawLine(Offset(x, py(c.close)), Offset(x + bodyW / 2, py(c.close)), stroke);
        } else {
          final t = py(math.max(c.open, c.close)), b = py(math.min(c.open, c.close));
          final body = Rect.fromLTRB(x - bodyW / 2, t, x + bodyW / 2, math.max(b, t + 1));
          if (w.type == FinanceChartType.hollowCandlestick && up) {
            canvas.drawRect(body.deflate(.7), stroke..strokeWidth = 1.4);
          } else {
            canvas.drawRect(body, Paint()..color = color);
          }
        }
      }
    }
    // overlays
    Path seg(List<double> v) {
      final p = Path();
      var pen = false;
      for (var i = first; i <= last; i++) {
        if (v[i].isNaN) {
          pen = false;
          continue;
        }
        final o = Offset(cx(i), py(v[i]));
        if (pen) {
          p.lineTo(o.dx, o.dy);
        } else {
          p.moveTo(o.dx, o.dy);
          pen = true;
        }
      }
      return p;
    }

    for (final ov in ovs) {
      if (ov.upper != null && ov.lower != null) {
        final band = Path();
        final idx = [for (var i = first; i <= last; i++) if (!ov.upper![i].isNaN) i];
        if (idx.length > 1) {
          band.moveTo(cx(idx.first), py(ov.upper![idx.first]));
          for (final i in idx.skip(1)) {
            band.lineTo(cx(i), py(ov.upper![i]));
          }
          for (final i in idx.reversed) {
            band.lineTo(cx(i), py(ov.lower![i]));
          }
          band.close();
          canvas.drawPath(band, Paint()..color = ov.color.faded(.09));
        }
        final edge = Paint()
          ..color = ov.color.faded(.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = ov.o.width;
        canvas.drawPath(seg(ov.upper!), edge);
        canvas.drawPath(seg(ov.lower!), edge);
      }
      canvas.drawPath(seg(ov.values), Paint()
        ..color = ov.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = ov.o.width
        ..strokeJoin = StrokeJoin.round);
    }
    canvas.restore();

    // overlay legend
    var lx = left + 6;
    for (final ov in ovs) {
      final tp = measureText(ov.o.label, theme.labelStyle);
      paintText(canvas, ov.o.label, Offset(lx, main.top + 4), theme.labelStyle.copyWith(color: ov.color, fontWeight: FontWeight.w600), align: Alignment.topLeft);
      lx += tp.width + 12;
    }

    // last price tag
    if (w.showLastPrice) {
      final yy = py(lastClose);
      if (yy >= main.top && yy <= main.bottom) {
        final prev = n > 1 ? src[n - 2].close : src.last.open;
        final color = lastClose >= prev ? w.upColor : w.downColor;
        _dash(canvas, Offset(left, yy), Offset(right, yy), Paint()
          ..color = color.faded(.8)
          ..strokeWidth = 1);
        final tag = RRect.fromRectAndRadius(Rect.fromLTWH(right + 2, yy - 8, labelW + 12, 16), const Radius.circular(3));
        canvas.drawRRect(tag, Paint()..color = color);
        paintText(canvas, fmt(lastClose), Offset(right + 8, yy), TextStyle(color: contrastOn(color), fontSize: 10.5, fontWeight: FontWeight.bold), align: Alignment.centerLeft);
      }
    }

    var paneIdx = 1;
    // ---- volume pane
    if (w.showVolume) {
      final r = rects[paneIdx++];
      var vmax = 1.0;
      for (var i = first; i <= last; i++) {
        vmax = math.max(vmax, src[i].volume);
      }
      canvas.drawRect(r, border);
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(left, r.top, left + (right - left) * progress, r.bottom));
      for (var i = first; i <= last; i++) {
        final up = src[i].close >= src[i].open;
        final h = src[i].volume / vmax * r.height;
        canvas.drawRect(Rect.fromLTRB(cx(i) - bodyW / 2, r.bottom - h, cx(i) + bodyW / 2, r.bottom), Paint()..color = (up ? w.upColor : w.downColor).faded(.65));
      }
      canvas.restore();
      paintText(canvas, vfmt(vmax), Offset(right + 6, r.top), theme.labelStyle, align: Alignment.topLeft);
      paintText(canvas, 'Volume', Offset(left + 6, r.top + 3), theme.labelStyle.copyWith(fontWeight: FontWeight.w600), align: Alignment.topLeft);
      panes.add(_Pane(r, (yy) => (r.bottom - yy) / r.height * vmax, vfmt));
    }

    // ---- indicator panels
    for (var k = 0; k < w.panels.length; k++) {
      final p = w.panels[k];
      final r = rects[paneIdx++];
      canvas.drawRect(r, border);
      paintText(canvas, p.label, Offset(left + 6, r.top + 3), theme.labelStyle.copyWith(fontWeight: FontWeight.w600), align: Alignment.topLeft);
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(left, r.top, left + (right - left) * progress, r.bottom));
      Path pseg(List<double> v, double Function(double) f) {
        final path = Path();
        var pen = false;
        for (var i = first; i <= last; i++) {
          if (v[i].isNaN) {
            pen = false;
            continue;
          }
          final o = Offset(cx(i), f(v[i]));
          if (pen) {
            path.lineTo(o.dx, o.dy);
          } else {
            path.moveTo(o.dx, o.dy);
            pen = true;
          }
        }
        return path;
      }

      if (p.kind == FinancePanelKind.rsi) {
        double f(double v) => r.bottom - v / 100 * r.height;
        canvas.drawRect(Rect.fromLTRB(left, f(p.overbought), right, f(p.oversold)), Paint()..color = theme.axisColor.faded(.08));
        for (final lv in [p.overbought, p.oversold]) {
          _dash(canvas, Offset(left, f(lv)), Offset(right, f(lv)), Paint()
            ..color = theme.axisColor.faded(.8)
            ..strokeWidth = 1);
        }
        canvas.drawPath(pseg(rsiVals[k]!, f), Paint()
          ..color = p.color ?? theme.colorAt(4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
        canvas.restore();
        paintText(canvas, p.overbought.round().toString(), Offset(right + 6, f(p.overbought)), theme.labelStyle, align: Alignment.centerLeft);
        paintText(canvas, p.oversold.round().toString(), Offset(right + 6, f(p.oversold)), theme.labelStyle, align: Alignment.centerLeft);
        panes.add(_Pane(r, (yy) => (r.bottom - yy) / r.height * 100, (v) => v.toStringAsFixed(1)));
      } else {
        final m = macdVals[k]!;
        var a = 0.0, b = 0.0;
        for (var i = first; i <= last; i++) {
          for (final v in [m.line[i], m.signal[i], m.hist[i]]) {
            if (!v.isNaN) {
              a = math.min(a, v);
              b = math.max(b, v);
            }
          }
        }
        final ms = NiceScale.compute(a, b, maxTicks: 4, includeZero: true);
        double f(double v) => r.bottom - (v - ms.min) / (ms.max - ms.min) * r.height;
        canvas.drawLine(Offset(left, f(0)), Offset(right, f(0)), Paint()
          ..color = theme.axisColor
          ..strokeWidth = 1);
        for (var i = first; i <= last; i++) {
          final h = m.hist[i];
          if (h.isNaN) continue;
          canvas.drawRect(Rect.fromLTRB(cx(i) - bodyW / 2, math.min(f(0), f(h)), cx(i) + bodyW / 2, math.max(f(0), f(h))), Paint()..color = (h >= 0 ? w.upColor : w.downColor).faded(.6));
        }
        canvas.drawPath(pseg(m.line, f), Paint()
          ..color = p.color ?? theme.colorAt(0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
        canvas.drawPath(pseg(m.signal, f), Paint()
          ..color = theme.colorAt(1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
        canvas.restore();
        for (final t in [ms.max, 0.0, ms.min]) {
          paintText(canvas, formatNumber(t), Offset(right + 6, f(t)), theme.labelStyle, align: Alignment.centerLeft);
        }
        panes.add(_Pane(r, (yy) => ms.min + (r.bottom - yy) / r.height * (ms.max - ms.min), (v) => v.toStringAsFixed(2)));
      }
    }

    // ---- x labels
    final maxLab = src.map((c) => measureText(c.label, theme.labelStyle).width).fold<double>(0, math.max);
    final step = math.max(1, ((maxLab + 10) / slot).ceil());
    for (var i = (first / step).ceil() * step; i <= last; i += step) {
      paintText(canvas, src[i].label, Offset(cx(i), bottom + 5), theme.labelStyle, align: Alignment.topCenter);
    }

    // ---- crosshair & tooltip
    final ptr = pointer;
    if (ptr != null && w.showCrosshair && progress >= 1 && ptr.dx >= left && ptr.dx <= right && ptr.dy >= top && ptr.dy <= bottom) {
      final idx = ((ptr.dx - left) / slot + xStart - .5).round().clamp(first, last).toInt();
      final guide = Paint()
        ..color = theme.axisColor
        ..strokeWidth = 1;
      _dash(canvas, Offset(cx(idx), top), Offset(cx(idx), bottom), guide);
      for (final pn in panes) {
        if (ptr.dy >= pn.rect.top && ptr.dy <= pn.rect.bottom) {
          _dash(canvas, Offset(left, ptr.dy), Offset(right, ptr.dy), Paint()
            ..color = theme.axisColor
            ..strokeWidth = 1);
          final label = pn.format(pn.valueAt(ptr.dy));
          final tag = RRect.fromRectAndRadius(Rect.fromLTWH(right + 2, ptr.dy - 8, labelW + 12, 16), const Radius.circular(3));
          canvas.drawRRect(tag, Paint()..color = theme.tooltipBackground);
          paintText(canvas, label, Offset(right + 8, ptr.dy), theme.tooltipStyle.copyWith(fontSize: 10.5), align: Alignment.centerLeft);
        }
      }
      final c = src[idx];
      final prevClose = idx > 0 ? src[idx - 1].close : c.open;
      final chg = prevClose == 0 ? 0.0 : (c.close - prevClose) / prevClose * 100;
      final upC = c.close >= c.open ? w.upColor : w.downColor;
      paintTooltip(canvas, size, Offset(cx(idx), ptr.dy), theme, title: c.label, rows: [
        TooltipRow('Open   ${fmt(c.open)}'),
        TooltipRow('High    ${fmt(c.high)}'),
        TooltipRow('Low     ${fmt(c.low)}'),
        TooltipRow('Close  ${fmt(c.close)}', color: upC),
        TooltipRow('Change ${chg >= 0 ? '+' : ''}${chg.toStringAsFixed(2)}%'),
        if (w.showVolume || c.volume > 0) TooltipRow('Volume ${vfmt(c.volume)}'),
        for (final ov in ovs)
          if (!ov.values[idx].isNaN) TooltipRow('${ov.o.label}  ${fmt(ov.values[idx])}', color: ov.color),
        for (var k = 0; k < w.panels.length; k++)
          if (rsiVals[k] != null && !rsiVals[k]![idx].isNaN)
            TooltipRow('${w.panels[k].label}  ${rsiVals[k]![idx].toStringAsFixed(1)}')
          else if (macdVals[k] != null && !macdVals[k]!.line[idx].isNaN)
            TooltipRow('${w.panels[k].label}  ${macdVals[k]!.line[idx].toStringAsFixed(2)}'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
