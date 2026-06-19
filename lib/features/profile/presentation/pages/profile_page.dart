import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../network/cashlenx_api.dart';
import '../../../../shared/widgets/app_surface.dart';
import '../../../../theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_profile.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _nicknameController = TextEditingController();
  final _avatarUrlController = TextEditingController();

  UserProfile? _profile;
  Object? _error;
  var _isLoading = true;
  var _isSaving = false;
  var _isEditing = false;
  var _gender = '';

  bool get _isDemo => ref.read(authNotifierProvider).value?.role == 'demo';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProfile();
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _avatarUrlController.dispose();
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
                  child: _ProfileHeader(
                    title: appT(context, 'profile'),
                    isEditing: _isEditing,
                    isSaving: _isSaving,
                    onBack: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                    onEdit: () => setState(() => _isEditing = true),
                    onSave: _saveProfile,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  sliver: SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -46),
                      child: Column(
                        children: [
                          _AvatarCard(
                            profile: profile,
                            avatarUrl: _avatarUrlController.text,
                            isEditing: _isEditing,
                            onAvatarChanged: (value) {
                              setState(() {
                                _avatarUrlController.text = value;
                              });
                            },
                          ),
                          const SizedBox(height: 18),
                          _PersonalInformationCard(
                            profile: profile,
                            isEditing: _isEditing,
                            nicknameController: _nicknameController,
                            avatarUrlController: _avatarUrlController,
                            gender: _gender,
                            onGenderChanged: (value) {
                              setState(() => _gender = value);
                            },
                          ),
                          const SizedBox(height: 18),
                          _AccountCard(profile: profile),
                          const SizedBox(height: 18),
                          OutlinedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () => ref
                                      .read(authNotifierProvider.notifier)
                                      .logout(),
                            icon: const Icon(Icons.logout),
                            label: Text(appT(context, 'log_out')),
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
    final nickname = _nicknameController.text.trim();
    final avatarUrl = _avatarUrlController.text.trim();
    final gender = _gender.trim();

    try {
      final profileDraft = profile.copyWith(
        nickname: nickname,
        avatarUrl: avatarUrl,
        gender: gender,
      );
      final updated = _isDemo
          ? profileDraft
          : UserProfile.fromResponse(
              await ref
                  .read(cashlenxApiProvider)
                  .updateUserProfile(
                    nickname: nickname,
                    avatarUrl: avatarUrl,
                    gender: gender,
                  ),
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
    _nicknameController.text = profile.displayName;
    _avatarUrlController.text = profile.avatarUrl ?? '';
    _gender = profile.gender ?? '';
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
        78,
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
                      isEditing ? appT(context, 'save') : appT(context, 'edit'),
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
    required this.avatarUrl,
    required this.isEditing,
    required this.onAvatarChanged,
  });

  final UserProfile profile;
  final String avatarUrl;
  final bool isEditing;
  final ValueChanged<String> onAvatarChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _ProfileAvatar(profile: profile, avatarUrl: avatarUrl, size: 96),
              if (isEditing)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Material(
                    color: Theme.of(context).colorScheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _showAvatarUrlSheet(context),
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
            profile.displayName,
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

  void _showAvatarUrlSheet(BuildContext context) {
    final controller = TextEditingController(text: avatarUrl);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppPanelHeader(title: 'Avatar URL'),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Image URL',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 18),
                AppPanelActions(
                  primaryLabel: 'Apply',
                  onPrimaryPressed: () {
                    onAvatarChanged(controller.text.trim());
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(controller.dispose);
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.profile,
    required this.avatarUrl,
    required this.size,
  });

  final UserProfile profile;
  final String avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = profile.displayName.trim().isEmpty
        ? 'U'
        : profile.displayName.trim()[0].toUpperCase();

    if (avatarUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _AvatarFallback(initial: initial, size: size);
          },
        ),
      );
    }

    return _AvatarFallback(initial: initial, size: size);
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.initial, required this.size});

  final String initial;
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
          colors: [
            Theme.of(context).colorScheme.primary,
            AppTheme.secondaryColor,
          ],
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
    required this.nicknameController,
    required this.avatarUrlController,
    required this.gender,
    required this.onGenderChanged,
  });

  final UserProfile profile;
  final bool isEditing;
  final TextEditingController nicknameController;
  final TextEditingController avatarUrlController;
  final String gender;
  final ValueChanged<String> onGenderChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              color: AppSurfaceTokens.textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          _ProfileField(
            label: 'Display Name',
            icon: Icons.person_outline,
            child: isEditing
                ? TextField(
                    controller: nicknameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Enter your display name',
                    ),
                  )
                : _ReadOnlyValue(profile.displayName),
          ),
          _ProfileField(
            label: 'Email Address',
            icon: Icons.mail_outline,
            child: _ReadOnlyValue(profile.displayEmail),
          ),
          _ProfileField(
            label: 'Username',
            icon: Icons.alternate_email,
            child: _ReadOnlyValue(profile.username),
          ),
          _ProfileField(
            label: 'Gender',
            icon: Icons.badge_outlined,
            child: isEditing
                ? DropdownButtonFormField<String>(
                    initialValue: gender,
                    decoration: const InputDecoration(),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Not set')),
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'others', child: Text('Others')),
                    ],
                    onChanged: (value) => onGenderChanged(value ?? ''),
                  )
                : _ReadOnlyValue(_genderLabel(profile.gender)),
          ),
          if (isEditing)
            _ProfileField(
              label: 'Avatar URL',
              icon: Icons.link,
              child: TextField(
                controller: avatarUrlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: 'https://example.com/avatar.png',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return AppListSection(
      title: 'Account',
      children: [
        AppListTile(
          icon: Icons.verified_user_outlined,
          color: profile.isActive == false
              ? AppTheme.errorColor
              : AppTheme.successColor,
          label: 'Status',
          trailing: Text(
            profile.isActive == false ? 'Inactive' : 'Active',
            style: const TextStyle(
              color: AppSurfaceTokens.mutedTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          onTap: () {},
        ),
        AppListTile(
          icon: Icons.admin_panel_settings_outlined,
          color: Theme.of(context).colorScheme.primary,
          label: 'Role',
          trailing: Text(
            profile.role,
            style: const TextStyle(
              color: AppSurfaceTokens.mutedTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          onTap: () {},
        ),
        AppListTile(
          icon: Icons.calendar_today_outlined,
          color: const Color(0xFF2563EB),
          label: 'Member Since',
          trailing: Text(
            _formatDate(profile.createdAt),
            style: const TextStyle(
              color: AppSurfaceTokens.mutedTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          onTap: () {},
        ),
      ],
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.icon,
    required this.child,
  });

  final String label;
  final IconData icon;
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
              Icon(icon, size: 16, color: AppSurfaceTokens.mutedTextColor),
              const SizedBox(width: 6),
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

class _ReadOnlyValue extends StatelessWidget {
  const _ReadOnlyValue(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppSurfaceTokens.softFillColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: AppSurfaceTokens.textColor,
          fontWeight: FontWeight.w600,
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
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String _genderLabel(String? gender) {
  return switch (gender) {
    'male' => 'Male',
    'female' => 'Female',
    'others' => 'Others',
    _ => 'Not set',
  };
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Not set';
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
