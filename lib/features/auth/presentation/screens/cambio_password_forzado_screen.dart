import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/utils/password_rules.dart';
import '../../../../core/widgets/botones.dart';
import '../../../../core/widgets/campo_texto.dart';
import '../../../../core/widgets/estructura.dart';
import '../../application/auth_controller.dart';
import 'registro_screen.dart' show ayudaPassword;

/// Pantalla 06 · Cambiar contraseña.
/// - [temporal] = true (RN-07): obligatoria, sin flecha atrás ni barra, con el aviso naranja; bloquea hasta completar.
/// - [temporal] = false: cambio voluntario desde el panel lateral (misma pantalla, sin el aviso).
/// Tras cambiarla el backend invalida los tokens y la app vuelve a iniciar sesión sola.
class CambioPasswordForzadoScreen extends ConsumerStatefulWidget {
  const CambioPasswordForzadoScreen({super.key, this.temporal = true});

  final bool temporal;

  @override
  ConsumerState<CambioPasswordForzadoScreen> createState() => _CambioPasswordForzadoScreenState();
}

class _CambioPasswordForzadoScreenState extends ConsumerState<CambioPasswordForzadoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmar = TextEditingController();
  bool _cargando = false;
  AppException? _error;

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _cambiar() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await ref.read(authControllerProvider.notifier).cambiarPassword(
            oldPassword: _actual.text,
            newPassword: _nueva.text,
          );
      if (mounted && !widget.temporal) {
        avisar(context, 'Contraseña actualizada.');
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _error;
    final errActual = e?.campo('old_password');
    final errNueva = e?.campo('new_password');
    final general = e != null && errActual == null && errNueva == null ? e.mensaje : null;
    final contenido = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(StreakSize.screenPadding, 12, StreakSize.screenPadding, 24),
        children: [
          if (widget.temporal) ...[
            const BannerAviso(
              key: ValueKey('aviso-temporal'),
              texto: 'Entraste con una contraseña temporal. Debes cambiarla para continuar.',
            ),
            const SizedBox(height: 22),
          ],
          if (general != null) ...[BannerAviso(texto: general), const SizedBox(height: 16)],
          CampoTexto(
            etiqueta: 'Contraseña actual',
            controller: _actual,
            contrasena: true,
            errorServidor: errActual,
            autofillHints: const [AutofillHints.password],
            validator: (v) => (v == null || v.isEmpty) ? 'Escribe tu contraseña actual' : null,
          ),
          const SizedBox(height: 16),
          CampoTexto(
            etiqueta: 'Nueva contraseña',
            controller: _nueva,
            contrasena: true,
            ayuda: ayudaPassword,
            errorServidor: errNueva,
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
          BotonPrimario(texto: 'Cambiar contraseña', cargando: _cargando, onPressed: _cambiar),
        ],
      ),
    );
    return PopScope(
      canPop: !widget.temporal,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.temporal,
          titleSpacing: widget.temporal ? StreakSize.screenPadding - 4 : 4,
          title: Text(widget.temporal ? 'Cambia tu contraseña' : 'Cambiar contraseña'),
        ),
        body: SafeArea(child: contenido),
      ),
    );
  }
}
