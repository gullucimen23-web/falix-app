import 'dart:math' as math;
import 'package:flutter/material.dart';

class FalixLogo extends StatefulWidget {
  const FalixLogo({super.key});

  @override
  State<FalixLogo> createState() => _FalixLogoState();
}

class _FalixLogoState extends State<FalixLogo>
    with TickerProviderStateMixin {
  late final AnimationController _rotateController;
  late final AnimationController _pulseController;
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();

    _rotateController =
        AnimationController(vsync: this, duration: const Duration(seconds: 12))
          ..repeat();

    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);

    _shimmerController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Widget _auraCircle(double size) {
    return AnimatedBuilder(
      animation: Listenable.merge([_rotateController, _pulseController]),
      builder: (_, __) {
        final scale = 0.95 + (_pulseController.value * 0.1);

        return Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: _rotateController.value * 2 * math.pi,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: const [
                    Color(0xFF7C3AED),
                    Color(0xFFDB2777),
                    Color(0xFF9333EA),
                    Color(0xFF7C3AED),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purpleAccent.withOpacity(0.6),
                    blurRadius: 60,
                    spreadRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _core() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [
            Color(0xFFDB2777),
            Color(0xFF7C3AED),
            Colors.black,
          ],
        ),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 38,
      ),
    );
  }

  Widget _shimmerText() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (_, __) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                Colors.white,
                Color(0xFFFFD978),
                Colors.white,
              ],
              stops: [
                (_shimmerController.value - 0.3).clamp(0, 1),
                _shimmerController.value,
                (_shimmerController.value + 0.3).clamp(0, 1),
              ],
            ).createShader(bounds);
          },
          child: const Text(
            "Falix",
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _auraCircle(140),
              _auraCircle(110),
              _core(),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _shimmerText(),
      ],
    );
  }
}