import 'dart:math' as math;

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/response_wrapper.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../network/cashlenx_api.dart';
import '../../../../shared/widgets/app_color_picker.dart';
import '../../../../shared/widgets/app_surface.dart';
import '../../../../theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../demo/data/demo_data_store.dart';
import '../providers/currency_provider.dart';

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

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  var _selectedTab = _HomeTab.home;
  var _showTransactions = false;
  var _showMoreStats = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).value;
    final username = user?.username ?? 'User';
    final isDemo = user?.role == 'demo';

    return Scaffold(
      backgroundColor: _AppShellColors.background,
      body: SafeArea(
        bottom: false,
        child: _showTransactions
            ? _TransactionsScreen(onBack: _closeTransactions)
            : _showMoreStats
            ? _MoreStatisticsScreen(onBack: _closeMoreStats)
            : IndexedStack(
                index: _selectedTab.index,
                children: [
                  _DashboardTab(
                    username: username,
                    isDemo: isDemo,
                    onAction: _showComingSoon,
                    onProfileTap: _openProfile,
                    onSeeAllTransactions: _openTransactions,
                    onMoreStats: _openMoreStats,
                  ),
                  _CategoryTab(onAction: _showComingSoon),
                  const SizedBox.shrink(),
                  _BudgetTab(onAction: _showComingSoon),
                  _SettingsTab(
                    username: username,
                    email: isDemo ? 'demo@cashlenx.com' : user?.username ?? '',
                    onAction: _showComingSoon,
                    onProfileTap: _openProfile,
                  ),
                ],
              ),
      ),
      bottomNavigationBar: _showTransactions || _showMoreStats
          ? null
          : _BottomNav(
              selectedTab: _selectedTab,
              onSelect: (tab) {
                if (tab == _HomeTab.add) {
                  _showAddTransactionSheet();
                  return;
                }
                setState(() => _selectedTab = tab);
                if (tab == _HomeTab.home || tab == _HomeTab.budget) {
                  ref.invalidate(_dashboardProvider);
                }
              },
            ),
    );
  }

  void _showComingSoon(String feature) {
    ToastUtils.showInfo(context, '$feature coming soon!');
  }

  void _openProfile() {
    context.push('/profile');
  }

  void _openTransactions() {
    setState(() => _showTransactions = true);
  }

  void _closeTransactions() {
    setState(() => _showTransactions = false);
    ref.invalidate(_dashboardProvider);
  }

  void _openMoreStats() {
    setState(() => _showMoreStats = true);
  }

  void _closeMoreStats() {
    setState(() => _showMoreStats = false);
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
    required this.isDemo,
    required this.onAction,
    required this.onProfileTap,
    required this.onSeeAllTransactions,
    required this.onMoreStats,
  });

  final String username;
  final bool isDemo;
  final ValueChanged<String> onAction;
  final VoidCallback onProfileTap;
  final VoidCallback onSeeAllTransactions;
  final VoidCallback onMoreStats;

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
          onProfileTap: onProfileTap,
        ),
        children: [
          _SummaryCard(summary: data.summary),
          _RecentActivity(
            transactions: data.recentTransactions,
            onSeeAll: onSeeAllTransactions,
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
  const _CategoryTab({required this.onAction});

  final ValueChanged<String> onAction;

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
    _loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: 'Categories',
      subtitle: 'Manage your categories',
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
    var selectedColor = category?.color ?? AppTheme.primaryColor;
    var selectedParentId = category?.parentId;
    var showEmojiPicker = false;

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
                            ? 'Edit Category'
                            : 'Create Category',
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
                            const Text('Name', style: _fieldLabelStyle),
                            const SizedBox(height: 8),
                            TextField(
                              controller: nameController,
                              maxLength: 64,
                              onChanged: (_) => setSheetState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Enter category name',
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
                                  borderSide: const BorderSide(
                                    color: AppTheme.primaryColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text('Icon', style: _fieldLabelStyle),
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
                            const Text('Color', style: _fieldLabelStyle),
                            const SizedBox(height: 12),
                            _CategoryColorPicker(
                              selectedColor: selectedColor,
                              onColorSelected: (color) {
                                setSheetState(() => selectedColor = color);
                              },
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Parent Category (Optional)',
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
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('None (Main Category)'),
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
                            const Text(
                              'Select a parent to create a subcategory',
                              style: TextStyle(
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
                              ? 'Save Changes'
                              : 'Create',
                          onPrimaryPressed: nameController.text.trim().isEmpty
                              ? null
                              : () {
                                  final request = _CategoryEditorRequest(
                                    name: nameController.text.trim(),
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
          ToastUtils.showSuccess(context, 'Category updated.');
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
          ToastUtils.showSuccess(context, 'Category created.');
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
                        'Move Category',
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
                const Text(
                  'Moving:',
                  style: TextStyle(color: _AppShellColors.mutedText),
                ),
                const SizedBox(height: 8),
                _MoveCategoryOption(
                  icon: category.icon,
                  color: category.color,
                  title: category.name,
                  subtitle: 'Current category',
                  selected: false,
                  onTap: null,
                ),
                const SizedBox(height: 18),
                const Text('Move to:', style: _fieldLabelStyle),
                const SizedBox(height: 8),
                _MoveCategoryOption(
                  icon: '*',
                  color: AppTheme.primaryColor,
                  title: 'Main Category',
                  subtitle: 'Make it a top-level category',
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
                          '${_childrenOf(parent.id).length} subcategories',
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
                    child: const Text('Cancel'),
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
        ToastUtils.showSuccess(context, 'Category moved.');
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
          title: const Text('Delete Category?', textAlign: TextAlign.center),
          content: Text(
            'This will delete "${category.name}"'
            '${childCount > 0 ? ' and all $childCount subcategories' : ''}, '
            'This action cannot be undone.',
            textAlign: TextAlign.center,
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteCategory(category);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: const Text('Delete'),
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
        ToastUtils.showSuccess(context, 'Category deleted.');
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
                  type.label,
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
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No categories yet. Create one below!',
                  style: TextStyle(color: _AppShellColors.mutedText),
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
      title: 'Categories failed to load',
      message: 'The category request did not complete.',
      actionLabel: 'Retry',
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
                          color: AppTheme.primaryColor,
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
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: const Text('Create New Category'),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        elevation: 8,
        shadowColor: AppTheme.primaryColor.withValues(alpha: 0.28),
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
              const Expanded(
                child: Text(
                  'Tap to change emoji',
                  style: TextStyle(color: _AppShellColors.mutedText),
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
          config: const Config(
            height: 400,
            emojiViewConfig: EmojiViewConfig(
              columns: 8,
              emojiSizeMax: 28,
              backgroundColor: Colors.white,
              gridPadding: EdgeInsets.all(8),
            ),
            searchViewConfig: SearchViewConfig(
              hintText: 'Search emoji...',
              backgroundColor: Color(0xFFF3F4F6),
            ),
            categoryViewConfig: CategoryViewConfig(
              backgroundColor: Colors.white,
              indicatorColor: AppTheme.primaryColor,
              iconColorSelected: AppTheme.primaryColor,
            ),
            bottomActionBarConfig: BottomActionBarConfig(
              backgroundColor: Colors.white,
              buttonColor: AppTheme.primaryColor,
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
    return Material(
      color: selected
          ? AppTheme.primaryColor.withValues(alpha: 0.08)
          : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppTheme.primaryColor : _AppShellColors.border,
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
        title: 'Budgets',
        subtitle: 'Manage your spending limits',
        trailing: _RoundIconButton(
          icon: Icons.add,
          onPressed: () => onAction('Add budget'),
        ),
        children: [
          _TotalBudgetCard(budget: data.budget),
          Text('Category Budgets', style: _sectionTitle(context)),
          ...data.categoryBudgets.map(_CategoryBudgetTile.new),
          FilledButton.icon(
            onPressed: () => onAction('Add budget'),
            icon: const Icon(Icons.add),
            label: const Text('Add New Budget'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 8,
              shadowColor: AppTheme.primaryColor.withValues(alpha: 0.28),
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionsScreen extends ConsumerStatefulWidget {
  const _TransactionsScreen({required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<_TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<_TransactionsScreen> {
  var _selectedType = _TransactionFilterType.all;
  String? _selectedCategoryId;
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
            title: 'Transactions',
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
                onClear: _clearFilters,
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
              ? const SliverToBoxAdapter(
                  child: _EmptyStateCard(
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions found',
                    message: 'Adjust your filters or add a new transaction.',
                    actionLabel: 'Clear Filters',
                    onAction: null,
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
                        previous.dateGroupLabel != transaction.dateGroupLabel;

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
                              transaction.dateGroupLabel,
                              style: const TextStyle(
                                color: _AppShellColors.mutedText,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        _TransactionTile(transaction: transaction),
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
    setState(() {
      _selectedType = _TransactionFilterType.all;
      _selectedCategoryId = null;
      _searchController.clear();
    });
  }
}

class _MoreStatisticsScreen extends StatelessWidget {
  const _MoreStatisticsScreen({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      header: _NavigationHeader(title: 'More Statistics', onBack: onBack),
      children: const [
        _InfoCard(
          icon: Icons.info_outline,
          title: 'Test Data',
          message:
              'These comparison charts use sample data until analytics endpoints are available.',
        ),
        _WeeklyComparisonCard(),
      ],
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
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  var _type = _CategoryType.expense;
  var _date = DateTime.now();
  String? _selectedCategoryId;
  var _isLoading = true;
  var _isSaving = false;
  Object? _error;
  List<_CategoryItem> _categories = const [];

  bool get _isDemo => ref.read(authNotifierProvider).value?.role == 'demo';

  List<_CategoryItem> get _visibleCategories {
    return _categories
        .where((category) => category.type == _type)
        .toList(growable: false);
  }

  _CategoryItem? get _selectedCategory {
    for (final category in _categories) {
      if (category.id == _selectedCategoryId) return category;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
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
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: AppPanelHeader(title: 'Add Transaction'),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CategoryTypeSwitcher(
                      activeType: _type,
                      onChanged: (type) {
                        setState(() {
                          _type = type;
                          _selectedCategoryId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Amount', style: _fieldLabelStyle),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        prefixText: r'$ ',
                        hintText: '0.00',
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Category', style: _fieldLabelStyle),
                    const SizedBox(height: 10),
                    if (_isLoading)
                      const _TransactionLoadingCard()
                    else if (_error != null)
                      _TransactionErrorCard(onRetry: _loadCategories)
                    else
                      _CategoryChoiceGrid(
                        categories: _visibleCategories,
                        selectedCategoryId: _selectedCategoryId,
                        onSelected: (category) {
                          setState(() => _selectedCategoryId = category.id);
                        },
                      ),
                    const SizedBox(height: 20),
                    const Text('Date', style: _fieldLabelStyle),
                    const SizedBox(height: 8),
                    _DateSelector(
                      date: _date,
                      onDateChanged: (date) => setState(() => _date = date),
                    ),
                    const SizedBox(height: 20),
                    const Text('Note', style: _fieldLabelStyle),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Add a note',
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
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
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveTransaction,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: _isSaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Transaction'),
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
    final amount = double.tryParse(_amountController.text.trim());
    final category = _selectedCategory;
    if (amount == null || amount <= 0) {
      ToastUtils.showInfo(context, 'Enter an amount greater than zero.');
      return;
    }
    if (category == null) {
      ToastUtils.showInfo(context, 'Choose a category.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final belongsDate = _dateToken(_date);
      final description = _noteController.text.trim();
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
      ToastUtils.showSuccess(context, 'Transaction added.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ToastUtils.showServerErrors(context, error);
    }
  }
}

class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab({
    required this.username,
    required this.email,
    required this.onAction,
    required this.onProfileTap,
  });

  final String username;
  final String email;
  final ValueChanged<String> onAction;
  final VoidCallback onProfileTap;

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final currency = ref.watch(currencyProvider);

    return _PageScaffold(
      title: 'Settings',
      subtitle: 'Personalize your experience',
      children: [
        _ProfileCard(
          username: widget.username,
          email: widget.email,
          onTap: widget.onProfileTap,
        ),
        _SettingsSection(
          title: 'Preferences',
          children: [
            _SettingsTile(
              icon: Icons.palette_outlined,
              color: themeColor,
              label: 'Theme',
              trailing: _ColorDot(color: themeColor),
              onTap: _showThemeColorDialog,
            ),
            _SettingsTile(
              icon: Icons.attach_money,
              color: AppTheme.successColor,
              label: 'Currency',
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
              icon: Icons.settings_outlined,
              color: _AppShellColors.mutedText,
              label: 'More Setting',
              onTap: () => widget.onAction('More Setting'),
            ),
          ],
        ),
        _SettingsSection(
          title: 'Support',
          children: [
            _SettingsTile(
              icon: Icons.help_outline,
              color: AppTheme.successColor,
              label: 'About',
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppPanelHeader(title: 'Choose Theme Color'),
                    const SizedBox(height: 18),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: draftColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: draftColor.withValues(alpha: 0.32),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Selected: ${AppTheme.hexColor(draftColor)}',
                      style: const TextStyle(
                        color: _AppShellColors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 22),
                    AppColorPicker(
                      colors: _categoryColorChoices,
                      selectedColor: draftColor,
                      layout: AppColorPickerLayout.wrap,
                      onColorSelected: (color) {
                        setDialogState(() => draftColor = color);
                      },
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'This theme color will be used throughout the app for primary buttons, accents, and highlights.',
                        style: TextStyle(
                          color: _AppShellColors.text,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppPanelActions(
                      primaryLabel: 'Apply',
                      onPrimaryPressed: () {
                        ref
                            .read(themeColorProvider.notifier)
                            .setColor(draftColor);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCurrencyDialog() {
    var draftCurrency = ref.read(currencyProvider);

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppPanelHeader(title: 'Select Currency'),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose the currency used for balances and transaction amounts.',
                      style: TextStyle(color: _AppShellColors.mutedText),
                    ),
                    const SizedBox(height: 18),
                    ...CurrencyOption.values.map(
                      (currency) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _CurrencyOptionTile(
                          currency: currency,
                          selected: draftCurrency == currency,
                          onTap: () {
                            setDialogState(() => draftCurrency = currency);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppPanelActions(
                      primaryLabel: 'Apply',
                      onPrimaryPressed: () {
                        ref
                            .read(currencyProvider.notifier)
                            .setCurrency(draftCurrency);
                        Navigator.pop(context);
                        ToastUtils.showSuccess(
                          context,
                          'Currency updated to ${draftCurrency.code}.',
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
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
                      child: Text('About', style: _sectionTitle(context)),
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
                const Text(
                  'CashLenX',
                  style: TextStyle(
                    color: _AppShellColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your Financial Companion',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _AppShellColors.mutedText),
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
                            'You are on the latest version.',
                          );
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Check Update'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
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
    final themeColor = _themeColor(context);

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
                  _greeting(),
                  style: const TextStyle(
                    color: _AppShellColors.mutedText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (isDemo)
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Demo',
                style: TextStyle(
                  color: themeColor,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  summary.balanceLabel,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SummaryRangeSwitcher(
                selectedRange: _selectedRange,
                onChanged: (range) {
                  setState(() => _selectedRange = range);
                },
              ),
            ],
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

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.transactions, required this.onSeeAll});

  final List<_Transaction> transactions;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
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
        const SizedBox(height: 8),
        ...transactions.map(
          (transaction) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TransactionTile(transaction: transaction),
          ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final _Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.flowType == _CashFlowType.income;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
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
            Text(
              '${isIncome ? '+' : '-'}${_money(transaction.amount.abs())}',
              style: TextStyle(
                color: isIncome ? AppTheme.errorColor : AppTheme.successColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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

    return _Card(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spending by Category', style: _sectionTitle(context)),
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
              label: const Text('More Statistics Charts'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                foregroundColor: AppTheme.primaryColor,
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

class _TotalBudgetCard extends StatelessWidget {
  const _TotalBudgetCard({required this.budget});

  final _BudgetSummary budget;

  @override
  Widget build(BuildContext context) {
    final themeColor = _themeColor(context);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [themeColor, AppTheme.secondaryColor],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.18),
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
    required this.categories,
    required this.searchController,
    required this.onTypeChanged,
    required this.onCategoryChanged,
    required this.onClear,
  });

  final _TransactionFilterType selectedType;
  final String? selectedCategoryId;
  final List<_CategoryItem> categories;
  final TextEditingController searchController;
  final ValueChanged<_TransactionFilterType> onTypeChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Type', style: _fieldLabelStyle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _TransactionFilterType.values.map((type) {
              final selected = selectedType == type;
              return ChoiceChip(
                selected: selected,
                label: Text(type.label),
                onSelected: (_) => onTypeChanged(type),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Category', style: _fieldLabelStyle),
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
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All Categories'),
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
          const Text('Search', style: _fieldLabelStyle),
          const SizedBox(height: 8),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search transactions',
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
              child: const Text('Clear Filters'),
            ),
          ),
        ],
      ),
    );
  }
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
      title: 'Transactions failed to load',
      message: 'The transaction request did not complete.',
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2563EB)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1E40AF),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: Color(0xFF2563EB))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyComparisonCard extends StatelessWidget {
  const _WeeklyComparisonCard();

  static const _data = [
    ('Mon', 45.0, 32.0),
    ('Tue', 52.0, 48.0),
    ('Wed', 38.0, 55.0),
    ('Thu', 65.0, 42.0),
    ('Fri', 58.0, 68.0),
    ('Sat', 72.0, 85.0),
    ('Sun', 48.0, 52.0),
  ];

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Comparison', style: _sectionTitle(context)),
          const SizedBox(height: 18),
          SizedBox(
            height: 200,
            child: CustomPaint(
              painter: _WeeklyComparisonPainter(
                data: _data,
                themeColor: _themeColor(context),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 8,
            children: [
              const _LegendDot(color: Color(0xFFD1D5DB), label: 'Last Week'),
              _LegendDot(color: _themeColor(context), label: 'This Week'),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeeklyComparisonPainter extends CustomPainter {
  const _WeeklyComparisonPainter({
    required this.data,
    required this.themeColor,
  });

  final List<(String, double, double)> data;
  final Color themeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = data
        .expand((entry) => [entry.$2, entry.$3])
        .fold<double>(0, (maxValue, value) => math.max(maxValue, value));
    final chartHeight = size.height - 28;
    final groupWidth = size.width / data.length;
    final barWidth = math.min(14.0, groupWidth / 4);
    final lastWeekPaint = Paint()..color = const Color(0xFFD1D5DB);
    final thisWeekPaint = Paint()..color = themeColor;
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    for (final entry in data.indexed) {
      final index = entry.$1;
      final item = entry.$2;
      final x = groupWidth * index + groupWidth / 2;
      final lastHeight = maxValue == 0
          ? 0.0
          : (item.$2 / maxValue) * chartHeight;
      final thisHeight = maxValue == 0
          ? 0.0
          : (item.$3 / maxValue) * chartHeight;
      final baseY = chartHeight;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x - barWidth - 2,
            baseY - lastHeight,
            barWidth,
            lastHeight,
          ),
          const Radius.circular(6),
        ),
        lastWeekPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 2, baseY - thisHeight, barWidth, thisHeight),
          const Radius.circular(6),
        ),
        thisWeekPaint,
      );
      textPainter.text = TextSpan(
        text: item.$1,
        style: const TextStyle(color: _AppShellColors.mutedText, fontSize: 11),
      );
      textPainter.layout(minWidth: groupWidth, maxWidth: groupWidth);
      textPainter.paint(canvas, Offset(groupWidth * index, chartHeight + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyComparisonPainter oldDelegate) {
    return oldDelegate.themeColor != themeColor || oldDelegate.data != data;
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: _AppShellColors.mutedText)),
      ],
    );
  }
}

class _CategoryChoiceGrid extends StatelessWidget {
  const _CategoryChoiceGrid({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  final List<_CategoryItem> categories;
  final String? selectedCategoryId;
  final ValueChanged<_CategoryItem> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const _Card(
        child: Center(
          child: Text(
            'No categories available.',
            style: TextStyle(color: _AppShellColors.mutedText),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.86,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final selected = category.id == selectedCategoryId;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onSelected(category),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected ? _themeColor(context) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(category.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 6),
                Text(
                  category.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : _AppShellColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

class _DateSelector extends StatelessWidget {
  const _DateSelector({required this.date, required this.onDateChanged});

  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onDateChanged(picked);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 18),
            const SizedBox(width: 10),
            Text(_dateLabel(date)),
          ],
        ),
      ),
    );
  }
}

class _CurrencyOptionTile extends StatelessWidget {
  const _CurrencyOptionTile({
    required this.currency,
    required this.selected,
    required this.onTap,
  });

  final CurrencyOption currency;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? _themeColor(context).withValues(alpha: 0.08)
          : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _themeColor(context) : _AppShellColors.border,
              width: selected ? 2 : 1,
            ),
          ),
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
                    currency.symbol,
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
                      currency.code,
                      style: const TextStyle(
                        color: _AppShellColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currency.name,
                      style: const TextStyle(
                        color: _AppShellColors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: _themeColor(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutVersionCard extends StatelessWidget {
  const _AboutVersionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          _AboutVersionRow(label: 'Version', value: '1.0.0'),
          SizedBox(height: 10),
          _AboutVersionRow(label: 'Build Date', value: '2026-05-21'),
        ],
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
                        tab.label,
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
                      color: isSelected ? themeColor : _AppShellColors.navMuted,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tab.label,
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
    final themeColor = _themeColor(context);

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [themeColor, AppTheme.secondaryColor],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
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
  stats('Category', Icons.grid_view_outlined),
  add('Add', Icons.add),
  budget('Budget', Icons.account_balance_wallet_outlined),
  settings('Settings', Icons.settings_outlined);

  const _HomeTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum _CategoryType {
  expense('Expense', 'expense'),
  income('Income', 'income');

  const _CategoryType(this.label, this.apiValue);

  final String label;
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
    required this.budget,
    required this.recentTransactions,
    required this.categoryBreakdown,
    required this.categoryBudgets,
  });

  final _Summary summary;
  final _BudgetSummary budget;
  final List<_Transaction> recentTransactions;
  final List<_CategoryBreakdownItem> categoryBreakdown;
  final List<_CategoryBudget> categoryBudgets;

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
    const budget = _BudgetSummary(spent: 1215, limit: 2000);
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
      budget: budget,
      recentTransactions: recentTransactions ?? const [],
      categoryBreakdown: resolvedCategoryBreakdown,
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
  day('Day'),
  month('Month'),
  year('Year'),
  total('Total');

  const _SummaryRange(this.label);

  final String label;
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
  all('All', null, null),
  income('Income', _CashFlowType.income, _CategoryType.income),
  expense('Expense', _CashFlowType.expense, _CategoryType.expense);

  const _TransactionFilterType(this.label, this.flowType, this.categoryType);

  final String label;
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

class _BudgetSummary {
  const _BudgetSummary({required this.spent, required this.limit});

  final double spent;
  final double limit;

  double get remaining => limit - spent;

  double get percentUsed => limit == 0 ? 0 : (spent / limit) * 100;
}

class _Transaction {
  const _Transaction({
    required this.id,
    required this.title,
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
      dateLabel: _transactionDateLabel(rawDate),
      dateGroupLabel: _transactionDateGroupLabel(rawDate),
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

String _transactionDateLabel(Object? value) {
  final date = _parseTransactionDate(value);
  if (date == null) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? 'Recent' : text;
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final transactionDay = DateTime(date.year, date.month, date.day);
  final dayDelta = today.difference(transactionDay).inDays;
  if (dayDelta == 0) return 'Today';
  if (dayDelta == 1) return 'Yesterday';

  return _dateLabel(date);
}

String _transactionDateGroupLabel(Object? value) {
  final date = _parseTransactionDate(value);
  if (date == null) return _transactionDateLabel(value);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final transactionDay = DateTime(date.year, date.month, date.day);
  final dayDelta = today.difference(transactionDay).inDays;
  if (dayDelta == 0) return 'Today';
  if (dayDelta == 1) return 'Yesterday';

  return _dateLabel(date);
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

String _dateLabel(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _dateToken(DateTime date) {
  return '${date.year}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';
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
