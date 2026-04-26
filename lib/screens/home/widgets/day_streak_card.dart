import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../models/user_model.dart';

class DayStreakCard extends StatelessWidget {
  final UserModel user;
  const DayStreakCard({required this.user});

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  @override
  Widget build(BuildContext context) {
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF87CEEB), Color(0xFFB0E0E6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user.currentStreak}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const Text(
                          'Hari',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
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
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    const Text('⭐', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 2),
                    Text(
                      'Rekor\n${user.longestStreak}',
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

          // Motivation text
          Text(
            user.currentStreak > 0
                ? 'Jaga api tetap menyala! 🔥'
                : 'Mulai sekarang! Konsistensi adalah kunci kesuksesan.',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.4,
            ),
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
                      color: Colors.red.withValues(alpha: 0.3),
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
