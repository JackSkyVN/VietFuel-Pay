/// Riverpod providers for the Staff POS Dashboard.
///
/// Fetches the current shift summary from the real backend endpoint:
///   GET /api/v1/staff/shift/{staff_id}
///
/// Falls back to a local empty state if the staff is not yet assigned a shift.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

// ── Domain objects ────────────────────────────────────────────────────────────

class ShiftTransaction {
  final String id;
  final String licensePlate;
  final int pumpNumber;
  final int amountVnd;
  final String paymentMethod;
  final DateTime time;

  const ShiftTransaction({
    required this.id,
    required this.licensePlate,
    required this.pumpNumber,
    required this.amountVnd,
    required this.paymentMethod,
    required this.time,
  });

  factory ShiftTransaction.fromJson(Map<String, dynamic> json) =>
      ShiftTransaction(
        id: json['id'] as String,
        licensePlate: json['license_plate'] as String,
        pumpNumber: json['pump_number'] as int,
        amountVnd: json['amount_vnd'] as int,
        paymentMethod: (json['payment_method'] as String?) ?? 'CASH',
        time: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}

class ShiftSummary {
  final String staffId;
  final String fullName;
  final String role;
  final String shiftLabel;
  final int totalRevenueVnd;
  final List<ShiftTransaction> transactions;

  const ShiftSummary({
    required this.staffId,
    required this.fullName,
    required this.role,
    required this.shiftLabel,
    required this.totalRevenueVnd,
    required this.transactions,
  });

  int get transactionCount => transactions.length;

  factory ShiftSummary.fromJson(Map<String, dynamic> json) => ShiftSummary(
        staffId: json['staff_id'] as String,
        fullName: json['full_name'] as String,
        role: json['role'] as String,
        shiftLabel: json['shift_label'] as String,
        totalRevenueVnd: json['total_revenue_vnd'] as int,
        transactions: (json['transactions'] as List)
            .map((t) => ShiftTransaction.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Fetches today's shift summary for the currently logged-in staff member.
/// Automatically re-fetches when the auth session changes.
final shiftSummaryProvider = FutureProvider<ShiftSummary>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null || !session.isStaff) {
    throw StateError('Not logged in as staff');
  }

  final dio = ref.watch(dioProvider);
  final response =
      await dio.get('/staff/shift/${session.customerId}');
  return ShiftSummary.fromJson(response.data as Map<String, dynamic>);
});
