import 'dart:async';
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
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() {
      _cooldownSeconds = seconds;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_cooldownSeconds <= 1) {
          _cooldownSeconds = 0;
          timer.cancel();
        } else {
          _cooldownSeconds--;
        }
      });
    });
  }

  Future<void> _create() async {
    if (_cooldownSeconds > 0) return;
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authStateProvider.notifier).register(
          email: widget.email,
          password: _passwordCtrl.text,
          confirmPassword: _confirmCtrl.text,
        );
    if (!mounted) return;
    if (success) {
      context.go('/dashboard');
    } else {
      final error = ref.read(authStateProvider).error ?? 'Registration failed';
      // If error message indicates cooldown
      if (error.contains('60 seconds') || error.contains('cooldown') || error.contains('wait')) {
        final match = RegExp(r'wait\s+(\d+)s').firstMatch(error);
        final seconds = match != null ? int.tryParse(match.group(1)!) ?? 60 : 60;
        _startCooldown(seconds);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: _cooldownSeconds > 0 ? AppColors.warning : AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  bool _hasMinLength(String v) => v.length >= 8;
  bool _hasUppercase(String v) => v.contains(RegExp(r'[A-Z]'));
  bool _hasLowercase(String v) => v.contains(RegExp(r'[a-z]'));
  bool _hasNumber(String v) => v.contains(RegExp(r'[0-9]'));
  bool _hasSpecial(String v) => v.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

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
                  'Set a strong password for ${widget.email}',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                // Step indicator (2-step flow)
                const Row(
                  children: [
                    _StepDot(label: '1', active: false, done: true),
                    _StepLine(active: true),
                    _StepDot(label: '2', active: true, done: false),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Step 2 of 2: Set password',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 24),
                if (_cooldownSeconds > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer_outlined, color: AppColors.warning, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Network cooldown active. You can retry in ${_cooldownSeconds}s.',
                            style: TextStyle(color: AppColors.warning, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
                  onChanged: (v) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (!_hasMinLength(v)) return 'Minimum 8 characters';
                    if (!_hasUppercase(v)) return 'Must include uppercase letter';
                    if (!_hasLowercase(v)) return 'Must include lowercase letter';
                    if (!_hasNumber(v)) return 'Must include a number';
                    if (!_hasSpecial(v)) return 'Must include a special character';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // Password strength indicators
                if (pw.isNotEmpty) ...[
                  _StrengthRow(text: 'At least 8 characters', met: _hasMinLength(pw)),
                  const SizedBox(height: 4),
                  _StrengthRow(text: 'Uppercase letter (A-Z)', met: _hasUppercase(pw)),
                  const SizedBox(height: 4),
                  _StrengthRow(text: 'Lowercase letter (a-z)', met: _hasLowercase(pw)),
                  const SizedBox(height: 4),
                  _StrengthRow(text: 'Number (0-9)', met: _hasNumber(pw)),
                  const SizedBox(height: 4),
                  _StrengthRow(text: 'Special character (!@#\$%...)', met: _hasSpecial(pw)),
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
                  text: _cooldownSeconds > 0 ? 'Please wait (${_cooldownSeconds}s)' : 'Create Account',
                  isLoading: auth.isLoading,
                  onPressed: _cooldownSeconds > 0 ? null : _create,
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

class _StepDot extends StatelessWidget {
  final String label;
  final bool active;
  final bool done;
  const _StepDot({required this.label, required this.active, required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? AppColors.success
            : active
                ? AppColors.purple
                : AppColors.border,
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
            : Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool active;
  const _StepLine({required this.active});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        color: active ? AppColors.purple : AppColors.border,
      ),
    );
  }
}
