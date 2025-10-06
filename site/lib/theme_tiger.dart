import 'package:flutter/material.dart';

/// --- THÈME TIGRES GLOBAL ---
class Tiger {
  static ThemeData get theme => ThemeData.dark().copyWith(
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      primary: Colors.orangeAccent,
      secondary: Colors.deepOrange,
    ),
    textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white70)),
  );

  static ButtonStyle tigerButton({Color? background}) {
    return ElevatedButton.styleFrom(
      backgroundColor: background ?? Colors.orangeAccent,
      foregroundColor: Colors.black,
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      minimumSize: const Size(180, 56),
      elevation: 3,
    );
  }
}

/// --- FOND TIGRE ANIMÉ GLOBAL ---
/// Effet horizontal lent, avec bandes tigres oranges/noires dynamiques
class TigerAnimatedBG extends StatefulWidget {
  final Widget child;
  final bool rightToLeft;
  final double speed;

  const TigerAnimatedBG({
    super.key,
    required this.child,
    this.rightToLeft = true,
    this.speed = 0.25,
  });

  @override
  State<TigerAnimatedBG> createState() => _TigerAnimatedBGState();
}

class _TigerAnimatedBGState extends State<TigerAnimatedBG>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: (60 / widget.speed).round()),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Génère un effet "bandes tigre" abstrait mais stylé
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final shift = widget.rightToLeft
            ? -_controller.value
            : _controller.value;

        return Container(
          decoration: const BoxDecoration(color: Colors.black),
          child: Stack(
            children: [
              // --- FOND ORANGE PROFOND ---
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF1A0B00),
                        Color(0xFF2C1000),
                        Color(0xFF0D0600),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),

              // --- BANDES TIGRES ---
              Positioned.fill(
                child: CustomPaint(painter: _TigerStripesPainter(shift)),
              ),

              // --- ENFANT (contenu de la page) ---
              widget.child,
            ],
          ),
        );
      },
    );
  }
}

/// Peint des bandes tigre diagonales oranges/noires qui bougent horizontalement
class _TigerStripesPainter extends CustomPainter {
  final double shift;

  _TigerStripesPainter(this.shift);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0;

    final stripeWidth = size.width / 6;
    final dx = shift * size.width * 2;

    for (int i = -1; i < 8; i++) {
      final xOffset = (i * stripeWidth * 1.2) + dx;
      final path = Path()
        ..moveTo(xOffset, 0)
        ..lineTo(xOffset + stripeWidth / 2, 0)
        ..lineTo(xOffset + stripeWidth, size.height)
        ..lineTo(xOffset + stripeWidth / 2, size.height)
        ..close();

      // Alterne les couleurs façon "tigre"
      paint.color = (i % 2 == 0)
          ? const Color(0xFFFF7A00).withOpacity(0.15) // orange doux
          : const Color(0xFF000000).withOpacity(0.4); // noir semi-transparent

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_TigerStripesPainter oldDelegate) =>
      oldDelegate.shift != shift;
}
