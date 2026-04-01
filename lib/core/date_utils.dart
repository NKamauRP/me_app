class AppDateUtils {
  static String toStorageDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');

    return '${normalized.year}-$month-$day';
  }

  static DateTime parseStorageDate(String value) {
    final segments = value.split('-');
    return DateTime(
      int.parse(segments[0]),
      int.parse(segments[1]),
      int.parse(segments[2]),
    );
  }

  static bool isYesterday(String? lastCheckinDate, DateTime today) {
    if (lastCheckinDate == null || lastCheckinDate.isEmpty) {
      return false;
    }

    final normalizedToday = DateTime(today.year, today.month, today.day);
    final previousDate = parseStorageDate(lastCheckinDate);

    return normalizedToday.difference(previousDate).inDays == 1;
  }

  static String readableDate(String value) {
    const months = <String>[
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

    final parsed = parseStorageDate(value);

    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }

  static List<DateTime> lastNDates(
    int count, {
    DateTime? endDate,
  }) {
    final anchor = endDate ?? DateTime.now();
    final normalized = DateTime(anchor.year, anchor.month, anchor.day);

    return List<DateTime>.generate(
      count,
      (index) => normalized.subtract(Duration(days: count - index - 1)),
    );
  }

  static String shortWeekday(DateTime date) {
    const weekdays = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return weekdays[date.weekday - 1];
  }
}
