import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/i18n/app_i18n.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_input.dart';
import '../../../../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_language_button.dart';
import '../widgets/auth_layout.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberMe();
  }

  Future<void> _loadRememberMe() async {
    final secureStorage = ref.read(secureStorageServiceProvider);
    final value = await secureStorage.getRememberMe();
    if (mounted) {
      setState(() {
        _rememberMe = value;
      });
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _identifierController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      await ref
          .read(authNotifierProvider.notifier)
          .login(
            _identifierController.text.trim(),
            _passwordController.text,
            rememberMe: _rememberMe,
          );
    }
  }

  void _handleDemoMode() {
    ref.read(authNotifierProvider.notifier).continueAsDemo();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final t = ref.watch(translationsProvider);

    // Listen for errors
    ref.listen(authNotifierProvider, (previous, next) {
      if (next.hasError) {
        ToastUtils.showServerErrors(context, next.error);
      } else if (next.hasValue &&
          next.value != null &&
          (previous?.isLoading == true || previous == null)) {
        final username = next.value?.username ?? 'User';
        ToastUtils.showSuccess(context, '${t('welcome_back')}, $username!');
      }
    });

    return AuthLayout(
      subtitle: t('auth_subtitle'),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            CustomInput(
              label: t('email_or_username'),
              controller: _identifierController,
              placeholder: t('enter_username'),
              keyboardType: TextInputType.text,
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final identifier = value?.trim() ?? '';
                if (identifier.isEmpty) {
                  return t('please_fill_all');
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            CustomInput(
              label: t('password'),
              controller: _passwordController,
              placeholder: t('enter_password'),
              obscureText: !_isPasswordVisible,
              suffixIcon: IconButton(
                tooltip: _isPasswordVisible
                    ? t('hide_password')
                    : t('show_password'),
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[500],
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return t('please_fill_all');
                }
                if (value.length < 6) {
                  return t('password_min_error');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      Tooltip(
                        message: t('remember_me_tooltip'),
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _rememberMe,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _rememberMe = !_rememberMe;
                            });
                          },
                          child: Tooltip(
                            message: t('remember_me_tooltip'),
                            child: Text(
                              t('remember_me'),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/forgot-password'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(t('forgot_password')),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: t('sign_in'),
                onPressed: _canSubmit ? _handleLogin : null,
                isLoading: isLoading,
                height: 48,
                borderRadius: 28,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${t('dont_have_account')} ',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                TextButton(
                  onPressed: () => context.go('/register'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(t('sign_up')),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const AuthDivider(),
            const SizedBox(height: 24),
            AuthOutlinedActionButton(
              text: t('continue_demo'),
              onPressed: _handleDemoMode,
            ),
            const SizedBox(height: 12),
            const AuthLanguageButton(),
          ],
        ),
      ),
    );
  }
}
