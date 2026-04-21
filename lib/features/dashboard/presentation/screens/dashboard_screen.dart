import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../shared/providers/pending_payment_provider.dart';
import '../../../../shared/providers/wallet_balance_provider.dart';
import '../../../../shared/widgets/animated_button.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../payment/presentation/widgets/payment_approval_sheet.dart';
import '../../domain/entities/transaction.dart';
import '../providers/transaction_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final ScrollController _scrollController = ScrollController();
  double _headerOpacity = 0;

  bool _approvalSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final opacity = (_scrollController.offset / 120).clamp(0.0, 1.0);
      if (opacity != _headerOpacity) setState(() => _headerOpacity = opacity);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ── Show approval sheet only when polling detects a payment ─────────────
    // Polling never starts on its own — only after "Pump Demo" is pressed.
    ref.listen<PendingPaymentState>(pendingPaymentProvider, (prev, next) {
      // Only react when info becomes non-null for the first time
      if (next.info != null && prev?.info == null && !_approvalSheetOpen) {
        _approvalSheetOpen = true;
        final payment = next.info!;
        final balance = ref.read(walletBalanceSyncProvider);
        showPaymentApprovalSheet(
          context: context,
          payment: payment,
          currentBalance: balance,
          onPaymentSuccess: (_) {
            // Re-fetch the real balance from DB for the logged-in user.
            // Using refresh() instead of invalidate() avoids the AsyncLoading
            // flash that can cause a white screen on slow networks.
            final customerId = ref.read(currentSessionProvider)?.customerId;
            if (customerId != null) {
              ref.read(walletBalanceProvider.notifier).refresh(customerId);
            }
            ref.read(pendingPaymentProvider.notifier).complete();
          },
          onDismiss: () {
            ref.read(pendingPaymentProvider.notifier).dismiss(payment.transactionId);
            _approvalSheetOpen = false;
          },
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildParallaxHeader(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 16),
                    _buildBalanceSection(),
                    const SizedBox(height: 16),
                    _buildQuickActions(),
                    const SizedBox(height: 20),
                    _buildLinkedCardsHeader(),
                    const SizedBox(height: 10),
                    _buildPaymentCardsScroll(),
                    const SizedBox(height: 20),
                    _buildTransactionHeader(),
                    const SizedBox(height: 10),
                    // ── Live transaction list (top 3) ──────────────────────
                    const _LiveTransactionList(),
                  ]),
                ),
              ),
            ],
          ),

          // Frosted top app bar on scroll
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _headerOpacity,
            child: _buildFrostedAppBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildParallaxHeader() {
    // Read the logged-in user's name from the auth session
    final session = ref.watch(currentSessionProvider);
    final fullName = session?.fullName ?? '';
    final parts = fullName.split(' ').where((s) => s.isNotEmpty).toList();
    final initials = parts.length > 1
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : (parts.isNotEmpty ? parts.first[0].toUpperCase() : '?');

    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A1A2E), AppColors.primaryRed],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.notifications_outlined,
                                color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.search_rounded,
                                color: Colors.white, size: 24),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${AppStrings.dashboardGreeting}, $fullName 👋',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1),
                  const SizedBox(height: 4),
                  Text(
                    'Ready to fuel up?',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 14,
                    ),
                  ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Pump simulator (demo only) ─────────────────────────────────────────────
  // Step 1: Call simulate-pump  → sets amount_vnd in the DB.
  // Step 2: On success, call startPolling() → polls every 3 s for up to 60 s.
  // Step 3: Notifier detects PENDING+amount → triggers ref.listen → sheet pops.
  // Polling is 100% OFF when this method is not called (i.e. on normal app open).
  Future<void> _simulatePump() async {
    const baseUrl = kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
    try {
      final dio = Dio(BaseOptions(
        baseUrl: '$baseUrl/api/v1',
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 10),
        validateStatus: (s) => s != null && s < 600,
        headers: {'Content-Type': 'application/json'},
      ));

      final response = await dio.post('/transactions/simulate-pump', data: {
        'amount_vnd': 150000,
        'license_plate': '29A-123.45',
        // Link the transaction to the logged-in customer so deductions hit
        // the correct wallet, not the hardcoded demo customer.
        'customer_id': ref.read(currentSessionProvider)?.customerId,
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Only start polling AFTER the pump successfully set the amount
        ref.read(pendingPaymentProvider.notifier).startPolling();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.sensors_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text('Tram xang da gui yeu cau. Dang cho xac nhan...')),
          ]),
          backgroundColor: AppColors.info,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          duration: const Duration(seconds: 4),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(response.data['detail'] ?? 'Loi ket noi tram xang.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        ));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Khong the ket noi den may chu.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ));
    }
  }

  Widget _buildFrostedAppBar() {
    return Container(
      height: MediaQuery.of(context).padding.top + 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: AppColors.borderGray.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text(
                AppStrings.appName,
                style: TextStyle(
                  color: AppColors.primaryRed,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              const Icon(Icons.notifications_outlined,
                  color: AppColors.charcoal, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceSection() {
    // Watch the reactive wallet balance — backed by real DB fetch on login
    final balance = ref.watch(walletBalanceSyncProvider);
    final formatted = '\u20ab ${_formatBalance(balance)}';

    return GlassCard(
      glassColor: Colors.white.withValues(alpha: 0.9),
      borderColor: AppColors.borderGray,
      boxShadow: AppColors.softShadow,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.balance,
                  style: const TextStyle(
                    color: AppColors.mediumGray,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                // AnimatedSwitcher gives a smooth fade when the number changes
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.25),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    formatted,
                    key: ValueKey(formatted),
                    style: const TextStyle(
                      color: AppColors.charcoal,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up_rounded,
                          color: AppColors.success, size: 13),
                      SizedBox(width: 4),
                      Text(
                        '+\u20ab120K this month',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          AnimatedPrimaryButton(
            label: 'Top Up',
            icon: Icons.add_rounded,
            width: 110,
            height: 44,
            borderRadius: 14,
            onTap: () {},
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.15);
  }

  /// Formats a VND double as "2,450,000" (dot-separated thousands).
  String _formatBalance(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction(icon: Icons.qr_code_rounded, label: 'QR Pay', color: AppColors.primaryRed, onTap: () {}),
      _QuickAction(icon: Icons.swap_horiz_rounded, label: 'Transfer', color: AppColors.info, onTap: () {}),
      _QuickAction(
        icon: Icons.sensors_rounded,
        label: 'Pump Demo',
        color: AppColors.warning,
        onTap: () => _simulatePump(),
      ),
      _QuickAction(icon: Icons.card_giftcard_rounded, label: 'Rewards', color: AppColors.success, onTap: () {}),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions
          .asMap()
          .entries
          .map(
            (e) => _QuickActionTile(action: e.value)
                .animate()
                .fadeIn(delay: (80 * e.key).ms, duration: 400.ms)
                .scale(begin: const Offset(0.85, 0.85)),
          )
          .toList(),
    );
  }

  Widget _buildLinkedCardsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          AppStrings.linkedCards,
          style: TextStyle(
            color: AppColors.charcoal,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextButton(
          onPressed: () {},
          child: const Text(AppStrings.viewAll),
        ),
      ],
    );
  }

  Widget _buildPaymentCardsScroll() {
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        clipBehavior: Clip.none,
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) => _PaymentCard(index: i)
            .animate()
            .fadeIn(delay: (100 * i).ms, duration: 500.ms)
            .slideX(begin: 0.2, curve: Curves.easeOut),
      ),
    );
  }

  Widget _buildTransactionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          AppStrings.recentTransactions,
          style: TextStyle(
            color: AppColors.charcoal,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () => ref.refresh(transactionHistoryProvider),
              child: const Icon(Icons.refresh_rounded,
                  color: AppColors.mediumGray, size: 18),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'See all',
                style: TextStyle(
                  color: AppColors.primaryRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Live Transaction List (Riverpod consumer) ─────────────────────────────────

class _LiveTransactionList extends ConsumerWidget {
  const _LiveTransactionList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTx = ref.watch(transactionHistoryProvider);

    return asyncTx.when(
      loading: () => _ShimmerTransactionList(),
      error: (err, stack) => _ErrorTransactionPanel(
        message: err.toString(),
        onRetry: () => ref.refresh(transactionHistoryProvider),
      ),
      data: (transactions) {
        if (transactions.isEmpty) {
          return _EmptyTransactionPanel();
        }
        final visible = transactions.take(3).toList();
        return Column(
          children: visible
              .asMap()
              .entries
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TransactionCard(transaction: e.value)
                      .animate()
                      .fadeIn(delay: (80 * e.key).ms, duration: 400.ms)
                      .slideX(begin: -0.1),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

// ── Shimmer skeleton loader ────────────────────────────────────────────────────

class _ShimmerTransactionList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade200,
            highlightColor: Colors.grey.shade50,
            child: Container(
              height: 78,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(height: 14, color: Colors.white,
                            width: double.infinity),
                        const SizedBox(height: 8),
                        Container(height: 10, color: Colors.white, width: 140),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(height: 14, color: Colors.white, width: 80),
                      const SizedBox(height: 8),
                      Container(height: 10, color: Colors.white, width: 52),
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

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorTransactionPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorTransactionPanel({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.primaryRed,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Could not load transactions',
            style: TextStyle(
              color: AppColors.charcoal,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Make sure the backend server is running.',
            style: TextStyle(
              color: AppColors.mediumGray,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1A2E), AppColors.primaryRed],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.92, 0.92));
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyTransactionPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 52, color: AppColors.mediumGray.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'No transactions yet',
            style: TextStyle(color: AppColors.mediumGray, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Real Transaction Card ─────────────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  final Transaction transaction;
  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final isSuccess = tx.isSuccess;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.softShadow,
        border: Border.all(
          color: isSuccess
              ? Colors.transparent
              : AppColors.primaryRed.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryRed.withValues(alpha: 0.15),
                  AppColors.primaryRed.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_gas_station_rounded,
              color: AppColors.primaryRed,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.stationName,
                  style: const TextStyle(
                    color: AppColors.charcoal,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSuccess
                            ? AppColors.success.withValues(alpha: 0.12)
                            : AppColors.primaryRed.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tx.status,
                        style: TextStyle(
                          color: isSuccess
                              ? AppColors.success
                              : AppColors.primaryRed,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${tx.fuelLiters}L · RON 95',
                      style: TextStyle(
                        color: AppColors.mediumGray,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Amount & time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-${tx.formattedAmount}',
                style: const TextStyle(
                  color: AppColors.charcoal,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tx.relativeTime,
                style: const TextStyle(
                  color: AppColors.mediumGray,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets (unchanged from original) ─────────────────────────────────────

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, this.onTap});
}

class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap ?? () {},
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: action.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(action.icon, color: action.color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            action.label,
            style: const TextStyle(
              color: AppColors.darkGray,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends ConsumerWidget {
  final int index;

  static const List<List<Color>> _palettes = [
    [Color(0xFF1A1A2E), Color(0xFFEE0033)],
    [Color(0xFF0F3460), Color(0xFF533483)],
    [Color(0xFF2D6A4F), Color(0xFF52B788)],
  ];

  static const List<String> _networks = ['VISA', 'MASTERCARD', 'JCB'];
  static const List<String> _lastFours = ['4242', '8888', '3141'];

  const _PaymentCard({required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = _palettes[index % _palettes.length];
    final network = _networks[index % _networks.length];
    final last4 = _lastFours[index % _lastFours.length];
    final session = ref.watch(currentSessionProvider);
    final cardName = (session?.fullName ?? '').toUpperCase();

    return Container(
      width: 195,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors[0].withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                network,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const Icon(Icons.wifi_rounded, color: Colors.white54, size: 16),
            ],
          ),
          const Spacer(),
          Text(
            '•••• $last4',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  cardName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '12/27',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
