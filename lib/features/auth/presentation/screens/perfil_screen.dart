import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/avatar_usuario.dart';
import '../../../../core/widgets/botones.dart';
import '../../../../core/widgets/campo_texto.dart';
import '../../../../core/widgets/estructura.dart';
import '../../../../core/widgets/streak_icon.dart';
import '../../../quinielas/presentation/widgets/quiniela_widgets.dart' show horaLocal;
import '../../application/auth_controller.dart';
import '../../data/auth_repository.dart';
import '../widgets/eliminar_cuenta_dialogo.dart';

/// Pantalla 10 · Mi perfil (B2): datos reales de `GET /usuarios/me/`; se guardan con `PATCH` (multipart si hay foto).
/// El usuario es de solo lectura (RN-09). La fecha de nacimiento aún no existe en la API: TODO(backend #18).
class PerfilScreen extends ConsumerStatefulWidget {
  const PerfilScreen({super.key});

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen> {
  final _nombre = TextEditingController();
  final _apellidos = TextEditingController();
  final _telefono = TextEditingController();
  FotoPerfil? _fotoNueva;
  Uint8List? _vistaPrevia;
  bool _guardando = false;
  AppException? _error;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _nombre.text = user?.firstName ?? '';
    _apellidos.text = user?.lastName ?? '';
    _telefono.text = user?.telefono ?? '';
  }

  @override
  void dispose() {
    _nombre.dispose();
    _apellidos.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _elegirFoto() async {
    final origen = await mostrarHoja<ImageSource>(
      context,
      titulo: 'Foto de perfil',
      contenido: (ctx) => [
        BotonSecundario(
          texto: 'Tomar foto',
          icono: StreakIcons.camera,
          onPressed: () => Navigator.pop(ctx, ImageSource.camera),
        ),
        const SizedBox(height: 12),
        BotonSecundario(
          texto: 'Elegir de la galería',
          icono: StreakIcons.user,
          onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
        ),
      ],
    );
    if (origen == null) return;
    final XFile? archivo;
    try {
      archivo = await ImagePicker().pickImage(source: origen, imageQuality: 70, maxWidth: 1024);
    } on Object {
      if (mounted) avisar(context, 'No se pudo abrir la ${origen == ImageSource.camera ? 'cámara' : 'galería'}.');
      return;
    }
    if (archivo == null) return;
    final bytes = await archivo.readAsBytes();
    setState(() {
      _fotoNueva = FotoPerfil(bytes: bytes, nombre: archivo!.name);
      _vistaPrevia = bytes;
    });
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).actualizarPerfil(
            firstName: _nombre.text.trim(),
            lastName: _apellidos.text.trim(),
            telefono: _telefono.text.trim(),
            foto: _fotoNueva,
          );
      _fotoNueva = null;
      if (mounted) avisar(context, 'Perfil actualizado.');
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(authControllerProvider);
    final user = sesion.user;
    final offlineDesde = sesion.offlineDesde;
    final e = _error;
    final conocidos = {'first_name', 'last_name', 'telefono', 'foto'};
    final general = e != null && !e.campos.keys.any(conocidos.contains) ? e.mensaje : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(StreakSize.screenPadding, 8, StreakSize.screenPadding, 24),
          children: [
            if (offlineDesde != null) ...[
              BannerAviso(icono: StreakIcons.retry, texto: 'Sin conexión · datos de ${horaLocal(offlineDesde)}'),
              const SizedBox(height: 16),
            ],
            Center(
              child: _FotoPerfil(
                vistaPrevia: _vistaPrevia,
                fotoUrl: user?.fotoUrl,
                nombre: user?.displayName ?? '',
                onTap: offlineDesde != null ? null : _elegirFoto,
              ),
            ),
            if (e?.campo('foto') != null) ...[
              const SizedBox(height: 8),
              Text(e!.campo('foto')!, textAlign: TextAlign.center, style: StreakText.error),
            ],
            const SizedBox(height: 22),
            if (general != null) ...[BannerAviso(texto: general), const SizedBox(height: 16)],
            CampoTexto(
              key: ValueKey('usuario-${user?.username}'),
              etiqueta: 'Usuario',
              initialValue: user?.username ?? '',
              soloLectura: true,
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
            // TODO(backend #18): la API no tiene fecha_nacimiento; se muestra deshabilitada y no se envía.
            const CampoTexto(
              etiqueta: 'Fecha de nacimiento',
              hint: 'dd/mm/aaaa',
              habilitado: false,
              sufijo: StreakIcons.calendar,
              ayuda: 'Aún no disponible',
            ),
            const SizedBox(height: 24),
            BotonPrimario(
              texto: offlineDesde != null ? 'Sin conexión' : 'Guardar cambios',
              cargando: _guardando,
              onPressed: offlineDesde != null ? null : _guardar,
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => mostrarEliminarCuenta(context),
                child: Text('Eliminar mi cuenta', style: StreakText.enlace.copyWith(color: StreakColors.orangeText)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Foto de 92 px con la insignia de cámara; sin foto muestra el ícono de usuario (o las iniciales si la imagen falla).
class _FotoPerfil extends StatelessWidget {
  const _FotoPerfil({required this.vistaPrevia, required this.fotoUrl, required this.nombre, required this.onTap});

  final Uint8List? vistaPrevia;
  final String? fotoUrl;
  final String nombre;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const lado = StreakSize.fotoPerfil;
    final Widget imagen;
    if (vistaPrevia != null) {
      imagen = ClipOval(child: Image.memory(vistaPrevia!, width: lado, height: lado, fit: BoxFit.cover));
    } else if (fotoUrl != null && fotoUrl!.isNotEmpty) {
      imagen = AvatarUsuario(nombre: nombre, fotoUrl: fotoUrl, diametro: lado);
    } else {
      imagen = Container(
        width: lado,
        height: lado,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: StreakColors.surface2,
          shape: BoxShape.circle,
          border: Border.all(color: StreakColors.line),
        ),
        child: const StreakIcon(StreakIcons.user, size: 40, color: StreakColors.muted),
      );
    }
    return Semantics(
      button: true,
      label: 'Cambiar foto de perfil',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: lado + 4,
          height: lado + 4,
          child: Stack(
            children: [
              imagen,
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: StreakColors.surface2,
                    shape: BoxShape.circle,
                    border: Border.all(color: StreakColors.bg, width: 2),
                  ),
                  child: const StreakIcon(StreakIcons.camera, size: StreakSize.iconChip, color: StreakColors.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
