import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:akhiyan_admin/src/core/api/api_providers.dart';
import 'package:akhiyan_admin/src/core/errors/error_mapper.dart';
import 'package:akhiyan_admin/src/core/router/app_router.dart';
import 'package:akhiyan_admin/src/core/theme/colors.dart';
import 'package:akhiyan_admin/src/core/theme/spacing.dart';
import 'package:akhiyan_admin/src/core/theme/typography.dart';
import 'package:akhiyan_admin/src/features/auth/presentation/controllers/auth_controller.dart';

// Login screen uses the same purple brand as the rest of the app
// (`AppColors.primary` and `AppColors.primaryContainer`) — kept as local
// aliases so the login layout reads cleanly.
const _loginBg = Color(0xFFF8F9FC);
const _inputBg = Color(0xFFFDF7FF);
const _inputBorder = Color(0xFFEAE6F0);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController(text: 'admin@akhiyan.com');
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).signIn(
            email: _email.text.trim(),
            password: _password.text,
          );
      if (!mounted) return;
      // Warm up caches in parallel — don't await; navigation continues
      // immediately so data is loading while the route transition animates.
      // The default range here MUST match dashboard_screen's initial _range
      // (midnight-today → midnight-today) so the cache key lines up.
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final defaultRange = DateTimeRange(start: today, end: today);
      // Dashboard + product list — what the dashboard route renders.
      unawaited(ref.read(dashboardDataProvider(defaultRange).future));
      unawaited(ref.read(productsListProvider.notifier).goToPage(1));
      unawaited(ref.read(currentUserProvider.future));
      // Hot lookups used by the order/product/customer forms. Pre-warming
      // these means the moment the user taps "+", every dropdown is
      // already populated — no spinner on form open.
      unawaited(ref.read(categoriesProvider.future));
      unawaited(ref.read(brandsProvider.future));
      unawaited(ref.read(orderStatusesProvider.future));
      unawaited(ref.read(staffListProvider.future));
      unawaited(ref.read(ordersListProvider.notifier).goToPage(1));
      unawaited(ref.read(customersListProvider.notifier).goToPage(1));
      context.go(AppRoute.dashboard.path);
    } on ArgumentError {
      setState(() => _error = 'Email and password are required.');
    } on Object catch (e) {
      // Repository converts everything to a Failure subtype; describeError
      // produces a friendly string without us having to type-test here.
      setState(() => _error = describeError(e, fallback: 'Login failed. Try again.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _loginBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.large),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F000000),
                          blurRadius: 16,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Image.asset(
                              'assets/branding/akhiyan_mark.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Akhiyan Admin',
                          style: AppTypography.h1.copyWith(
                            fontSize: 24,
                            color: AppColors.onBackground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Store Management',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _LoginField(
                          controller: _email,
                          label: 'Email',
                          hint: 'admin@akhiyan.com',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _LoginField(
                          controller: _password,
                          label: 'Password',
                          hint: '••••••••',
                          icon: Icons.lock_outline,
                          obscure: _obscure,
                          onToggleObscure: () =>
                              setState(() => _obscure = !_obscure),
                          onSubmit: _submit,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(_error!,
                              style: AppTypography.bodySm
                                  .copyWith(color: AppColors.error)),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              shadowColor: AppColors.primary.withValues(alpha: 0.3),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: AppSpacing.sm),
                                      Icon(Icons.arrow_forward, size: 18),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Forgot Password?'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Trusted by global commerce leaders',
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.outline),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PlaceholderLogo(width: 80),
                      SizedBox(width: AppSpacing.md),
                      _PlaceholderLogo(width: 64),
                      SizedBox(width: AppSpacing.md),
                      _PlaceholderLogo(width: 96),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscure = false,
    this.onToggleObscure,
    this.onSubmit,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onBackground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          onSubmitted: onSubmit == null ? null : (_) => onSubmit!(),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: _inputBg,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 14,
            ),
            prefixIcon: Icon(icon, color: AppColors.outline, size: 20),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AppColors.outline,
                    ),
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceholderLogo extends StatelessWidget {
  const _PlaceholderLogo({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
