import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/password_rules.dart';
import '../../application/auth_controller.dart';

class CambioPasswordForzadoScreen extends ConsumerStatefulWidget {
  const CambioPasswordForzadoScreen({super.key});

  @override
  ConsumerState<CambioPasswordForzadoScreen> createState() =>
      _CambioPasswordForzadoScreenState();
}

class _CambioPasswordForzadoScreenState
    extends ConsumerState<CambioPasswordForzadoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _nuevo = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _old.dispose();
    _nuevo.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).cambiarPassword(
            oldPassword: _old.text,
            newPassword: _nuevo.text,
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
      appBar: AppBar(
        title: const Text('Actualización requerida'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Icon(Icons.security, size: 56, color: AppColors.error),
                const SizedBox(height: 12),
                const Text(
                  'Debes cambiar la contraseña temporal antes de cualquier otra operación (RN-07). Doble confirmación obligatoria.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _old,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña actual (temporal)'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerida' : null,
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: Text(_loading ? 'GUARDANDO…' : 'ACTUALIZAR CONTRASEÑA'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
