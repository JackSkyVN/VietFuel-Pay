/// Auth session state – persists the logged-in user's session to
/// SharedPreferences so it survives hot restarts and app relaunches.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Storage keys ──────────────────────────────────────────────────────────────

const _kSessionKey = 'auth_session_v1';

// ── Session model ─────────────────────────────────────────────────────────────

class AuthSession {
  final String accessToken;
  final String customerId;
  final String fullName;
  final String phone;

  const AuthSession({
    required this.accessToken,
    required this.customerId,
    required this.fullName,
    required this.phone,
  });

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'customerId': customerId,
        'fullName': fullName,
        'phone': phone,
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        accessToken: json['accessToken'] as String,
        customerId: json['customerId'] as String,
        fullName: json['fullName'] as String,
        phone: json['phone'] as String,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AuthSessionNotifier extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    // Attempt to restore a previously persisted session on startup.
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSessionKey);
      if (raw != null) {
        return AuthSession.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      // Corrupted data – ignore and start fresh.
    }
    return null;
  }

  Future<void> login(AuthSession session) async {
    state = AsyncData(session);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSessionKey, jsonEncode(session.toJson()));
    } catch (_) {}
  }

  Future<void> logout() async {
    state = const AsyncData(null);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSessionKey);
    } catch (_) {}
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// The current [AuthSession], or null when not logged in.
final authSessionProvider =
    AsyncNotifierProvider<AuthSessionNotifier, AuthSession?>(
  AuthSessionNotifier.new,
);

/// Convenience: the logged-in session synchronously (null if not ready/logged out).
final currentSessionProvider = Provider<AuthSession?>((ref) {
  return ref.watch(authSessionProvider).valueOrNull;
});

/// Convenience: the logged-in customer's phone, or null if not logged in.
final sessionPhoneProvider = Provider<String?>((ref) {
  return ref.watch(currentSessionProvider)?.phone;
});
