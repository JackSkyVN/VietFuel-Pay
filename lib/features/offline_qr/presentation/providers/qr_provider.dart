import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/qr_token_model.dart';
import '../../domain/entities/qr_token.dart';

// ── State ─────────────────────────────────────────────────────────────────

class QrState {
  final QrToken? token;
  final int remainingSeconds;
  final bool isGenerating;
  final String? errorMessage;

  const QrState({
    this.token,
    this.remainingSeconds = 0,
    this.isGenerating = false,
    this.errorMessage,
  });

  bool get hasToken => token != null;
  bool get isValid => token?.isValid ?? false;
  double get progressFraction =>
      hasToken ? remainingSeconds / 600 : 0; // out of 10 min

  QrState copyWith({
    QrToken? token,
    int? remainingSeconds,
    bool? isGenerating,
    String? errorMessage,
  }) =>
      QrState(
        token: token ?? this.token,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        isGenerating: isGenerating ?? this.isGenerating,
        errorMessage: errorMessage,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────

class QrNotifier extends StateNotifier<QrState> {
  Timer? _timer;

  QrNotifier() : super(const QrState()) {
    generate();
  }

  /// Generate (or re-generate) a fresh QR token and start the countdown.
  Future<void> generate() async {
    _timer?.cancel();
    state = state.copyWith(isGenerating: true, errorMessage: null);

    // Simulate network call (replace with real repo call)
    await Future.delayed(const Duration(milliseconds: 800));

    final token = QrTokenModel.generate(
      vehiclePlate: '51A-12345', // Replace with real user plate
      amountLimit: 5_000_000,
      ttl: const Duration(minutes: 10),
    );

    state = QrState(
      token: token,
      remainingSeconds: 600,
      isGenerating: false,
    );

    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = state.remainingSeconds - 1;
      if (remaining <= 0) {
        _timer?.cancel();
        state = state.copyWith(remainingSeconds: 0);
        // Token expired — auto-regenerate
        generate();
      } else {
        state = state.copyWith(remainingSeconds: remaining);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ── Provider ─────────────────────────────────────────────────────────────

final qrProvider =
    StateNotifierProvider<QrNotifier, QrState>((ref) => QrNotifier());
