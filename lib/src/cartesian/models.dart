import 'package:flutter/material.dart';

/// One point. [size] turns a scatter point into a bubble.
class DataPoint {
  const DataPoint(this.x, this.y, {this.size});
  final double x;
  final double y;
  final double? size;

  /// Points at x = 0, 1, 2 ... (use with `xLabels`).
  static List<DataPoint> fromValues(List<double> values) =>
      [for (var i = 0; i < values.length; i++) DataPoint(i.toDouble(), values[i])];
}

enum BarMode { grouped, stacked }

abstract class CartesianSeries {
  const CartesianSeries(
      {required this.name, required this.points, this.color});
  final String name;
  final List<DataPoint> points;
  final Color? color;
}

class LineSeries extends CartesianSeries {
  const LineSeries({
    required super.name,
    required super.points,
    super.color,
    this.curved = true,
    this.stepped = false,
    this.dashed = false,
    this.fill = false,
    this.strokeWidth = 2.5,
    this.showMarkers = true,
  });

  LineSeries.fromValues({
    required String name,
    required List<double> values,
    Color? color,
    bool curved = true,
    bool stepped = false,
    bool dashed = false,
    bool fill = false,
    double strokeWidth = 2.5,
    bool showMarkers = true,
  }) : this(
            name: name,
            points: DataPoint.fromValues(values),
            color: color,
            curved: curved,
            stepped: stepped,
            dashed: dashed,
            fill: fill,
            strokeWidth: strokeWidth,
            showMarkers: showMarkers);

  final bool curved;
  final bool stepped;
  final bool dashed;
  final bool fill;
  final double strokeWidth;
  final bool showMarkers;
}

/// A line series with a gradient fill down to zero.
class AreaSeries extends LineSeries {
  const AreaSeries({
    required super.name,
    required super.points,
    super.color,
    super.curved,
    super.stepped,
    super.dashed,
    super.strokeWidth,
    super.showMarkers = false,
  }) : super(fill: true);

  AreaSeries.fromValues({
    required String name,
    required List<double> values,
    Color? color,
    bool curved = true,
  }) : this(
            name: name,
            points: DataPoint.fromValues(values),
            color: color,
            curved: curved);
}

class BarSeries extends CartesianSeries {
  const BarSeries({required super.name, required super.points, super.color});

  BarSeries.fromValues(
      {required String name, required List<double> values, Color? color})
      : this(name: name, points: DataPoint.fromValues(values), color: color);
}

/// Scatter points; give points a `size` to get a bubble chart.
class ScatterSeries extends CartesianSeries {
  const ScatterSeries(
      {required super.name,
      required super.points,
      super.color,
      this.markerSize = 5});
  final double markerSize;
}
