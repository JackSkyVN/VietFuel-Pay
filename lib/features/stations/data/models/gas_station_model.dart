/// Data model – maps backend JSON → GasStation entity.
library;

import '../../domain/entities/gas_station.dart';

class GasStationModel extends GasStation {
  const GasStationModel({
    required super.id,
    required super.name,
    required super.address,
    required super.latitude,
    required super.longitude,
    required super.status,
  });

  factory GasStationModel.fromJson(Map<String, dynamic> json) {
    return GasStationModel(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      status: json['status'] as String? ?? 'OPEN',
    );
  }
}

class StationListResult {
  final int total;
  final List<GasStationModel> items;

  const StationListResult({required this.total, required this.items});

  factory StationListResult.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? [];
    return StationListResult(
      total: json['total'] as int? ?? raw.length,
      items: raw
          .map((e) => GasStationModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
