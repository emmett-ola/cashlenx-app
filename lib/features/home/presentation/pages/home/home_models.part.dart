part of '../home_page.dart';

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
