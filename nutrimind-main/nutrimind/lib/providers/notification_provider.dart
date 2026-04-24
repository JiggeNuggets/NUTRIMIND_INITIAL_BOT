import 'dart:async';

import 'package:flutter/material.dart';

import '../models/meal_model.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';

class NotificationProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  StreamSubscription<List<NotificationModel>>? _notificationsSubscription;
  StreamSubscription<int>? _unreadCountSubscription;

  String? _uid;
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _loading = false;
  String? _error;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get loading => _loading;
  String? get error => _error;

  void setUser(String? uid) {
    if (_uid == uid) return;
    _notificationsSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    _uid = uid;

    if (uid == null || uid.isEmpty) {
      _notifications = [];
      _unreadCount = 0;
      _loading = false;
      _error = null;
      notifyListeners();
      return;
    }

    listenToNotifications();
    listenToUnreadNotificationCount();
  }

  void listenToNotifications({String? uid}) {
    if (uid != null) _uid = uid;
    final currentUid = _uid;
    if (currentUid == null || currentUid.isEmpty) return;

    _notificationsSubscription?.cancel();
    _loading = true;
    _error = null;
    notifyListeners();

    _notificationsSubscription =
        _firestoreService.notificationsStream(currentUid).listen(
      (notifications) {
        _notifications = notifications;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object error) {
        _notifications = [];
        _loading = false;
        _error = 'Could not load notifications. Please try again.';
        notifyListeners();
      },
    );
  }

  void listenToUnreadNotificationCount({String? uid}) {
    if (uid != null) _uid = uid;
    final currentUid = _uid;
    if (currentUid == null || currentUid.isEmpty) return;

    _unreadCountSubscription?.cancel();
    _unreadCountSubscription =
        _firestoreService.unreadNotificationCountStream(currentUid).listen(
      (count) {
        _unreadCount = count;
        notifyListeners();
      },
      onError: (Object error) {
        _unreadCount = 0;
        notifyListeners();
      },
    );
  }

  Future<void> createNotification(
    String targetUid,
    NotificationModel notification,
  ) async {
    if (targetUid.isEmpty) return;
    try {
      await _firestoreService.createNotification(targetUid, notification);
      _error = null;
    } catch (e) {
      _error = 'Could not create notification.';
      notifyListeners();
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    final currentUid = _uid;
    if (currentUid == null || currentUid.isEmpty || notificationId.isEmpty) {
      return;
    }
    await _firestoreService.markNotificationAsRead(
      currentUid,
      notificationId,
    );
  }

  Future<void> markAllNotificationsAsRead() async {
    final currentUid = _uid;
    if (currentUid == null || currentUid.isEmpty) return;
    await _firestoreService.markAllNotificationsAsRead(currentUid);
  }

  Future<void> deleteNotification(String notificationId) async {
    final currentUid = _uid;
    if (currentUid == null || currentUid.isEmpty || notificationId.isEmpty) {
      return;
    }
    await _firestoreService.deleteNotification(currentUid, notificationId);
  }

  Future<void> createMealReminderForMeal({
    required String uid,
    required MealModel meal,
  }) async {
    if (!_isActionableTodayMeal(uid, meal)) return;
    await createNotification(
      uid,
      NotificationModel(
        id: 'mealReminder_${_dateKey(meal.date)}_${meal.id}',
        category: 'mealPlan',
        type: 'mealReminder',
        mealId: meal.id,
        title: '${meal.typeLabel} plan',
        message: 'Your ${meal.type.name} plan is ready.',
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> createLogReminderForMeal({
    required String uid,
    required MealModel meal,
  }) async {
    if (!_isActionableTodayMeal(uid, meal)) return;
    await createNotification(
      uid,
      NotificationModel(
        id: 'logReminder_${_dateKey(meal.date)}_${meal.type.name}',
        category: 'mealPlan',
        type: 'logReminder',
        mealId: meal.id,
        title: 'Log ${meal.typeLabel}',
        message: "Don't forget to log your ${meal.type.name}.",
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> createMealRemindersForMeals({
    required String uid,
    required List<MealModel> meals,
    bool includeLogReminders = true,
  }) async {
    for (final meal in meals) {
      await createMealReminderForMeal(uid: uid, meal: meal);
      if (includeLogReminders) {
        await createLogReminderForMeal(uid: uid, meal: meal);
      }
    }
  }

  Future<void> createBudgetWarningIfNeeded({
    required String uid,
    required List<MealModel> meals,
    required double dailyBudget,
    DateTime? date,
  }) async {
    if (uid.isEmpty) return;
    final targetDate = _dateOnly(date ?? DateTime.now());
    if (targetDate != _dateOnly(DateTime.now())) return;

    final dailyCost = meals
        .where((meal) => _dateOnly(meal.date) == targetDate)
        .fold<double>(0, (sum, meal) => sum + meal.price);
    if (dailyBudget > 0 && dailyCost >= dailyBudget * 0.85) {
      await createNotification(
        uid,
        NotificationModel(
          id: 'budgetWarning_${_dateKey(targetDate)}',
          category: 'mealPlan',
          type: 'budgetWarning',
          title: 'Budget warning',
          message: dailyCost > dailyBudget
              ? 'You are over your daily food budget.'
              : 'You are close to your daily food budget.',
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> createPalengkeReminder({
    required String uid,
    DateTime? date,
  }) async {
    if (uid.isEmpty) return;
    final targetDate = date ?? DateTime.now();
    await createNotification(
      uid,
      NotificationModel(
        id: 'palengkeReminder_${_weekKey(targetDate)}',
        category: 'mealPlan',
        type: 'palengkeReminder',
        title: 'Palengke List',
        message: 'Check your weekly Palengke List before shopping.',
        createdAt: DateTime.now(),
      ),
    );
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    super.dispose();
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}$month$day';
  }

  String _weekKey(DateTime value) {
    final weekStart = value.subtract(Duration(days: value.weekday - 1));
    return _dateKey(weekStart);
  }

  bool _isActionableTodayMeal(String uid, MealModel meal) {
    if (uid.isEmpty || meal.status == MealStatus.logged) return false;
    return _dateOnly(meal.date) == _dateOnly(DateTime.now());
  }
}
