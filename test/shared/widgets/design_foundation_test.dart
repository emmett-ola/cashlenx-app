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

  testWidgets('auth input keeps entered text distinct from its placeholder', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'emmett');
    addTearDown(controller.dispose);

    Future<void> pumpWithTheme(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme.brightness == Brightness.light ? theme : null,
          darkTheme: theme.brightness == Brightness.dark ? theme : null,
          themeMode: theme.brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          home: Scaffold(
            body: CustomInput(
              label: 'Username',
              placeholder: 'Enter username',
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpWithTheme(AppTheme.lightTheme(AppTheme.primaryColor));
    var field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style?.color, AppDesignTokens.text);
    expect(field.decoration?.hintStyle?.color, AppDesignTokens.mutedText);
    expect(field.style?.color, isNot(field.decoration?.hintStyle?.color));

    final darkTheme = AppTheme.darkTheme(AppTheme.primaryColor);
    await pumpWithTheme(darkTheme);
    field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style?.color, darkTheme.colorScheme.onSurface);
    expect(
      field.decoration?.hintStyle?.color,
      darkTheme.colorScheme.onSurfaceVariant,
    );
    expect(
      field.decoration?.fillColor,
      darkTheme.colorScheme.surfaceContainerHighest,
    );
  });
}
