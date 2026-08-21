class StatisticsSnapshot {
  const StatisticsSnapshot({
    required this.year,
    required this.income,
    required this.expense,
    required this.balance,
    required this.transactionCount,
    required this.months,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.topExpenses,
  });

  final int year;
  final double income;
  final double expense;
  final double balance;
  final int transactionCount;
  final List<String> months;
  final List<double> monthlyIncome;
  final List<double> monthlyExpense;
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
