import 'package:cashlenx/features/statistics/data/statistics_repository.dart';
import 'package:cashlenx/features/home/presentation/providers/currency_provider.dart';
import 'package:cashlenx/features/statistics/domain/statistics_snapshot.dart';
import 'package:cashlenx/features/statistics/presentation/analytics_context.dart';
import 'package:cashlenx/features/statistics/presentation/statistics_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('changes range and preserves twelve months on compact layouts', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currencyProvider.overrideWith(_HkdCurrencyNotifier.new),
          statisticsProvider.overrideWith((ref, query) async {
            final count = query.range == AnalyticsRange.year ? 12 : 1;
            return StatisticsSnapshot(
              range: query.range,
              date: query.date,
              income: 1200,
              expense: 600,
              balance: 600,
              transactionCount: 12,
              seriesLabels: List.generate(
                count,
                (index) => '${index + 1}'.padLeft(2, '0'),
              ),
              seriesIncome: List.generate(count, (index) => index * 100),
              seriesExpense: List.generate(count, (index) => index * 50),
              topExpenses: const [],
            );
          }),
        ],
        child: const MaterialApp(home: StatisticsPage(onBack: _noop)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Day'), findsOneWidget);
    expect(find.text(r'HK$1,200'), findsOneWidget);
    expect(find.text(r'HK$600'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('statistics-period-selector')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    expect(find.bySemanticsLabel('Previous period'), findsOneWidget);
    expect(find.bySemanticsLabel('Next period'), findsOneWidget);

    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('statistics-series-chart')),
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
    semantics.dispose();
  });

  testWidgets('period navigation reloads the selected range', (tester) async {
    final queries = <StatisticsQuery>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          statisticsProvider.overrideWith((ref, query) async {
            queries.add(query);
            return StatisticsSnapshot(
              range: query.range,
              date: query.date,
              income: 0,
              expense: 0,
              balance: 0,
              transactionCount: 0,
              seriesLabels: const ['01'],
              seriesIncome: const [0],
              seriesExpense: const [0],
              topExpenses: const [],
            );
          }),
        ],
        child: const MaterialApp(home: StatisticsPage(onBack: _noop)),
      ),
    );
    await tester.pumpAndSettle();
    final initialDate = queries.last.date;

    await tester.tap(find.byKey(const ValueKey('statistics-previous-period')));
    await tester.pumpAndSettle();

    expect(queries.last.range, AnalyticsRange.day);
    expect(queries.last.date, initialDate.subtract(const Duration(days: 1)));
  });
}

void _noop() {}

class _HkdCurrencyNotifier extends CurrencyNotifier {
  @override
  CurrencyOption build() => CurrencyOption.hkd;
}
