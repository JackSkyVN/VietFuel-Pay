/// Riverpod providers for the dashboard feature.
///
/// Dependency chain:
///   dioProvider → TransactionRemoteDataSource → transactionHistoryProvider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/transaction_remote_datasource.dart';
import '../../domain/entities/transaction.dart';

// ── Data source provider ──────────────────────────────────────────────────────

final transactionDataSourceProvider = Provider<TransactionRemoteDataSource>(
  (ref) => TransactionRemoteDataSource(ref.watch(dioProvider)),
);

// ── Transaction history provider ──────────────────────────────────────────────

/// FutureProvider that fetches the real transaction history for the currently
/// logged-in customer (phone comes from auth session, not hardcoded).
final transactionHistoryProvider =
    FutureProvider<List<Transaction>>((ref) async {
  final phone = ref.watch(sessionPhoneProvider); // from AuthSession
  if (phone == null) return []; // session still loading or logged out
  final ds = ref.watch(transactionDataSourceProvider);
  final result = await ds.getTransactionHistory(phone: phone);
  return result.items;
});
