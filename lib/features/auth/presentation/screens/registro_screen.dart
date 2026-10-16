import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/utils/fecha_nacimiento.dart';
import '../../../../core/utils/password_rules.dart';
import '../../../../core/widgets/botones.dart';
import '../../../../core/widgets/campo_texto.dart';
import '../../../../core/widgets/estructura.dart';
import '../../application/auth_controller.dart';
import '../widgets/campo_fecha_nacimiento.dart';
import '../widgets/textos_legales.dart';

/// Texto de ayuda de la contraseña (RN-03), igual en registro, restablecer y cambio.
const ayudaPassword = 'Mínimo 8 caracteres, con una letra y un número';

/// Validación local de correo (el backend valida de nuevo).
String? validarCorreo(String? v) {
  final t = v?.trim() ?? '';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'Escribe un correo válido';
  return null;
}

/// Pantalla 02 · Registro.
class RegistroScreen extends ConsumerStatefulWidget {
  const RegistroScreen({super.key});

  @override
  ConsumerState<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends ConsumerState<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _correo = TextEditingController();
  final _nombre = TextEditingController();
  final _apellidos = TextEditingController();
  final _telefono = TextEditingController();
  final _fecha = TextEditingController();
  final _password = TextEditingController();
  bool _acepta = false;
  bool _faltaAceptar = false;
  bool _cargando = false;
  AppException? _error;

  @override
  void dispose() {
    for (final c in [_usuario, _correo, _nombre, _apellidos, _telefono, _fecha, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _crear() async {
    setState(() {
      _error = null;
      _faltaAceptar = !_acepta;
    });
    final valido = _formKey.currentState!.validate();
    if (!valido || !_acepta) return;
    setState(() => _cargando = true);
    try {
      await ref.read(authControllerProvider.notifier).register(
            username: _usuario.text,
            email: _correo.text,
            password: _password.text,
            firstName: _nombre.text,
            lastName: _apellidos.text,
            telefono: _telefono.text,
            fechaNacimiento: FechaNacimiento.parseVista(_fecha.text),
          );
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _error;
    final conocidos = {'username', 'email', 'first_name', 'last_name', 'telefono', 'fecha_nacimiento', 'password'};
    final general = e != null && !e.campos.keys.any(conocidos.contains) ? e.mensaje : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(StreakSize.screenPadding, 8, StreakSize.screenPadding, 24),
            children: [
              if (general != null) ...[BannerAviso(texto: general), const SizedBox(height: 16)],
              CampoTexto(
                etiqueta: 'Usuario',
                hint: 'mi_usuario',
                controller: _usuario,
                errorServidor: e?.campo('username'),
                autofillHints: const [AutofillHints.newUsername],
                validator: (v) => (v == null || v.trim().length < 3) ? 'Mínimo 3 caracteres' : null,
              ),
              const SizedBox(height: 16),
              CampoTexto(
                etiqueta: 'Correo electrónico',
                hint: 'nombre@correo.com',
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                errorServidor: e?.campo('email'),
                autofillHints: const [AutofillHints.email],
                validator: validarCorreo,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CampoTexto(
                      etiqueta: 'Nombre',
                      controller: _nombre,
                      errorServidor: e?.campo('first_name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CampoTexto(
                      etiqueta: 'Apellidos',
                      controller: _apellidos,
                      errorServidor: e?.campo('last_name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CampoTexto(
                etiqueta: 'Teléfono',
                controller: _telefono,
                keyboardType: TextInputType.phone,
                errorServidor: e?.campo('telefono'),
              ),
              const SizedBox(height: 16),
              CampoFechaNacimiento(controller: _fecha, errorServidor: e?.campo('fecha_nacimiento')),
              const SizedBox(height: 16),
              CampoTexto(
                etiqueta: 'Contraseña',
                controller: _password,
                contrasena: true,
                ayuda: ayudaPassword,
                errorServidor: e?.campo('password'),
                autofillHints: const [AutofillHints.newPassword],
                validator: PasswordRules.validate,
              ),
              const SizedBox(height: 14),
              _CasillaTerminos(
                valor: _acepta,
                error: _faltaAceptar,
                onCambio: (v) => setState(() {
                  _acepta = v;
                  if (v) _faltaAceptar = false;
                }),
              ),
              const SizedBox(height: 18),
              BotonPrimario(texto: 'Crear cuenta', cargando: _cargando, onPressed: _crear),
            ],
          ),
        ),
      ),
    );
  }
}

class _CasillaTerminos extends StatelessWidget {
  const _CasillaTerminos({required this.valor, required this.error, required this.onCambio});

  final bool valor;
  final bool error;
  final ValueChanged<bool> onCambio;

  @override
  Widget build(BuildContext context) {
    final enlace = StreakText.pequeno.copyWith(
      color: StreakColors.text,
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.underline,
      decorationColor: StreakColors.text,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: valor,
              onChanged: (v) => onCambio(v ?? false),
              side: BorderSide(color: error ? StreakColors.orangeText : StreakColors.line),
              semanticLabel: 'Acepto los términos y la política de privacidad',
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Acepto los ', style: StreakText.pequeno),
                  InkWell(onTap: () => mostrarTerminos(context), child: Text('términos', style: enlace)),
                  Text(' y la ', style: StreakText.pequeno),
                  InkWell(onTap: () => mostrarPrivacidad(context), child: Text('política de privacidad', style: enlace)),
                ],
              ),
            ),
          ],
        ),
        if (error)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text('Debes aceptar los términos para crear la cuenta', style: StreakText.error),
          ),
      ],
    );
  }
}
