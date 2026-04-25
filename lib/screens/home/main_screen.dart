import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../providers/auth_provider.dart';
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
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshNotificationsIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
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
      const FoodTrackerScreen(),
      const HealthTrackerScreen(),
      const EducationScreen(),
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
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Pengaturan',
            onPressed: () async {
              await Navigator.pushNamed(context, AppConstants.routeSettings);
              if (!mounted) return;
              _refreshNotificationsIfNeeded(force: true);
            },
          ),
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
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
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
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              blurRadius: 8,
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
                                            ? AppColors.primary
                                            : AppColors.navUnselected,
                                        size: selected ? 25 : 23,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    AnimatedDefaultTextStyle(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: selected
                                            ? AppColors.primary
                                            : AppColors.navUnselected,
                                      ),
                                      child: Text(
                                        item.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
