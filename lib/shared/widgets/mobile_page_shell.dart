import 'package:flutter/material.dart';

class MobilePageShell extends StatelessWidget {
  const MobilePageShell({super.key, required this.child});

  static const maxWidth = 430.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFD1D5DB),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              boxShadow: [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 28,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}
