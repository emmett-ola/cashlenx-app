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

    expect(find.text('Monthly Balance'), findsOneWidget);
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Year'), findsOneWidget);
    expect(find.text(r'$4,225.50'), findsOneWidget);
    expect(find.text('Grocery Shopping'), findsOneWidget);

    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();

    expect(find.text('Yearly Balance'), findsOneWidget);
    expect(find.text(r'$39,420.25'), findsOneWidget);

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
        'category_breakdown': <String, double>{},
      },
      'meta': <String, dynamic>{},
      'errors': <dynamic>[],
      'extra': <String, dynamic>{},
    };
  }
}
