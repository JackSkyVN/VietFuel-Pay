/// Staff POS Dashboard Screen
///
/// Designed for low-end Android POS terminals (Sunmi / Pax class).
/// Design rules strictly followed:
///   • ZERO shadows, blurs, or glassmorphism
///   • Pure flat colours only
///   • Minimum touch target: 56 dp (buttons are 72 dp)
///   • High contrast: charcoal on white, white on Viettel Red
///   • No heavy animations – only an instant `setState` on QR/Camera tap
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../providers/shift_providers.dart';

// ── Formatters ────────────────────────────────────────────────────────────────

final _vndFmt = NumberFormat('#,###', 'vi_VN');
final _timeFmt = DateFormat('HH:mm');

// ── Screen ────────────────────────────────────────────────────────────────────

class StaffDashboardScreen extends ConsumerWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncShift = ref.watch(shiftSummaryProvider);

    return asyncShift.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.primaryRed,
          elevation: 0,
          title: const Text('VietFuel Pay — Nhân viên',
              style: TextStyle(
                  color: AppColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryRed),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.primaryRed,
          elevation: 0,
          title: const Text('VietFuel Pay — Nhân viên',
              style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.primaryRed, size: 48),
              const SizedBox(height: 12),
              Text(e.toString(),
                  style: const TextStyle(color: AppColors.charcoal),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: AppColors.white),
                onPressed: () => ref.refresh(shiftSummaryProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
      data: (shift) => _buildDashboard(context, shift),
    );
  }

  Widget _buildDashboard(BuildContext context, ShiftSummary shift) {

    return Scaffold(
      backgroundColor: AppColors.white,
      // ── App Bar ─────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: AppColors.white,
        elevation: 0,
        titleSpacing: 16,
        title: const Text(
          'VietFuel Pay — Nhân viên',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          // Shift label chip
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryRedDark,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              shift.shiftLabel,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // ── 1. Revenue Overview ──────────────────────────────────────────────
          _RevenueOverview(shift: shift),

          // ── Divider ─────────────────────────────────────────────────────────
          const _FlatDivider(),

          // ── 2. Action Buttons ────────────────────────────────────────────────
          _ActionRow(context: context),

          // ── Divider ─────────────────────────────────────────────────────────
          const _FlatDivider(),

          // ── 3. Transaction feed header ───────────────────────────────────────
          const _FeedHeader(),

          // ── 4. Live feed ─────────────────────────────────────────────────────
          Expanded(
            child: _TransactionFeed(transactions: shift.transactions),
          ),
        ],
      ),
    );
  }
}

// ── Revenue Overview ──────────────────────────────────────────────────────────

class _RevenueOverview extends StatelessWidget {
  final ShiftSummary shift;
  const _RevenueOverview({required this.shift});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left: label + revenue ──────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ca làm việc hiện tại',
                  style: TextStyle(
                    color: AppColors.mediumGray,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_vndFmt.format(shift.totalRevenueVnd)}đ',
                  style: const TextStyle(
                    color: AppColors.charcoal,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),

          // ── Right: transaction count ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Column(
              children: [
                Text(
                  '${shift.transactionCount}',
                  style: const TextStyle(
                    color: AppColors.primaryRed,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'Giao dịch',
                  style: TextStyle(
                    color: AppColors.mediumGray,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Buttons ────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final BuildContext context;
  const _ActionRow({required this.context});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _PosActionButton(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Quét Mã QR',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.offlineQr),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PosActionButton(
              icon: Icons.camera_alt_rounded,
              label: 'Chụp Biển Số',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.plateCapture),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PosActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryRed,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        splashColor: AppColors.primaryRedDark,
        highlightColor: AppColors.primaryRedDark,
        onTap: onTap,
        child: Container(
          height: 80, // large touch target
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.white, size: 28),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Feed Header ───────────────────────────────────────────────────────────────

class _FeedHeader extends StatelessWidget {
  const _FeedHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF5F5F5),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: const Row(
        children: [
          Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.mediumGray),
          SizedBox(width: 8),
          Text(
            'GIAO DỊCH HÔM NAY',
            style: TextStyle(
              color: AppColors.mediumGray,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transaction Feed ──────────────────────────────────────────────────────────

class _TransactionFeed extends StatelessWidget {
  final List<ShiftTransaction> transactions;
  const _TransactionFeed({required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có giao dịch nào.',
          style: TextStyle(color: AppColors.mediumGray, fontSize: 15),
        ),
      );
    }

    return ListView.separated(
      physics: const ClampingScrollPhysics(), // lightweight on POS
      itemCount: transactions.length,
      separatorBuilder: (context, _) => const _FlatDivider(),
      itemBuilder: (_, i) => _TransactionTile(tx: transactions[i]),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final ShiftTransaction tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64, // consistent, chunky touch target height
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Pump indicator ─────────────────────────────────────────────
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              alignment: Alignment.center,
              child: Text(
                'P${tx.pumpNumber}',
                style: const TextStyle(
                  color: AppColors.charcoal,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // ── Plate + pump label ─────────────────────────────────────────
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.licensePlate,
                    style: const TextStyle(
                      color: AppColors.charcoal,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Vòi số ${tx.pumpNumber}  ·  ${_timeFmt.format(tx.time)}',
                    style: const TextStyle(
                      color: AppColors.mediumGray,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // ── Amount ────────────────────────────────────────────────────
            Text(
              '${_vndFmt.format(tx.amountVnd)}đ',
              style: const TextStyle(
                color: AppColors.primaryRed,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Flat Divider ──────────────────────────────────────────────────────────────

class _FlatDivider extends StatelessWidget {
  const _FlatDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0));
  }
}
