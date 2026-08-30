import 'package:cropsync/services/notification_service.dart';
import 'package:cropsync/theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Mark all as read when opening notifications screen
    NotificationService.unreadNotifier.value = 0;
  }

  IconData _getIconForScreen(String? screen) {
    switch (screen) {
      case 'weather':
        return Icons.cloud_rounded;
      case 'market':
        return Icons.trending_up_rounded;
      case 'seeds':
        return Icons.grain_rounded;
      case 'shop':
        return Icons.shopping_bag_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColorForScreen(String? screen) {
    switch (screen) {
      case 'weather':
        return const Color(0xFF0284C7); // Sky Blue
      case 'market':
        return const Color(0xFF16A34A); // Green
      case 'seeds':
        return const Color(0xFFD97706); // Amber
      case 'shop':
        return const Color(0xFF7C3AED); // Purple
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = NotificationService.notifications;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('notifications_title'.tr(), style: AppTheme.appBarTitle),
        backgroundColor: Colors.white,
        leading: AppTheme.backButton(context, color: AppTheme.appBarText),
        elevation: 0,
        actions: [
          if (list.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  NotificationService.notifications.clear();
                  NotificationService.unreadNotifier.value = 0;
                });
              },
              child: Text(
                "Clear All",
                style: TextStyle(
                  color: Colors.red[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.notifications_off_rounded, size: 48, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'notifications_empty'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'notifications_empty_desc'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final item = list[index];
                final title = item.notification?.title ?? 'Notification';
                final body = item.notification?.body ?? '';
                final screen = item.data['screen']?.toString();
                final categoryColor = _getColorForScreen(screen);
                final categoryIcon = _getIconForScreen(screen);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(categoryIcon, color: categoryColor, size: 24),
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        body,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                      ),
                    ),
                    trailing: screen != null
                        ? const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8))
                        : null,
                    onTap: () {
                      NotificationService.handleNotificationClick(item);
                    },
                  ),
                );
              },
            ),
    );
  }
}


