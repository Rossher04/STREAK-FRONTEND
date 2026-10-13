import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/deep_links.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/utils/password_rules.dart';
import '../../../../core/widgets/botones.dart';
import '../../../../core/widgets/campo_texto.dart';
import '../../../../core/widgets/estructura.dart';
import '../../application/auth_controller.dart';
import 'registro_screen.dart' show ayudaPassword;

/// Pantalla 04 · Nueva contraseña, destino del enlace `streak://reset-password?uid&token` (/restablecer/:uid/:token).
/// No se registra ni se muestra el token. Si el backend lo rechaza (TOKEN_INVALIDO) se abre "Enlace inválido" (05).
class RestablecerPasswordScreen extends ConsumerStatefulWidget {
  const RestablecerPasswordScreen({super.key, required this.uid, required this.token});

  final String uid;
  final String token;

  @override
  ConsumerState<RestablecerPasswordScreen> createState() => _RestablecerPasswordScreenState();
}

class _RestablecerPasswordScreenState extends ConsumerState<RestablecerPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nueva = TextEditingController();
  final _confirmar = TextEditingController();
  bool _cargando = false;
  AppException? _error;

  @override
  void dispose() {
    _nueva.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await ref.read(authControllerProvider.notifier).restablecer(
            uid: widget.uid,
            token: widget.token,
            newPassword: _nueva.text,
          );
      if (!mounted) return;
      avisar(context, 'Contraseña actualizada. Inicia sesión con la nueva.');
      context.go('/login');
    } on AppException catch (e) {
      if (!mounted) return;
      if (e.codigo == 'TOKEN_INVALIDO' || e.campo('uid') != null || e.campo('token') != null) {
        context.go(rutaEnlaceInvalido);
        return;
      }
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _error;
    final errorCampo = e?.campo('new_password');
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva contraseña')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(StreakSize.screenPadding, 12, StreakSize.screenPadding, 24),
            children: [
              Text('Elige una contraseña nueva para tu cuenta.', style: StreakText.secundario),
              const SizedBox(height: 22),
              if (e != null && errorCampo == null) ...[BannerAviso(texto: e.mensaje), const SizedBox(height: 16)],
              CampoTexto(
                etiqueta: 'Nueva contraseña',
                controller: _nueva,
                contrasena: true,
                ayuda: ayudaPassword,
                errorServidor: errorCampo,
                autofillHints: const [AutofillHints.newPassword],
                validator: PasswordRules.validate,
              ),
              const SizedBox(height: 16),
              CampoTexto(
                etiqueta: 'Confirmar contraseña',
                controller: _confirmar,
                contrasena: true,
                validator: (v) => v != _nueva.text ? 'Las contraseñas no coinciden' : null,
              ),
              const SizedBox(height: 24),
              BotonPrimario(texto: 'Guardar contraseña', cargando: _cargando, onPressed: _guardar),
            ],
          ),
        ),
      ),
    );
  }
}
