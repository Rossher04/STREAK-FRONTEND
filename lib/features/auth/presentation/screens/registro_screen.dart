import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/utils/password_rules.dart';
import '../../application/auth_controller.dart';

class RegistroScreen extends ConsumerStatefulWidget {
  const RegistroScreen({super.key});

  @override
  ConsumerState<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends ConsumerState<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).register(
            username: _username.text,
            email: _email.text,
            password: _password.text,
            firstName: _first.text,
            lastName: _last.text,
            telefono: _phone.text,
          );
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Text(
                  'El usuario no se podrá cambiar después (RN-09).',
                  style: TextStyle(color: StreakColors.text),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(labelText: 'Usuario'),
                  validator: (v) => (v == null || v.trim().length < 3) ? 'Mínimo 3 caracteres' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo'),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Correo inválido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _first,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _last,
                  decoration: const InputDecoration(labelText: 'Apellidos'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                  validator: PasswordRules.validate,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
                  validator: (v) => v != _password.text ? 'Las contraseñas no coinciden' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: Text(_loading ? 'CREANDO…' : 'CREAR CUENTA'),
                ),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Ya tengo cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
