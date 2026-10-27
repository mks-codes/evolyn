import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  void Function(Map<String, dynamic>)? _onNotificationTap;
  StreamSubscription<String>? _tokenRefreshSubscription;

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> initialize({
    required void Function(Map<String, dynamic> data)
        onNotificationTap,
  }) async {
    _onNotificationTap = onNotificationTap;

    if (_initialized) return;
    _initialized = true;

await _local.initialize(
  settings: const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  ),
  onDidReceiveNotificationResponse: (response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        _openNotification(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (error) {
      // Ignore malformed notification payloads.
    }
  },
);

    const channel = AndroidNotificationChannel(
      'evolyn_notifications',
      'Evolyn notifications',
      description: 'Learning reminders, weekly recaps and product updates',
      importance: Importance.high,
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Use the local-notification plugin to display messages while the app
    // is open, instead of displaying the same message twice on iOS.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _openNotification(message.data);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _openNotification(initialMessage.data);
    }

    _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen(
      (token) {
        unawaited(
          _saveToken(token).catchError((Object error) {
            // Log internally; don't expose device tokens to the user.
          }),
        );
      },
      onError: (Object error) {
        // Token refresh can be retried later.
      },
    );
  }

  Future<bool> requestPermissionAndRegister() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final allowed =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!allowed) return false;

    // On iOS, wait briefly for the APNs token before requesting the FCM token.
    if (Platform.isIOS) {
      String? apnsToken;

      for (var attempt = 0; attempt < 10; attempt++) {
        apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) break;

        await Future<void>.delayed(
          const Duration(milliseconds: 300),
        );
      }

      if (apnsToken == null) return false;
    }

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return false;

    await _saveToken(token);
    return true;
  }

  // Call after login to register an already-authorized device without
  // asking for permission again.
  Future<void> syncIfPermissionAlreadyGranted() async {
    if (_supabase.auth.currentUser == null) return;

    final settings = await _messaging.getNotificationSettings();

    final allowed =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    if (!allowed) return;

    if (Platform.isIOS) {
      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken == null) return;
    }

    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _saveToken(token);
    }
  }

  Future<void> _saveToken(String token) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    if (!Platform.isAndroid && !Platform.isIOS) return;

    await _supabase.from('device_push_tokens').upsert(
      {
        'user_id': user.id,
        'fcm_token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,fcm_token',
    );
  }

  // Call before signing the user out so the previous account is no longer
  // associated with this device.
  Future<void> unregisterCurrentDevice() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final token = await _messaging.getToken();
    if (token == null) return;

    await _supabase
        .from('device_push_tokens')
        .delete()
        .eq('user_id', user.id)
        .eq('fcm_token', token);
  }


Future<void> _showForegroundNotification(
  RemoteMessage message,
) async {
  final title =
      message.notification?.title ?? message.data['title']?.toString();
  final body =
      message.notification?.body ?? message.data['body']?.toString();

  if (title == null || body == null) return;

  await _local.show(
    id: message.messageId?.hashCode ??
        DateTime.now().millisecondsSinceEpoch,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'evolyn_notifications',
        'Evolyn notifications',
        channelDescription:
            'Learning reminders, weekly recaps and product updates',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    payload: jsonEncode(message.data),
  );
}


  void _openNotification(Map<String, dynamic> data) {
    _onNotificationTap?.call(data);
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }
}