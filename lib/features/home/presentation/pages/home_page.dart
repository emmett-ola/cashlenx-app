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

final _dashboardProvider = FutureProvider<_DashboardResponse>((ref) {
  final user = ref.watch(authNotifierProvider).value;
  if (user?.role == 'demo') {
    ref.watch(demoDataRevisionProvider);
    return _DashboardApi.demo(
      ref.watch(demoDataStoreProvider),
    ).fetchDashboard();
  }

  return _DashboardApi(ref.watch(cashlenxApiProvider)).fetchDashboard();
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

class _CategoryTab extends ConsumerStatefulWidget {
  const _CategoryTab();

  @override
  ConsumerState<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends ConsumerState<_CategoryTab> {
  var _activeType = _CategoryType.expense;
  final _expandedCategoryIds = <String>{};
  String? _openMenuId;
  var _isLoading = true;
  Object? _error;
  List<_CategoryItem> _categories = const [];

  bool get _isDemo => ref.read(authNotifierProvider).value?.role == 'demo';

  List<_CategoryItem> get _visibleParents => _categories
      .where(
        (category) => category.type == _activeType && category.parentId == null,
      )
      .toList(growable: false);

  List<_CategoryItem> _childrenOf(String parentId) {
    return _categories
        .where(
          (category) =>
              category.type == _activeType && category.parentId == parentId,
        )
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: appT(context, 'categories'),
      subtitle: appT(context, 'categories_subtitle'),
      children: [
        _CategoryTypeSwitcher(
          activeType: _activeType,
          onChanged: (type) {
            setState(() {
              _activeType = type;
              _openMenuId = null;
            });
            _loadCategories();
          },
        ),
        if (_isLoading)
          const _CategoryLoadingCard()
        else if (_error != null)
          _CategoryErrorCard(onRetry: _loadCategories)
        else
          _CategoryListCard(
            parentCategories: _visibleParents,
            expandedCategoryIds: _expandedCategoryIds,
            openMenuId: _openMenuId,
            childrenOf: _childrenOf,
            onToggleExpanded: _toggleExpanded,
            onToggleMenu: _toggleMenu,
            onAction: _handleCategoryAction,
          ),
        _CreateCategoryButton(
          onPressed: () =>
              _showCategoryEditor(mode: _CategoryEditorMode.create),
        ),
      ],
    );
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _openMenuId = null;
    });

    try {
      final response = await _listAllCategories();
      final categories = _CategoryItem.listFromResponse(response);

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _expandedCategoryIds.addAll(
          categories
              .where((category) => category.parentId == null)
              .take(2)
              .map((category) => category.id),
        );
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
      ToastUtils.showServerErrors(context, error);
    }
  }

  void _toggleExpanded(String id) {
    setState(() {
      if (_expandedCategoryIds.contains(id)) {
        _expandedCategoryIds.remove(id);
      } else {
        _expandedCategoryIds.add(id);
      }
      _openMenuId = null;
    });
  }

  void _toggleMenu(String id) {
    setState(() {
      _openMenuId = _openMenuId == id ? null : id;
    });
  }

  void _handleCategoryAction(
    _CategoryRowAction action,
    _CategoryItem category,
  ) {
    setState(() => _openMenuId = null);

    switch (action) {
      case _CategoryRowAction.edit:
        _showCategoryEditor(mode: _CategoryEditorMode.edit, category: category);
      case _CategoryRowAction.move:
        _showMoveCategorySheet(category);
      case _CategoryRowAction.delete:
        _showDeleteCategoryDialog(category);
    }
  }

  void _showCategoryEditor({
    required _CategoryEditorMode mode,
    _CategoryItem? category,
  }) {
    final nameController = TextEditingController(text: category?.name ?? '');
    var selectedIcon = category?.icon ?? _defaultCategoryEmoji;
    var selectedColor = category?.color ?? _themeColor(context);
    var selectedParentId = category?.parentId;
    var showEmojiPicker = false;
    var showNameError = false;
    var validationShakeTrigger = 0;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.9,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: AppPanelHeader(
                        title: mode == _CategoryEditorMode.edit
                            ? appT(context, 'edit_category')
                            : appT(context, 'create_category'),
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: selectedColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: selectedColor.withValues(
                                        alpha: 0.28,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    selectedIcon,
                                    style: const TextStyle(fontSize: 34),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              appT(context, 'name'),
                              style: _fieldLabelStyle,
                            ),
                            const SizedBox(height: 8),
                            _ValidationField(
                              errorText: showNameError
                                  ? appT(context, 'enter_category_name')
                                  : null,
                              shakeTrigger: validationShakeTrigger,
                              child: TextField(
                                controller: nameController,
                                maxLength: 64,
                                onChanged: (_) {
                                  setSheetState(() => showNameError = false);
                                },
                                decoration: InputDecoration(
                                  hintText: appT(
                                    context,
                                    'enter_category_name',
                                  ),
                                  hintStyle: const TextStyle(
                                    color: _AppShellColors.navMuted,
                                    fontSize: 14,
                                  ),
                                  counterStyle: const TextStyle(
                                    color: _AppShellColors.navMuted,
                                    fontSize: 12,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFD1D5DB),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFD1D5DB),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: _themeColor(context),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              appT(context, 'icon'),
                              style: _fieldLabelStyle,
                            ),
                            const SizedBox(height: 8),
                            _EmojiPickerButton(
                              emoji: selectedIcon,
                              onTap: () {
                                setSheetState(
                                  () => showEmojiPicker = !showEmojiPicker,
                                );
                              },
                            ),
                            if (showEmojiPicker) ...[
                              const SizedBox(height: 8),
                              _CategoryEmojiPicker(
                                onEmojiSelected: (emoji) {
                                  setSheetState(() {
                                    selectedIcon = emoji;
                                    showEmojiPicker = false;
                                  });
                                },
                              ),
                            ],
                            const SizedBox(height: 24),
                            Text(
                              appT(context, 'color'),
                              style: _fieldLabelStyle,
                            ),
                            const SizedBox(height: 12),
                            _CategoryColorPicker(
                              selectedColor: selectedColor,
                              onColorSelected: (color) {
                                setSheetState(() => selectedColor = color);
                              },
                            ),
                            const SizedBox(height: 24),
                            Text(
                              appT(context, 'parent_category_optional'),
                              style: _fieldLabelStyle,
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String?>(
                              initialValue: selectedParentId,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFFF3F4F6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    appT(context, 'none_main_category'),
                                  ),
                                ),
                                ..._visibleParents
                                    .where(
                                      (parent) => parent.id != category?.id,
                                    )
                                    .map(
                                      (parent) => DropdownMenuItem<String?>(
                                        value: parent.id,
                                        child: Text(
                                          '${parent.icon} ${parent.name}',
                                        ),
                                      ),
                                    ),
                              ],
                              onChanged: (value) {
                                setSheetState(() => selectedParentId = value);
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              appT(context, 'select_parent_hint'),
                              style: const TextStyle(
                                color: _AppShellColors.navMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: _AppShellColors.border),
                          ),
                        ),
                        child: AppPanelActions(
                          primaryLabel: mode == _CategoryEditorMode.edit
                              ? appT(context, 'save_changes')
                              : appT(context, 'create'),
                          onPrimaryPressed: () {
                            final name = nameController.text.trim();
                            if (name.isEmpty) {
                              setSheetState(() {
                                showNameError = true;
                                validationShakeTrigger++;
                              });
                              return;
                            }

                            final request = _CategoryEditorRequest(
                              name: name,
                              type: _activeType,
                              parentId: selectedParentId,
                              emoji: selectedIcon,
                              bgColor: selectedColor,
                            );
                            Navigator.pop(context);
                            _saveCategory(
                              mode: mode,
                              category: category,
                              request: request,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(nameController.dispose);
  }

  Future<void> _saveCategory({
    required _CategoryEditorMode mode,
    required _CategoryEditorRequest request,
    _CategoryItem? category,
  }) async {
    try {
      if (mode == _CategoryEditorMode.edit && category != null) {
        await _updateCategoryById(
          category.id,
          name: request.name,
          type: request.type.apiValue,
          parentId: request.parentId,
          emoji: request.resolvedEmoji,
          bgColor: request.resolvedBgColorHex,
          remark: category.remark,
        );
        if (mounted) {
          ToastUtils.showSuccess(context, appT(context, 'category_updated'));
        }
      } else {
        await _createCategory(
          name: request.name,
          type: request.type.apiValue,
          parentId: request.parentId,
          emoji: request.resolvedEmoji,
          bgColor: request.resolvedBgColorHex,
        );
        if (mounted) {
          ToastUtils.showSuccess(context, appT(context, 'category_created'));
        }
      }
      await _loadCategories();
    } catch (error) {
      if (!mounted) return;
      ToastUtils.showServerErrors(context, error);
    }
  }

  void _showMoveCategorySheet(_CategoryItem category) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final parents = _visibleParents
            .where((parent) => parent.id != category.id)
            .toList(growable: false);

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        appT(context, 'move_category'),
                        style: _sectionTitle(context),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  appT(context, 'moving'),
                  style: const TextStyle(color: _AppShellColors.mutedText),
                ),
                const SizedBox(height: 8),
                _MoveCategoryOption(
                  icon: category.icon,
                  color: category.color,
                  title: category.name,
                  subtitle: appT(context, 'current_category'),
                  selected: false,
                  onTap: null,
                ),
                const SizedBox(height: 18),
                Text(appT(context, 'move_to'), style: _fieldLabelStyle),
                const SizedBox(height: 8),
                _MoveCategoryOption(
                  icon: '*',
                  color: _themeColor(context),
                  title: appT(context, 'main_category'),
                  subtitle: appT(context, 'main_category_hint'),
                  selected: category.parentId == null,
                  onTap: () {
                    Navigator.pop(context);
                    _moveCategory(category, null);
                  },
                ),
                ...parents.map(
                  (parent) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _MoveCategoryOption(
                      icon: parent.icon,
                      color: parent.color,
                      title: parent.name,
                      subtitle:
                          '${_childrenOf(parent.id).length} ${appT(context, 'subcategories')}',
                      selected: category.parentId == parent.id,
                      onTap: () {
                        Navigator.pop(context);
                        _moveCategory(category, parent.id);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(
                        color: _AppShellColors.border,
                        width: 2,
                      ),
                    ),
                    child: Text(appT(context, 'cancel')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _moveCategory(_CategoryItem category, String? parentId) async {
    try {
      await _updateCategoryById(
        category.id,
        name: category.name,
        type: category.type.apiValue,
        parentId: parentId,
        emoji: category.icon,
        bgColor: _hexColor(category.color),
        remark: category.remark,
      );
      if (mounted) {
        ToastUtils.showSuccess(context, appT(context, 'category_moved'));
      }
      await _loadCategories();
    } catch (error) {
      if (!mounted) return;
      ToastUtils.showServerErrors(context, error);
    }
  }

  void _showDeleteCategoryDialog(_CategoryItem category) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final childCount = _childrenOf(category.id).length;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.errorColor,
              size: 30,
            ),
          ),
          title: Text(
            appT(context, 'delete_category_title'),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'This will delete "${category.name}"'
            '${childCount > 0 ? ' and all $childCount ${appT(context, 'subcategories')}' : ''}, '
            '${appT(context, 'delete_category_warning')}',
            textAlign: TextAlign.center,
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(appT(context, 'cancel')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteCategory(category);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: Text(appT(context, 'delete')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCategory(_CategoryItem category) async {
    try {
      await _deleteCategoryById(category.id);
      if (mounted) {
        ToastUtils.showSuccess(context, appT(context, 'category_deleted'));
      }
      await _loadCategories();
    } catch (error) {
      if (!mounted) return;
      ToastUtils.showServerErrors(context, error);
    }
  }

  Future<ApiJson> _listAllCategories() {
    if (_isDemo) {
      return ref.read(demoDataStoreProvider).listAllCategories();
    }

    return ref.read(cashlenxApiProvider).listAllCategories();
  }

  Future<void> _createCategory({
    required String name,
    required String type,
    String? parentId,
    String? emoji,
    String? bgColor,
  }) async {
    if (_isDemo) {
      await ref
          .read(demoDataStoreProvider)
          .createCategory(
            name: name,
            type: type,
            parentId: parentId,
            emoji: emoji,
            bgColor: bgColor,
          );
      ref.read(demoDataRevisionProvider.notifier).bump();
      return;
    }

    await ref
        .read(cashlenxApiProvider)
        .createCategory(
          name: name,
          type: type,
          parentId: parentId,
          emoji: emoji,
          bgColor: bgColor,
        );
  }

  Future<void> _updateCategoryById(
    String id, {
    required String name,
    required String type,
    String? parentId,
    String? emoji,
    String? bgColor,
    String? remark,
  }) async {
    if (_isDemo) {
      await ref
          .read(demoDataStoreProvider)
          .updateCategoryById(
            id,
            name: name,
            type: type,
            parentId: parentId,
            emoji: emoji,
            bgColor: bgColor,
            remark: remark,
          );
      ref.read(demoDataRevisionProvider.notifier).bump();
      return;
    }

    await ref
        .read(cashlenxApiProvider)
        .updateCategoryById(
          id,
          name: name,
          type: type,
          parentId: parentId,
          emoji: emoji,
          bgColor: bgColor,
          remark: remark,
        );
  }

  Future<void> _deleteCategoryById(String id) async {
    if (_isDemo) {
      await ref.read(demoDataStoreProvider).deleteCategoryById(id);
      ref.read(demoDataRevisionProvider.notifier).bump();
      return;
    }

    await ref.read(cashlenxApiProvider).deleteCategoryById(id);
  }
}

class _CategoryTypeSwitcher extends StatelessWidget {
  const _CategoryTypeSwitcher({
    required this.activeType,
    required this.onChanged,
  });

  final _CategoryType activeType;
  final ValueChanged<_CategoryType> onChanged;

  @override
  Widget build(BuildContext context) {
    final themeColor = _themeColor(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: _CategoryType.values.map((type) {
          final isSelected = activeType == type;

          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [themeColor, AppTheme.secondaryColor],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: themeColor.withValues(alpha: 0.22),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  appT(context, type.labelKey),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : _AppShellColors.mutedText,
                    fontSize: 14,
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

class _CategoryListCard extends StatelessWidget {
  const _CategoryListCard({
    required this.parentCategories,
    required this.expandedCategoryIds,
    required this.openMenuId,
    required this.childrenOf,
    required this.onToggleExpanded,
    required this.onToggleMenu,
    required this.onAction,
  });

  final List<_CategoryItem> parentCategories;
  final Set<String> expandedCategoryIds;
  final String? openMenuId;
  final List<_CategoryItem> Function(String parentId) childrenOf;
  final ValueChanged<String> onToggleExpanded;
  final ValueChanged<String> onToggleMenu;
  final void Function(_CategoryRowAction action, _CategoryItem category)
  onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: parentCategories.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  appT(context, 'no_categories'),
                  style: const TextStyle(color: _AppShellColors.mutedText),
                ),
              ),
            )
          : Column(
              children: parentCategories.indexed.map((entry) {
                final index = entry.$1;
                final category = entry.$2;
                final children = childrenOf(category.id);
                final isExpanded = expandedCategoryIds.contains(category.id);

                return Column(
                  children: [
                    _CategoryRow(
                      category: category,
                      childrenCount: children.length,
                      isExpanded: isExpanded,
                      isChild: false,
                      isMenuOpen: openMenuId == category.id,
                      onToggleExpanded: onToggleExpanded,
                      onToggleMenu: onToggleMenu,
                      onAction: onAction,
                    ),
                    if (children.isNotEmpty && isExpanded)
                      Container(
                        color: const Color(0xFFF9FAFB),
                        child: Column(
                          children: children.map((child) {
                            return _CategoryRow(
                              category: child,
                              childrenCount: 0,
                              isExpanded: false,
                              isChild: true,
                              isMenuOpen: openMenuId == child.id,
                              onToggleExpanded: onToggleExpanded,
                              onToggleMenu: onToggleMenu,
                              onAction: onAction,
                            );
                          }).toList(),
                        ),
                      ),
                    if (index != parentCategories.length - 1)
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  ],
                );
              }).toList(),
            ),
    );
  }
}

class _CategoryLoadingCard extends StatelessWidget {
  const _CategoryLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _CategoryErrorCard extends StatelessWidget {
  const _CategoryErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _EmptyStateCard(
      icon: Icons.error_outline,
      title: appT(context, 'categories_failed'),
      message: appT(context, 'category_request_failed'),
      actionLabel: appT(context, 'retry'),
      onAction: onRetry,
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.childrenCount,
    required this.isExpanded,
    required this.isChild,
    required this.isMenuOpen,
    required this.onToggleExpanded,
    required this.onToggleMenu,
    required this.onAction,
  });

  final _CategoryItem category;
  final int childrenCount;
  final bool isExpanded;
  final bool isChild;
  final bool isMenuOpen;
  final ValueChanged<String> onToggleExpanded;
  final ValueChanged<String> onToggleMenu;
  final void Function(_CategoryRowAction action, _CategoryItem category)
  onAction;

  @override
  Widget build(BuildContext context) {
    final hasChildren = childrenCount > 0 && !isChild;

    return InkWell(
      onTap: hasChildren ? () => onToggleExpanded(category.id) : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(isChild ? 52 : 16, 14, 12, 14),
        child: Row(
          children: [
            if (hasChildren)
              Icon(
                isExpanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
                color: Colors.grey[400],
              )
            else if (!isChild)
              const SizedBox(width: 24)
            else
              const SizedBox(width: 0),
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: category.color,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  category.icon,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _AppShellColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: isMenuOpen
                  ? Row(
                      key: const ValueKey('actions'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CategoryActionButton(
                          icon: Icons.edit_outlined,
                          color: _themeColor(context),
                          onTap: () =>
                              onAction(_CategoryRowAction.edit, category),
                        ),
                        _CategoryActionButton(
                          icon: Icons.open_with,
                          color: AppTheme.secondaryColor,
                          onTap: () =>
                              onAction(_CategoryRowAction.move, category),
                        ),
                        _CategoryActionButton(
                          icon: Icons.delete_outline,
                          color: AppTheme.errorColor,
                          onTap: () =>
                              onAction(_CategoryRowAction.delete, category),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
            IconButton(
              onPressed: () => onToggleMenu(category.id),
              icon: const Icon(Icons.more_vert),
              color: Colors.grey[500],
              style: IconButton.styleFrom(
                backgroundColor: isMenuOpen
                    ? const Color(0xFFE5E7EB)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryActionButton extends StatelessWidget {
  const _CategoryActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        color: color,
        style: IconButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.1),
          fixedSize: const Size(36, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _CreateCategoryButton extends StatelessWidget {
  const _CreateCategoryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final themeColor = _themeColor(context);

    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: Text(appT(context, 'create_new_category')),
      style: FilledButton.styleFrom(
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        elevation: 8,
        shadowColor: themeColor.withValues(alpha: 0.28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _EmojiPickerButton extends StatelessWidget {
  const _EmojiPickerButton({required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD1D5DB)),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  appT(context, 'tap_change_emoji'),
                  style: const TextStyle(color: _AppShellColors.mutedText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryEmojiPicker extends StatelessWidget {
  const _CategoryEmojiPicker({required this.onEmojiSelected});

  final ValueChanged<String> onEmojiSelected;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: _AppShellColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: EmojiPicker(
          onEmojiSelected: (_, emoji) => onEmojiSelected(emoji.emoji),
          config: Config(
            height: 400,
            emojiViewConfig: const EmojiViewConfig(
              columns: 8,
              emojiSizeMax: 28,
              backgroundColor: Colors.white,
              gridPadding: EdgeInsets.all(8),
            ),
            searchViewConfig: SearchViewConfig(
              hintText: appT(context, 'search_emoji'),
              backgroundColor: const Color(0xFFF3F4F6),
            ),
            categoryViewConfig: CategoryViewConfig(
              backgroundColor: Colors.white,
              indicatorColor: _themeColor(context),
              iconColorSelected: _themeColor(context),
            ),
            bottomActionBarConfig: BottomActionBarConfig(
              backgroundColor: Colors.white,
              buttonColor: _themeColor(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryColorPicker extends StatelessWidget {
  const _CategoryColorPicker({
    required this.selectedColor,
    required this.onColorSelected,
  });

  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  @override
  Widget build(BuildContext context) {
    return AppColorPicker(
      colors: _categoryColorChoices,
      selectedColor: selectedColor,
      onColorSelected: onColorSelected,
    );
  }
}

class _MoveCategoryOption extends StatelessWidget {
  const _MoveCategoryOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final themeColor = _themeColor(context);

    return Material(
      color: selected ? themeColor.withValues(alpha: 0.08) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? themeColor : _AppShellColors.border,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AppShellColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AppShellColors.mutedText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionsScreen extends ConsumerStatefulWidget {
  const _TransactionsScreen({
    required this.onBack,
    required this.onTransactionTap,
  });

  final VoidCallback onBack;
  final ValueChanged<_Transaction> onTransactionTap;

  @override
  ConsumerState<_TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<_TransactionsScreen> {
  var _selectedType = _TransactionFilterType.all;
  String? _selectedCategoryId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final _searchController = TextEditingController();
  var _showFilters = false;
  var _isLoading = true;
  Object? _error;
  List<_Transaction> _transactions = const [];
  List<_CategoryItem> _categories = const [];

  bool get _isDemo => ref.read(authNotifierProvider).value?.role == 'demo';

  List<_Transaction> get _filteredTransactions {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _transactions
        .where((transaction) {
          if (_selectedType != _TransactionFilterType.all &&
              transaction.flowType != _selectedType.flowType) {
            return false;
          }
          if (_selectedCategoryId != null &&
              transaction.categoryId != _selectedCategoryId) {
            return false;
          }
          if (!isWithinInclusiveDateRange(
            transaction.dateSort,
            from: _dateFrom,
            to: _dateTo,
          )) {
            return false;
          }
          if (query.isNotEmpty &&
              !transaction.title.toLowerCase().contains(query) &&
              !transaction.category.toLowerCase().contains(query)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    return filtered..sort(_compareTransactionsNewestFirst);
  }

  List<_CategoryItem> get _categoryOptions {
    return _categories
        .where(
          (category) =>
              _selectedType == _TransactionFilterType.all ||
              category.type == _selectedType.categoryType,
        )
        .toList(growable: false);
  }

  int get _activeFilterCount {
    var count = 0;
    if (_selectedType != _TransactionFilterType.all) count++;
    if (_selectedCategoryId != null) count++;
    if (_dateFrom != null || _dateTo != null) count++;
    if (_searchController.text.trim().isNotEmpty) count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = _filteredTransactions;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _NavigationHeader(
            title: appT(context, 'transactions'),
            onBack: widget.onBack,
            trailing: Stack(
              clipBehavior: Clip.none,
              children: [
                _RoundIconButton(
                  icon: Icons.filter_list,
                  onPressed: () {
                    setState(() => _showFilters = !_showFilters);
                  },
                ),
                if (_activeFilterCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: _FilterBadge(count: _activeFilterCount),
                  ),
              ],
            ),
          ),
        ),
        if (_showFilters)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _TransactionFiltersCard(
                selectedType: _selectedType,
                selectedCategoryId: _selectedCategoryId,
                dateFrom: _dateFrom,
                dateTo: _dateTo,
                categories: _categoryOptions,
                searchController: _searchController,
                onTypeChanged: (type) {
                  setState(() {
                    _selectedType = type;
                    _selectedCategoryId = null;
                  });
                },
                onCategoryChanged: (categoryId) {
                  setState(() => _selectedCategoryId = categoryId);
                },
                onDateFromPressed: () => _selectFilterDate(isFrom: true),
                onDateToPressed: () => _selectFilterDate(isFrom: false),
                onClear: _clearFilters,
              ),
            ),
          ),
        if (_activeFilterCount > 0 && !_showFilters)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _ActiveTransactionFilters(
                selectedType: _selectedType,
                selectedCategory: _selectedCategory,
                dateFrom: _dateFrom,
                dateTo: _dateTo,
                searchQuery: _searchController.text.trim(),
                onTypeRemoved: () {
                  setState(() => _selectedType = _TransactionFilterType.all);
                },
                onCategoryRemoved: () {
                  setState(() => _selectedCategoryId = null);
                },
                onDateRemoved: () => unawaited(_removeDateFilter()),
                onSearchRemoved: _searchController.clear,
              ),
            ),
          ),
        if (!_isLoading && _error == null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                _transactionResultSummary(
                  context,
                  filteredTransactions.length,
                  filtered: _activeFilterCount > 0,
                ),
                key: const ValueKey('transaction-result-summary'),
                style: const TextStyle(
                  color: _AppShellColors.mutedText,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          sliver: _isLoading
              ? const SliverToBoxAdapter(child: _TransactionLoadingCard())
              : _error != null
              ? SliverToBoxAdapter(
                  child: _TransactionErrorCard(onRetry: _loadData),
                )
              : filteredTransactions.isEmpty
              ? SliverToBoxAdapter(
                  child: _EmptyStateCard(
                    icon: Icons.receipt_long_outlined,
                    title: appT(context, 'no_transactions_found'),
                    message: appT(
                      context,
                      _activeFilterCount > 0
                          ? 'transactions_empty_filtered'
                          : 'transactions_empty_message',
                    ),
                    actionLabel: appT(context, 'clear_filters'),
                    onAction: _activeFilterCount > 0 ? _clearFilters : null,
                  ),
                )
              : SliverList.separated(
                  itemBuilder: (context, index) {
                    final transaction = filteredTransactions[index];
                    final previous = index == 0
                        ? null
                        : filteredTransactions[index - 1];
                    final showHeader =
                        previous == null ||
                        !_isSameDate(previous.dateSort, transaction.dateSort);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader) ...[
                          Padding(
                            padding: EdgeInsets.only(
                              top: index == 0 ? 0 : 12,
                              bottom: 8,
                            ),
                            child: Text(
                              _transactionDateGroupLabel(
                                context,
                                transaction.belongsDate,
                              ),
                              style: const TextStyle(
                                color: _AppShellColors.mutedText,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        _TransactionTile(
                          transaction: transaction,
                          onTap: () => widget.onTransactionTap(transaction),
                        ),
                      ],
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemCount: filteredTransactions.length,
                ),
        ),
      ],
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final responses = _isDemo
          ? await Future.wait([
              ref.read(demoDataStoreProvider).listAllTransactions(),
              ref.read(demoDataStoreProvider).listAllCategories(),
            ])
          : await Future.wait([
              ref.read(cashlenxApiProvider).listAllTransactions(),
              ref.read(cashlenxApiProvider).listAllCategories(),
            ]);
      if (!mounted) return;
      setState(() {
        _transactions = _Transaction.listFromResponse(responses[0])
          ..sort(_compareTransactionsNewestFirst);
        _categories = _CategoryItem.listFromResponse(responses[1]);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
      ToastUtils.showServerErrors(context, error);
    }
  }

  void _clearFilters() {
    final shouldReload = !_isDemo && (_dateFrom != null || _dateTo != null);
    setState(() {
      _selectedType = _TransactionFilterType.all;
      _selectedCategoryId = null;
      _dateFrom = null;
      _dateTo = null;
      _searchController.clear();
    });
    if (shouldReload) unawaited(_reloadTransactionsForDateRange());
  }

  _CategoryItem? get _selectedCategory {
    for (final category in _categories) {
      if (category.id == _selectedCategoryId) return category;
    }
    return null;
  }

  Future<void> _selectFilterDate({required bool isFrom}) async {
    final earliest = DateTime(2000);
    final latest = DateTime(2100, 12, 31);
    final current = isFrom ? _dateFrom : _dateTo;
    final firstDate = isFrom ? earliest : (_dateFrom ?? earliest);
    final lastDate = isFrom ? (_dateTo ?? latest) : latest;
    var initialDate = current ?? calendarDate(DateTime.now());
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (selected == null || !mounted) return;

    setState(() {
      if (isFrom) {
        _dateFrom = calendarDate(selected);
      } else {
        _dateTo = calendarDate(selected);
      }
    });
    await _reloadTransactionsForDateRange();
  }

  Future<void> _removeDateFilter() async {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
    });
    await _reloadTransactionsForDateRange();
  }

  Future<void> _reloadTransactionsForDateRange() async {
    if (_isDemo) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = _dateFrom == null && _dateTo == null
          ? await ref.read(cashlenxApiProvider).listAllTransactions()
          : await ref
                .read(cashlenxApiProvider)
                .getTransactionsByDateRange(
                  from: _dateToken(_dateFrom ?? DateTime(2000)),
                  to: _dateToken(_dateTo ?? DateTime(2100, 12, 31)),
                );
      if (!mounted) return;
      setState(() {
        _transactions = _Transaction.listFromResponse(response)
          ..sort(_compareTransactionsNewestFirst);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
      ToastUtils.showServerErrors(context, error);
    }
  }
}

class _TransactionDetailScreen extends ConsumerStatefulWidget {
  const _TransactionDetailScreen({
    required this.transactionId,
    required this.onBack,
    required this.onDeleted,
    required this.onUpdated,
  });

  final String transactionId;
  final VoidCallback onBack;
  final VoidCallback onDeleted;
  final VoidCallback onUpdated;

  @override
  ConsumerState<_TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<_TransactionDetailScreen> {
  final _descriptionController = TextEditingController();
  final _remarkController = TextEditingController();
  var _amountText = '0';
  var _isLoading = true;
  var _isEditing = false;
  var _isSaving = false;
  var _showDeleteConfirm = false;
  var _showAmountPad = false;
  Object? _error;
  _Transaction? _transaction;
  List<_CategoryItem> _categories = const [];
  var _type = _CategoryType.expense;
  var _date = DateTime.now();
  String? _selectedCategoryId;
  String? _activeCategoryParentId;
  final _selectedCategoryByType = <_CategoryType, String?>{};
  final _activeCategoryParentByType = <_CategoryType, String?>{};
  var _showAmountError = false;
  var _showCategoryError = false;
  var _validationShakeTrigger = 0;

  bool get _isDemo => ref.read(authNotifierProvider).value?.role == 'demo';

  List<_CategoryItem> get _visibleCategories {
    final typeCategories = _categories
        .where((category) => category.type == _type)
        .toList(growable: false);

    if (_activeCategoryParentId == null) {
      return typeCategories
          .where((category) => category.parentId == null)
          .toList(growable: false);
    }

    final parent = _categoryById(_activeCategoryParentId);
    return [
      if (parent != null && parent.type == _type) parent,
      ...typeCategories.where(
        (category) => category.parentId == _activeCategoryParentId,
      ),
    ];
  }

  _CategoryItem? get _selectedCategory {
    return _categoryById(_selectedCategoryId);
  }

  _CategoryItem? _categoryById(String? id) {
    if (id == null) return null;
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  bool _hasChildren(_CategoryItem category) {
    return _categories.any(
      (item) => item.type == _type && item.parentId == category.id,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transaction = _transaction;

    if (_isLoading) {
      return _LoadingPage(title: appT(context, 'transaction_detail'));
    }

    if (_error != null || transaction == null) {
      return _PageScaffold(
        header: _NavigationHeader(
          title: appT(context, 'transaction_detail'),
          onBack: widget.onBack,
        ),
        children: [
          _EmptyStateCard(
            icon: Icons.receipt_long_outlined,
            title: appT(context, 'transaction_detail_failed'),
            message: appT(context, 'transaction_request_failed'),
            actionLabel: appT(context, 'retry'),
            onAction: _loadData,
          ),
        ],
      );
    }

    final isIncome = transaction.flowType == _CashFlowType.income;
    final amountColor = isIncome ? AppTheme.successColor : AppTheme.errorColor;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _themeColor(context),
                  _themeColor(context).withValues(alpha: 0.78),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Row(
                    children: [
                      _HeaderCircleButton(
                        icon: Icons.arrow_back,
                        onTap: widget.onBack,
                      ),
                      Expanded(
                        child: Text(
                          appT(context, 'transaction_detail'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _isEditing
                          ? _HeaderCircleButton(
                              icon: Icons.check,
                              onTap: _isSaving ? null : _saveTransaction,
                            )
                          : TextButton(
                              onPressed: () {
                                setState(() {
                                  _isEditing = true;
                                  _showAmountPad = false;
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.white24,
                              ),
                              child: Text(appT(context, 'edit')),
                            ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Container(
                    width: 68,
                    height: 68,
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        transaction.icon,
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_isEditing)
                    _TransactionAmountDisplay(
                      amountText: _amountText,
                      prefix: _type == _CategoryType.income ? '+' : '-',
                      amountColor: Colors.white,
                      errorText: _showAmountError
                          ? appT(context, 'enter_amount_gt_zero')
                          : null,
                      shakeTrigger: _validationShakeTrigger,
                      expanded: _showAmountPad,
                      onToggleExpanded: () {
                        setState(() => _showAmountPad = !_showAmountPad);
                      },
                    )
                  else
                    Text(
                      '${isIncome ? '+' : '-'}${_money(transaction.amount.abs())}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    transaction.category,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isEditing && _showAmountPad)
          SliverToBoxAdapter(
            child: _TransactionAmountPad(
              onKeyPressed: (key) {
                setState(() => _handleAmountKey(key));
              },
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appT(context, 'type'), style: _fieldLabelStyle),
                const SizedBox(height: 8),
                _isEditing
                    ? _CategoryTypeSwitcher(
                        activeType: _type,
                        onChanged: (type) {
                          setState(() {
                            _switchCategoryType(type);
                          });
                        },
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: Chip(
                          label: Text(
                            appT(context, isIncome ? 'income' : 'expense'),
                          ),
                          labelStyle: TextStyle(
                            color: amountColor,
                            fontWeight: FontWeight.w800,
                          ),
                          backgroundColor: amountColor.withValues(alpha: 0.1),
                        ),
                      ),
                const SizedBox(height: 20),
                _AddTransactionFieldLabel(
                  icon: Icons.description_outlined,
                  text: appT(context, 'add_transaction_description_label'),
                ),
                const SizedBox(height: 8),
                _isEditing
                    ? TextField(
                        controller: _descriptionController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: appT(
                            context,
                            'add_transaction_description_placeholder',
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF3F4F6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      )
                    : _DetailValue(
                        icon: Icons.notes,
                        value: transaction.description.isEmpty
                            ? '-'
                            : transaction.description,
                      ),
                const SizedBox(height: 20),
                Text(appT(context, 'category'), style: _fieldLabelStyle),
                const SizedBox(height: 8),
                _isEditing
                    ? _CategoryChoiceGrid(
                        categories: _visibleCategories,
                        allCategories: _categories,
                        selectedCategoryId: _selectedCategoryId,
                        activeParentId: _activeCategoryParentId,
                        errorText: _showCategoryError
                            ? appT(context, 'choose_category')
                            : null,
                        shakeTrigger: _validationShakeTrigger,
                        onSelected: _handleCategorySelected,
                      )
                    : _DetailValue(
                        icon: Icons.category_outlined,
                        value: transaction.category,
                      ),
                const SizedBox(height: 20),
                Text(appT(context, 'date'), style: _fieldLabelStyle),
                const SizedBox(height: 8),
                _isEditing
                    ? _DateSelector(
                        date: _date,
                        onDateChanged: (date) => setState(() => _date = date),
                      )
                    : _DetailValue(
                        icon: Icons.calendar_today_outlined,
                        value: _transactionDateLabel(
                          context,
                          transaction.belongsDate,
                        ),
                      ),
                const SizedBox(height: 20),
                if (_isEditing) ...[
                  _AddTransactionFieldLabel(
                    icon: Icons.description_outlined,
                    text: appT(context, 'add_transaction_remark_label'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _remarkController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: appT(
                        context,
                        'add_transaction_remark_placeholder',
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  appT(context, 'transaction_attachments'),
                  style: _fieldLabelStyle,
                ),
                const SizedBox(height: 8),
                _DetailValue(
                  icon: Icons.attach_file,
                  value: appT(context, 'transaction_attach_coming_soon'),
                  muted: true,
                ),
                const SizedBox(height: 24),
                if (!_showDeleteConfirm)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showDeleteConfirm = true),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(appT(context, 'transaction_delete')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      minimumSize: const Size.fromHeight(52),
                      side: BorderSide(
                        color: AppTheme.errorColor.withValues(alpha: 0.28),
                      ),
                    ),
                  )
                else
                  _Card(
                    child: Column(
                      children: [
                        Text(
                          appT(context, 'transaction_delete_confirm'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          appT(context, 'transaction_delete_warning'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _AppShellColors.mutedText,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() => _showDeleteConfirm = false);
                                },
                                child: Text(appT(context, 'cancel')),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _deleteTransaction,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.errorColor,
                                ),
                                child: Text(appT(context, 'delete')),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final responses = _isDemo
          ? await Future.wait([
              ref
                  .read(demoDataStoreProvider)
                  .getTransactionById(widget.transactionId),
              ref.read(demoDataStoreProvider).listAllCategories(),
            ])
          : await Future.wait([
              ref
                  .read(cashlenxApiProvider)
                  .getTransactionById(widget.transactionId),
              ref.read(cashlenxApiProvider).listAllCategories(),
            ]);
      final transaction = _Transaction.fromResponse(responses[0]);
      final categories = _CategoryItem.listFromResponse(responses[1]);
      if (!mounted) return;
      setState(() {
        _transaction = transaction;
        _categories = categories;
        _isLoading = false;
      });
      _resetEditingState(transaction);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
      ToastUtils.showServerErrors(context, error);
    }
  }

  void _resetEditingState(_Transaction transaction) {
    final noteParts = _splitTransactionDescription(transaction.description);
    _amountText = _formatEditableAmount(transaction.amount.abs());
    _descriptionController.text = noteParts.$1;
    _remarkController.text = noteParts.$2;
    _type = transaction.flowType == _CashFlowType.income
        ? _CategoryType.income
        : _CategoryType.expense;
    _selectedCategoryId = _categoryForTransaction(transaction)?.id;
    final selectedCategory = _selectedCategory;
    _activeCategoryParentId = selectedCategory == null
        ? null
        : _hasChildren(selectedCategory)
        ? selectedCategory.id
        : selectedCategory.parentId;
    _rememberCategoryState();
    _date = _parseTransactionDate(transaction.belongsDate) ?? DateTime.now();
    _showAmountPad = false;
    _showAmountError = false;
    _showCategoryError = false;
  }

  _CategoryItem? _categoryForTransaction(_Transaction transaction) {
    final categoryId = transaction.categoryId;
    if (categoryId != null) {
      final category = _categoryById(categoryId);
      if (category != null) return category;
    }

    for (final category in _categories) {
      if (category.type == _type && category.name == transaction.category) {
        return category;
      }
    }
    return null;
  }

  void _handleCategorySelected(_CategoryItem category) {
    setState(() {
      _selectedCategoryId = category.id;
      _showCategoryError = false;
      if (!_hasChildren(category)) {
        _rememberCategoryState();
        return;
      }

      if (_activeCategoryParentId == category.id) {
        _activeCategoryParentId = category.parentId;
      } else {
        _activeCategoryParentId = category.id;
      }
      _rememberCategoryState();
    });
  }

  void _switchCategoryType(_CategoryType type) {
    if (_type == type) return;
    _rememberCategoryState();
    _type = type;
    _restoreCategoryState(type);
    _showCategoryError = false;
  }

  void _rememberCategoryState() {
    _selectedCategoryByType[_type] = _selectedCategoryId;
    _activeCategoryParentByType[_type] = _activeCategoryParentId;
  }

  void _restoreCategoryState(_CategoryType type) {
    final selectedCategory = _categoryById(_selectedCategoryByType[type]);
    _selectedCategoryId = selectedCategory?.type == type
        ? selectedCategory?.id
        : null;

    final activeParent = _categoryById(_activeCategoryParentByType[type]);
    _activeCategoryParentId = activeParent?.type == type
        ? activeParent?.id
        : null;
  }

  Future<void> _saveTransaction() async {
    final transaction = _transaction;
    final amount = double.tryParse(_amountText);
    final category = _selectedCategory;
    if (transaction == null) return;
    if (amount == null || amount <= 0) {
      setState(() {
        _showAmountError = true;
        _validationShakeTrigger++;
      });
      return;
    }
    if (category == null) {
      setState(() {
        _showCategoryError = true;
        _validationShakeTrigger++;
      });
      return;
    }

    setState(() => _isSaving = true);
    try {
      final belongsDate = _dateToken(_date);
      final description = _combinedTransactionDescription(
        _descriptionController,
        _remarkController,
      );
      final typeChanged =
          (_type == _CategoryType.income) !=
          (transaction.flowType == _CashFlowType.income);

      if (_isDemo) {
        final store = ref.read(demoDataStoreProvider);
        if (typeChanged) {
          await store.deleteTransactionById(transaction.id);
          await store.createTransaction(
            type: _type.apiValue,
            belongsDate: belongsDate,
            categoryName: category.name,
            amount: amount,
            description: description.isEmpty ? null : description,
          );
        } else {
          await store.updateTransactionById(
            transaction.id,
            belongsDate: belongsDate,
            categoryName: category.name,
            amount: amount,
            description: description.isEmpty ? null : description,
          );
        }
        ref.read(demoDataRevisionProvider.notifier).bump();
      } else {
        final api = ref.read(cashlenxApiProvider);
        if (typeChanged) {
          await api.deleteTransactionById(transaction.id);
          if (_type == _CategoryType.income) {
            await api.createIncome(
              belongsDate: belongsDate,
              categoryName: category.name,
              amount: amount,
              description: description.isEmpty ? null : description,
            );
          } else {
            await api.createExpense(
              belongsDate: belongsDate,
              categoryName: category.name,
              amount: amount,
              description: description.isEmpty ? null : description,
            );
          }
        } else {
          await api.updateTransactionById(
            transaction.id,
            belongsDate: belongsDate,
            categoryName: category.name,
            amount: amount,
            description: description.isEmpty ? null : description,
          );
        }
      }

      widget.onUpdated();
      if (!mounted) return;
      if (typeChanged) {
        widget.onBack();
        ToastUtils.showSuccess(context, appT(context, 'transaction_updated'));
      } else {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        await _loadData();
        if (!mounted) return;
        ToastUtils.showSuccess(context, appT(context, 'transaction_updated'));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ToastUtils.showServerErrors(context, error);
    }
  }

  void _handleAmountKey(String key) {
    _amountText = _updatedAmountText(_amountText, key);
    _showAmountError = false;
  }

  Future<void> _deleteTransaction() async {
    try {
      if (_isDemo) {
        await ref
            .read(demoDataStoreProvider)
            .deleteTransactionById(widget.transactionId);
        ref.read(demoDataRevisionProvider.notifier).bump();
      } else {
        await ref
            .read(cashlenxApiProvider)
            .deleteTransactionById(widget.transactionId);
      }
      widget.onDeleted();
      if (!mounted) return;
      ToastUtils.showSuccess(context, appT(context, 'transaction_deleted'));
    } catch (error) {
      if (!mounted) return;
      ToastUtils.showServerErrors(context, error);
    }
  }
}

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white24,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _DetailValue extends StatelessWidget {
  const _DetailValue({
    required this.icon,
    required this.value,
    this.muted = false,
  });

  final IconData icon;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: _AppShellColors.mutedText, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: muted ? _AppShellColors.mutedText : _AppShellColors.text,
                fontWeight: muted ? FontWeight.w500 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTransactionSheet extends ConsumerStatefulWidget {
  const _AddTransactionSheet();

  @override
  ConsumerState<_AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<_AddTransactionSheet> {
  final _descriptionController = TextEditingController();
  final _remarkController = TextEditingController();
  var _amountText = '0';
  var _type = _CategoryType.expense;
  var _date = DateTime.now();
  String? _selectedCategoryId;
  String? _activeCategoryParentId;
  final _selectedCategoryByType = <_CategoryType, String?>{};
  final _activeCategoryParentByType = <_CategoryType, String?>{};
  var _showAmountError = false;
  var _showCategoryError = false;
  var _validationShakeTrigger = 0;
  var _isLoading = true;
  var _isSaving = false;
  var _showDetails = false;
  Object? _error;
  List<_CategoryItem> _categories = const [];

  bool get _isDemo => ref.read(authNotifierProvider).value?.role == 'demo';

  List<_CategoryItem> get _visibleCategories {
    final typeCategories = _categories
        .where((category) => category.type == _type)
        .toList(growable: false);

    if (_activeCategoryParentId == null) {
      return typeCategories
          .where((category) => category.parentId == null)
          .toList(growable: false);
    }

    final parent = _categoryById(_activeCategoryParentId);
    return [
      if (parent != null && parent.type == _type) parent,
      ...typeCategories.where(
        (category) => category.parentId == _activeCategoryParentId,
      ),
    ];
  }

  _CategoryItem? get _selectedCategory {
    return _categoryById(_selectedCategoryId);
  }

  _CategoryItem? _categoryById(String? id) {
    if (id == null) return null;
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  bool _hasChildren(_CategoryItem category) {
    return _categories.any(
      (item) => item.type == _type && item.parentId == category.id,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: AppPanelHeader(
                title: appT(context, 'add_transaction_title'),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  children: [
                    _CategoryTypeSwitcher(
                      activeType: _type,
                      onChanged: (type) {
                        setState(() {
                          _switchCategoryType(type);
                        });
                      },
                    ),
                    const SizedBox(height: 34),
                    _TransactionAmountDisplay(
                      label: appT(context, 'add_transaction_amount_label'),
                      amountText: _amountText,
                      amountColor: _themeColor(context),
                      errorText: _showAmountError
                          ? appT(context, 'enter_amount_gt_zero')
                          : null,
                      shakeTrigger: _validationShakeTrigger,
                      expanded: !_showDetails,
                      onToggleExpanded: () {
                        setState(() => _showDetails = !_showDetails);
                      },
                    ),
                    const SizedBox(height: 20),
                    _DetailsToggleButton(
                      expanded: _showDetails,
                      onTap: () {
                        setState(() => _showDetails = !_showDetails);
                      },
                    ),
                    const SizedBox(height: 28),
                    if (_showDetails)
                      _AddTransactionDetails(
                        descriptionController: _descriptionController,
                        remarkController: _remarkController,
                        isLoading: _isLoading,
                        error: _error,
                        categories: _visibleCategories,
                        allCategories: _categories,
                        selectedCategoryId: _selectedCategoryId,
                        activeParentId: _activeCategoryParentId,
                        categoryErrorText: _showCategoryError
                            ? appT(context, 'choose_category')
                            : null,
                        validationShakeTrigger: _validationShakeTrigger,
                        date: _date,
                        onRetry: _loadCategories,
                        onCategorySelected: _handleCategorySelected,
                        onDateChanged: (date) => setState(() => _date = date),
                      )
                    else
                      _TransactionAmountPad(
                        onKeyPressed: (key) {
                          setState(() => _handleAmountKey(key));
                        },
                      ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: _AppShellColors.border),
                  ),
                ),
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveTransaction,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: _themeColor(context),
                  ),
                  child: _isSaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(appT(context, 'add_transaction_submit_button')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = _isDemo
          ? await ref.read(demoDataStoreProvider).listAllCategories()
          : await ref.read(cashlenxApiProvider).listAllCategories();
      if (!mounted) return;
      setState(() {
        _categories = _CategoryItem.listFromResponse(response);
        if (_activeCategoryParentId != null &&
            _categoryById(_activeCategoryParentId) == null) {
          _activeCategoryParentId = null;
        }
        _rememberCategoryState();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTransaction() async {
    final amount = double.tryParse(_amountText);
    final category = _selectedCategory;
    if (amount == null || amount <= 0) {
      setState(() {
        _showAmountError = true;
        _validationShakeTrigger++;
      });
      return;
    }
    if (category == null) {
      setState(() {
        _showDetails = true;
        _showCategoryError = true;
        _validationShakeTrigger++;
      });
      return;
    }

    setState(() => _isSaving = true);
    try {
      final belongsDate = _dateToken(_date);
      final description = _combinedTransactionDescription(
        _descriptionController,
        _remarkController,
      );
      if (_isDemo) {
        await ref
            .read(demoDataStoreProvider)
            .createTransaction(
              type: _type.apiValue,
              belongsDate: belongsDate,
              categoryName: category.name,
              amount: amount,
              description: description.isEmpty ? null : description,
            );
        ref.read(demoDataRevisionProvider.notifier).bump();
      } else if (_type == _CategoryType.income) {
        await ref
            .read(cashlenxApiProvider)
            .createIncome(
              belongsDate: belongsDate,
              categoryName: category.name,
              amount: amount,
              description: description.isEmpty ? null : description,
            );
      } else {
        await ref
            .read(cashlenxApiProvider)
            .createExpense(
              belongsDate: belongsDate,
              categoryName: category.name,
              amount: amount,
              description: description.isEmpty ? null : description,
            );
      }
      ref.invalidate(_dashboardProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ToastUtils.showSuccess(context, appT(context, 'transaction_added'));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ToastUtils.showServerErrors(context, error);
    }
  }

  void _handleCategorySelected(_CategoryItem category) {
    setState(() {
      _selectedCategoryId = category.id;
      _showCategoryError = false;
      if (!_hasChildren(category)) {
        _rememberCategoryState();
        return;
      }

      if (_activeCategoryParentId == category.id) {
        _activeCategoryParentId = category.parentId;
      } else {
        _activeCategoryParentId = category.id;
      }
      _rememberCategoryState();
    });
  }

  void _switchCategoryType(_CategoryType type) {
    if (_type == type) return;
    _rememberCategoryState();
    _type = type;
    _restoreCategoryState(type);
    _showCategoryError = false;
  }

  void _rememberCategoryState() {
    _selectedCategoryByType[_type] = _selectedCategoryId;
    _activeCategoryParentByType[_type] = _activeCategoryParentId;
  }

  void _restoreCategoryState(_CategoryType type) {
    final selectedCategory = _categoryById(_selectedCategoryByType[type]);
    _selectedCategoryId = selectedCategory?.type == type
        ? selectedCategory?.id
        : null;

    final activeParent = _categoryById(_activeCategoryParentByType[type]);
    _activeCategoryParentId = activeParent?.type == type
        ? activeParent?.id
        : null;
  }

  void _handleAmountKey(String key) {
    _amountText = _updatedAmountText(_amountText, key);
    _showAmountError = false;
  }
}

class _DetailsToggleButton extends StatelessWidget {
  const _DetailsToggleButton({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 18,
                color: _AppShellColors.mutedText,
              ),
              const SizedBox(width: 4),
              Text(
                appT(
                  context,
                  expanded
                      ? 'add_transaction_hide_details'
                      : 'add_transaction_show_details',
                ),
                style: const TextStyle(
                  color: _AppShellColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionAmountDisplay extends StatelessWidget {
  const _TransactionAmountDisplay({
    required this.amountText,
    required this.amountColor,
    required this.expanded,
    required this.onToggleExpanded,
    this.prefix = '',
    this.label,
    this.errorText,
    this.shakeTrigger = 0,
  });

  final String? label;
  final String amountText;
  final String prefix;
  final Color amountColor;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final String? errorText;
  final int shakeTrigger;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              color: _AppShellColors.mutedText,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
        ],
        _ValidationField(
          errorText: errorText,
          shakeTrigger: shakeTrigger,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$prefix\$$amountText',
                    style: TextStyle(
                      color: amountColor,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: amountColor.withValues(alpha: 0.78),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddTransactionDetails extends StatelessWidget {
  const _AddTransactionDetails({
    required this.descriptionController,
    required this.remarkController,
    required this.isLoading,
    required this.error,
    required this.categories,
    required this.allCategories,
    required this.selectedCategoryId,
    required this.activeParentId,
    required this.categoryErrorText,
    required this.validationShakeTrigger,
    required this.date,
    required this.onRetry,
    required this.onCategorySelected,
    required this.onDateChanged,
  });

  final TextEditingController descriptionController;
  final TextEditingController remarkController;
  final bool isLoading;
  final Object? error;
  final List<_CategoryItem> categories;
  final List<_CategoryItem> allCategories;
  final String? selectedCategoryId;
  final String? activeParentId;
  final String? categoryErrorText;
  final int validationShakeTrigger;
  final DateTime date;
  final VoidCallback onRetry;
  final ValueChanged<_CategoryItem> onCategorySelected;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _AppShellColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AddTransactionFieldLabel(
            icon: Icons.description_outlined,
            text: appT(context, 'add_transaction_description_label'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: descriptionController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: appT(
                context,
                'add_transaction_description_placeholder',
              ),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            appT(context, 'add_transaction_category_label'),
            style: _fieldLabelStyle,
          ),
          const SizedBox(height: 10),
          if (isLoading)
            const _TransactionLoadingCard()
          else if (error != null)
            _TransactionErrorCard(onRetry: onRetry)
          else
            _CategoryChoiceGrid(
              categories: categories,
              allCategories: allCategories,
              selectedCategoryId: selectedCategoryId,
              activeParentId: activeParentId,
              errorText: categoryErrorText,
              shakeTrigger: validationShakeTrigger,
              onSelected: onCategorySelected,
            ),
          const SizedBox(height: 18),
          _AddTransactionFieldLabel(
            icon: Icons.calendar_today_outlined,
            text: appT(context, 'add_transaction_date_label'),
          ),
          const SizedBox(height: 8),
          _DateSelector(date: date, onDateChanged: onDateChanged),
          const SizedBox(height: 18),
          _AddTransactionFieldLabel(
            icon: Icons.description_outlined,
            text: appT(context, 'add_transaction_remark_label'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: remarkController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: appT(context, 'add_transaction_remark_placeholder'),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _AddTransactionFieldLabel(
            icon: Icons.attach_file,
            text: appT(context, 'transaction_attachments'),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              border: Border.all(color: _AppShellColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.attach_file,
                  size: 18,
                  color: _AppShellColors.mutedText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    appT(context, 'transaction_attach_coming_soon'),
                    style: const TextStyle(
                      color: _AppShellColors.mutedText,
                      fontSize: 13,
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
}

class _AddTransactionFieldLabel extends StatelessWidget {
  const _AddTransactionFieldLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _AppShellColors.mutedText),
        const SizedBox(width: 5),
        Text(text, style: _fieldLabelStyle),
      ],
    );
  }
}

class _TransactionAmountPad extends StatelessWidget {
  const _TransactionAmountPad({required this.onKeyPressed});

  final ValueChanged<String> onKeyPressed;

  static const _keys = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['.', '0', 'backspace'],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.65,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final row in _keys)
            for (final key in row)
              Material(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onKeyPressed(key),
                  child: Center(
                    child: key == 'backspace'
                        ? const Icon(
                            Icons.backspace_outlined,
                            color: _AppShellColors.mutedText,
                          )
                        : Text(
                            key,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab({
    required this.username,
    required this.email,
    required this.avatarUrl,
    required this.onProfileTap,
  });

  final String username;
  final String email;
  final String? avatarUrl;
  final VoidCallback onProfileTap;

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final currency = ref.watch(currencyProvider);
    final language = ref.watch(i18nProvider);

    return _PageScaffold(
      title: appT(context, 'settings'),
      subtitle: appT(context, 'settings_subtitle'),
      children: [
        _ProfileCard(
          username: widget.username,
          email: widget.email,
          avatarUrl: widget.avatarUrl,
          onTap: widget.onProfileTap,
        ),
        _SettingsSection(
          title: appT(context, 'preferences'),
          children: [
            _SettingsTile(
              icon: Icons.palette_outlined,
              color: themeColor,
              label: appT(context, 'theme'),
              trailing: _ColorDot(color: themeColor),
              onTap: _showThemeColorDialog,
            ),
            _SettingsTile(
              icon: Icons.attach_money,
              color: AppTheme.successColor,
              label: appT(context, 'currency'),
              trailing: Text(
                '${currency.code} (${currency.symbol})',
                style: const TextStyle(
                  color: _AppShellColors.mutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: _showCurrencyDialog,
            ),
            _SettingsTile(
              icon: Icons.language,
              color: const Color(0xFF2563EB),
              label: appT(context, 'language'),
              trailing: Text(
                language.nativeName,
                style: const TextStyle(
                  color: _AppShellColors.mutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: _showLanguageDialog,
            ),
          ],
        ),
        _SettingsSection(
          title: appT(context, 'support'),
          children: [
            _SettingsTile(
              icon: Icons.help_outline,
              color: AppTheme.successColor,
              label: appT(context, 'about'),
              onTap: _showAboutDialog,
            ),
          ],
        ),
      ],
    );
  }

  void _showThemeColorDialog() {
    var draftColor = ref.read(themeColorProvider);

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 384),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppPanelHeader(
                        title: appT(context, 'choose_theme_color'),
                      ),
                      const SizedBox(height: 34),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: draftColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: draftColor.withValues(alpha: 0.24),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${appT(context, 'selected')}: ${AppTheme.hexColor(draftColor)}',
                        style: const TextStyle(
                          color: _AppShellColors.mutedText,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: Theme.of(
                            context,
                          ).colorScheme.copyWith(primary: draftColor),
                        ),
                        child: AppColorPicker(
                          colors: _categoryColorChoices,
                          selectedColor: draftColor,
                          onColorSelected: (color) {
                            setDialogState(() => draftColor = color);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '\uD83D\uDCA1',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                appT(context, 'theme_note'),
                                style: const TextStyle(
                                  color: _AppShellColors.text,
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _AppShellColors.text,
                                minimumSize: const Size.fromHeight(52),
                                side: const BorderSide(
                                  color: Color(0xFFD1D5DB),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                appT(context, 'cancel'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                await ref
                                    .read(themeColorProvider.notifier)
                                    .setColor(draftColor);
                                try {
                                  await ref.read(
                                    persistUserConfigurationProvider,
                                  )();
                                } catch (error) {
                                  if (context.mounted) {
                                    ToastUtils.showServerErrors(context, error);
                                  }
                                }
                                if (context.mounted) Navigator.pop(context);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: draftColor,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                appT(context, 'apply'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCurrencyDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        final selectedCurrency = ref.read(currencyProvider);

        return _SelectionDialog<CurrencyOption>(
          title: appT(context, 'select_currency'),
          description: appT(context, 'currency_description'),
          selectedValue: selectedCurrency,
          options: [
            for (final currency in CurrencyOption.values)
              _SelectionOption(
                value: currency,
                leadingText: currency.symbol,
                title: currency.code,
                subtitle: currency.name,
              ),
          ],
          onSelected: (currency) async {
            await ref.read(currencyProvider.notifier).setCurrency(currency);
            try {
              await ref.read(persistUserConfigurationProvider)();
            } catch (error) {
              if (context.mounted) {
                ToastUtils.showServerErrors(context, error);
              }
            }
            if (!context.mounted) return;
            Navigator.pop(context);
            ToastUtils.showSuccess(
              context,
              '${appT(context, 'currency_updated')} ${currency.code}.',
            );
          },
        );
      },
    );
  }

  void _showLanguageDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        final selectedLanguage = ref.read(i18nProvider);

        return _SelectionDialog<AppLanguage>(
          title: appT(context, 'select_language'),
          description: appT(context, 'language_description'),
          selectedValue: selectedLanguage,
          options: [
            for (final language in AppLanguage.values)
              _SelectionOption(
                value: language,
                leadingText: _languageLeadingText(language),
                title: _languageNativeName(language),
                subtitle: language.name,
              ),
          ],
          onSelected: (language) async {
            await ref.read(i18nProvider.notifier).setLanguage(language);
            try {
              await ref.read(persistUserConfigurationProvider)();
            } catch (error) {
              if (context.mounted) {
                ToastUtils.showServerErrors(context, error);
              }
            }
            if (!context.mounted) return;
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _showAboutDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        appT(context, 'about_title'),
                        style: _sectionTitle(context),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: 80,
                  height: 80,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Image.asset('assets/images/app_icon.png'),
                ),
                const SizedBox(height: 16),
                Text(
                  appT(context, 'app_name'),
                  style: const TextStyle(
                    color: _AppShellColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  appT(context, 'app_tagline'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _AppShellColors.mutedText),
                ),
                const SizedBox(height: 20),
                const _AboutVersionCard(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ToastUtils.showInfo(
                            context,
                            appT(context, 'latest_version'),
                          );
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(appT(context, 'check_update')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(appT(context, 'close')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  '© 2026 CashLenX. All rights reserved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _AppShellColors.navMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PageScaffold extends StatelessWidget {
  const _PageScaffold({
    this.title,
    this.subtitle,
    this.header,
    required this.children,
  });

  final String? title;
  final String? subtitle;
  final Widget? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child:
              header ?? _StandardHeader(title: title ?? '', subtitle: subtitle),
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

class _NavigationHeader extends StatelessWidget {
  const _NavigationHeader({
    required this.title,
    required this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback onBack;
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
          IconButton.filledTonal(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: _pageTitle(context))),
          ?trailing,
        ],
      ),
    );
  }
}

class _FilterBadge extends StatelessWidget {
  const _FilterBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: Color(0xFFFF8A65),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _TransactionFiltersCard extends StatelessWidget {
  const _TransactionFiltersCard({
    required this.selectedType,
    required this.selectedCategoryId,
    required this.dateFrom,
    required this.dateTo,
    required this.categories,
    required this.searchController,
    required this.onTypeChanged,
    required this.onCategoryChanged,
    required this.onDateFromPressed,
    required this.onDateToPressed,
    required this.onClear,
  });

  final _TransactionFilterType selectedType;
  final String? selectedCategoryId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final List<_CategoryItem> categories;
  final TextEditingController searchController;
  final ValueChanged<_TransactionFilterType> onTypeChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onDateFromPressed;
  final VoidCallback onDateToPressed;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(appT(context, 'type'), style: _fieldLabelStyle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _TransactionFilterType.values.map((type) {
              final selected = selectedType == type;
              return ChoiceChip(
                selected: selected,
                label: Text(appT(context, type.labelKey)),
                onSelected: (_) => onTypeChanged(type),
                showCheckmark: false,
                selectedColor: Theme.of(context).colorScheme.primary,
                backgroundColor: AppDesignTokens.softFill,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppDesignTokens.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(appT(context, 'category'), style: _fieldLabelStyle),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: selectedCategoryId,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(appT(context, 'all_categories')),
              ),
              ...categories.map(
                (category) => DropdownMenuItem<String?>(
                  value: category.id,
                  child: Text('${category.icon} ${category.name}'),
                ),
              ),
            ],
            onChanged: onCategoryChanged,
          ),
          const SizedBox(height: 16),
          Text(appT(context, 'date_range'), style: _fieldLabelStyle),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DateFilterButton(
                  key: const ValueKey('transaction-date-from'),
                  label: appT(context, 'date_from'),
                  date: dateFrom,
                  onPressed: onDateFromPressed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateFilterButton(
                  key: const ValueKey('transaction-date-to'),
                  label: appT(context, 'date_to'),
                  date: dateTo,
                  onPressed: onDateToPressed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(appT(context, 'search'), style: _fieldLabelStyle),
          const SizedBox(height: 8),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: appT(context, 'search_transactions'),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onClear,
              child: Text(appT(context, 'clear_filters')),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({
    super.key,
    required this.label,
    required this.date,
    required this.onPressed,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppDesignTokens.text,
        backgroundColor: AppDesignTokens.softFill,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        side: const BorderSide(color: AppDesignTokens.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              date == null
                  ? label
                  : MaterialLocalizations.of(context).formatCompactDate(date!),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveTransactionFilters extends StatelessWidget {
  const _ActiveTransactionFilters({
    required this.selectedType,
    required this.selectedCategory,
    required this.dateFrom,
    required this.dateTo,
    required this.searchQuery,
    required this.onTypeRemoved,
    required this.onCategoryRemoved,
    required this.onDateRemoved,
    required this.onSearchRemoved,
  });

  final _TransactionFilterType selectedType;
  final _CategoryItem? selectedCategory;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String searchQuery;
  final VoidCallback onTypeRemoved;
  final VoidCallback onCategoryRemoved;
  final VoidCallback onDateRemoved;
  final VoidCallback onSearchRemoved;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final dateLabel = switch ((dateFrom, dateTo)) {
      (final from?, final to?) =>
        '${localizations.formatCompactDate(from)} – ${localizations.formatCompactDate(to)}',
      (final from?, null) =>
        '${appT(context, 'date_from')}: ${localizations.formatCompactDate(from)}',
      (null, final to?) =>
        '${appT(context, 'date_to')}: ${localizations.formatCompactDate(to)}',
      _ => null,
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (selectedType != _TransactionFilterType.all)
          _RemovableFilterChip(
            label: appT(context, selectedType.labelKey),
            onDeleted: onTypeRemoved,
          ),
        if (selectedCategory != null)
          _RemovableFilterChip(
            label: selectedCategory!.name,
            onDeleted: onCategoryRemoved,
          ),
        if (dateLabel != null)
          _RemovableFilterChip(label: dateLabel, onDeleted: onDateRemoved),
        if (searchQuery.isNotEmpty)
          _RemovableFilterChip(
            label: '“$searchQuery”',
            onDeleted: onSearchRemoved,
          ),
      ],
    );
  }
}

class _RemovableFilterChip extends StatelessWidget {
  const _RemovableFilterChip({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close, size: 16),
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppDesignTokens.border),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(
        color: AppDesignTokens.text,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

String _transactionResultSummary(
  BuildContext context,
  int count, {
  required bool filtered,
}) {
  final base = switch (count) {
    0 => appT(context, 'no_transactions_found'),
    1 => '1 ${appT(context, 'transaction')}',
    _ => '$count ${appT(context, 'transactions_count')}',
  };
  return filtered ? '$base (${appT(context, 'filtered')})' : base;
}

class _TransactionLoadingCard extends StatelessWidget {
  const _TransactionLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _TransactionErrorCard extends StatelessWidget {
  const _TransactionErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _EmptyStateCard(
      icon: Icons.error_outline,
      title: appT(context, 'transactions_failed'),
      message: appT(context, 'transaction_request_failed'),
      actionLabel: appT(context, 'retry'),
      onAction: onRetry,
    );
  }
}

class _ValidationField extends StatefulWidget {
  const _ValidationField({
    required this.child,
    this.errorText,
    this.shakeTrigger = 0,
  });

  final Widget child;
  final String? errorText;
  final int shakeTrigger;

  @override
  State<_ValidationField> createState() => _ValidationFieldState();
}

class _ValidationFieldState extends State<_ValidationField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void didUpdateWidget(covariant _ValidationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorText != null &&
        widget.shakeTrigger != oldWidget.shakeTrigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const errorColor = Color(0xFFFF2A2A);
    final hasError = widget.errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasError) ...[
          Text(
            widget.errorText!,
            style: const TextStyle(
              color: errorColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
        ],
        AnimatedBuilder(
          animation: _controller,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: double.infinity,
            padding: hasError ? const EdgeInsets.all(8) : EdgeInsets.zero,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: hasError ? Border.all(color: errorColor, width: 2) : null,
            ),
            child: widget.child,
          ),
          builder: (context, child) {
            final offset = math.sin(_controller.value * math.pi * 6) * 7;
            return Transform.translate(offset: Offset(offset, 0), child: child);
          },
        ),
      ],
    );
  }
}

class _CategoryChoiceGrid extends StatelessWidget {
  const _CategoryChoiceGrid({
    required this.categories,
    this.allCategories,
    required this.selectedCategoryId,
    this.activeParentId,
    this.errorText,
    this.shakeTrigger = 0,
    required this.onSelected,
  });

  final List<_CategoryItem> categories;
  final List<_CategoryItem>? allCategories;
  final String? selectedCategoryId;
  final String? activeParentId;
  final String? errorText;
  final int shakeTrigger;
  final ValueChanged<_CategoryItem> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return _Card(
        child: Center(
          child: Text(
            appT(context, 'no_categories_available'),
            style: const TextStyle(color: _AppShellColors.mutedText),
          ),
        ),
      );
    }

    _CategoryItem? selectedCategory;
    for (final category in categories) {
      if (category.id == selectedCategoryId) {
        selectedCategory = category;
        break;
      }
    }

    return Column(
      children: [
        _ValidationField(
          errorText: errorText,
          shakeTrigger: shakeTrigger,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: 78,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final selected = category.id == selectedCategoryId;
              final hasChildren = (allCategories ?? categories).any(
                (item) =>
                    item.type == category.type && item.parentId == category.id,
              );
              final isActiveParent = activeParentId == category.id;

              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelected(category),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? _themeColor(context)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(
                    children: [
                      if (hasChildren)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Icon(
                            isActiveParent
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 15,
                            color: selected
                                ? Colors.white70
                                : _AppShellColors.mutedText,
                          ),
                        ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              category.icon,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(height: 5),
                            SizedBox(
                              width: double.infinity,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  category.name,
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : _AppShellColors.text,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    height: 1.05,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (selectedCategory != null) ...[
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              text: '${appT(context, 'selected')}: ',
              style: const TextStyle(
                color: _AppShellColors.mutedText,
                fontSize: 13,
              ),
              children: [
                TextSpan(
                  text: selectedCategory.name,
                  style: TextStyle(
                    color: _themeColor(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DateSelector extends StatefulWidget {
  const _DateSelector({required this.date, required this.onDateChanged});

  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;

  @override
  State<_DateSelector> createState() => _DateSelectorState();
}

class _DateSelectorState extends State<_DateSelector> {
  late var _visibleMonth = DateTime(widget.date.year, widget.date.month);
  var _isExpanded = false;

  @override
  void didUpdateWidget(covariant _DateSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDate(oldWidget.date, widget.date)) {
      _visibleMonth = DateTime(widget.date.year, widget.date.month);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _shortDateLabel(context, widget.date),
                    style: const TextStyle(
                      color: _AppShellColors.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: _AppShellColors.mutedText,
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _InlineCalendar(
              selectedDate: widget.date,
              visibleMonth: _visibleMonth,
              onMonthChanged: (month) {
                setState(() => _visibleMonth = month);
              },
              onDateSelected: widget.onDateChanged,
            ),
          ),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeOut,
          sizeCurve: Curves.easeOut,
        ),
      ],
    );
  }
}

class _InlineCalendar extends StatelessWidget {
  const _InlineCalendar({
    required this.selectedDate,
    required this.visibleMonth,
    required this.onMonthChanged,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final DateTime visibleMonth;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month);
    final daysInMonth = DateUtils.getDaysInMonth(
      visibleMonth.year,
      visibleMonth.month,
    );
    final localizations = MaterialLocalizations.of(context);
    final firstWeekday = firstDay.weekday % DateTime.daysPerWeek;
    final leadingEmptyCells =
        (firstWeekday - localizations.firstDayOfWeekIndex) %
        DateTime.daysPerWeek;
    final cellCount = leadingEmptyCells + daysInMonth;
    final rowCount = (cellCount / DateTime.daysPerWeek).ceil();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _AppShellColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _CalendarIconButton(
                icon: Icons.chevron_left,
                onTap: () => onMonthChanged(_addMonths(visibleMonth, -1)),
              ),
              Expanded(
                child: Text(
                  _monthYearLabel(context, visibleMonth),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _AppShellColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _CalendarIconButton(
                icon: Icons.chevron_right,
                onTap: () => onMonthChanged(_addMonths(visibleMonth, 1)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (final weekday in _localizedWeekdays(context))
                Expanded(
                  child: Text(
                    weekday,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _AppShellColors.mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            children: [
              for (var row = 0; row < rowCount; row++) ...[
                Row(
                  children: [
                    for (
                      var column = 0;
                      column < DateTime.daysPerWeek;
                      column++
                    )
                      Expanded(
                        child: _CalendarDayCell(
                          day: _dayForCell(
                            row: row,
                            column: column,
                            leadingEmptyCells: leadingEmptyCells,
                            daysInMonth: daysInMonth,
                          ),
                          month: visibleMonth,
                          selectedDate: selectedDate,
                          onDateSelected: onDateSelected,
                        ),
                      ),
                  ],
                ),
                if (row != rowCount - 1) const SizedBox(height: 10),
              ],
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: _AppShellColors.border),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: TextButton(
              onPressed: () {
                final today = DateTime.now();
                onDateSelected(DateTime(today.year, today.month, today.day));
                onMonthChanged(DateTime(today.year, today.month));
              },
              style: TextButton.styleFrom(
                foregroundColor: _AppShellColors.text,
                backgroundColor: const Color(0xFFF3F4F6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                appT(context, 'today'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int? _dayForCell({
    required int row,
    required int column,
    required int leadingEmptyCells,
    required int daysInMonth,
  }) {
    final day = row * DateTime.daysPerWeek + column - leadingEmptyCells + 1;
    if (day < 1 || day > daysInMonth) return null;
    return day;
  }
}

class _CalendarIconButton extends StatelessWidget {
  const _CalendarIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      color: _AppShellColors.text,
      iconSize: 22,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.month,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final int? day;
  final DateTime month;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final day = this.day;
    if (day == null) return const SizedBox(height: 48);

    final date = DateTime(month.year, month.month, day);
    final isSelected = _isSameDate(date, selectedDate);

    return Center(
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => onDateSelected(date),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? _themeColor(context) : Colors.transparent,
            shape: BoxShape.circle,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _themeColor(context).withValues(alpha: 0.24),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                color: isSelected ? Colors.white : _AppShellColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionDialog<T> extends StatelessWidget {
  const _SelectionDialog({
    required this.title,
    required this.description,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  final String title;
  final String description;
  final List<_SelectionOption<T>> options;
  final T selectedValue;
  final Future<void> Function(T value) onSelected;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 384),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppPanelHeader(title: title),
              const SizedBox(height: 24),
              Text(
                description,
                style: const TextStyle(
                  color: _AppShellColors.mutedText,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 18),
              for (final option in options) ...[
                _SelectionOptionTile<T>(
                  option: option,
                  selected: option.value == selectedValue,
                  onTap: () => onSelected(option.value),
                ),
                if (option != options.last) const SizedBox(height: 8),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _AppShellColors.text,
                    side: const BorderSide(
                      color: Color(0xFFD1D5DB),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    appT(context, 'cancel'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
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

class _SelectionOption<T> {
  const _SelectionOption({
    required this.value,
    required this.leadingText,
    required this.title,
    required this.subtitle,
  });

  final T value;
  final String leadingText;
  final String title;
  final String subtitle;
}

class _SelectionOptionTile<T> extends StatelessWidget {
  const _SelectionOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _SelectionOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFF3F4F6) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _themeColor(context),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    option.leadingText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: const TextStyle(
                        color: _AppShellColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: const TextStyle(
                        color: _AppShellColors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _themeColor(context),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutVersionCard extends ConsumerWidget {
  const _AboutVersionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfo = ref.watch(_packageInfoProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: packageInfo.when(
          loading: () => const [Center(child: CircularProgressIndicator())],
          error: (_, _) => [
            _AboutVersionRow(label: appT(context, 'version'), value: '—'),
          ],
          data: (info) => [
            _AboutVersionRow(
              label: appT(context, 'version'),
              value: info.version,
            ),
            const SizedBox(height: 10),
            _AboutVersionRow(
              label: appT(context, 'build_number'),
              value: info.buildNumber,
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutVersionRow extends StatelessWidget {
  const _AboutVersionRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _AppShellColors.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _AppShellColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppListSection(title: title, children: children);
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
    return AppListTile(
      icon: icon,
      color: color,
      label: label,
      onTap: onTap,
      trailing: trailing,
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.username,
    required this.email,
    required this.avatarUrl,
    required this.onTap,
  });

  final String username;
  final String email;
  final String? avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Card(
      onTap: onTap,
      child: Row(
        children: [
          _AvatarBadge(username: username, avatarUrl: avatarUrl),
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
    final themeColor = _themeColor(context);

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
          final label = appT(context, tab.labelKey);

          if (isAdd) {
            return Expanded(
              child: Semantics(
                button: true,
                label: label,
                excludeSemantics: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onSelect(tab),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: themeColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withValues(alpha: 0.2),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(tab.icon, color: Colors.white, size: 29),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: TextStyle(
                          color: themeColor,
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
            child: Semantics(
              button: true,
              selected: isSelected,
              label: label,
              excludeSemantics: true,
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
                            ? themeColor
                            : _AppShellColors.navMuted,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? themeColor
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
    return AppCard(onTap: onTap, padding: padding, child: child);
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({
    required this.username,
    required this.avatarUrl,
    required this.onTap,
  });

  final String username;
  final String? avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: _AvatarBadge(username: username, avatarUrl: avatarUrl),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.username, required this.avatarUrl});

  final String username;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF7E8A7),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: ClipOval(
          child: _AvatarImage(username: username, avatarUrl: avatarUrl),
        ),
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.username, required this.avatarUrl});

  final String username;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final value = avatarUrl?.trim() ?? '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(
        value,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _DefaultAvatarImage(username: username),
      );
    }

    if (value.startsWith('assets/')) {
      return Image.asset(
        value,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _DefaultAvatarImage(username: username),
      );
    }

    return _DefaultAvatarImage(username: username);
  }
}

class _DefaultAvatarImage extends StatelessWidget {
  const _DefaultAvatarImage({required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _defaultAvatarAsset,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        final initial = username.trim().isEmpty ? 'U' : username.trim()[0];
        return ColoredBox(
          color: _themeColor(context),
          child: Center(
            child: Text(
              initial.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
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
        backgroundColor: _themeColor(context),
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
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final themeColor = _themeColor(context);

    return _Card(
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: themeColor, size: 34),
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
          if (onAction != null)
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
      title: appT(context, 'home'),
      children: [
        _EmptyStateCard(
          icon: Icons.error_outline,
          title: appT(context, 'dashboard_failed'),
          message: appT(context, 'mock_request_failed'),
          actionLabel: appT(context, 'retry'),
          onAction: onRetry,
        ),
      ],
    );
  }
}

enum _HomeTab {
  home('nav_home', Icons.home_outlined),
  stats('nav_category', Icons.grid_view_outlined),
  add('nav_add', Icons.add),
  budget('nav_budget', Icons.account_balance_wallet_outlined),
  settings('nav_settings', Icons.settings_outlined);

  const _HomeTab(this.labelKey, this.icon);

  final String labelKey;
  final IconData icon;
}

enum _CategoryType {
  expense('expense', 'expense'),
  income('income', 'income');

  const _CategoryType(this.labelKey, this.apiValue);

  final String labelKey;
  final String apiValue;

  static _CategoryType fromApi(Object? value) {
    return switch (value?.toString()) {
      'income' => _CategoryType.income,
      _ => _CategoryType.expense,
    };
  }
}

enum _CategoryRowAction { edit, move, delete }

enum _CategoryEditorMode { create, edit }

class _CategoryEditorRequest {
  const _CategoryEditorRequest({
    required this.name,
    required this.type,
    this.parentId,
    this.emoji,
    this.bgColor,
  });

  final String name;
  final _CategoryType type;
  final String? parentId;
  final String? emoji;
  final Color? bgColor;

  String get resolvedEmoji => _categoryEmojiOrDefault(emoji);

  String get resolvedBgColorHex => _hexColor(bgColor ?? _defaultCategoryColor);
}

class _CategoryItem {
  const _CategoryItem({
    required this.id,
    required this.name,
    required this.type,
    required this.emoji,
    required this.bgColor,
    this.parentId,
    this.remark,
  });

  final String id;
  final String name;
  final _CategoryType type;
  final String emoji;
  final Color bgColor;
  final String? parentId;
  final String? remark;

  String get icon => emoji;

  Color get color => bgColor;

  factory _CategoryItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'] ?? json['Id'] ?? json['_id'] ?? json['category_id'];
    final parentId = json['parent_id'] ?? json['parentId'] ?? json['ParentId'];
    final name =
        json['name'] ?? json['Name'] ?? json['category_name'] ?? 'Category';

    return _CategoryItem(
      id: id?.toString() ?? name.toString(),
      name: name.toString(),
      type: _CategoryType.fromApi(json['type'] ?? json['Type']),
      emoji: _categoryEmojiOrDefault(json['emoji'] ?? json['Emoji']),
      bgColor: _categoryColorOrDefault(json['bg_color'] ?? json['bgColor']),
      parentId: _nullableString(parentId),
      remark: _nullableString(json['remark'] ?? json['Remark']),
    );
  }

  static List<_CategoryItem> listFromResponse(ApiJson response) {
    final data = _unwrapData(response);
    final rawList = _asList(data);

    return rawList
        .whereType<Map>()
        .map((item) => _CategoryItem.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }
}

class _DashboardApi {
  const _DashboardApi(this._api) : _demoDataStore = null;

  const _DashboardApi.demo(this._demoDataStore) : _api = null;

  final CashlenxApi? _api;
  final DemoDataStore? _demoDataStore;

  Future<_DashboardResponse> fetchDashboard() async {
    final now = DateTime.now();
    final date = _dateToken(now);
    final month = _monthToken(now);
    final year = _yearToken(now);
    final api = _api;
    final demoDataStore = _demoDataStore;

    final responses = demoDataStore != null
        ? await Future.wait([
            demoDataStore.getDailySummary(date),
            demoDataStore.getMonthlySummary(month),
            demoDataStore.getYearlySummary(year),
            demoDataStore.getTotalSummary(),
            demoDataStore.listAllTransactions(limit: 5),
          ])
        : await Future.wait([
            api!.getDailySummary(date),
            api.getMonthlySummary(month),
            api.getYearlySummary(year),
            api.getTotalSummary(),
            api.listAllTransactions(limit: 5),
          ]);

    final daySummary = _CashSummary.fromResponse(responses[0]);
    final monthSummary = _CashSummary.fromResponse(responses[1]);
    final yearSummary = _CashSummary.fromResponse(responses[2]);
    final totalSummary = _CashSummary.fromResponse(responses[3]);
    final recentTransactions = _Transaction.listFromResponse(responses[4]);

    return _DashboardResponse.mock(
      summary: _Summary.fromApi(
        day: daySummary,
        month: monthSummary,
        year: yearSummary,
        total: totalSummary,
      ),
      recentTransactions: recentTransactions,
      categoryBreakdown: _categoryBreakdownFromSummary(monthSummary),
    );
  }

  static String _dateToken(DateTime date) {
    return '${date.year}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String _monthToken(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}';
  }

  static String _yearToken(DateTime date) => date.year.toString();

  static List<_CategoryBreakdownItem> _categoryBreakdownFromSummary(
    _CashSummary summary,
  ) {
    if (summary.categoryBreakdown.isEmpty) {
      return const [];
    }

    final total = summary.categoryBreakdown.values.fold<double>(
      0,
      (sum, amount) => sum + amount,
    );
    final entries = summary.categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.indexed.map((entry) {
      final index = entry.$1;
      final category = entry.$2;
      final percent = total == 0 ? 0.0 : (category.value / total) * 100;

      return _CategoryBreakdownItem(
        name: category.key,
        amount: category.value,
        percent: percent,
        color: _categoryColors[index % _categoryColors.length],
      );
    }).toList();
  }
}

class _DashboardResponse {
  const _DashboardResponse({
    required this.summary,
    required this.recentTransactions,
    required this.categoryBreakdown,
  });

  final _Summary summary;
  final List<_Transaction> recentTransactions;
  final List<_CategoryBreakdownItem> categoryBreakdown;

  factory _DashboardResponse.mock({
    _Summary? summary,
    List<_Transaction>? recentTransactions,
    List<_CategoryBreakdownItem>? categoryBreakdown,
  }) {
    summary ??= const _Summary(
      dayBalance: 185.50,
      dayIncome: 420,
      dayExpense: 234.50,
      monthBalance: 8247.35,
      monthIncome: 3500,
      monthExpense: 1215,
      yearBalance: 7010.25,
      yearIncome: 2870,
      yearExpense: 1069.20,
      totalBalance: 15240.75,
      totalIncome: 6380,
      totalExpense: 3485.70,
    );
    final resolvedCategoryBreakdown =
        categoryBreakdown ??
        const [
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
        ];

    return _DashboardResponse(
      summary: summary,
      recentTransactions: recentTransactions ?? const [],
      categoryBreakdown: resolvedCategoryBreakdown,
    );
  }
}

class _Summary {
  const _Summary({
    required this.dayBalance,
    required this.dayIncome,
    required this.dayExpense,
    required this.monthBalance,
    required this.monthIncome,
    required this.monthExpense,
    required this.yearBalance,
    required this.yearIncome,
    required this.yearExpense,
    required this.totalBalance,
    required this.totalIncome,
    required this.totalExpense,
  });

  final double dayBalance;
  final double dayIncome;
  final double dayExpense;
  final double monthBalance;
  final double monthIncome;
  final double monthExpense;
  final double yearBalance;
  final double yearIncome;
  final double yearExpense;
  final double totalBalance;
  final double totalIncome;
  final double totalExpense;

  factory _Summary.fromApi({
    required _CashSummary day,
    required _CashSummary month,
    required _CashSummary year,
    required _CashSummary total,
  }) {
    return _Summary(
      dayBalance: day.balance,
      dayIncome: day.totalIncome,
      dayExpense: day.totalExpense,
      monthBalance: month.balance,
      monthIncome: month.totalIncome,
      monthExpense: month.totalExpense,
      yearBalance: year.balance,
      yearIncome: year.totalIncome,
      yearExpense: year.totalExpense,
      totalBalance: total.balance,
      totalIncome: total.totalIncome,
      totalExpense: total.totalExpense,
    );
  }

  double get income => totalIncome;

  double get expense => totalExpense;

  _SummaryRangeValues range(_SummaryRange range) {
    return switch (range) {
      _SummaryRange.day => _SummaryRangeValues(
        balanceLabel: 'Today Balance',
        totalBalance: dayBalance,
        income: dayIncome,
        expense: dayExpense,
      ),
      _SummaryRange.month => _SummaryRangeValues(
        balanceLabel: 'Month Balance',
        totalBalance: monthBalance,
        income: monthIncome,
        expense: monthExpense,
      ),
      _SummaryRange.year => _SummaryRangeValues(
        balanceLabel: 'Year Balance',
        totalBalance: yearBalance,
        income: yearIncome,
        expense: yearExpense,
      ),
      _SummaryRange.total => _SummaryRangeValues(
        balanceLabel: 'Total Balance',
        totalBalance: totalBalance,
        income: totalIncome,
        expense: totalExpense,
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
  day('day'),
  month('month'),
  year('year'),
  total('total');

  const _SummaryRange(this.labelKey);

  final String labelKey;
}

enum _CashFlowType {
  expense,
  income;

  static _CashFlowType fromApi(Object? value) {
    return switch (value?.toString()) {
      'income' => _CashFlowType.income,
      _ => _CashFlowType.expense,
    };
  }
}

enum _TransactionFilterType {
  all('all', null, null),
  income('income', _CashFlowType.income, _CategoryType.income),
  expense('expense', _CashFlowType.expense, _CategoryType.expense);

  const _TransactionFilterType(this.labelKey, this.flowType, this.categoryType);

  final String labelKey;
  final _CashFlowType? flowType;
  final _CategoryType? categoryType;
}

class _CashSummary {
  const _CashSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.categoryBreakdown,
  });

  final double totalIncome;
  final double totalExpense;
  final double balance;
  final Map<String, double> categoryBreakdown;

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
      categoryBreakdown: _jsonDoubleMap(json['category_breakdown']),
    );
  }
}

class _Transaction {
  const _Transaction({
    required this.id,
    required this.title,
    required this.description,
    required this.belongsDate,
    required this.dateLabel,
    required this.dateGroupLabel,
    required this.dateSort,
    required this.amount,
    required this.category,
    required this.categoryId,
    required this.flowType,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;
  final String description;
  final String belongsDate;
  final String dateLabel;
  final String dateGroupLabel;
  final DateTime dateSort;
  final double amount;
  final String category;
  final String? categoryId;
  final _CashFlowType flowType;
  final String icon;
  final Color color;

  factory _Transaction.fromJson(Map<String, dynamic> json) {
    final flowType = _CashFlowType.fromApi(
      json['flow_type'] ?? json['flowType'] ?? json['type'] ?? json['Type'],
    );
    final category = _jsonMap(json['category'] ?? json['Category']);
    final categoryName =
        _nullableString(
          json['category_name'] ??
              json['categoryName'] ??
              category?['name'] ??
              category?['category_name'] ??
              json['Category'],
        ) ??
        'Uncategorized';
    final description = _nullableString(
      json['description'] ?? json['Description'],
    );
    final rawDate = json['belongs_date'] ?? json['date'];
    final rawAmount = _jsonDouble(json['amount'] ?? json['Amount']);
    final amount = flowType == _CashFlowType.expense
        ? -rawAmount.abs()
        : rawAmount.abs();

    return _Transaction(
      id: (json['id'] ?? json['Id'] ?? json['_id'] ?? '').toString(),
      title: description ?? categoryName,
      description: description ?? '',
      belongsDate: rawDate?.toString() ?? '',
      dateLabel: _fallbackTransactionDateLabel(rawDate),
      dateGroupLabel: _fallbackTransactionDateLabel(rawDate),
      dateSort: _transactionDateSort(rawDate),
      amount: amount,
      category: categoryName,
      categoryId: _nullableString(json['category_id'] ?? json['categoryId']),
      flowType: flowType,
      icon: _categoryEmojiOrDefault(
        json['category_emoji'] ??
            json['categoryEmoji'] ??
            json['emoji'] ??
            category?['emoji'],
      ),
      color: _categoryColorOrDefault(
        json['category_bg_color'] ??
            json['categoryBgColor'] ??
            json['bg_color'] ??
            category?['bg_color'],
      ),
    );
  }

  static List<_Transaction> listFromResponse(ApiJson response) {
    final data = _unwrapData(response);
    final rawList = _asList(data);

    return rawList
        .whereType<Map>()
        .map((item) => _Transaction.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  static _Transaction fromResponse(ApiJson response) {
    final data = _unwrapData(response);
    if (data is Map) {
      return _Transaction.fromJson(Map<String, dynamic>.from(data));
    }
    return _Transaction.fromJson(response);
  }
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

class _AppShellColors {
  const _AppShellColors._();

  static const background = Color(0xFFF9FAFB);
  static const border = Color(0xFFE5E7EB);
  static const mutedText = Color(0xFF6B7280);
  static const navMuted = Color(0xFF9CA3AF);
  static const softGray = Color(0xFFE5E7EB);
  static const text = Color(0xFF111827);
}

const _categoryColors = [
  Color(0xFFFF8A65),
  AppTheme.secondaryColor,
  Color(0xFFFFB74D),
  Color(0xFF9575CD),
  Color(0xFF90A4AE),
  Color(0xFF2563EB),
];

const _defaultCategoryEmoji = '🙂';
const _defaultCategoryColor = Color(0xFFE5E7EB);

const _categoryColorChoices = [
  Color(0xFFF48FB1),
  Color(0xFFEC407A),
  Color(0xFFBA68C8),
  Color(0xFF9575CD),
  Color(0xFFFFCC80),
  Color(0xFFFFB74D),
  Color(0xFF81C784),
  Color(0xFF66BB6A),
  Color(0xFF80CBC4),
  Color(0xFF4DB6AC),
  Color(0xFF64B5F6),
  Color(0xFF42A5F5),
];

const _fieldLabelStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: _AppShellColors.text,
);

Object? _unwrapData(ApiJson response) {
  if (response.containsKey('data')) return response['data'];
  return response;
}

List<Object?> _asList(Object? data) {
  if (data is List) return data.cast<Object?>();
  if (data is Map) {
    for (final key in ['data', 'items', 'categories', 'list', 'records']) {
      final value = data[key];
      if (value is List) return value.cast<Object?>();
      if (value is Map) {
        final nestedList = _asList(value);
        if (nestedList.isNotEmpty) return nestedList;
      }
    }
  }
  return const [];
}

Map<String, dynamic>? _jsonMap(Object? value) {
  if (value is! Map) return null;
  return Map<String, dynamic>.from(value);
}

String? _nullableString(Object? value) {
  final rawValue = value is Map ? (value[r'$oid'] ?? value['oid']) : value;
  final text = rawValue?.toString().trim();
  if (text == null ||
      text.isEmpty ||
      text == 'null' ||
      text == '000000000000000000000000') {
    return null;
  }
  return text;
}

String _categoryEmojiOrDefault(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return _defaultCategoryEmoji;
  return text;
}

Color _categoryColorOrDefault(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return _defaultCategoryColor;

  final match = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(text);
  if (match == null) return _defaultCategoryColor;

  final rgb = int.parse(match.group(1)!, radix: 16);
  return Color(0xFF000000 | rgb);
}

String _languageLeadingText(AppLanguage language) {
  return switch (language) {
    AppLanguage.english => 'E',
    AppLanguage.simplifiedChinese => '\u7B80',
    AppLanguage.traditionalChinese => '\u7E41',
  };
}

String _languageNativeName(AppLanguage language) {
  return switch (language) {
    AppLanguage.english => 'English',
    AppLanguage.simplifiedChinese => '\u7B80\u4F53\u4E2D\u6587',
    AppLanguage.traditionalChinese => '\u7E41\u9AD4\u4E2D\u6587',
  };
}

String _transactionDateLabel(BuildContext context, Object? value) {
  final date = _parseTransactionDate(value);
  if (date == null) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? appT(context, 'recent') : text;
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final transactionDay = DateTime(date.year, date.month, date.day);
  final dayDelta = today.difference(transactionDay).inDays;
  if (dayDelta == 0) return appT(context, 'today');
  if (dayDelta == 1) return appT(context, 'yesterday');

  return _dateLabel(context, date);
}

String _transactionDateGroupLabel(BuildContext context, Object? value) {
  final date = _parseTransactionDate(value);
  if (date == null) return _transactionDateLabel(context, value);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final transactionDay = DateTime(date.year, date.month, date.day);
  final dayDelta = today.difference(transactionDay).inDays;
  if (dayDelta == 0) return appT(context, 'today');
  if (dayDelta == 1) return appT(context, 'yesterday');

  return _dateLabel(context, date);
}

String _fallbackTransactionDateLabel(Object? value) {
  final date = _parseTransactionDate(value);
  if (date == null) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? 'Recent' : text;
  }

  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

DateTime _transactionDateSort(Object? value) {
  return _parseTransactionDate(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _parseTransactionDate(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;

  final compact = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(text);
  final dateText = compact == null
      ? text.replaceAll('/', '-')
      : '${compact.group(1)}-${compact.group(2)}-${compact.group(3)}';
  return DateTime.tryParse(dateText);
}

int _compareTransactionsNewestFirst(_Transaction a, _Transaction b) {
  final dateCompare = b.dateSort.compareTo(a.dateSort);
  if (dateCompare != 0) return dateCompare;
  return b.id.compareTo(a.id);
}

String _dateLabel(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatShortDate(date);
}

String _shortDateLabel(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatShortDate(date);
}

String _monthYearLabel(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatMonthYear(date);
}

List<String> _localizedWeekdays(BuildContext context) {
  final localizations = MaterialLocalizations.of(context);
  final weekdays = localizations.narrowWeekdays;
  return [
    for (var index = 0; index < DateTime.daysPerWeek; index++)
      weekdays[(localizations.firstDayOfWeekIndex + index) %
          DateTime.daysPerWeek],
  ];
}

DateTime _addMonths(DateTime date, int monthOffset) {
  return DateTime(date.year, date.month + monthOffset);
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _formatEditableAmount(num value) {
  var text = value.toStringAsFixed(2);
  text = text.replaceFirst(RegExp(r'\.?0+$'), '');
  return text.isEmpty ? '0' : text;
}

String _updatedAmountText(String current, String key) {
  if (key == 'backspace') {
    return current.length > 1 ? current.substring(0, current.length - 1) : '0';
  }

  if (key == '.') {
    return current.contains('.') ? current : '$current.';
  }

  if (current == '0') return key;

  final decimalIndex = current.indexOf('.');
  if (decimalIndex != -1 && current.length - decimalIndex > 2) {
    return current;
  }

  return '$current$key';
}

String _combinedTransactionDescription(
  TextEditingController descriptionController,
  TextEditingController remarkController,
) {
  final description = descriptionController.text.trim();
  final remark = remarkController.text.trim();
  if (description.isEmpty) return remark;
  if (remark.isEmpty) return description;
  return '$description\n\n$remark';
}

(String, String) _splitTransactionDescription(String value) {
  final parts = value.split('\n\n');
  if (parts.length < 2) return (value, '');
  return (parts.first, parts.skip(1).join('\n\n'));
}

String _dateToken(DateTime date) {
  return '${date.year}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';
}

String _greeting(BuildContext context) {
  final hour = DateTime.now().hour;
  if (hour < 12) return appT(context, 'greeting_morning');
  if (hour < 18) return appT(context, 'greeting_afternoon');
  return appT(context, 'greeting_evening');
}

String _summaryBalanceKey(_SummaryRange range) {
  return switch (range) {
    _SummaryRange.day => 'day_balance',
    _SummaryRange.month => 'month_balance',
    _SummaryRange.year => 'year_balance',
    _SummaryRange.total => 'total_balance',
  };
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

String _hexColor(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

Color _themeColor(BuildContext context) {
  return Theme.of(context).colorScheme.primary;
}

double _jsonDouble(Object? value) {
  return switch (value) {
    num number => number.toDouble(),
    String text => double.tryParse(text) ?? 0,
    _ => 0,
  };
}

Map<String, double> _jsonDoubleMap(Object? value) {
  if (value is! Map) {
    return const {};
  }

  return value.map(
    (key, amount) => MapEntry(key.toString(), _jsonDouble(amount)),
  );
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
