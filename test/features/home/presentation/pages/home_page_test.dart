import 'dart:async';

import 'package:cashlenx/features/auth/domain/models/user.dart';
import 'package:cashlenx/features/auth/presentation/providers/auth_provider.dart';
import 'package:cashlenx/features/home/presentation/pages/home_page.dart';
import 'package:cashlenx/features/home/presentation/providers/app_release_identity_provider.dart';
import 'package:cashlenx/features/home/presentation/providers/currency_provider.dart';
import 'package:cashlenx/features/statistics/presentation/analytics_context.dart';
import 'package:cashlenx/network/api_client.dart';
import 'package:cashlenx/network/cashlenx_api.dart';
import 'package:cashlenx/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  for (final layout in <String, Size>{
    'compact': const Size(320, 844),
    'wide': const Size(1200, 844),
  }.entries) {
    testWidgets(
      'keeps preferences owned by Settings on ${layout.key} layouts',
      (tester) async {
        await tester.binding.setSurfaceSize(layout.value);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authNotifierProvider.overrideWith(_TestAuthNotifier.new),
              cashlenxApiProvider.overrideWithValue(_FakeCashlenxApi()),
            ],
            child: const MaterialApp(home: HomePage()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Settings').last);
        await tester.pumpAndSettle();

        expect(find.text('Preferences'), findsOneWidget);
        expect(find.text('Theme'), findsOneWidget);
        expect(find.text('Currency'), findsOneWidget);
        expect(find.text('Language'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('renders mock dashboard and shell navigation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_TestAuthNotifier.new),
          cashlenxApiProvider.overrideWithValue(_FakeCashlenxApi()),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('Today Balance'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Year'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text(r'$128.45'), findsOneWidget);
    expect(find.text('Coffee beans'), findsOneWidget);
    expect(find.text('-\$12.50'), findsOneWidget);
    expect(find.text('+\$3,500.00'), findsOneWidget);
    expect(find.text('\u{1F35C}'), findsOneWidget);
    expect(find.text('\u{1F4BC}'), findsOneWidget);

    final expenseAmount = tester.widget<Text>(find.text('-\$12.50'));
    final incomeAmount = tester.widget<Text>(find.text('+\$3,500.00'));
    expect(expenseAmount.style?.color, AppTheme.errorColor);
    expect(incomeAmount.style?.color, AppTheme.successColor);

    await tester.tap(find.text('See All'));
    await tester.pumpAndSettle();

    expect(find.text('Transactions'), findsNWidgets(2));
    expect(find.byIcon(Icons.filter_list), findsOneWidget);
    expect(find.bySemanticsLabel('Filter transactions'), findsOneWidget);
    expect(find.text('Coffee beans'), findsOneWidget);
    expect(find.text('+\$3,500.00'), findsOneWidget);
    expect(find.text('\u{1F35C}'), findsOneWidget);
    expect(find.text('\u{1F4BC}'), findsOneWidget);
    final allTransactionsIncome = tester.widget<Text>(find.text('+\$3,500.00'));
    expect(allTransactionsIncome.style?.color, AppTheme.successColor);
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Total'));
    await tester.pumpAndSettle();

    expect(find.text('Total Balance'), findsOneWidget);
    expect(find.text(r'$88,000.00'), findsOneWidget);

    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();

    expect(find.text('Year Balance'), findsOneWidget);
    expect(find.text(r'$39,420.25'), findsOneWidget);

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();

    expect(find.text('Month Balance'), findsOneWidget);
    expect(find.text(r'$4,225.50'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Financial Insights'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Financial Insights'), findsOneWidget);
    expect(find.text('Spending by Category'), findsNothing);
    expect(
      find.byKey(const ValueKey('financial-insights-entry')),
      findsOneWidget,
    );

    await tester.tap(find.text('Budget').last);
    await tester.pumpAndSettle();

    expect(find.text('Manage your spending limits'), findsOneWidget);
    expect(find.text('Category Budgets'), findsOneWidget);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Resource Management'), findsOneWidget);
    expect(find.text('Category Management'), findsOneWidget);
    expect(find.text('Currency'), findsOneWidget);
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('More Setting'), findsNothing);

    await tester.tap(find.text('Category Management'));
    await tester.pumpAndSettle();

    expect(find.text('Manage your categories'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Food & Dining'), findsOneWidget);
    expect(find.text('\u{1F35C}'), findsOneWidget);
    expect(find.text('Restaurants'), findsOneWidget);
    expect(find.text('\u{1F642}'), findsAtLeastNWidgets(1));
    expect(find.text('Create New Category'), findsOneWidget);

    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();

    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Bonus'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Resource Management'), findsOneWidget);

    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Financial Insights'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See where every dollar goes'));
    await tester.pumpAndSettle();

    expect(find.text('More Statistics'), findsOneWidget);
    expect(find.text('Income & Expense Trend'), findsOneWidget);
    expect(find.text('Top Expenses'), findsOneWidget);
    final rangeSelector = tester.widget<SegmentedButton<AnalyticsRange>>(
      find.byKey(const ValueKey('statistics-range-selector')),
    );
    expect(rangeSelector.selected, {AnalyticsRange.month});

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();

    expect(find.text('Add Transaction'), findsAtLeastNWidgets(1));
    expect(find.text('Amount'), findsOneWidget);
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete digit'), findsOneWidget);
    await tester.tap(find.text('Show Details'));
    await tester.pumpAndSettle();
    expect(find.text('Category'), findsAtLeastNWidgets(1));
  });

  testWidgets('dashboard financial insights replaces the category breakdown', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_UserAuthNotifier.new),
          cashlenxApiProvider.overrideWithValue(_FakeCashlenxApi()),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.text('Month Balance'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Financial Insights'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('financial-insights-entry')),
      findsOneWidget,
    );
    expect(find.text('Spending by Category'), findsNothing);
    expect(find.text('No data for this period'), findsNothing);
    expect(find.text('Day Category'), findsNothing);
  });

  testWidgets('currency changes update recent activity and transactions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_TestAuthNotifier.new),
          cashlenxApiProvider.overrideWithValue(_FakeCashlenxApi()),
          currencyProvider.overrideWith(_MutableCurrencyNotifier.new),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(r'-$12.50'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomePage)),
    );
    (container.read(currencyProvider.notifier) as _MutableCurrencyNotifier)
        .setForTest(CurrencyOption.sgd);
    await tester.pump();

    expect(find.text(r'S$128.45'), findsOneWidget);
    expect(find.text(r'-S$12.50'), findsOneWidget);
    expect(find.text(r'+S$3,500.00'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('See All'));
    await tester.pumpAndSettle();
    expect(find.text(r'-S$12.50'), findsOneWidget);
    expect(find.text(r'+S$3,500.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard range survives scrolling rebuild refresh and stats', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_TestAuthNotifier.new),
          cashlenxApiProvider.overrideWithValue(_FakeCashlenxApi()),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today Balance'), findsOneWidget);
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.text('Month Balance'), findsOneWidget);

    final dashboardScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Financial Insights'),
      300,
      scrollable: dashboardScroll,
    );
    await tester.scrollUntilVisible(
      find.text('Month Balance'),
      -300,
      scrollable: dashboardScroll,
    );
    expect(find.text('Month Balance'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(391, 844));
    await tester.pumpAndSettle();
    expect(find.text('Month Balance'), findsOneWidget);

    await tester.tap(find.text('Transactions').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(find.text('Month Balance'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Financial Insights'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('See where every dollar goes'));
    await tester.pumpAndSettle();

    final rangeSelector = tester.widget<SegmentedButton<AnalyticsRange>>(
      find.byKey(const ValueKey('statistics-range-selector')),
    );
    expect(rangeSelector.selected, {AnalyticsRange.month});

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Month Balance'), findsOneWidget);
  });

  for (final scenario in <(HomeSection, String)>[
    (HomeSection.dashboard, 'Today Balance'),
    (HomeSection.categories, 'Category Management'),
    (HomeSection.budget, 'Manage your spending limits'),
    (HomeSection.settings, 'Preferences'),
    (HomeSection.transactions, 'Transactions'),
    (HomeSection.statistics, 'More Statistics'),
  ]) {
    testWidgets('renders ${scenario.$1.name} as a direct web destination', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(_TestAuthNotifier.new),
            cashlenxApiProvider.overrideWithValue(_FakeCashlenxApi()),
          ],
          child: MaterialApp(home: HomePage(section: scenario.$1)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text(scenario.$2), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('core navigation remains semantic at compact scaled text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_TestAuthNotifier.new),
          cashlenxApiProvider.overrideWithValue(_FakeCashlenxApi()),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.6),
            ),
            child: HomePage(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    for (final label in ['Home', 'Transactions', 'Add', 'Budget', 'Settings']) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('about dialog stays within the mobile content viewport', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'CashLenX',
      packageName: 'cashlenx',
      version: '1.0.8',
      buildNumber: '14',
      buildSignature: '',
    );

    for (final scenario in <(Size, double)>[
      (const Size(1280, 900), 1),
      (const Size(320, 568), 1),
      (const Size(320, 568), 1.8),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(scenario.$1);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(_TestAuthNotifier.new),
            cashlenxApiProvider.overrideWithValue(_FakeCashlenxApi()),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scenario.$2)),
              child: child!,
            ),
            home: HomePage(
              key: ValueKey('about-${scenario.$1}-${scenario.$2}'),
              section: HomeSection.settings,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (
        var attempt = 0;
        attempt < 4 && find.text('About').evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -360));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('About'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('About'));
      await tester.pumpAndSettle();

      final dialog = find.byType(Dialog);
      expect(dialog, findsOneWidget);
      final dialogSize = tester.getSize(
        find.byKey(const ValueKey('about-dialog-surface')),
      );
      expect(dialogSize.width, lessThanOrEqualTo(382));
      expect(dialogSize.height, lessThanOrEqualTo(scenario.$1.height - 48));
      expect(tester.takeException(), isNull);

      final dialogScroll = find.descendant(
        of: dialog,
        matching: find.byType(SingleChildScrollView),
      );
      expect(dialogScroll, findsOneWidget);
      final dialogScrollable = find.descendant(
        of: dialogScroll,
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Close'),
        160,
        scrollable: dialogScrollable,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
    }

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('about shows distinct app API and artifact identities', (
    tester,
  ) async {
    await _openAboutDialog(tester, _FakeCashlenxApi());
    await tester.pumpAndSettle();

    expect(find.text('App Version'), findsOneWidget);
    expect(find.text('1.0.9'), findsOneWidget);
    expect(find.text('API Version'), findsOneWidget);
    expect(find.text('1.0.4'), findsOneWidget);
    expect(find.text('Build Date'), findsOneWidget);
    expect(find.text('2026-10-12'), findsOneWidget);
    expect(find.text('Build Number'), findsNothing);
  });

  testWidgets('about keeps app identity visible while API identity loads', (
    tester,
  ) async {
    await _openAboutDialog(tester, _PendingVersionCashlenxApi());
    await tester.pump();

    expect(find.text('App Version'), findsOneWidget);
    expect(find.text('1.0.9'), findsOneWidget);
    expect(find.text('API Version'), findsOneWidget);
    expect(find.text('Loading…'), findsOneWidget);
    expect(find.text('Build Date'), findsOneWidget);
    expect(find.text('2026-10-12'), findsOneWidget);
  });

  testWidgets('about exposes retry when API identity is unavailable', (
    tester,
  ) async {
    final api = _UnavailableVersionCashlenxApi();
    await _openAboutDialog(tester, api);
    await tester.pumpAndSettle();

    expect(find.text('App Version'), findsOneWidget);
    expect(find.text('1.0.9'), findsOneWidget);
    expect(find.text('API Version'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(api.versionRequests, 2);
    expect(find.text('Unavailable'), findsOneWidget);
  });

  testWidgets('transaction filters expose feedback and empty recovery', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_TestAuthNotifier.new),
          cashlenxApiProvider.overrideWithValue(_FakeCashlenxApi()),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    await tester.tap(find.text('See All'));
    await tester.pumpAndSettle();
    expect(find.text('2 transactions'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    expect(find.text('Date Range'), findsOneWidget);
    expect(find.byKey(const ValueKey('transaction-date-from')), findsOneWidget);
    expect(find.byKey(const ValueKey('transaction-date-to')), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Income'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();

    expect(find.byType(InputChip), findsOneWidget);
    expect(find.text('1 transaction (filtered)'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(InputChip),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pump();
    expect(find.text('2 transactions'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'SALARY');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();

    expect(find.text('1 transaction (filtered)'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'not-found');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();

    expect(find.text('“not-found”'), findsOneWidget);
    expect(find.text('No transactions found (filtered)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Clear Filters'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Clear Filters'));
    await tester.pumpAndSettle();

    expect(find.text('Coffee beans'), findsOneWidget);
    expect(find.text('2 transactions'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('authenticated filters are sent before server pagination', (
    tester,
  ) async {
    final api = _FakeCashlenxApi();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_UserAuthNotifier.new),
          cashlenxApiProvider.overrideWithValue(api),
        ],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    await tester.tap(find.text('See All'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('transaction-date-from')));
    await tester.pumpAndSettle();

    final today = DateTime.now();
    await tester.tap(find.text(today.day.toString()).last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(api.lastTransactionFromDate, isNotNull);
    expect(api.lastTransactionFromDate, matches(RegExp(r'^\d{8}$')));
    expect(api.lastTransactionToDate, isNull);
    expect(api.lastTransactionLimit, 20);
    expect(api.lastTransactionOffset, 0);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Income'));
    await tester.pumpAndSettle();
    expect(api.lastTransactionType, 'income');

    await tester.enterText(find.byType(TextField), 'salary');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(api.lastTransactionDescription, 'salary');
  });

  testWidgets('transactions expose server-backed page navigation', (
    tester,
  ) async {
    final api = _PagingCashlenxApi();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_UserAuthNotifier.new),
          cashlenxApiProvider.overrideWithValue(api),
        ],
        child: const MaterialApp(
          home: HomePage(section: HomeSection.transactions),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('21 transactions'), findsOneWidget);
    expect(find.text('Transaction 1'), findsOneWidget);
    expect(find.text('Transaction 21'), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('transactions-next-page')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('transactions-next-page')));
    await tester.pumpAndSettle();

    expect(api.offsets, containsAllInOrder([0, 20]));
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('Transaction 21'), findsOneWidget);
  });
}

class _TestAuthNotifier extends AuthNotifier {
  @override
  Future<User?> build() async {
    final now = DateTime(2026);
    return User(
      id: 'demo-user',
      username: 'Demo User',
      isActive: true,
      role: 'demo',
      createdAt: now,
      updatedAt: now,
    );
  }
}

class _MutableCurrencyNotifier extends CurrencyNotifier {
  @override
  CurrencyOption build() => CurrencyOption.usd;

  void setForTest(CurrencyOption currency) => state = currency;
}

class _UserAuthNotifier extends AuthNotifier {
  @override
  Future<User?> build() async {
    final now = DateTime(2026);
    return User(
      id: 'user-1',
      username: 'User',
      isActive: true,
      role: 'user',
      createdAt: now,
      updatedAt: now,
    );
  }
}

class _FakeCashlenxApi extends CashlenxApi {
  _FakeCashlenxApi() : super(ApiClient(Dio()));

  int? lastTransactionLimit;
  int? lastTransactionOffset;
  String? lastTransactionType;
  String? lastTransactionCategoryId;
  String? lastTransactionDescription;
  String? lastTransactionFromDate;
  String? lastTransactionToDate;

  @override
  Future<ApiJson> versionInfo() async {
    return {
      'code': 'OK',
      'message': '',
      'data': {'version': '1.0.4'},
      'errors': <dynamic>[],
    };
  }

  @override
  Future<ApiJson> getUserProfile() async {
    return {
      'code': 'OK',
      'message': '',
      'data': {
        'id': 'user-1',
        'username': 'User',
        'role': 'user',
        'nickname': 'User',
      },
      'errors': <dynamic>[],
    };
  }

  @override
  Future<ApiJson> getDailySummary(String date) async {
    expect(date, matches(RegExp(r'^\d{8}$')));
    return _wrappedSummary(
      balance: 128.45,
      totalIncome: 300,
      totalExpense: 171.55,
      categoryBreakdown: const {'Day Category': 171.55},
    );
  }

  @override
  Future<ApiJson> getMonthlySummary(String month) async {
    expect(month, matches(RegExp(r'^\d{6}$')));
    return _wrappedSummary(
      balance: 4225.50,
      totalIncome: 5200,
      totalExpense: 974.50,
      categoryBreakdown: const {},
    );
  }

  @override
  Future<ApiJson> getYearlySummary(String year) async {
    expect(year, matches(RegExp(r'^\d{4}$')));
    return _wrappedSummary(
      balance: 39420.25,
      totalIncome: 48600,
      totalExpense: 9179.75,
      categoryBreakdown: const {'Year Category': 9179.75},
    );
  }

  @override
  Future<ApiJson> getTotalSummary() async {
    return _wrappedSummary(
      balance: 88000,
      totalIncome: 120000,
      totalExpense: 32000,
      categoryBreakdown: const {'Total Category': 32000},
    );
  }

  @override
  Future<ApiJson> listAllTransactions({
    int? limit,
    int? offset,
    String? type,
    String? categoryId,
    String? description,
    String? fromDate,
    String? toDate,
  }) async {
    lastTransactionLimit = limit;
    lastTransactionOffset = offset;
    lastTransactionType = type;
    lastTransactionCategoryId = categoryId;
    lastTransactionDescription = description;
    lastTransactionFromDate = fromDate;
    lastTransactionToDate = toDate;
    final transactions = <ApiJson>[
      {
        'id': '507f1f77bcf86cd799439101',
        'belongs_date': '20260517',
        'category_id': {r'$oid': '507f1f77bcf86cd799439011'},
        'category_name': 'Food',
        'amount': 12.5,
        'description': 'Coffee beans',
      },
      {
        'id': '507f1f77bcf86cd799439102',
        'belongs_date': '2026-05-16',
        'category_id': {r'$oid': '507f1f77bcf86cd799439015'},
        'category_name': 'Salary',
        'amount': 3500,
        'description': '',
      },
    ];
    final normalizedSearch = description?.toLowerCase();
    final matches = transactions
        .where((transaction) {
          final transactionCategoryId =
              (transaction['category_id'] as Map?)?[r'$oid'];
          final transactionType =
              transactionCategoryId == '507f1f77bcf86cd799439015'
              ? 'income'
              : 'expense';
          if (type != null && transactionType != type) {
            return false;
          }
          if (categoryId != null && transactionCategoryId != categoryId) {
            return false;
          }
          if (normalizedSearch != null &&
              !transaction['description'].toString().toLowerCase().contains(
                normalizedSearch,
              ) &&
              !transaction['category_name'].toString().toLowerCase().contains(
                normalizedSearch,
              )) {
            return false;
          }
          final date = transaction['belongs_date'].toString().replaceAll(
            '-',
            '',
          );
          if (fromDate != null && date.compareTo(fromDate) < 0) return false;
          if (toDate != null && date.compareTo(toDate) > 0) return false;
          return true;
        })
        .toList(growable: false);
    final page = matches
        .skip(offset ?? 0)
        .take(limit ?? matches.length)
        .toList(growable: false);
    return {
      'code': 'OK',
      'message': '',
      'data': page,
      'meta': {
        'total_count': matches.length,
        'limit': limit,
        'offset': offset ?? 0,
      },
      'errors': <dynamic>[],
      'extra': <String, dynamic>{},
    };
  }

  @override
  Future<ApiJson> getTransactionsByDateRange({
    required String from,
    required String to,
  }) async {
    return listAllTransactions(fromDate: from, toDate: to);
  }

  @override
  Future<ApiJson> listAllCategories({
    int? limit,
    int? offset,
    String? type,
    String? parentId,
  }) async {
    expect(type, isNull);
    expect(parentId, isNull);

    final categories = [
      {
        'Id': {r'$oid': '507f1f77bcf86cd799439011'},
        'name': 'Food & Dining',
        'type': 'expense',
        'parent_id': '000000000000000000000000',
        'emoji': '\u{1F35C}',
        'bg_color': '#FF8A65',
      },
      {
        'Id': '507f1f77bcf86cd799439012',
        'name': 'Restaurants',
        'type': 'expense',
        'parent_id': '507f1f77bcf86cd799439011',
        'emoji': '',
        'bg_color': '',
      },
      {
        'Id': '507f1f77bcf86cd799439013',
        'name': 'Groceries',
        'type': 'expense',
        'parent_id': '507f1f77bcf86cd799439011',
      },
      {
        'Id': '507f1f77bcf86cd799439014',
        'name': 'Transportation',
        'type': 'expense',
        'parent_id': '000000000000000000000000',
      },
      {
        'Id': {r'$oid': '507f1f77bcf86cd799439015'},
        'name': 'Salary',
        'type': 'income',
        'parent_id': '000000000000000000000000',
        'emoji': '\u{1F4BC}',
        'bg_color': '#10B981',
      },
      {
        'Id': '507f1f77bcf86cd799439016',
        'name': 'Bonus',
        'type': 'income',
        'parent_id': '000000000000000000000000',
      },
    ];

    return {
      'code': 'OK',
      'message': '',
      'data': categories,
      'meta': {
        'total_count': categories.length,
        'limit': limit ?? 50,
        'offset': offset ?? 0,
      },
      'errors': <dynamic>[],
      'extra': <String, dynamic>{},
    };
  }

  ApiJson _wrappedSummary({
    required double balance,
    required double totalIncome,
    required double totalExpense,
    required Map<String, double> categoryBreakdown,
  }) {
    return {
      'code': 'OK',
      'message': '',
      'data': {
        'balance': balance,
        'total_income': totalIncome,
        'total_expense': totalExpense,
        'transaction_count': 12,
        'category_breakdown': categoryBreakdown,
      },
      'meta': <String, dynamic>{},
      'errors': <dynamic>[],
      'extra': <String, dynamic>{},
    };
  }
}

class _PendingVersionCashlenxApi extends _FakeCashlenxApi {
  @override
  Future<ApiJson> versionInfo() => Completer<ApiJson>().future;
}

class _UnavailableVersionCashlenxApi extends _FakeCashlenxApi {
  var versionRequests = 0;

  @override
  Future<ApiJson> versionInfo() async {
    versionRequests++;
    throw DioException(
      requestOptions: RequestOptions(path: '/open/version'),
      type: DioExceptionType.connectionError,
    );
  }
}

Future<void> _openAboutDialog(WidgetTester tester, CashlenxApi api) async {
  PackageInfo.setMockInitialValues(
    appName: 'CashLenX',
    packageName: 'cashlenx',
    version: '1.0.9',
    buildNumber: '15',
    buildSignature: '',
  );
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(_TestAuthNotifier.new),
        cashlenxApiProvider.overrideWithValue(api),
        artifactBuildDateProvider.overrideWithValue('2026-10-12'),
      ],
      child: const MaterialApp(home: HomePage(section: HomeSection.settings)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
  await tester.ensureVisible(find.text('About'));
  await tester.pump();
  await tester.tap(find.text('About'));
  await tester.pump();
}

class _PagingCashlenxApi extends _FakeCashlenxApi {
  final offsets = <int>[];

  @override
  Future<ApiJson> listAllTransactions({
    int? limit,
    int? offset,
    String? type,
    String? categoryId,
    String? description,
    String? fromDate,
    String? toDate,
  }) async {
    final resolvedOffset = offset ?? 0;
    final resolvedLimit = limit ?? 20;
    offsets.add(resolvedOffset);
    final transactions = List<ApiJson>.generate(21, (index) {
      final number = index + 1;
      return {
        'id': 'transaction-$number',
        'belongs_date': '20261010',
        'category_id': '507f1f77bcf86cd799439011',
        'category_name': 'Food',
        'category_type': 'expense',
        'amount': number,
        'description': 'Transaction $number',
        'create_time': DateTime.utc(
          2026,
          10,
          10,
          23,
          59 - index,
        ).toIso8601String(),
      };
    });
    return {
      'code': 'OK',
      'message': '',
      'data': transactions
          .skip(resolvedOffset)
          .take(resolvedLimit)
          .toList(growable: false),
      'meta': {
        'total_count': transactions.length,
        'limit': resolvedLimit,
        'offset': resolvedOffset,
      },
      'errors': <dynamic>[],
      'extra': <String, dynamic>{},
    };
  }
}
