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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          if (user != null)
            TextButton(
              onPressed: () => AppNotificationService.markAllAsRead(user.uid),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white : theme.primaryColor,
              ),
              child: Text(
                'Tandai dibaca',
                style: TextStyle(
                  color: isDark ? Colors.white : theme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (user != null)
            IconButton(
              tooltip: 'Bersihkan semua',
              onPressed: () => _confirmClearAll(context, user.uid),
              icon: Icon(
                Icons.delete_sweep_outlined,
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
      body: user == null
          ? Center(
              child: Text(
                'Login untuk melihat notifikasi.',
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              ),
            )
          : StreamBuilder<List<AppNotification>>(
              stream: AppNotificationService.watchNotifications(user.uid),
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <AppNotification>[];
                if (snapshot.connectionState == ConnectionState.waiting && items.isEmpty) {
                  return Center(
                    child: CircularProgressIndicator(color: theme.primaryColor),
                  );
                }

                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'Belum ada notifikasi.',
                      style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => AppNotificationService.refreshForUser(user),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 132),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          AppNotificationService.deleteNotification(user.uid, item.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Notifikasi dihapus')),
                          );
                        },
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => AppNotificationService.markAsRead(user.uid, item.id),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.cardTheme.color ?? theme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              border: Border.all(
                                color: item.isRead
                                    ? theme.dividerColor
                                    : _severityColor(item, theme).withValues(alpha: 0.45),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: _severityColor(item, theme).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    item.isFamilyAlert
                                        ? Icons.family_restroom
                                        : Icons.notifications_active_outlined,
                                    color: _severityColor(item, theme),
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
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: theme.textTheme.titleMedium?.color,
                                              ),
                                            ),
                                          ),
                                          if (!item.isRead)
                                            Container(
                                              width: 10,
                                              height: 10,
                                              decoration: BoxDecoration(
                                                color: _severityColor(item, theme),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.message,
                                        style: TextStyle(
                                          color: theme.textTheme.bodyMedium?.color,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _formatDateTime(item.createdAt),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: theme.hintColor,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Hapus',
                                            onPressed: () => _confirmDeleteOne(
                                              context,
                                              user.uid,
                                              item,
                                            ),
                                            icon: Icon(
                                              Icons.delete_outline,
                                              size: 20,
                                              color: theme.colorScheme.error,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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

  static Color _severityColor(AppNotification item, ThemeData theme) {
    if (item.typeKey.contains('family_alert')) return AppColors.error;
    if (item.typeKey.contains('warning') || item.typeKey.contains('trend')) {
      return AppColors.warning;
    }
    return theme.brightness == Brightness.dark
        ? theme.primaryColor
        : AppColors.info;
  }

  static String _formatDateTime(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year;
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  static Future<void> _confirmDeleteOne(
    BuildContext context,
    String uid,
    AppNotification item,
  ) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus notifikasi'),
        content: Text('Hapus notifikasi "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Hapus',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AppNotificationService.deleteNotification(uid, item.id);
    }
  }

  static Future<void> _confirmClearAll(BuildContext context, String uid) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bersihkan semua'),
        content: const Text(
          'Semua notifikasi akan dihapus. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Hapus semua',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AppNotificationService.clearAllNotifications(uid);
    }
  }
}
