import 'package:cashlenx/features/budget/data/budget_repository.dart';
import 'package:cashlenx/features/budget/domain/budget_models.dart';
import 'package:cashlenx/features/budget/presentation/budget_tab.dart';
import 'package:cashlenx/features/home/presentation/providers/currency_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    expect(find.text(r'S$1,000'), findsOneWidget);
    expect(find.text(r'Spent: S$250'), findsOneWidget);
    expect(find.text(r'Remaining: S$750'), findsOneWidget);
    expect(find.bySemanticsLabel('Add budget'), findsOneWidget);
    expect(find.bySemanticsLabel('Previous month'), findsOneWidget);
    expect(find.bySemanticsLabel('Next month'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(r'S$250 / S$1,000'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(r'S$250 / S$1,000'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

class _SgdCurrencyNotifier extends CurrencyNotifier {
  @override
  CurrencyOption build() => CurrencyOption.sgd;
}
