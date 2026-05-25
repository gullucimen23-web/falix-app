import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'human_expert_page.dart';
import 'paywall_page.dart';

class TarotResultPage extends StatefulWidget {
  final String result;

  const TarotResultPage({
    super.key,
    required this.result,
  });

  @override
  State<TarotResultPage> createState() => _TarotResultPageState();
}

class _TarotResultPageState extends State<TarotResultPage>
    with TickerProviderStateMixin {
  late final AnimationController _bgController;
  late final AnimationController _entryController;
  late final AnimationController _pulseController;

  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _cardsFade;
  late final Animation<Offset> _cardsSlide;

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

  List<String> get _parsedSections {
    final raw = widget.result.trim();
    if (raw.isEmpty) return ["Tarot yorumun hazırlanamadı."];
    return raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String get _headlineText {
    if (_parsedSections.isEmpty) return "Tarot Yorumun Hazır";
    return _parsedSections.first.length > 80
        ? "Tarot Yorumun Hazır"
        : _parsedSections.first;
  }

  String get _bodyText {
    if (_parsedSections.length <= 1) return widget.result.trim();
    return _parsedSections.skip(1).join('\n\n');
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
    final secretText = _bodyText.trim().isNotEmpty
        ? 'Gizli mesaj: Bu açılımda en güçlü işaret, beklediğin cevabın dışarıdan değil sezginden geleceğini söylüyor. Kartların enerjisi özellikle ilişki, karar ve yakın gelecek konusunda acele etmeden gözlem yapman gerektiğini gösteriyor. Sana yaklaşan fırsat önce küçük bir işaret gibi görünebilir; bu yüzden bugün gelen mesajlara, rüyalara ve iç sesine dikkat et.'
        : 'Gizli mesaj: Kartların altında saklanan enerji, içindeki cevabın yakında netleşeceğini söylüyor. Sezgine güven ve acele karar verme.';

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
                      'Premium Gizli Tarot Mesajın Açıldı',
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
                    child: const Icon(Icons.lock_open_rounded, color: Color(0xFFFFD166)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Kartların altında gizli bir mesaj var',
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
                'Premium ile Falix önceki enerjilerini hatırlar ve bu açılımı ilişki, kader bağı ve yakın gelecek açısından daha derin yorumlar.',
                style: TextStyle(color: Colors.white70, fontSize: 14.5, height: 1.55),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallPage()));
                  },
                  icon: const Icon(Icons.diamond_rounded),
                  label: const Text('Gizli Tarot Mesajını Aç'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD166),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                  'Kartların enerjisini gerçek rehbere açtır',
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
            'Bu tarot yorumu güçlü bir başlangıç. Gerçek uzmanlardan destek alarak ilişki, kader bağı ve yakın gelecek enerjisini daha detaylı yorumlatabilirsin.',
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _bgController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _TarotBackgroundPainter(
                        progress: _bgController.value,
                      ),
                    );
                  },
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.white.withOpacity(0.08),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: Color(0xFFFFD978),
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                "Premium Tarot",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FadeTransition(
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
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.14),
                                ),
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
                                      Icons.style_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Text(
                                      "Tarot Yorumun Hazır",
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
                                _headlineText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "Kartların söylediği enerjiyi senin için derinlemesine yorumladım. Sezgine en çok dokunan cümlelere dikkat et.",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14.5,
                                  height: 1.55,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: FadeTransition(
                        opacity: _cardsFade,
                        child: SlideTransition(
                          position: _cardsSlide,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                _glassCard(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: const Color(0xFF7C3AED)
                                                  .withOpacity(0.18),
                                            ),
                                            child: const Icon(
                                              Icons.auto_fix_high_rounded,
                                              color: Color(0xFFFFD978),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Expanded(
                                            child: Text(
                                              "Yorum Detayı",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _bodyText.isEmpty ? widget.result : _bodyText,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 15,
                                          height: 1.75,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _glassCard(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _MiniInfoCard(
                                          title: "Enerji",
                                          value: "Yüksek",
                                          icon: Icons.bolt_rounded,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _MiniInfoCard(
                                          title: "Akış",
                                          value: "Açılıyor",
                                          icon: Icons.timeline_rounded,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _MiniInfoCard(
                                          title: "Sezgi",
                                          value: "Güçlü",
                                          icon: Icons.visibility_rounded,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _buildPremiumUnlockCard(),
                                const SizedBox(height: 14),
                                _buildExpertCTA(),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF7C3AED),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                    ),
                                    child: const Text(
                                      "Ana Sayfaya Dön",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15.5,
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MiniInfoCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFFFD978), size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TarotBackgroundPainter extends CustomPainter {
  final double progress;

  _TarotBackgroundPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 16; i++) {
      final x = (size.width / 16) * i + math.sin((progress * 2 * math.pi) + i) * 10;
      final y = (size.height * ((i % 5) / 5)) +
          math.cos((progress * 2 * math.pi) + i) * 18;

      paint.color = Colors.white.withOpacity(0.035);
      canvas.drawCircle(
        Offset(x, y.abs() % size.height),
        1.5 + (i % 3).toDouble(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TarotBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}