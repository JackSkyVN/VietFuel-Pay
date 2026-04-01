/// Transaction entity – domain layer representation of a fuel transaction.
library;

import 'package:equatable/equatable.dart';

class Transaction extends Equatable {
  final String id;
  final String licensePlate;
  final double fuelLiters;
  final double amountVnd;
  final String status;
  final String paymentMethod;
  final String? stationId;
  final String? pumpId;
  final DateTime createdAt;
  final DateTime? completedAt;

  const Transaction({
    required this.id,
    required this.licensePlate,
    required this.fuelLiters,
    required this.amountVnd,
    required this.status,
    required this.paymentMethod,
    this.stationId,
    this.pumpId,
    required this.createdAt,
    this.completedAt,
  });

  /// Human-readable station name derived from station_id.
  String get stationName {
    const map = {
      'STN-001': 'Viettel Station — Q.1',
      'STN-002': 'Shell Cộng Hòa',
      'STN-003': 'Viettel Station — Q.7',
    };
    return map[stationId] ?? stationId ?? 'Unknown Station';
  }

  /// Formatted amount string (e.g. "₫180,000").
  String get formattedAmount {
    final n = amountVnd.toInt();
    final s = n.toString();
    final buf = StringBuffer('₫');
    int start = s.length % 3;
    if (start > 0) buf.write(s.substring(0, start));
    for (var i = start; i < s.length; i += 3) {
      if (i > 0 || start > 0) buf.write(',');
      buf.write(s.substring(i, i + 3));
    }
    return buf.toString();
  }

  /// Relative time string.
  String get relativeTime {
    final diff = DateTime.now().toUtc().difference(createdAt.toUtc());
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  bool get isSuccess => status == 'SUCCESS';

  @override
  List<Object?> get props => [id];
}
