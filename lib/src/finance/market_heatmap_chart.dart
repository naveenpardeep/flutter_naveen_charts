// Market heatmap: a treemap of assets, sized by volume and coloured by price change.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart3d.dart' show rampColor;
import '../core/chart_canvas.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import '../treemap_chart.dart' show squarify;

/// One asset (coin, stock, ETF ...) in a [MarketHeatmapChart].
class MarketTile {
  const MarketTile(this.symbol, this.volume, this.changePercent, {this.name, this.price});

  /// Short label drawn on the tile, e.g. `BTC`.
  final String symbol;

  /// Decides the tile area (traded volume, market cap, ...). Must be > 0.
  final double volume;

  /// Price change in percent, e.g. `-1.9` for a 1.9 % fall. Decides the colour.
  final double changePercent;

  /// Optional long name, shown in the tooltip.
  final String? name;

  /// Optional last price, shown in the tooltip.
  final double? price;
}

/// Default colour ramps. Index 0 is a small move, the last entry a big one.
const List<Color> kMarketDownColors = [Color(0xFFEA8A80), Color(0xFFDC4538), Color(0xFF8E1A12)];
const List<Color> kMarketUpColors = [Color(0xFF74BC7D), Color(0xFF3F9A4F), Color(0xFF1F6B33)];

/// Colour for a price change: green when up, red when down, darker the bigger
/// the move. A move of [maxMove] percent (or more) gets the darkest colour;
/// an exact zero gets [neutral].
Color marketChangeColor(
  double changePercent, {
  double maxMove = 5,
  List<Color> up = kMarketUpColors,
  List<Color> down = kMarketDownColors,
  Color neutral = const Color(0xFF9E9E9E),
}) {
  if (changePercent.abs() < 1e-12) return neutral;
  final t = (changePercent.abs() / maxMove).clamp(0.0, 1.0).toDouble();
  return rampColor(changePercent > 0 ? up : down, t);
}

/// Places [tiles] (largest volume first) inside [area] with the squarified
/// treemap algorithm. The returned rectangles follow the order of [tiles] and
/// have an area proportional to each volume.
List<Rect> layoutMarketTiles(List<MarketTile> tiles, Rect area) =>
    squarify([for (final t in tiles) t.volume], area);

/// Market heatmap: every asset is a rounded tile whose **size** shows volume
/// and whose **colour** shows the price change (green up, red down, darker =
/// bigger move). Tiles carry the symbol, an arrow and the percentage.
///
/// Everything is customisable: colour ramps, the move that counts as "big"
/// ([maxMove]), tile and frame corner radii, gaps, title, caption, number
/// formats, an optional colour legend and a tap callback. Hover a tile for
/// name, volume, share of volume and price.
class MarketHeatmapChart extends StatelessWidget {
  const MarketHeatmapChart({
    super.key,
    required this.tiles,
    this.title = 'Market heatmap',
    this.caption = 'The size shows volume, color shows price change — darker means a bigger move.',
    this.maxMove = 5,
    this.gap = 4,
    this.tileRadius = 10,
    this.outerRadius = 28,
    this.showArrows = true,
    this.showLegend = false,
    this.upColors = kMarketUpColors,
    this.downColors = kMarketDownColors,
    this.neutralColor,
    this.changeFormat,
    this.volumeFormat,
    this.priceFormat,
    this.onTileTap,
    this.aspectRatio = 1.4,
    this.theme,
    this.animationDuration = const Duration(milliseconds: 900),
  });

  /// The assets. Tiles with a volume of zero or less are skipped.
  final List<MarketTile> tiles;

  /// Heading above the chart (null hides it).
  final String? title;

  /// Explanation below the chart (null hides it).
  final String? caption;

  /// Price move in percent that gets the darkest colour.
  final double maxMove;

  /// Space between tiles in logical pixels.
  final double gap;

  /// Corner radius of a tile.
  final double tileRadius;

  /// Corner radius of the whole chart; tiles in the corners are clipped to it.
  final double outerRadius;

  /// Show an up / down arrow in front of the percentage.
  final bool showArrows;

  /// Show a small colour scale (-maxMove ... +maxMove) under the chart.
  final bool showLegend;

  /// Colour ramps, small move first.
  final List<Color> upColors, downColors;

  /// Colour of tiles with exactly 0 % change (default: theme axis colour).
  final Color? neutralColor;

  /// Formats the absolute percentage on the tile (default: 0.13, 1.9, 5.27).
  final String Function(double)? changeFormat;
  final String Function(double)? volumeFormat;
  final String Function(double)? priceFormat;

  /// Called when a tile is tapped.
  final void Function(MarketTile tile)? onTileTap;
  final double aspectRatio;
  final ChartTheme? theme;
  final Duration animationDuration;

  Color _color(MarketTile s, ChartTheme t) => marketChangeColor(s.changePercent,
      maxMove: maxMove, up: upColors, down: downColors, neutral: neutralColor ?? t.axisColor);

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    // Largest first: the treemap algorithm expects sorted input.
    final sorted = [...tiles.where((x) => x.volume > 0)]..sort((a, b) => b.volume.compareTo(a.volume));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (title != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(title!, style: t.labelStyle.copyWith(fontSize: 20, fontWeight: FontWeight.w700)),
        ),
      AspectRatio(
        aspectRatio: aspectRatio,
        child: LayoutBuilder(builder: (context, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          final rects = layoutMarketTiles(sorted, Offset.zero & size);
          return GestureDetector(
            onTapUp: onTileTap == null
                ? null
                : (d) {
                    for (var i = 0; i < sorted.length; i++) {
                      if (rects[i].contains(d.localPosition)) {
                        onTileTap!(sorted[i]);
                        break;
                      }
                    }
                  },
            child: ChartCanvas(
              duration: animationDuration,
              builder: (p, ptr) => _MarketPainter(this, sorted, rects, t, p, ptr),
            ),
          );
        }),
      ),
      if (showLegend)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            Text('−${formatNumber(maxMove)}%', style: t.labelStyle),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(colors: [...downColors.reversed, ...upColors]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('+${formatNumber(maxMove)}%', style: t.labelStyle),
          ]),
        ),
      if (caption != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(caption!, style: t.labelStyle.copyWith(fontSize: 14, height: 1.3)),
        ),
    ]);
  }
}

class _MarketPainter extends CustomPainter {
  _MarketPainter(this.w, this.tiles, this.rects, this.theme, this.progress, this.pointer);
  final MarketHeatmapChart w;
  final List<MarketTile> tiles;
  final List<Rect> rects;
  final ChartTheme theme;
  final double progress;
  final Offset? pointer;

  @override
  void paint(Canvas canvas, Size size) {
    final n = tiles.length;
    if (n == 0) return;
    final total = tiles.fold<double>(0, (a, t) => a + t.volume);
    final pct = w.changeFormat ?? formatNumber;

    // ---- which tile is under the pointer?
    int? hover;
    final ptr = pointer;
    if (ptr != null && progress >= 1) {
      for (var i = 0; i < n; i++) {
        if (rects[i].contains(ptr)) hover = i;
      }
    }

    // ---- everything is clipped to the big rounded frame, so tiles in the
    //      four corners get the large corner radius seen in the screenshot
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w.outerRadius)));
    for (var i = 0; i < n; i++) {
      // Tiles pop in one after another (biggest first).
      final t = (progress * 1.7 - i / n * .7).clamp(0.0, 1.0).toDouble();
      if (t <= 0) continue;
      final base = rects[i].deflate(w.gap / 2);
      final rect = Rect.fromCenter(center: base.center, width: base.width * (.85 + .15 * t), height: base.height * (.85 + .15 * t));
      var color = w._color(tiles[i], theme);
      if (hover == i) color = Color.lerp(color, Colors.white, .14)!;
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(w.tileRadius));
      canvas.drawRRect(rr, Paint()..color = color.faded(t));
      if (hover == i) {
        canvas.drawRRect(rr.deflate(1.2), Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4);
      }
      if (t > .6) _label(canvas, tiles[i], rect, t, pct);
    }
    canvas.restore();

    // ---- tooltip
    if (hover != null && ptr != null) {
      final s = tiles[hover];
      final vf = w.volumeFormat ?? formatNumber;
      final c = w._color(s, theme);
      paintTooltip(canvas, size, ptr, theme, title: s.name == null ? s.symbol : '${s.symbol} · ${s.name}', rows: [
        TooltipRow('Change: ${s.changePercent > 0 ? '+' : ''}${pct(s.changePercent)}%', color: c),
        TooltipRow('Volume: ${vf(s.volume)} (${(s.volume / total * 100).toStringAsFixed(1)}%)'),
        if (s.price != null) TooltipRow('Price: ${(w.priceFormat ?? formatNumber)(s.price!)}'),
      ]);
    }
  }

  /// Draws the symbol and the signed percentage centred in [rect]. Font sizes
  /// follow the tile size and shrink until the text fits; labels that cannot
  /// fit at a readable size are left out.
  void _label(Canvas canvas, MarketTile s, Rect rect, double alpha, String Function(double) pct) {
    var fs = (math.sqrt(rect.width * rect.height) * .2).clamp(8.0, 22.0).toDouble();
    TextStyle symStyle(double f) => TextStyle(color: Colors.white.faded(alpha), fontSize: f, fontWeight: FontWeight.w700, height: 1.1);
    while (fs > 7 && measureText(s.symbol, symStyle(fs)).width > rect.width - 10) {
      fs -= 1; // shrink until the symbol fits the width
    }
    if (measureText(s.symbol, symStyle(fs)).width > rect.width - 6 || rect.height < fs + 6) return;

    final arrow = s.changePercent > 0 ? '↑ ' : (s.changePercent < 0 ? '↓ ' : '');
    final change = '${w.showArrows ? arrow : ''}${pct(s.changePercent.abs())}%';
    var cf = fs * .78;
    TextStyle chStyle(double f) => TextStyle(color: Colors.white.faded(alpha), fontSize: f, fontWeight: FontWeight.w600, height: 1.1);
    while (cf > 6.5 && measureText(change, chStyle(cf)).width > rect.width - 6) {
      cf -= .5;
    }
    final twoLines = rect.height >= fs + cf + 12 && measureText(change, chStyle(cf)).width <= rect.width - 4;
    if (twoLines) {
      paintText(canvas, s.symbol, rect.center - Offset(0, cf * .62), symStyle(fs), maxWidth: rect.width - 4);
      paintText(canvas, change, rect.center + Offset(0, fs * .62), chStyle(cf), maxWidth: rect.width - 2);
    } else {
      paintText(canvas, s.symbol, rect.center, symStyle(fs), maxWidth: rect.width - 4);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
