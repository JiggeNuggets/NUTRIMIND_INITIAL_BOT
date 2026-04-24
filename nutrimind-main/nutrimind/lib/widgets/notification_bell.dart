import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notification_provider.dart';
import '../screens/main/notifications_screen.dart';
import '../theme/app_theme.dart';
import '../theme/modern_app_theme.dart';

class NotificationBell extends StatelessWidget {
  final bool boxed;

  const NotificationBell({
    super.key,
    this.boxed = false,
  });

  @override
  Widget build(BuildContext context) {
    final unreadCount =
        context.select<NotificationProvider, int>((p) => p.unreadCount);
    final label = unreadCount > 99 ? '99+' : '$unreadCount';

    final icon = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          unreadCount > 0
              ? Icons.notifications_active_outlined
              : Icons.notifications_outlined,
          color: AppTheme.textDark,
          size: 20,
        ),
        if (unreadCount > 0)
          Positioned(
            top: -8,
            right: -9,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.orangeAccent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );

    final child = boxed
        ? Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ModernAppTheme.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ModernAppTheme.divider),
              boxShadow: ModernAppTheme.shadowSm,
            ),
            child: icon,
          )
        : icon;

    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      ),
      icon: child,
    );
  }
}
