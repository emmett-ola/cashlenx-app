import 'dart:async';

import 'package:cashlenx/core/i18n/app_i18n.dart';
import 'package:cashlenx/features/auth/domain/models/user.dart';
import 'package:cashlenx/features/auth/presentation/pages/register_page.dart';
import 'package:cashlenx/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final layout in <String, Size>{
    'phone': const Size(320, 568),
    'wide': const Size(1200, 844),
  }.entries) {
    testWidgets(
      'shows the focused verification step and returns on ${layout.key}',
      (tester) async {
        SharedPreferences.setMockInitialValues({'app_language': 'en'});
        await tester.binding.setSurfaceSize(layout.value);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final notifier = _RegisterAuthNotifier();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [authNotifierProvider.overrideWith(() => notifier)],
            child: const MaterialApp(home: RegisterPage()),
          ),
        );
        await tester.pump();

        await _advanceToVerification(tester);

        expect(find.text('We sent a 6-character code to'), findsOneWidget);
        expect(find.text('person@example.test'), findsOneWidget);
        expect(find.text('Confirm'), findsOneWidget);
        expect(find.text('Return to edit email'), findsOneWidget);
        expect(find.text('Resend code in 60s'), findsOneWidget);
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Confirm'),
              )
              .onPressed,
          isNull,
        );
        expect(notifier.sentEmails, ['person@example.test']);

        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Resend code in 59s'), findsOneWidget);

        final returnAction = find.widgetWithText(
          OutlinedButton,
          'Return to edit email',
        );
        await tester.ensureVisible(returnAction);
        await tester.tap(returnAction);
        await tester.pump();

        final emailField = tester.widget<TextFormField>(
          find.byType(TextFormField),
        );
        expect(emailField.controller?.text, 'person@example.test');
        expect(find.text('Send Verification Code'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('validates and confirms an alphanumeric code', (tester) async {
    SharedPreferences.setMockInitialValues({'app_language': 'en'});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final verification = Completer<String>();
    final notifier = _RegisterAuthNotifier(verification: verification);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authNotifierProvider.overrideWith(() => notifier)],
        child: const MaterialApp(home: RegisterPage()),
      ),
    );
    await tester.pump();
    await _advanceToVerification(tester);

    final codeField = find.byType(TextFormField);
    await tester.enterText(codeField, 'A1b');
    await tester.pump();
    await tester.ensureVisible(find.text('Confirm'));
    await tester.tap(find.text('Confirm'));
    await tester.pump();

    expect(
      find.text('Enter a 6-character code using letters or numbers.'),
      findsOneWidget,
    );
    expect(notifier.verifiedCodes, isEmpty);

    await tester.enterText(codeField, 'A1b2C3');
    await tester.pump();
    await tester.tap(find.text('Confirm'));
    await tester.pump();

    expect(notifier.verifiedCodes, ['A1b2C3']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );

    verification.complete('verification-token');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Complete your profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('continues to accept a numeric verification code', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_language': 'en'});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final notifier = _RegisterAuthNotifier();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authNotifierProvider.overrideWith(() => notifier)],
        child: const MaterialApp(home: RegisterPage()),
      ),
    );
    await tester.pump();
    await _advanceToVerification(tester);

    await tester.enterText(find.byType(TextFormField), '123456');
    await tester.pump();
    await tester.ensureVisible(find.text('Confirm'));
    await tester.tap(find.text('Confirm'));
    await tester.pump();

    expect(notifier.verifiedCodes, ['123456']);
    expect(find.text('Complete your profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters non-ASCII code characters and limits input length', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_language': 'en'});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_RegisterAuthNotifier.new),
        ],
        child: const MaterialApp(home: RegisterPage()),
      ),
    );
    await tester.pump();
    await _advanceToVerification(tester);

    final codeField = find.byType(TextFormField);
    await tester.enterText(codeField, 'A1- b中2C3Z');
    await tester.pump();

    expect(tester.widget<TextFormField>(codeField).controller?.text, 'A1b2C3');
    expect(tester.takeException(), isNull);
  });

  test('localizes alphanumeric verification guidance', () {
    expect(
      const AppTranslations(AppLanguage.english)('please_enter_valid_code'),
      'Enter a 6-character code using letters or numbers.',
    );
    expect(
      const AppTranslations(AppLanguage.simplifiedChinese)(
        'please_enter_valid_code',
      ),
      '请输入由数字或英文字母组成的 6 位验证码。',
    );
    expect(
      const AppTranslations(AppLanguage.traditionalChinese)(
        'please_enter_valid_code',
      ),
      '請輸入由數字或英文字母組成的 6 位驗證碼。',
    );
  });

  test('localizes the requested verification actions', () {
    expect(
      const AppTranslations(AppLanguage.english)('verify_code_button'),
      'Confirm',
    );
    expect(
      const AppTranslations(AppLanguage.english)('back_to_email'),
      'Return to edit email',
    );
    expect(
      const AppTranslations(AppLanguage.simplifiedChinese)(
        'verify_code_button',
      ),
      '确认',
    );
    expect(
      const AppTranslations(AppLanguage.simplifiedChinese)('back_to_email'),
      '返回修改邮箱',
    );
    expect(
      const AppTranslations(AppLanguage.traditionalChinese)(
        'verify_code_button',
      ),
      '確認',
    );
    expect(
      const AppTranslations(AppLanguage.traditionalChinese)('back_to_email'),
      '返回修改電子郵件',
    );
  });
}

Future<void> _advanceToVerification(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField), 'person@example.test');
  await tester.pump();
  final sendAction = find.widgetWithText(
    ElevatedButton,
    'Send Verification Code',
  );
  await tester.ensureVisible(sendAction);
  await tester.tap(sendAction);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

class _RegisterAuthNotifier extends AuthNotifier {
  _RegisterAuthNotifier({Completer<String>? verification})
    : _verification = verification;

  final Completer<String>? _verification;
  final sentEmails = <String>[];
  final verifiedCodes = <String>[];

  @override
  Future<User?> build() async => null;

  @override
  Future<void> sendVerificationCode(String purpose, String email) async {
    expect(purpose, 'signup');
    sentEmails.add(email);
  }

  @override
  Future<String> verifyVerificationCode(
    String purpose,
    String email,
    String code,
  ) async {
    expect(purpose, 'signup');
    expect(email, 'person@example.test');
    verifiedCodes.add(code);
    return _verification?.future ?? 'verification-token';
  }
}
