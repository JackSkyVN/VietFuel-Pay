import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gas_station_pay/core/constants/app_colors.dart';
import 'package:gas_station_pay/shared/widgets/app_bottom_nav_bar.dart';
import 'package:gas_station_pay/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:gas_station_pay/features/offline_qr/presentation/screens/offline_qr_screen.dart';

import 'package:gas_station_pay/features/history/presentation/screens/transaction_history_screen.dart';
import 'package:gas_station_pay/features/profile/presentation/screens/profile_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;

  static final List<Widget> _screens = [
    const DashboardScreen(),
    const _StationsPlaceholder(),
    const OfflineQrScreen(),
    const TransactionHistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: child,
        ),
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: _screens[_selectedIndex],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

// ── Placeholder screens ────────────────────────────────────────────────────

class _StationsPlaceholder extends StatelessWidget {
  const _StationsPlaceholder();

  @override
  Widget build(BuildContext context) => _PlaceholderScreen(
        icon: Icons.local_gas_station_rounded,
        label: 'Nearby Stations',
        color: AppColors.warning,
      );
}

class _PlaceholderScreen extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _PlaceholderScreen({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(icon, color: color, size: 44),
            ),
            const SizedBox(height: 20),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.charcoal,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Coming soon',
              style: TextStyle(color: AppColors.mediumGray),
            ),
          ],
        ),
      ),
    );
  }
}
