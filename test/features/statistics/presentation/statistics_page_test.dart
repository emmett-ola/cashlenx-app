import 'package:cashlenx/features/statistics/data/statistics_repository.dart';
import 'package:cashlenx/features/statistics/domain/statistics_snapshot.dart';
import 'package:cashlenx/features/statistics/presentation/statistics_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows all twelve months on a compact viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          yearlyStatisticsProvider.overrideWith(
            (ref, year) async => StatisticsSnapshot(
              year: year,
              income: 1200,
              expense: 600,
              balance: 600,
              transactionCount: 12,
              months: const [
                '01',
                '02',
                '03',
                '04',
                '05',
                '06',
                '07',
                '08',
                '09',
                '10',
                '11',
                '12',
              ],
              monthlyIncome: List.generate(12, (index) => index * 100),
              monthlyExpense: List.generate(12, (index) => index * 50),
              topExpenses: const [],
            ),
          ),
        ],
        child: const MaterialApp(home: StatisticsPage(onBack: _noop)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('monthly-comparison-chart')),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    for (final month in const [
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
    ]) {
      expect(find.text(month), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
