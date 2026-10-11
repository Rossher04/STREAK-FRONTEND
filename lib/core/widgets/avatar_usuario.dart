import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Avatar con foto de red que, si la imagen no carga (404, sin red...), muestra la inicial en vez de
/// un error visual. En producción las imágenes de /media/ hoy dan 404 (docs/backend_pendientes.md, punto 9).
class AvatarUsuario extends StatelessWidget {
  const AvatarUsuario({
    super.key,
    required this.nombre,
    this.fotoUrl,
    this.radio = 20,
    this.fondo = AppColors.creamBackground,
    this.colorTexto = AppColors.primaryBlue,
  });

  final String nombre;
  final String? fotoUrl;
  final double radio;
  final Color fondo;
  final Color colorTexto;

  @override
  Widget build(BuildContext context) {
    final inicial = Text(
      nombre.isEmpty ? '?' : nombre[0].toUpperCase(),
      style: TextStyle(color: colorTexto, fontWeight: FontWeight.bold, fontSize: radio * 0.9),
    );
    final url = fotoUrl;
    return CircleAvatar(
      radius: radio,
      backgroundColor: fondo,
      child: url == null || url.isEmpty
          ? inicial
          : ClipOval(
              child: Image.network(
                url,
                width: radio * 2,
                height: radio * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => inicial,
                loadingBuilder: (_, hijo, progreso) => progreso == null ? hijo : inicial,
              ),
            ),
    );
  }
}
