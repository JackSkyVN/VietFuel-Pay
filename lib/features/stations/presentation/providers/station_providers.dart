/// Riverpod providers for the Station Map feature.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/datasources/station_remote_datasource.dart';
import '../../domain/entities/gas_station.dart';

// ── Data source ───────────────────────────────────────────────────────────────

final stationDataSourceProvider = Provider<StationRemoteDataSource>(
  (ref) => StationRemoteDataSource(ref.watch(dioProvider)),
);

// ── Station list ──────────────────────────────────────────────────────────────

/// Fetches all gas stations from the backend. Auto-cached by Riverpod.
final stationsProvider = FutureProvider<List<GasStation>>((ref) async {
  final ds = ref.watch(stationDataSourceProvider);
  final result = await ds.getStations();
  return result.items;
});
