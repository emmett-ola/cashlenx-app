import 'dart:convert';

import 'package:cashlenx/core/config/app_config.dart';
import 'package:cashlenx/network/api_client.dart';
import 'package:cashlenx/network/cashlenx_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Flutter API adapter completes the beta smoke flow', (
    tester,
  ) async {
    await AppConfig.init();
    const baseUrl = String.fromEnvironment('CASHLENX_SMOKE_BASE_URL');
    const signupEmail = String.fromEnvironment('CASHLENX_SIGNUP_EMAIL');
    const signupCode = String.fromEnvironment('CASHLENX_SIGNUP_CODE');
    const resetCode = String.fromEnvironment('CASHLENX_RESET_CODE');
    const username = String.fromEnvironment('CASHLENX_SMOKE_USERNAME');
    const password = String.fromEnvironment('CASHLENX_SMOKE_PASSWORD');
    const newPassword = String.fromEnvironment('CASHLENX_SMOKE_NEW_PASSWORD');
    const adminUsername = String.fromEnvironment(
      'CASHLENX_ADMIN_USERNAME',
      defaultValue: 'admin',
    );
    const adminPassword = String.fromEnvironment(
      'CASHLENX_ADMIN_PASSWORD',
      defaultValue: 'admin',
    );

    expect(baseUrl, isNotEmpty, reason: 'CASHLENX_SMOKE_BASE_URL is required');
    expect(signupEmail, isNotEmpty);
    expect(signupCode, isNotEmpty);
    expect(resetCode, isNotEmpty);
    expect(username, isNotEmpty);
    expect(password, isNotEmpty);
    expect(newPassword, isNotEmpty);

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    final api = CashlenxApi(ApiClient(dio));

    _expectOk(await api.healthCheck());
    _expectOk(await api.versionInfo());

    final signupVerification = _data(
      await api.verifyVerificationCode(
        purpose: 'signup',
        email: signupEmail,
        code: signupCode,
      ),
    );
    final signupToken = signupVerification['token'] as String;
    _expectOk(
      await api.register(
        username: username,
        password: password,
        email: signupEmail,
        verificationToken: signupToken,
      ),
    );

    var loginData = _data(
      await api.login(username: username, password: password),
    );
    var accessToken = loginData['access_token'] as String;
    var refreshToken = loginData['refresh_token'] as String;

    final refreshed = _data(await api.login(refreshToken: refreshToken));
    accessToken = refreshed['access_token'] as String;
    refreshToken = refreshed['refresh_token'] as String;
    dio.options.headers['Authorization'] = 'Bearer $accessToken';

    _expectOk(await api.getUserProfile());
    _expectOk(
      await api.updateUserProfile(nickname: 'Flutter Smoke', gender: 'others'),
    );

    const categoryName = 'flutter-smoke-$username';
    final category = _data(
      await api.createCategory(
        name: categoryName,
        type: 'expense',
        remark: 'Flutter integration smoke',
      ),
    );
    final categoryId = (category['id'] ?? category['Id']) as String;
    _expectOk(await api.listAllCategories(type: 'expense'));
    _expectOk(await api.getCategoryById(categoryId));
    _expectOk(await api.getCategoryTree(type: 'expense'));

    _expectOk(
      await api.createExpense(
        belongsDate: '20260115',
        categoryName: categoryName,
        amount: 12.34,
        description: 'Flutter smoke expense',
      ),
    );
    _expectOk(await api.listAllTransactions(type: 'expense'));
    _expectOk(
      await api.getTransactionsByDateRange(from: '20260101', to: '20260131'),
    );
    _expectOk(await api.getDailySummary('20260115'));
    _expectOk(await api.getMonthlySummary('202601'));
    _expectOk(await api.getTotalSummary());

    _expectOk(await api.getStatisticDailySummary('20260115'));
    _expectOk(await api.getStatisticMonthlyBreakdown('202601'));
    _expectOk(await api.getStatisticMonthlyTop(month: '202601'));
    _expectOk(
      await api.getStatisticDashboard(period: 'monthly', date: '202601'),
    );

    final csv = await api.exportStatisticData(
      format: 'csv',
      from: '2026-01-01',
      to: '2026-01-31',
    );
    expect(csv, isNotEmpty);
    final workbook = await api.exportStatisticData(
      format: 'xlsx',
      from: '2026-01-01',
      to: '2026-01-31',
    );
    expect(workbook, isNotEmpty);
    _expectOk(
      await api.importStatisticData(
        MultipartFile.fromBytes(workbook, filename: 'flutter-smoke.xlsx'),
      ),
    );
    expect(await api.exportUserData(), isNotEmpty);

    _expectOk(await api.requestPasswordReset('missing-$username'));
    final resetVerification = _data(
      await api.verifyVerificationCode(
        purpose: 'password_reset',
        email: signupEmail,
        code: resetCode,
      ),
    );
    _expectOk(
      await api.confirmPasswordReset(
        token: resetVerification['token'] as String,
        password: newPassword,
      ),
    );

    loginData = _data(
      await api.login(username: username, password: newPassword),
    );
    accessToken = loginData['access_token'] as String;
    refreshToken = loginData['refresh_token'] as String;
    dio.options.headers['Authorization'] = 'Bearer $accessToken';
    _expectOk(await api.logout(refreshToken: refreshToken));
    _expectOk(await api.deleteUserAccount());

    final admin = _data(
      await api.login(username: adminUsername, password: adminPassword),
    );
    dio.options.headers['Authorization'] =
        'Bearer ${admin['access_token'] as String}';
    _expectOk(await api.listAllUsers(limit: 5, offset: 0));
    expect(await api.dumpDatabase(), isNotEmpty);

    dio.close(force: true);
    expect(utf8.decode(csv), contains('Amount'));
  });
}

Map<String, dynamic> _data(ApiJson response) {
  _expectOk(response);
  return Map<String, dynamic>.from(response['data'] as Map);
}

void _expectOk(ApiJson response) {
  expect(response['code'], 'OK', reason: jsonEncode(response));
}
