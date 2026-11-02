import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/chart_theme.dart';
import '../core/chart_utils.dart';
import 'cartesian_chart.dart';
import 'models.dart';

/// Line chart (curved, stepped, dashed lines via [LineSeries]).
class LineChart extends StatelessWidget {
  const LineChart(
      {super.key,
      required this.series,
      this.xLabels,
      this.options = const CartesianOptions(),
      this.aspectRatio = 1.6,
      this.theme});
  final List<LineSeries> series;
  final List<String>? xLabels;
  final CartesianOptions options;
  final double aspectRatio;
  final ChartTheme? theme;

  @override
  Widget build(BuildContext context) => CartesianChart(
      series: series,
      xLabels: xLabels,
      options: options,
      aspectRatio: aspectRatio,
      theme: theme);
}

/// Area chart: lines with a gradient fill. (See also `StackedAreaChart`.)
class AreaChart extends StatelessWidget {
  const AreaChart(
      {super.key,
      required this.series,
      this.xLabels,
      this.options = const CartesianOptions(),
      this.aspectRatio = 1.6,
      this.theme});
  final List<AreaSeries> series;
  final List<String>? xLabels;
  final CartesianOptions options;
  final double aspectRatio;
  final ChartTheme? theme;

  @override
  Widget build(BuildContext context) => CartesianChart(
      series: series,
      xLabels: xLabels,
      options: options,
      aspectRatio: aspectRatio,
      theme: theme);
}

/// Vertical bar chart; set [stacked] for stacked bars.
/// For horizontal bars see `HorizontalBarChart`.
class BarChart extends StatelessWidget {
  const BarChart(
      {super.key,
      required this.series,
      this.xLabels,
      this.stacked = false,
      this.options = const CartesianOptions(),
      this.aspectRatio = 1.6,
      this.theme});
  final List<BarSeries> series;
  final List<String>? xLabels;
  final bool stacked;
  final CartesianOptions options;
  final double aspectRatio;
  final ChartTheme? theme;

  @override
  Widget build(BuildContext context) => CartesianChart(
      series: series,
      xLabels: xLabels,
      barMode: stacked ? BarMode.stacked : BarMode.grouped,
      options: options,
      aspectRatio: aspectRatio,
      theme: theme);
}

typedef ColumnChart = BarChart;

/// Scatter chart. Give points a `size` and it becomes a bubble chart.
class ScatterChart extends StatelessWidget {
  const ScatterChart(
      {super.key,
      required this.series,
      this.options = const CartesianOptions(),
      this.aspectRatio = 1.4,
      this.theme});
  final List<ScatterSeries> series;
  final CartesianOptions options;
  final double aspectRatio;
  final ChartTheme? theme;

  @override
  Widget build(BuildContext context) => CartesianChart(
      series: series, options: options, aspectRatio: aspectRatio, theme: theme);
}

typedef BubbleChart = ScatterChart;

/// Frequency histogram computed from raw [values].
class Histogram extends StatelessWidget {
  const Histogram(
      {super.key,
      required this.values,
      this.bins = 10,
      this.color,
      this.options = const CartesianOptions(showLegend: false),
      this.aspectRatio = 1.6,
      this.theme});
  final List<double> values;
  final int bins;
  final Color? color;
  final CartesianOptions options;
  final double aspectRatio;
  final ChartTheme? theme;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final width = (hi - lo) == 0 ? 1.0 : (hi - lo) / bins;
    final counts = List<double>.filled(bins, 0);
    for (final v in values) {
      var i = ((v - lo) / width).floor();
      if (i >= bins) i = bins - 1;
      counts[i] += 1;
    }
    return CartesianChart(
      series: [BarSeries.fromValues(name: 'Count', values: counts, color: color)],
      xLabels: [for (var i = 0; i < bins; i++) formatNumber(lo + i * width)],
      options: options,
      aspectRatio: aspectRatio,
      theme: theme,
    );
  }
}
