import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

typedef ApiJson = Map<String, dynamic>;

final cashlenxApiProvider = Provider<CashlenxApi>((ref) {
  return CashlenxApi(ref.watch(apiClientProvider));
});

class CashlenxApi {
  final ApiClient _client;

  CashlenxApi(this._client);

  static const _jsonRequestTimeout = Duration(seconds: 20);

  static final Options _anonymousOptions = Options(
    extra: const {'skipAuth': true, 'skipAuthRefresh': true},
  );

  static final Options _downloadOptions = Options(
    responseType: ResponseType.bytes,
  );

  Future<ApiJson> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    _logRequest('GET', path);
    return _client
        .get<ApiJson>(
          path,
          queryParameters: _withoutNulls(queryParameters),
          options: options,
        )
        .timeout(_jsonRequestTimeout);
  }

  Future<ApiJson> _post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    _logRequest('POST', path);
    return _client
        .post<ApiJson>(
          path,
          data: data,
          queryParameters: _withoutNulls(queryParameters),
          options: options,
        )
        .timeout(_jsonRequestTimeout);
  }

  Future<ApiJson> _put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    _logRequest('PUT', path);
    return _client
        .put<ApiJson>(
          path,
          data: data,
          queryParameters: _withoutNulls(queryParameters),
        )
        .timeout(_jsonRequestTimeout);
  }

  Future<ApiJson> _delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    _logRequest('DELETE', path);
    return _client
        .delete<ApiJson>(
          path,
          data: data,
          queryParameters: _withoutNulls(queryParameters),
        )
        .timeout(_jsonRequestTimeout);
  }

  static Map<String, dynamic>? _withoutNulls(Map<String, dynamic>? source) {
    if (source == null) return null;
    final result = Map<String, dynamic>.from(source)
      ..removeWhere((_, value) => value == null);
    return result.isEmpty ? null : result;
  }

  static String _path(String value) => Uri.encodeComponent(value);

  void _logRequest(String method, String path) {
    if (kDebugMode) {
      debugPrint('[CashlenxApi] $method ${_client.baseUrl}$path');
    }
  }

  // System
  Future<ApiJson> healthCheck() {
    return _get('/open/health', options: _anonymousOptions);
  }

  Future<ApiJson> versionInfo() {
    return _get('/open/version', options: _anonymousOptions);
  }

  // Authentication
  Future<ApiJson> login({
    String? username,
    String? password,
    String? refreshToken,
  }) {
    return _post(
      '/open/auth/login',
      data: _withoutNulls({
        'username': username,
        'password': password,
        'refresh_token': refreshToken,
      }),
      options: _anonymousOptions,
    );
  }

  Future<ApiJson> register({
    required String username,
    required String password,
    required String email,
    required String verificationToken,
  }) {
    return _post(
      '/open/auth/register',
      data: {
        'username': username,
        'password': password,
        'email': email,
        'verification_token': verificationToken,
      },
      options: _anonymousOptions,
    );
  }

  Future<ApiJson> sendVerificationCode({
    required String purpose,
    required String email,
  }) {
    return _post(
      '/open/verification/code',
      data: {'purpose': purpose, 'email': email},
      options: _anonymousOptions,
    );
  }

  Future<ApiJson> verifyVerificationCode({
    required String purpose,
    required String email,
    required String code,
  }) {
    return _post(
      '/open/verification/verify',
      data: {'purpose': purpose, 'email': email, 'code': code},
      options: _anonymousOptions,
    );
  }

  Future<ApiJson> logout({String? refreshToken}) {
    return _post(
      '/open/auth/logout',
      data: _withoutNulls({'refresh_token': refreshToken}),
    );
  }

  Future<ApiJson> getTokens() {
    return _get('/auth/tokens');
  }

  Future<ApiJson> requestPasswordReset(String emailOrUsername) {
    return _post(
      '/open/auth/reset-password',
      data: {'email_or_username': emailOrUsername},
      options: _anonymousOptions,
    );
  }

  Future<ApiJson> confirmPasswordReset({
    required String token,
    required String password,
  }) {
    return _post(
      '/open/auth/reset-password/confirm',
      data: {'token': token, 'password': password},
      options: _anonymousOptions,
    );
  }

  // User
  Future<ApiJson> getUserProfile() {
    return _get('/user/profile');
  }

  Future<ApiJson> updateUserProfile({
    String? nickname,
    String? avatarUrl,
    String? gender,
  }) {
    return _put(
      '/user/profile',
      data: _withoutNulls({
        'nickname': nickname,
        'avatar_url': avatarUrl,
        'gender': gender,
      }),
    );
  }

  Future<ApiJson> changeUserPassword({
    required String oldPassword,
    required String newPassword,
  }) {
    return _put(
      '/user/password',
      data: {'old_password': oldPassword, 'new_password': newPassword},
    );
  }

  Future<ApiJson> requestEmailChange(String newEmail) {
    return _post('/user/email/change', data: {'new_email': newEmail});
  }

  Future<ApiJson> confirmEmailChange({
    required String token,
    required String password,
  }) {
    return _post(
      '/user/email/confirm',
      data: {'token': token, 'password': password},
    );
  }

  Future<ApiJson> deleteUserAccount() {
    return _delete('/user/account');
  }

  Future<List<int>> exportUserData() {
    return _client.get<List<int>>(
      '/user/database/backup',
      options: _downloadOptions,
    );
  }

  Future<ApiJson> importUserData(MultipartFile file) {
    return _post(
      '/user/database/restore',
      data: FormData.fromMap({'file': file}),
    );
  }

  // Admin
  Future<ApiJson> createUser({
    required String username,
    required String password,
    String? role,
    String? nickname,
    String? avatarUrl,
    String? emailAddress,
    String? gender,
  }) {
    return _post(
      '/admin/user',
      data: _withoutNulls({
        'username': username,
        'password': password,
        'role': role,
        'nickname': nickname,
        'avatar_url': avatarUrl,
        'email_address': emailAddress,
        'gender': gender,
      }),
    );
  }

  Future<ApiJson> listAllUsers({int? limit, int? offset}) {
    return _get(
      '/admin/user',
      queryParameters: {'limit': limit, 'offset': offset},
    );
  }

  Future<ApiJson> getUserById(String id) {
    return _get('/admin/user/${_path(id)}');
  }

  Future<ApiJson> updateUserById(
    String id, {
    String? username,
    String? password,
    bool? isActive,
    String? role,
    String? nickname,
    String? avatarUrl,
    String? emailAddress,
    String? gender,
  }) {
    return _put(
      '/admin/user/${_path(id)}',
      data: _withoutNulls({
        'username': username,
        'password': password,
        'is_active': isActive,
        'role': role,
        'nickname': nickname,
        'avatar_url': avatarUrl,
        'email_address': emailAddress,
        'gender': gender,
      }),
    );
  }

  Future<ApiJson> deleteUserById(String id) {
    return _delete('/admin/user/${_path(id)}');
  }

  Future<List<int>> dumpDatabase() {
    return _client.get<List<int>>(
      '/admin/database/backup',
      options: _downloadOptions,
    );
  }

  Future<ApiJson> restoreDatabase(MultipartFile file) {
    return _post(
      '/admin/database/restore',
      data: FormData.fromMap({'file': file}),
    );
  }

  // Cash Flow
  Future<ApiJson> createExpense({
    required String belongsDate,
    required String categoryName,
    required num amount,
    String? description,
  }) {
    return _post(
      '/cash/expense',
      data: _cashFlowData(
        belongsDate: belongsDate,
        categoryName: categoryName,
        amount: amount,
        description: description,
      ),
    );
  }

  Future<ApiJson> createIncome({
    required String belongsDate,
    required String categoryName,
    required num amount,
    String? description,
  }) {
    return _post(
      '/cash/income',
      data: _cashFlowData(
        belongsDate: belongsDate,
        categoryName: categoryName,
        amount: amount,
        description: description,
      ),
    );
  }

  Future<ApiJson> listAllTransactions({
    int? limit,
    int? offset,
    String? type,
    String? categoryId,
    String? description,
  }) {
    return _get(
      '/cash',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        'type': type,
        'category_id': categoryId,
        'description': description,
      },
    );
  }

  Future<ApiJson> getTransactionsByDateRange({
    required String from,
    required String to,
  }) {
    return _get('/cash/range', queryParameters: {'from': from, 'to': to});
  }

  Future<ApiJson> getTransactionsByDate(String date) {
    return _get('/cash/date/${_path(date)}');
  }

  Future<ApiJson> deleteTransactionsByDate(String date) {
    return _delete('/cash/date/${_path(date)}');
  }

  Future<ApiJson> getDailySummary(String date) {
    return _get('/cash/summary/daily/${_path(date)}');
  }

  Future<ApiJson> getMonthlySummary(String month) {
    return _get('/cash/summary/monthly/${_path(month)}');
  }

  Future<ApiJson> getYearlySummary(String year) {
    return _get('/cash/summary/yearly/${_path(year)}');
  }

  Future<ApiJson> getTotalSummary() {
    return _get('/cash/summary/total');
  }

  Future<ApiJson> getTransactionById(String id) {
    return _get('/cash/${_path(id)}');
  }

  Future<ApiJson> updateTransactionById(
    String id, {
    required String belongsDate,
    required String categoryName,
    required num amount,
    String? description,
  }) {
    return _put(
      '/cash/${_path(id)}',
      data: _cashFlowData(
        belongsDate: belongsDate,
        categoryName: categoryName,
        amount: amount,
        description: description,
      ),
    );
  }

  Future<ApiJson> deleteTransactionById(String id) {
    return _delete('/cash/${_path(id)}');
  }

  static ApiJson _cashFlowData({
    required String belongsDate,
    required String categoryName,
    required num amount,
    String? description,
  }) {
    return _withoutNulls({
      'belongs_date': belongsDate,
      'category_name': categoryName,
      'amount': amount,
      'description': description,
    })!;
  }

  // Category
  Future<ApiJson> createCategory({
    required String name,
    required String type,
    String? parentId,
    String? emoji,
    String? bgColor,
    String? remark,
  }) {
    return _post(
      '/category',
      data: _categoryData(
        name: name,
        type: type,
        parentId: parentId,
        emoji: emoji,
        bgColor: bgColor,
        remark: remark,
      ),
    );
  }

  Future<ApiJson> listAllCategories({
    int? limit,
    int? offset,
    String? type,
    String? parentId,
  }) {
    return _get(
      '/category',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        'type': type,
        'parent_id': parentId,
      },
    );
  }

  Future<ApiJson> getCategoryByName(String name) {
    return _get('/category/name/${_path(name)}');
  }

  Future<ApiJson> getChildCategories(String parentId) {
    return _get('/category/${_path(parentId)}/children');
  }

  Future<ApiJson> getCategoryTree({String? type, int? maxDepth}) {
    return _get(
      '/category/tree',
      queryParameters: {'type': type, 'max_depth': maxDepth},
    );
  }

  Future<ApiJson> getCategoryById(String id) {
    return _get('/category/${_path(id)}');
  }

  Future<ApiJson> updateCategoryById(
    String id, {
    required String name,
    required String type,
    String? parentId,
    String? emoji,
    String? bgColor,
    String? remark,
  }) {
    return _put(
      '/category/${_path(id)}',
      data: _categoryData(
        name: name,
        type: type,
        parentId: parentId,
        emoji: emoji,
        bgColor: bgColor,
        remark: remark,
      ),
    );
  }

  Future<ApiJson> deleteCategoryById(String id) {
    return _delete('/category/${_path(id)}');
  }

  static ApiJson _categoryData({
    required String name,
    required String type,
    String? parentId,
    String? emoji,
    String? bgColor,
    String? remark,
  }) {
    return _withoutNulls({
      'name': name,
      'type': type,
      'parent_id': parentId,
      'emoji': emoji,
      'bg_color': bgColor,
      'remark': remark,
    })!;
  }

  // Statistic
  Future<List<int>> exportStatisticData({
    required String format,
    required String from,
    required String to,
  }) {
    return _client.get<List<int>>(
      '/statistic/export',
      queryParameters: {'format': format, 'from_date': from, 'to_date': to},
      options: _downloadOptions,
    );
  }

  Future<ApiJson> importStatisticData(MultipartFile file) {
    return _post('/statistic/import', data: FormData.fromMap({'file': file}));
  }

  Future<ApiJson> getStatisticDailySummary(String date) {
    return _get('/statistic/summary/daily/${_path(date)}');
  }

  Future<ApiJson> getStatisticMonthlySummary(String month) {
    return _get('/statistic/summary/monthly/${_path(month)}');
  }

  Future<ApiJson> getStatisticYearlySummary(String year) {
    return _get('/statistic/summary/yearly/${_path(year)}');
  }

  Future<ApiJson> getStatisticDailyBreakdown(String date) {
    return _get('/statistic/breakdown/daily/${_path(date)}');
  }

  Future<ApiJson> getStatisticMonthlyBreakdown(String month) {
    return _get('/statistic/breakdown/monthly/${_path(month)}');
  }

  Future<ApiJson> getStatisticYearlyBreakdown(String year) {
    return _get('/statistic/breakdown/yearly/${_path(year)}');
  }

  Future<ApiJson> getStatisticDailyTrends(String date) {
    return _get('/statistic/trends/daily/${_path(date)}');
  }

  Future<ApiJson> getStatisticMonthlyTrends(String month) {
    return _get('/statistic/trends/monthly/${_path(month)}');
  }

  Future<ApiJson> getStatisticYearlyTrends(String year) {
    return _get('/statistic/trends/yearly/${_path(year)}');
  }

  Future<ApiJson> getStatisticDailyTop({required String date, int? limit}) {
    return _get(
      '/statistic/top/daily/${_path(date)}',
      queryParameters: {'limit': limit},
    );
  }

  Future<ApiJson> getStatisticMonthlyTop({required String month, int? limit}) {
    return _get(
      '/statistic/top/monthly/${_path(month)}',
      queryParameters: {'limit': limit},
    );
  }

  Future<ApiJson> getStatisticYearlyTop({required String year, int? limit}) {
    return _get(
      '/statistic/top/yearly/${_path(year)}',
      queryParameters: {'limit': limit},
    );
  }

  Future<ApiJson> getStatisticDashboard({
    required String period,
    required String date,
  }) {
    return _get('/statistic/dashboard/${_path(period)}/${_path(date)}');
  }

  Future<ApiJson> getIncomeExpenseChart({
    required String period,
    required String date,
  }) {
    return _get(
      '/statistic/chart/income-expense/${_path(period)}/${_path(date)}',
    );
  }

  Future<ApiJson> getCategoryDistributionChart({
    required String period,
    required String date,
    String? type,
  }) {
    return _get(
      '/statistic/chart/category-distribution/${_path(period)}/${_path(date)}',
      queryParameters: {'type': type},
    );
  }

  Future<ApiJson> getMonthlyComparisonChart(String year) {
    return _get('/statistic/chart/monthly-comparison/${_path(year)}');
  }

  Future<ApiJson> getSpendingHeatmapChart(String year) {
    return _get('/statistic/chart/spending-heatmap/${_path(year)}');
  }
}
