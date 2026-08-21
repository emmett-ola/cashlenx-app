import 'package:cashlenx/features/demo/data/demo_data_store.dart';
import 'package:cashlenx/features/statistics/data/statistics_repository.dart';
import 'package:cashlenx/network/api_client.dart';
import 'package:cashlenx/network/cashlenx_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'combines the existing statistics endpoints into one snapshot',
    () async {
      final snapshot = await StatisticsRepository(
        api: _StatisticsApi(),
        demo: DemoDataStore(),
        isDemo: false,
      ).load(2026);

      expect(snapshot.income, 12000);
      expect(snapshot.expense, 4500);
      expect(snapshot.balance, 7500);
      expect(snapshot.months, ['01', '02']);
      expect(snapshot.monthlyExpense, [300, 450]);
      expect(snapshot.topExpenses.single.category, 'Housing');
    },
  );
}

class _StatisticsApi extends CashlenxApi {
  _StatisticsApi() : super(ApiClient(Dio()));

  @override
  Future<ApiJson> getStatisticYearlySummary(String year) async => {
    'data': {
      'income': 12000,
      'expense': 4500,
      'balance': 7500,
      'transaction_count': 42,
    },
  };

  @override
  Future<ApiJson> getMonthlyComparisonChart(String year) async => {
    'data': {
      'year': year,
      'months': ['01', '02'],
      'income': [1000, 1200],
      'expense': [300, 450],
      'balance': [700, 750],
    },
  };

  @override
  Future<ApiJson> getStatisticYearlyTop({
    required String year,
    int? limit,
  }) async => {
    'data': {
      'expenses': [
        {
          'id': 'expense-1',
          'date': '20260115',
          'category': 'Housing',
          'description': 'Rent',
          'amount': 1200,
        },
      ],
    },
  };
}
