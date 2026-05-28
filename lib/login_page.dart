import 'dart:convert';
import 'dart:math' as math;
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'services/user_service.dart';
import 'widgets/falix_logo.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {
  bool isLoading = false;
  String message = "Falix zamanla seni tanısın";

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final UserService _userService = UserService();

  late final AnimationController _bgController;
  late final AnimationController _entryController;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    initGoogleSignIn();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _contentFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
    );

    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  Future<void> initGoogleSignIn() async {
    await _googleSignIn.initialize();
  }

  Future<void> signInWithGoogle() async {
    try {
      setState(() {
        isLoading = true;
        message = "Giriş yapılıyor...";
      });

      final GoogleSignInAccount googleUser =
          await _googleSignIn.authenticate();

      final googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      await _userService.createUserIfNotExists();

      if (!mounted) return;
      setState(() {
        message = "Hoş geldin ✨";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = "Login hatası: $e";
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = math.Random.secure();

    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> signInWithApple() async {
    if (!Platform.isIOS) return;

    try {
      setState(() {
        isLoading = true;
        message = "Apple ile giriş yapılıyor...";
      });

      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      await _userService.createUserIfNotExists();

      if (!mounted) return;
      setState(() {
        message = "Hoş geldin ✨";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        message = "Apple login hatası: $e";
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
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
        borderRadius: radius ?? BorderRadius.circular(28),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.18),
            blurRadius: 30,
            spreadRadius: 1,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _stars() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (_, __) {
        return CustomPaint(
          painter: _StarPainter(_bgController.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }

  Widget _featureItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.045),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7C3AED).withOpacity(0.9),
                  const Color(0xFFDB2777).withOpacity(0.9),
                ],
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.8,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _googleButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : signInWithGoogle,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.white70,
          disabledForegroundColor: Colors.black54,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            else
              const Icon(Icons.login_rounded),
            const SizedBox(width: 10),
            Text(
              isLoading ? "Giriş Yapılıyor..." : "Falix’e Başla",
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appleButton() {
    if (!Platform.isIOS) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SignInWithAppleButton(
            text: "Apple ile Devam Et",
            onPressed: isLoading ? null : signInWithApple,
            borderRadius: BorderRadius.circular(22),
            height: 56,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(child: _stars()),
            Positioned(
              top: -80,
              left: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF7C3AED).withOpacity(0.16),
                ),
              ),
            ),
            Positioned(
              bottom: -110,
              right: -40,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFDB2777).withOpacity(0.10),
                ),
              ),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _contentFade,
                child: SlideTransition(
                  position: _contentSlide,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: height - MediaQuery.of(context).padding.top - 40,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 8),
                          const FalixLogo(),
                          const SizedBox(height: 14),
                          const Text(
                            "Sana özel, hafızalı ve mistik fal deneyimi",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14.5,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _glassCard(
                            child: Column(
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Color(0xFFFFD978),
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Falix her yorumda seni daha iyi tanır",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _featureItem(
                                  icon: Icons.local_cafe_rounded,
                                  title: "Kahve Falı",
                                  subtitle:
                                      "Fincanındaki sembolleri kişisel enerjinle birlikte yorumlat.",
                                ),
                                const SizedBox(height: 10),
                                _featureItem(
                                  icon: Icons.style_rounded,
                                  title: "Tarot Yorumları",
                                  subtitle:
                                      "Kartların mesajını aşk, karar ve kader enerjine göre keşfet.",
                                ),
                                const SizedBox(height: 10),
                                _featureItem(
                                  icon: Icons.workspace_premium_rounded,
                                  title: "Kişisel Hafıza",
                                  subtitle:
                                      "Falix önceki fallarını hatırlayarak daha özel yorumlar üretir.",
                                ),
                                const SizedBox(height: 18),
                                _googleButton(),
                                _appleButton(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            "Devam ederek Falix kullanım koşullarını kabul etmiş olursun.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 11.8,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  final double progress;

  _StarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (int i = 0; i < 42; i++) {
      final x = (size.width * (i / 42)) +
          math.sin(progress * 2 * math.pi + i) * 10;

      final y = (size.height * ((i % 12) / 12)) +
          math.cos(progress * 2 * math.pi + i) * 16;

      paint.color = Colors.white.withOpacity(0.05);
      canvas.drawCircle(
        Offset(x, y.abs() % size.height),
        i % 5 == 0 ? 1.8 : 1.2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) => true;
}