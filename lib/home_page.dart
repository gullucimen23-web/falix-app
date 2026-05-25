import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'coffee_loading_page.dart';
import 'coffee_result_page.dart';
import 'discover_page.dart';
import 'history_page.dart';
import 'human_expert_page.dart';
import 'paywall_page.dart';
import 'profile_setup_page.dart';
import 'services/user_service.dart';
import 'spin_wheel_page.dart';
import 'tarot_result_page.dart';
import 'tarot_selection_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  static const int _coffeeCost = 120;
  static const int _tarotCost = 80;

  String result = "Henüz fal bakılmadı";
  bool isLoading = false;
  bool isClaimingDailyReward = false;

  final String baseUrl = "https://falix-backend.onrender.com";
  final UserService _userService = UserService();
  final ImagePicker _picker = ImagePicker();

  RewardedAd? _rewardedAd;
  bool _isRewardedAdReady = false;

  DailyRewardStatus? _dailyRewardStatus;

  late final AnimationController _bgController;
  late final AnimationController _entryController;
  late final AnimationController _pulseController;

  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _cardsFade;
  late final Animation<Offset> _cardsSlide;
  late final Animation<double> _resultFade;

  static const String _testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  static const String _realRewardedAdUnitId =
      'ca-app-pub-6519845131494268/8544916065';

  String get rewardedAdUnitId {
    return kReleaseMode ? _realRewardedAdUnitId : _testRewardedAdUnitId;
  }

  String get adModeText {
    return kReleaseMode ? "Canlı reklam modu" : "Test reklam modu";
  }

  String get _currentUserName {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim() ?? '';

    if (displayName.isNotEmpty) return displayName;

    final email = user?.email?.trim() ?? '';
    if (email.contains('@')) {
      final localPart = email.split('@').first.trim();
      if (localPart.isNotEmpty) {
        final cleaned = localPart.replaceAll(RegExp(r'[._-]+'), ' ');
        return cleaned
            .split(' ')
            .where((e) => e.trim().isNotEmpty)
            .map((e) => e[0].toUpperCase() + e.substring(1))
            .join(' ');
      }
    }

    return "Güzel Ruh";
  }

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _heroFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.42, curve: Curves.easeOut),
    );

    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.42, curve: Curves.easeOutCubic),
      ),
    );

    _cardsFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.18, 0.72, curve: Curves.easeOut),
    );

    _cardsSlide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.18, 0.72, curve: Curves.easeOutCubic),
      ),
    );

    _resultFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.45, 1, curve: Curves.easeOut),
    );

    _entryController.forward();

    _loadRewardedAd();
    _loadDailyRewardStatus();
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _bgController.dispose();
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadDailyRewardStatus() async {
    final status = await _userService.getDailyRewardStatus();
    if (!mounted) return;

    setState(() {
      _dailyRewardStatus = status;
    });
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;

          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();

              if (mounted) {
                setState(() {
                  _rewardedAd = null;
                  _isRewardedAdReady = false;
                });
              } else {
                _rewardedAd = null;
                _isRewardedAdReady = false;
              }

              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();

              if (mounted) {
                setState(() {
                  _rewardedAd = null;
                  _isRewardedAdReady = false;
                  result = "Reklam gösterilemedi: $error";
                });
              } else {
                _rewardedAd = null;
                _isRewardedAdReady = false;
              }

              _loadRewardedAd();
            },
          );

          if (mounted) {
            setState(() {
              _isRewardedAdReady = true;
            });
          } else {
            _isRewardedAdReady = true;
          }
        },
        onAdFailedToLoad: (error) {
          if (mounted) {
            setState(() {
              _rewardedAd = null;
              _isRewardedAdReady = false;
              result = "Reklam yüklenemedi: ${error.message}";
            });
          } else {
            _rewardedAd = null;
            _isRewardedAdReady = false;
          }
        },
      ),
    );
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn.instance.signOut();
  }

  Future<ImageSource?> _showCoffeeImageSourceSheet() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF140A26),
                Color(0xFF2A1244),
                Color(0xFF090B18),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.24),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Kahve Falı İçin Fotoğraf Seç',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'İstersen kamerayla şimdi çek, istersen galeriden seç.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _CoffeeSourceButton(
                    icon: Icons.photo_camera_rounded,
                    title: 'Kamera ile Çek',
                    subtitle: 'Fincanı şimdi çek ve enerjiyi anında okut',
                    colors: const [Color(0xFF7C3AED), Color(0xFFDB2777)],
                    onTap: () => Navigator.of(context).pop(ImageSource.camera),
                  ),
                  const SizedBox(height: 12),
                  _CoffeeSourceButton(
                    icon: Icons.photo_library_rounded,
                    title: 'Galeriden Seç',
                    subtitle: 'Daha önce çektiğin fincan fotoğrafını kullan',
                    colors: const [Color(0xFF2563EB), Color(0xFF06B6D4)],
                    onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<File?> _pickCoffeeImage() async {
    final source = await _showCoffeeImageSourceSheet();
    if (source == null) return null;

    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (file == null) return null;
    return File(file.path);
  }

  Future<Map<String, dynamic>> _uploadCoffeeImage({
    required File imageFile,
    required bool useFreeCoffee,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Oturum bulunamadı');
    }

    final token = await user.getIdToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/coffee-vision'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['userName'] = _currentUserName;

    final profile = await _userService.getUserProfileData();
    request.fields['partnerInfo'] = _buildPartnerInfo(profile);
    request.fields['useFreeCoffee'] = useFreeCoffee.toString();

    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (_) {}

    if (response.statusCode == 401) {
      throw Exception(data['error']?.toString() ?? 'Yetkisiz istek');
    }

    if (response.statusCode == 402) {
      throw Exception(data['error']?.toString() ?? 'Coin yetersiz');
    }

    if (response.statusCode == 429) {
      throw Exception(data['error']?.toString() ?? 'Günlük limit doldu');
    }

    if (response.statusCode != 200) {
      throw Exception(data['error']?.toString() ?? responseBody);
    }

    final resultData = data['result'];

    if (resultData is Map<String, dynamic>) {
      return resultData;
    }

    if (resultData is String) {
      return {
        'greeting': "Merhaba $_currentUserName,",
        'overall': resultData,
        'love': '',
        'career': '',
        'money': '',
        'advice': '',
        'closing': '',
      };
    }

    return {
      'greeting': "Merhaba $_currentUserName,",
      'overall': 'Kahve falı yorumu alındı.',
      'love': '',
      'career': '',
      'money': '',
      'advice': '',
      'closing': '',
    };
  }

  String _coffeeResultToText(Map<String, dynamic> resultData) {
    final greeting = (resultData['greeting'] ?? '').toString().trim();
    final overall = (resultData['overall'] ?? '').toString().trim();
    final love = (resultData['love'] ?? '').toString().trim();
    final career = (resultData['career'] ?? '').toString().trim();
    final money = (resultData['money'] ?? '').toString().trim();
    final advice = (resultData['advice'] ?? '').toString().trim();
    final closing = (resultData['closing'] ?? '').toString().trim();

    return [
      if (greeting.isNotEmpty) greeting,
      if (overall.isNotEmpty) '\nGenel Enerji\n$overall',
      if (love.isNotEmpty) '\nAşk\n$love',
      if (career.isNotEmpty) '\nKariyer\n$career',
      if (money.isNotEmpty) '\nPara\n$money',
      if (advice.isNotEmpty) '\nTavsiye\n$advice',
      if (closing.isNotEmpty) '\nKapanış\n$closing',
    ].join('\n');
  }

  String _buildPartnerInfo(Map<String, dynamic> profile) {
    final partnerName = (profile['partnerName'] ?? '').toString().trim();
    final partnerMotherName =
        (profile['partnerMotherName'] ?? '').toString().trim();
    final partnerBirthDate =
        (profile['partnerBirthDate'] ?? '').toString().trim();

    if (partnerName.isEmpty &&
        partnerMotherName.isEmpty &&
        partnerBirthDate.isEmpty) {
      return '';
    }

    return [
      'İlişki yaşadığı kişi bilgileri:',
      if (partnerName.isNotEmpty) 'Adı: $partnerName',
      if (partnerMotherName.isNotEmpty) 'Anne adı: $partnerMotherName',
      if (partnerBirthDate.isNotEmpty) 'Doğum tarihi: $partnerBirthDate',
      'Bu bilgileri özellikle aşk, ilişki, bağ enerjisi ve niyet yorumlarında dikkate al.',
    ].join('\n');
  }

  String _topicTitle(String topic) {
    switch (topic) {
      case "ask":
        return "Aşk";
      case "kariyer":
        return "Kariyer";
      default:
        return "Genel";
    }
  }

  Future<String> getTarot({
    required String topic,
    required List<String> cards,
    required bool useFreeTarot,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Oturum bulunamadı');
    }

    final token = await user.getIdToken();
    final profile = await _userService.getUserProfileData();

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/tarot"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "topic": topic,
          "cards": cards,
          "userName": _currentUserName,
          "partnerInfo": _buildPartnerInfo(profile),
          "useFreeTarot": useFreeTarot,
        }),
      );

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception(
          "Backend JSON dönmedi. Status: ${res.statusCode}, Body: ${res.body}",
        );
      }

      if (res.statusCode == 401) {
        throw Exception(data['error']?.toString() ?? 'Yetkisiz istek');
      }

      if (res.statusCode == 402) {
        throw Exception(data['error']?.toString() ?? 'Coin yetersiz');
      }

      if (res.statusCode == 429) {
        throw Exception(data['error']?.toString() ?? 'Günlük limit doldu');
      }

      if (res.statusCode != 200) {
        throw Exception(data['error']?.toString() ?? 'Tarot isteği başarısız');
      }

      final text = data["result"]?.toString() ?? "Tarot sonucu boş geldi.";
      final fullText = """Konu: ${_topicTitle(topic)}
Kartlar: ${cards.join(", ")}

$text""";

      if (!mounted) return fullText;

      setState(() {
        result = fullText;
      });

      await _userService.saveReading(
        type: "tarot",
        result: fullText,
      );

      return fullText;
    } catch (e) {
      if (!mounted) rethrow;
      setState(() {
        result = "Tarot hatası: $e";
      });
      rethrow;
    }
  }


  Future<void> handleCoffee() async {
    setState(() {
      isLoading = true;
      result = "Kahve fincanı fotoğrafı seçiliyor...";
    });

    try {
      final spinStatus = await _userService.getSpinStatus();
      final freeCoffeeCount = (spinStatus['freeCoffeeCount'] ?? 0) as int;
      final useFreeCoffee = freeCoffeeCount > 0;

      final image = await _pickCoffeeImage();

      if (image == null) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          result = "Fotoğraf seçilmedi.";
        });
        return;
      }

      if (!mounted) return;

      final resultData = await Navigator.push<Map<String, dynamic>>(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => CoffeeLoadingPage(
            loadReading: () async {
              return _uploadCoffeeImage(
                imageFile: image,
                useFreeCoffee: useFreeCoffee,
              );
            },
          ),
          transitionDuration: const Duration(milliseconds: 650),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: child,
              ),
            );
          },
        ),
      );

      if (resultData == null) {
        if (!mounted) return;
        setState(() {
          result = "Kahve falı iptal edildi.";
        });
        return;
      }

      final textToSave = _coffeeResultToText(resultData);

      await _userService.saveReading(
        type: "coffee",
        result: textToSave,
      );

      if (!mounted) return;

      if (useFreeCoffee) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ücretsiz Kahve hakkın kullanıldı ✨')),
        );
      }

      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => CoffeeResultPage(
            resultData: resultData,
            onTryAgain: () {
              Navigator.pop(context);
              handleCoffee();
            },
          ),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: child,
              ),
            );
          },
        ),
      );

      if (!mounted) return;
      setState(() {
        result = textToSave;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        result = "Kahve falı hatası: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        await _loadDailyRewardStatus();
      }
    }
  }

  Future<void> handleTarot() async {
    final spinStatus = await _userService.getSpinStatus();
    final freeTarotCount = (spinStatus['freeTarotCount'] ?? 0) as int;
    final useFreeTarot = freeTarotCount > 0;

    final TarotSelectionResult? selection =
        await Navigator.push<TarotSelectionResult>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const TarotSelectionPage(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
      ),
    );

    if (selection == null) {
      setState(() {
        result = "Tarot seçimi iptal edildi.";
      });
      return;
    }

    if (!mounted) return;

    setState(() {
      isLoading = true;
      result = "Kart enerjileri birleşiyor... Mesajlar açığa çıkıyor...";
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _TarotWaitingDialog(),
    );

    try {
      final fullText = await getTarot(
        topic: selection.topic,
        cards: selection.cards,
        useFreeTarot: useFreeTarot,
      );

      if (!mounted) return;

      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (useFreeTarot) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ücretsiz Tarot hakkın kullanıldı ✨')),
        );
      }

      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => TarotResultPage(result: fullText),
          transitionDuration: const Duration(milliseconds: 650),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: child,
              ),
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;

      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      setState(() {
        result = "Tarot hatası: $e";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tarot hatası: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        await _loadDailyRewardStatus();
      }
    }
  }


  Future<void> watchAd() async {
    if (_rewardedAd == null || !_isRewardedAdReady) {
      setState(() {
        result = "Reklam henüz hazır değil, birazdan tekrar dene.";
      });
      _loadRewardedAd();
      return;
    }

    final ad = _rewardedAd!;

    setState(() {
      _rewardedAd = null;
      _isRewardedAdReady = false;
    });

    ad.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) async {
        await _userService.addCoin(
          20,
          historyType: 'rewarded_ad',
          meta: {
            'rewardType': reward.type,
            'rewardAmount': reward.amount,
          },
        );

        if (mounted) {
          setState(() {
            result = "+20 coin kazandın! ($adModeText)";
          });
        }
      },
    );
  }

  Future<void> claimDailyReward() async {
    if (isClaimingDailyReward) return;

    setState(() {
      isClaimingDailyReward = true;
    });

    final dailyResult = await _userService.claimDailyReward();

    if (!mounted) return;

    setState(() {
      isClaimingDailyReward = false;
      result = dailyResult.message;
    });

    await _loadDailyRewardStatus();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(dailyResult.message)),
    );
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    BorderRadius? radius,
  }) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: radius ?? BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E44FF).withOpacity(0.10),
            blurRadius: 22,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }


  Widget _buildHero() {
    return FadeTransition(
      opacity: _heroFade,
      child: SlideTransition(
        position: _heroSlide,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white.withOpacity(0.06),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF7C3AED),
                      Color(0xFFDB2777),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Merhaba, $_currentUserName",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Bugün enerjinde neler öne çıkıyor, birlikte bakalım.",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoTicker() {
    final items = const [
      'Günlük enerji ✨',
      'Rüya yorumu 🌙',
      'İlişki uyumu 💘',
      'Gerçek uzman 🔮',
      'Premium Coin 💎',
      'Kahve falı ☕',
      'Tarot kartları ✨',
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 42,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: Text(
                '•',
                style: TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          itemBuilder: (context, index) {
            return Center(
              child: Text(
                items[index],
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildUserInfo() {
    final user = FirebaseAuth.instance.currentUser;

    return _glassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        "Giriş yapan: ${user?.email ?? 'Email yok'}",
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: Colors.white70),
      ),
    );
  }

  Widget buildCoinWidget() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userService.userStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return _glassCard(
            child: const _StatRowLoading(),
          );
        }

        final data = snapshot.data!.data();
        final coin = data?['coin'] ?? 0;
        final premiumCoin = data?['premiumCoin'] ?? 0;
        final premium = data?['premium'] ?? false;
        final dailyUsage = data?['dailyUsage'] ?? 0;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: "Coin",
                    value: "$coin",
                    icon: Icons.monetization_on_rounded,
                    accent: const Color(0xFFFFC94D),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: "Premium Coin",
                    value: "$premiumCoin",
                    icon: Icons.diamond_rounded,
                    accent: const Color(0xFFFA9BFF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: "Durum",
                    value: premium ? "Premium" : "Standart",
                    icon: premium
                        ? Icons.workspace_premium_rounded
                        : Icons.person_rounded,
                    accent: premium
                        ? const Color(0xFFFA9BFF)
                        : const Color(0xFF8AB4FF),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: premium ? "AI Limit" : "Bugün",
                    value: premium ? "Sınırsız" : "$dailyUsage / 5",
                    icon: Icons.bolt_rounded,
                    accent: const Color(0xFFA98BFF),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }


  Widget _buildOnlineExpertsPreview() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('experts').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final experts = docs
            .where((doc) {
              final data = doc.data();
              return data['active'] != false && data['online'] == true;
            })
            .take(3)
            .toList();

        return _glassCard(
          radius: BorderRadius.circular(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: const Color(0xFF14B8A6).withOpacity(0.18),
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: Color(0xFF5EEAD4)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Online Uzmanlar', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                        SizedBox(height: 3),
                        Text('Gerçek rehberlerden canlı yorum al.', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Text('Uzmanlar kontrol ediliyor...', style: TextStyle(color: Colors.white70))
              else if (experts.isEmpty)
                const Text('Şu an online uzman görünmüyor. Talep bırakabilir, uzman aktif olduğunda cevap alabilirsin.', style: TextStyle(color: Colors.white70, height: 1.45))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: experts.map((doc) {
                    final data = doc.data();
                    final name = (data['name'] ?? data['email'] ?? 'Falix Uzmanı').toString();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: const Color(0xFF22C55E).withOpacity(0.12),
                        border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.22)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.circle, size: 8, color: Color(0xFF86EFAC)),
                          const SizedBox(width: 7),
                          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HumanExpertPage()));
                  },
                  icon: const Icon(Icons.chat_bubble_rounded),
                  label: const Text('Canlı Uzmana Bağlan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dailyRewardCard() {
    final status = _dailyRewardStatus;

    if (status == null) {
      return _glassCard(
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              "Günlük ödül yükleniyor...",
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return _glassCard(
      radius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF2B1648).withOpacity(0.55),
              const Color(0xFF4B1E74).withOpacity(0.25),
              const Color(0xFF1F1033).withOpacity(0.15),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: const Color(0xFF140F22).withOpacity(0.72),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 0.96 + (_pulseController.value * 0.08),
                          child: child,
                        );
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xFFFFD166).withOpacity(0.18),
                        ),
                        child: const Icon(
                          Icons.card_giftcard_rounded,
                          color: Color(0xFFFFD166),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Günlük Ödül",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  "Streak: ${status.streak} gün",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Bugünkü ödül: +${status.todayReward} coin",
                  style: const TextStyle(
                    color: Color(0xFFFFD166),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: status.canClaim && !isClaimingDailyReward
                        ? claimDailyReward
                        : null,
                    icon: isClaimingDailyReward
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.redeem_rounded),
                    label: Text(
                      status.canClaim ? "Günlük Ödülü Al" : "Bugün alındı",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickTipsCard() {
    return _glassCard(
      child: const Column(
        children: [
          Text(
            "Kahve Falı İçin Mini Ritüel",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 10),
          Text(
            "Fincanın içini üstten, net ve iyi ışıkta çek. Telve izleri ne kadar netse yorum o kadar güçlü olur.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              height: 1.45,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _economyCard() {
    return _glassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(
        "Ekonomi: Tarot $_tarotCost coin • Kahve $_coffeeCost coin • Reklam +20 coin",
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _simpleActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
    required Color accent,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: accent.withOpacity(0.16),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                trailing ??
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white54,
                      size: 16,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFocusReadingCard() {
  final hasReading = result.trim().isNotEmpty && result != "Henüz fal bakılmadı";

  return _glassCard(
    radius: BorderRadius.circular(30),
    padding: EdgeInsets.zero,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF3B1361).withOpacity(0.95),
            const Color(0xFF7C3AED).withOpacity(0.82),
            const Color(0xFFDB2777).withOpacity(0.72),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withOpacity(0.14),
                  ),
                  child: const Icon(
                    Icons.stars_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Bugün senin için çıkan mesaj",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              hasReading
                  ? result
                  : "Henüz fal bakmadın. İlk yorumunu al ve bugünün enerjisini keşfet.",
              maxLines: hasReading ? 6 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.92),
                fontSize: 14,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: hasReading ? null : (isLoading ? null : handleTarot),
                icon: Icon(
                  hasReading
                      ? Icons.visibility_rounded
                      : Icons.auto_awesome_rounded,
                ),
                label: Text(
                  hasReading ? "Sonuç aşağıda detaylı" : "İlk Falı Başlat",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white,
                  disabledForegroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildPrimaryActionTiles() {
  return Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _bigActionTile(
              title: "Kahve Falı",
              subtitle: "Fotoğraf gönder, telveyi yorumlat",
              icon: Icons.local_cafe_rounded,
              accentA: const Color(0xFFFFA94D),
              accentB: const Color(0xFFFF7A59),
              onTap: isLoading ? null : handleCoffee,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _bigActionTile(
              title: "Tarot Falı",
              subtitle: "Kartlarını seç, mesajı keşfet",
              icon: Icons.auto_awesome_rounded,
              accentA: const Color(0xFFA98BFF),
              accentB: const Color(0xFF7C3AED),
              onTap: isLoading ? null : handleTarot,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _bigActionTile(
              title: "Günlük Enerji",
              subtitle: "Bugünün mesajını aç",
              icon: Icons.wb_twilight_rounded,
              accentA: const Color(0xFF7C3AED),
              accentB: const Color(0xFFDB2777),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DiscoverPage()),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _bigActionTile(
              title: "Rüya Yorumu",
              subtitle: "Rüyanın işaretlerini çöz",
              icon: Icons.nightlight_round,
              accentA: const Color(0xFF2563EB),
              accentB: const Color(0xFF06B6D4),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DiscoverPage()),
                );
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _simpleActionCard(
        title: "İlişki Uyumu",
        subtitle: "İki isim arasındaki enerji uyumunu gör. Premium üyeler ücretsiz, standart kullanıcılar Premium Coin ile kullanır.",
        icon: Icons.favorite_rounded,
        accent: const Color(0xFFFB7185),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DiscoverPage()),
          );
        },
      ),
    ],
  );
}


Widget _bigActionTile({
  required String title,
  required String subtitle,
  required IconData icon,
  required Color accentA,
  required Color accentB,
  required VoidCallback? onTap,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentA.withOpacity(0.95),
              accentB.withOpacity(0.95),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: accentB.withOpacity(0.22),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.18),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(height: 36),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.88),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildUtilityGrid(String adSubtitle) {
  return Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _miniDashboardCard(
              title: "Günlük Ödül",
              subtitle: _dailyRewardStatus == null
                  ? "Yükleniyor..."
                  : _dailyRewardStatus!.canClaim
                      ? "+${_dailyRewardStatus!.todayReward} coin seni bekliyor"
                      : "Bugünkü ödül alındı",
              icon: Icons.card_giftcard_rounded,
              accent: const Color(0xFFFFD166),
              onTap: (_dailyRewardStatus?.canClaim ?? false) &&
                      !isClaimingDailyReward
                  ? claimDailyReward
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _miniDashboardCard(
              title: "Coin Kazan",
              subtitle: adSubtitle,
              icon: Icons.play_circle_fill_rounded,
              accent: const Color(0xFF22C55E),
              onTap: (!_isRewardedAdReady || isLoading) ? null : watchAd,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _miniDashboardCard(
              title: "Premium",
              subtitle: "Paketleri ve avantajları görüntüle",
              icon: Icons.workspace_premium_rounded,
              accent: const Color(0xFFF59E0B),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PaywallPage()),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _miniDashboardCard(
              title: "Uzman",
              subtitle: "Gerçek yorumcu yönlendirmesi",
              icon: Icons.support_agent_rounded,
              accent: const Color(0xFF14B8A6),
              onTap: () async {
                final message = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (_) => const HumanExpertPage()),
                );

                if (!mounted || message == null || message.trim().isEmpty) {
                  return;
                }

                setState(() {
                  result = message;
                });
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _miniDashboardCard(
              title: "Geçmişim",
              subtitle: "Önceki fal sonuçlarını görüntüle",
              icon: Icons.history_rounded,
              accent: const Color(0xFF60A5FA),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryPage()),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _miniDashboardCard(
              title: "Şans Çarkı",
              subtitle: "Günde 2 ücretsiz çevirme hakkı",
              icon: Icons.casino_rounded,
              accent: const Color(0xFF8B5CF6),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SpinWheelPage()),
                );
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _miniDashboardCard(
              title: "Kişisel Profilim",
              subtitle: "Ad, anne adı ve doğum yılı bilgilerini düzenle",
              icon: Icons.badge_rounded,
              accent: const Color(0xFFEC4899),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileSetupPage()),
                );
              },
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _miniDashboardCard({
  required String title,
  required String subtitle,
  required IconData icon,
  required Color accent,
  required VoidCallback? onTap,
}) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: Colors.white.withOpacity(0.08),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: accent.withOpacity(0.16),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _resultCard() {
    return FadeTransition(
      opacity: _resultFade,
      child: _glassCard(
        radius: BorderRadius.circular(30),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF201131).withOpacity(0.85),
                const Color(0xFF0F0B1A).withOpacity(0.85),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Container(
              height: 300,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFF120D20).withOpacity(0.82),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xFF7C3AED).withOpacity(0.18),
                        ),
                        child: const Icon(
                          Icons.stars_rounded,
                          color: Color(0xFFA98BFF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Fal Sonucu / Durum",
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (isLoading)
                    Expanded(
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 0.96 + (_pulseController.value * 0.08),
                              child: child,
                            );
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 34,
                                height: 34,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Color(0xFFA98BFF),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                result,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: true,
                        radius: const Radius.circular(99),
                        child: SingleChildScrollView(
                          child: Text(
                            result,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.62,
                              color: Colors.white70,
                            ),
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
    );
  }


  @override
  Widget build(BuildContext context) {
    final adSubtitle = _isRewardedAdReady
        ? "+20 coin kazan • $adModeText"
        : "Reklam yükleniyor... • $adModeText";

    return Scaffold(
      backgroundColor: const Color(0xFF090613),
      appBar: AppBar(
        title: const Text(
          "Falix",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: "Çıkış Yap",
            onPressed: signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0812),
                  Color(0xFF140A26),
                  Color(0xFF25103F),
                  Color(0xFF090B18),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MysticBackgroundPainter(
                      progress: _bgController.value,
                    ),
                  ),
                ),
                Positioned(
                  top: -40,
                  left: -20,
                  child: _GlowOrb(
                    size: 180,
                    color: const Color(0xFF7C3AED).withOpacity(0.24),
                  ),
                ),
                Positioned(
                  top: 110,
                  right: -20,
                  child: _GlowOrb(
                    size: 140,
                    color: const Color(0xFFDB2777).withOpacity(0.16),
                  ),
                ),
                Positioned(
                  bottom: 120,
                  left: -30,
                  child: _GlowOrb(
                    size: 160,
                    color: const Color(0xFF2563EB).withOpacity(0.14),
                  ),
                ),
                Positioned(
                  bottom: -30,
                  right: -20,
                  child: _GlowOrb(
                    size: 180,
                    color: const Color(0xFFFFB703).withOpacity(0.10),
                  ),
                ),
                SafeArea(child: child!),
              ],
            ),
          );
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          child: SlideTransition(
            position: _cardsSlide,
            child: FadeTransition(
              opacity: _cardsFade,
              child: Column(
                children: [
                  _buildHero(),
                  const SizedBox(height: 10),
                  _buildPromoTicker(),
                  const SizedBox(height: 14),
                  buildCoinWidget(),
                  const SizedBox(height: 18),
                  _buildFocusReadingCard(),
                  const SizedBox(height: 18),
                  _buildOnlineExpertsPreview(),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _sectionTitle("Bugün ne bakmak istersin?"),
                  ),
                  const SizedBox(height: 10),
                  _buildPrimaryActionTiles(),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _sectionTitle("Hızlı Erişim"),
                  ),
                  const SizedBox(height: 10),
                  _buildUtilityGrid(adSubtitle),
                  const SizedBox(height: 18),
                  _quickTipsCard(),
                  const SizedBox(height: 14),
                  _economyCard(),
                  const SizedBox(height: 18),
                  _resultCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}



class _TarotWaitingDialog extends StatelessWidget {
  const _TarotWaitingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(22),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF140A26),
              Color(0xFF25103F),
              Color(0xFF090B18),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white24),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF7C3AED).withOpacity(0.35),
              blurRadius: 34,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: Color(0xFFFFD166),
              ),
            ),
            SizedBox(height: 18),
            Text(
              'Tarot yorumun hazırlanıyor',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Kartların enerjisi okunuyor. Sonuç hazır olduğunda direkt sonuç sayfası açılacak.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoffeeSourceButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  const _CoffeeSourceButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.24),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.white.withOpacity(0.14),
                    border: Border.all(color: Colors.white.withOpacity(0.16)),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.12),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: accent.withOpacity(0.16),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRowLoading extends StatelessWidget {
  const _StatRowLoading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _MiniLoadingCard()),
        SizedBox(width: 12),
        Expanded(child: _MiniLoadingCard()),
        SizedBox(width: 12),
        Expanded(child: _MiniLoadingCard()),
      ],
    );
  }
}

class _MiniLoadingCard extends StatelessWidget {
  const _MiniLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.06),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 80,
              spreadRadius: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _MysticBackgroundPainter extends CustomPainter {
  final double progress;

  _MysticBackgroundPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final starsPaint = Paint()..style = PaintingStyle.fill;

    final starOffsets = <Offset>[
      Offset(size.width * 0.12, size.height * 0.15),
      Offset(size.width * 0.24, size.height * 0.28),
      Offset(size.width * 0.78, size.height * 0.12),
      Offset(size.width * 0.86, size.height * 0.22),
      Offset(size.width * 0.68, size.height * 0.36),
      Offset(size.width * 0.15, size.height * 0.62),
      Offset(size.width * 0.84, size.height * 0.68),
      Offset(size.width * 0.52, size.height * 0.78),
      Offset(size.width * 0.38, size.height * 0.86),
    ];

    for (var i = 0; i < starOffsets.length; i++) {
      final twinkle =
          0.25 + 0.75 * ((math.sin((progress * 2 * math.pi) + i) + 1) / 2);
      starsPaint.color = Colors.white.withOpacity(0.08 * twinkle);
      canvas.drawCircle(starOffsets[i], 1.4 + (twinkle * 1.2), starsPaint);
    }

    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFA98BFF).withOpacity(0.08);

    final path1 = Path();
    for (double x = 0; x <= size.width; x++) {
      final y =
          size.height * 0.20 + math.sin((x / 75) + (progress * 2 * math.pi)) * 8;
      if (x == 0) {
        path1.moveTo(x, y);
      } else {
        path1.lineTo(x, y);
      }
    }

    final path2 = Path();
    for (double x = 0; x <= size.width; x++) {
      final y =
          size.height * 0.72 + math.sin((x / 90) - (progress * 2 * math.pi)) * 10;
      if (x == 0) {
        path2.moveTo(x, y);
      } else {
        path2.lineTo(x, y);
      }
    }

    canvas.drawPath(path1, wavePaint);
    canvas.drawPath(
      path2,
      wavePaint..color = const Color(0xFFDB2777).withOpacity(0.05),
    );
  }

  @override
  bool shouldRepaint(covariant _MysticBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}