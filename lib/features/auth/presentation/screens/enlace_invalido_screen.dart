import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';

/// Se muestra cuando un enlace de recuperación llega sin uid o sin token.
class EnlaceInvalidoScreen extends StatelessWidget {
  const EnlaceInvalidoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enlace inválido')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_off, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('Enlace inválido', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'El enlace de recuperación está incompleto. Pide uno nuevo desde "¿Olvidaste tu contraseña?".',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/recuperar'),
                child: const Text('PEDIR UN ENLACE NUEVO'),
              ),
              TextButton(onPressed: () => context.go('/login'), child: const Text('Volver al inicio de sesión')),
            ],
          ),
        ),
      ),
    );
  }
}
