import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../domain/quiniela_vista.dart';
import '../../domain/reglas.dart';

export '../../../../core/widgets/estructura.dart' show BannerAviso;

/// Fecha y hora local (RN-70: el backend envía UTC).
String fechaLocal(DateTime utc) => DateFormat("EEE d MMM · HH:mm", 'es').format(utc.toLocal());

String horaLocal(DateTime utc) => DateFormat('HH:mm').format(utc.toLocal());

/// "Aguilas 2 - 1 Lobos" sin marcador cuando no lo hay.
String textoMarcador(Marcador? m) => m == null ? '– –' : '${m.local} - ${m.visita}';

/// Agrupa partidos por fase, en el orden de la fase.
List<(Fase?, List<Partido>)> agruparPorFase(QuinielaVista v, List<Partido> partidos) {
  final porFase = <int, List<Partido>>{};
  for (final p in partidos) {
    porFase.putIfAbsent(p.faseId, () => []).add(p);
  }
  final ids = porFase.keys.toList()
    ..sort((a, b) => (v.fases[a]?.orden ?? 0).compareTo(v.fases[b]?.orden ?? 0));
  return [for (final id in ids) (v.fases[id], porFase[id]!)];
}

class EncabezadoFase extends StatelessWidget {
  const EncabezadoFase(this.fase, {super.key});

  final Fase? fase;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        (fase?.nombre ?? 'Partidos').toUpperCase(),
        style: const TextStyle(
          color: StreakColors.cream,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Estado de error con botón de reintentar.
class ErrorReintentar extends StatelessWidget {
  const ErrorReintentar({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final sinRed = error is AppException &&
        ((error as AppException).codigo == 'NETWORK_ERROR' || (error as AppException).codigo == 'TIMEOUT_ERROR');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(sinRed ? Icons.wifi_off : Icons.error_outline, size: 56, color: StreakColors.muted),
            const SizedBox(height: 16),
            Text(
              error is AppException ? (error as AppException).mensaje : 'No se pudo cargar la información.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: StreakColors.text),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('REINTENTAR')),
          ],
        ),
      ),
    );
  }
}

/// Mensaje vacío que además permite "tirar para refrescar".
class ListaVacia extends StatelessWidget {
  const ListaVacia({super.key, required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Icon(icono, size: 56, color: StreakColors.muted),
        const SizedBox(height: 16),
        Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: StreakColors.text)),
      ],
    );
  }
}

/// Etiqueta de puntos de un partido resuelto (Exacto 5 / Diferencia 4 / Resultado 3 / Fallo 0).
class EtiquetaPuntosChip extends StatelessWidget {
  const EtiquetaPuntosChip(this.partido, {super.key});

  final Partido partido;

  @override
  Widget build(BuildContext context) {
    final noCuenta = partido.estado == 'SUSPENDIDO' || partido.estado == 'CANCELADO';
    final color = noCuenta || partido.pronostico == null
        ? StreakColors.text
        : switch (partido.puntos) {
            5 => StreakColors.accent,
            4 => StreakColors.brand,
            3 => StreakColors.orange,
            _ => StreakColors.orangeText,
          };
    final texto = etiquetaPuntos(
      estado: partido.estado,
      tienePronostico: partido.pronostico != null,
      puntos: partido.puntos,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(texto, style: const TextStyle(color: StreakColors.text, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

/// Texto del estado de un partido ya resuelto o en juego.
String textoEstado(Partido p) {
  switch (p.estado) {
    case 'EN_JUEGO':
      return 'En juego';
    case 'SUSPENDIDO':
      return 'Suspendido';
    case 'CANCELADO':
      return 'Cancelado';
    case 'FINALIZADO':
      return 'Finalizado';
    default:
      return 'Programado';
  }
}
