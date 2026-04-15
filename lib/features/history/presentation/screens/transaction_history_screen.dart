/// Full Transaction History Screen with date filtering,
/// grouped sections, and tap-to-expand detail cards.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../dashboard/domain/entities/transaction.dart';
import '../../../dashboard/presentation/providers/transaction_providers.dart';

// ── Filter enum ──────────────────────────────────────────────────────────────

enum _TxFilter { all, week, month }

extension _TxFilterLabel on _TxFilter {
  String get label {
    switch (this) {
      case _TxFilter.all:
        return 'All Time';
      case _TxFilter.week:
        return 'This Week';
      case _TxFilter.month:
        return 'This Month';
    }
  }
}

// ── Screen ───────────────────────────────────────────────────────────────────

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  _TxFilter _filter = _TxFilter.all;

  List<Transaction> _applyFilter(List<Transaction> all) {
    final now = DateTime.now();
    switch (_filter) {
      case _TxFilter.all:
        return all;
      case _TxFilter.week:
        return all
            .where((t) => now.difference(t.createdAt).inDays <= 7)
            .toList();
      case _TxFilter.month:
        return all
            .where((t) => now.difference(t.createdAt).inDays <= 30)
            .toList();
    }
  }

  /// Group transactions by human-readable date bucket.
  Map<String, List<Transaction>> _groupByDate(List<Transaction> txs) {
    final grouped = <String, List<Transaction>>{};
    final now = DateTime.now();
    for (final tx in txs) {
      final d = tx.createdAt.toLocal();
      final diff = DateTime(now.year, now.month, now.day)
          .difference(DateTime(d.year, d.month, d.day))
          .inDays;
      final label = diff == 0
          ? 'Today'
          : diff == 1
              ? 'Yesterday'
              : '${d.day} ${_monthName(d.month)} ${d.year}';
      grouped.putIfAbsent(label, () => []).add(tx);
    }
    return grouped;
  }

  String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  @override
  Widget build(BuildContext context) {
    final asyncTx = ref.watch(transactionHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildHeader(),
          SliverToBoxAdapter(child: _buildFilterChips()),
          SliverToBoxAdapter(child: const SizedBox(height: 8)),
          asyncTx.when(
            loading: () => _buildShimmerSliver(),
            error: (e, _) => SliverToBoxAdapter(child: _buildError(e)),
            data: (all) {
              final filtered = _applyFilter(all);
              if (filtered.isEmpty) {
                return SliverToBoxAdapter(child: _buildEmpty());
              }
              final grouped = _groupByDate(filtered);
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, idx) {
                      final keys = grouped.keys.toList();
                      int count = 0;
                      for (final key in keys) {
                        // Section header
                        if (idx == count) {
                          return _SectionHeader(label: key)
                              .animate()
                              .fadeIn(delay: (40 * count).ms, duration: 300.ms);
                        }
                        count++;
                        final txs = grouped[key]!;
                        for (final tx in txs) {
                          if (idx == count) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ExpandableTransactionCard(tx: tx)
                                  .animate()
                                  .fadeIn(
                                      delay: (50 * count).ms, duration: 350.ms)
                                  .slideX(begin: -0.05),
                            );
                          }
                          count++;
                        }
                      }
                      return null;
                    },
                    childCount: grouped.values
                            .fold<int>(0, (s, v) => s + v.length) +
                        grouped.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 130,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
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
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Transaction History',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
                  const SizedBox(height: 4),
                  Text(
                    'All your fuel transactions in one place',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                  ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: _TxFilter.values.map((f) {
          final active = _filter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? AppColors.primaryRed : AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: active ? AppColors.redGlow : AppColors.softShadow,
                ),
                child: Text(
                  f.label,
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.mediumGray,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildShimmerSliver() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Shimmer.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.grey.shade50,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          childCount: 5,
        ),
      ),
    );
  }

  Widget _buildError(Object e) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded,
              color: AppColors.primaryRed, size: 48),
          const SizedBox(height: 16),
          const Text('Could not load transactions',
              style: TextStyle(
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => ref.refresh(transactionHistoryProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 60, color: AppColors.mediumGray.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Text('No transactions in this period',
              style: TextStyle(color: AppColors.mediumGray, fontSize: 14)),
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.charcoal,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Divider(color: AppColors.borderGray, thickness: 1)),
        ],
      ),
    );
  }
}

// ── Expandable Transaction Card ───────────────────────────────────────────────

class _ExpandableTransactionCard extends StatefulWidget {
  final Transaction tx;
  const _ExpandableTransactionCard({required this.tx});

  @override
  State<_ExpandableTransactionCard> createState() =>
      _ExpandableTransactionCardState();
}

class _ExpandableTransactionCardState
    extends State<_ExpandableTransactionCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _expanded ? AppColors.cardShadow : AppColors.softShadow,
          border: Border.all(
            color: _expanded
                ? AppColors.primaryRed.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            // ── Row ──────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFEBEE), Color(0xFFFFF5F5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.local_gas_station_rounded,
                        color: AppColors.primaryRed, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.stationName,
                          style: const TextStyle(
                              color: AppColors.charcoal,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _StatusChip(isSuccess: tx.isSuccess),
                            const SizedBox(width: 8),
                            Text(
                              '${tx.fuelLiters}L',
                              style: const TextStyle(
                                  color: AppColors.mediumGray, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '-${tx.formattedAmount}',
                        style: const TextStyle(
                            color: AppColors.charcoal,
                            fontSize: 15,
                            fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(tx.relativeTime,
                          style: const TextStyle(
                              color: AppColors.mediumGray, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.mediumGray, size: 20),
                  ),
                ],
              ),
            ),
            // ── Expanded detail ───────────────────────────────────────────────
            SizeTransition(
              sizeFactor: _expandAnim,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                        label: 'Transaction ID',
                        value: tx.id.substring(0, 8).toUpperCase()),
                    _DetailRow(label: 'License Plate', value: tx.licensePlate),
                    _DetailRow(label: 'Pump', value: tx.pumpId ?? '—'),
                    _DetailRow(label: 'Station ID', value: tx.stationId ?? '—'),
                    _DetailRow(label: 'Payment', value: tx.paymentMethod),
                    _DetailRow(
                      label: 'Completed',
                      value: tx.completedAt != null
                          ? _formatFull(tx.completedAt!)
                          : '—',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFull(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusChip extends StatelessWidget {
  final bool isSuccess;
  const _StatusChip({required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSuccess
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.primaryRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isSuccess ? 'SUCCESS' : 'FAILED',
        style: TextStyle(
          color: isSuccess ? AppColors.success : AppColors.primaryRed,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.mediumGray,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: const TextStyle(
                  color: AppColors.charcoal,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
