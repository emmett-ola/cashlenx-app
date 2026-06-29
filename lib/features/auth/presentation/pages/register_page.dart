import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_i18n.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_input.dart';
import '../../../../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_language_button.dart';
import '../widgets/auth_layout.dart';

enum _RegisterStep { email, verify, complete }

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _emailFormKey = GlobalKey<FormState>();
  final _verifyFormKey = GlobalKey<FormState>();
  final _completeFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  var _step = _RegisterStep.email;
  var _isSendingCode = false;
  var _isVerifying = false;
  var _isRegistering = false;
  var _resendCountdown = 0;
  var _isPasswordVisible = false;
  var _isConfirmPasswordVisible = false;
  String? _verificationToken;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _verificationCodeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _canSendCode => _emailController.text.trim().isNotEmpty;

  bool get _canVerify => _verificationCodeController.text.trim().isNotEmpty;

  bool get _canComplete =>
      _usernameController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _confirmPasswordController.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    return AuthLayout(
      subtitle: switch (_step) {
        _RegisterStep.email => t('create_account'),
        _RegisterStep.verify => t('verify_email'),
        _RegisterStep.complete => t('complete_profile'),
      },
      onBack: () => context.go('/login'),
      child: switch (_step) {
        _RegisterStep.email => _buildEmailStep(),
        _RegisterStep.verify => _buildVerifyStep(),
        _RegisterStep.complete => _buildCompleteStep(),
      },
    );
  }

  Widget _buildEmailStep() {
    final t = ref.watch(translationsProvider);

    return Column(
      children: [
        Form(
          key: _emailFormKey,
          child: Column(
            children: [
              CustomInput(
                label: '${t('email')} *',
                controller: _emailController,
                placeholder: 'email@example.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icon(Icons.mail_outline, color: Colors.grey[500]),
                onChanged: (_) => setState(() {}),
                validator: _validateEmail,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: t('send_verification_code'),
                  onPressed: _canSendCode ? _sendVerificationCode : null,
                  isLoading: _isSendingCode,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SignInPrompt(onPressed: () => context.go('/login')),
        const SizedBox(height: 24),
        const AuthDivider(),
        const SizedBox(height: 24),
        const AuthLanguageButton(),
      ],
    );
  }

  Widget _buildVerifyStep() {
    final t = ref.watch(translationsProvider);

    return Column(
      children: [
        Form(
          key: _verifyFormKey,
          child: Column(
            children: [
              CustomInput(
                label: t('email'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icon(Icons.mail_outline, color: Colors.grey[500]),
                enabled: false,
              ),
              const SizedBox(height: 20),
              CustomInput(
                label: '${t('verification_code')} *',
                controller: _verificationCodeController,
                placeholder: t('enter_code'),
                keyboardType: TextInputType.number,
                prefixIcon: Icon(Icons.error_outline, color: Colors.grey[500]),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return t('please_enter_code');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _resendCountdown > 0 ? null : _resendCode,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _resendCountdown > 0
                        ? '${t('resend_in')} ${_resendCountdown}s'
                        : t('resend_code'),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: _isVerifying ? t('verifying') : t('verify_code_button'),
                  onPressed: _canVerify ? _verifyCode : null,
                  isLoading: _isVerifying,
                ),
              ),
              const SizedBox(height: 12),
              AuthOutlinedActionButton(
                text: t('back_to_email'),
                icon: Icons.arrow_back,
                onPressed: _backToEmail,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SignInPrompt(onPressed: () => context.go('/login')),
        const SizedBox(height: 24),
        const AuthDivider(),
        const SizedBox(height: 24),
        const AuthLanguageButton(),
      ],
    );
  }

  Widget _buildCompleteStep() {
    final t = ref.watch(translationsProvider);

    return Column(
      children: [
        Form(
          key: _completeFormKey,
          child: Column(
            children: [
              CustomInput(
                label: '${t('username')} *',
                controller: _usernameController,
                placeholder: t('choose_username'),
                prefixIcon: Icon(Icons.person_outline, color: Colors.grey[500]),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return t('please_fill_required');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              CustomInput(
                label: '${t('password')} *',
                controller: _passwordController,
                placeholder: t('password_min_chars'),
                obscureText: !_isPasswordVisible,
                prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[500]),
                suffixIcon: IconButton(
                  tooltip: _isPasswordVisible
                      ? t('hide_password')
                      : t('show_password'),
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.grey[500],
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                onChanged: (_) => setState(() {}),
                validator: _validatePassword,
              ),
              const SizedBox(height: 20),
              CustomInput(
                label: '${t('confirm_password')} *',
                controller: _confirmPasswordController,
                placeholder: t('reenter_password'),
                obscureText: !_isConfirmPasswordVisible,
                prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[500]),
                suffixIcon: IconButton(
                  tooltip: _isConfirmPasswordVisible
                      ? t('hide_password')
                      : t('show_password'),
                  icon: Icon(
                    _isConfirmPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.grey[500],
                  ),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return t('please_fill_required');
                  }
                  if (value != _passwordController.text) {
                    return t('passwords_do_not_match');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: _isRegistering
                      ? t('creating_account')
                      : t('complete_registration'),
                  onPressed: _canComplete ? _completeRegistration : null,
                  isLoading: _isRegistering,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SignInPrompt(onPressed: () => context.go('/login')),
        const SizedBox(height: 24),
        const AuthDivider(),
        const SizedBox(height: 24),
        const AuthLanguageButton(),
      ],
    );
  }

  Future<void> _sendVerificationCode() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() {
      _isSendingCode = true;
    });

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .sendVerificationCode('signup', _emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _step = _RegisterStep.verify;
      });
      ToastUtils.showSuccess(
        context,
        ref.read(translationsProvider)('verification_sent'),
      );
      _startResendCountdown();
    } catch (error) {
      if (mounted) ToastUtils.showServerErrors(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCode = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _isSendingCode = true;
    });

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .sendVerificationCode('signup', _emailController.text.trim());
      if (!mounted) return;
      ToastUtils.showSuccess(
        context,
        ref.read(translationsProvider)('verification_resent'),
      );
      _startResendCountdown();
    } catch (error) {
      if (mounted) ToastUtils.showServerErrors(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCode = false;
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    if (!_verifyFormKey.currentState!.validate()) return;

    setState(() {
      _isVerifying = true;
    });

    try {
      final token = await ref
          .read(authNotifierProvider.notifier)
          .verifyVerificationCode(
            'signup',
            _emailController.text.trim(),
            _verificationCodeController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _verificationToken = token;
        _step = _RegisterStep.complete;
      });
      ToastUtils.showSuccess(
        context,
        ref.read(translationsProvider)('email_verified'),
      );
    } catch (error) {
      if (mounted) ToastUtils.showServerErrors(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _completeRegistration() async {
    if (!_completeFormKey.currentState!.validate()) return;
    final verificationToken = _verificationToken;
    if (verificationToken == null || verificationToken.isEmpty) {
      setState(() {
        _step = _RegisterStep.verify;
      });
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .register(
            _usernameController.text.trim(),
            _passwordController.text,
            _emailController.text.trim(),
            verificationToken,
          );

      if (!mounted) return;
      ToastUtils.showSuccess(
        context,
        ref.read(translationsProvider)('account_created'),
      );
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      ToastUtils.showServerErrors(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  void _backToEmail() {
    _resendTimer?.cancel();
    setState(() {
      _step = _RegisterStep.email;
      _verificationCodeController.clear();
      _verificationToken = null;
      _resendCountdown = 0;
    });
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 60;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown <= 1) {
        timer.cancel();
        setState(() {
          _resendCountdown = 0;
        });
        return;
      }
      setState(() {
        _resendCountdown--;
      });
    });
  }

  String? _validateEmail(String? value) {
    final t = ref.read(translationsProvider);
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return t('please_enter_email');
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      return t('please_enter_valid_email');
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final t = ref.read(translationsProvider);
    if (value == null || value.isEmpty) {
      return t('please_fill_required');
    }
    if (value.length < 6) {
      return t('password_min_error');
    }
    return null;
  }
}

class _SignInPrompt extends ConsumerWidget {
  const _SignInPrompt({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '${t('have_account')} ',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(t('sign_in')),
        ),
      ],
    );
  }
}
