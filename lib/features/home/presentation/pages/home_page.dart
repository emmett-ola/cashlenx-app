import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/response_wrapper.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../network/cashlenx_api.dart';
import '../../../../theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final _dashboardProvider = FutureProvider<_DashboardResponse>((ref) {
  return _DashboardApi(ref.watch(cashlenxApiProvider)).fetchDashboard();
});

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  var _selectedTab = _HomeTab.home;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).value;
    final username = user?.username ?? 'User';
    final isDemo = user?.role == 'demo';

    return Scaffold(
      backgroundColor: _AppShellColors.background,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedTab.index,
          children: [
            _DashboardTab(
              username: username,
              isDemo: isDemo,
              onAction: _showComingSoon,
              onSeeAllTransactions: () => _showComingSoon('Transactions'),
            ),
            _StatsTab(onAction: _showComingSoon),
            _AddPlaceholderTab(onAction: _showComingSoon),
            _BudgetTab(onAction: _showComingSoon),
            _SettingsTab(
              username: username,
              email: isDemo ? 'demo@cashlenx.com' : user?.username ?? '',
              onAction: _showComingSoon,
              onLogout: () {
                ref.read(authNotifierProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        selectedTab: _selectedTab,
        onSelect: (tab) {
          if (tab == _HomeTab.add) {
            _showComingSoon('Add transaction');
            return;
          }
          setState(() => _selectedTab = tab);
        },
      ),
    );
  }

  void _showComingSoon(String feature) {
    ToastUtils.showSuccess(context, '$feature coming soon!');
  }
}

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab({
    required this.username,
    required this.isDemo,
    required this.onAction,
    required this.onSeeAllTransactions,
  });

  final String username;
  final bool isDemo;
  final ValueChanged<String> onAction;
  final VoidCallback onSeeAllTransactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(_dashboardProvider);

    return dashboard.when(
      loading: () => const _LoadingPage(title: 'Home'),
      error: (error, stackTrace) => _ErrorPage(
        onRetry: () {
          ref.invalidate(_dashboardProvider);
        },
      ),
      data: (data) => _PageScaffold(
        header: _DashboardHeader(
          username: username,
          isDemo: isDemo,
          onProfileTap: () => onAction('Profile'),
        ),
        children: [
          _SummaryCard(summary: data.summary),
          _QuickActions(onAction: onAction),
          _BudgetPreview(budget: data.budget, onTap: () => onAction('Budget')),
          _RecentActivity(
            transactions: data.recentTransactions,
            onSeeAll: onSeeAllTransactions,
          ),
        ],
      ),
    );
  }
}

class _StatsTab extends ConsumerWidget {
  const _StatsTab({required this.onAction});

  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(_dashboardProvider);

    return dashboard.when(
      loading: () => const _LoadingPage(title: 'Statistics'),
      error: (error, stackTrace) => _ErrorPage(
        onRetry: () {
          ref.invalidate(_dashboardProvider);
        },
      ),
      data: (data) => _PageScaffold(
        title: 'Statistics',
        subtitle: 'Your financial insights',
        trailing: _RoundIconButton(
          icon: Icons.tune,
          onPressed: () => onAction('Filters'),
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.trending_up,
                  iconColor: AppTheme.successColor,
                  label: 'Income',
                  value: _money(data.summary.income),
                  caption: '+12% from last month',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  icon: Icons.trending_down,
                  iconColor: AppTheme.errorColor,
                  label: 'Expenses',
                  value: _money(data.summary.expense),
                  caption: '+8% from last month',
                ),
              ),
            ],
          ),
          _CategoryBreakdown(categories: data.categoryBreakdown),
          _TopMerchants(merchants: data.topMerchants),
        ],
      ),
    );
  }
}

class _BudgetTab extends ConsumerWidget {
  const _BudgetTab({required this.onAction});

  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(_dashboardProvider);

    return dashboard.when(
      loading: () => const _LoadingPage(title: 'Budget'),
      error: (error, stackTrace) => _ErrorPage(
        onRetry: () {
          ref.invalidate(_dashboardProvider);
        },
      ),
      data: (data) => _PageScaffold(
        title: 'Budget',
        subtitle: 'Manage your spending limits',
        trailing: _RoundIconButton(
          icon: Icons.add,
          onPressed: () => onAction('Add budget'),
        ),
        children: [
          _TotalBudgetCard(budget: data.budget),
          Text('Category Budgets', style: _sectionTitle(context)),
          ...data.categoryBudgets.map(_CategoryBudgetTile.new),
          OutlinedButton.icon(
            onPressed: () => onAction('Add budget'),
            icon: const Icon(Icons.add),
            label: const Text('Add New Budget'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPlaceholderTab extends StatelessWidget {
  const _AddPlaceholderTab({required this.onAction});

  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: 'Add Transaction',
      subtitle: 'Capture income and expenses',
      children: [
        _EmptyStateCard(
          icon: Icons.receipt_long,
          title: 'Transaction entry is coming soon',
          message: 'The screen is reserved for the real add transaction flow.',
          actionLabel: 'Notify Me',
          onAction: () => onAction('Add transaction'),
        ),
      ],
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.username,
    required this.email,
    required this.onAction,
    required this.onLogout,
  });

  final String username;
  final String email;
  final ValueChanged<String> onAction;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: 'Settings',
      children: [
        _ProfileCard(
          username: username,
          email: email,
          onTap: () => onAction('Profile'),
        ),
        _SettingsSection(
          title: 'Preferences',
          children: [
            _SettingsTile(
              icon: Icons.palette_outlined,
              color: AppTheme.primaryColor,
              label: 'Theme Color',
              trailing: const _ColorDot(color: AppTheme.primaryColor),
              onTap: () => onAction('Theme Color'),
            ),
            _SettingsTile(
              icon: Icons.account_tree_outlined,
              color: AppTheme.primaryColor,
              label: 'Manage Categories',
              onTap: () => onAction('Manage Categories'),
            ),
          ],
        ),
        _SettingsSection(
          title: 'Privacy & Security',
          children: [
            _SettingsTile(
              icon: Icons.visibility_outlined,
              color: const Color(0xFF2563EB),
              label: 'Privacy Settings',
              onTap: () => onAction('Privacy Settings'),
            ),
            _SettingsTile(
              icon: Icons.lock_outline,
              color: const Color(0xFF7C3AED),
              label: 'Security',
              onTap: () => onAction('Security'),
            ),
            _SettingsTile(
              icon: Icons.notifications_none,
              color: const Color(0xFFF97316),
              label: 'Notifications',
              onTap: () => onAction('Notifications'),
            ),
          ],
        ),
        _SettingsSection(
          title: 'Support',
          children: [
            _SettingsTile(
              icon: Icons.help_outline,
              color: AppTheme.successColor,
              label: 'Help & Support',
              onTap: () => onAction('Help & Support'),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Log Out'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.errorColor,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const Center(
          child: Text(
            'CashLenX v1.0.0',
            style: TextStyle(color: _AppShellColors.mutedText),
          ),
        ),
      ],
    );
  }
}

class _PageScaffold extends StatelessWidget {
  const _PageScaffold({
    this.title,
    this.subtitle,
    this.header,
    this.trailing,
    required this.children,
  });

  final String? title;
  final String? subtitle;
  final Widget? header;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child:
              header ??
              _StandardHeader(
                title: title ?? '',
                subtitle: subtitle,
                trailing: trailing,
              ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
          sliver: SliverList.separated(
            itemBuilder: (context, index) => children[index],
            separatorBuilder: (context, index) => const SizedBox(height: 18),
            itemCount: children.length,
          ),
        ),
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.username,
    required this.isDemo,
    required this.onProfileTap,
  });

  final String username;
  final bool isDemo;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _AppShellColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_greeting()},',
                  style: const TextStyle(
                    color: _AppShellColors.mutedText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                TextButton(
                  onPressed: onProfileTap,
                  style: TextButton.styleFrom(
                    foregroundColor: _AppShellColors.text,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(username, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          if (isDemo)
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Demo',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          _AvatarButton(username: username, onTap: onProfileTap),
        ],
      ),
    );
  }
}

class _StandardHeader extends StatelessWidget {
  const _StandardHeader({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _AppShellColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _pageTitle(context)),
                ...?subtitle == null
                    ? null
                    : [
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: _AppShellColors.mutedText,
                          ),
                        ),
                      ],
              ],
            ),
          ),
          ...?trailing == null ? null : [trailing!],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatefulWidget {
  const _SummaryCard({required this.summary});

  final _Summary summary;

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  var _selectedRange = _SummaryRange.month;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary.range(_selectedRange);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: _SummaryRangeSwitcher(
              selectedRange: _selectedRange,
              onChanged: (range) {
                setState(() => _selectedRange = range);
              },
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 120),
                child: Text(
                  summary.balanceLabel,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _money(summary.totalBalance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _SummaryMetric(
                      icon: Icons.south_west,
                      label: 'Income',
                      value: _money(summary.income),
                      iconColor: AppTheme.successColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _SummaryMetric(
                      icon: Icons.north_east,
                      label: 'Expense',
                      value: _money(summary.expense),
                      iconColor: AppTheme.errorColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRangeSwitcher extends StatelessWidget {
  const _SummaryRangeSwitcher({
    required this.selectedRange,
    required this.onChanged,
  });

  final _SummaryRange selectedRange;
  final ValueChanged<_SummaryRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _SummaryRange.values.map((range) {
          final isSelected = range == selectedRange;

          return Semantics(
            button: true,
            selected: isSelected,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onChanged(range),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  range.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onAction});

  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickActionButton(
          icon: Icons.document_scanner_outlined,
          label: 'Scan',
          onTap: () => onAction('Scan'),
        ),
        const SizedBox(width: 12),
        _QuickActionButton(
          icon: Icons.send_outlined,
          label: 'Transfer',
          onTap: () => onAction('Transfer'),
        ),
        const SizedBox(width: 12),
        _QuickActionButton(
          icon: Icons.receipt_long_outlined,
          label: 'Bills',
          onTap: () => onAction('Bills'),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AppShellColors.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetPreview extends StatelessWidget {
  const _BudgetPreview({required this.budget, required this.onTap});

  final _BudgetSummary budget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Card(
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Budget',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _AppShellColors.text,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Fixed mock data',
                      style: TextStyle(
                        color: _AppShellColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${budget.percentUsed.round()}%',
                style: const TextStyle(
                  color: Color(0xFFFF8A65),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: budget.percentUsed / 100,
              minHeight: 8,
              backgroundColor: _AppShellColors.softGray,
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_money(budget.spent, decimals: 0)} spent',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _AppShellColors.mutedText),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '${_money(budget.limit, decimals: 0)} limit',
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: _AppShellColors.mutedText),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.transactions, required this.onSeeAll});

  final List<_Transaction> transactions;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent Activity',
                  overflow: TextOverflow.ellipsis,
                  style: _sectionTitle(context),
                ),
              ),
              TextButton.icon(
                onPressed: onSeeAll,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.chevron_right, size: 18),
                label: const Text('See All'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...transactions.map((transaction) {
            final isLast = transaction == transactions.last;
            return Column(
              children: [
                _TransactionTile(transaction: transaction),
                if (!isLast) const Divider(height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final _Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final isPositive = transaction.amount >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: transaction.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(transaction.icon, color: transaction.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AppShellColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  transaction.dateLabel,
                  style: const TextStyle(
                    color: _AppShellColors.mutedText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? '+' : '-'}${_money(transaction.amount.abs())}',
                style: TextStyle(
                  color: isPositive
                      ? AppTheme.successColor
                      : _AppShellColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                transaction.category,
                style: const TextStyle(
                  color: _AppShellColors.mutedText,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _AppShellColors.mutedText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: _cardValue(context)),
          ),
          const SizedBox(height: 4),
          Text(caption, style: TextStyle(color: iconColor, fontSize: 12)),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.categories});

  final List<_CategoryBreakdownItem> categories;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spending by Category', style: _sectionTitle(context)),
          const SizedBox(height: 18),
          ...categories.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            color: _AppShellColors.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _money(item.amount, decimals: 0),
                        style: const TextStyle(
                          color: _AppShellColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: item.percent / 100,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: _AppShellColors.softGray,
                    valueColor: AlwaysStoppedAnimation(item.color),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopMerchants extends StatelessWidget {
  const _TopMerchants({required this.merchants});

  final List<_Merchant> merchants;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Spending Sources', style: _sectionTitle(context)),
          const SizedBox(height: 14),
          ...merchants.indexed.map((entry) {
            final index = entry.$1;
            final merchant = entry.$2;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primaryColor.withValues(
                      alpha: 0.1,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      merchant.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AppShellColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _money(merchant.amount),
                    style: const TextStyle(
                      color: _AppShellColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TotalBudgetCard extends StatelessWidget {
  const _TotalBudgetCard({required this.budget});

  final _BudgetSummary budget;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Monthly Budget',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _money(budget.limit, decimals: 0),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Spent: ${_money(budget.spent, decimals: 0)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    Text(
                      'Remaining: ${_money(budget.remaining, decimals: 0)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: budget.percentUsed / 100,
                  minHeight: 9,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetTile extends StatelessWidget {
  const _CategoryBudgetTile(this.budget);

  final _CategoryBudget budget;

  @override
  Widget build(BuildContext context) {
    final percent = budget.percentUsed;
    final isOverBudget = budget.spent > budget.limit;
    final statusColor = isOverBudget
        ? AppTheme.errorColor
        : percent >= 80
        ? const Color(0xFFF59E0B)
        : AppTheme.successColor;

    return _Card(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: budget.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    budget.icon,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.category,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AppShellColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_money(budget.spent, decimals: 0)} of ${_money(budget.limit, decimals: 0)}',
                      style: const TextStyle(color: _AppShellColors.mutedText),
                    ),
                  ],
                ),
              ),
              if (isOverBudget)
                const Icon(Icons.error_outline, color: AppTheme.errorColor),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: percent.clamp(0, 100) / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: _AppShellColors.softGray,
            valueColor: AlwaysStoppedAnimation(statusColor),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${percent.round()}% used',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${_money(budget.remaining, decimals: 0)} left',
                style: const TextStyle(color: _AppShellColors.mutedText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: _AppShellColors.mutedText,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        _Card(
          padding: EdgeInsets.zero,
          child: Column(
            children: children.indexed.map((entry) {
              final index = entry.$1;
              final child = entry.$2;
              return Column(
                children: [
                  child,
                  if (index != children.length - 1)
                    const Divider(height: 1, indent: 64),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _AppShellColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.username,
    required this.email,
    required this.onTap,
  });

  final String username;
  final String email;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Card(
      onTap: onTap,
      child: Row(
        children: [
          _AvatarBadge(username: username),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AppShellColors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _AppShellColors.mutedText),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.black38),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedTab, required this.onSelect});

  final _HomeTab selectedTab;
  final ValueChanged<_HomeTab> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _AppShellColors.border)),
      ),
      padding: EdgeInsets.only(
        left: 6,
        right: 6,
        top: 8,
        bottom: MediaQuery.paddingOf(context).bottom + 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _HomeTab.values.map((tab) {
          final isAdd = tab == _HomeTab.add;
          final isSelected = selectedTab == tab;

          if (isAdd) {
            return Expanded(
              child: Semantics(
                button: true,
                label: tab.label,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onSelect(tab),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x33008080),
                              blurRadius: 14,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(tab.icon, color: Colors.white, size: 29),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tab.label,
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelect(tab),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : _AppShellColors.navMuted,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tab.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : _AppShellColors.navMuted,
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.username, required this.onTap});

  final String username;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: _AvatarBadge(username: username),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    final initial = username.trim().isEmpty ? 'U' : username.trim()[0];

    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: _AppShellColors.border, width: 2),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 34),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: _sectionTitle(context),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _AppShellColors.mutedText),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: title,
      children: const [
        Center(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: CircularProgressIndicator(),
          ),
        ),
      ],
    );
  }
}

class _ErrorPage extends StatelessWidget {
  const _ErrorPage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: 'Home',
      children: [
        _EmptyStateCard(
          icon: Icons.error_outline,
          title: 'Dashboard data failed to load',
          message: 'The mock request did not complete.',
          actionLabel: 'Retry',
          onAction: onRetry,
        ),
      ],
    );
  }
}

enum _HomeTab {
  home('Home', Icons.home_outlined),
  stats('Stats', Icons.bar_chart_outlined),
  add('Add', Icons.add),
  budget('Budget', Icons.account_balance_wallet_outlined),
  settings('Settings', Icons.settings_outlined);

  const _HomeTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _DashboardApi {
  const _DashboardApi(this._api);

  final CashlenxApi _api;

  Future<_DashboardResponse> fetchDashboard() async {
    final now = DateTime.now();
    final month = _monthToken(now);
    final year = _yearToken(now);

    final responses = await Future.wait([
      _api.getMonthlySummary(month),
      _api.getYearlySummary(year),
    ]);

    return _DashboardResponse.mock(
      summary: _Summary.fromApi(
        month: _CashSummary.fromResponse(responses[0]),
        year: _CashSummary.fromResponse(responses[1]),
      ),
    );
  }

  static String _monthToken(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}';
  }

  static String _yearToken(DateTime date) => date.year.toString();
}

class _DashboardResponse {
  const _DashboardResponse({
    required this.summary,
    required this.budget,
    required this.recentTransactions,
    required this.categoryBreakdown,
    required this.topMerchants,
    required this.categoryBudgets,
  });

  final _Summary summary;
  final _BudgetSummary budget;
  final List<_Transaction> recentTransactions;
  final List<_CategoryBreakdownItem> categoryBreakdown;
  final List<_Merchant> topMerchants;
  final List<_CategoryBudget> categoryBudgets;

  factory _DashboardResponse.mock({_Summary? summary}) {
    summary ??= const _Summary(
      monthBalance: 8247.35,
      monthIncome: 3500,
      monthExpense: 1215,
      yearBalance: 7010.25,
      yearIncome: 2870,
      yearExpense: 1069.20,
    );
    const budget = _BudgetSummary(spent: 1215, limit: 2000);

    return _DashboardResponse(
      summary: summary,
      budget: budget,
      recentTransactions: const [
        _Transaction(
          title: 'Grocery Shopping',
          dateLabel: 'Today, 2:30 PM',
          amount: -85.50,
          category: 'Shopping',
          icon: Icons.shopping_cart_outlined,
          color: Color(0xFFFF8A65),
        ),
        _Transaction(
          title: 'Coffee Shop',
          dateLabel: 'Today, 9:15 AM',
          amount: -12.50,
          category: 'Food',
          icon: Icons.local_cafe_outlined,
          color: Color(0xFFF59E0B),
        ),
        _Transaction(
          title: 'Uber Ride',
          dateLabel: 'Yesterday, 6:45 PM',
          amount: -18.00,
          category: 'Transport',
          icon: Icons.directions_car_outlined,
          color: AppTheme.primaryColor,
        ),
        _Transaction(
          title: 'Movie Tickets',
          dateLabel: 'Yesterday, 7:00 PM',
          amount: -35.00,
          category: 'Entertainment',
          icon: Icons.movie_outlined,
          color: Color(0xFF4A6363),
        ),
        _Transaction(
          title: 'Salary Deposit',
          dateLabel: 'Feb 1, 9:00 AM',
          amount: 3500.00,
          category: 'Income',
          icon: Icons.bolt_outlined,
          color: AppTheme.successColor,
        ),
      ],
      categoryBreakdown: const [
        _CategoryBreakdownItem(
          name: 'Food',
          amount: 450,
          percent: 33,
          color: Color(0xFFFF8A65),
        ),
        _CategoryBreakdownItem(
          name: 'Shopping',
          amount: 320,
          percent: 24,
          color: AppTheme.secondaryColor,
        ),
        _CategoryBreakdownItem(
          name: 'Transport',
          amount: 180,
          percent: 13,
          color: Color(0xFFFFB74D),
        ),
        _CategoryBreakdownItem(
          name: 'Home',
          amount: 280,
          percent: 21,
          color: Color(0xFF9575CD),
        ),
        _CategoryBreakdownItem(
          name: 'Others',
          amount: 120,
          percent: 9,
          color: Color(0xFF90A4AE),
        ),
      ],
      topMerchants: const [
        _Merchant(name: 'Amazon', amount: 245.50),
        _Merchant(name: 'Walmart', amount: 187.30),
        _Merchant(name: 'Starbucks', amount: 156.80),
        _Merchant(name: 'Uber', amount: 142.20),
      ],
      categoryBudgets: const [
        _CategoryBudget(
          category: 'Food & Dining',
          spent: 450,
          limit: 600,
          color: Color(0xFFFF8A65),
          icon: 'FD',
        ),
        _CategoryBudget(
          category: 'Shopping',
          spent: 820,
          limit: 800,
          color: AppTheme.secondaryColor,
          icon: 'SH',
        ),
        _CategoryBudget(
          category: 'Transportation',
          spent: 180,
          limit: 300,
          color: Color(0xFFFFB74D),
          icon: 'TR',
        ),
        _CategoryBudget(
          category: 'Entertainment',
          spent: 150,
          limit: 200,
          color: Color(0xFF9575CD),
          icon: 'EN',
        ),
      ],
    );
  }
}

class _Summary {
  const _Summary({
    required this.monthBalance,
    required this.monthIncome,
    required this.monthExpense,
    required this.yearBalance,
    required this.yearIncome,
    required this.yearExpense,
  });

  final double monthBalance;
  final double monthIncome;
  final double monthExpense;
  final double yearBalance;
  final double yearIncome;
  final double yearExpense;

  factory _Summary.fromApi({
    required _CashSummary month,
    required _CashSummary year,
  }) {
    return _Summary(
      monthBalance: month.balance,
      monthIncome: month.totalIncome,
      monthExpense: month.totalExpense,
      yearBalance: year.balance,
      yearIncome: year.totalIncome,
      yearExpense: year.totalExpense,
    );
  }

  double get totalBalance => monthBalance;

  double get income => monthIncome;

  double get expense => monthExpense;

  _SummaryRangeValues range(_SummaryRange range) {
    return switch (range) {
      _SummaryRange.month => _SummaryRangeValues(
        balanceLabel: 'Monthly Balance',
        totalBalance: monthBalance,
        income: monthIncome,
        expense: monthExpense,
      ),
      _SummaryRange.year => _SummaryRangeValues(
        balanceLabel: 'Yearly Balance',
        totalBalance: yearBalance,
        income: yearIncome,
        expense: yearExpense,
      ),
    };
  }
}

class _SummaryRangeValues {
  const _SummaryRangeValues({
    required this.balanceLabel,
    required this.totalBalance,
    required this.income,
    required this.expense,
  });

  final String balanceLabel;
  final double totalBalance;
  final double income;
  final double expense;
}

enum _SummaryRange {
  month('Month'),
  year('Year');

  const _SummaryRange(this.label);

  final String label;
}

class _CashSummary {
  const _CashSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
  });

  final double totalIncome;
  final double totalExpense;
  final double balance;

  factory _CashSummary.fromResponse(ApiJson response) {
    final wrapper = ResponseWrapper<_CashSummary>.fromJson(
      response,
      (json) => _CashSummary.fromJson(json as Map<String, dynamic>),
    );

    if (wrapper.data == null) {
      throw Exception(wrapper.message);
    }

    return wrapper.data!;
  }

  factory _CashSummary.fromJson(Map<String, dynamic> json) {
    return _CashSummary(
      totalIncome: _jsonDouble(json['total_income']),
      totalExpense: _jsonDouble(json['total_expense']),
      balance: _jsonDouble(json['balance']),
    );
  }
}

class _BudgetSummary {
  const _BudgetSummary({required this.spent, required this.limit});

  final double spent;
  final double limit;

  double get remaining => limit - spent;

  double get percentUsed => limit == 0 ? 0 : (spent / limit) * 100;
}

class _Transaction {
  const _Transaction({
    required this.title,
    required this.dateLabel,
    required this.amount,
    required this.category,
    required this.icon,
    required this.color,
  });

  final String title;
  final String dateLabel;
  final double amount;
  final String category;
  final IconData icon;
  final Color color;
}

class _CategoryBreakdownItem {
  const _CategoryBreakdownItem({
    required this.name,
    required this.amount,
    required this.percent,
    required this.color,
  });

  final String name;
  final double amount;
  final double percent;
  final Color color;
}

class _Merchant {
  const _Merchant({required this.name, required this.amount});

  final String name;
  final double amount;
}

class _CategoryBudget {
  const _CategoryBudget({
    required this.category,
    required this.spent,
    required this.limit,
    required this.color,
    required this.icon,
  });

  final String category;
  final double spent;
  final double limit;
  final Color color;
  final String icon;

  double get remaining => limit - spent;

  double get percentUsed => limit == 0 ? 0 : (spent / limit) * 100;
}

class _AppShellColors {
  const _AppShellColors._();

  static const background = Color(0xFFF9FAFB);
  static const border = Color(0xFFE5E7EB);
  static const mutedText = Color(0xFF6B7280);
  static const navMuted = Color(0xFF9CA3AF);
  static const softGray = Color(0xFFE5E7EB);
  static const text = Color(0xFF111827);
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good Morning';
  if (hour < 18) return 'Good Afternoon';
  return 'Good Evening';
}

String _money(double value, {int decimals = 2}) {
  final sign = value < 0 ? '-' : '';
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts.first;
  final buffer = StringBuffer();

  for (var i = 0; i < whole.length; i++) {
    if (i != 0 && (whole.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(whole[i]);
  }

  final cents = decimals == 0 ? '' : '.${parts[1]}';
  return '$sign\$${buffer.toString()}$cents';
}

double _jsonDouble(Object? value) {
  return switch (value) {
    num number => number.toDouble(),
    String text => double.tryParse(text) ?? 0,
    _ => 0,
  };
}

TextStyle _pageTitle(BuildContext context) {
  return Theme.of(context).textTheme.headlineSmall!.copyWith(
    color: _AppShellColors.text,
    fontWeight: FontWeight.w800,
  );
}

TextStyle _sectionTitle(BuildContext context) {
  return Theme.of(context).textTheme.titleMedium!.copyWith(
    color: _AppShellColors.text,
    fontWeight: FontWeight.w800,
  );
}

TextStyle _cardValue(BuildContext context) {
  return Theme.of(context).textTheme.titleLarge!.copyWith(
    color: _AppShellColors.text,
    fontWeight: FontWeight.w800,
  );
}
