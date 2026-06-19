import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/i18n/app_i18n.dart';
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
      await ref
          .read(authNotifierProvider.notifier)
          .requestPasswordReset(_emailController.text.trim());

      if (!mounted) return;
      ToastUtils.showSuccess(
        context,
        ref.read(translationsProvider)('reset_token_sent'),
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
      await ref
          .read(authNotifierProvider.notifier)
          .confirmPasswordReset(
            _tokenController.text.trim(),
            _passwordController.text,
          );

      if (!mounted) return;
      ToastUtils.showSuccess(
        context,
        ref.read(translationsProvider)('password_reset_success'),
      );
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
    final t = ref.watch(translationsProvider);

    return AuthLayout(
      subtitle: t('reset_password_title'),
      onBack: () => context.go('/login'),
      child: _isConfirmStep ? _buildConfirmForm() : _buildRequestForm(),
    );
  }

  Widget _buildRequestForm() {
    final t = ref.watch(translationsProvider);

    return Form(
      key: _requestFormKey,
      child: Column(
        children: [
          CustomInput(
            label: t('email'),
            controller: _emailController,
            placeholder: 'email@example.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icon(Icons.mail_outline, color: Colors.grey[500]),
            onChanged: (_) => setState(() {}),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) {
                return t('please_fill_all');
              }
              final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
              if (!emailRegex.hasMatch(email)) {
                return t('please_enter_valid_email');
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: CustomButton(
              text: t('send_reset_token'),
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
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
            child: Text(t('already_have_token')),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmForm() {
    final t = ref.watch(translationsProvider);

    return Form(
      key: _confirmFormKey,
      child: Column(
        children: [
          CustomInput(
            label: t('reset_token'),
            controller: _tokenController,
            placeholder: t('enter_reset_token'),
            prefixIcon: Icon(Icons.key_outlined, color: Colors.grey[500]),
            onChanged: (_) => setState(() {}),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return t('please_fill_all');
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          CustomInput(
            label: t('new_password'),
            controller: _passwordController,
            placeholder: t('password_min_chars'),
            obscureText: !_isPasswordVisible,
            prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[500]),
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
          const SizedBox(height: 20),
          CustomInput(
            label: t('confirm_password'),
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
                return t('please_fill_all');
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
              text: t('reset_password'),
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
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
            child: Text(t('request_new_token')),
          ),
        ],
      ),
    );
  }
}
