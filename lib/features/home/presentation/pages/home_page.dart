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
import '../../../../shared/widgets/app_color_picker.dart';
import '../../../../shared/widgets/app_surface.dart';
import '../../../../theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../budget/presentation/budget_tab.dart';
import '../../../demo/data/demo_data_store.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../settings/data/user_configuration_sync.dart';
import '../../../statistics/presentation/statistics_page.dart';
import '../providers/currency_provider.dart';
import '../utils/transaction_filter_utils.dart';

part 'home/dashboard_tab.part.dart';
part 'home/category_tab.part.dart';
part 'home/transactions.part.dart';
part 'home/settings_tab.part.dart';
part 'home/shared_widgets.part.dart';
part 'home/home_models.part.dart';

const _defaultAvatarAsset =
    'assets/images/avatars/f9b59ca5421b2b7ef2e31c2ba4d827f48d22594a.png';

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
    return await _DashboardApi.demo(
      ref.watch(demoDataStoreProvider),
    ).fetchDashboard();
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
  const HomePage({this.section = HomeSection.dashboard, super.key});

  final HomeSection section;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  var _selectedTab = _HomeTab.home;
  var _showTransactions = false;
  var _showMoreStats = false;
  String? _selectedTransactionId;

  @override
  void initState() {
    super.initState();
    _applySection(widget.section);
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      setState(() => _applySection(widget.section));
    }
  }

  void _applySection(HomeSection section) {
    _selectedTab = switch (section) {
      HomeSection.categories => _HomeTab.stats,
      HomeSection.budget => _HomeTab.budget,
      HomeSection.settings => _HomeTab.settings,
      _ => _HomeTab.home,
    };
    _showTransactions = section == HomeSection.transactions;
    _showMoreStats = section == HomeSection.statistics;
    _selectedTransactionId = null;
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
            : _showTransactions
            ? _TransactionsScreen(
                onBack: _closeTransactions,
                onTransactionTap: _openTransactionDetail,
              )
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
                  ),
                  const _CategoryTab(),
                  const SizedBox.shrink(),
                  _selectedTab == _HomeTab.budget
                      ? const BudgetTab()
                      : const SizedBox.shrink(),
                  _SettingsTab(
                    username: username,
                    email: isDemo ? 'demo@cashlenx.com' : user?.username ?? '',
                    avatarUrl: avatarUrl,
                    onProfileTap: _openProfile,
                  ),
                ],
              ),
      ),
      bottomNavigationBar:
          _showTransactions || _showMoreStats || _selectedTransactionId != null
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
                  _HomeTab.stats => HomeSection.categories,
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
    await context.push('/profile');
    ref.invalidate(_userProfileProvider);
  }

  void _openTransactions() {
    _navigate(HomeSection.transactions);
  }

  void _closeTransactions() {
    _navigate(HomeSection.dashboard);
    ref.invalidate(_dashboardProvider);
  }

  void _openMoreStats() {
    _navigate(HomeSection.statistics);
  }

  void _closeMoreStats() {
    _navigate(HomeSection.dashboard);
  }

  void _openTransactionDetail(_Transaction transaction) {
    setState(() => _selectedTransactionId = transaction.id);
  }

  void _closeTransactionDetail() {
    setState(() => _selectedTransactionId = null);
  }

  void _handleTransactionUpdated() {
    ref.invalidate(_dashboardProvider);
  }

  void _handleTransactionDeleted() {
    setState(() {
      _selectedTransactionId = null;
      _showTransactions = false;
    });
    ref.invalidate(_dashboardProvider);
  }

  void _showAddTransactionSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddTransactionSheet(),
    ).whenComplete(() {
      ref.invalidate(_dashboardProvider);
    });
  }
}
