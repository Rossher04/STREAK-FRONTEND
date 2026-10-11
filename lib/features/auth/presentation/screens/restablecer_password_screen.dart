import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/password_rules.dart';
import '../../application/auth_controller.dart';

/// Destino del enlace de recuperación: /restablecer/:uid/:token.
/// No se registra ni se muestra el token.
class RestablecerPasswordScreen extends ConsumerStatefulWidget {
  const RestablecerPasswordScreen({super.key, required this.uid, required this.token});

  final String uid;
  final String token;

  @override
  ConsumerState<RestablecerPasswordScreen> createState() => _RestablecerPasswordScreenState();
}

class _RestablecerPasswordScreenState extends ConsumerState<RestablecerPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nuevo = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nuevo.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final mensaje = await ref.read(authControllerProvider.notifier).restablecer(
            uid: widget.uid,
            token: widget.token,
            newPassword: _nuevo.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
      context.go('/login');
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restablecer contraseña')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Icon(Icons.lock_reset, size: 56, color: AppColors.primaryBlue),
                const SizedBox(height: 12),
                const Text(
                  'Elige tu nueva contraseña. Después iniciarás sesión con ella.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nuevo,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nueva contraseña'),
                  validator: PasswordRules.validate,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmar nueva contraseña'),
                  validator: (v) => v != _nuevo.text ? 'Las contraseñas no coinciden' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
                  TextButton(
                    onPressed: () => context.go('/recuperar'),
                    child: const Text('Pedir un enlace nuevo'),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: Text(_loading ? 'GUARDANDO…' : 'RESTABLECER CONTRASEÑA'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
