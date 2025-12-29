import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/notification.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    
    // Skip initialization on web - local notifications don't work on web
    if (kIsWeb) {
      _initialized = true;
      print('⚠️ NotificationService: Skipping initialization on web platform');
      return;
    }

    // Initialize timezone
    tz.initializeTimeZones();

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions for Android 13+
    if (await _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission() ??
        false) {
      _initialized = true;
    } else {
      _initialized = true; // Still mark as initialized even if permission denied
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    print('Notification tapped: ${response.payload}');
    // You can navigate to specific screens based on the payload
  }

  Future<void> showNotification(AppNotification notification) async {
    if (!_initialized) {
      await initialize();
    }
    
    // Skip showing notifications on web - use browser notifications instead if needed
    if (kIsWeb) {
      print('📱 Notification (web): ${notification.title} - ${notification.body}');
      // On web, you could use browser notifications here if needed
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'orderq_channel',
      'OrderQ Notifications',
      channelDescription: 'Notifications for order updates and important events',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: notification.type.color,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      notification.id.hashCode,
      notification.title,
      notification.body,
      details,
      payload: notification.data?.toString(),
    );
  }

  Future<void> scheduleNotification(
    AppNotification notification,
    DateTime scheduledDate,
  ) async {
    if (!_initialized) {
      await initialize();
    }
    
    // Skip scheduling notifications on web
    if (kIsWeb) {
      print('📱 Scheduled notification (web): ${notification.title} - ${notification.body}');
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'orderq_channel',
      'OrderQ Notifications',
      channelDescription: 'Notifications for order updates and important events',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: notification.type.color,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      notification.id.hashCode,
      notification.title,
      notification.body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: notification.data?.toString(),
    );
  }

  Future<void> cancelNotification(String notificationId) async {
    if (kIsWeb) return;
    await _notifications.cancel(notificationId.hashCode);
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
  }

  // Helper methods to create common notifications
  AppNotification createOrderCreatedNotification({
    required String orderCode,
    required String restaurantName,
    String? orderId,
  }) {
    return AppNotification(
      id: 'order_created_${orderId ?? orderCode}',
      title: 'New Order Created',
      body: 'Order $orderCode from $restaurantName is now open',
      type: NotificationType.orderCreated,
      createdAt: DateTime.now(),
      data: {
        'order_code': orderCode,
        'order_id': orderId,
        'type': 'order_created',
      },
    );
  }

  AppNotification createOrderUpdatedNotification({
    required String orderCode,
    required String status,
    String? orderId,
  }) {
    return AppNotification(
      id: 'order_updated_${orderId ?? orderCode}',
      title: 'Order Updated',
      body: 'Order $orderCode status changed to $status',
      type: NotificationType.orderUpdated,
      createdAt: DateTime.now(),
      data: {
        'order_code': orderCode,
        'order_id': orderId,
        'status': status,
        'type': 'order_updated',
      },
    );
  }

  AppNotification createItemAddedNotification({
    required String orderCode,
    required String itemName,
    required String userName,
    String? orderId,
  }) {
    return AppNotification(
      id: 'item_added_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Item Added',
      body: '$userName added $itemName to order $orderCode',
      type: NotificationType.itemAdded,
      createdAt: DateTime.now(),
      data: {
        'order_code': orderCode,
        'order_id': orderId,
        'item_name': itemName,
        'user_name': userName,
        'type': 'item_added',
      },
    );
  }

  AppNotification createPaymentNotification({
    required String orderCode,
    required String userName,
    required double amount,
    required bool isPaid,
    String? orderId,
  }) {
    return AppNotification(
      id: 'payment_${DateTime.now().millisecondsSinceEpoch}',
      title: isPaid ? 'Payment Received' : 'Payment Marked Paid',
      body: '$userName ${isPaid ? 'paid' : 'marked as paid'} ${amount.toStringAsFixed(2)} EGP for order $orderCode',
      type: isPaid ? NotificationType.paymentReceived : NotificationType.paymentMarkedPaid,
      createdAt: DateTime.now(),
      data: {
        'order_code': orderCode,
        'order_id': orderId,
        'user_name': userName,
        'amount': amount,
        'is_paid': isPaid,
        'type': 'payment',
      },
    );
  }

  AppNotification createCutoffTimeReminder({
    required String orderCode,
    required DateTime cutoffTime,
    String? orderId,
  }) {
    final timeUntil = cutoffTime.difference(DateTime.now());
    final minutes = timeUntil.inMinutes;
    
    return AppNotification(
      id: 'cutoff_reminder_${orderId ?? orderCode}',
      title: 'Cutoff Time Reminder',
      body: 'Order $orderCode cutoff time is in ${minutes} minutes',
      type: NotificationType.cutoffTimeReminder,
      createdAt: DateTime.now(),
      data: {
        'order_code': orderCode,
        'order_id': orderId,
        'cutoff_time': cutoffTime.toIso8601String(),
        'type': 'cutoff_reminder',
      },
    );
  }
}

