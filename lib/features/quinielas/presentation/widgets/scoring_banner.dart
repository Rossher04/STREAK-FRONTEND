import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

/// Banner obligatorio B3: sistema de puntaje 5 / 3 / +1 (A5 y RN-45 a RN-47).
class ScoringBanner extends StatelessWidget {
  const ScoringBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.creamBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.goldAccent),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sistema de puntaje',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
            ),
          ),
          SizedBox(height: 8),
          Text('Marcador exacto: ${AppConstants.puntosMarcadorExacto} pts'),
          Text('Ganador o empate correcto: ${AppConstants.puntosGanadorCorrecto} pts'),
          Text('+${AppConstants.puntosDiferenciaGolesExtra} pt si aciertas la diferencia (total 4)'),
          Text('Fallo o sin pronóstico: ${AppConstants.puntosFallo} pts'),
        ],
      ),
    );
  }
}
