/// API client configuration using Dio.
///
/// Base URLs:
///   Web / Desktop        → http://127.0.0.1:8000
///   Android emulator     → http://10.0.2.2:8000
///   Physical device      → replace with your machine's LAN IP
///
/// The [dioProvider] automatically attaches the JWT from [authSessionProvider]
/// on every request via an [AuthInterceptor], so all protected backend
/// endpoints work without manually setting headers in each call.
library;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// Change this to match your dev environment.
String get kBaseUrl {
  if (kIsWeb) {
    return 'http://127.0.0.1:8000'; // Chrome / web debug
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000'; // Android emulator loopback
  }
  return 'http://127.0.0.1:8000'; // iOS simulator or desktop
}

const String kApiPrefix = '/api/v1';
const Duration kConnectTimeout = Duration(seconds: 10);
const Duration kReceiveTimeout = Duration(seconds: 15);

// ── Auth interceptor ──────────────────────────────────────────────────────────

/// Injects `Authorization: Bearer <token>` on every outgoing request if a
/// session is available.  Skips injection on public auth endpoints so that
/// login / register calls are never blocked.
class AuthInterceptor extends Interceptor {
  final Ref _ref;

  const AuthInterceptor(this._ref);

  static const _publicPaths = {'/auth/login', '/auth/register', '/auth/staff-login'};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;

    // Skip token injection for public endpoints
    final isPublic = _publicPaths.any((p) => path.endsWith(p));
    if (!isPublic) {
      final session = _ref.read(currentSessionProvider);
      if (session != null) {
        options.headers['Authorization'] = 'Bearer ${session.accessToken}';
      }
    }

    handler.next(options);
  }
}

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

  // Attach JWT on every protected request automatically
  dio.interceptors.add(AuthInterceptor(ref));

  // Debug logging (debug builds only)
  dio.interceptors.add(
    LogInterceptor(
      requestBody: false,
      responseBody: true,
      logPrint: (obj) => _debugLog(obj.toString()),
    ),
  );

  return dio;
});

void _debugLog(String msg) {
  assert(() {
    // ignore: avoid_print
    print('[DIO] $msg');
    return true;
  }());
}
