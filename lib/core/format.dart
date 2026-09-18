// Framework-free formatting helpers.

/// Formats a number with South Asian digit grouping (e.g. 384200 -> "3,84,200").
/// Values are rounded to the nearest whole number, per the design spec.
String formatGroupedNumber(num value) {
  final isNegative = value < 0;
  final rounded = value.abs().round();
  final digits = rounded.toString();

  if (digits.length <= 3) {
    return isNegative ? '-$digits' : digits;
  }

  final lastThree = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final pairs = <String>[];
  while (rest.length > 2) {
    pairs.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) pairs.insert(0, rest);

  final grouped = '${pairs.join(',')},$lastThree';
  return isNegative ? '-$grouped' : grouped;
}

/// Formats a PKR amount, e.g. 384200 -> "Rs 3,84,200".
String formatPkrCurrency(num value) => 'Rs ${formatGroupedNumber(value)}';

/// yyyy-MM-dd, the format Entry.date is stored/compared as.
String formatDateIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// 'yyyy-MM' -> 'Month yyyy', e.g. '2026-09' -> 'September 2026'.
String formatMonthLabel(String monthKey) {
  final parts = monthKey.split('-');
  final month = int.parse(parts[1]);
  return '${_monthNames[month - 1]} ${parts[0]}';
}
