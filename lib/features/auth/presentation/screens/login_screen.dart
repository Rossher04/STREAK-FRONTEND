import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/actividad_red.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/botones.dart';
import '../../../../core/widgets/campo_texto.dart';
import '../../../../core/widgets/estructura.dart';
import '../../../../core/widgets/marca.dart';
import '../../application/auth_controller.dart';

/// Pantalla 01 · Login.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _password = TextEditingController();
  bool _cargando = false;
  AppException? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await ref.read(authControllerProvider.notifier).login(_usuario.text, _password.text);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aviso = ref.watch(authControllerProvider).message;
    final e = _error;
    // Usuario/contraseña incorrectos van bajo la contraseña; los errores por campo, bajo su campo;
    // cualquier otro (red, servidor) en un aviso.
    final errorUsuario = e?.campo('username');
    final errorPassword =
        e?.campo('password') ?? (e?.codigo == 'CREDENCIALES_INVALIDAS' ? e!.mensaje : null);
    final errorGeneral = e != null && errorUsuario == null && errorPassword == null ? e.mensaje : null;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: StreakSize.screenPadding),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 48),
                      const MarcaStreak(),
                      const SizedBox(height: 44),
                      const AvisoServidorLento(),
                      if (aviso != null) ...[
                        BannerAviso(texto: aviso, neutro: true),
                        const SizedBox(height: 16),
                      ],
                      if (errorGeneral != null) ...[
                        BannerAviso(texto: errorGeneral),
                        const SizedBox(height: 16),
                      ],
                      CampoTexto(
                        etiqueta: 'Usuario',
                        hint: 'Tu usuario',
                        controller: _usuario,
                        errorServidor: errorUsuario,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe tu usuario' : null,
                      ),
                      const SizedBox(height: 16),
                      CampoTexto(
                        etiqueta: 'Contraseña',
                        hint: 'Tu contraseña',
                        controller: _password,
                        contrasena: true,
                        errorServidor: errorPassword,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _entrar(),
                        validator: (v) => (v == null || v.isEmpty) ? 'Escribe tu contraseña' : null,
                      ),
                      const SizedBox(height: 22),
                      BotonPrimario(texto: 'Iniciar sesión', cargando: _cargando, onPressed: _entrar),
                      const SizedBox(height: 8),
                      EnlaceTexto(texto: '¿Olvidaste tu contraseña?', onPressed: () => context.push('/recuperar')),
                      const Spacer(),
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          onPressed: () => context.push('/register'),
                          child: Text.rich(
                            TextSpan(
                              text: '¿No tienes cuenta? ',
                              style: StreakText.enlace,
                              children: [
                                TextSpan(
                                  text: 'Regístrate',
                                  style: StreakText.enlace.copyWith(
                                    color: StreakColors.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
