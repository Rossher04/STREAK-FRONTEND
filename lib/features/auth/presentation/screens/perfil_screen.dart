import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/auth_controller.dart';

class PerfilScreen extends ConsumerStatefulWidget {
  const PerfilScreen({super.key});

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  DateTime? _birth;
  String? _foto;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _first.text = user?.firstName ?? '';
    _last.text = user?.lastName ?? '';
    _phone.text = user?.telefono ?? '';
    _birth = user?.fechaNacimiento;
    _foto = user?.fotoPath;
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
    if (file != null) setState(() => _foto = file.path);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 18),
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (picked != null) setState(() => _birth = picked);
  }

  void _save() {
    final current = ref.read(authControllerProvider).user;
    if (current == null) return;
    ref.read(authControllerProvider.notifier).updateProfile(
          current.copyWith(
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            telefono: _phone.text.trim(),
            fechaNacimiento: _birth,
            fotoPath: _foto,
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil actualizado (usuario y contraseña no se tocan, RN-09).')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
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
                backgroundImage:
                    (!kIsWeb && _foto != null) ? FileImage(File(_foto!)) : null,
                child: _foto == null
                    ? const Icon(Icons.camera_alt, color: AppColors.primaryBlue, size: 32)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Toca para cambiar foto', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          TextFormField(
            initialValue: user?.username ?? '',
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Usuario (no editable)',
              helperText: 'RN-09: el nombre de usuario no se cambia desde el perfil',
            ),
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
            decoration: const InputDecoration(labelText: 'Teléfono'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fecha de nacimiento (RN-09)'),
            subtitle: Text(
              _birth == null ? 'Sin definir' : DateFormat('d MMMM yyyy', 'es').format(_birth!),
            ),
            trailing: const Icon(Icons.calendar_month, color: AppColors.primaryBlue),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          const Text(
            'La contraseña solo se cambia con la actual, no desde este formulario.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _save, child: const Text('GUARDAR CAMBIOS')),
        ],
      ),
    );
  }
}
