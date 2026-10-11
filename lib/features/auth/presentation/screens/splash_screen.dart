import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/actividad_red.dart';
import '../../../../core/theme/app_colors.dart';

/// La redirección de sesión la hace GoRouter. Esta pantalla cubre AuthStatus.unknown.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: AppColors.sportsOrange,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sports_soccer, size: 54, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text(
              AppConstants.appName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.goldAccent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                AppConstants.appTagline,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.goldAccent,
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(32, 24, 32, 0),
              child: AvisoServidorLento(),
            ),
          ],
        ),
      ),
    );
  }
}
