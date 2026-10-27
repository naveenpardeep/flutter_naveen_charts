import 'package:flutter/material.dart';

extension ColorFade on Color {
  /// This color at the given opacity (0..1).
  Color faded(double opacity) =>
      withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
}

const List<Color> _tableau10 = [
  Color(0xFF4E79A7),
  Color(0xFFF28E2B),
  Color(0xFFE15759),
  Color(0xFF76B7B2),
  Color(0xFF59A14F),
  Color(0xFFEDC948),
  Color(0xFFB07AA1),
  Color(0xFFFF9DA7),
  Color(0xFF9C755F),
  Color(0xFFBAB0AC),
];

/// Colors and text styles shared by every chart.
class ChartTheme {
  const ChartTheme({
    required this.palette,
    required this.gridColor,
    required this.axisColor,
    required this.textColor,
    required this.labelStyle,
    required this.tooltipBackground,
    required this.tooltipStyle,
    required this.surface,
  });

  final List<Color> palette;
  final Color gridColor;
  final Color axisColor;
  final Color textColor;
  final TextStyle labelStyle;
  final Color tooltipBackground;
  final TextStyle tooltipStyle;

  /// Background the chart sits on (used for marker centers).
  final Color surface;

  factory ChartTheme.light() => const ChartTheme(
        palette: _tableau10,
        gridColor: Color(0xFFE0E0E0),
        axisColor: Color(0xFF9E9E9E),
        textColor: Color(0xFF212121),
        labelStyle: TextStyle(fontSize: 11, color: Color(0xFF616161)),
        tooltipBackground: Color(0xFF263238),
        tooltipStyle: TextStyle(fontSize: 12, color: Colors.white),
        surface: Colors.white,
      );

  factory ChartTheme.dark() => const ChartTheme(
        palette: _tableau10,
        gridColor: Color(0xFF37474F),
        axisColor: Color(0xFF78909C),
        textColor: Color(0xFFECEFF1),
        labelStyle: TextStyle(fontSize: 11, color: Color(0xFFB0BEC5)),
        tooltipBackground: Color(0xFFECEFF1),
        tooltipStyle: TextStyle(fontSize: 12, color: Color(0xFF212121)),
        surface: Color(0xFF1E1E1E),
      );

  /// Picks light or dark from the ambient [Theme].
  static ChartTheme of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? ChartTheme.dark()
          : ChartTheme.light();

  Color colorAt(int i) => palette[i % palette.length];

  ChartTheme copyWith({List<Color>? palette}) => ChartTheme(
        palette: palette ?? this.palette,
        gridColor: gridColor,
        axisColor: axisColor,
        textColor: textColor,
        labelStyle: labelStyle,
        tooltipBackground: tooltipBackground,
        tooltipStyle: tooltipStyle,
        surface: surface,
      );
}
