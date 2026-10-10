import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../network/cashlenx_api.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../demo/data/demo_data_store.dart';
import '../domain/analytics_range.dart';
import '../domain/statistics_snapshot.dart';

final statisticsProvider =
    FutureProvider.family<StatisticsSnapshot, StatisticsQuery>((
      ref,
      query,
    ) async {
      ref.watch(demoDataRevisionProvider);
      final user = await ref.watch(authNotifierProvider.future);
      return StatisticsRepository(
        api: ref.watch(cashlenxApiProvider),
        demo: ref.watch(demoDataStoreProvider),
        isDemo: user?.role == 'demo',
      ).load(query);
    });

class StatisticsQuery {
  StatisticsQuery({required this.range, required DateTime date})
    : assert(range != AnalyticsRange.total),
      date = DateTime(date.year, date.month, date.day);

  final AnalyticsRange range;
  final DateTime date;

  String get token => switch (range) {
    AnalyticsRange.day => _dateToken(date),
    AnalyticsRange.month => _monthToken(date),
    AnalyticsRange.year => date.year.toString(),
    AnalyticsRange.total => throw StateError(
      'Total is not a statistics range.',
    ),
  };

  @override
  bool operator ==(Object other) {
    return other is StatisticsQuery &&
        other.range == range &&
        other.date == date;
  }

  @override
  int get hashCode => Object.hash(range, date);
}

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

  Future<StatisticsSnapshot> load(StatisticsQuery query) async {
    final responses = await Future.wait([
      _loadSummary(query),
      _loadSeries(query),
      _loadTop(query),
    ]);
    final summary = _mapData(responses[0]);
    final series = _normalizeSeries(query, _mapData(responses[1]));
    final top = _mapData(responses[2]);
    final rawTop = top['expenses'];

    return StatisticsSnapshot(
      range: query.range,
      date: query.date,
      income: _number(summary['income'] ?? summary['total_income']),
      expense: _number(summary['expense'] ?? summary['total_expense']),
      balance: _number(summary['balance']),
      transactionCount: (summary['transaction_count'] as num?)?.toInt() ?? 0,
      seriesLabels: series.labels,
      seriesIncome: series.income,
      seriesExpense: series.expense,
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

  Future<ApiJson> _loadSummary(StatisticsQuery query) {
    return switch ((query.range, _isDemo)) {
      (AnalyticsRange.day, true) => _demo.getStatisticDailySummary(query.token),
      (AnalyticsRange.month, true) => _demo.getStatisticMonthlySummary(
        query.token,
      ),
      (AnalyticsRange.year, true) => _demo.getStatisticYearlySummary(
        query.token,
      ),
      (AnalyticsRange.day, false) => _api.getStatisticDailySummary(query.token),
      (AnalyticsRange.month, false) => _api.getStatisticMonthlySummary(
        query.token,
      ),
      (AnalyticsRange.year, false) => _api.getStatisticYearlySummary(
        query.token,
      ),
      (AnalyticsRange.total, _) => throw StateError(
        'Total is not a statistics range.',
      ),
    };
  }

  Future<ApiJson> _loadSeries(StatisticsQuery query) {
    return switch ((query.range, _isDemo)) {
      (AnalyticsRange.day, true) => _demo.getStatisticDailyTrends(query.token),
      (AnalyticsRange.month, true) => _demo.getStatisticMonthlyTrends(
        query.token,
      ),
      (AnalyticsRange.year, true) => _demo.getMonthlyComparisonChart(
        query.token,
      ),
      (AnalyticsRange.day, false) => _api.getStatisticDailyTrends(query.token),
      (AnalyticsRange.month, false) => _api.getStatisticMonthlyTrends(
        query.token,
      ),
      (AnalyticsRange.year, false) => _api.getMonthlyComparisonChart(
        query.token,
      ),
      (AnalyticsRange.total, _) => throw StateError(
        'Total is not a statistics range.',
      ),
    };
  }

  Future<ApiJson> _loadTop(StatisticsQuery query) {
    return switch ((query.range, _isDemo)) {
      (AnalyticsRange.day, true) => _demo.getStatisticDailyTop(
        date: query.token,
        limit: 5,
      ),
      (AnalyticsRange.month, true) => _demo.getStatisticMonthlyTop(
        month: query.token,
        limit: 5,
      ),
      (AnalyticsRange.year, true) => _demo.getStatisticYearlyTop(
        year: query.token,
        limit: 5,
      ),
      (AnalyticsRange.day, false) => _api.getStatisticDailyTop(
        date: query.token,
        limit: 5,
      ),
      (AnalyticsRange.month, false) => _api.getStatisticMonthlyTop(
        month: query.token,
        limit: 5,
      ),
      (AnalyticsRange.year, false) => _api.getStatisticYearlyTop(
        year: query.token,
        limit: 5,
      ),
      (AnalyticsRange.total, _) => throw StateError(
        'Total is not a statistics range.',
      ),
    };
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

_Series _normalizeSeries(StatisticsQuery query, Map<String, dynamic> json) {
  if (query.range == AnalyticsRange.year) {
    return _normalizeYearSeries(json);
  }

  final count = query.range == AnalyticsRange.day
      ? 1
      : DateTime(query.date.year, query.date.month + 1, 0).day;
  final labels = query.range == AnalyticsRange.day
      ? [_dateToken(query.date)]
      : List.generate(count, (index) => '${index + 1}'.padLeft(2, '0'));
  final income = List<double>.filled(count, 0);
  final expense = List<double>.filled(count, 0);
  final rawPoints = json['data_points'];
  if (rawPoints is List) {
    for (final rawPoint in rawPoints.whereType<Map>()) {
      final point = Map<String, dynamic>.from(rawPoint);
      final digits =
          point['date']?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
      final day = digits.length >= 8
          ? int.tryParse(digits.substring(6, 8))
          : null;
      final index = query.range == AnalyticsRange.day ? 0 : (day ?? 0) - 1;
      if (index < 0 || index >= count) continue;
      income[index] = _number(point['income']);
      expense[index] = _number(point['expense']);
    }
  }
  return _Series(labels: labels, income: income, expense: expense);
}

_Series _normalizeYearSeries(Map<String, dynamic> json) {
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

  return _Series(
    labels: const [
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
    ],
    income: List.unmodifiable(income),
    expense: List.unmodifiable(expense),
  );
}

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

int? _monthIndex(String value) {
  final normalized = value.trim().toLowerCase();
  final numeric = int.tryParse(normalized);
  if (numeric != null && numeric >= 1 && numeric <= 12) return numeric - 1;
  return _englishMonthIndexes[normalized];
}

String _dateToken(DateTime date) {
  return '${date.year}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';
}

String _monthToken(DateTime date) {
  return '${date.year}${date.month.toString().padLeft(2, '0')}';
}

class _Series {
  const _Series({
    required this.labels,
    required this.income,
    required this.expense,
  });

  final List<String> labels;
  final List<double> income;
  final List<double> expense;
}
