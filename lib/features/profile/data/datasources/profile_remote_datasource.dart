import 'package:dio/dio.dart';
import '../models/profile_model.dart';

class ProfileRemoteDataSource {
  final Dio dio;

  ProfileRemoteDataSource(this.dio);

  Future<ProfileModel> getProfile(String phone) async {
    try {
      final response = await dio.get(
        '/customer/profile/dev',
        queryParameters: {'phone': phone},
      );
      return ProfileModel.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to load profile: ${e.message}');
    }
  }

  Future<VehicleModel> addVehicle(String phone, String licensePlate) async {
    try {
      final response = await dio.post(
        '/customer/vehicles/dev',
        queryParameters: {'phone': phone},
        data: {
          'license_plate': licensePlate,
          'make': null,
          'model': null,
          'is_primary': false,
        },
      );
      return VehicleModel.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception('Failed to add vehicle: ${e.message}');
    }
  }
}
