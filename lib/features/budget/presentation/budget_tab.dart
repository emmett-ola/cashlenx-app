import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_i18n.dart';
import '../../../theme/app_theme.dart';
import '../../demo/data/demo_data_store.dart';
import '../data/budget_repository.dart';
import '../domain/budget_models.dart';

class BudgetTab extends ConsumerStatefulWidget {
  const BudgetTab({super.key});

  @override
  ConsumerState<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends ConsumerState<BudgetTab> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String get _period =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final budgets = ref.watch(monthlyBudgetsProvider(_period));
    return ColoredBox(
      color: const Color(0xFFF9FAFB),
      child: RefreshIndicator(
        onRefresh: () async =>
            ref.refresh(monthlyBudgetsProvider(_period).future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
          children: [
            _Header(onAdd: () => _editBudget()),
            const SizedBox(height: 20),
            _MonthSelector(month: _month, onChanged: _changeMonth),
            const SizedBox(height: 16),
            ...budgets.when(
              loading: () => const [
                Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (error, stack) => [_ErrorCard(onRetry: _refresh)],
              data: (items) => [
                _TotalCard(items: items),
                const SizedBox(height: 22),
                Text(
                  appT(context, 'category_budgets'),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty) _EmptyBudget(onAdd: () => _editBudget()),
                for (final item in items) ...[
                  _BudgetTile(
                    item: item,
                    onEdit: () => _editBudget(item),
                    onDelete: () => _deleteBudget(item),
                  ),
                  const SizedBox(height: 12),
                ],
                if (items.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () => _editBudget(),
                    icon: const Icon(Icons.add),
                    label: Text(appT(context, 'add_new_budget')),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _refresh() => ref.invalidate(monthlyBudgetsProvider(_period));

  Future<void> _editBudget([BudgetItem? existing]) async {
    List<BudgetCategory> categories;
    try {
      categories = await ref.read(budgetRepositoryProvider).expenseCategories();
    } catch (error) {
      if (mounted) _showError(error);
      return;
    }
    if (!mounted) return;
    final result = await showDialog<_BudgetDraft>(
      context: context,
      builder: (context) =>
          _BudgetDialog(existing: existing, categories: categories),
    );
    if (result == null || !mounted) return;
    try {
      await ref
          .read(budgetRepositoryProvider)
          .save(
            existing: existing,
            categoryId: result.categoryId,
            period: _period,
            limit: result.limit,
          );
      ref.read(demoDataRevisionProvider.notifier).bump();
      _refresh();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _deleteBudget(BudgetItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(appT(context, 'delete')),
        content: Text(item.categoryName),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(appT(context, 'cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: Text(appT(context, 'delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(budgetRepositoryProvider).delete(item.id);
      ref.read(demoDataRevisionProvider.notifier).bump();
      _refresh();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appT(context, 'budgets'),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              appT(context, 'budget_subtitle'),
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
      IconButton.filled(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        style: IconButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    ],
  );
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({required this.month, required this.onChanged});
  final DateTime month;
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
            '${month.year}-${month.month.toString().padLeft(2, '0')}',
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

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.items});
  final List<BudgetItem> items;
  @override
  Widget build(BuildContext context) {
    final limit = items.fold<double>(0, (sum, item) => sum + item.limit);
    final spent = items.fold<double>(0, (sum, item) => sum + item.spent);
    final progress = limit <= 0 ? 0.0 : spent / limit;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF008080), Color(0xFF4A6363)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appT(context, 'total_monthly_budget'),
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _money(limit),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${appT(context, 'spent')}: ${_money(spent)}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              Text(
                '${appT(context, 'remaining')}: ${_money(limit - spent)}',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 9,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ],
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });
  final BudgetItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final over = item.spent > item.limit;
    final color = over
        ? AppTheme.errorColor
        : item.progress >= .8
        ? const Color(0xFFF59E0B)
        : AppTheme.successColor;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: .12),
                    foregroundColor: color,
                    child: Text(
                      item.categoryName.characters.first.toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.categoryName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_money(item.spent)} / ${_money(item.limit)}',
                          style: const TextStyle(color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) =>
                        value == 'edit' ? onEdit() : onDelete(),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(appT(context, 'edit')),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(appT(context, 'delete')),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: item.progress.clamp(0, 1),
                minHeight: 8,
                borderRadius: BorderRadius.circular(99),
                backgroundColor: const Color(0xFFF3F4F6),
                valueColor: AlwaysStoppedAnimation(color),
              ),
              const SizedBox(height: 7),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${(item.progress * 100).round()}% ${appT(context, 'used')}',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBudget extends StatelessWidget {
  const _EmptyBudget({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        const Icon(Icons.savings_outlined, size: 42, color: Color(0xFF6B7280)),
        const SizedBox(height: 10),
        Text(
          appT(context, 'no_budgets_yet'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text(appT(context, 'add_new_budget')),
        ),
      ],
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      children: [
        const Icon(Icons.cloud_off_outlined, size: 42),
        const SizedBox(height: 10),
        FilledButton(onPressed: onRetry, child: Text(appT(context, 'retry'))),
      ],
    ),
  );
}

class _BudgetDraft {
  const _BudgetDraft(this.categoryId, this.limit);
  final String categoryId;
  final double limit;
}

class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({required this.existing, required this.categories});
  final BudgetItem? existing;
  final List<BudgetCategory> categories;
  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  late String? _categoryId =
      widget.existing?.categoryId ??
      (widget.categories.isEmpty ? null : widget.categories.first.id);
  late final TextEditingController _amount = TextEditingController(
    text: widget.existing?.limit.toStringAsFixed(0) ?? '',
  );
  String? _error;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existing == null
          ? appT(context, 'add_new_budget')
          : appT(context, 'edit'),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _categoryId,
          decoration: InputDecoration(labelText: appT(context, 'category')),
          items: widget.categories
              .map(
                (item) =>
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
              )
              .toList(),
          onChanged: (value) => setState(() => _categoryId = value),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: appT(context, 'amount'),
            prefixText: r'$ ',
            errorText: _error,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(appT(context, 'cancel')),
      ),
      FilledButton(onPressed: _submit, child: Text(appT(context, 'save'))),
    ],
  );
  void _submit() {
    final amount = double.tryParse(_amount.text.trim());
    if (_categoryId == null || amount == null || amount <= 0) {
      setState(() => _error = appT(context, 'enter_amount_gt_zero'));
      return;
    }
    Navigator.pop(context, _BudgetDraft(_categoryId!, amount));
  }
}

String _money(double value) => '\$${value.toStringAsFixed(0)}';
