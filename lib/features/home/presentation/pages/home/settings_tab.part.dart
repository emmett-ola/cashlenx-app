part of '../home_page.dart';

class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab({
    required this.username,
    required this.email,
    required this.avatarUrl,
    required this.onProfileTap,
  });

  final String username;
  final String email;
  final String? avatarUrl;
  final VoidCallback onProfileTap;

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final currency = ref.watch(currencyProvider);
    final language = ref.watch(i18nProvider);

    return _PageScaffold(
      title: appT(context, 'settings'),
      subtitle: appT(context, 'settings_subtitle'),
      children: [
        _ProfileCard(
          username: widget.username,
          email: widget.email,
          avatarUrl: widget.avatarUrl,
          onTap: widget.onProfileTap,
        ),
        _SettingsSection(
          title: appT(context, 'preferences'),
          children: [
            _SettingsTile(
              icon: Icons.palette_outlined,
              color: themeColor,
              label: appT(context, 'theme'),
              trailing: _ColorDot(color: themeColor),
              onTap: _showThemeColorDialog,
            ),
            _SettingsTile(
              icon: Icons.attach_money,
              color: AppTheme.successColor,
              label: appT(context, 'currency'),
              trailing: Text(
                '${currency.code} (${currency.symbol})',
                style: const TextStyle(
                  color: _AppShellColors.mutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: _showCurrencyDialog,
            ),
            _SettingsTile(
              icon: Icons.language,
              color: const Color(0xFF2563EB),
              label: appT(context, 'language'),
              trailing: Text(
                language.nativeName,
                style: const TextStyle(
                  color: _AppShellColors.mutedText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: _showLanguageDialog,
            ),
          ],
        ),
        _SettingsSection(
          title: appT(context, 'support'),
          children: [
            _SettingsTile(
              icon: Icons.help_outline,
              color: AppTheme.successColor,
              label: appT(context, 'about'),
              onTap: _showAboutDialog,
            ),
          ],
        ),
      ],
    );
  }

  void _showThemeColorDialog() {
    var draftColor = ref.read(themeColorProvider);

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 384),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppPanelHeader(
                        title: appT(context, 'choose_theme_color'),
                      ),
                      const SizedBox(height: 34),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: draftColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: draftColor.withValues(alpha: 0.24),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${appT(context, 'selected')}: ${AppTheme.hexColor(draftColor)}',
                        style: const TextStyle(
                          color: _AppShellColors.mutedText,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: Theme.of(
                            context,
                          ).colorScheme.copyWith(primary: draftColor),
                        ),
                        child: AppColorPicker(
                          colors: _categoryColorChoices,
                          selectedColor: draftColor,
                          onColorSelected: (color) {
                            setDialogState(() => draftColor = color);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '\uD83D\uDCA1',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                appT(context, 'theme_note'),
                                style: const TextStyle(
                                  color: _AppShellColors.text,
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _AppShellColors.text,
                                minimumSize: const Size.fromHeight(52),
                                side: const BorderSide(
                                  color: Color(0xFFD1D5DB),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                appT(context, 'cancel'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                await ref
                                    .read(themeColorProvider.notifier)
                                    .setColor(draftColor);
                                try {
                                  await ref.read(
                                    persistUserConfigurationProvider,
                                  )();
                                } catch (error) {
                                  if (context.mounted) {
                                    ToastUtils.showServerErrors(context, error);
                                  }
                                }
                                if (context.mounted) Navigator.pop(context);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: draftColor,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                appT(context, 'apply'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCurrencyDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        final selectedCurrency = ref.read(currencyProvider);

        return _SelectionDialog<CurrencyOption>(
          title: appT(context, 'select_currency'),
          description: appT(context, 'currency_description'),
          selectedValue: selectedCurrency,
          options: [
            for (final currency in CurrencyOption.values)
              _SelectionOption(
                value: currency,
                leadingText: currency.symbol,
                title: currency.code,
                subtitle: currency.name,
              ),
          ],
          onSelected: (currency) async {
            await ref.read(currencyProvider.notifier).setCurrency(currency);
            try {
              await ref.read(persistUserConfigurationProvider)();
            } catch (error) {
              if (context.mounted) {
                ToastUtils.showServerErrors(context, error);
              }
            }
            if (!context.mounted) return;
            Navigator.pop(context);
            ToastUtils.showSuccess(
              context,
              '${appT(context, 'currency_updated')} ${currency.code}.',
            );
          },
        );
      },
    );
  }

  void _showLanguageDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        final selectedLanguage = ref.read(i18nProvider);

        return _SelectionDialog<AppLanguage>(
          title: appT(context, 'select_language'),
          description: appT(context, 'language_description'),
          selectedValue: selectedLanguage,
          options: [
            for (final language in AppLanguage.values)
              _SelectionOption(
                value: language,
                leadingText: _languageLeadingText(language),
                title: _languageNativeName(language),
                subtitle: language.name,
              ),
          ],
          onSelected: (language) async {
            await ref.read(i18nProvider.notifier).setLanguage(language);
            try {
              await ref.read(persistUserConfigurationProvider)();
            } catch (error) {
              if (context.mounted) {
                ToastUtils.showServerErrors(context, error);
              }
            }
            if (!context.mounted) return;
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _showAboutDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        appT(context, 'about_title'),
                        style: _sectionTitle(context),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: 80,
                  height: 80,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Image.asset('assets/images/app_icon.png'),
                ),
                const SizedBox(height: 16),
                Text(
                  appT(context, 'app_name'),
                  style: const TextStyle(
                    color: _AppShellColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  appT(context, 'app_tagline'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _AppShellColors.mutedText),
                ),
                const SizedBox(height: 20),
                const _AboutVersionCard(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ToastUtils.showInfo(
                            context,
                            appT(context, 'latest_version'),
                          );
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(appT(context, 'check_update')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(appT(context, 'close')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  '© 2026 CashLenX. All rights reserved.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _AppShellColors.navMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AboutVersionCard extends ConsumerWidget {
  const _AboutVersionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfo = ref.watch(_packageInfoProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: packageInfo.when(
          loading: () => const [Center(child: CircularProgressIndicator())],
          error: (_, _) => [
            _AboutVersionRow(label: appT(context, 'version'), value: '—'),
          ],
          data: (info) => [
            _AboutVersionRow(
              label: appT(context, 'version'),
              value: info.version,
            ),
            const SizedBox(height: 10),
            _AboutVersionRow(
              label: appT(context, 'build_number'),
              value: info.buildNumber,
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutVersionRow extends StatelessWidget {
  const _AboutVersionRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _AppShellColors.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _AppShellColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppListSection(title: title, children: children);
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      icon: icon,
      color: color,
      label: label,
      onTap: onTap,
      trailing: trailing,
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.username,
    required this.email,
    required this.avatarUrl,
    required this.onTap,
  });

  final String username;
  final String email;
  final String? avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Card(
      onTap: onTap,
      child: Row(
        children: [
          _AvatarBadge(username: username, avatarUrl: avatarUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AppShellColors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _AppShellColors.mutedText),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.black38),
        ],
      ),
    );
  }
}
