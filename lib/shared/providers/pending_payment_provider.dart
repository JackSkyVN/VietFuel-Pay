import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class PendingPaymentInfo {
  final String transactionId;
  final String licensePlate;
  final int amountVnd;
  final String? stationId;
  final String? pumpId;

  const PendingPaymentInfo({
    required this.transactionId,
    required this.licensePlate,
    required this.amountVnd,
    this.stationId,
    this.pumpId,
  });

  factory PendingPaymentInfo.fromJson(Map<String, dynamic> json) {
    return PendingPaymentInfo(
      transactionId: json['transaction_id'] as String,
      licensePlate: json['license_plate'] as String,
      amountVnd: (json['amount_vnd'] as num).toInt(),
      stationId: json['station_id'] as String?,
      pumpId: json['pump_id'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier state
// ─────────────────────────────────────────────────────────────────────────────

class PendingPaymentState {
  /// null  = idle / nothing detected yet
  /// non-null = pump sent a request, show the sheet
  final PendingPaymentInfo? info;

  /// true while simulate-pump was called and we are actively polling
  final bool isPolling;

  const PendingPaymentState({this.info, this.isPolling = false});

  PendingPaymentState copyWith({PendingPaymentInfo? info, bool? isPolling, bool clearInfo = false}) {
    return PendingPaymentState(
      info: clearInfo ? null : (info ?? this.info),
      isPolling: isPolling ?? this.isPolling,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

/// Lifecycle:
///   1. [startPolling] is called by "Pump Demo" button AFTER simulate-pump succeeds.
///   2. Polls every 3 s for up to 60 s looking for a PENDING transaction with amount > 0.
///   3. When found → state.info becomes non-null → dashboard shows the sheet.
///   4. [complete] is called on payment success (transaction already COMPLETED in DB).
///   5. [dismiss] is called on cancel → calls dismiss-pump API to clear amount_vnd.
///
/// The notifier is IDLE on app start — no polling, no popup.
class PendingPaymentNotifier extends AutoDisposeNotifier<PendingPaymentState> {
  static const _kBaseUrl =
      kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
  static const _kPollInterval = Duration(seconds: 3);
  static const _kMaxPolls = 20; // 60 s timeout

  Timer? _timer;
  int _pollCount = 0;

  final _dio = Dio(BaseOptions(
    baseUrl: '$_kBaseUrl/api/v1',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 8),
    validateStatus: (s) => s != null && s < 600,
  ));

  @override
  PendingPaymentState build() {
    ref.onDispose(_stopPolling);
    // Always idle on first build — polling never starts automatically
    return const PendingPaymentState();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Called by "Pump Demo" after simulate-pump succeeds.
  /// Starts polling until a payment request is detected.
  void startPolling() {
    _stopPolling();
    _pollCount = 0;
    state = const PendingPaymentState(isPolling: true);
    _timer = Timer.periodic(_kPollInterval, (_) => _poll());
    _poll(); // immediate first check
  }

  /// Called when user taps Confirm and payment COMPLETED.
  /// Just clear local state — DB already has COMPLETED status so polling won't match.
  void complete() {
    _stopPolling();
    state = const PendingPaymentState();
  }

  /// Called when user taps Cancel.
  /// Clears local state immediately and tells the backend to zero out amount_vnd.
  Future<void> dismiss(String transactionId) async {
    _stopPolling();
    state = const PendingPaymentState(); // clear UI immediately

    // Fire-and-forget: clear amount_vnd in the DB
    try {
      await _dio.post('/transactions/$transactionId/dismiss-pump');
    } catch (_) {
      // Best-effort — if this fails the transaction stays at amount_vnd > 0
      // but since polling is stopped it won't reappear until the next
      // "Pump Demo" press, which calls simulate-pump and resets everything.
    }
  }

  // ── Internal polling ───────────────────────────────────────────────────────

  Future<void> _poll() async {
    // If a payment was already detected, stop polling
    if (state.info != null) {
      _stopPolling();
      return;
    }

    // Timeout guard
    _pollCount++;
    if (_pollCount > _kMaxPolls) {
      _stopPolling();
      state = const PendingPaymentState(); // timed out, back to idle
      return;
    }

    try {
      final response = await _dio.get('/transactions/awaiting-payment');
      if (response.statusCode == 200 && response.data != null) {
        final info = PendingPaymentInfo.fromJson(
          response.data as Map<String, dynamic>,
        );
        _stopPolling();
        // Set info → triggers ref.listen in dashboard → sheet shows
        state = PendingPaymentState(info: info, isPolling: false);
      }
      // null body → nothing ready yet, keep polling
    } catch (_) {
      // Network error → keep polling silently
    }
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }
}

final pendingPaymentProvider =
    NotifierProvider.autoDispose<PendingPaymentNotifier, PendingPaymentState>(
  PendingPaymentNotifier.new,
);
