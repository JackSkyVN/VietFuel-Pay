/// License Plate Scanner Screen
/// Web: browser file-picker → simulated OCR scan animation
/// Android/iOS: native camera input
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';

// ── Scanner state ─────────────────────────────────────────────────────────────

enum _ScanState { idle, picked, scanning, validated, failed }

// ── Screen ────────────────────────────────────────────────────────────────────

class PlateScannerScreen extends ConsumerStatefulWidget {
  const PlateScannerScreen({super.key});

  @override
  ConsumerState<PlateScannerScreen> createState() => _PlateScannerScreenState();
}

class _PlateScannerScreenState extends ConsumerState<PlateScannerScreen>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  _ScanState _state = _ScanState.idle;
  Uint8List? _imageBytes;
  String _detectedPlate = '';
  double _confidence = 0;
  String? _errorMsg;

  // scan-line animation
  late final AnimationController _scanLineCtrl;
  late final Animation<double> _scanLineAnim;

  // pulse animation for corner brackets
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scanLineAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanLineCtrl, curve: Curves.easeInOut),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(_pulseCtrl);
  }

  @override
  void dispose() {
    _scanLineCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1280,
      );
      if (xFile == null) return;
      final bytes = await xFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _state = _ScanState.picked;
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'Could not access camera/gallery.';
        _state = _ScanState.failed;
      });
    }
  }

  Future<void> _runScan() async {
    if (_imageBytes == null) return;
    setState(() => _state = _ScanState.scanning);
    _scanLineCtrl.repeat();

    // Simulate OCR processing delay
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    _scanLineCtrl.stop();

    // Simulate detected plate
    const detected = '51G-123.45';
    setState(() {
      _detectedPlate = detected;
      _confidence = 0.97;
      _state = _ScanState.validated;
    });
  }

  void _reset() {
    setState(() {
      _state = _ScanState.idle;
      _imageBytes = null;
      _detectedPlate = '';
      _confidence = 0;
      _errorMsg = null;
    });
    _scanLineCtrl.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D1A), Color(0xFF1A1A2E), Color(0xFF0D0D1A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white, size: 20),
          ),
          const Expanded(
            child: Text(
              'License Plate Scanner',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildBody() {
    switch (_state) {
      case _ScanState.idle:
        return _buildIdleState();
      case _ScanState.picked:
        return _buildPickedState();
      case _ScanState.scanning:
        return _buildScanningState();
      case _ScanState.validated:
        return _buildValidatedState();
      case _ScanState.failed:
        return _buildFailedState();
    }
  }

  // ── Idle — show scan frame + instructions ─────────────────────────────────

  Widget _buildIdleState() {
    return Column(
      children: [
        const SizedBox(height: 32),
        // Animated scan frame
        Center(
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, _) {
              return CustomPaint(
                painter: _ScanFramePainter(
                    opacity: _pulseAnim.value, color: AppColors.primaryRed),
                child: Container(
                  width: 280,
                  height: 140,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.document_scanner_outlined,
                        color: Colors.white.withValues(alpha: 0.35),
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Position plate here',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.9, 0.9)),
        ),
        const SizedBox(height: 32),
        Text(
          'Take a clear photo of your\nlicense plate or vehicle',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 15,
            height: 1.5,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
          child: Column(
            children: [
              _GlowButton(
                label: 'Open Camera',
                icon: Icons.camera_alt_rounded,
                onTap: () => _pickImage(ImageSource.camera),
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.3),
              const SizedBox(height: 14),
              _OutlineButton(
                label: 'Choose from Gallery',
                icon: Icons.photo_library_rounded,
                onTap: () => _pickImage(ImageSource.gallery),
              ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(begin: 0.3),
            ],
          ),
        ),
      ],
    );
  }

  // ── Picked — show selected image + scan button ────────────────────────────

  Widget _buildPickedState() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(
              _imageBytes!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),
        const SizedBox(height: 24),
        Text(
          'Image selected — ready to scan',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
          child: Column(
            children: [
              _GlowButton(
                label: 'Scan Plate',
                icon: Icons.document_scanner_rounded,
                onTap: _runScan,
              ),
              const SizedBox(height: 14),
              _OutlineButton(
                label: 'Retake Photo',
                icon: Icons.refresh_rounded,
                onTap: _reset,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Scanning — red sweep line animation ──────────────────────────────────

  Widget _buildScanningState() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.memory(
                  _imageBytes!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              // Scan line overlay
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AnimatedBuilder(
                  animation: _scanLineAnim,
                  builder: (_, _) {
                    return CustomPaint(
                      painter: _ScanLinePainter(_scanLineAnim.value),
                      child: const SizedBox(height: 200, width: double.infinity),
                    );
                  },
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 32),
        const CircularProgressIndicator(
          color: AppColors.primaryRed,
          strokeWidth: 2.5,
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 16),
        const Text(
          'Scanning license plate…',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 8),
        Text(
          'Powered by Smart AI Vision',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
        ),
      ],
    );
  }

  // ── Validated ─────────────────────────────────────────────────────────────

  Widget _buildValidatedState() {
    final pct = (_confidence * 100).toInt();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      child: Column(
        children: [
          // Success badge
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF00C853), Color(0xFF69F0AE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.4),
                    blurRadius: 24,
                    spreadRadius: 4),
              ],
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
          ).animate().scale(begin: const Offset(0.5, 0.5), duration: 500.ms, curve: Curves.elasticOut),

          const SizedBox(height: 20),

          const Text(
            'Plate Detected!',
            style: TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

          const SizedBox(height: 24),

          // Plate number card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFF2D2D4E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.primaryRed.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primaryRed.withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 2),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'DETECTED PLATE',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(
                  _detectedPlate,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 16),
                // Confidence bar
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Confidence',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12)),
                        Text('$pct%',
                            style: const TextStyle(
                                color: AppColors.success,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _confidence,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.success),
                        minHeight: 6,
                      )
                          .animate()
                          .custom(
                            delay: 400.ms,
                            duration: 800.ms,
                            builder: (_, v, child) =>
                                ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _confidence * v,
                                backgroundColor: Colors.white.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.success),
                                minHeight: 6,
                              ),
                            ),
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.2),

          const SizedBox(height: 24),

          // Vehicle match info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_car_rounded,
                      color: AppColors.info, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Honda Air Blade 160',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Matched to your profile',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12)),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.verified_rounded,
                    color: AppColors.success, size: 20),
              ],
            ),
          ).animate().fadeIn(delay: 450.ms, duration: 400.ms),

          const SizedBox(height: 32),

          _GlowButton(
            label: 'Save & Continue',
            icon: Icons.check_circle_rounded,
            onTap: () => Navigator.of(context).pop(_detectedPlate),
          ).animate().fadeIn(delay: 550.ms, duration: 400.ms).slideY(begin: 0.2),

          const SizedBox(height: 14),

          _OutlineButton(
            label: 'Scan Again',
            icon: Icons.refresh_rounded,
            onTap: _reset,
          ).animate().fadeIn(delay: 600.ms, duration: 400.ms),
        ],
      ),
    );
  }

  // ── Failed ────────────────────────────────────────────────────────────────

  Widget _buildFailedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: AppColors.primaryRed, size: 40),
            ).animate().scale(begin: const Offset(0.5, 0.5), duration: 400.ms),
            const SizedBox(height: 20),
            Text(
              _errorMsg ?? 'Scan failed',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 32),
            _GlowButton(
              label: 'Try Again',
              icon: Icons.refresh_rounded,
              onTap: _reset,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom Painters ───────────────────────────────────────────────────────────

class _ScanFramePainter extends CustomPainter {
  final double opacity;
  final Color color;
  const _ScanFramePainter({required this.opacity, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    const r = 10.0;

    // Top-left
    canvas.drawLine(
        Offset(r, len), Offset(r, r), paint);
    canvas.drawLine(
        Offset(r, r), Offset(len, r), paint);
    // Top-right
    canvas.drawLine(
        Offset(size.width - len, r), Offset(size.width - r, r), paint);
    canvas.drawLine(
        Offset(size.width - r, r), Offset(size.width - r, len), paint);
    // Bottom-left
    canvas.drawLine(
        Offset(r, size.height - len), Offset(r, size.height - r), paint);
    canvas.drawLine(
        Offset(r, size.height - r), Offset(len, size.height - r), paint);
    // Bottom-right
    canvas.drawLine(
        Offset(size.width - len, size.height - r),
        Offset(size.width - r, size.height - r), paint);
    canvas.drawLine(
        Offset(size.width - r, size.height - len),
        Offset(size.width - r, size.height - r), paint);
  }

  @override
  bool shouldRepaint(_ScanFramePainter old) => old.opacity != opacity;
}

class _ScanLinePainter extends CustomPainter {
  final double progress;
  const _ScanLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final gradient = LinearGradient(
      colors: [
        AppColors.primaryRed.withValues(alpha: 0),
        AppColors.primaryRed.withValues(alpha: 0.85),
        AppColors.primaryRed.withValues(alpha: 0),
      ],
    );
    final rect = Rect.fromLTWH(0, y - 20, size.width, 40);
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);

    final linePaint = Paint()
      ..color = AppColors.primaryRed
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
}

// ── Reusable buttons ──────────────────────────────────────────────────────────

class _GlowButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GlowButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryRed, Color(0xFFFF4060)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.redGlow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _OutlineButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
