import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../theme/app_theme.dart';
import '../data/statistics_repository.dart';
import '../domain/statistics_snapshot.dart';

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  var _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(yearlyStatisticsProvider(_year));
    return ColoredBox(
      color: const Color(0xFFF9FAFB),
      child: RefreshIndicator(
        onRefresh: () async =>
            ref.refresh(yearlyStatisticsProvider(_year).future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    appT(context, 'more_statistics_title'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _YearSelector(
              year: _year,
              onChanged: (delta) => setState(() => _year += delta),
            ),
            const SizedBox(height: 16),
            ...snapshot.when(
              loading: () => const [
                Padding(
                  padding: EdgeInsets.all(64),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (error, stack) => [
                _ErrorCard(
                  onRetry: () =>
                      ref.invalidate(yearlyStatisticsProvider(_year)),
                ),
              ],
              data: (data) => [
                _SummaryGrid(data: data),
                const SizedBox(height: 16),
                _ComparisonCard(data: data),
                const SizedBox(height: 16),
                _TopExpensesCard(expenses: data.topExpenses),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _YearSelector extends StatelessWidget {
  const _YearSelector({required this.year, required this.onChanged});
  final int year;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Row(
      children: [
        IconButton(
          onPressed: () => onChanged(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            '$year',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          onPressed: () => onChanged(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.data});
  final StatisticsSnapshot data;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _MetricCard(
              label: appT(context, 'income'),
              value: data.income,
              color: AppTheme.successColor,
              icon: Icons.south_west,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              label: appT(context, 'expense'),
              value: data.expense,
              color: AppTheme.errorColor,
              icon: Icons.north_east,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _MetricCard(
        label: appT(context, 'total_balance'),
        value: data.balance,
        color: AppTheme.primaryColor,
        icon: Icons.account_balance_wallet_outlined,
        wide: true,
      ),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.wide = false,
  });
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  final bool wide;
  @override
  Widget build(BuildContext context) => Container(
    width: wide ? double.infinity : null,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          foregroundColor: color,
          child: Icon(icon),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  _money(value),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.data});
  final StatisticsSnapshot data;
  @override
  Widget build(BuildContext context) {
    final count = math.min(
      data.months.length,
      math.min(data.monthlyIncome.length, data.monthlyExpense.length),
    );
    final maxValue = [
      ...data.monthlyIncome,
      ...data.monthlyExpense,
    ].fold<double>(0, math.max);
    return _Card(
      title: appT(context, 'monthly_comparison'),
      child: count == 0
          ? _NoData()
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(MediaQuery.sizeOf(context).width - 66, 600),
                height: 190,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(count, (index) {
                    final incomeHeight = maxValue == 0
                        ? 0.0
                        : data.monthlyIncome[index] / maxValue * 130;
                    final expenseHeight = maxValue == 0
                        ? 0.0
                        : data.monthlyExpense[index] / maxValue * 130;
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _Bar(
                                height: incomeHeight,
                                color: AppTheme.successColor,
                              ),
                              const SizedBox(width: 3),
                              _Bar(
                                height: expenseHeight,
                                color: AppTheme.errorColor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            data.months[index],
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.color});
  final double height;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 11,
    height: math.max(height, 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
    ),
  );
}

class _TopExpensesCard extends StatelessWidget {
  const _TopExpensesCard({required this.expenses});
  final List<TopExpense> expenses;
  @override
  Widget build(BuildContext context) => _Card(
    title: appT(context, 'top_expenses'),
    child: expenses.isEmpty
        ? _NoData()
        : Column(
            children: [
              for (final (index, expense) in expenses.indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFEE2E2),
                    foregroundColor: AppTheme.errorColor,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(
                    expense.category,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    expense.description.isEmpty
                        ? expense.date
                        : expense.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '-${_money(expense.amount)}',
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}

class _NoData extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: Text(
        appT(context, 'no_statistics_data'),
        style: const TextStyle(color: Color(0xFF6B7280)),
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton(
      onPressed: onRetry,
      child: Text(appT(context, 'retry')),
    ),
  );
}

String _money(double value) => '\$${value.toStringAsFixed(0)}';
