import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/auth_controller.dart';
import '../../data/auth_repository.dart';

/// B2: datos reales de /usuarios/me/. Usuario y correo son de solo lectura;
/// la contraseña no se toca desde aquí.
class PerfilScreen extends ConsumerStatefulWidget {
  const PerfilScreen({super.key});

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  FotoPerfil? _fotoNueva;
  Uint8List? _fotoPreview;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _first.text = user?.firstName ?? '';
    _last.text = user?.lastName ?? '';
    _phone.text = user?.telefono ?? '';
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _fotoNueva = FotoPerfil(bytes: bytes, nombre: file.name);
      _fotoPreview = bytes;
    });
  }

  Future<void> _save() async {
    setState(() => _guardando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authControllerProvider.notifier).actualizarPerfil(
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            telefono: _phone.text.trim(),
            foto: _fotoNueva,
          );
      _fotoNueva = null;
      messenger.showSnackBar(const SnackBar(content: Text('Perfil actualizado.')));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final fotoUrl = user?.fotoUrl;
    ImageProvider? imagen;
    if (_fotoPreview != null) {
      imagen = MemoryImage(_fotoPreview!);
    } else if (fotoUrl != null) {
      imagen = NetworkImage(fotoUrl);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.creamBackground,
                backgroundImage: imagen,
                child: imagen == null
                    ? const Icon(Icons.camera_alt, color: AppColors.primaryBlue, size: 32)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Toca para cambiar foto',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          TextFormField(
            key: ValueKey('username-${user?.username}'),
            initialValue: user?.username ?? '',
            enabled: false,
            decoration: const InputDecoration(labelText: 'Usuario (no editable)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('email-${user?.email}'),
            initialValue: user?.email ?? '',
            enabled: false,
            decoration: const InputDecoration(labelText: 'Correo (no editable)'),
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
            keyboardType: TextInputType.phone,
            maxLength: 20,
            decoration: const InputDecoration(labelText: 'Teléfono'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _guardando ? null : _save,
            child: Text(_guardando ? 'GUARDANDO…' : 'GUARDAR CAMBIOS'),
          ),
        ],
      ),
    );
  }
}
