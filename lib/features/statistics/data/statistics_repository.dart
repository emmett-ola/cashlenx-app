import 'dart:math' as math;

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
    final monthly = _normalizeMonthlyComparison(comparison);

    return StatisticsSnapshot(
      year: year,
      income: _number(summary['income'] ?? summary['total_income']),
      expense: _number(summary['expense'] ?? summary['total_expense']),
      balance: _number(summary['balance']),
      transactionCount: (summary['transaction_count'] as num?)?.toInt() ?? 0,
      months: monthly.months,
      monthlyIncome: monthly.income,
      monthlyExpense: monthly.expense,
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

const _canonicalMonths = <String>[
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
];

const _englishMonthIndexes = <String, int>{
  'jan': 0,
  'january': 0,
  'feb': 1,
  'february': 1,
  'mar': 2,
  'march': 2,
  'apr': 3,
  'april': 3,
  'may': 4,
  'jun': 5,
  'june': 5,
  'jul': 6,
  'july': 6,
  'aug': 7,
  'august': 7,
  'sep': 8,
  'sept': 8,
  'september': 8,
  'oct': 9,
  'october': 9,
  'nov': 10,
  'november': 10,
  'dec': 11,
  'december': 11,
};

_MonthlySeries _normalizeMonthlyComparison(Map<String, dynamic> json) {
  final rawMonths = _strings(json['months']);
  final rawIncome = _numbers(json['income']);
  final rawExpense = _numbers(json['expense']);
  final income = List<double>.filled(12, 0);
  final expense = List<double>.filled(12, 0);
  final itemCount = [
    rawMonths.length,
    rawIncome.length,
    rawExpense.length,
  ].fold<int>(0, math.max);

  for (var index = 0; index < itemCount && index < 12; index++) {
    final monthIndex = index < rawMonths.length
        ? (_monthIndex(rawMonths[index]) ?? index)
        : index;
    if (monthIndex < 0 || monthIndex >= 12) continue;
    if (index < rawIncome.length) income[monthIndex] = rawIncome[index];
    if (index < rawExpense.length) expense[monthIndex] = rawExpense[index];
  }

  return _MonthlySeries(
    months: _canonicalMonths,
    income: List.unmodifiable(income),
    expense: List.unmodifiable(expense),
  );
}

int? _monthIndex(String value) {
  final normalized = value.trim().toLowerCase();
  final numeric = int.tryParse(normalized);
  if (numeric != null && numeric >= 1 && numeric <= 12) return numeric - 1;
  return _englishMonthIndexes[normalized];
}

class _MonthlySeries {
  const _MonthlySeries({
    required this.months,
    required this.income,
    required this.expense,
  });

  final List<String> months;
  final List<double> income;
  final List<double> expense;
}
