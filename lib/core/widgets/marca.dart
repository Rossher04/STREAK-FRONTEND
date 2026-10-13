import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/app_constants.dart';
import '../theme/streak_theme.dart';

/// Logo (boceto PROVISIONAL: `assets/logo/streak_logo_boceto.svg`; el definitivo usará el mismo nombre).
class LogoStreak extends StatelessWidget {
  const LogoStreak({super.key, this.lado = 68});

  final double lado;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/logo/streak_logo_boceto.svg',
        width: lado,
        height: lado,
        semanticsLabel: AppConstants.appName,
      );
}

/// Logo + "STREAK" + "NO ROMPAS LA RACHA" (login y arranque).
class MarcaStreak extends StatelessWidget {
  const MarcaStreak({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ExcludeSemantics(child: LogoStreak()),
        const SizedBox(height: 14),
        Text(AppConstants.appName, style: StreakText.wordmark),
        const SizedBox(height: 10),
        Text(AppConstants.appTagline.toUpperCase(), style: StreakText.lema),
      ],
    );
  }
}

/// Ilustración de marca: balón con estelas amarillo / naranja / amarillo (estado vacío y éxito).
class EstelaIlustracion extends StatelessWidget {
  const EstelaIlustracion({super.key, this.ancho = 122});

  final double ancho;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: ancho,
        height: ancho * 65 / 122,
        child: CustomPaint(painter: _EstelaPainter()),
      ),
    );
  }
}

class _EstelaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 122;
    final trazo = Paint()
      ..strokeWidth = 5 * k
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(6 * k, 13 * k), Offset(45 * k, 13 * k), trazo..color = StreakColors.accent);
    canvas.drawLine(Offset(2 * k, 32.5 * k), Offset(49 * k, 32.5 * k), trazo..color = StreakColors.orange);
    canvas.drawLine(Offset(10 * k, 52 * k), Offset(45 * k, 52 * k), trazo..color = StreakColors.accent);
    final centro = Offset(89.5 * k, 32.5 * k);
    canvas.drawCircle(centro, 32.5 * k, Paint()..color = StreakColors.cream);
    // Pentágono del balón.
    final r = 15 * k;
    final pent = Path();
    for (var i = 0; i < 5; i++) {
      final a = -1.5708 + i * 1.2566;
      final p = Offset(centro.dx + r * math.cos(a), centro.dy + 1.5 * k + r * math.sin(a));
      i == 0 ? pent.moveTo(p.dx, p.dy) : pent.lineTo(p.dx, p.dy);
    }
    pent.close();
    canvas.drawPath(pent, Paint()..color = StreakColors.brand);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
