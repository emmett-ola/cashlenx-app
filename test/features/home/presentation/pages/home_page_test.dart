import 'package:cashlenx/features/auth/domain/models/user.dart';
import 'package:cashlenx/features/auth/presentation/providers/auth_provider.dart';
import 'package:cashlenx/features/home/presentation/pages/home_page.dart';
import 'package:cashlenx/network/api_client.dart';
import 'package:cashlenx/network/cashlenx_api.dart';
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
    expect(find.text('Grocery Shopping'), findsOneWidget);

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
    expect(find.text('Restaurants'), findsOneWidget);
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

    expect(find.text('Privacy & Security'), findsOneWidget);

    await tester.tap(find.text('Security'));
    await tester.pump();

    expect(find.text('Security coming soon!'), findsOneWidget);
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

class _FakeCashlenxApi extends CashlenxApi {
  _FakeCashlenxApi() : super(ApiClient(Dio()));

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
  Future<ApiJson> listAllCategories({
    int? limit,
    int? offset,
    String? type,
    String? parentId,
  }) async {
    final categories = [
      {
        'id': 'food',
        'name': 'Food & Dining',
        'type': 'expense',
        'parent_id': null,
      },
      {
        'id': 'restaurants',
        'name': 'Restaurants',
        'type': 'expense',
        'parent_id': 'food',
      },
      {
        'id': 'groceries',
        'name': 'Groceries',
        'type': 'expense',
        'parent_id': 'food',
      },
      {
        'id': 'transport',
        'name': 'Transportation',
        'type': 'expense',
        'parent_id': null,
      },
      {'id': 'salary', 'name': 'Salary', 'type': 'income', 'parent_id': null},
      {'id': 'bonus', 'name': 'Bonus', 'type': 'income', 'parent_id': null},
    ];

    return {
      'code': 'OK',
      'message': '',
      'data': categories
          .where((category) => type == null || category['type'] == type)
          .where(
            (category) => parentId == null || category['parent_id'] == parentId,
          )
          .toList(),
      'meta': <String, dynamic>{},
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
