import 'package:flutter/material.dart';

class MobilePageShell extends StatelessWidget {
  const MobilePageShell({super.key, required this.child});

  static const maxWidth = 430.0;
  static const viewportKey = ValueKey('mobile-page-shell-viewport');
  static const canvasKey = ValueKey('mobile-page-shell-canvas');

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: viewportKey,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          key: canvasKey,
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: SizedBox.expand(child: ClipRect(child: child)),
        ),
      ),
    );
  }
}
