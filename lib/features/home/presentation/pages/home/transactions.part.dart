part of '../home_page.dart';

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
