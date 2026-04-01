/// Riverpod providers for the dashboard feature.
///
/// Dependency chain:
///   dioProvider → TransactionRemoteDataSource → transactionHistoryProvider
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/datasources/transaction_remote_datasource.dart';
import '../../domain/entities/transaction.dart';

// ── Data source provider ──────────────────────────────────────────────────────

final transactionDataSourceProvider = Provider<TransactionRemoteDataSource>(
  (ref) => TransactionRemoteDataSource(ref.watch(dioProvider)),
);

// ── Transaction history provider ──────────────────────────────────────────────

/// FutureProvider that fetches the real transaction history from the API.
/// Change [_kDevPhone] to the seeded customer's phone number.
const _kDevPhone = '0901234567';

final transactionHistoryProvider =
    FutureProvider<List<Transaction>>((ref) async {
  final ds = ref.watch(transactionDataSourceProvider);
  final result = await ds.getTransactionHistory(phone: _kDevPhone);
  return result.items;
});
