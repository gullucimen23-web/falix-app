import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'services/live_analytics_service.dart';

class TarotSelectionResult {
  final String topic;
  final List<String> cards;

  const TarotSelectionResult({
    required this.topic,
    required this.cards,
  });
}

class TarotSelectionPage extends StatefulWidget {
  const TarotSelectionPage({super.key});

  @override
  State<TarotSelectionPage> createState() => _TarotSelectionPageState();
}

class _TarotSelectionPageState extends State<TarotSelectionPage>
    with TickerProviderStateMixin {
  final List<String> _cards = const [
    "Deli",
    "Büyücü",
    "Başrahibe",
    "İmparatoriçe",
    "İmparator",
    "Aziz",
    "Aşıklar",
    "Savaş Arabası",
    "Güç",
    "Ermiş",
    "Kader Çarkı",
    "Adalet",
    "Asılan Adam",
    "Ölüm",
    "Denge",
    "Şeytan",
    "Kule",
    "Yıldız",
    "Ay",
    "Güneş",
    "Mahkeme",
    "Dünya",
  ];

  String _selectedTopic = "genel";
  final List<String> _selectedCards = [];

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
    LiveAnalyticsService.instance.trackScreen(screenName: 'Tarot Kart Seçimi', screenKey: 'tarot_selection');

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
      duration: const Duration(milliseconds: 1150),
    )..forward();

    _headerFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );

    _headerSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    _cardsFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.20, 1, curve: Curves.easeOut),
    );

    _cardsSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.20, 1, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleCard(String card) {
    setState(() {
      if (_selectedCards.contains(card)) {
        _selectedCards.remove(card);
      } else {
        if (_selectedCards.length < 3) {
          _selectedCards.add(card);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tarot açılımı için sadece 3 kart seçebilirsin.'),
            ),
          );
        }
      }
    });
  }

  String _topicLabel(String value) {
    switch (value) {
      case "ask":
        return "Aşk";
      case "kariyer":
        return "Kariyer";
      default:
        return "Genel";
    }
  }

  IconData _topicIcon(String value) {
    switch (value) {
      case "ask":
        return Icons.favorite_rounded;
      case "kariyer":
        return Icons.work_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  Future<void> _openCards() async {
    if (_selectedCards.length != 3) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future.delayed(const Duration(milliseconds: 2400), () {
          if (!mounted) return;
          Navigator.of(dialogContext).pop();
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: _OpeningDialog(
            pulseController: _pulseController,
            topic: _topicLabel(_selectedTopic),
          ),
        );
      },
    );

    if (!mounted) return;

    Navigator.pop(
      context,
      TarotSelectionResult(
        topic: _selectedTopic,
        cards: List<String>.from(_selectedCards),
      ),
    );
  }

  Widget _topicChip(String topic) {
    final selected = _selectedTopic == topic;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTopic = topic;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: selected
              ? const LinearGradient(
                  colors: [
                    Color(0xFFFFD166),
                    Color(0xFFFF8FAB),
                  ],
                )
              : null,
          color: selected ? null : Colors.white.withOpacity(0.08),
          border: Border.all(
            color: selected ? Colors.white.withOpacity(0.28) : Colors.white.withOpacity(0.10),
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: const Color(0xFFFFD166).withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _topicIcon(topic),
              color: selected ? Colors.black : Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              _topicLabel(topic),
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
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
                    color: const Color(0xFF7C3AED).withOpacity(0.26),
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
                      'Gizemli Tarot Açılımı',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Kart isimleri kapalı tutulur. Sezgine güven, üç kart seç ve Falix gizli mesajları senin için açsın.',
                style: TextStyle(
                  color: Colors.white70,
                  height: 1.55,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _ProgressPill(
                    value: '${_selectedCards.length}/3',
                    label: 'Kart seçildi',
                  ),
                  const SizedBox(width: 10),
                  _ProgressPill(
                    value: _topicLabel(_selectedTopic),
                    label: 'Konu',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _selectedCards.length == 3;

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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Tarot Seçimi',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _bgController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _TarotSelectionBackgroundPainter(
                        progress: _bgController.value,
                      ),
                    );
                  },
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: FadeTransition(
                      opacity: _cardsFade,
                      child: SlideTransition(
                        position: _cardsSlide,
                        child: CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                              sliver: SliverToBoxAdapter(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildHero(),
                                    const SizedBox(height: 18),
                                    const Text(
                                      'Konu seç',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        for (final topic in const ['genel', 'ask', 'kariyer'])
                                          _topicChip(topic),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Kapalı kartlardan 3 tanesini seç',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(999),
                                            color: canContinue
                                                ? const Color(0xFFFFD166).withOpacity(0.18)
                                                : Colors.white.withOpacity(0.08),
                                            border: Border.all(
                                              color: canContinue
                                                  ? const Color(0xFFFFD166).withOpacity(0.34)
                                                  : Colors.white.withOpacity(0.08),
                                            ),
                                          ),
                                          child: Text(
                                            '${_selectedCards.length}/3',
                                            style: TextStyle(
                                              color: canContinue
                                                  ? const Color(0xFFFFD166)
                                                  : Colors.white70,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Kartların isimleri sonuç hazırlanana kadar gizli kalır.',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 13.2,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                              sliver: SliverGrid(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: 0.76,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final card = _cards[index];
                                    final isSelected = _selectedCards.contains(card);
                                    final order = isSelected
                                        ? _selectedCards.indexOf(card) + 1
                                        : null;

                                    return _MysteryTarotCard(
                                      index: index,
                                      isSelected: isSelected,
                                      selectedOrder: order,
                                      pulseValue: _pulseController.value,
                                      onTap: () => _toggleCard(card),
                                    );
                                  },
                                  childCount: _cards.length,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090613).withOpacity(0.74),
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: canContinue ? _openCards : null,
                        icon: Icon(
                          canContinue
                              ? Icons.auto_awesome_rounded
                              : Icons.lock_outline_rounded,
                        ),
                        label: Text(
                          canContinue
                              ? 'Kart Enerjilerini Aç'
                              : 'Devam etmek için 3 kart seç',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canContinue
                              ? const Color(0xFFFFD166)
                              : Colors.white.withOpacity(0.16),
                          foregroundColor: canContinue ? Colors.black : Colors.white70,
                          disabledBackgroundColor: Colors.white.withOpacity(0.12),
                          disabledForegroundColor: Colors.white54,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 17),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MysteryTarotCard extends StatelessWidget {
  final int index;
  final bool isSelected;
  final int? selectedOrder;
  final double pulseValue;
  final VoidCallback onTap;

  const _MysteryTarotCard({
    required this.index,
    required this.isSelected,
    required this.selectedOrder,
    required this.pulseValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final angle = isSelected ? math.pi : 0.0;
    final glow = 0.85 + (pulseValue * 0.15);

    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: angle),
        duration: const Duration(milliseconds: 460),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          final showBack = value < math.pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(value),
            child: showBack
                ? _CardFaceBack(
                    index: index,
                    glow: glow,
                  )
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _CardFaceSelected(
                      order: selectedOrder ?? 1,
                      glow: glow,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _CardFaceBack extends StatelessWidget {
  final int index;
  final double glow;

  const _CardFaceBack({
    required this.index,
    required this.glow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF211138).withOpacity(glow),
            const Color(0xFF32135A).withOpacity(glow),
            const Color(0xFF100A1E).withOpacity(glow),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.14),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFD166).withOpacity(0.18)),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white.withOpacity(0.24),
              size: 16,
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: Transform.rotate(
              angle: math.pi,
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white.withOpacity(0.24),
                size: 16,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFD166).withOpacity(0.12),
                    border: Border.all(color: const Color(0xFFFFD166).withOpacity(0.22)),
                  ),
                  child: const Icon(
                    Icons.visibility_rounded,
                    color: Color(0xFFFFD166),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'FALIX',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.4,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Gizemli Kart',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.64),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardFaceSelected extends StatelessWidget {
  final int order;
  final double glow;

  const _CardFaceSelected({
    required this.order,
    required this.glow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFD166).withOpacity(glow),
            const Color(0xFFFF8FAB).withOpacity(glow),
            const Color(0xFF7C3AED).withOpacity(glow),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.32), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD166).withOpacity(0.24),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.32)),
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.18),
                    border: Border.all(color: Colors.white.withOpacity(0.38)),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '$order. Kart',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Enerjisi seçildi',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OpeningDialog extends StatelessWidget {
  final AnimationController pulseController;
  final String topic;

  const _OpeningDialog({
    required this.pulseController,
    required this.topic,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final scale = 0.96 + (pulseController.value * 0.08);

        return Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF7C3AED),
                Color(0xFFDB2777),
                Color(0xFFFFD166),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withOpacity(0.36),
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: const Color(0xFF120D20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFD166).withOpacity(0.14),
                      border: Border.all(color: const Color(0xFFFFD166).withOpacity(0.30)),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFFFD166),
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Kart enerjileri açılıyor...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$topic konusu için seçtiğin üç kartın gizli mesajı hazırlanıyor.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 22),
                const SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Color(0xFFFFD166),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProgressPill extends StatelessWidget {
  final String value;
  final String label;

  const _ProgressPill({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(0.10),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarotSelectionBackgroundPainter extends CustomPainter {
  final double progress;

  _TarotSelectionBackgroundPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 22; i++) {
      final x = (size.width / 22) * i + math.sin((progress * 2 * math.pi) + i) * 12;
      final y = (size.height * ((i % 7) / 7)) +
          math.cos((progress * 2 * math.pi) + i) * 22;

      paint.color = Colors.white.withOpacity(0.035);
      canvas.drawCircle(
        Offset(x, y.abs() % size.height),
        1.2 + (i % 3).toDouble(),
        paint,
      );
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFFA98BFF).withOpacity(0.06);

    final path = Path();
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * 0.36 +
          math.sin((x / 82) + (progress * 2 * math.pi)) * 10;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TarotSelectionBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
