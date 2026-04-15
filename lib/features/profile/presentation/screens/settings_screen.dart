/// Settings Screen
/// App preferences, notifications, security, and logout.
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.charcoal, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(color: AppColors.charcoal, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionTitle(title: 'Account Settings'),
          _SettingsGroup(
            children: [
              _SettingsTile(icon: Icons.person_outline_rounded, title: 'Edit Profile', onTap: () {}),
              _SettingsTile(icon: Icons.lock_outline_rounded, title: 'Change PIN', onTap: () {}),
              _SettingsTile(
                icon: Icons.fingerprint_rounded, 
                title: 'Biometric Login', 
                trailing: CupertinoSwitch(value: true, activeTrackColor: AppColors.success, onChanged: (v) {}),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const _SectionTitle(title: 'Notifications'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: Icons.notifications_active_outlined, 
                title: 'Payment Alerts', 
                trailing: CupertinoSwitch(value: true, activeTrackColor: AppColors.success, onChanged: (v) {}),
              ),
              _SettingsTile(
                icon: Icons.map_outlined, 
                title: 'Nearby Station Prompts', 
                trailing: CupertinoSwitch(value: false, activeTrackColor: AppColors.success, onChanged: (v) {}),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const _SectionTitle(title: 'Preferences'),
          _SettingsGroup(
            children: [
              _SettingsTile(icon: Icons.language_rounded, title: 'Language', subtitle: 'English (US)', onTap: () {}),
              _SettingsTile(icon: Icons.dark_mode_outlined, title: 'Dark Mode', subtitle: 'System default', onTap: () {}),
            ],
          ),
          const SizedBox(height: 32),

          // About & Logout
          _SettingsTile(icon: Icons.info_outline_rounded, title: 'About ViettelFuel Pay', onTap: () {}),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.logout_rounded, 
            title: 'Log Out', 
            iconColor: AppColors.primaryRed,
            titleColor: AppColors.primaryRed,
            showChevron: false,
            onTap: () => _showLogoutDialog(context),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to log out of your account? You will need to enter your PIN or use biometrics to log back in.', style: TextStyle(color: AppColors.darkGray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.mediumGray, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.onboarding, (_) => false);
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.mediumGray,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(color: AppColors.borderGray, height: 1, indent: 56, endIndent: 20),
          ]
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color iconColor;
  final Color titleColor;
  final bool showChevron;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.iconColor = AppColors.charcoal,
    this.titleColor = AppColors.charcoal,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: titleColor, fontSize: 16, fontWeight: FontWeight.w600)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: const TextStyle(color: AppColors.mediumGray, fontSize: 13)),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!
            else if (showChevron) const Icon(Icons.chevron_right_rounded, color: AppColors.mediumGray, size: 20),
          ],
        ),
      ),
    );
  }
}
