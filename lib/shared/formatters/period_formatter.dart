import 'dart:ui';

import 'package:intl/intl.dart';

enum PeriodLabelGranularity { day, month, year }

String canonicalMonthPeriod(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

String localizedPeriodLabel(
  DateTime date, {
  required Locale locale,
  required PeriodLabelGranularity granularity,
}) {
  final localeName = locale.toLanguageTag();
  return switch (granularity) {
    PeriodLabelGranularity.day => DateFormat.yMMMMd(localeName).format(date),
    PeriodLabelGranularity.month => DateFormat.yMMMM(localeName).format(date),
    PeriodLabelGranularity.year => DateFormat.y(localeName).format(date),
  };
}
