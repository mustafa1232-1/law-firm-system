import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../theme/lexiq_colors.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        context.go('/');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.4,
                colors: [
                  Color(0xFF1B2D57),
                  LexiqColors.deepNavy,
                  LexiqColors.obsidianBlack,
                ],
              ),
            ),
          ),
          CustomPaint(painter: _FaintGridPainter()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.balance_rounded,
                  size: 92,
                  color: LexiqColors.brassGold,
                ).animate().scale(duration: 700.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 18),
                Text(
                  context.tr('LexIQ Iraq'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ).animate().fadeIn(delay: 250.ms, duration: 500.ms),
                const SizedBox(height: 8),
                Text(
                  context.tr('Iraqi Legal Intelligence Platform'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ).animate().fadeIn(delay: 450.ms, duration: 500.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaintGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LexiqColors.brassGold.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += 44) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
