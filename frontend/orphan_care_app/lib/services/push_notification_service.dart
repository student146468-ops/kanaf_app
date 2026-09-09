import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../router/kanaf_router.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> kanafFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // The app can still run when Firebase config is absent in development APKs.
  }
}

void configureKanafFirebaseBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(
    kanafFirebaseMessagingBackgroundHandler,
  );
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'kanaf_notifications',
    'Kanaf notifications',
    description: 'Kanaf account updates and activity notifications',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  GlobalKey<NavigatorState>? _navigatorKey;
  ApiService? _apiService;
  bool _firebaseReady = false;
  bool _localNotificationsReady = false;
  bool _initialized = false;

  Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
    required ApiService apiService,
  }) async {
    if (_initialized) return;
    _initialized = true;
    _navigatorKey = navigatorKey;
    _apiService = apiService;

    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (error, stackTrace) {
      debugPrint('Kanaf FCM disabled: Firebase config is missing. $error');
      debugPrint('$stackTrace');
      return;
    }

    await _initializeLocalNotifications();
    await _requestPermission();
    await registerCurrentDevice();

    _messaging.onTokenRefresh.listen((token) {
      debugPrint('FCM TOKEN RECEIVED');
      registerCurrentDevice(tokenOverride: token);
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleRemoteMessageTap(initialMessage);
      });
    }
  }

  Future<void> registerCurrentDevice({String? tokenOverride}) async {
    if (!_firebaseReady) return;
    final apiService = _apiService;
    if (apiService == null || !await apiService.isAuthenticated()) return;

    try {
      final token = tokenOverride ?? await _messaging.getToken();
      if (token == null || token.trim().isEmpty) return;
      debugPrint('FCM TOKEN RECEIVED');
      await apiService.registerDeviceToken(
        token.trim(),
        platform: _platformName(),
      );
      debugPrint('DEVICE TOKEN REGISTERED');
    } catch (error, stackTrace) {
      debugPrint('Kanaf FCM token registration failed: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> deactivateCurrentDeviceToken() async {
    if (!_firebaseReady) return;
    final apiService = _apiService;
    if (apiService == null || !await apiService.isAuthenticated()) return;

    try {
      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) return;
      await apiService.deactivateDeviceToken(token.trim());
    } catch (error, stackTrace) {
      debugPrint('Kanaf FCM token deactivation failed: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsReady) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            _handleNotificationData(decoded);
          } else if (decoded is Map) {
            _handleNotificationData(Map<String, dynamic>.from(decoded));
          }
        } catch (error) {
          debugPrint('Kanaf notification payload parse failed: $error');
        }
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    _localNotificationsReady = true;
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
      'Kanaf FCM permission status: ${settings.authorizationStatus.name}',
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null && body == null) return;

    await _initializeLocalNotifications();
    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleRemoteMessageTap(RemoteMessage message) {
    _handleNotificationData(message.data);
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    final apiService = _apiService;
    final notificationId = int.tryParse(
      data['notification_id']?.toString() ?? '',
    );
    if (apiService != null && notificationId != null) {
      apiService.markNotificationRead(notificationId).catchError((error) {
        debugPrint('Kanaf mark push notification read failed: $error');
      });
    }

    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    final type = data['type']?.toString() ?? '';
    final relatedModel = data['related_model']?.toString() ?? '';
    final relatedId = int.tryParse(
      data['related_object_id']?.toString() ?? '',
    );

    if (type == 'need' || relatedModel == 'need') {
      navigator.pushNamed(
        KanafRoutes.needDetails,
        arguments: {'id': relatedId},
      );
      return;
    }

    if (type == 'volunteer' || relatedModel == 'volunteer_opportunity') {
      navigator.pushNamed(
        KanafRoutes.volunteerOpportunityDetails,
        arguments: relatedId == null ? null : {'id': relatedId},
      );
      return;
    }

    if (type == 'donation' || type == 'donation_status') {
      navigator.pushNamed(KanafRoutes.donationHistory);
      return;
    }

    navigator.pushNamed(KanafRoutes.donorNotifications);
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }
}
