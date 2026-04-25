import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../models/app_notification.dart';
import '../../providers/auth_provider.dart';
import '../../services/app_notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          if (user != null)
            TextButton(
              onPressed: () => AppNotificationService.markAllAsRead(user.uid),
              child: const Text('Tandai dibaca'),
            ),
        ],
      ),
      body: user == null
          ? const Center(
              child: Text(
                'Login untuk melihat notifikasi.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : StreamBuilder<List<AppNotification>>(
              stream: AppNotificationService.watchNotifications(user.uid),
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <AppNotification>[];
                if (snapshot.connectionState == ConnectionState.waiting && items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada notifikasi.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => AppNotificationService.refreshForUser(user),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => AppNotificationService.markAsRead(user.uid, item.id),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: item.isRead
                                  ? AppColors.border
                                  : _severityColor(item).withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: _severityColor(item).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  item.isFamilyAlert ? Icons.family_restroom : Icons.notifications_active_outlined,
                                  color: _severityColor(item),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (!item.isRead)
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: _severityColor(item),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.message,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _formatDateTime(item.createdAt),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textHint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  static Color _severityColor(AppNotification item) {
    if (item.typeKey.contains('family_alert')) return AppColors.error;
    if (item.typeKey.contains('warning') || item.typeKey.contains('trend')) {
      return AppColors.warning;
    }
    return AppColors.info;
  }

  static String _formatDateTime(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year;
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }
}
