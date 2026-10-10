import 'package:cashlenx/features/demo/data/demo_data_store.dart';
import 'package:cashlenx/features/statistics/data/statistics_repository.dart';
import 'package:cashlenx/features/statistics/presentation/analytics_context.dart';
import 'package:cashlenx/network/api_client.dart';
import 'package:cashlenx/network/cashlenx_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserves the normalized twelve-month year comparison', () async {
    final snapshot = await _repository(_StatisticsApi()).load(
      StatisticsQuery(range: AnalyticsRange.year, date: DateTime(2026, 10, 10)),
    );

    expect(snapshot.range, AnalyticsRange.year);
    expect(snapshot.income, 12000);
    expect(snapshot.expense, 4500);
    expect(snapshot.balance, 7500);
    expect(snapshot.seriesLabels, [
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
    expect(snapshot.seriesIncome, [1000, 1200, ...List.filled(10, 0)]);
    expect(snapshot.seriesExpense, [300, 450, ...List.filled(10, 0)]);
    expect(snapshot.topExpenses.single.category, 'Housing');
  });

  test('loads and normalizes the selected monthly context', () async {
    final api = _StatisticsApi();
    final snapshot = await _repository(api).load(
      StatisticsQuery(
        range: AnalyticsRange.month,
        date: DateTime(2026, 10, 10),
      ),
    );

    expect(api.monthTokens, ['202610', '202610', '202610']);
    expect(snapshot.seriesLabels, hasLength(31));
    expect(snapshot.seriesIncome[9], 100);
    expect(snapshot.seriesExpense[9], 20);
    expect(snapshot.seriesIncome.where((value) => value != 0), [100]);
  });

  test('loads the exact selected day without mixing wider data', () async {
    final api = _StatisticsApi();
    final snapshot = await _repository(api).load(
      StatisticsQuery(range: AnalyticsRange.day, date: DateTime(2026, 10, 10)),
    );

    expect(api.dayTokens, ['20261010', '20261010', '20261010']);
    expect(snapshot.seriesLabels, ['20261010']);
    expect(snapshot.seriesIncome, [100]);
    expect(snapshot.seriesExpense, [20]);
  });
}

StatisticsRepository _repository(CashlenxApi api) {
  return StatisticsRepository(api: api, demo: DemoDataStore(), isDemo: false);
}

class _StatisticsApi extends CashlenxApi {
  _StatisticsApi() : super(ApiClient(Dio()));

  final dayTokens = <String>[];
  final monthTokens = <String>[];

  ApiJson get _summary => {
    'data': {
      'income': 12000,
      'expense': 4500,
      'balance': 7500,
      'transaction_count': 42,
    },
  };

  ApiJson _trends(String token) => {
    'data': {
      'data_points': [
        {'date': '2026-10-10', 'income': 100, 'expense': 20},
      ],
    },
  };

  ApiJson get _top => {
    'data': {
      'expenses': [
        {
          'id': 'expense-1',
          'date': '20261010',
          'category': 'Housing',
          'description': 'Rent',
          'amount': 1200,
        },
      ],
    },
  };

  @override
  Future<ApiJson> getStatisticDailySummary(String date) async {
    dayTokens.add(date);
    return _summary;
  }

  @override
  Future<ApiJson> getStatisticDailyTrends(String date) async {
    dayTokens.add(date);
    return _trends(date);
  }

  @override
  Future<ApiJson> getStatisticDailyTop({
    required String date,
    int? limit,
  }) async {
    dayTokens.add(date);
    return _top;
  }

  @override
  Future<ApiJson> getStatisticMonthlySummary(String month) async {
    monthTokens.add(month);
    return _summary;
  }

  @override
  Future<ApiJson> getStatisticMonthlyTrends(String month) async {
    monthTokens.add(month);
    return _trends(month);
  }

  @override
  Future<ApiJson> getStatisticMonthlyTop({
    required String month,
    int? limit,
  }) async {
    monthTokens.add(month);
    return _top;
  }

  @override
  Future<ApiJson> getStatisticYearlySummary(String year) async => _summary;

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
  }) async => _top;
}
