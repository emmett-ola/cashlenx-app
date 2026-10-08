import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class CustomInput extends StatelessWidget {
  final String label;
  final String? placeholder;
  final TextEditingController? controller;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final void Function(String)? onChanged;
  final bool enabled;

  const CustomInput({
    super.key,
    required this.label,
    this.placeholder,
    this.controller,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.keyboardType,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final inputTextColor = isDark
        ? colorScheme.onSurface
        : AppDesignTokens.text;
    final hintTextColor = isDark
        ? colorScheme.onSurfaceVariant
        : AppDesignTokens.mutedText;
    final fillColor = isDark
        ? colorScheme.surfaceContainerHighest
        : AppDesignTokens.softFill;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: inputTextColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          keyboardType: keyboardType,
          onChanged: onChanged,
          enabled: enabled,
          style: TextStyle(
            color: enabled
                ? inputTextColor
                : inputTextColor.withValues(alpha: 0.38),
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(color: hintTextColor, fontSize: 16),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDesignTokens.space4,
              vertical: AppDesignTokens.space3,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusField),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusField),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusField),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusField),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: enabled ? fillColor : fillColor.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
