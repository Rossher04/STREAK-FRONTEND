import 'package:flutter/material.dart';

import '../theme/streak_theme.dart';

/// Iniciales para el respaldo de avatar y escudo: "Ana Morales" → "AM", "ana_m" → "A".
String iniciales(String nombre, {int maximo = 2}) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  return partes.take(maximo).map((p) => p.characters.first.toUpperCase()).join();
}

/// Círculo con imagen de red que, si falla (404, sin red…), muestra las iniciales en vez de un error visual.
class _CirculoConRespaldo extends StatelessWidget {
  const _CirculoConRespaldo({
    required this.texto,
    required this.url,
    required this.diametro,
    required this.fondo,
    required this.borde,
    required this.estilo,
  });

  final String texto;
  final String? url;
  final double diametro;
  final Color fondo;
  final Color borde;
  final TextStyle estilo;

  @override
  Widget build(BuildContext context) {
    final respaldo = Center(child: Text(texto, style: estilo, maxLines: 1));
    final u = url;
    return Container(
      width: diametro,
      height: diametro,
      decoration: BoxDecoration(color: fondo, shape: BoxShape.circle, border: Border.all(color: borde)),
      child: ClipOval(
        child: u == null || u.isEmpty
            ? respaldo
            : Image.network(
                u,
                width: diametro,
                height: diametro,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => respaldo,
                loadingBuilder: (_, hijo, progreso) => progreso == null ? hijo : respaldo,
              ),
      ),
    );
  }
}

/// Avatar de usuario: foto del backend o iniciales sobre el azul de marca.
class AvatarUsuario extends StatelessWidget {
  const AvatarUsuario({super.key, required this.nombre, this.fotoUrl, this.diametro = StreakSize.avatar});

  final String nombre;
  final String? fotoUrl;
  final double diametro;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: _CirculoConRespaldo(
        texto: iniciales(nombre),
        url: fotoUrl,
        diametro: diametro,
        fondo: StreakColors.brand,
        borde: StreakColors.brandBorder,
        estilo: StreakText.iniciales(diametro),
      ),
    );
  }
}

/// Escudo de equipo: imagen del backend o círculo con la inicial (nunca escudos de clubes reales).
class EscudoEquipo extends StatelessWidget {
  const EscudoEquipo({super.key, required this.nombre, this.escudoUrl, this.diametro = StreakSize.escudo});

  final String nombre;
  final String? escudoUrl;
  final double diametro;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: _CirculoConRespaldo(
        texto: iniciales(nombre, maximo: 1),
        url: escudoUrl,
        diametro: diametro,
        fondo: StreakColors.surface2,
        borde: StreakColors.line,
        estilo: StreakText.iniciales(diametro, color: StreakColors.cream),
      ),
    );
  }
}
