import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'main_shell_page.dart';
import 'services/user_service.dart';
import 'services/live_analytics_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

Future<void> _initNotifications() async {
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  const androidChannel = AndroidNotificationChannel(
    'falix_channel',
    'Falix Bildirimleri',
    description: 'Falix uygulama bildirimleri',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(androidChannel);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final token = await messaging.getToken();
  debugPrint('FCM TOKEN: $token');

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'falix_channel',
          'Falix Bildirimleri',
          channelDescription: 'Falix uygulama bildirimleri',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('Bildirim açılarak uygulamaya dönüldü: ${message.messageId}');
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

   // await MobileAds.instance.initialize();
    await _initNotifications();
  } catch (e, st) {
    debugPrint('Init error: $e');
    debugPrintStack(stackTrace: st);
  }

  runApp(const FalixApp());
}

class FalixApp extends StatefulWidget {
  const FalixApp({super.key});

  @override
  State<FalixApp> createState() => _FalixAppState();
}

class _FalixAppState extends State<FalixApp> with WidgetsBindingObserver {
  final AppOpenAdManager _appOpenAdManager = AppOpenAdManager();

  ForceUpdateConfig? _forceUpdateConfig;
  bool _checkingForceUpdate = true;
  bool _forceUpdateRequired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LiveAnalyticsService.instance.markOnline();
    _checkForceUpdate();
  }

  Future<void> _checkForceUpdate() async {
    try {
      final config = await ForceUpdateService().getConfig();
      if (!mounted) return;

      setState(() {
        _forceUpdateConfig = config;
        _forceUpdateRequired = config.required;
        _checkingForceUpdate = false;
      });

      if (!config.required) {
        _showOpeningAdAfterFirstFrame();
      }
    } catch (e, st) {
      debugPrint('Force update check error: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;

      setState(() {
        _checkingForceUpdate = false;
        _forceUpdateRequired = false;
      });

      _showOpeningAdAfterFirstFrame();
    }
  }

  void _showOpeningAdAfterFirstFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted || _forceUpdateRequired) return;
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      LiveAnalyticsService.instance.markOnline();
      if (!_forceUpdateRequired) {
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      LiveAnalyticsService.instance.markOffline();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appOpenAdManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget home;

    if (_checkingForceUpdate) {
      home = const SplashPage();
    } else if (_forceUpdateRequired && _forceUpdateConfig != null) {
      home = ForceUpdatePage(config: _forceUpdateConfig!);
    } else {
      home = const AuthWrapper();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Falix',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.transparent,
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _FalixPageTransitionsBuilder(),
            TargetPlatform.iOS: _FalixPageTransitionsBuilder(),
            TargetPlatform.macOS: _FalixPageTransitionsBuilder(),
          },
        ),
      ),
      home: home,
    );
  }
}

class AppOpenAdManager {
  static const String _androidAdUnitId = 'ca-app-pub-6519845131494268/5504587661';

  final Duration _maxCacheDuration = const Duration(hours: 4);
  final Duration _minShowInterval = const Duration(minutes: 5);

  AppOpenAd? _appOpenAd;
  DateTime? _appOpenLoadTime;
  DateTime? _lastShowTime;
  bool _isShowingAd = false;
  bool _isLoadingAd = false;

  String get _adUnitId {
    if (Platform.isAndroid) return _androidAdUnitId;
    return _androidAdUnitId;
  }

  bool get _isAdAvailable => _appOpenAd != null;

  void loadAd() {
    if (_isLoadingAd || _isAdAvailable) return;

    _isLoadingAd = true;

    AppOpenAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AppOpenAd loaded');
          _isLoadingAd = false;
          _appOpenAd = ad;
          _appOpenLoadTime = DateTime.now();
        },
        onAdFailedToLoad: (error) {
          debugPrint('AppOpenAd failed to load: $error');
          _isLoadingAd = false;
          _appOpenAd = null;
          _appOpenLoadTime = null;
        },
      ),
    );
  }

  void showAdIfAvailable() {
    if (_isShowingAd) return;

    final lastShowTime = _lastShowTime;
    if (lastShowTime != null &&
        DateTime.now().difference(lastShowTime) < _minShowInterval) {
      return;
    }

    if (!_isAdAvailable) {
      loadAd();
      return;
    }

    final loadTime = _appOpenLoadTime;
    if (loadTime == null ||
        DateTime.now().difference(loadTime) > _maxCacheDuration) {
      _appOpenAd?.dispose();
      _appOpenAd = null;
      _appOpenLoadTime = null;
      loadAd();
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('AppOpenAd showed');
        _isShowingAd = true;
        _lastShowTime = DateTime.now();
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('AppOpenAd dismissed');
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        _appOpenLoadTime = null;
        loadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AppOpenAd failed to show: $error');
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        _appOpenLoadTime = null;
        loadAd();
      },
    );

    _appOpenAd!.show();
  }

  void dispose() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
  }
}

class ForceUpdateConfig {
  const ForceUpdateConfig({
    required this.required,
    required this.currentVersion,
    required this.minimumVersion,
    required this.playStoreUrl,
    required this.message,
  });

  final bool required;
  final String currentVersion;
  final String minimumVersion;
  final String playStoreUrl;
  final String message;
}

class ForceUpdateService {
  Future<ForceUpdateConfig> getConfig() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.buildNumber;
    debugPrint("CURRENT BUILD => $currentVersion");
    final packageName = packageInfo.packageName;
    final defaultPlayStoreUrl =
        'https://play.google.com/store/apps/details?id=$packageName';

    final doc = await FirebaseFirestore.instance
        .collection('app_config')
        .doc('version')
        .get();

    if (!doc.exists) {
      return ForceUpdateConfig(
        required: false,
        currentVersion: currentVersion,
        minimumVersion: currentVersion,
        playStoreUrl: defaultPlayStoreUrl,
        message: 'Yeni sürümü yükleyerek devam etmelisin.',
      );
    }

    final data = doc.data() ?? <String, dynamic>{};
    final enabled = data['force_update_enabled'] == true;
    final minimumVersion =
        (data['minimum_build_number'] ?? currentVersion).toString();

    debugPrint("MIN BUILD => $minimumVersion");
    debugPrint("FORCE UPDATE ENABLED => $enabled");
    final playStoreUrl =
        (data['play_store_url'] ?? defaultPlayStoreUrl).toString();
    final message = (data['force_update_message'] ??
            'Falix uygulamasını kullanmaya devam etmek için son sürümü yüklemelisin.')
        .toString();

    final needsUpdate = enabled &&
        Platform.isAndroid &&
        _isVersionLower(currentVersion, minimumVersion);

    return ForceUpdateConfig(
      required: needsUpdate,
      currentVersion: currentVersion,
      minimumVersion: minimumVersion,
      playStoreUrl: playStoreUrl,
      message: message,
    );
  }

  bool _isVersionLower(String current, String minimum) {
    final currentBuild = int.tryParse(current) ?? 0;
    final minimumBuild = int.tryParse(minimum) ?? 0;

    return currentBuild < minimumBuild;
  }
}

class ForceUpdatePage extends StatelessWidget {
  const ForceUpdatePage({super.key, required this.config});

  final ForceUpdateConfig config;

  Future<void> _openStore() async {
    final uri = Uri.parse(config.playStoreUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Play Store açılamadı: ${config.playStoreUrl}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF140A26),
              Color(0xFF2A1244),
              Color(0xFF090B18),
            ],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.system_update_alt_rounded,
                      size: 72,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Güncelleme Gerekli',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      config.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _openStore,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            'Güncelle',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashPage();
        }

        if (!snapshot.hasData) {
          return const LoginPage();
        }

        return FutureBuilder<void>(
          future: UserService().createUserIfNotExists(),
          builder: (context, userInitSnapshot) {
            if (userInitSnapshot.connectionState != ConnectionState.done) {
              return const SplashPage();
            }

            if (userInitSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Text(
                    'Kullanıcı hazırlanırken hata oluştu:\n${userInitSnapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return const MainShellPage();
          },
        );
      },
    );
  }
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF140A26),
            Color(0xFF2A1244),
            Color(0xFF090B18),
          ],
        ),
      ),
      child: const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _FalixPageTransitionsBuilder extends PageTransitionsBuilder {
  const _FalixPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fade = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final slide = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(fade);

    final scale = Tween<double>(
      begin: 0.99,
      end: 1,
    ).animate(fade);

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: ScaleTransition(
          scale: scale,
          child: child,
        ),
      ),
    );
  }
}
