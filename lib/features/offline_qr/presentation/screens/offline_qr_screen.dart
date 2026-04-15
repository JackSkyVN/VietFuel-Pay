import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../providers/qr_provider.dart';

class OfflineQrScreen extends ConsumerStatefulWidget {
  const OfflineQrScreen({super.key});

  @override
  ConsumerState<OfflineQrScreen> createState() => _OfflineQrScreenState();
}

class _OfflineQrScreenState extends ConsumerState<OfflineQrScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _rotateCtrl;
  late AnimationController _glowCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color _timerColor(int seconds) {
    if (seconds > 300) return AppColors.success;
    if (seconds > 120) return AppColors.warning;
    return AppColors.primaryRed;
  }

  @override
  Widget build(BuildContext context) {
    final qrState = ref.watch(qrProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.charcoal,
      body: Stack(
        children: [
          // ── Animated background gradient ──────────────────────────────
          _AnimatedBackground(pulseCtrl: _pulseCtrl),

          // ── Main content ──────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: qrState.isGenerating
                      ? _buildLoading()
                      : _buildContent(qrState, size),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppStrings.offlineModeTitle,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _glowCtrl,
                      builder: (_, _) => Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            AppColors.success,
                            AppColors.successLight,
                            _glowCtrl.value,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.success.withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      AppStrings.qrLive,
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Chip: Offline mode badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.wifi_off_rounded,
                    color: AppColors.warning, size: 13),
                SizedBox(width: 5),
                Text(
                  'Offline',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, curve: Curves.easeOut);
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppColors.primaryRed,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Generating secure QR…',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Widget _buildContent(QrState qrState, Size size) {
    final qrSize = size.width * 0.62;
    final timerColor = _timerColor(qrState.remainingSeconds);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        children: [
          // ── QR Code section ────────────────────────────────────────────
          _buildQrSection(qrState, qrSize),
          const SizedBox(height: 28),

          // ── Timer & progress ──────────────────────────────────────────
          _buildTimer(qrState, timerColor),
          const SizedBox(height: 28),

          // ── Info cards row ────────────────────────────────────────────
          _buildInfoRow(qrState),
          const SizedBox(height: 28),

          // ── Scannable hint ────────────────────────────────────────────
          _buildScanHint(),
          const SizedBox(height: 24),

          // ── Regenerate button ─────────────────────────────────────────
          _buildRegenerateButton(),
        ],
      ),
    );
  }

  Widget _buildQrSection(QrState qrState, double qrSize) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // ── Outermost pulsating ring ─────────────────────────────────────
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, _) {
            final pulse = 1.0 + (_pulseCtrl.value * 0.08);
            return Container(
              width: qrSize + 96 * pulse,
              height: qrSize + 96 * pulse,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      AppColors.primaryRed.withValues(alpha: 0.12 + 0.08 * _pulseCtrl.value),
                  width: 1.5,
                ),
              ),
            );
          },
        ),

        // ── Second pulsating ring ──────────────────────────────────────
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, _) {
            final pulse = 1.0 + (_pulseCtrl.value * 0.05);
            return Container(
              width: qrSize + 60 * pulse,
              height: qrSize + 60 * pulse,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      AppColors.primaryRed.withValues(alpha: 0.2 + 0.1 * _pulseCtrl.value),
                  width: 1.5,
                ),
              ),
            );
          },
        ),

        // ── Rotating dashed ring ───────────────────────────────────────
        AnimatedBuilder(
          animation: _rotateCtrl,
          builder: (_, _) => Transform.rotate(
            angle: _rotateCtrl.value * 2 * math.pi,
            child: CustomPaint(
              size: Size(qrSize + 40, qrSize + 40),
              painter: _DashedCirclePainter(
                color: AppColors.primaryRed.withValues(alpha: 0.55),
                dashCount: 24,
                strokeWidth: 2.5,
              ),
            ),
          ),
        ),

        // ── Inner glow ring ────────────────────────────────────────────
        AnimatedBuilder(
          animation: _glowCtrl,
          builder: (_, _) => Container(
            width: qrSize + 24,
            height: qrSize + 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryRed
                      .withValues(alpha: 0.25 + 0.2 * _glowCtrl.value),
                  blurRadius: 30 + 10 * _glowCtrl.value,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
        ),

        // ── QR Card ────────────────────────────────────────────────────
        Container(
          width: qrSize + 16,
          height: qrSize + 16,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 40,
                spreadRadius: 0,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Viettel logo placeholder
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'VIET\nFUEL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.local_gas_station_rounded,
                    color: AppColors.primaryRed,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // QR Code
              if (qrState.token != null)
                QrImageView(
                  data: qrState.token!.payload,
                  version: QrVersions.auto,
                  size: qrSize - 64,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.charcoal,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.charcoal,
                  ),
                  embeddedImage:
                      null, // replace with AssetImage for logo overlay
                )
              else
                SizedBox(
                  width: qrSize - 64,
                  height: qrSize - 64,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ).animate().scale(
              begin: const Offset(0.85, 0.85),
              duration: 600.ms,
              curve: Curves.elasticOut,
            ),
      ],
    );
  }

  Widget _buildTimer(QrState qrState, Color timerColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.timer_rounded, color: timerColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.qrExpires,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.5),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  _formatTime(qrState.remainingSeconds),
                  key: ValueKey(qrState.remainingSeconds ~/ 1),
                  style: TextStyle(
                    color: timerColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: qrState.progressFraction,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(timerColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.2);
  }

  Widget _buildInfoRow(QrState qrState) {
    return Row(
      children: [
        Expanded(
          child: _InfoChip(
            icon: Icons.directions_car_rounded,
            label: 'Vehicle',
            value: qrState.token?.vehiclePlate ?? '—',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _InfoChip(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Max Limit',
            value: qrState.token != null
                ? '${(qrState.token!.amountLimit / 1000).round()}K ₫'
                : '—',
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.2);
  }

  Widget _buildScanHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryRed.withValues(alpha: 0.18),
            AppColors.primaryRed.withValues(alpha: 0.06),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryRed,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              AppStrings.scanAtStation,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms);
  }

  Widget _buildRegenerateButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        ref.read(qrProvider.notifier).generate();
      },
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.redGlow,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              AppStrings.regenerate,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 500.ms, duration: 400.ms)
        .slideY(begin: 0.3, curve: Curves.easeOut);
  }
}

// ── Info chip ─────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryRed, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated Background ────────────────────────────────────────────────────
class _AnimatedBackground extends StatelessWidget {
  final AnimationController pulseCtrl;

  const _AnimatedBackground({required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (_, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A1A2E),
                Color.lerp(
                  const Color(0xFF16213E),
                  const Color(0xFF1A1035),
                  pulseCtrl.value,
                )!,
                const Color(0xFF0F3460),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Dashed Circle Painter ─────────────────────────────────────────────────
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final int dashCount;
  final double strokeWidth;

  _DashedCirclePainter({
    required this.color,
    required this.dashCount,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;
    final dashAngle = (2 * math.pi) / dashCount;
    final gapFraction = 0.4; // 40% gap between dashes

    for (int i = 0; i < dashCount; i++) {
      final startAngle = dashAngle * i;
      final sweepAngle = dashAngle * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) =>
      old.color != color || old.dashCount != dashCount;
}
