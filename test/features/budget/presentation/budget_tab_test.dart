import 'package:cashlenx/core/i18n/app_i18n.dart';
import 'package:cashlenx/features/budget/data/budget_repository.dart';
import 'package:cashlenx/features/budget/domain/budget_models.dart';
import 'package:cashlenx/features/budget/presentation/budget_tab.dart';
import 'package:cashlenx/features/home/presentation/providers/currency_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'app_language': 'en'}));

  for (final language in AppLanguage.values) {
    testWidgets('localizes core budget icon semantics in ${language.name}', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final container = ProviderContainer(
        overrides: [
          monthlyBudgetsProvider.overrideWith((ref, period) async => const []),
        ],
      );
      addTearDown(container.dispose);
      await container.read(i18nProvider.notifier).setLanguage(language);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: language.locale,
            supportedLocales: AppLanguage.values.map(
              (language) => language.locale,
            ),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            home: Scaffold(body: BudgetTab(initialMonth: DateTime(2026, 10))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final translations = AppTranslations(language);
      for (final key in ['add_budget', 'previous_month', 'next_month']) {
        expect(
          find.bySemanticsLabel(translations(key)),
          findsAtLeastNWidgets(1),
        );
      }
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('localizes month labels without changing budget query periods', (
    tester,
  ) async {
    final requestedPeriods = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyBudgetsProvider.overrideWith((ref, period) async {
            requestedPeriods.add(period);
            return const [];
          }),
        ],
        child: MaterialApp(
          locale: const Locale('zh', 'TW'),
          supportedLocales: const [Locale('en'), Locale('zh', 'TW')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: Scaffold(body: BudgetTab(initialMonth: DateTime(2026, 12))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2026年12月'), findsOneWidget);
    expect(requestedPeriods.last, '2026-12');

    await tester.tap(find.bySemanticsLabel('Next month'));
    await tester.pumpAndSettle();

    expect(find.text('2027年1月'), findsOneWidget);
    expect(requestedPeriods.last, '2027-01');

    await tester.tap(find.bySemanticsLabel('Previous month'));
    await tester.pumpAndSettle();

    expect(find.text('2026年12月'), findsOneWidget);
    expect(requestedPeriods, ['2026-12', '2027-01']);
  });

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
