import 'package:cashlenx/features/auth/domain/models/user.dart';
import 'package:cashlenx/features/auth/presentation/providers/auth_provider.dart';
import 'package:cashlenx/features/demo/data/demo_data_store.dart';
import 'package:cashlenx/features/profile/presentation/pages/profile_page.dart';
import 'package:cashlenx/network/api_client.dart';
import 'package:cashlenx/network/cashlenx_api.dart';
import 'package:cashlenx/shared/avatar_presets.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  testWidgets('selects and persists an image-backed avatar preset', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1200, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_DemoAuthNotifier.new),
        cashlenxApiProvider.overrideWithValue(_ThrowingCashlenxApi()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authNotifierProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ProfilePage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
    await tester.pump();
    expect(find.bySemanticsLabel('Edit avatar'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('profile-modal-surface'))).width,
      lessThanOrEqualTo(520),
    );
    expect(
      find.text('Tip: Choose an avatar that best represents you!'),
      findsNothing,
    );

    for (final assetPath in avatarPresetAssets) {
      expect(find.byKey(ValueKey('avatar-preset-$assetPath')), findsOneWidget);
    }

    final selectedAsset = avatarPresetAssets.first;
    final selectedPreset = find.byKey(ValueKey('avatar-preset-$selectedAsset'));
    await tester.ensureVisible(selectedPreset);
    await tester.tap(selectedPreset);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final response = await container.read(demoDataStoreProvider).getProfile();
    expect(
      (response['data'] as Map<String, dynamic>)['avatar_url'],
      selectedAsset,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ProfilePage(key: ValueKey('reloaded-profile')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == selectedAsset,
      ),
      findsOneWidget,
    );
  });

  test('maps legacy preset values to tracked avatar assets', () {
    expect(resolveAvatarAssetPath('preset:0'), avatarPresetAssets.first);
    expect(resolveAvatarAssetPath('preset:6'), avatarPresetAssets.last);
    expect(resolveAvatarAssetPath('preset:99'), isNull);
    expect(
      resolveAvatarAssetPath(avatarPresetAssets[2]),
      avatarPresetAssets[2],
    );
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
