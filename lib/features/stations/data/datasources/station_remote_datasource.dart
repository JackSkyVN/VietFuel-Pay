/// Remote data source – calls GET /api/v1/stations.
library;

import 'package:dio/dio.dart';

import '../models/gas_station_model.dart';

class StationRemoteDataSource {
  final Dio _dio;

  const StationRemoteDataSource(this._dio);

  Future<StationListResult> getStations() async {
    final response = await _dio.get<Map<String, dynamic>>('/stations');

    if (response.data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Empty response from /stations',
      );
    }

    return StationListResult.fromJson(response.data!);
  }
}
