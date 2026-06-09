import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Navigate to AuthScreen after 4.5 seconds
    Timer(const Duration(milliseconds: 4500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const AuthScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 1000),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFF), // Very light cool white
      body: Stack(
        children: [
          // 1. Background Grid (Top Left)
          Positioned(
            top: 40,
            left: 20,
            child: CustomPaint(
              size: const Size(100, 100),
              painter: _GridPainter(),
            ).animate().fadeIn(duration: 1.seconds).slideX(begin: -0.2),
          ),

          // 2. Background Concentric Circles (Top Right)
          Positioned(
            top: -50,
            right: -50,
            child: CustomPaint(
              size: const Size(200, 200),
              painter: _ConcentricCirclesPainter(),
            ).animate().fadeIn(duration: 1.5.seconds).scale(begin: const Offset(0.8, 0.8)),
          ),

          // 3. Animated Skyline & Clouds (Middle/Bottom Background)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            left: -50,
            right: -50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                const Icon(Icons.location_city, size: 150, color: Color(0xFFEDF2F7))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .slideY(begin: 0, end: -0.05, duration: 4.seconds, curve: Curves.easeInOutSine),
                const Icon(Icons.location_city, size: 200, color: Color(0xFFF1F5F9))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .slideY(begin: -0.02, end: 0.05, duration: 5.seconds, curve: Curves.easeInOutSine),
                const Icon(Icons.location_city, size: 120, color: Color(0xFFEDF2F7))
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .slideY(begin: 0, end: -0.08, duration: 3.5.seconds, curve: Curves.easeInOutSine),
              ],
            ).animate().fadeIn(duration: 2.seconds),
          ),

          // 4. Animated Blueprint lines (Bottom Background)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: 0.4,
              child: CustomPaint(
                size: Size(MediaQuery.of(context).size.width, 250),
                painter: _BlueprintPainter(),
              ).animate().fadeIn(delay: 500.ms, duration: 1.5.seconds).slideY(begin: 0.2),
            ),
          ),

          // 5. Main Foreground Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Circle with animated ring
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Spinning outer blue arc
                      AnimatedBuilder(
                        animation: _spinController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _spinController.value * 2 * math.pi,
                            child: CustomPaint(
                              size: const Size(160, 160),
                              painter: _ArcPainter(),
                            ),
                          );
                        },
                      ),
                      
                      // Inner White Circle with Shadow
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.1),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Building (Black)
                              Positioned(
                                right: 26,
                                bottom: 28,
                                child: Container(
                                  width: 26,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFF1E293B), width: 4),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Container(width: 6, height: 6, color: const Color(0xFF1E293B)),
                                      Container(width: 6, height: 6, color: const Color(0xFF1E293B)),
                                      Container(width: 6, height: 6, color: const Color(0xFF1E293B)),
                                    ],
                                  ),
                                ).animate().slideX(begin: 0.5, duration: 800.ms, curve: Curves.easeOutBack),
                              ),
                              // House (Blue)
                              Positioned(
                                left: 24,
                                bottom: 28,
                                child: Icon(
                                  Icons.home_outlined,
                                  size: 60,
                                  color: const Color(0xFF2979FF),
                                ).animate().scale(begin: const Offset(0, 0), duration: 800.ms, curve: Curves.easeOutBack),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 800.ms).scale(curve: Curves.easeOutBack),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // AI HOUSE Text
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'AI ',
                        style: TextStyle(
                          color: Color(0xFF2979FF),
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      TextSpan(
                        text: 'HOUSE',
                        style: TextStyle(
                          color: Color(0xFF1E293B), // Dark text
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),

                const SizedBox(height: 16),

                // Divider and Tagline
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 20, height: 1, color: const Color(0xFF2979FF)),
                    const SizedBox(width: 12),
                    const Text(
                      'BUILDING THE FUTURE',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(width: 20, height: 1, color: const Color(0xFF2979FF)),
                  ],
                ).animate().fadeIn(delay: 800.ms).slideX(begin: 0.1),

                const SizedBox(height: 60),

                // Loading Spinner
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2979FF)),
                  ),
                ).animate().fadeIn(delay: 1200.ms),

                const SizedBox(height: 16),

                // Loading Text
                const Text(
                  'Loading...',
                  style: TextStyle(
                    color: Color(0xFF2979FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fadeIn(delay: 1400.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painters for Background Details

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD3E3FD)
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 5; j++) {
        canvas.drawCircle(Offset(i * 15.0, j * 15.0), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ConcentricCirclesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8F0FE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    final center = Offset(size.width, 0); // Top right corner center
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, i * 40.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BlueprintPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBFD4F2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    // Draw some architectural wireframe lines
    // Base lines
    canvas.drawLine(Offset(0, size.height - 20), Offset(size.width, size.height - 20), paint);
    canvas.drawLine(Offset(0, size.height - 15), Offset(size.width, size.height - 15), paint);
    
    // Building 1
    final p1 = Path();
    p1.moveTo(size.width * 0.2, size.height - 20);
    p1.lineTo(size.width * 0.2, size.height * 0.4);
    p1.lineTo(size.width * 0.4, size.height * 0.4);
    p1.lineTo(size.width * 0.4, size.height - 20);
    
    // Grid inside Building 1
    for(double i = size.height * 0.45; i < size.height - 20; i += 15) {
      p1.moveTo(size.width * 0.2, i);
      p1.lineTo(size.width * 0.4, i);
    }
    for(double i = size.width * 0.25; i < size.width * 0.4; i += 20) {
      p1.moveTo(i, size.height * 0.4);
      p1.lineTo(i, size.height - 20);
    }

    // Building 2 (House shape)
    p1.moveTo(size.width * 0.5, size.height - 20);
    p1.lineTo(size.width * 0.5, size.height * 0.6);
    p1.lineTo(size.width * 0.65, size.height * 0.45); // roof tip
    p1.lineTo(size.width * 0.8, size.height * 0.6);
    p1.lineTo(size.width * 0.8, size.height - 20);

    canvas.drawPath(p1, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2979FF)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;
    
    // Draw an arc from top-left curving around
    canvas.drawArc(
      Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: size.width, height: size.height),
      -math.pi, // start at left
      math.pi * 1.2, // sweep more than half
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
