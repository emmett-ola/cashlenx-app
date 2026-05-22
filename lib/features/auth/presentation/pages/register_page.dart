import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    return AuthLayout(
      subtitle: switch (_step) {
        _RegisterStep.email => 'Create your account',
        _RegisterStep.verify => 'Verify Email',
        _RegisterStep.complete => 'Complete Profile',
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
    return Column(
      children: [
        Form(
          key: _emailFormKey,
          child: Column(
            children: [
              CustomInput(
                label: 'Email *',
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
                  text: 'Send Verification Code',
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
    return Column(
      children: [
        Form(
          key: _verifyFormKey,
          child: Column(
            children: [
              CustomInput(
                label: 'Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icon(Icons.mail_outline, color: Colors.grey[500]),
                enabled: false,
              ),
              const SizedBox(height: 20),
              CustomInput(
                label: 'Verification Code *',
                controller: _verificationCodeController,
                placeholder: 'Enter code',
                keyboardType: TextInputType.number,
                prefixIcon: Icon(Icons.error_outline, color: Colors.grey[500]),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Please enter the verification code.';
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
                        ? 'Resend in ${_resendCountdown}s'
                        : 'Resend Code',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: _isVerifying ? 'Verifying...' : 'Verify Code',
                  onPressed: _canVerify ? _verifyCode : null,
                  isLoading: _isVerifying,
                ),
              ),
              const SizedBox(height: 12),
              AuthOutlinedActionButton(
                text: 'Back to Email',
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
    return Column(
      children: [
        Form(
          key: _completeFormKey,
          child: Column(
            children: [
              CustomInput(
                label: 'Username *',
                controller: _usernameController,
                placeholder: 'Choose a username',
                prefixIcon: Icon(Icons.person_outline, color: Colors.grey[500]),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Please fill in all required fields.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              CustomInput(
                label: 'Password *',
                controller: _passwordController,
                placeholder: 'At least 6 characters',
                obscureText: !_isPasswordVisible,
                prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[500]),
                suffixIcon: IconButton(
                  tooltip: _isPasswordVisible
                      ? 'Hide password'
                      : 'Show password',
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
                label: 'Confirm Password *',
                controller: _confirmPasswordController,
                placeholder: 'Re-enter your password',
                obscureText: !_isConfirmPasswordVisible,
                prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[500]),
                suffixIcon: IconButton(
                  tooltip: _isConfirmPasswordVisible
                      ? 'Hide password'
                      : 'Show password',
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
                    return 'Please fill in all required fields.';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: _isRegistering
                      ? 'Creating Account...'
                      : 'Complete Registration',
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

    await Future<void>.delayed(const Duration(milliseconds: 350));

    if (!mounted) return;
    setState(() {
      _isSendingCode = false;
      _step = _RegisterStep.verify;
    });
    ToastUtils.showSuccess(context, 'Verification code sent to your email!');
    _startResendCountdown();
  }

  Future<void> _resendCode() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _isSendingCode = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 350));

    if (!mounted) return;
    setState(() {
      _isSendingCode = false;
    });
    ToastUtils.showSuccess(context, 'Verification code resent!');
    _startResendCountdown();
  }

  Future<void> _verifyCode() async {
    if (!_verifyFormKey.currentState!.validate()) return;

    setState(() {
      _isVerifying = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 350));

    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _step = _RegisterStep.complete;
    });
    ToastUtils.showSuccess(context, 'Email verified successfully!');
  }

  Future<void> _completeRegistration() async {
    if (!_completeFormKey.currentState!.validate()) return;

    setState(() {
      _isRegistering = true;
    });

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .register(_usernameController.text.trim(), _passwordController.text);

      if (!mounted) return;
      ToastUtils.showSuccess(
        context,
        'Account created successfully! Please sign in to continue.',
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
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Please enter your email address.';
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please fill in all required fields.';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long.';
    }
    return null;
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Already have an account? ',
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
          child: const Text('Sign In'),
        ),
      ],
    );
  }
}
