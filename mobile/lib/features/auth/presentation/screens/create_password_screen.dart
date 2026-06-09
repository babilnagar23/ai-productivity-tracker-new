import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_widgets.dart';

class CreatePasswordScreen extends ConsumerStatefulWidget {
  final String email;
  const CreatePasswordScreen({super.key, required this.email});

  @override
  ConsumerState<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends ConsumerState<CreatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showPassword = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(authStateProvider.notifier).completeRegistration(
          email: widget.email,
          password: _passwordCtrl.text,
          confirmPassword: _confirmCtrl.text,
        );
    if (!mounted) return;
    if (success) {
      // completeRegistration now auto-logs in via the returned JWT
      context.go('/template-select');
    } else {
      final error = ref.read(authStateProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Registration failed'), backgroundColor: AppColors.error),
      );
    }
  }

  bool _hasMinLength(String v) => v.length >= 8;
  bool _hasUppercase(String v) => v.contains(RegExp(r'[A-Z]'));
  bool _hasNumber(String v) => v.contains(RegExp(r'[0-9]'));

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final pw = _passwordCtrl.text;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Password',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Set a strong password for your account',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 40),
                AuthTextField(
                  controller: _passwordCtrl,
                  label: 'Password',
                  hint: '8+ characters',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: !_showPassword,
                  suffixIcon: IconButton(
                    icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 8) return 'Minimum 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // Password strength indicators
                if (pw.isNotEmpty) ...[
                  _StrengthRow(text: 'At least 8 characters', met: _hasMinLength(pw)),
                  const SizedBox(height: 4),
                  _StrengthRow(text: 'Contains uppercase letter', met: _hasUppercase(pw)),
                  const SizedBox(height: 4),
                  _StrengthRow(text: 'Contains a number', met: _hasNumber(pw)),
                  const SizedBox(height: 16),
                ],
                AuthTextField(
                  controller: _confirmCtrl,
                  label: 'Confirm Password',
                  hint: 'Repeat your password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: !_showConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(_showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _showConfirm = !_showConfirm),
                  ),
                  validator: (v) {
                    if (v != _passwordCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 40),
                GradientButton(
                  text: 'Create Account',
                  isLoading: auth.isLoading,
                  onPressed: _create,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StrengthRow extends StatelessWidget {
  final String text;
  final bool met;
  const _StrengthRow({required this.text, required this.met});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.circle_outlined,
          color: met ? AppColors.success : AppColors.textMuted,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: met ? AppColors.success : AppColors.textMuted, fontSize: 13)),
      ],
    );
  }
}
