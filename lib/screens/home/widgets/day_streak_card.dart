import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/user_model.dart';

class DayStreakCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback? onInputFood;
  final VoidCallback? onInputHealth;
  const DayStreakCard({
    super.key,
    required this.user,
    this.onInputFood,
    this.onInputHealth,
  });

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    // Filter loginDates untuk bulan ini
    final thisMonthLogins = user.loginDates.where((d) {
      return d.year == currentYear && d.month == currentMonth;
    }).toSet();

    // Generate semua hari dalam bulan ini
    final daysInMonth = _getDaysInMonth(currentYear, currentMonth);
    final firstDayOfWeek = DateTime(currentYear, currentMonth, 1).weekday;
    final hasInputToday = thisMonthLogins.any((d) => d.day == now.day);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [const Color(0xFF0D1B3E), const Color(0xFF000621)]
              : [const Color(0xFF0B3C8A), const Color(0xFF1E5BB8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
            blurRadius: 22,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: (isDark ? const Color(0xFF62E7D9) : Colors.white)
                .withValues(alpha: isDark ? 0.08 : 0.35),
            blurRadius: 18,
            spreadRadius: -6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Streak badge + Longest streak
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Current Streak
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2A5E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                    if (hasInputToday)
                      BoxShadow(
                        color: const Color(0xFFFF6D00).withValues(alpha: 0.35),
                        blurRadius: 14,
                        spreadRadius: 0.2,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ColorFiltered(
                      colorFilter: hasInputToday
                          ? const ColorFilter.mode(
                              Colors.transparent, BlendMode.dst)
                          : const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0,      0,      0,      1, 0,
                            ]),
                      child: const Text(
                        '🔥',
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Hari',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '${user.currentStreak}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: hasInputToday
                                ? Colors.redAccent
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Longest Streak
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 2),
                    Text(
                      'Total\n${user.currentStreak}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Motivation + Quick Actions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Tambah catatan untuk menyalakan api',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
              _quickActionButton(
                label: 'Input Makanan',
                onTap: onInputFood,
              ),
              _quickActionButton(
                label: 'Input Health Track',
                onTap: onInputHealth,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Calendar header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat(
                  'MMMM y',
                  'id_ID',
                ).format(DateTime(currentYear, currentMonth)),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: hasInputToday
                          ? Colors.red.withValues(alpha: 0.5)
                          : Colors.grey.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Aktif',
                    style: TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mini calendar
          _MiniCalendar(
            daysInMonth: daysInMonth,
            firstDayOfWeek: firstDayOfWeek,
            loginDays: thisMonthLogins,
          ),
          const SizedBox(height: 12),

          // Daily reward badges
          _RewardBadges(currentMonth: currentMonth, loginDays: thisMonthLogins),
        ],
      ),
    );
  }

  Widget _quickActionButton({
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MINI CALENDAR
// ─────────────────────────────────────────────────────────────────────────────

class _MiniCalendar extends StatelessWidget {
  final int daysInMonth;
  final int firstDayOfWeek;
  final Set<DateTime> loginDays;

  const _MiniCalendar({
    required this.daysInMonth,
    required this.firstDayOfWeek,
    required this.loginDays,
  });

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cells = <Widget>[];

    // Day labels
    for (var label in dayLabels) {
      cells.add(
        Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }

    // Empty cells sebelum hari pertama
    for (var i = 0; i < firstDayOfWeek - 1; i++) {
      cells.add(const SizedBox.shrink());
    }

    // Hari-hari dalam bulan
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(
        loginDays.isNotEmpty ? loginDays.first.year : now.year,
        loginDays.isNotEmpty ? loginDays.first.month : now.month,
        day,
      );
      final hasLogin = loginDays.any((d) => d.day == day);
      final isToday =
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;

      cells.add(
        Container(
          decoration: BoxDecoration(
            color: hasLogin
                ? Colors.red.shade400
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isToday && hasLogin
                  ? Colors.white
                  : hasLogin
                  ? Colors.red.shade600
                  : Colors.white.withValues(alpha: 0.2),
              width: isToday && hasLogin ? 2.5 : 1,
            ),
            boxShadow: hasLogin
                ? [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 13,
              fontWeight: hasLogin ? FontWeight.bold : FontWeight.w500,
              color: hasLogin ? Colors.white : Colors.white70,
              letterSpacing: 0.3,
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.1,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: cells,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REWARD BADGES (Daily bonus)
// ─────────────────────────────────────────────────────────────────────────────

class _RewardBadges extends StatelessWidget {
  final int currentMonth;
  final Set<DateTime> loginDays;

  const _RewardBadges({required this.currentMonth, required this.loginDays});

  @override
  Widget build(BuildContext context) {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const bonuses = ['+2', '+2', '+2', '+2', '+2', '+2', '+2'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reward Harian',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (ctx, idx) {
              return Container(
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      days[idx],
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bonuses[idx],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.yellow,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
