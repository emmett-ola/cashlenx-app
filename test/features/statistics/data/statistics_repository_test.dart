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
      expect(snapshot.months, [
        '01',
        '02',
        '03',
        '04',
        '05',
        '06',
        '07',
        '08',
        '09',
        '10',
        '11',
        '12',
      ]);
      expect(snapshot.monthlyIncome, [1000, 1200, ...List.filled(10, 0)]);
      expect(snapshot.monthlyExpense, [300, 450, ...List.filled(10, 0)]);
      expect(snapshot.topExpenses.single.category, 'Housing');
    },
  );

  test(
    'normalizes partial and mismatched monthly arrays to twelve months',
    () async {
      final snapshot = await StatisticsRepository(
        api: _StatisticsApi(
          monthly: {
            'data': {
              'months': ['Jan', 'Mar'],
              'income': [100],
              'expense': [10, 30],
            },
          },
        ),
        demo: DemoDataStore(),
        isDemo: false,
      ).load(2026);

      expect(snapshot.months, hasLength(12));
      expect(snapshot.monthlyIncome, [100, 0, 0, ...List.filled(9, 0)]);
      expect(snapshot.monthlyExpense, [10, 0, 30, ...List.filled(9, 0)]);
    },
  );
}

class _StatisticsApi extends CashlenxApi {
  _StatisticsApi({ApiJson? monthly})
    : _monthly = monthly,
      super(ApiClient(Dio()));

  final ApiJson? _monthly;

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
  Future<ApiJson> getMonthlyComparisonChart(String year) async =>
      _monthly ??
      {
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
