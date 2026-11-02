import 'package:flutter/material.dart';

/// One point. [size] turns a scatter point into a bubble.
class DataPoint {
  const DataPoint(this.x, this.y, {this.size});
  final double x;
  final double y;
  final double? size;

  /// Points at x = 0, 1, 2 ... (use with `xLabels`).
  static List<DataPoint> fromValues(List<double> values) => [
        for (var i = 0; i < values.length; i++) DataPoint(i.toDouble(), values[i])
      ];
}

enum BarMode { grouped, stacked }

enum GridMode { none, horizontal, vertical, both }

/// A horizontal guide line at a y value (targets, thresholds, averages).
class ReferenceLine {
  const ReferenceLine(this.value, {this.label, this.color, this.dashed = true});
  final double value;
  final String? label;
  final Color? color;
  final bool dashed;
}

abstract class CartesianSeries {
  const CartesianSeries({
    required this.name,
    required this.points,
    this.color,
    this.secondaryAxis = false,
  });
  final String name;
  final List<DataPoint> points;
  final Color? color;

  /// Plot against the right-hand y axis (lines, areas and scatter only).
  final bool secondaryAxis;
}

class LineSeries extends CartesianSeries {
  const LineSeries({
    required super.name,
    required super.points,
    super.color,
    super.secondaryAxis,
    this.curved = true,
    this.stepped = false,
    this.dashed = false,
    this.fill = false,
    this.strokeWidth = 2.5,
    this.showMarkers = true,
    this.markerRadius = 4,
  });

  LineSeries.fromValues({
    required String name,
    required List<double> values,
    Color? color,
    bool secondaryAxis = false,
    bool curved = true,
    bool stepped = false,
    bool dashed = false,
    bool fill = false,
    double strokeWidth = 2.5,
    bool showMarkers = true,
    double markerRadius = 4,
  }) : this(
            name: name,
            points: DataPoint.fromValues(values),
            color: color,
            secondaryAxis: secondaryAxis,
            curved: curved,
            stepped: stepped,
            dashed: dashed,
            fill: fill,
            strokeWidth: strokeWidth,
            showMarkers: showMarkers,
            markerRadius: markerRadius);

  final bool curved;
  final bool stepped;
  final bool dashed;
  final bool fill;
  final double strokeWidth;
  final bool showMarkers;
  final double markerRadius;
}

/// A line series with a gradient fill down to zero.
class AreaSeries extends LineSeries {
  const AreaSeries({
    required super.name,
    required super.points,
    super.color,
    super.secondaryAxis,
    super.curved,
    super.stepped,
    super.dashed,
    super.strokeWidth,
    super.showMarkers = false,
    super.markerRadius,
  }) : super(fill: true);

  AreaSeries.fromValues({
    required String name,
    required List<double> values,
    Color? color,
    bool secondaryAxis = false,
    bool curved = true,
  }) : this(
            name: name,
            points: DataPoint.fromValues(values),
            color: color,
            secondaryAxis: secondaryAxis,
            curved: curved);
}

class BarSeries extends CartesianSeries {
  const BarSeries(
      {required super.name,
      required super.points,
      super.color,
      this.cornerRadius = 4});

  BarSeries.fromValues(
      {required String name,
      required List<double> values,
      Color? color,
      double cornerRadius = 4})
      : this(
            name: name,
            points: DataPoint.fromValues(values),
            color: color,
            cornerRadius: cornerRadius);

  final double cornerRadius;
}

/// Scatter points; give points a `size` to get a bubble chart.
class ScatterSeries extends CartesianSeries {
  const ScatterSeries(
      {required super.name,
      required super.points,
      super.color,
      super.secondaryAxis,
      this.markerSize = 5,
      this.maxBubbleRadius = 26});
  final double markerSize;
  final double maxBubbleRadius;
}

/// Every look-and-feel switch of [CartesianChart] in one place.
class CartesianOptions {
  const CartesianOptions({
    this.title,
    this.xAxisTitle,
    this.yAxisTitle,
    this.secondaryAxisTitle,
    this.gridMode = GridMode.horizontal,
    this.dashedGrid = false,
    this.showLegend = true,
    this.showValueLabels = false,
    this.referenceLines = const [],
    this.zoomable = false,
    this.maxZoom = 12,
    this.yFormat,
    this.xFormat,
    this.secondaryYFormat,
    this.yMin,
    this.yMax,
    this.secondaryYMin,
    this.secondaryYMax,
    this.barWidthFactor = 0.72,
    this.interactive = true,
  });

  final String? title;
  final String? xAxisTitle;
  final String? yAxisTitle;
  final String? secondaryAxisTitle;
  final GridMode gridMode;
  final bool dashedGrid;
  final bool showLegend;
  final bool showValueLabels;
  final List<ReferenceLine> referenceLines;

  /// Pinch / drag / mouse-wheel zoom along x. Double-tap resets.
  final bool zoomable;
  final double maxZoom;
  final String Function(double)? yFormat;
  final String Function(double)? xFormat;
  final String Function(double)? secondaryYFormat;
  final double? yMin, yMax, secondaryYMin, secondaryYMax;

  /// Share of each category slot used by bars (0..1).
  final double barWidthFactor;
  final bool interactive;
}
