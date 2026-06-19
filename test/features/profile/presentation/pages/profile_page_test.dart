import 'package:cashlenx/features/auth/domain/models/user.dart';
import 'package:cashlenx/features/auth/presentation/providers/auth_provider.dart';
import 'package:cashlenx/features/profile/presentation/pages/profile_page.dart';
import 'package:cashlenx/network/api_client.dart';
import 'package:cashlenx/network/cashlenx_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders demo profile without requesting the api', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(_DemoAuthNotifier.new),
          cashlenxApiProvider.overrideWithValue(_ThrowingCashlenxApi()),
        ],
        child: const MaterialApp(home: ProfilePage()),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Demo User'), findsWidgets);
    expect(find.text('demo@cashlenx.com'), findsWidgets);
    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Account Statistics'), findsOneWidget);
    expect(find.text('Log Out'), findsOneWidget);
  });
}

class _DemoAuthNotifier extends AuthNotifier {
  @override
  Future<User?> build() async {
    final now = DateTime(2026);
    return User(
      id: 'demo-user',
      username: 'Demo User',
      isActive: true,
      role: 'demo',
      createdAt: now,
      updatedAt: now,
    );
  }
}

class _ThrowingCashlenxApi extends CashlenxApi {
  _ThrowingCashlenxApi() : super(ApiClient(Dio()));

  @override
  Future<ApiJson> getUserProfile() {
    throw StateError('Demo profile must not request the API');
  }
}
