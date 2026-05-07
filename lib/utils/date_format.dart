String formatTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final targetDay = DateTime(dt.year, dt.month, dt.day);
  final differenceInDays = today.difference(targetDay).inDays;

  if (differenceInDays == 0) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  if (differenceInDays == 1) {
    return 'Dün';
  }

  if (differenceInDays > 1 && differenceInDays < 7) {
    const shortDays = <int, String>{
      DateTime.monday: 'Pzt',
      DateTime.tuesday: 'Sal',
      DateTime.wednesday: 'Çar',
      DateTime.thursday: 'Per',
      DateTime.friday: 'Cum',
      DateTime.saturday: 'Cmt',
      DateTime.sunday: 'Paz',
    };
    return shortDays[dt.weekday] ?? '';
  }

  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final year = dt.year.toString();
  return '$day.$month.$year';
}