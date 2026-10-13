import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/botones.dart';
import '../../../../core/widgets/streak_icon.dart';

/// Pantalla 05 · Enlace inválido o vencido: faltan uid o token, o el backend rechazó el token.
class EnlaceInvalidoScreen extends StatelessWidget {
  const EnlaceInvalidoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(StreakSize.screenPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: StreakIcon(StreakIcons.alert, size: 52, color: StreakColors.orangeText)),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text('Enlace inválido o vencido', textAlign: TextAlign.center, style: StreakText.tituloGrande),
                ),
                const SizedBox(height: 12),
                Text('Pide un enlace nuevo para recuperar tu contraseña.',
                    textAlign: TextAlign.center, style: StreakText.secundario),
                const SizedBox(height: 32),
                BotonPrimario(texto: 'Pedir un enlace nuevo', onPressed: () => context.go('/recuperar')),
                const SizedBox(height: 12),
                BotonSecundario(texto: 'Volver a iniciar sesión', onPressed: () => context.go('/login')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
