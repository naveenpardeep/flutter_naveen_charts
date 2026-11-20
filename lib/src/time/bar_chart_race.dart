// Bar-chart race: an animated ranking that changes over time.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';

/// One step of a [BarChartRace] (a year, a day ...): [values] has one number
/// per name in `BarChartRace.names`, in the same order.
class BarRaceFrame {
  const BarRaceFrame(this.label, this.values);
  final String label;
  final List<double> values;
}

/// Bar-chart race: horizontal bars that grow, shrink and swap places as time
/// moves through the [frames]. Values are interpolated between frames and the
/// ranks glide smoothly, so you can watch who overtakes whom. Only the
/// [topN] items are shown; others slide in and out at the bottom.
///
/// Comes with play / pause, restart and a slider to scrub through time.
/// Hover a bar for its rank and value.
class BarChartRace extends StatefulWidget {
  const BarChartRace({
    super.key,
    required this.names,
    required this.frames,
    this.colors,
    this.topN = 8,
    this.secondsPerFrame = 1.2,
    this.autoPlay = true,
    this.loop = false,
    this.showControls = true,
    this.valueFormat,
    this.aspectRatio = 1.3,
    this.theme,
  });

  /// The competing items.
  final List<String> names;

  /// The time steps, in order.
  final List<BarRaceFrame> frames;

  /// One colour per name (default: theme palette).
  final List<Color>? colors;

  /// Number of bars shown at once.
  final int topN;

  /// How long the race spends on moving from one frame to the next.
  final double secondsPerFrame;
  final bool autoPlay;

  /// Start over when the race ends.
  final bool loop;

  /// Show the play / pause, restart and time slider row.
  final bool showControls;
  final String Function(double)? valueFormat;
  final double aspectRatio;
  final ChartTheme? theme;

  @override
  State<BarChartRace> createState() => _BarChartRaceState();
}

class _BarChartRaceState extends State<BarChartRace> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  /// `_ranks[frame][item]` = position of the item in that frame (0 = leader).
  List<List<int>> _ranks = [];
  Offset? _pointer;

  Duration get _duration =>
      Duration(milliseconds: math.max(1, (widget.secondsPerFrame * 1000 * math.max(1, widget.frames.length - 1)).round()));

  void _computeRanks() {
    _ranks = [
      for (final f in widget.frames)
        () {
          // sort item indexes by value (ties keep the original order)
          final order = List<int>.generate(widget.names.length, (i) => i)
            ..sort((a, b) {
              final va = a < f.values.length ? f.values[a] : 0.0, vb = b < f.values.length ? f.values[b] : 0.0;
              final c = vb.compareTo(va);
              return c != 0 ? c : a.compareTo(b);
            });
          final rank = List<int>.filled(widget.names.length, 0);
          for (var pos = 0; pos < order.length; pos++) {
            rank[order[pos]] = pos;
          }
          return rank;
        }()
    ];
  }

  @override
  void initState() {
    super.initState();
    _computeRanks();
    _ctrl = AnimationController(vsync: this, duration: _duration);
    if (widget.autoPlay && widget.frames.length > 1) {
      widget.loop ? _ctrl.repeat() : _ctrl.forward();
    }
    // Registered after the first start so it only reacts to later changes; it
    // keeps the play / pause icon in sync when the race ends by itself.
    _ctrl.addStatusListener((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(BarChartRace old) {
    super.didUpdateWidget(old);
    _computeRanks();
    _ctrl.duration = _duration;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_ctrl.isAnimating) {
      _ctrl.stop();
    } else if (_ctrl.value >= 1) {
      widget.loop ? _ctrl.repeat() : _ctrl.forward(from: 0);
    } else {
      widget.loop ? _ctrl.repeat() : _ctrl.forward();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme ?? ChartTheme.of(context);
    final steps = math.max(1, widget.frames.length - 1);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: MouseRegion(
          onHover: (e) => setState(() => _pointer = e.localPosition),
          onExit: (_) => setState(() => _pointer = null),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => setState(() => _pointer = e.localPosition),
            onPointerMove: (e) => setState(() => _pointer = e.localPosition),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => CustomPaint(
                size: Size.infinite,
                painter: _RacePainter(widget, _ranks, _ctrl.value * steps, t, _pointer),
              ),
            ),
          ),
        ),
      ),
      if (widget.showControls && widget.frames.length > 1)
        Row(children: [
          IconButton(
            tooltip: _ctrl.isAnimating ? 'Pause' : 'Play',
            icon: Icon(_ctrl.isAnimating ? Icons.pause : Icons.play_arrow),
            onPressed: _togglePlay,
          ),
          IconButton(
            tooltip: 'Restart',
            icon: const Icon(Icons.replay),
            onPressed: () {
              _ctrl.forward(from: 0);
              setState(() {});
            },
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Slider(
                value: _ctrl.value.clamp(0.0, 1.0).toDouble(),
                // dragging the slider pauses the race and jumps to that time
                onChanged: (v) {
                  _ctrl.stop();
                  _ctrl.value = v;
                },
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => SizedBox(
              width: 52,
              child: Text(widget.frames[(_ctrl.value * steps).round().clamp(0, widget.frames.length - 1)].label, style: t.labelStyle),
            ),
          ),
        ]),
    ]);
  }
}

class _RacePainter extends CustomPainter {
  _RacePainter(this.w, this.ranks, this.time, this.theme, this.pointer);
  final BarChartRace w;
  final List<List<int>> ranks;

  /// Position in frames (0 .. frames-1, fractional between two frames).
  final double time;
  final ChartTheme theme;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final n = w.frames.length, items = w.names.length;
    if (n == 0 || items == 0) return;
    final topN = math.min(w.topN, items);
    final fmt = w.valueFormat ?? formatNumber;

    // ---- 1. which two frames are we between, and how far along?
    final t = time.clamp(0.0, (n - 1).toDouble()).toDouble();
    final f0 = n == 1 ? 0 : math.min(t.floor(), n - 2);
    final f1 = n == 1 ? 0 : f0 + 1;
    final u = n == 1 ? 0.0 : (t - f0).clamp(0.0, 1.0).toDouble();
    final eased = u * u * (3 - 2 * u); // smoothstep: bars start and stop gently
    double lerp(double a, double b, double k) => a + (b - a) * k;
    double value(int frame, int i) => i < w.frames[frame].values.length ? w.frames[frame].values[i] : 0.0;

    // ---- 2. current value and row position of every item. Values move
    //         linearly; positions move between the two ranks (clamped to topN
    //         so items outside the chart slide in from the bottom).
    final vals = [for (var i = 0; i < items; i++) lerp(value(f0, i), value(f1, i), u)];
    final pos = [for (var i = 0; i < items; i++) lerp(math.min(ranks[f0][i], topN).toDouble(), math.min(ranks[f1][i], topN).toDouble(), eased)];

    // ---- 3. layout
    final labelW = math.min(110.0, w.names.map((s) => measureText(s, theme.labelStyle).width).fold<double>(0, math.max) + 8);
    final valueW = 70.0;
    final plot = Rect.fromLTRB(labelW + 10, 8, size.width - valueW, size.height - 8);
    if (plot.width < 40 || plot.height < 40) return;
    final rowH = plot.height / topN;
    var maxV = 1e-9;
    for (var i = 0; i < items; i++) {
      if (pos[i] < topN - .5) maxV = math.max(maxV, vals[i]);
    }
    maxV *= 1.04;
    Color colorOf(int i) => (w.colors != null && i < w.colors!.length) ? w.colors![i] : theme.colorAt(i);

    // ---- 4. big frame label in the corner (drawn first, so bars sit on top)
    paintText(canvas, w.frames[(t).round().clamp(0, n - 1)].label, Offset(plot.right + valueW - 6, plot.bottom - 2),
        TextStyle(color: theme.textColor.faded(.16), fontSize: math.min(54.0, plot.height * .26), fontWeight: FontWeight.w800),
        align: Alignment.bottomRight);

    // ---- 5. bars, back to front
    final order = List<int>.generate(items, (i) => i)..sort((a, b) => pos[b].compareTo(pos[a]));
    int? hover;
    final ptr = pointer;
    for (final i in order) {
      if (pos[i] >= topN) continue; // not on the chart
      final top = plot.top + pos[i] * rowH;
      final alpha = (topN - pos[i]).clamp(0.0, 1.0).toDouble(); // fades while leaving
      final barH = rowH * .78;
      final y = top + (rowH - barH) / 2;
      final width = math.max(2.0, vals[i] / maxV * plot.width);
      final rect = Rect.fromLTWH(plot.left, y, width, barH);
      if (ptr != null && ptr.dy >= top && ptr.dy < top + rowH && ptr.dx >= 0 && ptr.dx <= size.width) hover = i;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5)), Paint()..color = colorOf(i).faded(alpha * (hover == i ? 1 : .92)));
      paintText(canvas, w.names[i], Offset(plot.left - 8, y + barH / 2), theme.labelStyle.copyWith(color: theme.textColor.faded(alpha), fontWeight: FontWeight.w600),
          align: Alignment.centerRight, maxWidth: labelW);
      paintText(canvas, fmt(vals[i]), Offset(rect.right + 6, y + barH / 2), theme.labelStyle.copyWith(color: theme.textColor.faded(alpha)), align: Alignment.centerLeft);
    }

    // ---- 6. tooltip: current rank of the hovered bar
    if (hover != null && ptr != null) {
      final h = hover;
      final rank = vals.where((v) => v > vals[h]).length + 1;
      paintTooltip(canvas, size, ptr, theme, title: w.names[h], rows: [
        TooltipRow('Rank #$rank', color: colorOf(h)),
        TooltipRow('${w.frames[t.round().clamp(0, n - 1)].label}: ${fmt(vals[h])}'),
      ]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
