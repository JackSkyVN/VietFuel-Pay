import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 1 ─ Amount option model
// ─────────────────────────────────────────────────────────────────────────────

class _AmountOption {
  final int value;
  final String label;
  final String? badge; // e.g. "Popular"

  const _AmountOption({
    required this.value,
    required this.label,
    this.badge,
  });
}

const List<_AmountOption> _kAmountOptions = [
  _AmountOption(value: 50000, label: '50.000đ'),
  _AmountOption(value: 100000, label: '100.000đ', badge: 'Phổ biến'),
  _AmountOption(value: 200000, label: '200.000đ'),
  _AmountOption(value: 500000, label: '500.000đ'),
];

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 2 ─ Public entry-point helper
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the Smart Wallet payment bottom sheet.
///
/// [licensePlate]   – The detected plate string (e.g. "29A-123.45").
/// [walletBalance]  – The customer's current wallet balance in VND.
/// [onPaymentSuccess] – Called with the new balance after a successful payment.
Future<void> showPaymentBottomSheet({
  required BuildContext context,
  required String licensePlate,
  required double walletBalance,
  ValueChanged<double>? onPaymentSuccess,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => ProviderScope(
      overrides: const [],
      child: _PaymentBottomSheetContent(
        licensePlate: licensePlate,
        initialBalance: walletBalance,
        onPaymentSuccess: onPaymentSuccess,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 3 ─ Main widget
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentBottomSheetContent extends ConsumerStatefulWidget {
  final String licensePlate;
  final double initialBalance;
  final ValueChanged<double>? onPaymentSuccess;

  const _PaymentBottomSheetContent({
    required this.licensePlate,
    required this.initialBalance,
    this.onPaymentSuccess,
  });

  @override
  ConsumerState<_PaymentBottomSheetContent> createState() =>
      _PaymentBottomSheetContentState();
}

enum _PaymentState { idle, loading, success }

class _PaymentBottomSheetContentState
    extends ConsumerState<_PaymentBottomSheetContent>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  int _selectedAmount = _kAmountOptions[1].value; // default: 100.000đ
  _PaymentState _payState = _PaymentState.idle;
  late double _currentBalance;

  // ── Animation controllers ──────────────────────────────────────────────────
  late AnimationController _successCtrl;
  late AnimationController _checkCtrl;
  late Animation<double> _successScale;
  late Animation<double> _checkOpacity;

  @override
  void initState() {
    super.initState();
    _currentBalance = widget.initialBalance;

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _successScale = CurvedAnimation(
      parent: _successCtrl,
      curve: Curves.elasticOut,
    );
    _checkOpacity = CurvedAnimation(
      parent: _checkCtrl,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _successCtrl.dispose();
    _checkCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Payment logic
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _handlePay() async {
    if (_payState != _PaymentState.idle) return;
    HapticFeedback.mediumImpact();

    setState(() => _payState = _PaymentState.loading);

    try {
      // ── Real API call to FastAPI backend ───────────────────────────────
      const transactionId = '00000000-0000-0000-0000-000000000abc';
      final baseUrl = kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';

      final dio = Dio(BaseOptions(
        baseUrl: '$baseUrl/api/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
        validateStatus: (status) => status != null && status < 600,
      ));

      final response = await dio.post(
        '/transactions/$transactionId/complete_demo',
        data: {'final_amount': _selectedAmount},
      );

      // ── Map HTTP errors ────────────────────────────────────────────────
      if (response.statusCode == 402) {
        final detail = response.data['detail'] ?? 'So du khong du.';
        throw _InsufficientBalanceException(detail.toString());
      }
      if (response.statusCode != 200) {
        final detail = response.data['detail'] ?? 'Loi khong xac dinh.';
        throw Exception(detail.toString());
      }

      // ── Success path ───────────────────────────────────────────────────
      final newBalance = (response.data['new_balance'] as num).toDouble();
      setState(() {
        _currentBalance = newBalance;
        _payState = _PaymentState.success;
      });
      HapticFeedback.heavyImpact();

      await _successCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 100));
      await _checkCtrl.forward();

      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        widget.onPaymentSuccess?.call(newBalance);
        Navigator.of(context).pop();
      }
    } on _InsufficientBalanceException catch (e) {
      setState(() => _payState = _PaymentState.idle);
      if (mounted) _showErrorSnackBar(e.message);
    } on DioException catch (e) {
      setState(() => _payState = _PaymentState.idle);
      if (mounted) {
        final msg = (e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout)
            ? 'Het thoi gian ket noi. Kiem tra mang.'
            : 'Khong the ket noi den may chu.';
        _showErrorSnackBar(msg);
      }
    } catch (e) {
      setState(() => _payState = _PaymentState.idle);
      if (mounted) {
        _showErrorSnackBar(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ───────────────────────────────────────────────
            _buildDragHandle(),

            // ── Body ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.0).animate(anim),
                    child: child,
                  ),
                ),
                child: _payState == _PaymentState.success
                    ? _buildSuccessView()
                    : _buildPaymentView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Drag Handle ───────────────────────────────────────────────────────────

  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.borderGray,
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        // Icon badge
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryRed.withValues(alpha: 0.30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_gas_station_rounded,
            color: AppColors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),

        // Title + subtitle
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Xác nhận đổ xăng',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Smart Wallet · Viettel Money',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.mediumGray,
              ),
            ),
          ],
        ),

        const Spacer(),

        // Close button
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.mediumGray,
            ),
          ),
        ),
      ],
    );
  }

  // ── Details Section ───────────────────────────────────────────────────────

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.lightGray,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          // License plate chip
          Expanded(
            child: _DetailCell(
              icon: Icons.directions_car_rounded,
              iconColor: AppColors.info,
              label: 'Biển số xe',
              value: widget.licensePlate,
              valueFontSize: 17,
            ),
          ),

          // Vertical divider
          Container(
            width: 1,
            height: 44,
            color: AppColors.borderGray,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),

          // Wallet balance
          Expanded(
            child: _DetailCell(
              icon: Icons.account_balance_wallet_rounded,
              iconColor: AppColors.success,
              label: 'Số dư ví',
              value: _formatCurrency(_currentBalance),
              valueFontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // ── Amount Selection ──────────────────────────────────────────────────────

  Widget _buildAmountSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chọn số tiền',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.charcoal,
          ),
        ),
        const SizedBox(height: 12),

        // 2 × 2 grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.8,
          children: _kAmountOptions
              .map((opt) => _AmountChip(
                    option: opt,
                    isSelected: _selectedAmount == opt.value,
                    onTap: () {
                      if (_payState != _PaymentState.idle) return;
                      HapticFeedback.selectionClick();
                      setState(() => _selectedAmount = opt.value);
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ── Summary Row ───────────────────────────────────────────────────────────

  Widget _buildSummaryRow() {
    final bool canPay = _selectedAmount <= _currentBalance;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: canPay
            ? AppColors.primaryRed.withValues(alpha: 0.05)
            : AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: canPay
              ? AppColors.primaryRed.withValues(alpha: 0.15)
              : AppColors.error.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Icon(
            canPay
                ? Icons.check_circle_outline_rounded
                : Icons.warning_amber_rounded,
            color: canPay ? AppColors.primaryRed : AppColors.error,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            canPay
                ? 'Sau giao dịch còn: ${_formatCurrency(_currentBalance - _selectedAmount)}'
                : 'Số dư không đủ để thanh toán',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: canPay ? AppColors.charcoal : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  // ── Confirm Button ────────────────────────────────────────────────────────

  Widget _buildConfirmButton() {
    final bool canPay = _selectedAmount <= _currentBalance;
    final bool isLoading = _payState == _PaymentState.loading;

    return GestureDetector(
      onTap: canPay ? _handlePay : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 58,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: canPay
              ? AppColors.primaryGradient
              : const LinearGradient(
                  colors: [Color(0xFFCCCCCC), Color(0xFFBBBBBB)],
                ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: canPay && !isLoading
              ? [
                  BoxShadow(
                    color: AppColors.primaryRed.withValues(alpha: 0.40),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Đang xử lý…',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: AppColors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Xác nhận & Thanh toán',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Full payment view ─────────────────────────────────────────────────────

  Widget _buildPaymentView() {
    return Column(
      key: const ValueKey('payment'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader()
            .animate()
            .fadeIn(duration: 300.ms)
            .slideY(begin: -0.1, curve: Curves.easeOut),

        const SizedBox(height: 20),

        _buildDetailsCard()
            .animate()
            .fadeIn(delay: 80.ms, duration: 300.ms)
            .slideY(begin: 0.1),

        const SizedBox(height: 22),

        _buildAmountSelection()
            .animate()
            .fadeIn(delay: 150.ms, duration: 300.ms)
            .slideY(begin: 0.1),

        const SizedBox(height: 16),

        _buildSummaryRow()
            .animate()
            .fadeIn(delay: 220.ms, duration: 300.ms),

        const SizedBox(height: 20),

        _buildConfirmButton()
            .animate()
            .fadeIn(delay: 280.ms, duration: 300.ms)
            .slideY(begin: 0.15),
      ],
    );
  }

  // ── Success view ──────────────────────────────────────────────────────────

  Widget _buildSuccessView() {
    return Column(
      key: const ValueKey('success'),
      children: [
        const SizedBox(height: 16),

        // Animated checkmark circle
        ScaleTransition(
          scale: _successScale,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.successGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.40),
                  blurRadius: 28,
                  spreadRadius: 4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: FadeTransition(
              opacity: _checkOpacity,
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),

        const SizedBox(height: 22),

        Text(
          'Thanh toán thành công!',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.charcoal,
            letterSpacing: -0.4,
          ),
        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),

        const SizedBox(height: 6),

        Text(
          '${_formatCurrency(_selectedAmount.toDouble())} đã được trừ từ ví',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.mediumGray,
            fontWeight: FontWeight.w400,
          ),
        ).animate().fadeIn(delay: 500.ms),

        const SizedBox(height: 20),

        // New balance chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
                color: AppColors.success.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              Text(
                'Số dư mới: ${_formatCurrency(_currentBalance)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 600.ms).scale(begin: const Offset(0.9, 0.9)),

        const SizedBox(height: 28),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatCurrency(double amount) {
    final formatted = amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return '$formatted₫';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 4 ─ Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// A single info cell used inside the details card.
class _DetailCell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final double valueFontSize;

  const _DetailCell({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueFontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.mediumGray,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: valueFontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.charcoal,
            letterSpacing: -0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// A selectable amount chip with an optional "Popular" badge.
class _AmountChip extends StatelessWidget {
  final _AmountOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _AmountChip({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryRed
              : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryRed
                : AppColors.borderGray,
            width: isSelected ? 2.0 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryRed.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            // Main label
            Center(
              child: Text(
                option.label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppColors.white : AppColors.charcoal,
                  letterSpacing: -0.1,
                ),
              ),
            ),

            // Badge
            if (option.badge != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                  child: Text(
                    option.badge!,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.white
                          : AppColors.warning,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 5 ─ Custom exceptions
// ─────────────────────────────────────────────────────────────────────────────

class _InsufficientBalanceException implements Exception {
  final String message;
  const _InsufficientBalanceException(this.message);
}
