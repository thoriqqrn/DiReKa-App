import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../models/disease_type.dart';
import '../../providers/auth_provider.dart';
import '../../providers/disease_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final disease = context.watch<DiseaseProvider>().selectedDisease;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting card
              _GreetingCard(auth: auth),
              const SizedBox(height: 20),

              // Disease info
              if (disease != null) ...[
                _DiseaseInfoCard(disease: disease),
                const SizedBox(height: 20),
              ],

              // Login prompt (jika guest)
              if (!auth.isAuthenticated) ...[
                _GuestPromptCard(),
                const SizedBox(height: 20),
              ],

              // Menu cepat
              const Text(
                'Fitur Utama',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              _QuickMenuGrid(isAuthenticated: auth.isAuthenticated),
            ],
          ),
        ),
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  final AuthProvider auth;
  const _GreetingCard({required this.auth});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    final name = auth.userModel?.name ?? 'Pengguna';
    return Container(
      width: double.infinity,
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting,',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  auth.isAuthenticated ? name : 'Tamu',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  auth.isAuthenticated
                      ? 'Pantau kesehatanmu hari ini!'
                      : 'Masuk untuk akses fitur lengkap',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.favorite, color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }
}

class _DiseaseInfoCard extends StatelessWidget {
  final DiseaseType disease;
  const _DiseaseInfoCard({required this.disease});

  Color get _color {
    switch (disease) {
      case DiseaseType.chronicKidneyDisease:
        return AppColors.kidneyColor;
      case DiseaseType.type2DiabetesMellitus:
        return AppColors.diabetesColor;
      case DiseaseType.heartFailure:
        return AppColors.heartColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                disease.iconEmoji,
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kondisi Anda',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  disease.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  disease.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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

class _GuestPromptCard extends StatelessWidget {
  const _GuestPromptCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mode Tamu',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Masuk untuk mencatat dan menyimpan data kesehatan Anda.',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppConstants.routeLogin),
                      icon: const Icon(Icons.login, size: 16),
                      label: const Text('Masuk'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppConstants.routeRegister,
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        foregroundColor: AppColors.primary,
                      ),
                      child: const Text('Daftar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickMenuGrid extends StatelessWidget {
  final bool isAuthenticated;
  const _QuickMenuGrid({required this.isAuthenticated});

  @override
  Widget build(BuildContext context) {
    final menus = [
      _MenuData(
        icon: Icons.restaurant_menu,
        label: 'Pelacak\nMakanan',
        color: Colors.orange,
        locked: !isAuthenticated,
        onTap: () {
          if (!isAuthenticated) {
            Navigator.pushNamed(context, AppConstants.routeLogin);
          }
        },
      ),
      _MenuData(
        icon: Icons.monitor_heart,
        label: 'Pelacak\nKesehatan',
        color: Colors.red,
        locked: !isAuthenticated,
        onTap: () {
          if (!isAuthenticated) {
            Navigator.pushNamed(context, AppConstants.routeLogin);
          }
        },
      ),
      _MenuData(
        icon: Icons.menu_book,
        label: 'Edukasi\nKesehatan',
        color: Colors.teal,
        locked: false,
        onTap: () {},
      ),
      _MenuData(
        icon: Icons.person_outline,
        label: 'Profil\nSaya',
        color: AppColors.primary,
        locked: !isAuthenticated,
        onTap: () {
          if (isAuthenticated) {
            Navigator.pushNamed(context, AppConstants.routeSettings);
          } else {
            Navigator.pushNamed(context, AppConstants.routeLogin);
          }
        },
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: menus.map((m) => _MenuCard(data: m)).toList(),
    );
  }
}

class _MenuData {
  final IconData icon;
  final String label;
  final Color color;
  final bool locked;
  final VoidCallback onTap;

  _MenuData({
    required this.icon,
    required this.label,
    required this.color,
    required this.locked,
    required this.onTap,
  });
}

class _MenuCard extends StatelessWidget {
  final _MenuData data;
  const _MenuCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: data.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: data.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(data.icon, color: data.color, size: 24),
                ),
                if (data.locked)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.lock,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              data.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: data.locked
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
