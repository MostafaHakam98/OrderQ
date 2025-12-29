import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification.dart';
import '../models/order.dart';
import '../services/notification_service.dart';
import '../services/notifications_websocket_service.dart';

class NotificationsProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final List<AppNotification> _notifications = [];
  bool _isLoading = false;
  NotificationsWebSocketService? _wsService;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  List<AppNotification> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();
  int get unreadCount => unreadNotifications.length;

  bool get isLoading => _isLoading;

  NotificationsProvider() {
    _loadNotifications();
    _initializeWebSocket();
  }

  Future<void> _initializeWebSocket() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      // Only connect if user is authenticated
      if (token != null && token.isNotEmpty) {
        _wsService = NotificationsWebSocketService(prefs);
        _wsService!.connect((order) async {
          // Handle new order notification
          // Check if we should notify (don't notify if order is private and user doesn't have access)
          // For now, we'll notify for all new orders - the backend will handle access control
          await notifyOrderCreated(
            orderCode: order.code,
            restaurantName: order.restaurant.name,
            orderId: order.id.toString(),
          );
        });
      }
    } catch (e) {
      print('Error initializing notifications WebSocket: $e');
    }
  }

  void connectWebSocket() {
    _initializeWebSocket();
  }

  void disconnectWebSocket() {
    _wsService?.disconnect();
    _wsService = null;
  }

  Future<void> loadNotifications() async {
    await _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getStringList('notifications') ?? [];
      _notifications.clear();
      _notifications.addAll(
        notificationsJson.map((json) {
          // Parse JSON string to Map
          // Simple parsing - in production, use proper JSON parsing
          try {
            final parts = json.split('|');
            if (parts.length >= 5) {
              return AppNotification(
                id: parts[0],
                title: parts[1],
                body: parts[2],
                type: NotificationType.values.firstWhere(
                  (e) => e.toString().split('.').last == parts[3],
                  orElse: () => NotificationType.info,
                ),
                createdAt: DateTime.parse(parts[4]),
                isRead: parts.length > 5 ? parts[5] == 'true' : false,
              );
            }
          } catch (e) {
            print('Error parsing notification: $e');
          }
          return null;
        }).whereType<AppNotification>(),
      );
      
      // Sort by creation date (newest first)
      _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('Error loading notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = _notifications.map((n) {
        // Simple serialization - in production, use proper JSON
        return '${n.id}|${n.title}|${n.body}|${n.type.toString().split('.').last}|${n.createdAt.toIso8601String()}|${n.isRead}';
      }).toList();
      await prefs.setStringList('notifications', notificationsJson);
    } catch (e) {
      print('Error saving notifications: $e');
    }
  }

  Future<void> addNotification(AppNotification notification) async {
    // Check if notification already exists (avoid duplicates)
    if (_notifications.any((n) => n.id == notification.id)) {
      return;
    }

    _notifications.insert(0, notification);
    await _saveNotifications();
    
    // Show local notification
    await _notificationService.showNotification(notification);
    
    notifyListeners();
  }

  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      await _saveNotifications();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    await _saveNotifications();
    notifyListeners();
  }

  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    await _saveNotifications();
    notifyListeners();
  }

  Future<void> clearAllNotifications() async {
    _notifications.clear();
    await _saveNotifications();
    notifyListeners();
  }

  // Helper methods for common notification types
  Future<void> notifyOrderCreated({
    required String orderCode,
    required String restaurantName,
    String? orderId,
  }) async {
    final notification = _notificationService.createOrderCreatedNotification(
      orderCode: orderCode,
      restaurantName: restaurantName,
      orderId: orderId,
    );
    await addNotification(notification);
  }

  Future<void> notifyOrderUpdated({
    required String orderCode,
    required String status,
    String? orderId,
  }) async {
    final notification = _notificationService.createOrderUpdatedNotification(
      orderCode: orderCode,
      status: status,
      orderId: orderId,
    );
    await addNotification(notification);
  }

  Future<void> notifyItemAdded({
    required String orderCode,
    required String itemName,
    required String userName,
    String? orderId,
  }) async {
    final notification = _notificationService.createItemAddedNotification(
      orderCode: orderCode,
      itemName: itemName,
      userName: userName,
      orderId: orderId,
    );
    await addNotification(notification);
  }

  Future<void> notifyPayment({
    required String orderCode,
    required String userName,
    required double amount,
    required bool isPaid,
    String? orderId,
  }) async {
    final notification = _notificationService.createPaymentNotification(
      orderCode: orderCode,
      userName: userName,
      amount: amount,
      isPaid: isPaid,
      orderId: orderId,
    );
    await addNotification(notification);
  }

  Future<void> scheduleCutoffReminder({
    required String orderCode,
    required DateTime cutoffTime,
    String? orderId,
  }) async {
    // Schedule notification 15 minutes before cutoff
    final reminderTime = cutoffTime.subtract(const Duration(minutes: 15));
    if (reminderTime.isAfter(DateTime.now())) {
      final notification = _notificationService.createCutoffTimeReminder(
        orderCode: orderCode,
        cutoffTime: cutoffTime,
        orderId: orderId,
      );
      await _notificationService.scheduleNotification(notification, reminderTime);
      
      // Also add to in-app notifications
      await addNotification(notification);
    }
  }
}

