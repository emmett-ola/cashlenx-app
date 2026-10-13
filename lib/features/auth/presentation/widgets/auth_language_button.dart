import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../theme/app_theme.dart';

class AuthLanguageButton extends ConsumerWidget {
  const AuthLanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showLanguageDialog(context, ref),
        icon: const Icon(Icons.language, size: 20),
        label: Text(t('change_language')),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.primaryColor, width: 2),
          foregroundColor: AppTheme.primaryColor,
          fixedSize: const Size.fromHeight(48),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusControl),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final selectedLanguage = ref.read(i18nProvider);
    final t = ref.read(translationsProvider);

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(t('select_language')),
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  t('language_description'),
                  style: TextStyle(
                    color: context.appColors.mutedText,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...AppLanguage.values.map((language) {
                final isSelected = language == selectedLanguage;
                return ListTile(
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : context.appColors.mutedText,
                  ),
                  title: Text(language.nativeName),
                  subtitle: Text(language.name),
                  onTap: () {
                    ref.read(i18nProvider.notifier).setLanguage(language);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t('close')),
            ),
          ],
        );
      },
    );
  }
}

class AuthDivider extends ConsumerWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);

    return Row(
      children: [
        Expanded(child: Divider(color: context.appColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            t('or'),
            style: TextStyle(color: context.appColors.mutedText, fontSize: 14),
          ),
        ),
        Expanded(child: Divider(color: context.appColors.border)),
      ],
    );
  }
}

class AuthOutlinedActionButton extends StatelessWidget {
  const AuthOutlinedActionButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
  });

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (icon == null) {
      return SizedBox(
        width: double.infinity,
        child: CustomButton(
          text: text,
          isOutlined: true,
          onPressed: onPressed,
          height: 48,
          borderRadius: AppDesignTokens.radiusControl,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(text),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: context.appColors.border, width: 2),
          foregroundColor: context.appColors.text,
          fixedSize: const Size.fromHeight(48),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusControl),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
