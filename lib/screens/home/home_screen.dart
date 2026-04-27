import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/app_notification_service.dart';
import 'widgets/day_streak_card.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;
  final int currentTabIndex;

  const HomeScreen({super.key, this.onNavigateToTab, this.currentTabIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _checkNotifications();
  }

  Future<void> _checkNotifications() async {
    final enabled = await AppNotificationService.checkPermissionStatus();
    if (mounted) setState(() => _notificationsEnabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GreetingCard(auth: auth),
          const SizedBox(height: 20),

          // Notification Alert Badge
          if (auth.isAuthenticated && !_notificationsEnabled) ...[
            _NotificationPrompt(onTap: () {
              Navigator.pushNamed(context, AppConstants.routeSettings).then((_) => _checkNotifications());
            }),
            const SizedBox(height: 20),
          ],

          if (auth.isAuthenticated && auth.currentUser != null) ...[
            DayStreakCard(user: auth.currentUser!),
            const SizedBox(height: 20),
          ],
          if (!auth.isAuthenticated) ...[
            _GuestInteractiveGuide(
              onNavigateToTab: widget.onNavigateToTab,
              currentTabIndex: widget.currentTabIndex,
            ),
            const SizedBox(height: 20),
            const _GuestPromptCard(),
          ],
        ],
      ),
    );
  }
}

class _NotificationPrompt extends StatelessWidget {
  final VoidCallback onTap;
  const _NotificationPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_none, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aktifkan Notifikasi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFFE65100), // Orange Deep
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Dapatkan notifikasi, pastikan Anda tahu saat ada pesan baru.',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.orange),
          ],
        ),
      ),
    );
  }
}

class _GuestInteractiveGuide extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;
  final int currentTabIndex;

  const _GuestInteractiveGuide({
    this.onNavigateToTab,
    required this.currentTabIndex,
  });

  @override
  State<_GuestInteractiveGuide> createState() => _GuestInteractiveGuideState();
}

class _GuestInteractiveGuideState extends State<_GuestInteractiveGuide> {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;
  static const _tabLabels = ['Beranda', 'Makanan', 'Kesehatan', 'Edukasi'];

  static const _steps = [
    _GuideStep(
      title: 'Mulai dari Beranda',
      description:
          'Beranda jadi tempat orientasi. Dari sini kamu bisa kenalan dulu dengan alur aplikasi sebelum mulai tracking.',
      badge: 'Pengenalan',
      buttonLabel: 'Tetap di Beranda',
      tabIndex: 0,
      icon: Icons.home_rounded,
      gradient: [Color(0xFF1A73E8), Color(0xFF00BCD4)],
      bullets: [
        'Lihat ringkasan fungsi utama aplikasi',
        'Pahami urutan menu yang akan dipakai',
        'Cocok untuk pengguna baru yang masih eksplor',
      ],
    ),
    _GuideStep(
      title: 'Lihat Tracker Makanan',
      description:
          'Di sini user bisa mencari makanan, melihat porsi, dan memahami simulasi nutrisi walau belum login penuh.',
      badge: 'Fitur Inti',
      buttonLabel: 'Buka Menu Makanan',
      tabIndex: 1,
      icon: Icons.restaurant_menu_rounded,
      gradient: [Color(0xFF0F9D58), Color(0xFF7CB342)],
      bullets: [
        'Lihat daftar makanan dan takaran saji',
        'Pahami hitungan gram dan nutrisi',
        'Login dibutuhkan jika ingin menyimpan catatan',
      ],
    ),
    _GuideStep(
      title: 'Jelajahi Tracker Kesehatan',
      description:
          'User guest tetap bisa melihat form dan alur input kesehatan supaya lebih paham fitur sebelum membuat akun.',
      badge: 'Preview',
      buttonLabel: 'Buka Tracker Kesehatan',
      tabIndex: 2,
      icon: Icons.monitor_heart_rounded,
      gradient: [Color(0xFFE53935), Color(0xFFFF8A65)],
      bullets: [
        'Lihat form indikator kesehatan per penyakit',
        'Kenali data apa saja yang akan dipantau',
        'Penyimpanan aktif setelah login',
      ],
    ),
    _GuideStep(
      title: 'Lihat Edukasi',
      description:
          'Menu edukasi menunjukkan bahwa aplikasi bukan hanya tracker, tapi juga tempat belajar pola makan dan kesehatan.',
      badge: 'Konten',
      buttonLabel: 'Buka Edukasi',
      tabIndex: 3,
      icon: Icons.menu_book_rounded,
      gradient: [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
      bullets: [
        'Preview halaman edukasi kesehatan',
        'Sebagian konten membutuhkan login',
        'Cocok untuk memperlihatkan cakupan fitur aplikasi',
      ],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentPage];
    final isLastPage = _currentPage == _steps.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tur Singkat Aplikasi',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Geser kartunya atau pakai tombol Lanjut untuk lihat semua fitur, lalu buka menu yang ingin kamu coba.',
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Langkah ${_currentPage + 1} dari ${_steps.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_tabLabels.length, (index) {
                  final isStepActive = step.tabIndex == index;
                  final isCurrentTab = widget.currentTabIndex == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isStepActive
                          ? AppColors.primary
                          : isCurrentTab
                          ? AppColors.primaryLight
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isStepActive || isCurrentTab
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      isCurrentTab && !isStepActive
                          ? '${_tabLabels[index]} aktif'
                          : _tabLabels[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isStepActive
                            ? Colors.white
                            : isCurrentTab
                            ? AppColors.primaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 410,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _steps.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final item = _steps[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _GuideFeatureCard(
                  step: item,
                  isActive: index == _currentPage,
                  onOpen: () => widget.onNavigateToTab?.call(item.tabIndex),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(_steps.length, (index) {
                final active = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: active ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_currentPage > 0)
                  TextButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: const Text('Sebelumnya'),
                  ),
                OutlinedButton.icon(
                  onPressed: () {
                    if (isLastPage) {
                      widget.onNavigateToTab?.call(step.tabIndex);
                      return;
                    }
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  icon: Icon(
                    isLastPage
                        ? Icons.check_circle_outline
                        : Icons.arrow_forward,
                    size: 18,
                  ),
                  label: Text(isLastPage ? 'Selesai' : 'Lanjut'),
                ),
                TextButton.icon(
                  onPressed: () => widget.onNavigateToTab?.call(step.tabIndex),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(step.buttonLabel),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _GuideFeatureCard extends StatelessWidget {
  final _GuideStep step;
  final bool isActive;
  final VoidCallback onOpen;

  const _GuideFeatureCard({
    required this.step,
    required this.isActive,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: step.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isActive ? 0.14 : 0.08),
            blurRadius: isActive ? 24 : 14,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              step.icon,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              step.badge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        step.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        step.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...step.bullets.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 3),
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onOpen,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(step.buttonLabel),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GuideStep {
  final String title;
  final String description;
  final String badge;
  final String buttonLabel;
  final int tabIndex;
  final IconData icon;
  final List<Color> gradient;
  final List<String> bullets;

  const _GuideStep({
    required this.title,
    required this.description,
    required this.badge,
    required this.buttonLabel,
    required this.tabIndex,
    required this.icon,
    required this.gradient,
    required this.bullets,
  });
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
