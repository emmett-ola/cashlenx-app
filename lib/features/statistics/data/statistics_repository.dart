import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../network/cashlenx_api.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../demo/data/demo_data_store.dart';
import '../domain/statistics_snapshot.dart';

final yearlyStatisticsProvider = FutureProvider.family<StatisticsSnapshot, int>(
  (ref, year) async {
    ref.watch(demoDataRevisionProvider);
    final api = ref.watch(cashlenxApiProvider);
    final demo = ref.watch(demoDataStoreProvider);
    final user = await ref.watch(authNotifierProvider.future);
    return StatisticsRepository(
      api: api,
      demo: demo,
      isDemo: user?.role == 'demo',
    ).load(year);
  },
);

class StatisticsRepository {
  const StatisticsRepository({
    required CashlenxApi api,
    required DemoDataStore demo,
    required bool isDemo,
  }) : _api = api,
       _demo = demo,
       _isDemo = isDemo;

  final CashlenxApi _api;
  final DemoDataStore _demo;
  final bool _isDemo;

  Future<StatisticsSnapshot> load(int year) async {
    final token = year.toString();
    final responses = _isDemo
        ? await Future.wait([
            _demo.getStatisticYearlySummary(token),
            _demo.getMonthlyComparisonChart(token),
            _demo.getStatisticYearlyTop(year: token, limit: 5),
          ])
        : await Future.wait([
            _api.getStatisticYearlySummary(token),
            _api.getMonthlyComparisonChart(token),
            _api.getStatisticYearlyTop(year: token, limit: 5),
          ]);

    final summary = _mapData(responses[0]);
    final comparison = _mapData(responses[1]);
    final top = _mapData(responses[2]);
    final rawTop = top['expenses'];

    return StatisticsSnapshot(
      year: year,
      income: _number(summary['income'] ?? summary['total_income']),
      expense: _number(summary['expense'] ?? summary['total_expense']),
      balance: _number(summary['balance']),
      transactionCount: (summary['transaction_count'] as num?)?.toInt() ?? 0,
      months: _strings(comparison['months']),
      monthlyIncome: _numbers(comparison['income']),
      monthlyExpense: _numbers(comparison['expense']),
      topExpenses: rawTop is List
          ? rawTop
                .whereType<Map>()
                .map(
                  (item) =>
                      TopExpense.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

Map<String, dynamic> _mapData(ApiJson response) {
  final data = response['data'];
  if (data is Map) return Map<String, dynamic>.from(data);
  return response;
}

double _number(Object? value) => value is num ? value.toDouble() : 0;

List<double> _numbers(Object? value) => value is List
    ? value.map((item) => _number(item)).toList(growable: false)
    : const [];

List<String> _strings(Object? value) => value is List
    ? value.map((item) => item.toString()).toList(growable: false)
    : const [];
