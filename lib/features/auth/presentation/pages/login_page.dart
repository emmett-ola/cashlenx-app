import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_input.dart';
import '../../../../theme/app_theme.dart';
import '../providers/auth_provider.dart';
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

    // Listen for errors
    ref.listen(authNotifierProvider, (previous, next) {
      if (next.hasError) {
        ToastUtils.showServerErrors(context, next.error);
      } else if (next.hasValue &&
          next.value != null &&
          (previous?.isLoading == true || previous == null)) {
        final username = next.value?.username ?? 'User';
        ToastUtils.showSuccess(context, 'Welcome back, $username!');
      }
    });

    return AuthLayout(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            CustomInput(
              label: 'Email or Username',
              controller: _identifierController,
              placeholder: 'email@example.com or username',
              keyboardType: TextInputType.text,
              prefixIcon: Icon(Icons.mail_outline, color: Colors.grey[500]),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final identifier = value?.trim() ?? '';
                if (identifier.isEmpty) {
                  return 'Please fill in all fields.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            CustomInput(
              label: 'Password',
              controller: _passwordController,
              placeholder: 'Enter your password',
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      Tooltip(
                        message: 'We will keep you signed in for 30 days',
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
                            message: 'We will keep you signed in for 30 days',
                            child: Text(
                              'Remember me',
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
                  child: const Text('Forgot Password?'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'Sign In',
                onPressed: _canSubmit ? _handleLogin : null,
                isLoading: isLoading,
                height: 48,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'or',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300])),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'Continue with Demo Mode',
                isOutlined: true,
                onPressed: _handleDemoMode,
                height: 48,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
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
                  child: const Text('Sign Up'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
