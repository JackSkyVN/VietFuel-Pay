/// API client configuration using Dio.
///
/// Base URLs:
///   Android emulator  → http://10.0.2.2:8000
///   iOS simulator     → http://127.0.0.1:8000
///   Physical device   → replace with your machine's LAN IP
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/foundation.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// Change this to match your dev environment.
String get kBaseUrl {
  if (kIsWeb) {
    return 'http://127.0.0.1:8000'; // Web works directly with localhost
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000'; // Android Emulator loopback
  }
  return 'http://127.0.0.1:8000'; // iOS Simulator or desktop
}

const String kApiPrefix = '/api/v1';
const Duration kConnectTimeout = Duration(seconds: 10);
const Duration kReceiveTimeout = Duration(seconds: 15);

// ── Dio instance provider ─────────────────────────────────────────────────────

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: '$kBaseUrl$kApiPrefix',
      connectTimeout: kConnectTimeout,
      receiveTimeout: kReceiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // ── Interceptors ────────────────────────────────────────────────────────────
  dio.interceptors.add(
    LogInterceptor(
      requestBody: false,
      responseBody: true,
      logPrint: (obj) => debugLog(obj.toString()),
    ),
  );

  return dio;
});

void debugLog(String msg) {
  // ignore: avoid_print
  assert(() {
    // ignore: avoid_print
    print('[DIO] $msg');
    return true;
  }());
}
