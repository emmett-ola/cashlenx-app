import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../shared/formatters/money_formatter.dart';
import '../../../shared/formatters/period_formatter.dart';
import '../../../theme/app_theme.dart';
import '../../home/presentation/providers/currency_provider.dart';
import '../data/statistics_repository.dart';
import '../domain/statistics_snapshot.dart';
import 'analytics_context.dart';

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({required this.onBack, super.key});

  final VoidCallback onBack;

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  var _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final storedRange = ref.watch(analyticsRangeProvider);
    final range = storedRange == AnalyticsRange.total
        ? AnalyticsRange.year
        : storedRange;
    final query = StatisticsQuery(range: range, date: _selectedDate);
    final snapshot = ref.watch(statisticsProvider(query));
    final currencySymbol = ref.watch(
      currencyProvider.select((currency) => currency.symbol),
    );

    return ColoredBox(
      color: context.appColors.background,
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(statisticsProvider(query).future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(
              children: [
                Tooltip(
                  message: appT(context, 'back'),
                  excludeFromSemantics: true,
                  child: Semantics(
                    container: true,
                    label: appT(context, 'back'),
                    button: true,
                    onTap: widget.onBack,
                    excludeSemantics: true,
                    child: IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
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
            _RangeSelector(
              range: range,
              onChanged: (value) {
                ref.read(analyticsRangeProvider.notifier).setRange(value);
              },
            ),
            const SizedBox(height: 12),
            _PeriodSelector(
              range: range,
              date: _selectedDate,
              onChanged: (delta) {
                setState(() {
                  _selectedDate = _movePeriod(_selectedDate, range, delta);
                });
              },
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
                  onRetry: () => ref.invalidate(statisticsProvider(query)),
                ),
              ],
              data: (data) => [
                _SummaryGrid(data: data, currencySymbol: currencySymbol),
                const SizedBox(height: 16),
                _SeriesCard(data: data),
                const SizedBox(height: 16),
                _TopExpensesCard(
                  expenses: data.topExpenses,
                  currencySymbol: currencySymbol,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.range, required this.onChanged});

  final AnalyticsRange range;
  final ValueChanged<AnalyticsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AnalyticsRange>(
      key: const ValueKey('statistics-range-selector'),
      segments: [
        for (final value in const [
          AnalyticsRange.day,
          AnalyticsRange.month,
          AnalyticsRange.year,
        ])
          ButtonSegment(value: value, label: Text(appT(context, value.name))),
      ],
      selected: {range},
      showSelectedIcon: false,
      onSelectionChanged: (values) => onChanged(values.single),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.range,
    required this.date,
    required this.onChanged,
  });

  final AnalyticsRange range;
  final DateTime date;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canMoveBack = _periodStart(date, range).year > 1900;
    final canMoveForward = _periodStart(
      date,
      range,
    ).isBefore(_periodStart(DateTime.now(), range));

    return Container(
      key: const ValueKey('statistics-period-selector'),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appColors.border),
      ),
      child: Row(
        children: [
          Tooltip(
            message: appT(context, 'previous_period'),
            excludeFromSemantics: true,
            child: Semantics(
              container: true,
              label: appT(context, 'previous_period'),
              button: true,
              enabled: canMoveBack,
              onTap: canMoveBack ? () => onChanged(-1) : null,
              excludeSemantics: true,
              child: IconButton(
                key: const ValueKey('statistics-previous-period'),
                onPressed: canMoveBack ? () => onChanged(-1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
            ),
          ),
          Expanded(
            child: Text(
              _periodLabel(context, range, date),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Tooltip(
            message: appT(context, 'next_period'),
            excludeFromSemantics: true,
            child: Semantics(
              container: true,
              label: appT(context, 'next_period'),
              button: true,
              enabled: canMoveForward,
              onTap: canMoveForward ? () => onChanged(1) : null,
              excludeSemantics: true,
              child: IconButton(
                key: const ValueKey('statistics-next-period'),
                onPressed: canMoveForward ? () => onChanged(1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.data, required this.currencySymbol});

  final StatisticsSnapshot data;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _MetricCard(
              label: appT(context, 'income'),
              value: data.income,
              currencySymbol: currencySymbol,
              color: AppTheme.successColor,
              icon: Icons.south_west,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              label: appT(context, 'expense'),
              value: data.expense,
              currencySymbol: currencySymbol,
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
        currencySymbol: currencySymbol,
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
    required this.currencySymbol,
    required this.color,
    required this.icon,
    this.wide = false,
  });

  final String label;
  final double value;
  final String currencySymbol;
  final Color color;
  final IconData icon;
  final bool wide;

  @override
  Widget build(BuildContext context) => Container(
    width: wide ? double.infinity : null,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.appColors.border),
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
              Text(label, style: TextStyle(color: context.appColors.mutedText)),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  formatMoney(value, symbol: currencySymbol, fractionDigits: 0),
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

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({required this.data});

  final StatisticsSnapshot data;

  @override
  Widget build(BuildContext context) {
    final maxValue = [
      ...data.seriesIncome,
      ...data.seriesExpense,
    ].fold<double>(0, math.max);
    return _Card(
      title: appT(context, 'income_expense_trend'),
      child: SizedBox(
        key: const ValueKey('statistics-series-chart'),
        height: 190,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final count = math.max(1, data.seriesLabels.length);
            final slotWidth = constraints.maxWidth / count;
            final barWidth = math.max(2.0, math.min(9.0, (slotWidth - 2) / 2));
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < data.seriesLabels.length; index++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _Bar(
                              height: _barHeight(
                                data.seriesIncome[index],
                                maxValue,
                              ),
                              color: AppTheme.successColor,
                              width: barWidth,
                            ),
                            const SizedBox(width: 2),
                            _Bar(
                              height: _barHeight(
                                data.seriesExpense[index],
                                maxValue,
                              ),
                              color: AppTheme.errorColor,
                              width: barWidth,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          child: Text(
                            _seriesLabel(context, data, index),
                            style: TextStyle(
                              color: context.appColors.mutedText,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.color, required this.width});

  final double height;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: math.max(height, 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
    ),
  );
}

class _TopExpensesCard extends StatelessWidget {
  const _TopExpensesCard({
    required this.expenses,
    required this.currencySymbol,
  });

  final List<TopExpense> expenses;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) => _Card(
    title: appT(context, 'top_expenses'),
    child: expenses.isEmpty
        ? const _NoData()
        : Column(
            children: [
              for (final (index, expense) in expenses.indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.errorColor.withValues(alpha: .16),
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
                    '-${formatMoney(expense.amount, symbol: currencySymbol, fractionDigits: 0)}',
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
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.appColors.border),
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
  const _NoData();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: Text(
        appT(context, 'no_statistics_data'),
        style: TextStyle(color: context.appColors.mutedText),
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

DateTime _movePeriod(DateTime date, AnalyticsRange range, int delta) {
  return switch (range) {
    AnalyticsRange.day => date.add(Duration(days: delta)),
    AnalyticsRange.month => DateTime(date.year, date.month + delta),
    AnalyticsRange.year => DateTime(date.year + delta, date.month, date.day),
    AnalyticsRange.total => date,
  };
}

DateTime _periodStart(DateTime date, AnalyticsRange range) {
  return switch (range) {
    AnalyticsRange.day => DateTime(date.year, date.month, date.day),
    AnalyticsRange.month => DateTime(date.year, date.month),
    AnalyticsRange.year => DateTime(date.year),
    AnalyticsRange.total => DateTime(date.year),
  };
}

String _periodLabel(BuildContext context, AnalyticsRange range, DateTime date) {
  final granularity = switch (range) {
    AnalyticsRange.day => PeriodLabelGranularity.day,
    AnalyticsRange.month => PeriodLabelGranularity.month,
    AnalyticsRange.year || AnalyticsRange.total => PeriodLabelGranularity.year,
  };
  return localizedPeriodLabel(
    date,
    locale: Localizations.localeOf(context),
    granularity: granularity,
  );
}

String _seriesLabel(BuildContext context, StatisticsSnapshot data, int index) {
  if (data.range == AnalyticsRange.year) {
    return DateFormat.MMM(Localizations.localeOf(context).toLanguageTag())
        .format(DateTime(2000, index + 1));
  }
  if (data.range == AnalyticsRange.month) {
    final day = index + 1;
    final last = data.seriesLabels.length;
    return day == 1 || day == last || day % 5 == 0 ? '$day' : '';
  }
  return DateFormat.Md(Localizations.localeOf(context).toLanguageTag())
      .format(data.date);
}

double _barHeight(double value, double maximum) {
  return maximum == 0 ? 0 : value / maximum * 130;
}
