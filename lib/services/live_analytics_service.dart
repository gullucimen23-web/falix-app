import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class LiveAnalyticsService {
  LiveAnalyticsService._();
  static final LiveAnalyticsService instance = LiveAnalyticsService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _lastScreenKey;
  DateTime? _lastScreenWriteAt;

  User? get _user => _auth.currentUser;

  Future<void> trackScreen({
    required String screenName,
    required String screenKey,
    Map<String, dynamic>? extra,
  }) async {
    final user = _user;
    if (user == null) return;

    final now = DateTime.now();
    if (_lastScreenKey == screenKey &&
        _lastScreenWriteAt != null &&
        now.difference(_lastScreenWriteAt!).inSeconds < 4) {
      return;
    }

    _lastScreenKey = screenKey;
    _lastScreenWriteAt = now;

    final payload = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'currentScreen': screenName,
      'currentScreenKey': screenKey,
      'lastActiveAt': FieldValue.serverTimestamp(),
      'isOnline': true,
      'platform': defaultTargetPlatform.name,
      'updatedAt': FieldValue.serverTimestamp(),
      if (extra != null) ...extra,
    };

    await Future.wait([
      _db.collection('live_activity').doc(user.uid).set(payload, SetOptions(merge: true)),
      _db.collection('users').doc(user.uid).set({
        'currentScreen': screenName,
        'currentScreenKey': screenKey,
        'lastActiveAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)),
    ]);
  }

  Future<void> trackAction(String action, {Map<String, dynamic>? meta}) async {
    final user = _user;
    if (user == null) return;

    await _db.collection('analytics_events').add({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'action': action,
      'screenKey': _lastScreenKey,
      'meta': meta ?? <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('live_activity').doc(user.uid).set({
      'lastAction': action,
      'lastActionAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
      'isOnline': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markOnline() async {
    final user = _user;
    if (user == null) return;
    await _db.collection('live_activity').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'isOnline': true,
      'lastActiveAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db.collection('users').doc(user.uid).set({
      'lastActiveAt': FieldValue.serverTimestamp(),
      'isOnline': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markOffline() async {
    final user = _user;
    if (user == null) return;
    await _db.collection('live_activity').doc(user.uid).set({
      'isOnline': false,
      'lastSeenAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db.collection('users').doc(user.uid).set({
      'isOnline': false,
      'lastSeenAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
