class BudgetItem {
  const BudgetItem({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.period,
    required this.limit,
    required this.spent,
  });

  final String id;
  final String categoryId;
  final String categoryName;
  final String period;
  final double limit;
  final double spent;

  double get remaining => limit - spent;
  double get progress => limit <= 0 ? 0 : spent / limit;

  factory BudgetItem.fromJson(Map<String, dynamic> json) {
    return BudgetItem(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      categoryId: (json['category_id'] ?? '').toString(),
      categoryName: (json['category_name'] ?? 'Category').toString(),
      period: (json['period'] ?? '').toString(),
      limit: _number(json['limit_amount']),
      spent: _number(json['spent_amount']),
    );
  }
}

class BudgetCategory {
  const BudgetCategory({required this.id, required this.name});

  final String id;
  final String name;

  factory BudgetCategory.fromJson(Map<String, dynamic> json) {
    return BudgetCategory(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      name: (json['name'] ?? json['Name'] ?? 'Category').toString(),
    );
  }
}

double _number(Object? value) => value is num ? value.toDouble() : 0;
