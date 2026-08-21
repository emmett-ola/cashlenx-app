import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../network/cashlenx_api.dart';

final demoDataRevisionProvider =
    NotifierProvider<DemoDataRevisionNotifier, int>(
      DemoDataRevisionNotifier.new,
    );

class DemoDataRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() {
    state++;
  }
}

final demoDataStoreProvider = Provider<DemoDataStore>((ref) {
  return DemoDataStore();
});

class DemoDataStore {
  DemoDataStore() {
    reset();
  }

  var _nextCategoryId = 100;
  var _nextTransactionId = 100;
  var _nextBudgetId = 100;
  late List<ApiJson> _categories;
  late List<ApiJson> _transactions;
  late List<ApiJson> _budgets;
  late ApiJson _profile;
  late ApiJson _configuration;

  void reset() {
    _nextCategoryId = 100;
    _nextTransactionId = 100;
    _nextBudgetId = 100;
    _categories = _initialCategories();
    _transactions = _initialTransactions();
    _budgets = _initialBudgets();
    _profile = {
      'id': 'demo-user',
      'username': 'Demo User',
      'role': 'demo',
      'is_active': true,
      'nickname': 'Demo User',
      'email_address': 'demo@cashlenx.com',
      'gender': 'others',
      'phone_number': '+65 6123 4567',
      'location': 'Singapore',
      'birth_date': '1995-03-15',
    };
    _configuration = {
      'display_language': 'en',
      'currency_code': 'USD',
      'active_theme_color': '#008080',
    };
  }

  Future<ApiJson> getProfile() async {
    return _wrappedData(Map<String, dynamic>.from(_profile));
  }

  Future<ApiJson> updateProfile({
    required String nickname,
    required String avatarUrl,
    required String phoneNumber,
    required String location,
    required String birthDate,
  }) async {
    _profile = {
      ..._profile,
      'nickname': nickname,
      'avatar_url': avatarUrl,
      'phone_number': phoneNumber,
      'location': location,
      'birth_date': birthDate,
    };
    return _wrappedData(Map<String, dynamic>.from(_profile));
  }

  Future<ApiJson> getConfiguration() async {
    return _wrappedData(Map<String, dynamic>.from(_configuration));
  }

  Future<ApiJson> updateConfiguration({
    required String displayLanguage,
    required String currencyCode,
    required String activeThemeColor,
  }) async {
    _configuration = {
      'display_language': displayLanguage,
      'currency_code': currencyCode,
      'active_theme_color': activeThemeColor,
    };
    return _wrappedData(Map<String, dynamic>.from(_configuration));
  }

  Future<ApiJson> getDailySummary(String date) async {
    return _wrappedSummary(
      balance: 128.45,
      totalIncome: 300,
      totalExpense: 171.55,
      categoryBreakdown: const {
        'Dining': 82.25,
        'Transport': 56.80,
        'Shopping': 32.50,
      },
    );
  }

  Future<ApiJson> getMonthlySummary(String month) async {
    return _wrappedSummary(
      balance: 4225.50,
      totalIncome: 5200,
      totalExpense: 974.50,
      categoryBreakdown: const {
        'Dining': 420.25,
        'Shopping': 300.75,
        'Transport': 253.50,
      },
    );
  }

  Future<ApiJson> getYearlySummary(String year) async {
    return _wrappedSummary(
      balance: 39420.25,
      totalIncome: 48600,
      totalExpense: 9179.75,
      categoryBreakdown: const {
        'Dining': 3980.25,
        'Shopping': 2850.75,
        'Transport': 2348.75,
      },
    );
  }

  Future<ApiJson> getTotalSummary() async {
    return _wrappedSummary(
      balance: 88000,
      totalIncome: 120000,
      totalExpense: 32000,
      categoryBreakdown: const {
        'Dining': 12420.25,
        'Shopping': 10300.75,
        'Transport': 9278.50,
      },
    );
  }

  Future<ApiJson> listAllTransactions({
    int? limit,
    int? offset,
    String? type,
    String? categoryId,
    String? description,
  }) async {
    final transactions = _transactions
        .where((transaction) {
          if (type != null && transaction['flow_type'] != type) return false;
          if (categoryId != null && transaction['category_id'] != categoryId) {
            return false;
          }
          if (description != null &&
              !transaction['description'].toString().toLowerCase().contains(
                description.toLowerCase(),
              )) {
            return false;
          }
          return true;
        })
        .map(Map<String, dynamic>.from)
        .skip(offset ?? 0)
        .take(limit ?? _transactions.length)
        .toList(growable: false);

    return _wrappedList(transactions, limit: limit, offset: offset);
  }

  Future<ApiJson> createTransaction({
    required String type,
    required String belongsDate,
    required String categoryName,
    required num amount,
    String? description,
  }) async {
    final category = _categories.firstWhere(
      (category) =>
          category['name'] == categoryName && category['type'] == type,
      orElse: () => <String, dynamic>{},
    );
    final transaction = {
      'id': 'demo-transaction-${_nextTransactionId++}',
      'belongs_date': belongsDate,
      'category_id': category['Id'],
      'category_name': categoryName,
      'flow_type': type,
      'amount': amount,
      'description': description,
      'category_emoji': category['emoji'],
      'category_bg_color': category['bg_color'],
    };
    _transactions.insert(0, transaction);
    return _wrappedData(Map<String, dynamic>.from(transaction));
  }

  Future<ApiJson> getTransactionById(String id) async {
    final transaction = _transactions.firstWhere(
      (transaction) => transaction['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    if (transaction.isEmpty) {
      throw StateError('Demo transaction not found.');
    }
    return _wrappedData(Map<String, dynamic>.from(transaction));
  }

  Future<ApiJson> updateTransactionById(
    String id, {
    required String belongsDate,
    required String categoryName,
    required num amount,
    String? description,
  }) async {
    final index = _transactions.indexWhere(
      (transaction) => transaction['id'] == id,
    );
    if (index == -1) {
      throw StateError('Demo transaction not found.');
    }

    final currentType = _transactions[index]['flow_type']?.toString();
    final category = _categories.firstWhere(
      (category) =>
          category['name'] == categoryName && category['type'] == currentType,
      orElse: () => <String, dynamic>{},
    );
    final updated = {
      ..._transactions[index],
      'belongs_date': belongsDate,
      'category_id': category['Id'] ?? _transactions[index]['category_id'],
      'category_name': categoryName,
      'amount': amount,
      'description': description,
      'category_emoji':
          category['emoji'] ?? _transactions[index]['category_emoji'],
      'category_bg_color':
          category['bg_color'] ?? _transactions[index]['category_bg_color'],
    };
    _transactions[index] = updated;
    return _wrappedData(Map<String, dynamic>.from(updated));
  }

  Future<ApiJson> deleteTransactionById(String id) async {
    _transactions.removeWhere((transaction) => transaction['id'] == id);
    return _wrappedData({'deleted': true});
  }

  Future<ApiJson> listAllCategories({
    int? limit,
    int? offset,
    String? type,
    String? parentId,
  }) async {
    final categories = _categories
        .where((category) {
          if (type != null && category['type'] != type) return false;
          if (parentId != null && category['parent_id'] != parentId) {
            return false;
          }
          return true;
        })
        .skip(offset ?? 0)
        .take(limit ?? _categories.length)
        .map(Map<String, dynamic>.from)
        .toList(growable: false);

    return _wrappedList(categories, limit: limit, offset: offset);
  }

  Future<ApiJson> createCategory({
    required String name,
    required String type,
    String? parentId,
    String? emoji,
    String? bgColor,
    String? remark,
  }) async {
    final category = _categoryData(
      id: 'demo-category-${_nextCategoryId++}',
      name: name,
      type: type,
      parentId: parentId,
      emoji: emoji,
      bgColor: bgColor,
      remark: remark,
    );
    _categories.add(category);
    return _wrappedData(Map<String, dynamic>.from(category));
  }

  Future<ApiJson> updateCategoryById(
    String id, {
    required String name,
    required String type,
    String? parentId,
    String? emoji,
    String? bgColor,
    String? remark,
  }) async {
    final index = _categories.indexWhere((category) => category['Id'] == id);
    if (index == -1) {
      throw StateError('Demo category not found.');
    }

    _categories[index] = _categoryData(
      id: id,
      name: name,
      type: type,
      parentId: parentId,
      emoji: emoji,
      bgColor: bgColor,
      remark: remark,
    );

    return _wrappedData(Map<String, dynamic>.from(_categories[index]));
  }

  Future<ApiJson> deleteCategoryById(String id) async {
    final removedIds = <String>{id};
    var changed = true;
    while (changed) {
      changed = false;
      for (final category in _categories) {
        if (removedIds.contains(category['parent_id']) &&
            removedIds.add(category['Id'].toString())) {
          changed = true;
        }
      }
    }

    _categories.removeWhere((category) => removedIds.contains(category['Id']));
    return _wrappedData({'deleted': true});
  }

  Future<ApiJson> listBudgets({required String period}) async {
    final spentByCategory = <String, double>{};
    for (final transaction in _transactions) {
      if (transaction['flow_type'] != 'expense') continue;
      final date = _dateDigits(transaction['belongs_date']);
      if (date.length < 6 ||
          '${date.substring(0, 4)}-${date.substring(4, 6)}' != period) {
        continue;
      }
      final categoryId = transaction['category_id']?.toString() ?? '';
      spentByCategory[categoryId] =
          (spentByCategory[categoryId] ?? 0) +
          ((transaction['amount'] as num?)?.toDouble() ?? 0);
    }
    final data = _budgets
        .where((budget) => budget['period'] == period)
        .map((budget) {
          final categoryId = budget['category_id'].toString();
          final category = _categories.firstWhere(
            (item) => item['Id'] == categoryId,
            orElse: () => <String, dynamic>{},
          );
          final limit = (budget['limit_amount'] as num).toDouble();
          final spent = spentByCategory[categoryId] ?? 0;
          return <String, dynamic>{
            ...budget,
            'category_name': category['name'] ?? 'Category',
            'spent_amount': spent,
            'remaining': limit - spent,
            'progress': limit == 0 ? 0 : spent / limit,
          };
        })
        .toList(growable: false);
    return _wrappedList(data);
  }

  Future<ApiJson> createBudget({
    required String categoryId,
    required String period,
    required num limitAmount,
  }) async {
    if (_budgets.any(
      (item) => item['category_id'] == categoryId && item['period'] == period,
    )) {
      throw StateError('Budget already exists for this category.');
    }
    final budget = <String, dynamic>{
      'id': 'demo-budget-${_nextBudgetId++}',
      'category_id': categoryId,
      'period': period,
      'limit_amount': limitAmount.toDouble(),
    };
    _budgets.add(budget);
    return _wrappedData(budget);
  }

  Future<ApiJson> updateBudget(
    String id, {
    required String categoryId,
    required String period,
    required num limitAmount,
  }) async {
    final index = _budgets.indexWhere((item) => item['id'] == id);
    if (index == -1) throw StateError('Demo budget not found.');
    if (_budgets.indexed.any(
      (entry) =>
          entry.$1 != index &&
          entry.$2['category_id'] == categoryId &&
          entry.$2['period'] == period,
    )) {
      throw StateError('Budget already exists for this category.');
    }
    _budgets[index] = <String, dynamic>{
      'id': id,
      'category_id': categoryId,
      'period': period,
      'limit_amount': limitAmount.toDouble(),
    };
    return _wrappedData(_budgets[index]);
  }

  Future<ApiJson> deleteBudget(String id) async {
    final before = _budgets.length;
    _budgets.removeWhere((item) => item['id'] == id);
    if (before == _budgets.length) throw StateError('Demo budget not found.');
    return _wrappedData({'deleted': true});
  }

  Future<ApiJson> getStatisticYearlySummary(String year) async {
    var income = 0.0;
    var expense = 0.0;
    var count = 0;
    for (final item in _transactions) {
      if (!item['belongs_date'].toString().startsWith(year)) continue;
      final amount = (item['amount'] as num?)?.toDouble() ?? 0;
      if (item['flow_type'] == 'income') {
        income += amount;
      } else {
        expense += amount;
      }
      count++;
    }
    return _wrappedData({
      'period': year,
      'period_type': 'yearly',
      'income': income,
      'expense': expense,
      'balance': income - expense,
      'transaction_count': count,
    });
  }

  Future<ApiJson> getMonthlyComparisonChart(String year) async {
    final income = List<double>.filled(12, 0);
    final expense = List<double>.filled(12, 0);
    for (final item in _transactions) {
      final date = _dateDigits(item['belongs_date']);
      if (date.length < 6 || !date.startsWith(year)) continue;
      final month = int.parse(date.substring(4, 6)) - 1;
      final amount = (item['amount'] as num?)?.toDouble() ?? 0;
      if (item['flow_type'] == 'income') {
        income[month] += amount;
      } else {
        expense[month] += amount;
      }
    }
    return _wrappedData({
      'year': year,
      'months': List.generate(
        12,
        (index) => (index + 1).toString().padLeft(2, '0'),
      ),
      'income': income,
      'expense': expense,
      'balance': List.generate(12, (index) => income[index] - expense[index]),
    });
  }

  Future<ApiJson> getStatisticYearlyTop({
    required String year,
    int? limit,
  }) async {
    final expenses =
        _transactions
            .where(
              (item) =>
                  item['flow_type'] == 'expense' &&
                  item['belongs_date'].toString().startsWith(year),
            )
            .toList()
          ..sort(
            (a, b) => ((b['amount'] as num?) ?? 0).compareTo(
              (a['amount'] as num?) ?? 0,
            ),
          );
    final result = expenses
        .take(limit ?? 5)
        .map(
          (item) => <String, dynamic>{
            'id': item['id'],
            'date': item['belongs_date'],
            'category': item['category_name'],
            'amount': item['amount'],
            'description': item['description'] ?? '',
          },
        )
        .toList(growable: false);
    return _wrappedData({
      'period': year,
      'limit': limit ?? 5,
      'total_expense': expenses.fold<double>(
        0,
        (sum, item) => sum + ((item['amount'] as num?)?.toDouble() ?? 0),
      ),
      'expenses': result,
    });
  }

  ApiJson _wrappedSummary({
    required double balance,
    required double totalIncome,
    required double totalExpense,
    required Map<String, double> categoryBreakdown,
  }) {
    return _wrappedData({
      'balance': balance,
      'total_income': totalIncome,
      'total_expense': totalExpense,
      'transaction_count': 12,
      'category_breakdown': categoryBreakdown,
    });
  }

  ApiJson _wrappedData(Object data) {
    return {
      'code': 'OK',
      'message': '',
      'data': data,
      'meta': <String, dynamic>{},
      'errors': <dynamic>[],
      'extra': <String, dynamic>{},
    };
  }

  ApiJson _wrappedList(List<ApiJson> data, {int? limit, int? offset}) {
    return {
      'code': 'OK',
      'message': '',
      'data': data,
      'meta': {
        'total_count': data.length,
        'limit': limit ?? data.length,
        'offset': offset ?? 0,
      },
      'errors': <dynamic>[],
      'extra': <String, dynamic>{},
    };
  }

  List<ApiJson> _initialCategories() {
    return [
      _categoryData(
        id: 'demo-category-food',
        name: 'Food & Dining',
        type: 'expense',
        emoji: '\u{1F35C}',
        bgColor: '#FF8A65',
      ),
      _categoryData(
        id: 'demo-category-restaurants',
        name: 'Restaurants',
        type: 'expense',
        parentId: 'demo-category-food',
        emoji: '',
        bgColor: '',
      ),
      _categoryData(
        id: 'demo-category-groceries',
        name: 'Groceries',
        type: 'expense',
        parentId: 'demo-category-food',
      ),
      _categoryData(
        id: 'demo-category-transportation',
        name: 'Transportation',
        type: 'expense',
      ),
      _categoryData(
        id: 'demo-category-salary',
        name: 'Salary',
        type: 'income',
        emoji: '\u{1F4BC}',
        bgColor: '#10B981',
      ),
      _categoryData(
        id: 'demo-category-bonus',
        name: 'Bonus',
        type: 'income',
        emoji: '\u{1F389}',
        bgColor: '#42A5F5',
      ),
    ];
  }

  List<ApiJson> _initialTransactions() {
    final now = DateTime.now();
    final previous = now.subtract(const Duration(days: 1));
    return [
      {
        'id': 'demo-transaction-coffee',
        'belongs_date': _compactDate(now),
        'category_id': 'demo-category-food',
        'category_name': 'Food',
        'flow_type': 'expense',
        'amount': 12.5,
        'description': 'Coffee beans',
        'category': {'emoji': '\u{1F35C}', 'bg_color': '#FF8A65'},
      },
      {
        'id': 'demo-transaction-salary',
        'belongs_date': _dashDate(previous),
        'category_id': 'demo-category-salary',
        'category_name': 'Salary',
        'flow_type': 'income',
        'amount': 3500,
        'description': '',
        'category_emoji': '\u{1F4BC}',
        'category_bg_color': '#10B981',
      },
    ];
  }

  List<ApiJson> _initialBudgets() {
    final now = DateTime.now();
    final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return [
      {
        'id': 'demo-budget-food',
        'category_id': 'demo-category-food',
        'period': period,
        'limit_amount': 600.0,
      },
      {
        'id': 'demo-budget-transport',
        'category_id': 'demo-category-transportation',
        'period': period,
        'limit_amount': 300.0,
      },
    ];
  }

  static String _dateDigits(Object? value) =>
      value?.toString().replaceAll(RegExp('[^0-9]'), '') ?? '';

  static String _compactDate(DateTime date) =>
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

  static String _dashDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  ApiJson _categoryData({
    required String id,
    required String name,
    required String type,
    String? parentId,
    String? emoji,
    String? bgColor,
    String? remark,
  }) {
    return {
      'Id': id,
      'name': name,
      'type': type,
      'parent_id': parentId,
      'emoji': emoji,
      'bg_color': bgColor,
      'remark': remark,
    };
  }
}
