import 'package:flutter/material.dart';

import '../../../../core/network/actividad_red.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/marca.dart';

/// Arranque: la redirección de sesión la hace GoRouter; esta pantalla cubre AuthStatus.unknown.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(StreakSize.screenPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MarcaStreak(),
                SizedBox(height: 40),
                SizedBox(
                  width: StreakSize.icon,
                  height: StreakSize.icon,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                SizedBox(height: 24),
                AvisoServidorLento(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
