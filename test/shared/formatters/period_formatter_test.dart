import 'dart:ui';

import 'package:cashlenx/shared/formatters/period_formatter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  final date = DateTime(2026, 10, 13);

  setUpAll(initializeDateFormatting);

  test('keeps canonical month periods stable for API queries', () {
    expect(canonicalMonthPeriod(date), '2026-10');
    expect(canonicalMonthPeriod(DateTime(2027, 1)), '2027-01');
  });

  test('formats month labels naturally for every supported locale', () {
    expect(
      localizedPeriodLabel(
        date,
        locale: const Locale('en'),
        granularity: PeriodLabelGranularity.month,
      ),
      'October 2026',
    );
    expect(
      localizedPeriodLabel(
        date,
        locale: const Locale('zh', 'CN'),
        granularity: PeriodLabelGranularity.month,
      ),
      '2026年10月',
    );
    expect(
      localizedPeriodLabel(
        date,
        locale: const Locale('zh', 'TW'),
        granularity: PeriodLabelGranularity.month,
      ),
      '2026年10月',
    );
  });

  test('uses the same locale-aware boundary for day and year labels', () {
    expect(
      localizedPeriodLabel(
        date,
        locale: const Locale('en'),
        granularity: PeriodLabelGranularity.day,
      ),
      'October 13, 2026',
    );
    expect(
      localizedPeriodLabel(
        date,
        locale: const Locale('zh', 'CN'),
        granularity: PeriodLabelGranularity.year,
      ),
      '2026年',
    );
  });
}
