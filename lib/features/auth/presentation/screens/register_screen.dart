import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/widgets/animated_button.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../providers/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Live password-strength indicators
  bool get _hasUpper => RegExp(r'[A-Z]').hasMatch(_passCtrl.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_passCtrl.text);
  bool get _hasSpecial =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\]~`]').hasMatch(_passCtrl.text);
  bool get _hasMinLen => _passCtrl.text.length >= 8;

  @override
  void initState() {
    super.initState();
    _passCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Normalise phone: "901234567" → "0901234567" ────────────────────────────
  String _normalisePhone(String raw) {
    String p = raw.trim();
    if (p.startsWith('84')) return '0${p.substring(2)}';
    if (!p.startsWith('0')) return '0$p';
    return p;
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _register() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final dio = ref.read(dioProvider);
      final ds = AuthRemoteDataSource(dio);

      final data = await ds.register(
        fullName: _nameCtrl.text.trim(),
        phone: _normalisePhone(_phoneCtrl.text),
        password: _passCtrl.text,
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      );

      await ref.read(authSessionProvider.notifier).login(
            AuthSession(
              accessToken: data['access_token'] as String,
              customerId: data['customer_id'] as String,
              fullName: data['full_name'] as String,
              phone: data['phone'] as String,
            ),
          );

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.dashboard,
          (_) => false,
        );
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final detail = e.response?.data?['detail'] as String?;
      if (statusCode == 409) {
        setState(() => _errorMessage =
            detail ?? 'This phone number is already registered.');
      } else if (statusCode == 422) {
        // Pydantic validation error from server
        final errors = e.response?.data?['detail'];
        if (errors is List && errors.isNotEmpty) {
          setState(() => _errorMessage = errors.first['msg'] as String? ??
              'Validation error. Check your inputs.');
        } else {
          setState(() => _errorMessage = detail ?? 'Invalid input.');
        }
      } else {
        setState(() =>
            _errorMessage = 'Network error. Please check your connection.');
      }
    } catch (_) {
      setState(() => _errorMessage = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // Header gradient blob
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 260,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A1A2E), AppColors.primaryRed],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(40)),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  const SizedBox(height: 28),

                  // Logo area
                  Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.person_add_rounded,
                            color: Colors.white, size: 32),
                      )
                          .animate()
                          .scale(duration: 600.ms, curve: Curves.elasticOut),
                      const SizedBox(height: 12),
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
                      const SizedBox(height: 4),
                      Text(
                        'Join VietFuel Pay today',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // Form card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Full Name ────────────────────────────────────
                          _FieldLabel(label: 'Full Name'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'Nguyen Van A',
                              prefixIcon: Icon(Icons.person_outline_rounded,
                                  color: AppColors.mediumGray),
                            ),
                            validator: (v) => (v == null || v.trim().length < 2)
                                ? 'Enter your full name (min 2 characters)'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // ── Phone Number ─────────────────────────────────
                          _FieldLabel(label: 'Phone Number (Username)'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration: const InputDecoration(
                              hintText: '0901 234 567',
                              prefixIcon: Icon(Icons.phone_rounded,
                                  color: AppColors.mediumGray),
                              prefixText: '+84 ',
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Phone number is required';
                              }
                              final normalised = _normalisePhone(v);
                              final regex =
                                  RegExp(r'^0[35789][0-9]{8}$');
                              if (!regex.hasMatch(normalised)) {
                                return 'Enter a valid Vietnamese mobile number (10 digits, 03/05/07/08/09...)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // ── Email (optional) ─────────────────────────────
                          _FieldLabel(label: 'Email (Optional)'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'your@email.com',
                              prefixIcon: Icon(Icons.email_outlined,
                                  color: AppColors.mediumGray),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return null; // optional
                              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // ── Password ─────────────────────────────────────
                          _FieldLabel(label: 'Password'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscurePass,
                            decoration: InputDecoration(
                              hintText: 'Min 8 chars with A, 1, @',
                              prefixIcon: const Icon(Icons.lock_rounded,
                                  color: AppColors.mediumGray),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePass
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: AppColors.mediumGray,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePass = !_obscurePass),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              if (!RegExp(r'[A-Z]').hasMatch(v)) {
                                return 'Add at least one uppercase letter (A–Z)';
                              }
                              if (!RegExp(r'[0-9]').hasMatch(v)) {
                                return 'Add at least one number (0–9)';
                              }
                              if (!RegExp(
                                      r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\]~`]')
                                  .hasMatch(v)) {
                                return 'Add at least one special character (!@#\$...)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          // ── Password strength row ─────────────────────────
                          _PasswordStrengthRow(
                            hasUpper: _hasUpper,
                            hasNumber: _hasNumber,
                            hasSpecial: _hasSpecial,
                            hasMinLen: _hasMinLen,
                          ),
                          const SizedBox(height: 16),

                          // ── Confirm Password ──────────────────────────────
                          _FieldLabel(label: 'Confirm Password'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _confirmCtrl,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              hintText: 'Re-enter password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded,
                                  color: AppColors.mediumGray),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: AppColors.mediumGray,
                                ),
                                onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (v != _passCtrl.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),

                          // ── Error Banner ──────────────────────────────────
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primaryRed.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.primaryRed
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: AppColors.primaryRed, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: AppColors.primaryRed,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(duration: 300.ms).shake(hz: 2),
                          ],

                          const SizedBox(height: 24),

                          // ── Submit ────────────────────────────────────────
                          AnimatedPrimaryButton(
                            label: 'Create Account',
                            isLoading: _isLoading,
                            width: double.infinity,
                            onTap: _register,
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms, duration: 500.ms).slideY(begin: 0.2),

                  const SizedBox(height: 20),

                  // ── Back to login ─────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account?',
                          style: TextStyle(color: AppColors.darkGray)),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Sign In'),
                      ),
                    ],
                  ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Field Label ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.charcoal,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ── Password Strength Indicators ──────────────────────────────────────────────

class _PasswordStrengthRow extends StatelessWidget {
  final bool hasUpper;
  final bool hasNumber;
  final bool hasSpecial;
  final bool hasMinLen;

  const _PasswordStrengthRow({
    required this.hasUpper,
    required this.hasNumber,
    required this.hasSpecial,
    required this.hasMinLen,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _StrengthChip(label: '8+ chars', met: hasMinLen),
        _StrengthChip(label: 'Uppercase A–Z', met: hasUpper),
        _StrengthChip(label: 'Number 0–9', met: hasNumber),
        _StrengthChip(label: 'Special !@#\$', met: hasSpecial),
      ],
    );
  }
}

class _StrengthChip extends StatelessWidget {
  final String label;
  final bool met;
  const _StrengthChip({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: met
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.lightGray,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: met ? AppColors.success : AppColors.borderGray,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: met ? AppColors.success : AppColors.mediumGray,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: met ? AppColors.success : AppColors.mediumGray,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
