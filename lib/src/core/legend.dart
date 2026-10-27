import 'package:flutter/material.dart';
import 'chart_theme.dart';

class LegendItem {
  const LegendItem(this.label, this.color);
  final String label;
  final Color color;
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.items, this.theme});
  final List<LegendItem> items;
  final ChartTheme? theme;

  @override
  Widget build(BuildContext context) {
    final t = theme ?? ChartTheme.of(context);
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        for (final i in items)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: i.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(i.label, style: t.labelStyle),
          ]),
      ],
    );
  }
}
