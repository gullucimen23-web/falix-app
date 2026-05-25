import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'services/live_analytics_service.dart';

class CoffeeLoadingPage extends StatefulWidget {
  final Future<Map<String, dynamic>> Function() loadReading;

  const CoffeeLoadingPage({
    super.key,
    required this.loadReading,
  });

  @override
  State<CoffeeLoadingPage> createState() => _CoffeeLoadingPageState();
}

class _CoffeeLoadingPageState extends State<CoffeeLoadingPage>
    with TickerProviderStateMixin {
  late final AnimationController _bgController;
  late final AnimationController _pulseController;
  late final AnimationController _entryController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  String _title = 'Fal ritüeli başladı';
  String _subtitle = 'Fincandaki enerjiler dikkatle okunuyor...';
  double _progress = 0.08;
  bool _isDone = false;

  final List<_CoffeeStage> _stages = const [
    _CoffeeStage(
      title: 'Fincan açılıyor',
      subtitle: 'Telve izleri ve semboller tek tek ayıklanıyor...',
      progress: 0.18,
      waitMs: 1100,
    ),
    _CoffeeStage(
      title: 'Enerji okunuyor',
      subtitle: 'Fincandaki yoğunluk, kalp ve kısmet alanına göre çözülüyor...',
      progress: 0.42,
      waitMs: 1400,
    ),
    _CoffeeStage(
      title: 'Gerçek yorumcu hissi',
      subtitle: 'İşaretler birleştiriliyor, sana özel yorum hazırlanıyor...',
      progress: 0.68,
      waitMs: 1500,
    ),
    _CoffeeStage(
      title: 'Fal netleşiyor',
      subtitle: 'Son enerji dokunuşları yapılıyor. Yorum birazdan açılacak...',
      progress: 0.9,
      waitMs: 1200,
    ),
  ];

  @override
  void initState() {
    super.initState();
    LiveAnalyticsService.instance.trackScreen(screenName: 'Kahve Falı Analiz', screenKey: 'coffee_loading');

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
      duration: const Duration(milliseconds: 900),
    )..forward();

    _fade = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startFlow();
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _pulseController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _startFlow() async {
    final stopwatch = Stopwatch()..start();
    final future = widget.loadReading();

    try {
      for (final stage in _stages) {
        if (!mounted) return;
        setState(() {
          _title = stage.title;
          _subtitle = stage.subtitle;
          _progress = stage.progress;
        });
        await Future.delayed(Duration(milliseconds: stage.waitMs));
      }

      final result = await future;

      const minTotalMs = 6200;
      final remaining = minTotalMs - stopwatch.elapsedMilliseconds;
      if (remaining > 0) {
        if (!mounted) return;
        setState(() {
          _title = 'Falın açılıyor';
          _subtitle = 'Son sezgisel kontrol yapılıyor. Mesaj birazdan seninle.';
          _progress = 0.97;
        });
        await Future.delayed(Duration(milliseconds: remaining));
      }

      if (!mounted) return;
      setState(() {
        _isDone = true;
        _progress = 1;
        _title = 'Hazır';
        _subtitle = 'Yorumun tamamlandı. Kapılar açılıyor...';
      });

      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kahve falı hatası: $e')),
      );
    }
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.12),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
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
                      painter: _CoffeeLoadingPainter(progress: _bgController.value),
                    );
                  },
                ),
              ),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                    child: Column(
                      children: [
                        const Spacer(),
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final glow = 0.84 + (_pulseController.value * 0.16);
                            return Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFFDB2777).withOpacity(0.95 * glow),
                                    const Color(0xFF7C3AED).withOpacity(0.82 * glow),
                                    const Color(0xFF120B22).withOpacity(0.18),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7C3AED).withOpacity(0.35),
                                    blurRadius: 46,
                                    spreadRadius: 6,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: 92,
                                  height: 92,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.08),
                                    border: Border.all(color: Colors.white.withOpacity(0.14)),
                                  ),
                                  child: const Icon(
                                    Icons.local_cafe_rounded,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 26),
                        Text(
                          _title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14.5,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _glassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD978), size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Yorum hazırlanıyor',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: _progress,
                                  minHeight: 10,
                                  backgroundColor: Colors.white.withOpacity(0.08),
                                  valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD978)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Mistik çözümleme',
                                    style: TextStyle(color: Colors.white54, fontSize: 12.5),
                                  ),
                                  Text(
                                    '${(_progress * 100).round()}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isDone
                              ? 'Yorumun tamamlandı.'
                              : 'Gerçek yorumcu hissi için falın birkaç saniye derinlemesine okunuyor.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.62),
                            fontSize: 12.8,
                            height: 1.45,
                          ),
                        ),
                        const Spacer(),
                      ],
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

class _CoffeeStage {
  final String title;
  final String subtitle;
  final double progress;
  final int waitMs;

  const _CoffeeStage({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.waitMs,
  });
}

class _CoffeeLoadingPainter extends CustomPainter {
  final double progress;

  _CoffeeLoadingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 20; i++) {
      final x = (size.width / 20) * i + math.sin((progress * 2 * math.pi) + i) * 10;
      final y = (size.height * ((i % 6) / 6)) +
          math.cos((progress * 2 * math.pi) + i) * 18;

      paint.color = Colors.white.withOpacity(0.03);
      canvas.drawCircle(
        Offset(x, y.abs() % size.height),
        1.3 + (i % 3).toDouble(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CoffeeLoadingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
