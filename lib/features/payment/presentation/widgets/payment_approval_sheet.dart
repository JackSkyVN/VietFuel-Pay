import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/providers/pending_payment_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the Smart Payment approval sheet.
/// This is triggered automatically by the dashboard when the pump sends
/// a payment request — the amount is pre-filled, the customer only
/// needs to tap "Confirm & Pay".
Future<void> showPaymentApprovalSheet({
  required BuildContext context,
  required PendingPaymentInfo payment,
  required double currentBalance,
  required ValueChanged<double> onPaymentSuccess,
  required VoidCallback onDismiss,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => _PaymentApprovalSheet(
      payment: payment,
      currentBalance: currentBalance,
      onPaymentSuccess: onPaymentSuccess,
      onDismiss: onDismiss,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

enum _SheetState { idle, loading, success }

class _PaymentApprovalSheet extends StatefulWidget {
  final PendingPaymentInfo payment;
  final double currentBalance;
  final ValueChanged<double> onPaymentSuccess;
  final VoidCallback onDismiss;

  const _PaymentApprovalSheet({
    required this.payment,
    required this.currentBalance,
    required this.onPaymentSuccess,
    required this.onDismiss,
  });

  @override
  State<_PaymentApprovalSheet> createState() => _PaymentApprovalSheetState();
}

class _PaymentApprovalSheetState extends State<_PaymentApprovalSheet>
    with TickerProviderStateMixin {
  _SheetState _sheetState = _SheetState.idle;
  late double _currentBalance;

  late AnimationController _successCtrl;
  late AnimationController _checkCtrl;
  late Animation<double> _successScale;
  late Animation<double> _checkOpacity;

  @override
  void initState() {
    super.initState();
    _currentBalance = widget.currentBalance;

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _successScale = CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut);
    _checkOpacity = CurvedAnimation(parent: _checkCtrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _successCtrl.dispose();
    _checkCtrl.dispose();
    super.dispose();
  }

  // ── Payment handler ────────────────────────────────────────────────────────

  Future<void> _confirmPayment() async {
    if (_sheetState != _SheetState.idle) return;
    HapticFeedback.mediumImpact();
    setState(() => _sheetState = _SheetState.loading);

    try {
      final baseUrl = kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
      final dio = Dio(BaseOptions(
        baseUrl: '$baseUrl/api/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
        validateStatus: (s) => s != null && s < 600,
      ));

      final response = await dio.post(
        '/transactions/${widget.payment.transactionId}/complete_demo',
        data: {'final_amount': widget.payment.amountVnd},
      );

      if (response.statusCode == 402) {
        throw Exception(response.data['detail'] ?? 'So du khong du.');
      }
      if (response.statusCode != 200) {
        throw Exception(response.data['detail'] ?? 'Loi khong xac dinh.');
      }

      final newBalance = (response.data['new_balance'] as num).toDouble();
      setState(() {
        _currentBalance = newBalance;
        _sheetState = _SheetState.success;
      });
      HapticFeedback.heavyImpact();

      await _successCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 100));
      await _checkCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 1400));

      if (mounted) {
        widget.onPaymentSuccess(newBalance);
        widget.onDismiss();
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _sheetState = _SheetState.idle);
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _cancel() {
    widget.onDismiss();
    Navigator.of(context).pop();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13))),
      ]),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      duration: const Duration(seconds: 4),
    ));
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 6),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderGray,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
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
                child: _sheetState == _SheetState.success
                    ? _buildSuccess()
                    : _buildApproval(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Approval view ──────────────────────────────────────────────────────────

  Widget _buildApproval() {
    final bool canPay = _currentBalance >= widget.payment.amountVnd;
    final bool isLoading = _sheetState == _SheetState.loading;

    return Column(
      key: const ValueKey('approval'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Row(children: [
          // Pump icon badge with pulse
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                color: AppColors.primaryRed.withValues(alpha: 0.35),
                blurRadius: 16, offset: const Offset(0, 4),
              )],
            ),
            child: const Icon(Icons.local_gas_station_rounded,
                color: AppColors.white, size: 26),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .scaleXY(begin: 1.0, end: 1.05, duration: 900.ms, curve: Curves.easeInOut),

          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Yeu cau thanh toan!',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800,
                    color: AppColors.charcoal, letterSpacing: -0.3)),
              const SizedBox(height: 2),
              Text(
                widget.payment.stationId != null
                    ? 'Tram ${widget.payment.stationId}'
                    : 'Tram xang thong minh',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500,
                    color: AppColors.mediumGray),
              ),
            ]),
          ),
          // Dismiss
          GestureDetector(
            onTap: isLoading ? null : _cancel,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: AppColors.lightGray, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.close_rounded, size: 18, color: AppColors.mediumGray),
            ),
          ),
        ]).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1),

        const SizedBox(height: 20),

        // ── Amount card ──────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryRed.withValues(alpha: 0.06),
                AppColors.primaryRed.withValues(alpha: 0.02),
              ],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.18)),
          ),
          child: Column(children: [
            Text('So tien can thanh toan',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500,
                  color: AppColors.mediumGray)),
            const SizedBox(height: 8),
            Text(_formatVnd(widget.payment.amountVnd),
              style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w900,
                  color: AppColors.primaryRed, letterSpacing: -1.0)),
            const SizedBox(height: 12),
            // Details row
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _InfoChip(icon: Icons.directions_car_rounded,
                  label: widget.payment.licensePlate, color: AppColors.info),
              if (widget.payment.pumpId != null) ...[
                const SizedBox(width: 8),
                _InfoChip(icon: Icons.ev_station_rounded,
                    label: widget.payment.pumpId!, color: AppColors.success),
              ],
            ]),
          ]),
        ).animate().fadeIn(delay: 80.ms, duration: 320.ms).slideY(begin: 0.12),

        const SizedBox(height: 16),

        // ── Balance status ───────────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: canPay
                ? AppColors.success.withValues(alpha: 0.06)
                : AppColors.error.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: canPay
                  ? AppColors.success.withValues(alpha: 0.20)
                  : AppColors.error.withValues(alpha: 0.25),
            ),
          ),
          child: Row(children: [
            Icon(
              canPay ? Icons.account_balance_wallet_rounded : Icons.warning_amber_rounded,
              color: canPay ? AppColors.success : AppColors.error, size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(
              canPay
                  ? 'So du vi: ${_formatVnd(_currentBalance.toInt())}  •  Con lai: ${_formatVnd((_currentBalance - widget.payment.amountVnd).toInt())}'
                  : 'So du vi khong du. Can nan them ${_formatVnd(widget.payment.amountVnd - _currentBalance.toInt())}.',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500,
                  color: canPay ? AppColors.success : AppColors.error),
            )),
          ]),
        ).animate().fadeIn(delay: 160.ms, duration: 280.ms),

        const SizedBox(height: 20),

        // ── Buttons ──────────────────────────────────────────────────────────
        Row(children: [
          // Cancel
          Expanded(
            flex: 4,
            child: GestureDetector(
              onTap: isLoading ? null : _cancel,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderGray),
                ),
                child: Center(
                  child: Text('Tu choi',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600,
                        color: AppColors.mediumGray)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Confirm
          Expanded(
            flex: 6,
            child: GestureDetector(
              onTap: canPay && !isLoading ? _confirmPayment : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 54,
                decoration: BoxDecoration(
                  gradient: canPay
                      ? AppColors.primaryGradient
                      : const LinearGradient(colors: [Color(0xFFCCCCCC), Color(0xFFBBBBBB)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: canPay && !isLoading
                      ? [BoxShadow(color: AppColors.primaryRed.withValues(alpha: 0.40),
                          blurRadius: 18, offset: const Offset(0, 6))]
                      : [],
                ),
                child: Center(
                  child: isLoading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.bolt_rounded, color: AppColors.white, size: 18),
                          const SizedBox(width: 6),
                          Text('Xac nhan thanh toan',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700,
                                color: AppColors.white)),
                        ]),
                ),
              ),
            ),
          ),
        ]).animate().fadeIn(delay: 240.ms, duration: 300.ms).slideY(begin: 0.15),
      ],
    );
  }

  // ── Success view ───────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Column(
      key: const ValueKey('success'),
      children: [
        const SizedBox(height: 16),
        ScaleTransition(
          scale: _successScale,
          child: Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.successGradient,
              boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.40),
                  blurRadius: 28, spreadRadius: 4, offset: const Offset(0, 8))],
            ),
            child: FadeTransition(
              opacity: _checkOpacity,
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text('Thanh toan thanh cong!',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800,
              color: AppColors.charcoal, letterSpacing: -0.4),
        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
        const SizedBox(height: 6),
        Text('${_formatVnd(widget.payment.amountVnd)} da duoc tru tu vi',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.mediumGray),
        ).animate().fadeIn(delay: 500.ms),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.account_balance_wallet_rounded,
                color: AppColors.success, size: 18),
            const SizedBox(width: 8),
            Text('So du moi: ${_formatVnd(_currentBalance.toInt())}',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppColors.success)),
          ]),
        ).animate().fadeIn(delay: 600.ms).scale(begin: const Offset(0.9, 0.9)),
        const SizedBox(height: 28),
      ],
    );
  }

  // ── Formatter ──────────────────────────────────────────────────────────────

  String _formatVnd(int amount) {
    final s = amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '\u20ab$s';
  }
}

// ── Small chip widget ─────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}
