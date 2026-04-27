import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/app_notification_service.dart';
import 'home_screen.dart';
import '../tracker/food_tracker_screen.dart';
import '../tracker/health_tracker_screen.dart';
import '../tracker/education_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  String? _lastNotificationUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshNotificationsIfNeeded(force: true);
      _checkAndShowNotificationPrompt();
    });
  }

  Future<void> _checkAndShowNotificationPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Jangan ganggu jika user sudah pernah di prompt dalam 3 hari terakhir
    final lastPromptStr = prefs.getString('last_notif_prompt');
    if (lastPromptStr != null) {
      final lastPrompt = DateTime.parse(lastPromptStr);
      if (DateTime.now().difference(lastPrompt).inDays < 3) {
        return;
      }
    }

    final allowed = await AppNotificationService.checkPermissionStatus();
    if (!allowed && mounted) {
      _showNotifPermissionModal();
    }
  }

  void _showNotifPermissionModal() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_active_outlined,
                size: 40,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aktifkan Notifikasi Kesehatan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Dapatkan peringatan otomatis jika asupan cairan/makanan berlebih, jadwal cuci darah, dan pantauan kondisi harian kamu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await AppNotificationService.requestPermissions();
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('last_notif_prompt', DateTime.now().toIso8601String());
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Ya, Izinkan Sekarang',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('last_notif_prompt', DateTime.now().toIso8601String());
              },
              child: Text(
                'Mungkin Nanti',
                style: TextStyle(color: theme.hintColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshNotificationsIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = auth.currentUser;
    final screens = [
      HomeScreen(
        currentTabIndex: _currentIndex,
        onNavigateToTab: (index) {
          if (!mounted) return;
          setState(() => _currentIndex = index);
          _refreshNotificationsIfNeeded(force: true);
        },
      ),
      FoodTrackerScreen(),
      HealthTrackerScreen(),
      EducationScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: user == null
            ? null
            : _NotificationButton(
                uid: user.uid,
                onTap: () async {
                  final navigator = Navigator.of(context);
                  await AppNotificationService.refreshForUser(user);
                  await navigator.pushNamed(AppConstants.routeNotifications);
                  await AppNotificationService.refreshForUser(user);
                },
              ),
        title: _buildTitle(),
        automaticallyImplyLeading: false,
        actions: [
          // Theme Toggle
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: InkWell(
              onTap: () => themeProvider.toggleTheme(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode 
                      ? const Color(0xFF62E7D9).withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Icon(
                    themeProvider.isDarkMode 
                        ? Icons.nightlight_round
                        : Icons.wb_sunny_rounded,
                    key: ValueKey(themeProvider.isDarkMode),
                    size: 18,
                    color: themeProvider.isDarkMode 
                        ? const Color(0xFF62E7D9)
                        : Colors.orange,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: 'Pengaturan',
            onPressed: () async {
              await Navigator.pushNamed(context, AppConstants.routeSettings);
              if (!mounted) return;
              _refreshNotificationsIfNeeded(force: true);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IndexedStack(index: _currentIndex, children: screens),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _FloatingBottomNav(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() => _currentIndex = index);
                _refreshNotificationsIfNeeded(force: true);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    const titles = [
      'Beranda',
      'Pelacak Makanan',
      'Pelacak Kesehatan',
      'Edukasi',
    ];
    return Text(titles[_currentIndex]);
  }

  void _refreshNotificationsIfNeeded({bool force = false}) {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    if (!force && _lastNotificationUid == user.uid) return;
    _lastNotificationUid = user.uid;
    AppNotificationService.refreshForUser(user);
  }
}

class _FloatingBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _FloatingBottomNav({required this.currentIndex, required this.onTap});

  static const _items = [
    _FloatingNavItem(
      label: 'Beranda',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _FloatingNavItem(
      label: 'Makanan',
      icon: Icons.restaurant_menu_outlined,
      activeIcon: Icons.restaurant_menu_rounded,
    ),
    _FloatingNavItem(
      label: 'Kesehatan',
      icon: Icons.monitor_heart_outlined,
      activeIcon: Icons.monitor_heart_rounded,
    ),
    _FloatingNavItem(
      label: 'Edukasi',
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();
    final isDark = theme.brightness == Brightness.dark;
    final selectedNavBackground = isDark
        ? const Color(0xFF16224F)
        : (ext?.primaryLight.withValues(alpha: 0.7) ?? theme.primaryColorLight);
    final selectedNavForeground = isDark ? Colors.white : theme.primaryColor;
    final unselectedNavForeground = isDark
        ? Colors.white.withValues(alpha: 0.68)
        : theme.hintColor;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: theme.brightness == Brightness.dark 
                    ? const Color(0xFF62E7D9).withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
              if (theme.brightness == Brightness.dark)
                BoxShadow(
                  color: const Color(0xFF62E7D9).withValues(alpha: 0.05),
                  blurRadius: 30,
                  spreadRadius: -5,
                ),
            ],
            border: theme.brightness == Brightness.dark ? Border.all(color: theme.dividerColor) : null,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth = constraints.maxWidth / _items.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    left: slotWidth * currentIndex,
                    top: 0,
                    bottom: 0,
                    width: slotWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: selectedNavBackground,
                          borderRadius: BorderRadius.circular(20),
                          border: isDark
                              ? Border.all(
                                  color: const Color(0xFF62E7D9).withValues(alpha: 0.3),
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? const Color(0xFF62E7D9).withValues(alpha: 0.18)
                                  : theme.primaryColor.withValues(alpha: 0.08),
                              blurRadius: isDark ? 14 : 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(_items.length, (index) {
                      final item = _items[index];
                      final selected = index == currentIndex;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => onTap(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                scale: selected ? 1.0 : 0.96,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      transitionBuilder: (child, animation) =>
                                          ScaleTransition(
                                            scale: animation,
                                            child: FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            ),
                                          ),
                                      child: Icon(
                                        selected ? item.activeIcon : item.icon,
                                        key: ValueKey('$index-$selected'),
                                        color: selected
                                            ? selectedNavForeground
                                            : unselectedNavForeground,
                                        size: selected ? 25 : 23,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: selected
                                            ? selectedNavForeground
                                            : unselectedNavForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FloatingNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _FloatingNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class _NotificationButton extends StatelessWidget {
  final String uid;
  final VoidCallback onTap;

  const _NotificationButton({required this.uid, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: AppNotificationService.watchUnreadCount(uid),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        return IconButton(
          tooltip: 'Notifikasi',
          onPressed: onTap,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_outlined),
              if (unreadCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
