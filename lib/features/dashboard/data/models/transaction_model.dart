/// Transaction data model (DTO) – maps JSON from the FastAPI /history endpoint.
library;

import '../../domain/entities/transaction.dart';

class TransactionModel extends Transaction {
  const TransactionModel({
    required super.id,
    required super.licensePlate,
    required super.fuelLiters,
    required super.amountVnd,
    required super.status,
    required super.paymentMethod,
    super.stationId,
    super.pumpId,
    required super.createdAt,
    super.completedAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      licensePlate: json['license_plate'] as String,
      fuelLiters: (json['fuel_liters'] as num).toDouble(),
      amountVnd: (json['amount_vnd'] as num).toDouble(),
      status: json['status'] as String,
      paymentMethod: json['payment_method'] as String,
      stationId: json['station_id'] as String?,
      pumpId: json['pump_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }
}

// ── Paginated response wrapper ────────────────────────────────────────────────

class TransactionHistoryResult {
  final int total;
  final int page;
  final int pageSize;
  final List<TransactionModel> items;

  const TransactionHistoryResult({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.items,
  });

  factory TransactionHistoryResult.fromJson(Map<String, dynamic> json) {
    return TransactionHistoryResult(
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      items: (json['items'] as List<dynamic>)
          .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
