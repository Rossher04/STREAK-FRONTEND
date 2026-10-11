import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/auth_controller.dart';

class RecuperarPasswordScreen extends ConsumerStatefulWidget {
  const RecuperarPasswordScreen({super.key});

  @override
  ConsumerState<RecuperarPasswordScreen> createState() =>
      _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState extends ConsumerState<RecuperarPasswordScreen> {
  final _email = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _mensaje; // respuesta del backend tras enviar

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final mensaje = await ref.read(authControllerProvider.notifier).recuperar(_email.text);
      if (mounted) setState(() => _mensaje = mensaje);
    } on AppException catch (e) {
      if (mounted) {
        final sinCorreo = e.codigo == 'CORREO_NO_CONFIGURADO';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(sinCorreo
              ? '${e.mensaje} El envío de correos aún no está configurado en el servidor; inténtalo más tarde.'
              : e.mensaje),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _mensaje != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mark_email_read_outlined, size: 64, color: AppColors.sportsOrange),
                  const SizedBox(height: 16),
                  Text(_mensaje!, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text(
                    'Abre el enlace del correo (vale una hora) para elegir una contraseña nueva.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('VOLVER AL LOGIN'),
                  ),
                ],
              )
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text(
                      'Ingresa el correo con el que te registraste.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Correo'),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Correo inválido' : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: Text(_loading ? 'ENVIANDO…' : 'ENVIAR INSTRUCCIONES'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
