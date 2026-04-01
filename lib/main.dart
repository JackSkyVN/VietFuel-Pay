import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'features/payment/presentation/screens/payment_success_screen.dart';
import 'features/scanner/presentation/screens/plate_scanner_screen.dart';
import 'features/profile/presentation/screens/settings_screen.dart';
import 'shared/widgets/main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status/nav bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    // Riverpod ProviderScope wraps the entire app
    const ProviderScope(
      child: GasStationPayApp(),
    ),
  );
}

class GasStationPayApp extends StatelessWidget {
  const GasStationPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VietFuel Pay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,

      // ── Named Route Table ──────────────────────────────────────────────
      initialRoute: AppRoutes.onboarding,
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    Widget page;

    switch (settings.name) {
      case AppRoutes.onboarding:
        page = const OnboardingScreen();
        break;
      case AppRoutes.login:
        page = const LoginScreen();
        break;
      case AppRoutes.dashboard:
        page = const MainShell();
        break;
      case AppRoutes.paymentSuccess:
        final args = settings.arguments as Map<String, dynamic>?;
        page = PaymentSuccessScreen(
          stationName: args?['stationName'] ?? 'Viettel Station',
          amountPaid: args?['amountPaid'] ?? 0.0,
          litersFueled: args?['litersFueled'] ?? 0.0,
        );
        break;
      case AppRoutes.plateCapture:
        page = const PlateScannerScreen();
        break;
      case AppRoutes.settings:
        page = const SettingsScreen();
        break;
      default:
        page = const _NotFoundScreen();
    }

    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (ctx, anim, secAnim) => page,
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeSlideTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
    );
  }
}

// ── 404 Fall-back ──────────────────────────────────────────────────────────
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Page not found', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context)
                  .pushNamedAndRemoveUntil(AppRoutes.onboarding, (_) => false),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
