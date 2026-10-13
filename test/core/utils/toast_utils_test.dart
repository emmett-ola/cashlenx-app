import 'package:cashlenx/core/utils/toast_utils.dart';
import 'package:cashlenx/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('toast variants share the same visual container', (tester) async {
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    late BuildContext pageContext;

    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: messengerKey,
        theme: AppTheme.lightTheme(AppTheme.primaryColor),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              pageContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    for (final showToast in [
      () => ToastUtils.showSuccess(pageContext, 'Saved'),
      () => ToastUtils.showInfo(pageContext, 'Coming soon'),
      () => ToastUtils.showError(pageContext, 'Failed'),
    ]) {
      showToast();
      await tester.pump();

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, Colors.white);
      expect(snackBar.behavior, SnackBarBehavior.floating);
      expect(snackBar.padding, EdgeInsets.zero);
      expect(snackBar.shape, isA<RoundedRectangleBorder>());

      final shape = snackBar.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(14));

      messengerKey.currentState!.hideCurrentSnackBar();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('toast uses the dark semantic surface and foreground', (
    tester,
  ) async {
    late BuildContext pageContext;
    final darkTheme = AppTheme.darkTheme(AppTheme.primaryColor);
    final colors = darkTheme.extension<AppSurfaceColors>()!;

    await tester.pumpWidget(
      MaterialApp(
        darkTheme: darkTheme,
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              pageContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    ToastUtils.showSuccess(pageContext, 'Saved');
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, colors.surface);
    final shape = snackBar.shape! as RoundedRectangleBorder;
    expect(shape.side.color, colors.border);
    expect(tester.widget<Text>(find.text('Saved')).style?.color, colors.text);
  });
}
