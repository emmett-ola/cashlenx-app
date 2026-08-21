import 'package:cashlenx/features/auth/domain/models/user.dart';
import 'package:cashlenx/features/auth/presentation/providers/auth_provider.dart';
import 'package:cashlenx/features/home/presentation/pages/home_page.dart';
import 'package:cashlenx/network/api_client.dart';
import 'package:cashlenx/network/cashlenx_api.dart';
import 'package:cashlenx/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    expect(find.text('Total Balance'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Year'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text(r'$88,000.00'), findsOneWidget);
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

    expect(find.text('Transactions'), findsOneWidget);
    expect(find.byIcon(Icons.filter_list), findsOneWidget);
    expect(find.text('Coffee beans'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();

    expect(find.text('Today Balance'), findsOneWidget);
    expect(find.text(r'$128.45'), findsOneWidget);

    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();

    expect(find.text('Year Balance'), findsOneWidget);
    expect(find.text(r'$39,420.25'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Spending by Category'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Spending by Category'), findsOneWidget);
    expect(find.text('More Statistics Charts'), findsOneWidget);

    await tester.tap(find.text('Category').last);
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

    await tester.tap(find.text('Budget').last);
    await tester.pumpAndSettle();

    expect(find.text('Manage your spending limits'), findsOneWidget);
    expect(find.text('Category Budgets'), findsOneWidget);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Currency'), findsOneWidget);
    expect(find.text('Support'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);

    await tester.tap(find.text('More Setting'));
    await tester.pump();

    expect(find.text('More Setting coming soon!'), findsOneWidget);

    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('More Statistics Charts'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('More Statistics Charts'));
    await tester.pumpAndSettle();

    expect(find.text('More Statistics'), findsOneWidget);
    expect(find.text('Monthly Comparison'), findsOneWidget);
    expect(find.text('Top Expenses'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();

    expect(find.text('Add Transaction'), findsAtLeastNWidgets(1));
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Category'), findsAtLeastNWidgets(1));
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
    await tester.enterText(find.byType(TextField), 'not-found');
    await tester.pump();
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

  testWidgets('authenticated date filters use the server range endpoint', (
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

    expect(api.lastRangeFrom, isNotNull);
    expect(api.lastRangeFrom, matches(RegExp(r'^\d{8}$')));
    expect(api.lastRangeTo, '21001231');
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

  String? lastRangeFrom;
  String? lastRangeTo;

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
    );
  }

  @override
  Future<ApiJson> getMonthlySummary(String month) async {
    expect(month, matches(RegExp(r'^\d{6}$')));
    return _wrappedSummary(
      balance: 4225.50,
      totalIncome: 5200,
      totalExpense: 974.50,
    );
  }

  @override
  Future<ApiJson> getYearlySummary(String year) async {
    expect(year, matches(RegExp(r'^\d{4}$')));
    return _wrappedSummary(
      balance: 39420.25,
      totalIncome: 48600,
      totalExpense: 9179.75,
    );
  }

  @override
  Future<ApiJson> getTotalSummary() async {
    return _wrappedSummary(
      balance: 88000,
      totalIncome: 120000,
      totalExpense: 32000,
    );
  }

  @override
  Future<ApiJson> listAllTransactions({
    int? limit,
    int? offset,
    String? type,
    String? categoryId,
    String? description,
  }) async {
    return {
      'code': 'OK',
      'message': '',
      'data': [
        {
          'id': '507f1f77bcf86cd799439101',
          'belongs_date': '20260517',
          'category_name': 'Food',
          'flow_type': 'expense',
          'amount': 12.5,
          'description': 'Coffee beans',
          'category': {'emoji': '\u{1F35C}', 'bg_color': '#FF8A65'},
        },
        {
          'id': '507f1f77bcf86cd799439102',
          'belongs_date': '2026-05-16',
          'category_name': 'Salary',
          'flow_type': 'income',
          'amount': 3500,
          'description': '',
          'category_emoji': '\u{1F4BC}',
          'category_bg_color': '#10B981',
        },
      ],
      'meta': {'total_count': 2, 'limit': limit, 'offset': offset ?? 0},
      'errors': <dynamic>[],
      'extra': <String, dynamic>{},
    };
  }

  @override
  Future<ApiJson> getTransactionsByDateRange({
    required String from,
    required String to,
  }) async {
    lastRangeFrom = from;
    lastRangeTo = to;
    return listAllTransactions();
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
        'Id': '507f1f77bcf86cd799439011',
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
        'Id': '507f1f77bcf86cd799439015',
        'name': 'Salary',
        'type': 'income',
        'parent_id': '000000000000000000000000',
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
  }) {
    return {
      'code': 'OK',
      'message': '',
      'data': {
        'balance': balance,
        'total_income': totalIncome,
        'total_expense': totalExpense,
        'transaction_count': 12,
        'category_breakdown': {
          'Dining': 420.25,
          'Shopping': 300.75,
          'Transport': 253.50,
        },
      },
      'meta': <String, dynamic>{},
      'errors': <dynamic>[],
      'extra': <String, dynamic>{},
    };
  }
}
