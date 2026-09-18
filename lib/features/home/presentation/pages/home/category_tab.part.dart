part of '../home_page.dart';

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
