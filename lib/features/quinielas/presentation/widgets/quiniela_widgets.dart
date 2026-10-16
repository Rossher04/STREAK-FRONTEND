import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/avatar_usuario.dart';
import '../../../../core/widgets/botones.dart';
import '../../../../core/widgets/chips.dart';
import '../../../../core/widgets/estructura.dart';
import '../../../../core/widgets/streak_icon.dart';
import '../../domain/quiniela_vista.dart';
import '../../domain/reglas.dart';

export '../../../../core/widgets/estructura.dart' show BannerAviso;

const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// "Sáb 14 jun" en hora local (RN-70: el backend envía UTC).
String diaLocal(DateTime utc) {
  final l = utc.toLocal();
  return '${_dias[l.weekday - 1]} ${l.day} ${_meses[l.month - 1]}';
}

/// "Sáb 14 jun · 18:00" en hora local.
String fechaLocal(DateTime utc) => '${diaLocal(utc)} · ${horaLocal(utc)}';

String horaLocal(DateTime utc) => DateFormat('HH:mm').format(utc.toLocal());

/// "3 – 1"; "– –" cuando no hay marcador.
String textoMarcador(Marcador? m) => m == null ? '– –' : '${m.local} – ${m.visita}';

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

/// Aviso de fase eliminatoria (RN-23).
const avisoNoventa = 'Cuenta el tiempo reglamentario (90 min)';

/// Título de fase ("Semifinales") con el aviso de 90 min a la derecha si es eliminatoria.
class EncabezadoFase extends StatelessWidget {
  const EncabezadoFase(this.fase, {super.key, this.eliminatoria = false});

  final Fase? fase;
  final bool eliminatoria;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(fase?.nombre ?? 'Partidos', style: StreakText.cuerpoMedio.copyWith(fontWeight: FontWeight.w600)),
          ),
          if (eliminatoria) ...[
            const SizedBox(width: 12),
            Expanded(child: Text(avisoNoventa, textAlign: TextAlign.right, style: StreakText.pequeno)),
          ],
        ],
      ),
    );
  }
}

/// Escudo (o inicial) con el nombre del equipo debajo.
class EquipoColumna extends StatelessWidget {
  const EquipoColumna({super.key, required this.nombre, this.escudo});

  final String nombre;
  final String? escudo;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EscudoEquipo(nombre: nombre, escudoUrl: escudo),
        const SizedBox(height: 6),
        Text(nombre,
            textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: StreakText.cuerpo),
      ],
    );
  }
}

/// Chip de puntos de un partido resuelto: +5 borde amarillo, +4/+3 neutro, 0 borde `line`;
/// suspendido o cancelado "0 pts · no cuenta". Los puntos son los del backend.
class ChipPuntosPartido extends StatelessWidget {
  const ChipPuntosPartido({super.key, required this.estado, required this.puntos});

  final String estado;
  final int puntos;

  @override
  Widget build(BuildContext context) {
    if (estado == 'SUSPENDIDO' || estado == 'CANCELADO') {
      return const ChipStreak('0 pts · no cuenta', variante: VarianteChip.contorno);
    }
    if (estado != 'FINALIZADO') return const SizedBox.shrink();
    return Semantics(label: '$puntos puntos', excludeSemantics: true, child: ChipStreak.puntos(puntos));
  }
}

/// Nombre de usuario con corona si es PRO y "(tú)" si es el usuario actual (una sola vez).
class NombreParticipante extends StatelessWidget {
  const NombreParticipante({super.key, required this.nombre, this.esPro = false, this.esYo = false, this.estilo});

  final String nombre;
  final bool esPro;
  final bool esYo;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: estilo ?? StreakText.cuerpo),
        ),
        if (esPro) ...[
          const SizedBox(width: 6),
          const StreakIcon(StreakIcons.crownPro, color: StreakColors.accent, size: StreakSize.iconChip, semanticLabel: 'PRO'),
        ],
        if (esYo) ...[
          const SizedBox(width: 6),
          Text('(tú)', style: StreakText.pequeno),
        ],
      ],
    );
  }
}

bool esSinConexion(Object error) =>
    error is AppException && (error.codigo == 'NETWORK_ERROR' || error.codigo == 'TIMEOUT_ERROR');

/// Error de carga o sin conexión con "Reintentar" (botón secundario).
class ErrorReintentar extends StatelessWidget {
  const ErrorReintentar({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final sinRed = esSinConexion(error);
    return EstadoError(
      sinConexion: sinRed,
      mensaje: sinRed
          ? 'Revisa tu conexión: no hay una copia guardada de estos datos.'
          : error is AppException
              ? (error as AppException).mensaje
              : 'No se pudo cargar la información.',
      onReintentar: onRetry,
    );
  }
}

/// Esqueleto de carga (tarjetas `surface1`).
class CargandoTarjetas extends StatelessWidget {
  const CargandoTarjetas({super.key, this.cantidad = 3, this.alto = 124});

  final int cantidad;
  final double alto;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(StreakSize.screenPadding),
        children: [EsqueletoTarjetas(cantidad: cantidad, alto: alto)],
      );
}

/// Mensaje vacío dentro de una lista (sin ilustración).
class MensajeVacio extends StatelessWidget {
  const MensajeVacio(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
        child: Text(texto, textAlign: TextAlign.center, style: StreakText.secundario),
      );
}

/// Texto del estado de un partido.
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

/// Hoja ⓘ con el sistema de puntaje (lo que calcula el backend) y RN-23 / RN-37.
Future<void> mostrarSistemaPuntaje(BuildContext context) {
  Widget fila(String puntos, String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 44, child: Text(puntos, style: StreakText.cifraFila.copyWith(color: StreakColors.accent))),
            Expanded(child: Text(texto, style: StreakText.cuerpoMedio)),
          ],
        ),
      );
  return mostrarHoja<void>(
    context,
    titulo: 'Sistema de puntaje',
    texto: 'Puntos por partido según tu pronóstico del marcador.',
    contenido: (ctx) => [
      fila('5', 'Marcador exacto.'),
      fila('4', 'Aciertas el resultado y la misma diferencia de goles. Un empate no exacto también vale 4.'),
      fila('3', 'Solo aciertas el resultado (quién gana).'),
      fila('0', 'Fallo o sin pronóstico.'),
      fila('0', 'Partido suspendido o cancelado: vale 0 para todos y no cuenta.'),
      const SizedBox(height: 4),
      const BannerAviso(
        neutro: true,
        icono: StreakIcons.timer,
        texto: 'En fases eliminatorias solo cuenta el tiempo reglamentario (90 min): la prórroga y los '
            'penales no se suman. Los pronósticos cierran $minutosCierre minutos antes del inicio.',
      ),
      const SizedBox(height: 16),
      BotonSecundario(texto: 'Entendido', onPressed: () => Navigator.of(ctx).pop()),
    ],
  );
}
