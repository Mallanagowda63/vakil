const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "14:05"
String clockTime(DateTime time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// "Today", "Yesterday" or "3 Sep 2026" for date separators.
String dayLabel(DateTime time) {
  final now = DateTime.now();
  if (sameDay(time, now)) return 'Today';
  if (sameDay(time, now.subtract(const Duration(days: 1)))) return 'Yesterday';
  return '${time.day} ${_months[time.month - 1]} ${time.year}';
}

/// Chat-list time: clock time today, "Yesterday", or a short date.
String listTime(DateTime time) {
  final now = DateTime.now();
  if (sameDay(time, now)) return clockTime(time);
  if (sameDay(time, now.subtract(const Duration(days: 1)))) return 'Yesterday';
  return '${time.day} ${_months[time.month - 1]}';
}

/// "last seen today at 14:05" / "last seen 3 Sep at 14:05"
String lastSeenLabel(DateTime? time) {
  if (time == null) return 'offline';
  final day = sameDay(time, DateTime.now()) ? 'today' : dayLabel(time) == 'Yesterday' ? 'yesterday' : '${time.day} ${_months[time.month - 1]}';
  return 'last seen $day at ${clockTime(time)}';
}

/// "0:42" for countdowns.
String countdown(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// "3:25", or "1:02:07" after an hour, for the running chat time.
String elapsedLabel(int seconds) {
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = (seconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}
