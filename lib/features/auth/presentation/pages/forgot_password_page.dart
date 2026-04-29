import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_input.dart';
import '../../../../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_layout.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _requestFormKey = GlobalKey<FormState>();
  final _confirmFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _isConfirmStep = false;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _canRequest => _emailController.text.trim().isNotEmpty;

  bool get _canConfirm =>
      _tokenController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _confirmPasswordController.text.isNotEmpty;

  Future<void> _handleRequestReset() async {
    if (!_requestFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(authNotifierProvider.notifier).requestPasswordReset(
            _emailController.text.trim(),
          );

      if (!mounted) return;
      ToastUtils.showSuccess(
        context,
        'If the account exists, a reset token will be sent.',
      );
      setState(() {
        _isConfirmStep = true;
      });
    } catch (error) {
      if (!mounted) return;
      ToastUtils.showServerErrors(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleConfirmReset() async {
    if (!_confirmFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(authNotifierProvider.notifier).confirmPasswordReset(
            _tokenController.text.trim(),
            _passwordController.text,
          );

      if (!mounted) return;
      ToastUtils.showSuccess(context, 'Password reset. Please sign in.');
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      ToastUtils.showServerErrors(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      subtitle: 'Reset your password',
      onBack: () => context.go('/login'),
      child: _isConfirmStep ? _buildConfirmForm() : _buildRequestForm(),
    );
  }

  Widget _buildRequestForm() {
    return Form(
      key: _requestFormKey,
      child: Column(
        children: [
          CustomInput(
            label: 'Email',
            controller: _emailController,
            placeholder: 'email@example.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icon(Icons.mail_outline, color: Colors.grey[500]),
            onChanged: (_) => setState(() {}),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) {
                return 'Please fill in all fields.';
              }
              final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
              if (!emailRegex.hasMatch(email)) {
                return 'Please enter a valid email address.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              text: 'Send Reset Token',
              onPressed: _canRequest ? _handleRequestReset : null,
              isLoading: _isLoading,
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () {
              setState(() {
                _isConfirmStep = true;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Already have a token?'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmForm() {
    return Form(
      key: _confirmFormKey,
      child: Column(
        children: [
          CustomInput(
            label: 'Reset Token',
            controller: _tokenController,
            placeholder: 'Enter reset token',
            prefixIcon: Icon(Icons.key_outlined, color: Colors.grey[500]),
            onChanged: (_) => setState(() {}),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please fill in all fields.';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          CustomInput(
            label: 'New Password',
            controller: _passwordController,
            placeholder: 'At least 6 characters',
            obscureText: !_isPasswordVisible,
            prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[500]),
            suffixIcon: IconButton(
              tooltip: _isPasswordVisible ? 'Hide password' : 'Show password',
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
                return 'Please fill in all fields.';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters long.';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          CustomInput(
            label: 'Confirm Password',
            controller: _confirmPasswordController,
            placeholder: 'Re-enter your password',
            obscureText: !_isConfirmPasswordVisible,
            prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[500]),
            suffixIcon: IconButton(
              tooltip:
                  _isConfirmPasswordVisible ? 'Hide password' : 'Show password',
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
                return 'Please fill in all fields.';
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
              text: 'Reset Password',
              onPressed: _canConfirm ? _handleConfirmReset : null,
              isLoading: _isLoading,
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () {
              setState(() {
                _isConfirmStep = false;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Request a new token'),
          ),
        ],
      ),
    );
  }
}
