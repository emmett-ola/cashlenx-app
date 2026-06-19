import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../network/cashlenx_api.dart';
import '../../../../shared/widgets/app_surface.dart';
import '../../../../theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/presentation/providers/currency_provider.dart';
import '../../domain/user_profile.dart';

const _avatarPresets = [
  Color(0xFF5FB3A9),
  Color(0xFF8B7CF6),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFFEF4444),
  Color(0xFF3B82F6),
];

const _defaultAvatarAsset =
    'assets/images/avatars/f9b59ca5421b2b7ef2e31c2ba4d827f48d22594a.png';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _birthDateController = TextEditingController();

  UserProfile? _profile;
  Object? _error;
  var _isLoading = true;
  var _isSaving = false;
  var _isEditing = false;
  var _avatarValue = '';
  late CurrencyOption _selectedCurrency;

  bool get _isDemo => ref.read(authNotifierProvider).value?.role == 'demo';

  @override
  void initState() {
    super.initState();
    _selectedCurrency = ref.read(currencyProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProfile();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(i18nProvider);
    final profile = _profile;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ProfileError(onRetry: _loadProfile)
          : profile == null
          ? _ProfileError(onRetry: _loadProfile)
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _ProfileTopSection(
                    header: _ProfileHeader(
                      title: appT(context, 'profile_title'),
                      isEditing: _isEditing,
                      isSaving: _isSaving,
                      onBack: () => context.canPop()
                          ? context.pop()
                          : context.go('/home'),
                      onEdit: () => setState(() => _isEditing = true),
                      onSave: _saveProfile,
                    ),
                    child: _AvatarCard(
                      profile: profile,
                      avatarValue: _avatarValue,
                      displayName: _nameController.text,
                      isEditing: _isEditing,
                      onAvatarTap: () => _showAvatarPicker(profile),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          children: [
                            _PersonalInformationCard(
                              profile: profile,
                              isEditing: _isEditing,
                              nameController: _nameController,
                              phoneController: _phoneController,
                              locationController: _locationController,
                              birthDateController: _birthDateController,
                              currency: _selectedCurrency,
                              onCurrencyTap: _showCurrencyPicker,
                              onBirthDateTap: _selectBirthDate,
                            ),
                            const SizedBox(height: 18),
                            _AccountStatsCard(currency: _selectedCurrency),
                            const SizedBox(height: 18),
                            OutlinedButton.icon(
                              onPressed: _isSaving
                                  ? null
                                  : () => ref
                                        .read(authNotifierProvider.notifier)
                                        .logout(),
                              icon: const Icon(Icons.logout),
                              label: Text(
                                appT(context, 'profile_logout_button'),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.errorColor,
                                minimumSize: const Size.fromHeight(52),
                                side: BorderSide(
                                  color: AppTheme.errorColor.withValues(
                                    alpha: 0.28,
                                  ),
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await ref.read(authNotifierProvider.future);
      if (user == null) {
        throw StateError('No active user session');
      }

      final profile = user.role == 'demo'
          ? UserProfile.demo(user)
          : UserProfile.fromResponse(
              await ref.read(cashlenxApiProvider).getUserProfile(),
              fallback: UserProfile.fromUser(user),
            );

      if (!mounted) return;
      _applyProfile(profile);
      setState(() {
        _profile = profile;
        _isLoading = false;
        _isEditing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
      ToastUtils.showServerErrors(context, error);
    }
  }

  Future<void> _saveProfile() async {
    final profile = _profile;
    if (profile == null || _isSaving) return;

    setState(() => _isSaving = true);
    final nickname = _nameController.text.trim();
    final avatarUrl = _avatarValue.trim();

    try {
      await ref.read(currencyProvider.notifier).setCurrency(_selectedCurrency);

      final profileDraft = profile.copyWith(
        nickname: nickname,
        avatarUrl: avatarUrl,
      );
      final updated = _isDemo
          ? profileDraft
          : UserProfile.fromResponse(
              await ref
                  .read(cashlenxApiProvider)
                  .updateUserProfile(nickname: nickname, avatarUrl: avatarUrl),
              fallback: profileDraft,
            );

      if (!mounted) return;
      _applyProfile(updated);
      setState(() {
        _profile = updated;
        _isSaving = false;
        _isEditing = false;
      });
      ToastUtils.showSuccess(context, appT(context, 'profile_saved'));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ToastUtils.showServerErrors(context, error);
    }
  }

  void _applyProfile(UserProfile profile) {
    _nameController.text = profile.displayName;
    _avatarValue = profile.avatarUrl ?? '';
    _selectedCurrency = ref.read(currencyProvider);
  }

  Future<void> _selectBirthDate() async {
    if (!_isEditing) return;

    final current = DateTime.tryParse(_birthDateController.text);
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(1995, 3, 15),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (selected == null || !mounted) return;

    setState(() {
      _birthDateController.text =
          '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
    });
  }

  void _showCurrencyPicker() {
    if (!_isEditing) return;

    var query = '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = CurrencyOption.values.where((currency) {
              final search = query.trim().toLowerCase();
              return search.isEmpty ||
                  currency.code.toLowerCase().contains(search) ||
                  currency.name.toLowerCase().contains(search);
            }).toList();

            return _ProfileModal(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppPanelHeader(
                    title: appT(context, 'profile_currency_modal_title'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      hintText: appT(
                        context,
                        'profile_currency_search_placeholder',
                      ),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (value) => setModalState(() => query = value),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final currency = filtered[index];
                        final selected = currency == _selectedCurrency;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: AppIconCircle(
                            icon: Icons.attach_money,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            currency.code,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(currency.name),
                          trailing: selected
                              ? Icon(
                                  Icons.check,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                          onTap: () {
                            setState(() => _selectedCurrency = currency);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAvatarPicker(UserProfile profile) {
    if (!_isEditing) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ProfileModal(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppPanelHeader(
                title: appT(context, 'profile_avatar_modal_title'),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: _avatarPresets.length,
                itemBuilder: (context, index) {
                  final value = 'preset:$index';
                  final selected = _avatarValue == value;
                  return _AvatarPresetButton(
                    color: _avatarPresets[index],
                    initial: _profileInitial(profile, _nameController.text),
                    selected: selected,
                    onTap: () {
                      setState(() => _avatarValue = value);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  appT(context, 'profile_avatar_tip'),
                  style: const TextStyle(color: AppSurfaceTokens.textColor),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileTopSection extends StatelessWidget {
  const _ProfileTopSection({required this.header, required this.child});

  static const _cardOverlap = 104.0;

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: _cardOverlap),
          child: header,
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 0,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.title,
    required this.isEditing,
    required this.isSaving,
    required this.onBack,
    required this.onEdit,
    required this.onSave,
  });

  final String title;
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 18,
        16,
        126,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [themeColor, AppTheme.secondaryColor],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton.filledTonal(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.20),
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall!
                          .copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: isSaving ? null : (isEditing ? onSave : onEdit),
                    icon: isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(isEditing ? Icons.save_outlined : Icons.edit),
                    label: Text(
                      isEditing
                          ? appT(context, 'profile_save_button')
                          : appT(context, 'profile_edit_button'),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: isEditing
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.20),
                      foregroundColor: isEditing ? themeColor : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
  }
}

class _AvatarCard extends StatelessWidget {
  const _AvatarCard({
    required this.profile,
    required this.avatarValue,
    required this.displayName,
    required this.isEditing,
    required this.onAvatarTap,
  });

  final UserProfile profile;
  final String avatarValue;
  final String displayName;
  final bool isEditing;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return _DesignCard(
      padding: const EdgeInsets.all(24),
      elevated: true,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _ProfileAvatar(
                profile: profile,
                avatarValue: avatarValue,
                displayName: displayName,
                size: 96,
              ),
              if (isEditing)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Material(
                    color: Theme.of(context).colorScheme.primary,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onAvatarTap,
                      child: const SizedBox(
                        width: 34,
                        height: 34,
                        child: Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              color: AppSurfaceTokens.textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.displayEmail,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppSurfaceTokens.mutedTextColor),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.profile,
    required this.avatarValue,
    required this.displayName,
    required this.size,
  });

  final UserProfile profile;
  final String avatarValue;
  final String displayName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final preset = _presetIndex(avatarValue);
    if (preset != null) {
      return _AvatarFallback(
        initial: _profileInitial(profile, displayName),
        color: _avatarPresets[preset],
        size: size,
      );
    }

    if (avatarValue.startsWith('http://') ||
        avatarValue.startsWith('https://')) {
      return ClipOval(
        child: Image.network(
          avatarValue,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _DefaultProfileAvatar(size: size);
          },
        ),
      );
    }

    if (avatarValue.startsWith('assets/')) {
      return ClipOval(
        child: Image.asset(
          avatarValue,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _DefaultProfileAvatar(size: size);
          },
        ),
      );
    }

    return _DefaultProfileAvatar(size: size);
  }
}

class _DefaultProfileAvatar extends StatelessWidget {
  const _DefaultProfileAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        _defaultAvatarAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({
    required this.initial,
    required this.color,
    required this.size,
  });

  final String initial;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.white, 0.32)!],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.34,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _PersonalInformationCard extends StatelessWidget {
  const _PersonalInformationCard({
    required this.profile,
    required this.isEditing,
    required this.nameController,
    required this.phoneController,
    required this.locationController,
    required this.birthDateController,
    required this.currency,
    required this.onCurrencyTap,
    required this.onBirthDateTap,
  });

  final UserProfile profile;
  final bool isEditing;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController locationController;
  final TextEditingController birthDateController;
  final CurrencyOption currency;
  final VoidCallback onCurrencyTap;
  final VoidCallback onBirthDateTap;

  @override
  Widget build(BuildContext context) {
    return _DesignCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appT(context, 'profile_personal_info'),
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              color: AppSurfaceTokens.textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          _ProfileField(
            label: appT(context, 'profile_full_name'),
            child: isEditing
                ? _ProfileTextField(
                    controller: nameController,
                    hintText: appT(context, 'profile_name_placeholder'),
                  )
                : _ReadOnlyValue(nameController.text),
          ),
          _ProfileField(
            label: appT(context, 'profile_email'),
            icon: Icons.mail_outline,
            child: _ReadOnlyValue(profile.displayEmail),
          ),
          _ProfileField(
            label: appT(context, 'profile_phone'),
            icon: Icons.phone_outlined,
            child: isEditing
                ? _ProfileTextField(
                    controller: phoneController,
                    hintText: appT(context, 'profile_phone_placeholder'),
                    icon: Icons.phone_outlined,
                  )
                : _ReadOnlyValue(_displayValue(context, phoneController.text)),
          ),
          _ProfileField(
            label: appT(context, 'profile_location'),
            icon: Icons.location_on_outlined,
            child: isEditing
                ? _ProfileTextField(
                    controller: locationController,
                    hintText: appT(context, 'profile_location_placeholder'),
                    icon: Icons.location_on_outlined,
                  )
                : _ReadOnlyValue(
                    _displayValue(context, locationController.text),
                  ),
          ),
          _ProfileField(
            label: appT(context, 'profile_birth_date'),
            icon: Icons.calendar_today_outlined,
            child: isEditing
                ? InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onBirthDateTap,
                    child: IgnorePointer(
                      child: _ProfileTextField(
                        controller: birthDateController,
                        hintText: 'YYYY-MM-DD',
                        icon: Icons.calendar_today_outlined,
                      ),
                    ),
                  )
                : _ReadOnlyValue(
                    _formatReadableDate(context, birthDateController.text),
                  ),
          ),
          _ProfileField(
            label: appT(context, 'profile_currency'),
            icon: Icons.attach_money,
            child: isEditing
                ? InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onCurrencyTap,
                    child: _ReadOnlyValue(
                      '${currency.name} (${currency.symbol})',
                      trailing: const Icon(
                        Icons.attach_money,
                        color: Colors.black38,
                      ),
                    ),
                  )
                : _ReadOnlyValue('${currency.name} (${currency.symbol})'),
          ),
        ],
      ),
    );
  }
}

class _AccountStatsCard extends StatelessWidget {
  const _AccountStatsCard({required this.currency});

  final CurrencyOption currency;

  @override
  Widget build(BuildContext context) {
    return _DesignCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appT(context, 'profile_account_stats'),
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              color: AppSurfaceTokens.textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.35,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _StatTile(
                value: '--',
                label: appT(context, 'profile_transactions'),
              ),
              _StatTile(
                value: '--',
                label: appT(context, 'profile_active_budgets'),
              ),
              _StatTile(
                value: '--',
                label: appT(context, 'profile_months_active'),
              ),
              _StatTile(
                value: '${currency.symbol}--',
                label: appT(context, 'profile_saved_stat'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppSurfaceTokens.mutedTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.child, this.icon});

  final String label;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppSurfaceTokens.mutedTextColor),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.hintText,
    this.icon,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
    );
  }
}

class _ReadOnlyValue extends StatelessWidget {
  const _ReadOnlyValue(this.value, {this.trailing});

  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppSurfaceTokens.softFillColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppSurfaceTokens.textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _DesignCard extends StatelessWidget {
  const _DesignCard({
    required this.child,
    required this.padding,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: elevated ? 0.12 : 0.05),
            blurRadius: elevated ? 22 : 12,
            offset: Offset(0, elevated ? 10 : 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ProfileModal extends StatelessWidget {
  const _ProfileModal({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.80,
          ),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AvatarPresetButton extends StatelessWidget {
  const _AvatarPresetButton({
    required this.color,
    required this.initial,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String initial;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? themeColor : Colors.transparent,
            width: 4,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.all(4),
              child: _AvatarFallback(initial: initial, color: color, size: 72),
            ),
            if (selected)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 30),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppTheme.errorColor,
              size: 42,
            ),
            const SizedBox(height: 12),
            const Text(
              'Profile failed to load',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 6),
            const Text(
              'Please try again.',
              style: TextStyle(color: AppSurfaceTokens.mutedTextColor),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(appT(context, 'retry')),
            ),
          ],
        ),
      ),
    );
  }
}

String _profileInitial(UserProfile profile, String displayName) {
  final text = displayName.trim().isEmpty ? profile.displayName : displayName;
  if (text.trim().isEmpty) return 'U';
  return text.trim()[0].toUpperCase();
}

int? _presetIndex(String value) {
  if (!value.startsWith('preset:')) return null;
  final index = int.tryParse(value.substring(7));
  if (index == null || index < 0 || index >= _avatarPresets.length) {
    return null;
  }
  return index;
}

String _displayValue(BuildContext context, String value) {
  final text = value.trim();
  if (text.isEmpty) return appT(context, 'profile_currency_not_set');
  return text;
}

String _formatReadableDate(BuildContext context, String value) {
  if (value.trim().isEmpty) return appT(context, 'profile_currency_not_set');
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return MaterialLocalizations.of(context).formatShortDate(date);
}
