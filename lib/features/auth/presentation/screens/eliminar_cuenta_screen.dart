import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/botones.dart';
import '../../../../core/widgets/campo_texto.dart';
import '../../../../core/widgets/estructura.dart';
import '../../application/auth_controller.dart';

/// Ruta de la pantalla 11 (se abre desde el panel lateral y desde el perfil).
const rutaEliminarCuenta = '/eliminar-cuenta';

/// URL web pública para solicitar la eliminación sin la app (ficha de Google Play).
const urlWebEliminarCuenta = 'https://streak-api-6cl2.onrender.com/eliminar-cuenta/';

const textoAdvertenciaEliminar =
    'Se borrarán tu perfil, tu foto, tus pronósticos y tus participaciones. No se puede deshacer.';

/// Pantalla 11 · Eliminar cuenta: advertencia, contraseña actual y doble confirmación.
/// DELETE /usuarios/me/ → 400 marca el campo; 204 borra todo lo local y vuelve al login.
class EliminarCuentaScreen extends ConsumerStatefulWidget {
  const EliminarCuentaScreen({super.key});

  @override
  ConsumerState<EliminarCuentaScreen> createState() => _EliminarCuentaScreenState();
}

class _EliminarCuentaScreenState extends ConsumerState<EliminarCuentaScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  String? _errorPassword;
  String? _errorGeneral;
  bool _enviando = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _solicitar() async {
    setState(() {
      _errorPassword = null;
      _errorGeneral = null;
    });
    if (!(_form.currentState?.validate() ?? false)) return;
    final confirmado = await mostrarDialogo<bool>(
      context,
      titulo: '¿Eliminar tu cuenta definitivamente?',
      texto: 'Esta acción es permanente. Perderás tus pronósticos, tus puntos y tu historial.',
      contenido: (ctx) => [
        BotonDestructivo(
          key: const ValueKey('confirmar-eliminar'),
          texto: 'Sí, eliminar mi cuenta',
          onPressed: () => Navigator.pop(ctx, true),
        ),
        const SizedBox(height: 12),
        BotonSecundario(texto: 'Cancelar', onPressed: () => Navigator.pop(ctx, false)),
      ],
    );
    if (confirmado != true || !mounted) return;
    setState(() => _enviando = true);
    try {
      // Tras el 204 la sesión pasa a "sin sesión" y el router lleva al login con el mensaje.
      await ref.read(authControllerProvider.notifier).eliminarCuenta(_password.text);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.codigo == 'CREDENCIALES_INVALIDAS' || e.codigo == 'PASSWORD_REQUERIDO' || e.codigo == 'DATOS_INVALIDOS') {
          _errorPassword = e.codigo == 'CREDENCIALES_INVALIDAS' ? 'La contraseña no es correcta.' : e.mensaje;
        } else {
          _errorGeneral = e.mensaje;
        }
      });
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eliminar cuenta')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(StreakSize.screenPadding, 16, StreakSize.screenPadding, 24),
            children: [
              const BannerAviso(key: ValueKey('advertencia'), texto: textoAdvertenciaEliminar),
              const SizedBox(height: 16),
              Text(
                'Las quinielas que creaste seguirán para sus participantes, sin creador. '
                'Los registros de pago se conservan sin tus datos personales (importe, fecha y referencia). '
                'Eliminar la cuenta no reembolsa ni cancela un pago en proceso.',
                style: StreakText.secundario,
              ),
              const SizedBox(height: 20),
              CampoTexto(
                campoKey: const ValueKey('campo-password'),
                etiqueta: 'Contraseña',
                controller: _password,
                contrasena: true,
                errorServidor: _errorPassword,
                autofillHints: const [AutofillHints.password],
                validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña actual.' : null,
                onChanged: (_) {
                  if (_errorPassword != null) setState(() => _errorPassword = null);
                },
              ),
              if (_errorGeneral != null) ...[
                const SizedBox(height: 12),
                Text(_errorGeneral!, key: const ValueKey('error-general'), style: StreakText.error),
              ],
              const SizedBox(height: 24),
              BotonDestructivo(
                key: const ValueKey('boton-eliminar'),
                texto: 'Eliminar mi cuenta',
                cargando: _enviando,
                onPressed: _solicitar,
              ),
              const SizedBox(height: 12),
              BotonSecundario(
                texto: 'Cancelar',
                onPressed: _enviando ? null : () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
