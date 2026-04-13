/// GasStation domain entity.
library;

import 'package:equatable/equatable.dart';

class GasStation extends Equatable {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String status; // OPEN | BUSY | CLOSED

  const GasStation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.status,
  });

  bool get isOpen => status == 'OPEN';
  bool get isBusy => status == 'BUSY';
  bool get isClosed => status == 'CLOSED';

  @override
  List<Object?> get props => [id];
}
