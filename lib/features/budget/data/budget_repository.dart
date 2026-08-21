import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../network/cashlenx_api.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../demo/data/demo_data_store.dart';
import '../domain/budget_models.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final isDemo = ref.watch(authNotifierProvider).value?.role == 'demo';
  return BudgetRepository(
    api: ref.watch(cashlenxApiProvider),
    demo: ref.watch(demoDataStoreProvider),
    isDemo: isDemo,
  );
});

final monthlyBudgetsProvider = FutureProvider.family<List<BudgetItem>, String>((
  ref,
  period,
) async {
  ref.watch(demoDataRevisionProvider);
  final api = ref.watch(cashlenxApiProvider);
  final demo = ref.watch(demoDataStoreProvider);
  final user = await ref.watch(authNotifierProvider.future);
  return BudgetRepository(
    api: api,
    demo: demo,
    isDemo: user?.role == 'demo',
  ).list(period);
});

class BudgetRepository {
  const BudgetRepository({
    required CashlenxApi api,
    required DemoDataStore demo,
    required bool isDemo,
  }) : _api = api,
       _demo = demo,
       _isDemo = isDemo;

  final CashlenxApi _api;
  final DemoDataStore _demo;
  final bool _isDemo;

  Future<List<BudgetItem>> list(String period) async {
    final response = _isDemo
        ? await _demo.listBudgets(period: period)
        : await _api.listBudgets(period: period);
    return _listData(response)
        .whereType<Map>()
        .map((item) => BudgetItem.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<List<BudgetCategory>> expenseCategories() async {
    final response = _isDemo
        ? await _demo.listAllCategories(type: 'expense')
        : await _api.listAllCategories(type: 'expense', limit: 200);
    return _listData(response)
        .whereType<Map>()
        .map((item) => BudgetCategory.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> save({
    BudgetItem? existing,
    required String categoryId,
    required String period,
    required double limit,
  }) async {
    if (existing == null) {
      if (_isDemo) {
        await _demo.createBudget(
          categoryId: categoryId,
          period: period,
          limitAmount: limit,
        );
      } else {
        await _api.createBudget(
          categoryId: categoryId,
          period: period,
          limitAmount: limit,
        );
      }
      return;
    }
    if (_isDemo) {
      await _demo.updateBudget(
        existing.id,
        categoryId: categoryId,
        period: period,
        limitAmount: limit,
      );
    } else {
      await _api.updateBudget(
        existing.id,
        categoryId: categoryId,
        period: period,
        limitAmount: limit,
      );
    }
  }

  Future<void> delete(String id) async {
    if (_isDemo) {
      await _demo.deleteBudget(id);
    } else {
      await _api.deleteBudget(id);
    }
  }
}

Object? _unwrap(Map<String, dynamic> response) {
  return response.containsKey('data') ? response['data'] : response;
}

List<dynamic> _listData(Map<String, dynamic> response) {
  final first = _unwrap(response);
  if (first is List) return first;
  if (first is Map && first['data'] is List) return first['data'] as List;
  return const [];
}
