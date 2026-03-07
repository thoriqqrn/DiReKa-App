import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan Admin'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profil Admin
            _AdminProfileCard(),
            const SizedBox(height: 24),

            // Manajemen Pengguna
            const _SectionLabel(label: 'Manajemen Pengguna'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.download_outlined,
                  label: 'Export Daftar Pengguna (CSV)',
                  subtitle: 'Download semua data akun pengguna',
                  isSoon: true,
                  onTap: () => _showSoon(context),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.filter_list,
                  label: 'Filter & Pencarian Pengguna',
                  subtitle: 'Cari pengguna berdasarkan nama atau penyakit',
                  isSoon: true,
                  onTap: () => _showSoon(context),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.person_remove_outlined,
                  label: 'Hapus Akun Pengguna',
                  subtitle: 'Nonaktifkan atau hapus akun tertentu',
                  isSoon: true,
                  onTap: () => _showSoon(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Notifikasi & Broadcast
            const _SectionLabel(label: 'Notifikasi & Broadcast'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.campaign_outlined,
                  label: 'Kirim Notifikasi ke Semua User',
                  subtitle: 'Broadcast pesan ke seluruh pengguna aktif',
                  isSoon: true,
                  onTap: () => _showSoon(context),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.schedule_outlined,
                  label: 'Jadwal Pengingat Kesehatan',
                  subtitle: 'Atur notifikasi pengingat otomatis untuk user',
                  isSoon: true,
                  onTap: () => _showSoon(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Keamanan
            const _SectionLabel(label: 'Keamanan'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.lock_reset_outlined,
                  label: 'Ganti Password Admin',
                  subtitle: 'Perbarui kredensial masuk admin',
                  isSoon: true,
                  onTap: () => _showSoon(context),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.history_outlined,
                  label: 'Riwayat Login Admin',
                  subtitle: 'Pantau aktivitas masuk ke panel admin',
                  isSoon: true,
                  onTap: () => _showSoon(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Informasi Aplikasi
            const _SectionLabel(label: 'Informasi Aplikasi'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _InfoRow(
                  icon: Icons.info_outline,
                  label: 'Versi Aplikasi',
                  value: '1.0.0 (build 1)',
                ),
                const Divider(height: 1),
                _InfoRow(
                  icon: Icons.android_outlined,
                  label: 'Package Name',
                  value: 'direka.app',
                  copiable: true,
                ),
                const Divider(height: 1),
                _InfoRow(
                  icon: Icons.cloud_outlined,
                  label: 'Firebase Project',
                  value: 'direka-app',
                  copiable: true,
                ),
                const Divider(height: 1),
                _InfoRow(
                  icon: Icons.storage_outlined,
                  label: 'Database',
                  value: 'Cloud Firestore',
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Keluar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Keluar dari Panel Admin'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fitur ini akan segera hadir'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content:
            const Text('Apakah Anda yakin ingin keluar dari panel admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppConstants.routeLogin,
                (_) => false,
              );
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

// --- Widgets ---

class _AdminProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1a237e), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Administrator',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  AppConstants.adminEmail,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4), width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, color: Colors.amber, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Super Admin',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSoon;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSoon
              ? AppColors.textHint.withValues(alpha: 0.1)
              : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSoon ? AppColors.textHint : AppColors.primary,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isSoon ? AppColors.textSecondary : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textHint),
      ),
      trailing: isSoon
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.textHint.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Soon',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : const Icon(Icons.chevron_right,
              color: AppColors.textHint, size: 20),
      onTap: onTap,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool copiable;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.copiable = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, size: 20, color: AppColors.textSecondary),
      title: Text(
        label,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: copiable
          ? IconButton(
              icon: const Icon(Icons.copy_outlined,
                  size: 18, color: AppColors.textHint),
              tooltip: 'Salin',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label disalin'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            )
          : null,
    );
  }
}
