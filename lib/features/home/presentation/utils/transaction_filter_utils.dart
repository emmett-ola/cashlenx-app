DateTime calendarDate(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

bool isValidInclusiveDateRange({DateTime? from, DateTime? to}) {
  if (from == null || to == null) return true;
  return !calendarDate(from).isAfter(calendarDate(to));
}

bool isWithinInclusiveDateRange(
  DateTime value, {
  DateTime? from,
  DateTime? to,
}) {
  if (!isValidInclusiveDateRange(from: from, to: to)) return false;

  final date = calendarDate(value);
  if (from != null && date.isBefore(calendarDate(from))) return false;
  if (to != null && date.isAfter(calendarDate(to))) return false;
  return true;
}
