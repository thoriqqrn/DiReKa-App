import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../models/disease_type.dart';
import '../../providers/auth_provider.dart';
import '../../providers/disease_provider.dart';
import '../../services/app_notification_service.dart';
import '../notifications/notification_info_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();
    final guestDisease = context.watch<DiseaseProvider>().selectedDisease;
    final user = auth.userModel;
    final disease = auth.isAuthenticated && user != null
        ? user.diseaseType
        : guestDisease;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                    const Divider(height: 1),
                    _InfoRow(
                      label: 'Alamat',
                      value:
                          '${user.addressVillage}, ${user.addressDistrict}, ${user.addressCity}, ${user.addressProvince}',
                      icon: Icons.location_on_outlined,
                    ),
                    const Divider(height: 1),
                    _InfoRow(
                      label: 'Pendidikan',
                      value: user.education.isEmpty ? '-' : user.education,
                      icon: Icons.school_outlined,
                    ),
                    const Divider(height: 1),
                    _InfoRow(
                      label: 'Pekerjaan',
                      value: user.occupation.isEmpty ? '-' : user.occupation,
                      icon: Icons.work_outline,
                    ),
                    if (user.diseaseType == DiseaseType.type2DiabetesMellitus ||
                        user.diseaseType == DiseaseType.heartFailure) ...[
                      const Divider(height: 1),
                      _InfoRow(
                        label: user.diseaseType == DiseaseType.type2DiabetesMellitus
                            ? 'Lama DM'
                            : 'Lama Jantung Koroner',
                        value: user.diseaseType == DiseaseType.type2DiabetesMellitus
                            ? '${user.diabetesDurationYears.toStringAsFixed(1)} tahun'
                            : '${user.heartDiseaseDurationYears.toStringAsFixed(1)} tahun',
                        icon: Icons.timelapse_outlined,
                      ),
                      if (user.diseaseType == DiseaseType.type2DiabetesMellitus) ...[
                        const Divider(height: 1),
                        _InfoRow(
                          label: 'Terapi insulin',
                          value: user.usesInsulinTherapy ? 'Ya' : 'Tidak',
                          icon: Icons.medication_outlined,
                        ),
                        if (user.usesInsulinTherapy) ...[
                          const Divider(height: 1),
                          _InfoRow(
                            label: 'Lama Insulin',
                            value: '${user.insulinDurationYears.toStringAsFixed(1)} tahun',
                            icon: Icons.history_edu_outlined,
                          ),
                        ],
                      ],
                    ],
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

              // Notifikasi
              _SectionCard(
                title: 'Notifikasi',
                children: [
                  _SettingsTile(
                    icon: Icons.notifications_active_outlined,
                    label: 'Izinkan Notifikasi HP',
                    subtitle: 'Aktifkan izin untuk menerima peringatan kesehatan di bar HP',
                    onTap: () async {
                      await AppNotificationService.requestPermissions();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Permintaan izin notifikasi dikirim.')),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.info_outline,
                    label: 'Apa saja yang dinotifikasi?',
                    subtitle: 'Lihat daftar peringatan kesehatan yang akan Anda terima',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationInfoScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.notification_important_outlined,
                    label: 'Tes Kirim Notifikasi',
                    subtitle: 'Coba kirim satu notifikasi tes ke HP ini',
                    onTap: () async {
                      await AppNotificationService.sendTestNotification();
                    },
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
                      icon: Icons.group_add_outlined,
                      label: 'Buat akun untuk keluarga',
                      subtitle:
                          'Data kesehatan akun baru akan disalin dari akun utama',
                      onTap: () => _showCreateFamilyAccountDialog(context),
                    ),
                    const Divider(height: 1),
                    _SettingsTile(
                      icon: Icons.logout,
                      label: 'Keluar',
                      color: theme.colorScheme.error,
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

              if (auth.isAuthenticated) ...[
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Akun Keluarga Aktif',
                  children: [
                    if (auth.linkedFamilyAccounts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Belum ada akun keluarga yang ditautkan.',
                          style: TextStyle(color: theme.hintColor),
                        ),
                      )
                    else
                      ...auth.linkedFamilyAccounts.asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        return Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: Icon(
                                Icons.family_restroom,
                                color: ext?.diabetesColor ?? theme.primaryColor,
                              ),
                              title: Text(item.name),
                              subtitle: Text(
                                '${item.email}\n${item.lastLoginDate != null ? 'Terakhir login: ${_formatDate(item.lastLoginDate!)}' : 'Belum ada riwayat login'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                              isThreeLine: true,
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: item.isActive
                                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                      : theme.colorScheme.error.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  item.isActive ? 'Aktif' : 'Nonaktif',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: item.isActive
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.error,
                                  ),
                                ),
                              ),
                            ),
                            if (i != auth.linkedFamilyAccounts.length - 1)
                              const Divider(height: 1),
                          ],
                        );
                      }),
                  ],
                ),
              ],

              const SizedBox(height: 32),
              Center(
                child: Text(
                  'Direka v1.0.0',
                  style: TextStyle(color: theme.hintColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year;
    return '$d/$m/$y';
  }

  void _showCreateFamilyAccountDialog(BuildContext context) {
    final theme = Theme.of(context);
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            title: const Text('Buat akun untuk keluarga'),
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Akun keluarga akan dibuat dengan fitur yang sama dan data profil kesehatan disalin dari akun utama.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nama akun keluarga'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email akun keluarga'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: confirmController,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'Konfirmasi password'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final auth = context.read<AuthProvider>();
                  final name = nameController.text.trim();
                  final email = emailController.text.trim();
                  final password = passwordController.text.trim();
                  final confirm = confirmController.text.trim();

                  if (name.isEmpty || email.isEmpty || password.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nama, email, dan password wajib diisi.'),
                      ),
                    );
                    return;
                  }
                  if (password.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password minimal 6 karakter.'),
                      ),
                    );
                    return;
                  }
                  if (password != confirm) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Konfirmasi password tidak sama.'),
                      ),
                    );
                    return;
                  }

                  final success = await auth.createFamilyAccount(
                    familyName: name,
                    familyEmail: email,
                    familyPassword: password,
                  );

                  if (!context.mounted) return;
                  if (success) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Akun keluarga berhasil dibuat dan ditautkan.'),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          auth.errorMessage ?? 'Gagal membuat akun keluarga.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Buat akun'),
              ),
            ],
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor, theme.colorScheme.secondary],
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
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ext?.primaryLight.withValues(alpha: 0.3) ?? theme.primaryColorLight.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.primaryColor,
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode Tamu',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Masuk atau daftar untuk menyimpan data Anda.',
                  style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
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
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.hintColor,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ext?.border ?? theme.dividerColor),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.primaryColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                    height: 1.35,
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
    final theme = Theme.of(context);
    final iconColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.secondary
        : theme.hintColor;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: theme.textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: theme.hintColor),
      ),
      trailing: Icon(
        Icons.lock_outline,
        color: iconColor.withValues(alpha: 0.9),
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
    final theme = Theme.of(context);
    final c = color ?? theme.textTheme.bodyLarge?.color;
    final iconColor = color ??
        (theme.brightness == Brightness.dark
            ? theme.colorScheme.secondary
            : theme.primaryColor);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(
        label,
        style: TextStyle(fontSize: 14, color: c, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: theme.hintColor,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: theme.hintColor,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
