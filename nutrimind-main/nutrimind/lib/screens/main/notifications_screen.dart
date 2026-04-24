import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/modern_app_theme.dart';
import '../../widgets/state_views.dart';
import 'meal_plan_screen.dart';
import 'post_detail_screen.dart';
import 'user_profile_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: ModernAppTheme.backgroundNeutral,
        appBar: AppBar(
          backgroundColor: ModernAppTheme.backgroundNeutral,
          surfaceTintColor: Colors.transparent,
          title: const Text('Notifications'),
          actions: [
            Consumer<NotificationProvider>(
              builder: (context, provider, _) {
                if (provider.unreadCount == 0) return const SizedBox.shrink();
                return TextButton(
                  onPressed: provider.markAllNotificationsAsRead,
                  child: const Text(
                    'Mark all as read',
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppTheme.primaryGreen,
            labelColor: AppTheme.primaryGreen,
            unselectedLabelColor: AppTheme.textMid,
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Community'),
              Tab(text: 'Meal Plan'),
            ],
          ),
        ),
        body: Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            if (provider.loading) {
              return const LoadingStateView(
                message: 'Loading notifications...',
              );
            }

            if (provider.error != null) {
              return ErrorStateView(
                message: provider.error,
                onRetry: () => provider.listenToNotifications(),
              );
            }

            final all = provider.notifications;
            return TabBarView(
              children: [
                _NotificationsList(notifications: all),
                _NotificationsList(
                  notifications: all
                      .where((notification) =>
                          notification.category == 'community')
                      .toList(growable: false),
                ),
                _NotificationsList(
                  notifications: all
                      .where(
                          (notification) => notification.category == 'mealPlan')
                      .toList(growable: false),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotificationsList extends StatelessWidget {
  final List<NotificationModel> notifications;

  const _NotificationsList({required this.notifications});

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return const _StateMessage(
        icon: Icons.notifications_none_outlined,
        title: 'No notifications yet.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _NotificationCard(notification: notifications[index]);
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(notification.type);
    return Material(
      color: notification.isRead ? ModernAppTheme.white : AppTheme.softGreen,
      borderRadius: BorderRadius.circular(ModernAppTheme.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(ModernAppTheme.radiusLg),
        onTap: () => _openNotification(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_iconForType(notification.type),
                    color: accent, size: 21),
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
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.orangeAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        color: AppTheme.textMid,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          notification.timeAgo,
                          style: const TextStyle(
                            color: AppTheme.textLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        _TypeChip(notification: notification),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Notification options',
                icon: const Icon(Icons.more_vert,
                    color: AppTheme.textLight, size: 18),
                onSelected: (value) {
                  if (value == 'read') {
                    context
                        .read<NotificationProvider>()
                        .markNotificationAsRead(notification.id);
                  } else if (value == 'delete') {
                    context
                        .read<NotificationProvider>()
                        .deleteNotification(notification.id);
                  }
                },
                itemBuilder: (_) => [
                  if (!notification.isRead)
                    const PopupMenuItem(
                      value: 'read',
                      child: Text('Mark as read'),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNotification(BuildContext context) async {
    final provider = context.read<NotificationProvider>();
    await provider.markNotificationAsRead(notification.id);

    if (!context.mounted) return;
    if (notification.postId != null && notification.postId!.isNotEmpty) {
      final post = await FirestoreService().getPost(notification.postId!);
      if (!context.mounted) return;
      if (post == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This post is no longer available.'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
      );
      return;
    }

    if (notification.mealId != null || notification.category == 'mealPlan') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MealPlanScreen()),
      );
      return;
    }

    if (notification.fromUserId != null &&
        notification.fromUserId!.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(
            userId: notification.fromUserId!,
            fallbackName: notification.fromUserName,
            fallbackPhotoUrl: notification.fromUserPhotoUrl,
          ),
        ),
      );
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'follow':
        return Icons.person_add_alt_1_outlined;
      case 'like':
        return Icons.favorite_border;
      case 'comment':
        return Icons.chat_bubble_outline;
      case 'mealReminder':
        return Icons.restaurant_menu_outlined;
      case 'logReminder':
        return Icons.check_circle_outline;
      case 'budgetWarning':
        return Icons.account_balance_wallet_outlined;
      case 'palengkeReminder':
        return Icons.shopping_basket_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _accentColor(String type) {
    switch (type) {
      case 'like':
        return AppTheme.errorRed;
      case 'budgetWarning':
        return AppTheme.orangeAccent;
      case 'comment':
        return AppTheme.infoBlue;
      default:
        return AppTheme.primaryGreen;
    }
  }
}

class _TypeChip extends StatelessWidget {
  final NotificationModel notification;

  const _TypeChip({required this.notification});

  @override
  Widget build(BuildContext context) {
    final label =
        notification.category == 'mealPlan' ? 'Meal Plan' : 'Community';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ModernAppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textMid,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;

  const _StateMessage({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.textLight, size: 48),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textMid,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
