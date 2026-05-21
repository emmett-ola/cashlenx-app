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
}
