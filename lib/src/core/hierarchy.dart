import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Tree node shared by [TreemapChart] and [SunburstChart].
/// Leaves carry a [value]; parents sum their children.
class HierarchyNode {
  const HierarchyNode(this.label,
      {this.value = 0, this.children = const [], this.color});
  final String label;
  final double value;
  final List<HierarchyNode> children;
  final Color? color;

  double get total => children.isEmpty
      ? math.max(0.0, value)
      : children.fold<double>(0, (a, c) => a + c.total);

  int get depth => children.isEmpty
      ? 1
      : 1 + children.map((c) => c.depth).reduce(math.max);
}
