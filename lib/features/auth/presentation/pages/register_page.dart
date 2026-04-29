import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_input.dart';
import '../../../../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_layout.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _confirmPasswordController.text.isNotEmpty;

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      await ref.read(authNotifierProvider.notifier).register(
            email,
            _passwordController.text,
          );

      if (!mounted) return;
      ToastUtils.showSuccess(context, 'Account created. Please sign in.');
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
      subtitle: 'Create your account',
      onBack: () => context.go('/login'),
      child: Form(
        key: _formKey,
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
            const SizedBox(height: 20),
            CustomInput(
              label: 'Password',
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
                text: 'Create Account',
                onPressed: _canSubmit ? _handleRegister : null,
                isLoading: _isLoading,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                TextButton(
                  onPressed: () => context.go('/login'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Sign In'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
