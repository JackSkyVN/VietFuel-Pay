import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/presentation/providers/auth_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Wallet Balance – fetched from the real DB, updated on every payment
// ─────────────────────────────────────────────────────────────────────────────

class WalletBalanceNotifier extends AsyncNotifier<double> {
  static const _baseUrl = kIsWeb
      ? 'http://127.0.0.1:8000'
      : 'http://10.0.2.2:8000';

  @override
  Future<double> build() async {
    // ref.watch is intentional: currentSessionProvider is null while SharedPreferences
    // loads on startup, then emits the real AuthSession. ref.watch re-runs build()
    // at that moment so the balance is fetched for the correct user, not stuck at 0.
    final session = ref.watch(currentSessionProvider);
    if (session == null) return 0;
    return _fetchBalance(session.customerId);
  }

  Future<double> _fetchBalance(String customerId) async {
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: '$_baseUrl/api/v1',
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 10),
          validateStatus: (s) => s != null && s < 600,
        ),
      );
      final response = await dio.get(
        '/customer/wallet/balance/dev',
        queryParameters: {'customer_id': customerId},
      );
      if (response.statusCode == 200 && response.data != null) {
        return ((response.data['wallet_balance'] as num?) ?? 0).toDouble();
      }
    } catch (_) {
      // Network issue — fall back to 0
    }
    return 0;
  }

  /// Instantly updates the displayed balance without a network round-trip.
  /// Call after a successful payment with the returned new_balance value.
  void setBalance(double newBalance) {
    state = AsyncData(newBalance);
  }

  /// Re-fetches the balance from the DB for the given customer.
  /// Call after login or after any operation that changes the DB balance.
  Future<void> refresh(String customerId) async {
    state = const AsyncLoading();
    state = AsyncData(await _fetchBalance(customerId));
  }
}

final walletBalanceProvider =
    AsyncNotifierProvider<WalletBalanceNotifier, double>(
      WalletBalanceNotifier.new,
    );

/// Synchronous convenience — returns 0 safely while loading or on error.
final walletBalanceSyncProvider = Provider<double>((ref) {
  // .when handles loading, error, and data safely — never throws
  return ref
      .watch(walletBalanceProvider)
      .when(data: (v) => v, loading: () => 0, error: (e, _) => 0);
});
