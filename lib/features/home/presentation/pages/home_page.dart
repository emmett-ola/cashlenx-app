import 'dart:async';
import 'dart:math' as math;

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../core/network/response_wrapper.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../network/cashlenx_api.dart';
import '../../../../shared/avatar_presets.dart';
import '../../../../shared/formatters/money_formatter.dart';
import '../../../../shared/widgets/app_color_picker.dart';
import '../../../../shared/widgets/app_surface.dart';
import '../../../../theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../budget/presentation/budget_tab.dart';
import '../../../demo/data/demo_data_store.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../settings/data/user_configuration_sync.dart';
import '../../../statistics/presentation/analytics_context.dart';
import '../../../statistics/presentation/statistics_page.dart';
import '../providers/app_release_identity_provider.dart';
import '../providers/currency_provider.dart';
import '../utils/transaction_filter_utils.dart';

part 'home/dashboard_tab.part.dart';
part 'home/category_tab.part.dart';
part 'home/transactions.part.dart';
part 'home/settings_tab.part.dart';
part 'home/shared_widgets.part.dart';
part 'home/home_models.part.dart';

final _userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = await ref.watch(authNotifierProvider.future);
  if (user == null) return null;
  if (user.role == 'demo') {
    return UserProfile.fromResponse(
      await ref.watch(demoDataStoreProvider).getProfile(),
      fallback: UserProfile.demo(user),
    );
  }

  return UserProfile.fromResponse(
    await ref.watch(cashlenxApiProvider).getUserProfile(),
    fallback: UserProfile.fromUser(user),
  );
});

final _packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

final _dashboardProvider = FutureProvider<_DashboardResponse>((ref) async {
  final user = await ref.watch(authNotifierProvider.future);
  if (user?.role == 'demo') {
    ref.watch(demoDataRevisionProvider);
    return await _DashboardApi.demo(ref.watch(demoDataStoreProvider))
        .fetchDashboard();
  }

  return await _DashboardApi(ref.watch(cashlenxApiProvider)).fetchDashboard();
});

enum HomeSection {
  dashboard('/home'),
  categories('/categories'),
  budget('/budgets'),
  settings('/settings'),
  transactions('/transactions'),
  statistics('/statistics');

  const HomeSection(this.path);

  final String path;
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({
    this.section = HomeSection.dashboard,
    this.transactionId,
    super.key,
  });

  final HomeSection section;
  final String? transactionId;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  var _selectedTab = _HomeTab.home;
  var _showCategories = false;
  var _showMoreStats = false;
  String? _selectedTransactionId;

  @override
  void initState() {
    super.initState();
    _applySection(widget.section, transactionId: widget.transactionId);
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section ||
        oldWidget.transactionId != widget.transactionId) {
      setState(
        () =>
            _applySection(widget.section, transactionId: widget.transactionId),
      );
    }
  }

  void _applySection(HomeSection section, {String? transactionId}) {
    _selectedTab = switch (section) {
      HomeSection.transactions => _HomeTab.transactions,
      HomeSection.categories => _HomeTab.settings,
      HomeSection.budget => _HomeTab.budget,
      HomeSection.settings => _HomeTab.settings,
      _ => _HomeTab.home,
    };
    _showCategories = section == HomeSection.categories;
    _showMoreStats = section == HomeSection.statistics;
    _selectedTransactionId = transactionId;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(i18nProvider);
    ref.watch(userConfigurationSyncProvider);
    final user = ref.watch(authNotifierProvider).value;
    final profile = ref
        .watch(_userProfileProvider)
        .whenOrNull(data: (profile) => profile);
    final username = profile?.displayName ?? user?.username ?? 'User';
    final avatarUrl = profile?.avatarUrl;
    final isDemo = user?.role == 'demo';
    final analyticsRange = ref.watch(analyticsRangeProvider);

    return Scaffold(
      backgroundColor: _AppShellColors.background,
      body: SafeArea(
        bottom: false,
        child: _selectedTransactionId != null
            ? _TransactionDetailScreen(
                transactionId: _selectedTransactionId!,
                onBack: _closeTransactionDetail,
                onDeleted: _handleTransactionDeleted,
                onUpdated: _handleTransactionUpdated,
              )
            : _showCategories
            ? _CategoryTab(onBack: _closeCategories)
            : _showMoreStats
            ? StatisticsPage(onBack: _closeMoreStats)
            : IndexedStack(
                index: _selectedTab.index,
                children: [
                  _DashboardTab(
                    username: username,
                    avatarUrl: avatarUrl,
                    onTransactionTap: _openTransactionDetail,
                    onProfileTap: _openProfile,
                    onSeeAllTransactions: _openTransactions,
                    onMoreStats: _openMoreStats,
                    selectedRange: analyticsRange,
                    onRangeChanged: ref
                        .read(analyticsRangeProvider.notifier)
                        .setRange,
                  ),
                  _selectedTab == _HomeTab.transactions
                      ? _TransactionsScreen(
                          onTransactionTap: _openTransactionDetail,
                        )
                      : const SizedBox.shrink(),
                  const SizedBox.shrink(),
                  _selectedTab == _HomeTab.budget
                      ? const BudgetTab()
                      : const SizedBox.shrink(),
                  _SettingsTab(
                    username: username,
                    email: isDemo ? 'demo@cashlenx.com' : user?.username ?? '',
                    avatarUrl: avatarUrl,
                    onProfileTap: _openProfile,
                    onCategoryManagement: _openCategories,
                  ),
                ],
              ),
      ),
      bottomNavigationBar:
          _showCategories || _showMoreStats || _selectedTransactionId != null
          ? null
          : _BottomNav(
              selectedTab: _selectedTab,
              onSelect: (tab) {
                if (tab == _HomeTab.add) {
                  _showAddTransactionSheet();
                  return;
                }
                final section = switch (tab) {
                  _HomeTab.home => HomeSection.dashboard,
                  _HomeTab.transactions => HomeSection.transactions,
                  _HomeTab.budget => HomeSection.budget,
                  _HomeTab.settings => HomeSection.settings,
                  _HomeTab.add => HomeSection.dashboard,
                };
                _navigate(section);
                if (tab == _HomeTab.home || tab == _HomeTab.budget) {
                  ref.invalidate(_dashboardProvider);
                }
              },
            ),
    );
  }

  void _navigate(HomeSection section) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(section.path);
      return;
    }
    setState(() => _applySection(section));
  }

  Future<void> _openProfile() async {
    final origin = _selectedTab == _HomeTab.settings ? 'settings' : 'home';
    await context.push('/profile?from=$origin');
    ref.invalidate(_userProfileProvider);
  }

  void _openTransactions() {
    _navigate(HomeSection.transactions);
  }

  void _openCategories() {
    _navigate(HomeSection.categories);
  }

  void _closeCategories() {
    _navigate(HomeSection.settings);
  }

  void _openMoreStats() {
    final range = ref.read(analyticsRangeProvider);
    if (range == AnalyticsRange.total) {
      ref.read(analyticsRangeProvider.notifier).setRange(AnalyticsRange.year);
    }
    _navigate(HomeSection.statistics);
  }

  void _closeMoreStats() {
    _navigate(HomeSection.dashboard);
  }

  void _openTransactionDetail(_Transaction transaction) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      final origin = _selectedTab == _HomeTab.transactions
          ? 'transactions'
          : 'home';
      context.push(
        '/transactions/${Uri.encodeComponent(transaction.id)}?from=$origin',
      );
      return;
    }
    setState(() => _selectedTransactionId = transaction.id);
  }

  void _closeTransactionDetail() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(widget.section.path);
      }
      return;
    }
    setState(() => _selectedTransactionId = null);
  }

  void _handleTransactionUpdated() {
    ref.invalidate(_dashboardProvider);
  }

  void _handleTransactionDeleted() {
    _closeTransactionDetail();
    ref.invalidate(_dashboardProvider);
  }

  void _showAddTransactionSheet() {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddTransactionSheet(),
    ).then((created) {
      if (created == true) ref.invalidate(_dashboardProvider);
    });
  }
}
