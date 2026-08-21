import 'package:cashlenx/features/demo/data/demo_data_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'demo budgets support create update delete and ledger spending',
    () async {
      final store = DemoDataStore();
      final now = DateTime.now();
      final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      var items = _dataList(await store.listBudgets(period: period));
      expect(items, hasLength(2));
      final food = items.firstWhere(
        (item) => item['category_id'] == 'demo-category-food',
      );
      expect(food['spent_amount'], 12.5);

      final created = _dataMap(
        await store.createBudget(
          categoryId: 'demo-category-groceries',
          period: period,
          limitAmount: 250,
        ),
      );
      final id = created['id'].toString();
      items = _dataList(await store.listBudgets(period: period));
      expect(items, hasLength(3));

      await store.updateBudget(
        id,
        categoryId: 'demo-category-groceries',
        period: period,
        limitAmount: 325,
      );
      items = _dataList(await store.listBudgets(period: period));
      expect(items.firstWhere((item) => item['id'] == id)['limit_amount'], 325);

      await store.deleteBudget(id);
      items = _dataList(await store.listBudgets(period: period));
      expect(items, hasLength(2));
    },
  );

  test(
    'demo yearly statistics are derived from current transactions',
    () async {
      final store = DemoDataStore();
      final year = DateTime.now().year.toString();

      final summary = _dataMap(await store.getStatisticYearlySummary(year));
      expect(summary['income'], 3500);
      expect(summary['expense'], 12.5);
      expect(summary['balance'], 3487.5);

      final comparison = _dataMap(await store.getMonthlyComparisonChart(year));
      expect(comparison['months'], hasLength(12));
      expect(comparison['income'], hasLength(12));
      expect(comparison['expense'], hasLength(12));

      final top = _dataMap(
        await store.getStatisticYearlyTop(year: year, limit: 5),
      );
      expect(top['expenses'], hasLength(1));
    },
  );

  test('demo profile and configuration persist until reset', () async {
    final store = DemoDataStore();

    await store.updateProfile(
      nickname: 'Demo Saver',
      avatarUrl: 'avatar-2',
      phoneNumber: '+65 6999 0000',
      location: 'Tampines',
      birthDate: '1990-01-02',
    );
    await store.updateConfiguration(
      displayLanguage: 'zh-Hans',
      currencyCode: 'SGD',
      activeThemeColor: '#004D40',
    );

    expect(
      _dataMap(await store.getProfile()),
      containsPair('location', 'Tampines'),
    );
    expect(
      _dataMap(await store.getConfiguration()),
      containsPair('currency_code', 'SGD'),
    );

    store.reset();
    expect(
      _dataMap(await store.getProfile()),
      containsPair('nickname', 'Demo User'),
    );
    expect(
      _dataMap(await store.getConfiguration()),
      containsPair('currency_code', 'USD'),
    );
  });
}

List<Map<String, dynamic>> _dataList(Map<String, dynamic> response) {
  return (response['data'] as List)
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Map<String, dynamic> _dataMap(Map<String, dynamic> response) {
  return Map<String, dynamic>.from(response['data'] as Map);
}
