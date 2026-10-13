import 'package:cashlenx/features/budget/data/budget_repository.dart';
import 'package:cashlenx/features/budget/domain/budget_models.dart';
import 'package:cashlenx/features/budget/presentation/budget_tab.dart';
import 'package:cashlenx/features/home/presentation/providers/currency_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses ISO minor-unit precision for supported currencies', () {
    expect(CurrencyOption.usd.minorUnitDigits, 2);
    expect(CurrencyOption.sgd.minorUnitDigits, 2);
    expect(CurrencyOption.jpy.minorUnitDigits, 0);
    expect(CurrencyOption.krw.minorUnitDigits, 0);
    expect(CurrencyOption.vnd.minorUnitDigits, 0);
  });

  testWidgets('uses the selected multi-character symbol on compact layouts', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currencyProvider.overrideWith(_SgdCurrencyNotifier.new),
          monthlyBudgetsProvider.overrideWith((ref, period) async {
            return [
              BudgetItem(
                id: 'budget-1',
                categoryId: 'category-1',
                categoryName: 'Dining',
                period: period,
                limit: 1000,
                spent: 250,
              ),
            ];
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: BudgetTab())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(r'S$1,000.00'), findsOneWidget);
    expect(find.text(r'Spent: S$250.00'), findsOneWidget);
    expect(find.text(r'Remaining: S$750.00'), findsOneWidget);
    expect(find.bySemanticsLabel('Add budget'), findsOneWidget);
    expect(find.bySemanticsLabel('Previous month'), findsOneWidget);
    expect(find.bySemanticsLabel('Next month'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(r'S$250.00 / S$1,000.00'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(r'S$250.00 / S$1,000.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('zero-decimal budget values reconcile when over budget', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currencyProvider.overrideWith(_JpyCurrencyNotifier.new),
          monthlyBudgetsProvider.overrideWith((ref, period) async {
            return [
              BudgetItem(
                id: 'budget-1',
                categoryId: 'category-1',
                categoryName: 'Dining',
                period: period,
                limit: 1000.4,
                spent: 1000.6,
              ),
              BudgetItem(
                id: 'budget-2',
                categoryId: 'category-2',
                categoryName: 'Transport',
                period: period,
                limit: 1.4,
                spent: 0.6,
              ),
            ];
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: BudgetTab())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('¥1,002'), findsOneWidget);
    expect(find.text('Spent: ¥1,001'), findsOneWidget);
    expect(find.text('Remaining: ¥1'), findsOneWidget);
    expect(find.text('¥1,001 / ¥1,000'), findsOneWidget);
    expect(find.text('100% used'), findsOneWidget);
    expect(find.text('43% used'), findsOneWidget);
  });
}

class _SgdCurrencyNotifier extends CurrencyNotifier {
  @override
  CurrencyOption build() => CurrencyOption.sgd;
}

class _JpyCurrencyNotifier extends CurrencyNotifier {
  @override
  CurrencyOption build() => CurrencyOption.jpy;
}
