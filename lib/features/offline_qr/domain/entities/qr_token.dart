import 'package:equatable/equatable.dart';

class QrToken extends Equatable {
  final String id;
  final String payload;     // JSON-serialized payment intent
  final String vehiclePlate;
  final double amountLimit;  // max VND allowed for this token
  final DateTime expiresAt;
  final bool isUsed;

  const QrToken({
    required this.id,
    required this.payload,
    required this.vehiclePlate,
    required this.amountLimit,
    required this.expiresAt,
    this.isUsed = false,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isExpired && !isUsed;

  Duration get timeUntilExpiry => expiresAt.difference(DateTime.now());

  QrToken copyWith({
    String? id,
    String? payload,
    String? vehiclePlate,
    double? amountLimit,
    DateTime? expiresAt,
    bool? isUsed,
  }) =>
      QrToken(
        id: id ?? this.id,
        payload: payload ?? this.payload,
        vehiclePlate: vehiclePlate ?? this.vehiclePlate,
        amountLimit: amountLimit ?? this.amountLimit,
        expiresAt: expiresAt ?? this.expiresAt,
        isUsed: isUsed ?? this.isUsed,
      );

  @override
  List<Object?> get props =>
      [id, payload, vehiclePlate, amountLimit, expiresAt, isUsed];
}
