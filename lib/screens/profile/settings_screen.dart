import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../models/disease_type.dart';
import '../../providers/auth_provider.dart';
import '../../providers/disease_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final disease = context.watch<DiseaseProvider>().selectedDisease;
    final user = auth.userModel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pengaturan')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profil card
              if (auth.isAuthenticated && user != null) ...[
                _ProfileCard(
                  name: user.name,
                  email: user.email,
                  disease: disease?.label ?? '-',
                  onEdit: () => Navigator.pushNamed(
                    context,
                    AppConstants.routeEditProfile,
                  ),
                ),
                const SizedBox(height: 20),

                // Info kesehatan
                _SectionCard(
                  title: 'Informasi Kesehatan',
                  children: [
                    _InfoRow(
                      label: 'Usia',
                      value: user.ageString,
                      icon: Icons.calendar_today_outlined,
                    ),
                    const Divider(height: 1),
                    _InfoRow(
                      label: 'Berat Badan',
                      value: '${user.weight} kg',
                      icon: Icons.monitor_weight_outlined,
                    ),
                    const Divider(height: 1),
                    _InfoRow(
                      label: 'Tinggi Badan',
                      value: '${user.height} cm',
                      icon: Icons.height,
                    ),
                    const Divider(height: 1),
                    _InfoRow(
                      label: 'IMT',
                      value:
                          '${user.bmi.toStringAsFixed(1)} (${user.bmiCategory})',
                      icon: Icons.calculate_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ] else ...[
                _GuestCard(),
                const SizedBox(height: 20),
              ],

              // Preferensi
              _SectionCard(
                title: 'Preferensi',
                children: [
                  if (!auth.isAuthenticated)
                    _SettingsTile(
                      icon: Icons.medical_services_outlined,
                      label: 'Ubah Jenis Penyakit',
                      subtitle: disease?.label ?? 'Belum dipilih',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppConstants.routeDiseaseSelection,
                      ),
                    )
                  else
                    _InfoTile(
                      icon: Icons.medical_services_outlined,
                      label: 'Jenis Penyakit',
                      subtitle: disease?.label ?? '-',
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Akun
              _SectionCard(
                title: 'Akun',
                children: [
                  if (auth.isAuthenticated) ...[
                    _SettingsTile(
                      icon: Icons.edit_outlined,
                      label: 'Edit Profil',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppConstants.routeEditProfile,
                      ),
                    ),
                    const Divider(height: 1),
                    _SettingsTile(
                      icon: Icons.logout,
                      label: 'Keluar',
                      color: AppColors.error,
                      onTap: () => _confirmLogout(context),
                    ),
                  ] else ...[
                    _SettingsTile(
                      icon: Icons.login,
                      label: 'Masuk',
                      onTap: () =>
                          Navigator.pushNamed(context, AppConstants.routeLogin),
                    ),
                    const Divider(height: 1),
                    _SettingsTile(
                      icon: Icons.person_add_outlined,
                      label: 'Daftar Akun',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppConstants.routeRegister,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 32),
              const Center(
                child: Text(
                  'Direka v1.0.0',
                  style: TextStyle(color: AppColors.textHint, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final navigator = Navigator.of(context);
              await context.read<AuthProvider>().signOut();
              navigator.pushNamedAndRemoveUntil(
                AppConstants.routeLogin,
                (_) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String email;
  final String disease;
  final VoidCallback onEdit;

  const _ProfileCard({
    required this.name,
    required this.email,
    required this.disease,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  disease,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white70),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mode Tamu',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Masuk atau daftar untuk menyimpan data Anda.',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: AppColors.textHint, size: 22),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: const Icon(
        Icons.lock_outline,
        color: AppColors.textHint,
        size: 18,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? color;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: c, size: 22),
      title: Text(
        label,
        style: TextStyle(fontSize: 14, color: c, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            )
          : null,
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textHint,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
