String formatGrouped(num value) {
  final negative = value < 0;
  final digits = value.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return negative ? '-$buffer' : '$buffer';
}

String formatPkr(num value) {
  final whole = (value - value.truncateToDouble()).abs() < 0.0000001;
  final body = whole ? formatGrouped(value.round()) : _fixedGrouped(value);
  if (body.startsWith('-')) return '-PKR ${body.substring(1)}';
  return 'PKR $body';
}

String _fixedGrouped(num value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  buffer.write('.');
  buffer.write(parts[1]);
  return negative ? '-$buffer' : '$buffer';
}

String formatAdminDay(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String formatAdminTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String formatAdminStamp(DateTime date) =>
    '${formatAdminDay(date)} · ${formatAdminTime(date)}';
