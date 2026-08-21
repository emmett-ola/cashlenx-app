import 'package:cashlenx/shared/widgets/custom_button.dart';
import 'package:cashlenx/shared/widgets/custom_input.dart';
import 'package:cashlenx/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared auth controls use the live design geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppTheme.primaryColor),
        home: Scaffold(
          body: Column(
            children: [
              CustomInput(label: 'Email', controller: TextEditingController()),
              const CustomButton(text: 'Continue'),
            ],
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    final enabledBorder = field.decoration?.enabledBorder as OutlineInputBorder;
    final focusedBorder = field.decoration?.focusedBorder as OutlineInputBorder;
    expect(
      enabledBorder.borderRadius,
      BorderRadius.circular(AppDesignTokens.radiusField),
    );
    expect(enabledBorder.borderSide, BorderSide.none);
    expect(
      focusedBorder.borderRadius,
      BorderRadius.circular(AppDesignTokens.radiusField),
    );
    expect(field.decoration?.fillColor, AppDesignTokens.softFill);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    final shape = button.style?.shape?.resolve({}) as RoundedRectangleBorder;
    expect(
      shape.borderRadius,
      BorderRadius.circular(AppDesignTokens.radiusControl),
    );
  });
}
