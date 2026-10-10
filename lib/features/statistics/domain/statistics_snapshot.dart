import 'analytics_range.dart';

class StatisticsSnapshot {
  const StatisticsSnapshot({
    required this.range,
    required this.date,
    required this.income,
    required this.expense,
    required this.balance,
    required this.transactionCount,
    required this.seriesLabels,
    required this.seriesIncome,
    required this.seriesExpense,
    required this.topExpenses,
  });

  final AnalyticsRange range;
  final DateTime date;
  final double income;
  final double expense;
  final double balance;
  final int transactionCount;
  final List<String> seriesLabels;
  final List<double> seriesIncome;
  final List<double> seriesExpense;
  final List<TopExpense> topExpenses;
}

class TopExpense {
  const TopExpense({
    required this.id,
    required this.category,
    required this.description,
    required this.date,
    required this.amount,
  });

  final String id;
  final String category;
  final String description;
  final String date;
  final double amount;

  factory TopExpense.fromJson(Map<String, dynamic> json) => TopExpense(
    id: (json['id'] ?? '').toString(),
    category: (json['category'] ?? 'Expense').toString(),
    description: (json['description'] ?? '').toString(),
    date: (json['date'] ?? '').toString(),
    amount: _number(json['amount']),
  );
}

double _number(Object? value) => value is num ? value.toDouble() : 0;
