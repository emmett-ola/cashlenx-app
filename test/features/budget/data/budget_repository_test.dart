import 'package:cashlenx/features/budget/data/budget_repository.dart';
import 'package:cashlenx/features/demo/data/demo_data_store.dart';
import 'package:cashlenx/network/api_client.dart';
import 'package:cashlenx/network/cashlenx_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the server nested budget list contract', () async {
    final repository = BudgetRepository(
      api: _BudgetApi(),
      demo: DemoDataStore(),
      isDemo: false,
    );

    final items = await repository.list('2026-08');

    expect(items, hasLength(1));
    expect(items.single.categoryName, 'Food & Dining');
    expect(items.single.limit, 600);
    expect(items.single.spent, 125.5);
    expect(items.single.remaining, 474.5);
  });
}

class _BudgetApi extends CashlenxApi {
  _BudgetApi() : super(ApiClient(Dio()));

  @override
  Future<ApiJson> listBudgets({required String period}) async {
    expect(period, '2026-08');
    return {
      'code': 'OK',
      'data': {
        'data': [
          {
            'id': 'budget-1',
            'category_id': 'category-1',
            'category_name': 'Food & Dining',
            'period': period,
            'limit_amount': 600,
            'spent_amount': 125.5,
            'remaining': 474.5,
            'progress': 0.209,
          },
        ],
      },
    };
  }
}
