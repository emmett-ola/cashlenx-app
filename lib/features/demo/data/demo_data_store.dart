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
  late List<ApiJson> _categories;
  late List<ApiJson> _transactions;

  void reset() {
    _nextCategoryId = 100;
    _nextTransactionId = 100;
    _categories = _initialCategories();
    _transactions = _initialTransactions();
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
    return const [
      {
        'id': 'demo-transaction-coffee',
        'belongs_date': '20260517',
        'category_id': 'demo-category-food',
        'category_name': 'Food',
        'flow_type': 'expense',
        'amount': 12.5,
        'description': 'Coffee beans',
        'category': {'emoji': '\u{1F35C}', 'bg_color': '#FF8A65'},
      },
      {
        'id': 'demo-transaction-salary',
        'belongs_date': '2026-05-16',
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
