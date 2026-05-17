import 'dart:math' as math;

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
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
            _CategoryTab(onAction: _showComingSoon),
            _AddPlaceholderTab(onAction: _showComingSoon),
            _BudgetTab(onAction: _showComingSoon),
            _SettingsTab(
              username: username,
              email: isDemo ? 'demo@cashlenx.com' : user?.username ?? '',
              onAction: _showComingSoon,
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
          _RecentActivity(
            transactions: data.recentTransactions,
            onSeeAll: onSeeAllTransactions,
          ),
          _SpendingByCategoryCard(
            categories: data.categoryBreakdown,
            onMoreStats: () => onAction('More Statistics'),
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
      final response = await ref.read(cashlenxApiProvider).listAllCategories();
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
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              mode == _CategoryEditorMode.edit
                                  ? 'Edit Category'
                                  : 'Create Category',
                              style: _sectionTitle(context),
                            ),
                          ),
                          Material(
                            color: const Color(0xFFF3F4F6),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => Navigator.pop(context),
                              child: const SizedBox(
                                width: 32,
                                height: 32,
                                child: Icon(
                                  Icons.close,
                                  color: _AppShellColors.mutedText,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
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
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                  side: const BorderSide(
                                    color: _AppShellColors.border,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: nameController.text.trim().isEmpty
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
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                  backgroundColor: AppTheme.primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  mode == _CategoryEditorMode.edit
                                      ? 'Save Changes'
                                      : 'Create',
                                ),
                              ),
                            ),
                          ],
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
        await ref
            .read(cashlenxApiProvider)
            .updateCategoryById(
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
        await ref
            .read(cashlenxApiProvider)
            .createCategory(
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
      await ref
          .read(cashlenxApiProvider)
          .updateCategoryById(
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
      await ref.read(cashlenxApiProvider).deleteCategoryById(category.id);
      if (mounted) {
        ToastUtils.showSuccess(context, 'Category deleted.');
      }
      await _loadCategories();
    } catch (error) {
      if (!mounted) return;
      ToastUtils.showServerErrors(context, error);
    }
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
                      ? const LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.secondaryColor,
                          ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(
                              alpha: 0.22,
                            ),
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

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.white,
            width: isSelected ? 4 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      clipBehavior: Clip.none,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisExtent: 60,
        mainAxisSpacing: 0,
        crossAxisSpacing: 12,
      ),
      itemCount: _categoryColorChoices.length,
      itemBuilder: (context, index) {
        final color = _categoryColorChoices[index];
        final isSelected = selectedColor == color;

        return Center(
          child: Semantics(
            button: true,
            selected: isSelected,
            label: 'Select color ${_hexColor(color)}',
            child: GestureDetector(
              onTap: () => onColorSelected(color),
              child: AnimatedScale(
                scale: isSelected ? 1.1 : 1,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? const [
                            BoxShadow(
                              color: Colors.white,
                              spreadRadius: 2,
                              blurRadius: 0,
                            ),
                            BoxShadow(
                              color: AppTheme.primaryColor,
                              spreadRadius: 6,
                              blurRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ),
        );
      },
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

class _SettingsTab extends StatefulWidget {
  const _SettingsTab({
    required this.username,
    required this.email,
    required this.onAction,
  });

  final String username;
  final String email;
  final ValueChanged<String> onAction;

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  var _themeColor = AppTheme.primaryColor;

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      title: 'Settings',
      subtitle: 'Personalize your experience',
      children: [
        _ProfileCard(
          username: widget.username,
          email: widget.email,
          onTap: () => widget.onAction('Profile'),
        ),
        _SettingsSection(
          title: 'Preferences',
          children: [
            _SettingsTile(
              icon: Icons.palette_outlined,
              color: _themeColor,
              label: 'Theme Color',
              trailing: _ColorDot(color: _themeColor),
              onTap: _showThemeColorDialog,
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
              onTap: () => widget.onAction('Privacy Settings'),
            ),
            _SettingsTile(
              icon: Icons.lock_outline,
              color: const Color(0xFF7C3AED),
              label: 'Security',
              onTap: () => widget.onAction('Security'),
            ),
            _SettingsTile(
              icon: Icons.notifications_none,
              color: const Color(0xFFF97316),
              label: 'Notifications',
              onTap: () => widget.onAction('Notifications'),
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
              onTap: () => widget.onAction('Help & Support'),
            ),
          ],
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

  void _showThemeColorDialog() {
    var draftColor = _themeColor;

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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Choose Theme Color',
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
                      'Selected: ${_hexColor(draftColor).toUpperCase()}',
                      style: const TextStyle(
                        color: _AppShellColors.mutedText,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: _categoryColorChoices.map((color) {
                        final isSelected = color == draftColor;
                        return _ColorChoice(
                          color: color,
                          isSelected: isSelected,
                          onTap: () {
                            setDialogState(() => draftColor = color);
                          },
                        );
                      }).toList(),
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
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              side: const BorderSide(
                                color: _AppShellColors.border,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              setState(() => _themeColor = draftColor);
                              Navigator.pop(context);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: draftColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
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
  var _selectedRange = _SummaryRange.total;

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
      width: 56,
      height: 56,
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
  const _DashboardApi(this._api);

  final CashlenxApi _api;

  Future<_DashboardResponse> fetchDashboard() async {
    final now = DateTime.now();
    final date = _dateToken(now);
    final month = _monthToken(now);
    final year = _yearToken(now);

    final responses = await Future.wait([
      _api.getDailySummary(date),
      _api.getMonthlySummary(month),
      _api.getYearlySummary(year),
      _api.getTotalSummary(),
      _api.listAllTransactions(limit: 5),
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
    required this.title,
    required this.dateLabel,
    required this.amount,
    required this.category,
    required this.flowType,
    required this.icon,
    required this.color,
  });

  final String title;
  final String dateLabel;
  final double amount;
  final String category;
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
    final rawAmount = _jsonDouble(json['amount'] ?? json['Amount']);
    final amount = flowType == _CashFlowType.expense
        ? -rawAmount.abs()
        : rawAmount.abs();

    return _Transaction(
      title: description ?? categoryName,
      dateLabel: _transactionDateLabel(json['belongs_date'] ?? json['date']),
      amount: amount,
      category: categoryName,
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
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return 'Recent';

  final compact = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(text);
  final dateText = compact == null
      ? text.replaceAll('/', '-')
      : '${compact.group(1)}-${compact.group(2)}-${compact.group(3)}';
  final date = DateTime.tryParse(dateText);
  if (date == null) return text;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final transactionDay = DateTime(date.year, date.month, date.day);
  final dayDelta = today.difference(transactionDay).inDays;
  if (dayDelta == 0) return 'Today';
  if (dayDelta == 1) return 'Yesterday';

  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
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
