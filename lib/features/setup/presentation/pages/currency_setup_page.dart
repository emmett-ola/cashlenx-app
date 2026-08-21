import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../shared/widgets/app_surface.dart';
import '../../../../theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/presentation/providers/currency_provider.dart';
import '../../data/setup_service.dart';

class CurrencySetupPage extends ConsumerStatefulWidget {
  const CurrencySetupPage({super.key, this.firstLoginSetup = false});

  final bool firstLoginSetup;

  @override
  ConsumerState<CurrencySetupPage> createState() => _CurrencySetupPageState();
}

class _CurrencySetupPageState extends ConsumerState<CurrencySetupPage> {
  final _searchController = TextEditingController();
  late CurrencyOption _selectedCurrency;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = ref.read(currencyProvider);
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(i18nProvider);
    final query = _searchController.text.trim().toLowerCase();
    final currencies = CurrencyOption.values
        .where((currency) {
          return query.isEmpty ||
              currency.code.toLowerCase().contains(query) ||
              currency.name.toLowerCase().contains(query);
        })
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AppDesignTokens.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 18),
                child: widget.firstLoginSetup
                    ? const _WelcomeHeader()
                    : _SimpleHeader(onBack: () => context.pop()),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppCard(
                  borderRadius: AppDesignTokens.radiusCard,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appT(
                          context,
                          widget.firstLoginSetup
                              ? 'setup_currency_preference'
                              : 'currency_setup_title',
                        ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        appT(
                          context,
                          widget.firstLoginSetup
                              ? 'setup_currency_description'
                              : 'currency_setup_subtitle',
                        ),
                        style: const TextStyle(color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: appT(context, 'setup_search_placeholder'),
                          filled: true,
                          fillColor: AppDesignTokens.softFill,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppDesignTokens.radiusField,
                            ),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 420),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: currencies.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final currency = currencies[index];
                            return _CurrencySetupTile(
                              currency: currency,
                              selected: currency == _selectedCurrency,
                              emphasizeSymbol: widget.firstLoginSetup,
                              onTap: () {
                                setState(() => _selectedCurrency = currency);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton(
                          onPressed: _finish,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                          ),
                          child: Text(
                            appT(
                              context,
                              widget.firstLoginSetup
                                  ? 'setup_finish_button'
                                  : 'currency_setup_continue_button',
                            ),
                          ),
                        ),
                        if (widget.firstLoginSetup) ...[
                          const SizedBox(height: 12),
                          Text(
                            appT(context, 'setup_change_settings_note'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finish() async {
    await ref.read(currencyProvider.notifier).setCurrency(_selectedCurrency);
    if (widget.firstLoginSetup) {
      final user = ref.read(authNotifierProvider).value;
      if (user != null) {
        await ref.read(setupServiceProvider).markSetupCompleted(user.id);
        ref.invalidate(setupCompletedProvider);
      }
    }
    if (!mounted) return;
    context.go('/home');
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: SvgPicture.asset(
            'assets/images/logo_teal.svg',
            key: const ValueKey('setup-official-logo'),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          appT(context, 'welcome_title'),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          appT(context, 'welcome_subtitle'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}

class _SimpleHeader extends StatelessWidget {
  const _SimpleHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onBack,
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.arrow_back,
              color: AppDesignTokens.mutedText,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrencySetupTile extends StatelessWidget {
  const _CurrencySetupTile({
    required this.currency,
    required this.selected,
    required this.emphasizeSymbol,
    required this.onTap,
  });

  final CurrencyOption currency;
  final bool selected;
  final bool emphasizeSymbol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: emphasizeSymbol
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        foregroundColor: emphasizeSymbol
            ? Colors.white
            : Theme.of(context).colorScheme.primary,
        child: Text(
          currency.symbol,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      title: Text(
        currency.code,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(currency.name),
      trailing: selected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
    );
  }
}
