import 'package:dio/dio.dart';

class AuthRemoteDataSource {
  final Dio dio;
  AuthRemoteDataSource(this.dio);

  /// Calls POST /auth/login (customer).
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

  /// Calls POST /auth/staff-login.
  /// [identifier] may be a phone number OR an employee code (e.g. "NV001").
  /// Returns the raw JSON map with a `role` field on success.
  Future<Map<String, dynamic>> staffLogin({
    required String identifier,
    required String password,
  }) async {
    final response = await dio.post(
      '/auth/staff-login',
      data: {'identifier': identifier, 'password': password},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Calls POST /auth/register.
  /// Returns the raw JSON map (same shape as login) on success.
  /// Throws [DioException] on network/HTTP errors.
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String phone,
    required String password,
    String? email,
  }) async {
    final response = await dio.post(
      '/auth/register',
      data: {
        'full_name': fullName,
        'phone': phone,
        'password': password,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
