import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../domain/entities/qr_token.dart';

class QrTokenModel extends QrToken {
  const QrTokenModel({
    required super.id,
    required super.payload,
    required super.vehiclePlate,
    required super.amountLimit,
    required super.expiresAt,
    super.isUsed,
  });

  /// Generate a fresh offline token (normally this comes from your backend).
  factory QrTokenModel.generate({
    required String vehiclePlate,
    double amountLimit = 5000000, // 5M VND
    Duration ttl = const Duration(minutes: 10),
  }) {
    final id = const Uuid().v4();
    final expiresAt = DateTime.now().add(ttl);

    final payloadMap = {
      'tokenId': id,
      'plate': vehiclePlate,
      'limit': amountLimit,
      'exp': expiresAt.millisecondsSinceEpoch,
      'iss': 'VietFuelPay',
      'type': 'OFFLINE_PAYMENT',
    };

    return QrTokenModel(
      id: id,
      payload: jsonEncode(payloadMap),
      vehiclePlate: vehiclePlate,
      amountLimit: amountLimit,
      expiresAt: expiresAt,
    );
  }

  factory QrTokenModel.fromJson(Map<String, dynamic> json) {
    return QrTokenModel(
      id: json['id'] as String,
      payload: json['payload'] as String,
      vehiclePlate: json['vehiclePlate'] as String,
      amountLimit: (json['amountLimit'] as num).toDouble(),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      isUsed: json['isUsed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'payload': payload,
        'vehiclePlate': vehiclePlate,
        'amountLimit': amountLimit,
        'expiresAt': expiresAt.toIso8601String(),
        'isUsed': isUsed,
      };
}
