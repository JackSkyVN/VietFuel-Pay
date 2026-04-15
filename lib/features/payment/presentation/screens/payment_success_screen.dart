import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/widgets/animated_button.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final String stationName;
  final double amountPaid;
  final double litersFueled;

  const PaymentSuccessScreen({
    super.key,
    this.stationName = 'Viettel Station — Q.1',
    this.amountPaid = 180000,
    this.litersFueled = 8.5,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            children: [
              const Spacer(),

              // ── Lottie / Fallback success animation ───────────────────
              _buildSuccessAnimation(),
              const SizedBox(height: 32),

              // ── Title ─────────────────────────────────────────────────
              const Text(
                AppStrings.paymentSuccess,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(delay: 600.ms, duration: 500.ms).slideY(begin: 0.3),

              const SizedBox(height: 8),

              Text(
                'Your transaction has been processed.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 14,
                ),
              ).animate().fadeIn(delay: 750.ms, duration: 500.ms),

              const SizedBox(height: 40),

              // ── Receipt card ─────────────────────────────────────────
              _buildReceiptCard(context)
                  .animate()
                  .fadeIn(delay: 900.ms, duration: 500.ms)
                  .slideY(begin: 0.25),

              const Spacer(),

              // ── Done button ───────────────────────────────────────────
              AnimatedPrimaryButton(
                label: AppStrings.done,
                icon: Icons.check_rounded,
                width: double.infinity,
                onTap: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil('/dashboard', (_) => false),
              )
                  .animate()
                  .fadeIn(delay: 1100.ms, duration: 400.ms)
                  .slideY(begin: 0.3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessAnimation() {
    // Try to load Lottie — falls back to animated icon if asset missing
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glowing circle
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.35),
                  blurRadius: 50,
                  spreadRadius: 10,
                ),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .scaleXY(begin: 0.9, end: 1.1, duration: 1500.ms, curve: Curves.easeInOut),

          // Lottie or fallback
          LottieBuilder.asset(
            'assets/lottie/success.json',
            width: 140,
            height: 140,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.successGradient,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 60,
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          _ReceiptRow(label: AppStrings.stationName, value: stationName),
          const SizedBox(height: 16),
          _ReceiptRow(label: AppStrings.fuelAmount, value: '${litersFueled}L'),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.1), thickness: 1),
          const SizedBox(height: 16),
          _ReceiptRow(
            label: AppStrings.totalCost,
            value: '₫${amountPaid.toStringAsFixed(0).replaceAllMapped(
                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                  (m) => '${m[1]},',
                )}',
            isHighlight: true,
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _ReceiptRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: isHighlight ? 0.9 : 0.55),
            fontSize: isHighlight ? 15 : 13,
            fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? AppColors.success : Colors.white,
            fontSize: isHighlight ? 20 : 14,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
