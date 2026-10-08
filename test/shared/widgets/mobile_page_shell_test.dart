import 'package:cashlenx/shared/widgets/mobile_page_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const viewportSizes = <Size>[
    Size(390, 844),
    Size(430, 932),
    Size(768, 1024),
    Size(1440, 900),
  ];

  for (final viewportSize in viewportSizes) {
    testWidgets(
      'centers a full-height mobile canvas at ${viewportSize.width}px',
      (tester) async {
        await tester.binding.setSurfaceSize(viewportSize);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: MobilePageShell(child: ColoredBox(color: Colors.white)),
          ),
        );

        final canvasFinder = find.byKey(MobilePageShell.canvasKey);
        final canvasSize = tester.getSize(canvasFinder);
        final canvasOffset = tester.getTopLeft(canvasFinder);
        final expectedWidth = viewportSize.width <= MobilePageShell.maxWidth
            ? viewportSize.width
            : MobilePageShell.maxWidth;

        expect(canvasSize, Size(expectedWidth, viewportSize.height));
        expect(
          canvasOffset.dx,
          moreOrLessEquals((viewportSize.width - expectedWidth) / 2),
        );
        expect(canvasOffset.dy, 0);
      },
    );
  }

  testWidgets('uses the active theme background outside the mobile canvas', (
    tester,
  ) async {
    const background = Color(0xFF102030);
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: background),
        home: const MobilePageShell(
          child: ColoredBox(color: Color(0xFFFFFFFF)),
        ),
      ),
    );

    final viewport = tester.widget<ColoredBox>(
      find.byKey(MobilePageShell.viewportKey),
    );
    expect(viewport.color, background);
  });
}
