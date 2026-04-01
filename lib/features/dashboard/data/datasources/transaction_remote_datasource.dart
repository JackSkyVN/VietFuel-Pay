/// Transaction remote data source – calls the FastAPI backend.
library;

import 'package:dio/dio.dart';

import '../models/transaction_model.dart';

class TransactionRemoteDataSource {
  final Dio _dio;

  const TransactionRemoteDataSource(this._dio);

  /// Fetches paginated transaction history for a customer by phone number.
  /// Uses the unauthenticated /history/dev endpoint during development.
  Future<TransactionHistoryResult> getTransactionHistory({
    required String phone,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/customer/history/dev',
      queryParameters: {
        'phone': phone,
        'page': page,
        'page_size': pageSize,
      },
    );

    if (response.data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Empty response from server',
      );
    }

    return TransactionHistoryResult.fromJson(response.data!);
  }
}
