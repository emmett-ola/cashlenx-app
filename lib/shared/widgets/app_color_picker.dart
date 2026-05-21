import 'package:flutter/material.dart';

enum AppColorPickerLayout { grid, wrap }

class AppColorPicker extends StatelessWidget {
  const AppColorPicker({
    super.key,
    required this.colors,
    required this.selectedColor,
    required this.onColorSelected,
    this.layout = AppColorPickerLayout.grid,
  });

  final List<Color> colors;
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;
  final AppColorPickerLayout layout;

  @override
  Widget build(BuildContext context) {
    return switch (layout) {
      AppColorPickerLayout.grid => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        clipBehavior: Clip.none,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisExtent: 60,
          mainAxisSpacing: 0,
          crossAxisSpacing: 12,
        ),
        itemCount: colors.length,
        itemBuilder: (context, index) {
          final color = colors[index];
          return Center(
            child: AppColorSwatch(
              color: color,
              isSelected: selectedColor == color,
              onTap: () => onColorSelected(color),
            ),
          );
        },
      ),
      AppColorPickerLayout.wrap => Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: colors.map((color) {
          return AppColorSwatch(
            color: color,
            isSelected: selectedColor == color,
            onTap: () => onColorSelected(color),
          );
        }).toList(),
      ),
    };
  }
}

class AppColorSwatch extends StatelessWidget {
  const AppColorSwatch({
    super.key,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedRingColor = Theme.of(context).colorScheme.primary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Select color ${_hexColor(color)}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: AnimatedScale(
          scale: isSelected ? 1.1 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: isSelected
                  ? [
                      const BoxShadow(
                        color: Colors.white,
                        spreadRadius: 2,
                        blurRadius: 0,
                      ),
                      BoxShadow(
                        color: selectedRingColor,
                        spreadRadius: 6,
                        blurRadius: 0,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}

String _hexColor(Color color) {
  final value = color.toARGB32() & 0x00FFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
