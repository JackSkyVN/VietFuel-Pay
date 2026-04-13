import 'package:dio/dio.dart';

class AuthRemoteDataSource {
  final Dio dio;
  AuthRemoteDataSource(this.dio);

  /// Calls POST /auth/login.
  /// Returns the raw JSON map on success.
  /// Throws [DioException] on network/HTTP errors (caller handles 401).
  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final response = await dio.post(
      '/auth/login',
      data: {'phone': phone, 'password': password},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
