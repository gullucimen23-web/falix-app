import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'human_expert_page.dart';
import 'paywall_page.dart';

class CoffeeResultPage extends StatefulWidget {
  final Map<String, dynamic> resultData;
  final VoidCallback? onTryAgain;

  const CoffeeResultPage({
    super.key,
    required this.resultData,
    this.onTryAgain,
  });

  @override
  State<CoffeeResultPage> createState() => _CoffeeResultPageState();
}

class _CoffeeResultPageState extends State<CoffeeResultPage>
    with TickerProviderStateMixin {
  late final AnimationController _bgController;
  late final AnimationController _entryController;
  late final AnimationController _pulseController;

  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _cardsFade;
  late final Animation<Offset> _cardsSlide;

  String get greeting => (widget.resultData['greeting'] ?? '').toString().trim();
  String get overall => (widget.resultData['overall'] ?? '').toString().trim();
  String get love => (widget.resultData['love'] ?? '').toString().trim();
  String get career => (widget.resultData['career'] ?? '').toString().trim();
  String get money => (widget.resultData['money'] ?? '').toString().trim();
  String get advice => (widget.resultData['advice'] ?? '').toString().trim();
  String get closing => (widget.resultData['closing'] ?? '').toString().trim();

  int get energyScore {
    final raw = widget.resultData['energyScore'];
    if (raw is int) return raw.clamp(0, 100);
    return int.tryParse(raw?.toString() ?? '')?.clamp(0, 100) ?? 84;
  }

  List<Map<String, dynamic>> get symbols {
    final raw = widget.resultData['symbols'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
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
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..forward();

    _headerFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
    );

    _headerSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOutCubic),
      ),
    );

    _cardsFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.18, 1, curve: Curves.easeOut),
    );

    _cardsSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.18, 1, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _bgController.dispose();
    _pulseController.dispose();
    _entryController.dispose();
    super.dispose();
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
            color: const Color(0xFF8E44FF).withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildHero() {
    return FadeTransition(
      opacity: _headerFade,
      child: SlideTransition(
        position: _headerSlide,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final glow = 0.84 + (_pulseController.value * 0.16);

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF4C1D95).withOpacity(glow),
                    const Color(0xFF7C3AED).withOpacity(glow),
                    const Color(0xFFDB2777).withOpacity(glow),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.14)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withOpacity(0.28),
                    blurRadius: 36,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.local_cafe_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      "Kahve Falın Hazır",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                greeting.isNotEmpty ? greeting : "Merhaba güzel ruh,",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                overall.isNotEmpty
                    ? overall
                    : "Fincanda güçlü bir hareket, dönüşüm ve içsel açıklık enerjisi görünüyor.",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14.5,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 18),
              _EnergyBar(score: energyScore),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String text,
    required IconData icon,
    required Color accent,
  }) {
    return _glassCard(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withOpacity(0.16),
              const Color(0xFF130E21).withOpacity(0.92),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: accent.withOpacity(0.18),
                    ),
                    child: Icon(icon, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                text.isNotEmpty ? text : "Bu alanda yakında daha güçlü mesajlar açığa çıkacak.",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14.5,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSymbols() {
    if (symbols.isEmpty) return const SizedBox.shrink();

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Fincanda Beliren Semboller",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ...symbols.map((symbol) {
            final name = (symbol['name'] ?? '').toString().trim();
            final meaning = (symbol['meaning'] ?? '').toString().trim();

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withOpacity(0.05),
                  border: Border.all(color: Colors.white.withOpacity(0.07)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFFA98BFF).withOpacity(0.16),
                      ),
                      child: const Icon(
                        Icons.stars_rounded,
                        color: Color(0xFFA98BFF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isNotEmpty ? name : "Sembol",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            meaning.isNotEmpty
                                ? meaning
                                : "Bu sembol, yaklaşan bir işaretin habercisi gibi duruyor.",
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.5,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildClosingCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Kapanış Mesajı",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            closing.isNotEmpty
                ? closing
                : "Enerji sana yavaş ama güçlü bir açılım gösteriyor. Sezgine güven.",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14.5,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPremiumUnlockCard() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _buildLockedPremiumCard();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};
        final isPremium = data['premium'] == true || data['isPremium'] == true;

        if (isPremium) {
          return _buildUnlockedSecretCard();
        }

        return _buildLockedPremiumCard();
      },
    );
  }

  Widget _buildUnlockedSecretCard() {
    final secretText = 'Gizli mesaj: Fincanın enerjisinde görünmeyen ama güçlü bir işaret var. Yakın dönemde beklediğin bir haber veya netleşmeyen bir konuşma tekrar gündeme gelebilir. Özellikle aşk ve niyet tarafında karşı tarafın sessizliği tamamen kopuş değil; daha çok düşünme ve içe çekilme enerjisi taşıyor. Bu süreçte acele etmek yerine sezgini dinlemen daha doğru olur.';

    return _glassCard(
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFD166),
              Color(0xFF7C3AED),
              Color(0xFFDB2777),
            ],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: const Color(0xFF120D20),
          ),
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
                      color: const Color(0xFFFFD166).withOpacity(0.18),
                    ),
                    child: const Icon(Icons.visibility_rounded, color: Color(0xFFFFD166)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Premium Gizli Kahve Mesajın Açıldı',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                secretText,
                style: const TextStyle(color: Colors.white70, fontSize: 14.5, height: 1.55),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockedPremiumCard() {
    return _glassCard(
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF7C3AED),
              Color(0xFFDB2777),
              Color(0xFFFFD166),
            ],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: const Color(0xFF120D20),
          ),
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
                      color: const Color(0xFFFFD166).withOpacity(0.18),
                    ),
                    child: const Icon(
                      Icons.lock_open_rounded,
                      color: Color(0xFFFFD166),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Falix burada gizli bir enerji yakaladı',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Premium ile önceki fallarına göre daha kişisel ilişki, kader ve yakın dönem mesajlarını açabilirsin.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14.5,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 650),
                        pageBuilder: (_, __, ___) => const PaywallPage(),
                        transitionsBuilder: (_, animation, __, child) {
                          final fade = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
                          return FadeTransition(opacity: fade, child: child);
                        },
                      ),
                    );
                  },
                  icon: const Icon(Icons.diamond_rounded),
                  label: const Text('Gizli Mesajları Premium ile Aç'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD166),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildExpertCTA() {
    return _glassCard(
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
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Color(0xFF5EEAD4),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Bu enerjiyi gerçek rehbere açtır',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Bu yorum sana özel hazırlandı. Gerçek uzmanlardan destek alarak aşk, ilişki ve yakın dönem enerjisini daha derin açtırabilirsin.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HumanExpertPage()),
                );
              },
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Uzmandan Derin Yorum Al'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.onTryAgain ??
                () {
                  Navigator.pop(context);
                },
            icon: const Icon(Icons.replay_rounded),
            label: const Text("Yeniden Fal Bak"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  transitionDuration: const Duration(milliseconds: 650),
                  reverseTransitionDuration: const Duration(milliseconds: 420),
                  pageBuilder: (_, __, ___) => const PaywallPage(),
                  transitionsBuilder: (_, animation, __, child) {
                    final fade = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                      reverseCurve: Curves.easeInCubic,
                    );

                    return FadeTransition(
                      opacity: fade,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.035),
                          end: Offset.zero,
                        ).animate(fade),
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.99, end: 1).animate(fade),
                          child: child,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            icon: const Icon(Icons.diamond_rounded),
            label: const Text("Premium’a Geç"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.18)),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090613),
      appBar: AppBar(
        title: const Text(
          "Kahve Falı",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
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
                    painter: _ResultBackgroundPainter(progress: _bgController.value),
                  ),
                ),
                Positioned(
                  top: -40,
                  left: -20,
                  child: _GlowOrb(
                    size: 170,
                    color: const Color(0xFF7C3AED).withOpacity(0.22),
                  ),
                ),
                Positioned(
                  top: 110,
                  right: -20,
                  child: _GlowOrb(
                    size: 140,
                    color: const Color(0xFFDB2777).withOpacity(0.14),
                  ),
                ),
                Positioned(
                  bottom: 100,
                  left: -20,
                  child: _GlowOrb(
                    size: 150,
                    color: const Color(0xFFFFB703).withOpacity(0.10),
                  ),
                ),
                Positioned(
                  bottom: -20,
                  right: -20,
                  child: _GlowOrb(
                    size: 180,
                    color: const Color(0xFF2563EB).withOpacity(0.12),
                  ),
                ),
                SafeArea(child: child!),
              ],
            ),
          );
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          child: FadeTransition(
            opacity: _cardsFade,
            child: SlideTransition(
              position: _cardsSlide,
              child: Column(
                children: [
                  _buildHero(),
                  const SizedBox(height: 18),
                  _buildSectionCard(
                    title: "Aşk",
                    text: love,
                    icon: Icons.favorite_rounded,
                    accent: const Color(0xFFFF6FAE),
                  ),
                  const SizedBox(height: 14),
                  _buildSectionCard(
                    title: "Kariyer",
                    text: career,
                    icon: Icons.work_rounded,
                    accent: const Color(0xFFA98BFF),
                  ),
                  const SizedBox(height: 14),
                  _buildSectionCard(
                    title: "Para",
                    text: money,
                    icon: Icons.monetization_on_rounded,
                    accent: const Color(0xFFFFD166),
                  ),
                  const SizedBox(height: 14),
                  _buildSectionCard(
                    title: "Tavsiye",
                    text: advice,
                    icon: Icons.auto_awesome_rounded,
                    accent: const Color(0xFF6EE7B7),
                  ),
                  const SizedBox(height: 14),
                  _buildSymbols(),
                  const SizedBox(height: 14),
                  _buildClosingCard(),
                  const SizedBox(height: 14),
                  _buildPremiumUnlockCard(),
                  const SizedBox(height: 14),
                  _buildExpertCTA(),
                  const SizedBox(height: 18),
                  _buildBottomActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EnergyBar extends StatelessWidget {
  final int score;

  const _EnergyBar({required this.score});

  @override
  Widget build(BuildContext context) {
    final widthFactor = (score.clamp(0, 100)) / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Enerji Yoğunluğu",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withOpacity(0.16),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: widthFactor.toDouble(),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFD166),
                      Color(0xFFFA9BFF),
                      Color(0xFFA98BFF),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "$score / 100",
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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

class _ResultBackgroundPainter extends CustomPainter {
  final double progress;

  _ResultBackgroundPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final stars = <Offset>[
      Offset(size.width * 0.12, size.height * 0.12),
      Offset(size.width * 0.26, size.height * 0.21),
      Offset(size.width * 0.84, size.height * 0.16),
      Offset(size.width * 0.72, size.height * 0.32),
      Offset(size.width * 0.16, size.height * 0.48),
      Offset(size.width * 0.88, size.height * 0.55),
      Offset(size.width * 0.30, size.height * 0.72),
      Offset(size.width * 0.62, size.height * 0.84),
    ];

    for (var i = 0; i < stars.length; i++) {
      final twinkle = 0.25 + 0.75 * ((math.sin((progress * 2 * math.pi) + i) + 1) / 2);
      paint.color = Colors.white.withOpacity(0.08 * twinkle);
      canvas.drawCircle(stars[i], 1.4 + (twinkle * 1.1), paint);
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFA98BFF).withOpacity(0.06);

    final path = Path();
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.24 +
          math.sin((x / 78) + (progress * 2 * math.pi)) * 8;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _ResultBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}