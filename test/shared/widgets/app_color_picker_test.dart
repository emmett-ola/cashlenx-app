import 'package:cashlenx/shared/widgets/app_color_picker.dart';
import 'package:cashlenx/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('color picker renders swatches and reports selection', (
    tester,
  ) async {
    var selectedColor = const Color(0xFFEC407A);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(AppTheme.primaryColor),
        home: Scaffold(
          body: AppColorPicker(
            colors: const [Color(0xFFEC407A), Color(0xFF42A5F5)],
            selectedColor: selectedColor,
            onColorSelected: (color) => selectedColor = color,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Select color #EC407A'), findsOneWidget);
    expect(find.bySemanticsLabel('Select color #42A5F5'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Select color #42A5F5'));
    expect(selectedColor, const Color(0xFF42A5F5));
  });
}
