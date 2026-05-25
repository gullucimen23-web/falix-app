import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ChatNotificationService {
  ChatNotificationService._();
  static final ChatNotificationService instance = ChatNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init({required String role}) async {
    if (_initialized) return;
    _initialized = true;

    if (!kIsWeb) {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      const settings = InitializationSettings(android: android, iOS: ios);
      await _local.initialize(settings);

      final token = await _messaging.getToken();
      await _saveToken(role: role, token: token);

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await _saveToken(role: role, token: newToken);
      });

      FirebaseMessaging.onMessage.listen((message) async {
        final notification = message.notification;
        final title = notification?.title ?? message.data['title'] ?? 'Falix';
        final body = notification?.body ?? message.data['body'] ?? 'Yeni mesajın var.';
        await showLocal(title: title, body: body);
      });
    }
  }

  Future<void> _saveToken({required String role, String? token}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || token == null || token.trim().isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    final collection = role == 'expert' ? 'experts' : 'users';

    await firestore.collection(collection).doc(user.uid).set({
      'fcmToken': token,
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastTokenUpdateAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> showLocal({required String title, required String body}) async {
    if (kIsWeb) return;
    const android = AndroidNotificationDetails(
      'falix_chat_channel',
      'Falix Sohbet Bildirimleri',
      channelDescription: 'Uzman ve kullanıcı canlı sohbet bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);
    await _local.show(DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details);
  }
}
