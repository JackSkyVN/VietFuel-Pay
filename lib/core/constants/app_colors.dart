import 'package:flutter/material.dart';

abstract class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color primaryRed = Color(0xFFEE0033);
  static const Color primaryRedDark = Color(0xFFCC0029);
  static const Color primaryRedLight = Color(0xFFFF1A47);

  // ── Neutrals ────────────────────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFF9F9F9);
  static const Color borderGray = Color(0xFFEEEEEE);
  static const Color charcoal = Color(0xFF333333);
  static const Color mediumGray = Color(0xFF888888);
  static const Color darkGray = Color(0xFF555555);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF00C853);
  static const Color successLight = Color(0xFFB9F6CA);
  static const Color warning = Color(0xFFFFAB00);
  static const Color error = Color(0xFFDD2C00);
  static const Color info = Color(0xFF0091EA);

  // ── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryRed, Color(0xFFFF5252)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00C853), Color(0xFF69F0AE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFFFF5F5), Color(0xFFF9F9F9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Glassmorphism ─────────────────────────────────────────────────────────
  static Color glassWhite = Colors.white.withOpacity(0.18);
  static Color glassBorder = Colors.white.withOpacity(0.35);
  static Color glassRed = primaryRed.withOpacity(0.15);

  // ── Shadows ───────────────────────────────────────────────────────────────
  static List<BoxShadow> redGlow = [
    BoxShadow(
      color: primaryRed.withOpacity(0.45),
      blurRadius: 24,
      spreadRadius: 2,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 20,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 32,
      spreadRadius: 0,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: primaryRed.withOpacity(0.06),
      blurRadius: 20,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
  ];
}
