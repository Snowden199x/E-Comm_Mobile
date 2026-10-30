const List<String> _months = [
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

const List<String> _weekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

String timeLabel(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $suffix';
}

/// "Today", "Tomorrow", "Yesterday", or "Sat, 31 Oct".
String dayLabel(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(value.year, value.month, value.day);
  final difference = day.difference(today).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Tomorrow';
  if (difference == -1) return 'Yesterday';
  return '${_weekdays[value.weekday - 1]}, ${value.day} '
      '${_months[value.month - 1]}';
}

/// "Today · 8:00 AM".
String dateTimeLabel(DateTime value) => '${dayLabel(value)} · ${timeLabel(value)}';

/// "Thu, 30 Oct 2026".
String fullDateLabel(DateTime value) =>
    '${_weekdays[value.weekday - 1]}, ${value.day} '
    '${_months[value.month - 1]} ${value.year}';

/// "30 Oct 2026".
String shortDateLabel(DateTime value) =>
    '${value.day} ${_months[value.month - 1]} ${value.year}';
