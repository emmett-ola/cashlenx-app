part of '../home_page.dart';

class _TransactionsScreen extends ConsumerStatefulWidget {
  const _TransactionsScreen({required this.onTransactionTap});

  final ValueChanged<_Transaction> onTransactionTap;

  @override
  ConsumerState<_TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<_TransactionsScreen> {
  static const _pageSize = 20;

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
  var _pageIndex = 0;
  var _totalCount = 0;
  var _requestSerial = 0;
  Timer? _searchDebounce;

  bool get _isDemo => ref.read(authNotifierProvider).value?.role == 'demo';

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
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _NavigationHeader(
            title: appT(context, 'transactions'),
            trailing: Stack(
              clipBehavior: Clip.none,
              children: [
                _RoundIconButton(
                  icon: Icons.filter_list,
                  tooltip: appT(context, 'filter_transactions'),
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
                onTypeChanged: _changeType,
                onCategoryChanged: _changeCategory,
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
                onTypeRemoved: _removeTypeFilter,
                onCategoryRemoved: _removeCategoryFilter,
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
                  _totalCount,
                  filtered: _activeFilterCount > 0,
                ),
                key: const ValueKey('transaction-result-summary'),
                style: TextStyle(
                  color: context.appColors.mutedText,
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
              : _transactions.isEmpty
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
                    final transaction = _transactions[index];
                    final previous = index == 0
                        ? null
                        : _transactions[index - 1];
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
                              style: TextStyle(
                                color: context.appColors.mutedText,
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
                  itemCount: _transactions.length,
                ),
        ),
        if (!_isLoading && _error == null && _totalCount > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: _TransactionPaginationControls(
                page: _pageIndex + 1,
                pageCount: _pageCount,
                onPrevious: _pageIndex > 0
                    ? () => unawaited(_goToPage(_pageIndex - 1))
                    : null,
                onNext: (_pageIndex + 1) * _pageSize < _totalCount
                    ? () => unawaited(_goToPage(_pageIndex + 1))
                    : null,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _loadData() async {
    final requestSerial = ++_requestSerial;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final responses = await Future.wait([
        _fetchTransactions(),
        _isDemo
            ? ref.read(demoDataStoreProvider).listAllCategories()
            : ref.read(cashlenxApiProvider).listAllCategories(),
      ]);
      if (!mounted || requestSerial != _requestSerial) return;
      final categories = _CategoryItem.listFromResponse(responses[1]);
      final transactions = _Transaction.listFromResponse(
        responses[0],
        categories: categories,
      )..sort(_compareTransactionsNewestFirst);
      setState(() {
        _transactions = transactions;
        _totalCount = _totalCountFromResponse(
          responses[0],
          fallback: transactions.length,
        );
        _categories = categories;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || requestSerial != _requestSerial) return;
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
      _dateFrom = null;
      _dateTo = null;
      _searchController.clear();
      _pageIndex = 0;
    });
    _searchDebounce?.cancel();
    unawaited(_reloadTransactions());
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
      _pageIndex = 0;
    });
    await _reloadTransactions();
  }

  Future<void> _removeDateFilter() async {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
      _pageIndex = 0;
    });
    await _reloadTransactions();
  }

  Future<void> _reloadTransactions() async {
    final requestSerial = ++_requestSerial;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _fetchTransactions();
      if (!mounted || requestSerial != _requestSerial) return;
      final transactions = _Transaction.listFromResponse(
        response,
        categories: _categories,
      )..sort(_compareTransactionsNewestFirst);
      setState(() {
        _transactions = transactions;
        _totalCount = _totalCountFromResponse(
          response,
          fallback: transactions.length,
        );
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || requestSerial != _requestSerial) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
      ToastUtils.showServerErrors(context, error);
    }
  }

  Future<ApiJson> _fetchTransactions() {
    final search = _searchController.text.trim();
    final type = _selectedType.flowType?.name;
    final fromDate = _dateFrom == null ? null : _dateToken(_dateFrom!);
    final toDate = _dateTo == null ? null : _dateToken(_dateTo!);
    if (_isDemo) {
      return ref
          .read(demoDataStoreProvider)
          .listAllTransactions(
            limit: _pageSize,
            offset: _pageIndex * _pageSize,
            type: type,
            categoryId: _selectedCategoryId,
            description: search.isEmpty ? null : search,
            fromDate: fromDate,
            toDate: toDate,
          );
    }
    return ref
        .read(cashlenxApiProvider)
        .listAllTransactions(
          limit: _pageSize,
          offset: _pageIndex * _pageSize,
          type: type,
          categoryId: _selectedCategoryId,
          description: search.isEmpty ? null : search,
          fromDate: fromDate,
          toDate: toDate,
        );
  }

  int get _pageCount => math.max(1, (_totalCount + _pageSize - 1) ~/ _pageSize);

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _pageIndex = 0;
      unawaited(_reloadTransactions());
    });
  }

  void _changeType(_TransactionFilterType type) {
    setState(() {
      _selectedType = type;
      _selectedCategoryId = null;
      _pageIndex = 0;
    });
    unawaited(_reloadTransactions());
  }

  void _changeCategory(String? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _pageIndex = 0;
    });
    unawaited(_reloadTransactions());
  }

  void _removeTypeFilter() => _changeType(_TransactionFilterType.all);

  void _removeCategoryFilter() => _changeCategory(null);

  Future<void> _goToPage(int pageIndex) async {
    setState(() => _pageIndex = pageIndex);
    await _reloadTransactions();
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
    final currencySymbol = ref.watch(
      currencyProvider.select((currency) => currency.symbol),
    );

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
                      currencySymbol: currencySymbol,
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
                      '${isIncome ? '+' : '-'}${formatMoney(transaction.amount.abs(), symbol: currencySymbol)}',
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
                Text(appT(context, 'type'), style: _fieldLabelStyle(context)),
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
                          fillColor: context.appColors.softFill,
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
                Text(
                  appT(context, 'category'),
                  style: _fieldLabelStyle(context),
                ),
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
                Text(appT(context, 'date'), style: _fieldLabelStyle(context)),
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
                      fillColor: context.appColors.softFill,
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
                  style: _fieldLabelStyle(context),
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
                          style: TextStyle(color: context.appColors.mutedText),
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
      final categories = _CategoryItem.listFromResponse(responses[1]);
      final transaction = _Transaction.fromResponse(
        responses[0],
        categories: categories,
      );
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
        color: context.appColors.softFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.appColors.mutedText, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: muted
                    ? context.appColors.mutedText
                    : context.appColors.text,
                fontWeight: muted ? FontWeight.w500 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTransactionPage extends ConsumerStatefulWidget {
  const _AddTransactionPage();

  @override
  ConsumerState<_AddTransactionPage> createState() =>
      _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<_AddTransactionPage> {
  var _type = _CategoryType.expense;
  String? _selectedCategoryId;
  String? _activeCategoryParentId;
  var _entryDraftGeneration = 0;
  var _isLoading = true;
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

    return typeCategories
        .where((category) => category.parentId == _activeCategoryParentId)
        .toList(growable: false);
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
  Widget build(BuildContext context) {
    final activeParent = _categoryById(_activeCategoryParentId);
    final selectedCategory = _categoryById(_selectedCategoryId);

    return PopScope<bool>(
      canPop: selectedCategory == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _hideAmountPanel();
      },
      child: Scaffold(
        key: const ValueKey('add-transaction-page'),
        backgroundColor: context.appColors.surface,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              key: const ValueKey('transaction-entry-canvas'),
              constraints: const BoxConstraints(
                maxWidth: AppDesignTokens.mobileCanvasMaxWidth,
              ),
              child: Stack(
                children: [
                  Column(
                    children: [
                      _TransactionEntryHeader(
                        activeType: _type,
                        onTypeChanged: _switchCategoryType,
                        onCancel: () => Navigator.pop(context, false),
                      ),
                      if (activeParent != null)
                        _TransactionCategoryBreadcrumb(
                          name: activeParent.name,
                          onBack: _showParentCategories,
                        ),
                      Expanded(child: _buildCategoryBody()),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      reverseDuration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) => SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, 1),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                                reverseCurve: Curves.easeInCubic,
                              ),
                            ),
                        child: child,
                      ),
                      child: selectedCategory == null
                          ? const SizedBox.shrink(
                              key: ValueKey('transaction-amount-sheet-hidden'),
                            )
                          : _TransactionAmountEntrySheet(
                              key: ValueKey(
                                'transaction-entry-draft-'
                                '$_entryDraftGeneration',
                              ),
                              category: selectedCategory,
                              onDismiss: _hideAmountPanel,
                              onCreated: _handleTransactionCreated,
                              onSubmit:
                                  ({
                                    required amount,
                                    required date,
                                    required remark,
                                  }) => _createTransaction(
                                    category: selectedCategory,
                                    amount: amount,
                                    date: date,
                                    remark: remark,
                                  ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBody() {
    if (_isLoading) return const _TransactionLoadingCard();
    if (_error != null) return _TransactionErrorCard(onRetry: _loadCategories);
    if (_visibleCategories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.category_outlined,
                size: 44,
                color: context.appColors.mutedText,
              ),
              const SizedBox(height: 12),
              Text(
                appT(context, 'no_categories_available'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.appColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                appT(context, 'transaction_choose_category_hint'),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.appColors.mutedText),
              ),
            ],
          ),
        ),
      );
    }

    final canvasWidth = math.min(
      MediaQuery.sizeOf(context).width,
      AppDesignTokens.mobileCanvasMaxWidth,
    );
    final bottomPadding = _selectedCategoryId == null
        ? 32.0
        : canvasWidth / 1.55 + 190;

    return GridView.builder(
      key: const ValueKey('transaction-category-grid'),
      padding: EdgeInsets.fromLTRB(18, 24, 18, bottomPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 20,
        crossAxisSpacing: 12,
        mainAxisExtent: 100,
      ),
      itemCount: _visibleCategories.length,
      itemBuilder: (context, index) {
        final category = _visibleCategories[index];
        final hasChildren = _hasChildren(category);
        final selected = category.id == _selectedCategoryId;
        return _TransactionCategoryTile(
          category: category,
          hasChildren: hasChildren,
          selected: selected,
          onTap: () => _handleCategorySelected(category),
        );
      },
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

  Future<bool> _createTransaction({
    required _CategoryItem category,
    required double amount,
    required DateTime date,
    required String remark,
  }) async {
    try {
      final belongsDate = _dateToken(date);
      final description = remark.trim();
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
      if (!mounted) return false;
      ToastUtils.showSuccess(context, appT(context, 'transaction_added'));
      return true;
    } catch (error) {
      if (mounted) ToastUtils.showServerErrors(context, error);
      return false;
    }
  }

  void _handleCategorySelected(_CategoryItem category) {
    if (_hasChildren(category)) {
      setState(() {
        _selectedCategoryId = null;
        _activeCategoryParentId = category.id;
        _entryDraftGeneration += 1;
      });
      return;
    }

    setState(() => _selectedCategoryId = category.id);
  }

  void _showParentCategories() {
    setState(() {
      final activeParent = _categoryById(_activeCategoryParentId);
      _activeCategoryParentId = activeParent?.parentId;
      _selectedCategoryId = null;
      _entryDraftGeneration += 1;
    });
  }

  void _switchCategoryType(_CategoryType type) {
    if (_type == type) return;
    setState(() {
      _type = type;
      _selectedCategoryId = null;
      _activeCategoryParentId = null;
      _entryDraftGeneration += 1;
    });
  }

  void _hideAmountPanel() {
    if (_selectedCategoryId == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedCategoryId = null;
      _entryDraftGeneration += 1;
    });
  }

  void _handleTransactionCreated() {
    if (mounted) Navigator.pop(context, true);
  }
}

class _TransactionEntryHeader extends StatelessWidget {
  const _TransactionEntryHeader({
    required this.activeType,
    required this.onTypeChanged,
    required this.onCancel,
  });

  final _CategoryType activeType;
  final ValueChanged<_CategoryType> onTypeChanged;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final themeColor = _themeColor(context);
    return Material(
      color: themeColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
        child: Row(
          children: [
            const SizedBox(width: 64),
            Expanded(
              child: Row(
                children: _CategoryType.values
                    .map((type) {
                      final selected = type == activeType;
                      return Expanded(
                        child: InkWell(
                          key: ValueKey('transaction-type-${type.apiValue}'),
                          onTap: () => onTypeChanged(type),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(2, 10, 2, 7),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    appT(context, type.labelKey),
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: selected
                                          ? FontWeight.w900
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: selected ? 42 : 0,
                                  height: 3,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
            SizedBox(
              width: 64,
              child: TextButton(
                onPressed: onCancel,
                child: Text(
                  appT(context, 'cancel'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionCategoryBreadcrumb extends StatelessWidget {
  const _TransactionCategoryBreadcrumb({
    required this.name,
    required this.onBack,
  });

  final String name;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.appColors.surface,
        border: Border(bottom: BorderSide(color: context.appColors.border)),
      ),
      child: TextButton.icon(
        key: const ValueKey('transaction-category-back'),
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back),
        label: Text(name),
      ),
    );
  }
}

class _TransactionCategoryTile extends StatelessWidget {
  const _TransactionCategoryTile({
    required this.category,
    required this.hasChildren,
    required this.selected,
    required this.onTap,
  });

  final _CategoryItem category;
  final bool hasChildren;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final themeColor = _themeColor(context);
    return Semantics(
      button: true,
      selected: selected,
      label: category.name,
      child: InkWell(
        key: ValueKey('transaction-category-${category.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? themeColor
                    : category.color.withValues(alpha: 0.14),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(category.icon, style: const TextStyle(fontSize: 27)),
                  if (hasChildren)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.appColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_right,
                          size: 17,
                          color: themeColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: Text(
                  category.name,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.appColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _TransactionAmountSubmit = Future<bool> Function({
  required double amount,
  required DateTime date,
  required String remark,
});

class _TransactionAmountEntrySheet extends ConsumerStatefulWidget {
  const _TransactionAmountEntrySheet({
    super.key,
    required this.category,
    required this.onDismiss,
    required this.onCreated,
    required this.onSubmit,
  });

  final _CategoryItem category;
  final VoidCallback onDismiss;
  final VoidCallback onCreated;
  final _TransactionAmountSubmit onSubmit;

  @override
  ConsumerState<_TransactionAmountEntrySheet> createState() =>
      _TransactionAmountEntrySheetState();
}

class _TransactionAmountEntrySheetState
    extends ConsumerState<_TransactionAmountEntrySheet> {
  final _calculator = TransactionAmountCalculator();
  final _remarkController = TextEditingController();
  var _date = DateTime.now();
  var _showAmountError = false;
  var _isSaving = false;
  var _dismissDragDistance = 0.0;

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final currencySymbol = ref.watch(
      currencyProvider.select((currency) => currency.symbol),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        key: const ValueKey('transaction-amount-sheet'),
        color: context.appColors.surface,
        elevation: 16,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                key: const ValueKey('transaction-amount-sheet-dismiss-handle'),
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (_) => _dismissDragDistance = 0,
                onVerticalDragUpdate: (details) {
                  _dismissDragDistance = math.max(
                    0,
                    _dismissDragDistance + details.delta.dy,
                  );
                },
                onVerticalDragEnd: (details) {
                  if (_dismissDragDistance >= 48 ||
                      (details.primaryVelocity ?? 0) > 300) {
                    widget.onDismiss();
                  }
                },
                child: SizedBox(
                  height: 24,
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.appColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.category.name,
                      style: TextStyle(
                        color: context.appColors.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$currencySymbol${_calculator.displayText}',
                      key: const ValueKey('transaction-calculator-display'),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        color: context.appColors.text,
                        fontSize: 34,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_showAmountError) ...[
                      const SizedBox(height: 6),
                      Text(
                        appT(context, 'enter_amount_gt_zero'),
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('transaction-remark-field'),
                      controller: _remarkController,
                      maxLines: 1,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.notes),
                        hintText: appT(
                          context,
                          'add_transaction_note_placeholder',
                        ),
                        filled: true,
                        fillColor: context.appColors.softFill,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _TransactionCalculatorPad(
                date: _date,
                isSaving: _isSaving,
                onKeyPressed: _handleKey,
                onDatePressed: _chooseDate,
                onComplete: _complete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleKey(String key) {
    setState(() {
      _showAmountError = false;
      switch (key) {
        case 'backspace':
          _calculator.backspace();
        case '.':
          _calculator.inputDecimalPoint();
        case '+':
          _calculator.applyOperator(TransactionAmountOperator.add);
        case '-':
          _calculator.applyOperator(TransactionAmountOperator.subtract);
        default:
          _calculator.inputDigit(key);
      }
    });
  }

  Future<void> _chooseDate() async {
    final nextDate = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (nextDate != null && mounted) setState(() => _date = nextDate);
  }

  Future<void> _complete() async {
    final amount = _calculator.result;
    if (amount <= 0) {
      setState(() => _showAmountError = true);
      return;
    }

    setState(() => _isSaving = true);
    final created = await widget.onSubmit(
      amount: amount,
      date: _date,
      remark: _remarkController.text,
    );
    if (!mounted) return;
    if (created) {
      widget.onCreated();
    } else {
      setState(() => _isSaving = false);
    }
  }
}

class _TransactionCalculatorPad extends StatelessWidget {
  const _TransactionCalculatorPad({
    required this.date,
    required this.isSaving,
    required this.onKeyPressed,
    required this.onDatePressed,
    required this.onComplete,
  });

  final DateTime date;
  final bool isSaving;
  final ValueChanged<String> onKeyPressed;
  final VoidCallback onDatePressed;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = _isSameDate(today, date);
    final keys = <_CalculatorKey>[
      for (final value in ['7', '8', '9']) _CalculatorKey.text(value),
      _CalculatorKey.action(
        label: isToday ? appT(context, 'today') : _dateLabel(context, date),
        icon: Icons.calendar_today_outlined,
        onTap: onDatePressed,
      ),
      for (final value in ['4', '5', '6', '+']) _CalculatorKey.text(value),
      for (final value in ['1', '2', '3', '-']) _CalculatorKey.text(value),
      _CalculatorKey.text('.'),
      _CalculatorKey.text('0'),
      _CalculatorKey.action(
        label: appT(context, 'delete_digit'),
        icon: Icons.backspace_outlined,
        onTap: () => onKeyPressed('backspace'),
        iconOnly: true,
      ),
      _CalculatorKey.action(
        label: appT(context, 'complete'),
        onTap: isSaving ? null : onComplete,
        emphasized: true,
        loading: isSaving,
      ),
    ];

    return GridView.builder(
      key: const ValueKey('transaction-calculator-pad'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.55,
      ),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index];
        final onTap =
            key.onTap ??
            (key.text == null ? null : () => onKeyPressed(key.text!));
        return Semantics(
          button: true,
          label: key.label ?? key.text,
          child: InkWell(
            key: key.icon == Icons.calendar_today_outlined
                ? const ValueKey('transaction-calculator-date')
                : key.text == null
                ? null
                : ValueKey('transaction-calculator-${key.text}'),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: key.emphasized
                    ? _themeColor(context)
                    : context.appColors.surface,
                border: Border(
                  top: BorderSide(color: context.appColors.border),
                  left: BorderSide(color: context.appColors.border),
                ),
              ),
              child: Center(
                child: key.loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : key.icon == null
                    ? Text(
                        key.label ?? key.text!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: key.emphasized
                              ? Colors.white
                              : context.appColors.text,
                          fontSize: key.emphasized ? 17 : 24,
                          fontWeight: key.emphasized
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            key.icon,
                            color: context.appColors.text,
                            size: 21,
                          ),
                          if (!key.iconOnly) ...[
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                key.label!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.appColors.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CalculatorKey {
  const _CalculatorKey._({
    this.text,
    this.label,
    this.icon,
    this.onTap,
    this.emphasized = false,
    this.iconOnly = false,
    this.loading = false,
  });

  factory _CalculatorKey.text(String value) => _CalculatorKey._(text: value);

  factory _CalculatorKey.action({
    required String label,
    IconData? icon,
    VoidCallback? onTap,
    bool emphasized = false,
    bool iconOnly = false,
    bool loading = false,
  }) => _CalculatorKey._(
    label: label,
    icon: icon,
    onTap: onTap,
    emphasized: emphasized,
    iconOnly: iconOnly,
    loading: loading,
  );

  final String? text;
  final String? label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool emphasized;
  final bool iconOnly;
  final bool loading;
}

class _TransactionAmountDisplay extends StatelessWidget {
  const _TransactionAmountDisplay({
    required this.amountText,
    required this.currencySymbol,
    required this.amountColor,
    required this.expanded,
    required this.onToggleExpanded,
    this.prefix = '',
    this.errorText,
    this.shakeTrigger = 0,
  });

  final String amountText;
  final String currencySymbol;
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
                    '$prefix$currencySymbol$amountText',
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

class _AddTransactionFieldLabel extends StatelessWidget {
  const _AddTransactionFieldLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.appColors.mutedText),
        const SizedBox(width: 5),
        Text(text, style: _fieldLabelStyle(context)),
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
      color: context.appColors.surface,
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
              Tooltip(
                message: key == 'backspace'
                    ? appT(context, 'delete_digit')
                    : key,
                excludeFromSemantics: true,
                child: Semantics(
                  container: true,
                  label: key == 'backspace'
                      ? appT(context, 'delete_digit')
                      : key,
                  button: true,
                  onTap: () => onKeyPressed(key),
                  excludeSemantics: true,
                  child: Material(
                    color: context.appColors.softFill,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onKeyPressed(key),
                      child: Center(
                        child: key == 'backspace'
                            ? Icon(
                                Icons.backspace_outlined,
                                color: context.appColors.mutedText,
                              )
                            : Text(
                                key,
                                style: TextStyle(
                                  color: context.appColors.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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
  const _NavigationHeader({required this.title, this.onBack, this.trailing});

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        border: Border(bottom: BorderSide(color: context.appColors.border)),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            Tooltip(
              message: appT(context, 'back'),
              excludeFromSemantics: true,
              child: Semantics(
                container: true,
                label: appT(context, 'back'),
                button: true,
                onTap: onBack,
                excludeSemantics: true,
                child: IconButton.filledTonal(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
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
          Text(appT(context, 'type'), style: _fieldLabelStyle(context)),
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
                backgroundColor: context.appColors.softFill,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : context.appColors.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(appT(context, 'category'), style: _fieldLabelStyle(context)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: selectedCategoryId,
            decoration: InputDecoration(
              filled: true,
              fillColor: context.appColors.softFill,
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
          Text(appT(context, 'date_range'), style: _fieldLabelStyle(context)),
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
          Text(appT(context, 'search'), style: _fieldLabelStyle(context)),
          const SizedBox(height: 8),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: appT(context, 'search_transactions'),
              filled: true,
              fillColor: context.appColors.softFill,
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
        foregroundColor: context.appColors.text,
        backgroundColor: context.appColors.softFill,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        side: BorderSide(color: context.appColors.border),
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
      backgroundColor: context.appColors.surface,
      side: BorderSide(color: context.appColors.border),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        color: context.appColors.text,
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

int _totalCountFromResponse(ApiJson response, {required int fallback}) {
  final meta = _jsonMap(response['meta']);
  final value = meta?['total_count'] ?? meta?['totalCount'];
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

class _TransactionPaginationControls extends StatelessWidget {
  const _TransactionPaginationControls({
    required this.page,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('transactions-previous-page'),
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            label: Text(appT(context, 'previous')),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$page / $pageCount',
          key: const ValueKey('transaction-page-status'),
          style: TextStyle(
            color: context.appColors.mutedText,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('transactions-next-page'),
            onPressed: onNext,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right),
            label: Text(appT(context, 'next')),
          ),
        ),
      ],
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
      duration: AppMotion.feedbackDuration,
    );
  }

  @override
  void didUpdateWidget(covariant _ValidationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorText != null &&
        widget.shakeTrigger != oldWidget.shakeTrigger) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.stop();
        _controller.value = 0;
      } else {
        _controller.forward(from: 0);
      }
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final field = Container(
      key: const ValueKey('validation-feedback'),
      width: double.infinity,
      padding: hasError ? const EdgeInsets.all(8) : EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: hasError ? Border.all(color: errorColor, width: 2) : null,
      ),
      child: widget.child,
    );

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
        if (reduceMotion)
          field
        else
          AnimatedBuilder(
            animation: _controller,
            child: field,
            builder: (context, child) {
              final progress = _controller.value;
              final offset =
                  math.sin(progress * math.pi * 6) * 5 * (1 - progress);
              return Transform.translate(
                key: const ValueKey('validation-shake'),
                offset: Offset(offset, 0),
                child: child,
              );
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
            style: TextStyle(color: context.appColors.mutedText),
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
                        : context.appColors.softFill,
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
                                : context.appColors.mutedText,
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
                                        : context.appColors.text,
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
              style: TextStyle(
                color: context.appColors.mutedText,
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
              color: context.appColors.softFill,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _shortDateLabel(context, widget.date),
                    style: TextStyle(
                      color: context.appColors.text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: context.appColors.mutedText,
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
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appColors.border),
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
                  style: TextStyle(
                    color: context.appColors.text,
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
                    style: TextStyle(
                      color: context.appColors.mutedText,
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
          Divider(height: 1, color: context.appColors.border),
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
                foregroundColor: context.appColors.text,
                backgroundColor: context.appColors.softFill,
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
      color: context.appColors.text,
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
                color: isSelected ? Colors.white : context.appColors.text,
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
      backgroundColor: context.appColors.surface,
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
                style: TextStyle(
                  color: context.appColors.mutedText,
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
                    foregroundColor: context.appColors.text,
                    side: BorderSide(
                      color: context.appColors.border,
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
      color: selected ? context.appColors.softFill : context.appColors.surface,
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
                      style: TextStyle(
                        color: context.appColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: TextStyle(
                        color: context.appColors.mutedText,
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
