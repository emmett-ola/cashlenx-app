part of '../home_page.dart';

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab({
    required this.username,
    required this.avatarUrl,
    required this.onTransactionTap,
    required this.onProfileTap,
    required this.onSeeAllTransactions,
    required this.onMoreStats,
  });

  final String username;
  final String? avatarUrl;
  final ValueChanged<_Transaction> onTransactionTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSeeAllTransactions;
  final VoidCallback onMoreStats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(_dashboardProvider);

    return dashboard.when(
      loading: () => _LoadingPage(title: appT(context, 'home')),
      error: (error, stackTrace) => _ErrorPage(
        onRetry: () {
          ref.invalidate(_dashboardProvider);
        },
      ),
      data: (data) => _PageScaffold(
        header: _DashboardHeader(
          username: username,
          avatarUrl: avatarUrl,
          onProfileTap: onProfileTap,
        ),
        children: [
          _SummaryCard(summary: data.summary),
          _RecentActivity(
            transactions: data.recentTransactions,
            onSeeAll: onSeeAllTransactions,
            onTransactionTap: onTransactionTap,
          ),
          _SpendingByCategoryCard(
            categories: data.categoryBreakdown,
            onMoreStats: onMoreStats,
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.username,
    required this.avatarUrl,
    required this.onProfileTap,
  });

  final String username;
  final String? avatarUrl;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
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
                GestureDetector(
                  onTap: onProfileTap,
                  child: Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _AppShellColors.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _greeting(context),
                  style: const TextStyle(
                    color: _AppShellColors.mutedText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _AvatarButton(
            username: username,
            avatarUrl: avatarUrl,
            onTap: onProfileTap,
          ),
        ],
      ),
    );
  }
}

class _StandardHeader extends StatelessWidget {
  const _StandardHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

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
  var _selectedRange = _SummaryRange.total;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary.range(_selectedRange);
    final themeColor = _themeColor(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [themeColor, AppTheme.secondaryColor],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  MediaQuery.sizeOf(context).width <= 340 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3;
              final label = Text(
                appT(context, _summaryBalanceKey(_selectedRange)),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              );
              final switcher = _SummaryRangeSwitcher(
                selectedRange: _selectedRange,
                onChanged: (range) {
                  setState(() => _selectedRange = range);
                },
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    label,
                    const SizedBox(height: 10),
                    FittedBox(fit: BoxFit.scaleDown, child: switcher),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: label),
                  const SizedBox(width: 8),
                  switcher,
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _money(summary.totalBalance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
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
                  label: appT(context, 'income'),
                  value: _money(summary.income),
                  iconColor: AppTheme.successColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.north_east,
                  label: appT(context, 'expense'),
                  value: _money(summary.expense),
                  iconColor: AppTheme.errorColor,
                ),
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
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
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
                  appT(context, range.labelKey),
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

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.transactions,
    required this.onSeeAll,
    required this.onTransactionTap,
  });

  final List<_Transaction> transactions;
  final VoidCallback onSeeAll;
  final ValueChanged<_Transaction> onTransactionTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                appT(context, 'recent_activity'),
                overflow: TextOverflow.ellipsis,
                style: _sectionTitle(context),
              ),
            ),
            TextButton.icon(
              onPressed: onSeeAll,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right, size: 18),
              label: Text(appT(context, 'see_all')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...transactions.map(
          (transaction) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TransactionTile(
              transaction: transaction,
              onTap: () => onTransactionTap(transaction),
            ),
          ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, this.onTap});

  final _Transaction transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.flowType == _CashFlowType.income;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: transaction.color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    transaction.icon,
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
                      _transactionDateLabel(context, transaction.belongsDate),
                      style: const TextStyle(
                        color: _AppShellColors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 112),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${isIncome ? '+' : '-'}${_money(transaction.amount.abs())}',
                    style: TextStyle(
                      color: isIncome
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                      fontWeight: FontWeight.w800,
                    ),
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

class _SpendingByCategoryCard extends StatelessWidget {
  const _SpendingByCategoryCard({
    required this.categories,
    required this.onMoreStats,
  });

  final List<_CategoryBreakdownItem> categories;
  final VoidCallback onMoreStats;

  @override
  Widget build(BuildContext context) {
    final visibleCategories = categories.take(5).toList(growable: false);
    final themeColor = _themeColor(context);

    return _Card(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appT(context, 'spending_by_category'),
            style: _sectionTitle(context),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 200,
            width: double.infinity,
            child: CustomPaint(
              painter: _CategoryDonutPainter(visibleCategories),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 10),
          ...visibleCategories.map(
            (category) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: category.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      category.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AppShellColors.text,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    _money(category.amount, decimals: 0),
                    style: const TextStyle(
                      color: _AppShellColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onMoreStats,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right, size: 18),
              label: Text(appT(context, 'more_statistics')),
              style: FilledButton.styleFrom(
                backgroundColor: themeColor.withValues(alpha: 0.1),
                foregroundColor: themeColor,
                elevation: 0,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDonutPainter extends CustomPainter {
  const _CategoryDonutPainter(this.categories);

  final List<_CategoryBreakdownItem> categories;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 18;
    final strokeWidth = math.min(20.0, radius * 0.28);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = categories.fold<double>(
      0,
      (sum, category) => sum + category.amount.abs(),
    );

    final backgroundPaint = Paint()
      ..color = _AppShellColors.softGray
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, backgroundPaint);

    if (total == 0) return;

    var startAngle = -math.pi / 2;
    for (final category in categories) {
      final sweepAngle = (category.amount.abs() / total) * math.pi * 2;
      final paint = Paint()
        ..color = category.color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;

      canvas.drawArc(rect, startAngle, sweepAngle - 0.08, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _CategoryDonutPainter oldDelegate) {
    return oldDelegate.categories != categories;
  }
}
