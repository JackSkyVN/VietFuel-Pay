/// Profile Screen
/// Shows user info, linked vehicles with scan button, payment methods, and settings link.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import '../../data/models/profile_model.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      body: asyncProfile.when(
        loading: () => _buildLoadingState(),
        error: (e, _) => _buildErrorState(e.toString(), () => ref.refresh(profileProvider)),
        data: (profile) => CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildHeroHeader(context, profile),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildVehiclesSection(context, profile.vehicles, ref),
                  const SizedBox(height: 32),
                  _buildPaymentMethodsSection(context, profile.paymentMethods),
                  const SizedBox(height: 32),
                  _buildSettingsRow(context),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator(color: AppColors.primaryRed));
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.primaryRed, size: 48),
          const SizedBox(height: 16),
          Text(error, style: const TextStyle(color: AppColors.charcoal), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context, ProfileModel profile) {
    // Generate initials (e.g., "Nguyễn Văn A" -> "NA")
    final parts = profile.fullName.split(' ').where((s) => s.isNotEmpty).toList();
    final initials = parts.length > 1 
      ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
      : (parts.isNotEmpty ? parts.first[0].toUpperCase() : '?');

    final joinedYear = profile.createdAt.year;

    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A1A2E), AppColors.primaryRed],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                  ),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: AppColors.primaryRed,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ).animate().scale(begin: const Offset(0.8, 0.8), duration: 500.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 16),
                Text(
                  profile.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.1),
                const SizedBox(height: 6),
                Text(
                  '${_formatPhone(profile.phone)}  ·  Joined $joinedYear',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatPhone(String phone) {
    if (phone.length == 10) {
      return '${phone.substring(0,3)} ${phone.substring(3,6)} ${phone.substring(6)}';
    }
    return phone;
  }

  Widget _buildVehiclesSection(BuildContext context, List<VehicleModel> vehicles, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'My Vehicles', actionLabel: 'Add New', onAction: () {}),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            children: [
              ...vehicles.map((v) => Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _VehicleCard(
                  plate: v.licensePlate,
                  desc: [v.make, v.model].where((e) => e != null && e.isNotEmpty).join(' ') 
                        .padRight(1, 'Vehicle Profile'), // default text if empty
                  isPrimary: v.isPrimary,
                ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1),
              )),
              // add new button
              GestureDetector(
                onTap: () async {
                  final val = await Navigator.of(context).pushNamed(AppRoutes.plateCapture);
                  if (val != null && val is String && context.mounted) {
                    try {
                      // Call backend to save
                      final ds = ref.read(profileDataSourceProvider);
                      final phone = ref.read(sessionPhoneProvider);
                      if (phone == null) return;
                      await ds.addVehicle(phone, val);
                      
                      // Trigger profile UI reload upon success
                      ref.invalidate(profileProvider);
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Successfully added vehicle: $val'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to add vehicle: $e'),
                            backgroundColor: AppColors.primaryRed,
                          ),
                        );
                      }
                    }
                  }
                },
                child: Container(
                  width: 120,
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primaryRed.withOpacity(0.2)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed,
                          shape: BoxShape.circle,
                          boxShadow: AppColors.redGlow,
                        ),
                        child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Scan Plate',
                        style: TextStyle(
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodsSection(BuildContext context, List<PaymentMethodModel> methods) {
    if (methods.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: 'Payment Methods', actionLabel: 'Manage', onAction: () {}),
          const SizedBox(height: 16),
          const Text('No payment methods linked.', style: TextStyle(color: AppColors.mediumGray)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'Payment Methods', actionLabel: 'Manage', onAction: () {}),
        const SizedBox(height: 16),
        ...methods.map((pm) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.softShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 32,
                  decoration: BoxDecoration(
                    color: pm.provider.toUpperCase() == 'VISA' ? const Color(0xFF1A1F71) : AppColors.primaryRed,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(pm.provider, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Linked Card', style: const TextStyle(color: AppColors.charcoal, fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(pm.maskedAccount, style: const TextStyle(color: AppColors.mediumGray, fontSize: 12, letterSpacing: 1)),
                    ],
                  ),
                ),
                if (pm.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('DEFAULT', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w800)),
                  )
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
        )),
      ],
    );
  }

  Widget _buildSettingsRow(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.settings),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.charcoal.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.settings_rounded, color: AppColors.charcoal, size: 22),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Settings & Preferences',
                style: TextStyle(
                  color: AppColors.charcoal,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.mediumGray),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({required this.label, required this.actionLabel, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.charcoal,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        TextButton(
          onPressed: onAction,
          child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final String plate;
  final String desc;
  final bool isPrimary;

  const _VehicleCard({required this.plate, required this.desc, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_car_rounded, color: AppColors.info, size: 20),
              ),
              if (isPrimary)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('PRIMARY', style: TextStyle(color: AppColors.primaryRed, fontSize: 9, fontWeight: FontWeight.w800)),
                )
            ],
          ),
          const Spacer(),
          Text(
            plate,
            style: const TextStyle(
              color: AppColors.charcoal,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc.isEmpty ? 'Vehicle Profile' : desc,
            style: const TextStyle(
              color: AppColors.mediumGray,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

