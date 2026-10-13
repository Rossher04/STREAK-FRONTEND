import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/botones.dart';
import '../../../../core/widgets/campo_texto.dart';
import '../../../../core/widgets/estructura.dart';
import '../../../../core/widgets/streak_icon.dart';
import '../../application/auth_controller.dart';
import 'registro_screen.dart' show validarCorreo;

/// Pantalla 03 · Recuperar contraseña (el texto vive en [AppConstants.textoRecuperarPassword]).
class RecuperarPasswordScreen extends ConsumerStatefulWidget {
  const RecuperarPasswordScreen({super.key});

  @override
  ConsumerState<RecuperarPasswordScreen> createState() => _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState extends ConsumerState<RecuperarPasswordScreen> {
  final _correo = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _cargando = false;
  bool _enviado = false;
  AppException? _error;

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await ref.read(authControllerProvider.notifier).recuperar(_correo.text);
      if (mounted) setState(() => _enviado = true);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _error;
    final mensajeGeneral = e == null || e.campo('email') != null
        ? null
        : e.codigo == 'CORREO_NO_CONFIGURADO'
            ? 'La recuperación por correo no está disponible por ahora. Inténtalo más tarde.'
            : e.mensaje;
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(StreakSize.screenPadding, 12, StreakSize.screenPadding, 24),
          children: _enviado
              ? [
                  const BannerAviso(texto: AppConstants.textoRecuperarEnviado, icono: StreakIcons.mail, neutro: true),
                  const SizedBox(height: 24),
                  BotonPrimario(texto: 'Volver a iniciar sesión', onPressed: () => context.go('/login')),
                ]
              : [
                  Text(AppConstants.textoRecuperarPassword, style: StreakText.secundario),
                  const SizedBox(height: 22),
                  if (mensajeGeneral != null) ...[BannerAviso(texto: mensajeGeneral), const SizedBox(height: 16)],
                  Form(
                    key: _formKey,
                    child: CampoTexto(
                      etiqueta: 'Correo electrónico',
                      hint: 'nombre@correo.com',
                      controller: _correo,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      errorServidor: e?.campo('email'),
                      validator: (v) =>
                          validarCorreo(v) == null ? null : 'Escribe un correo válido, por ejemplo nombre@correo.com',
                      onSubmitted: (_) => _enviar(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  BotonPrimario(texto: 'Enviar instrucciones', cargando: _cargando, onPressed: _enviar),
                ],
        ),
      ),
    );
  }
}
