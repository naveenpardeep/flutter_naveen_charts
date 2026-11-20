// Date helpers shared by the time charts: "nice" axis ticks and formatting.

const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// `Mar 5, 2026`.
String formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// `Mar 5`.
String formatShortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

/// Short month name for a 1-based month number.
String monthName(int month) => _months[(month - 1) % 12];

/// One labelled position on a date axis.
class TimeTick {
  const TimeTick(this.date, this.label);
  final DateTime date;
  final String label;
}

/// A step size for the date axis: [unit] is `h`, `d`, `m` or `y`.
class _Step {
  const _Step(this.unit, this.step, this.days);
  final String unit;
  final int step;

  /// Approximate length of one step in days (used to count ticks).
  final double days;
}

const List<_Step> _steps = [
  _Step('h', 1, 1 / 24), _Step('h', 3, 3 / 24), _Step('h', 6, .25), _Step('h', 12, .5),
  _Step('d', 1, 1), _Step('d', 2, 2), _Step('d', 7, 7), _Step('d', 14, 14),
  _Step('m', 1, 30.4), _Step('m', 2, 61), _Step('m', 3, 91), _Step('m', 6, 182),
  _Step('y', 1, 365), _Step('y', 2, 730), _Step('y', 5, 1826), _Step('y', 10, 3652),
  _Step('y', 20, 7305), _Step('y', 50, 18262), _Step('y', 100, 36525),
];

/// Calendar-aligned ticks between [lo] and [hi]: whole hours, days, months or
/// years, whichever gives at most [maxTicks] labels.
List<TimeTick> niceTimeTicks(DateTime lo, DateTime hi, {int maxTicks = 7}) {
  final days = hi.difference(lo).inSeconds / 86400.0;
  if (days <= 0) return [TimeTick(lo, formatShortDate(lo))];

  // 1. pick the smallest step that does not produce too many ticks
  final step = _steps.firstWhere((s) => days / s.days <= maxTicks, orElse: () => _steps.last);

  // 2. start at the calendar boundary at or before `lo`
  DateTime floorTo(DateTime d) {
    switch (step.unit) {
      case 'h':
        return DateTime(d.year, d.month, d.day, (d.hour ~/ step.step) * step.step);
      case 'd':
        return DateTime(d.year, d.month, d.day);
      case 'm':
        return DateTime(d.year, ((d.month - 1) ~/ step.step) * step.step + 1);
      default:
        return DateTime((d.year ~/ step.step) * step.step);
    }
  }

  // 3. DateTime's constructor normalises overflow (month 13 -> January next year)
  DateTime advance(DateTime d) {
    switch (step.unit) {
      case 'h':
        return DateTime(d.year, d.month, d.day, d.hour + step.step);
      case 'd':
        return DateTime(d.year, d.month, d.day + step.step);
      case 'm':
        return DateTime(d.year, d.month + step.step);
      default:
        return DateTime(d.year + step.step);
    }
  }

  String label(DateTime d) {
    switch (step.unit) {
      case 'h':
        return d.hour == 0 ? formatShortDate(d) : '${d.hour.toString().padLeft(2, '0')}:00';
      case 'd':
        return formatShortDate(d);
      case 'm':
        return d.month == 1 ? '${d.year}' : monthName(d.month);
      default:
        return '${d.year}';
    }
  }

  final out = <TimeTick>[];
  var t = floorTo(lo);
  for (var guard = 0; guard < 600 && !t.isAfter(hi); guard++) {
    if (!t.isBefore(lo)) out.add(TimeTick(t, label(t)));
    t = advance(t);
  }
  return out;
}

/// Fraction (0..1) of [d] between [lo] and [hi].
double timeFraction(DateTime d, DateTime lo, DateTime hi) {
  final span = hi.millisecondsSinceEpoch - lo.millisecondsSinceEpoch;
  return span == 0 ? 0 : (d.millisecondsSinceEpoch - lo.millisecondsSinceEpoch) / span;
}
