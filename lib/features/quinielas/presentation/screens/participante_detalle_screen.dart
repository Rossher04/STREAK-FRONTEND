import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/avatar_usuario.dart';
import '../../../../core/widgets/chips.dart';
import '../../../../core/widgets/estructura.dart';
import '../../../../core/widgets/streak_icon.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/quinielas_providers.dart';
import '../../domain/quiniela_vista.dart';
import '../../domain/reglas.dart';
import '../widgets/quiniela_widgets.dart';

/// Orden de la lista: primero los partidos ya jugados o en juego (el más reciente arriba) y después
/// los próximos (el más cercano arriba).
List<Partido> ordenarParaParticipante(List<Partido> partidos) {
  bool jugado(Partido p) => p.esResuelto || p.enJuego;
  final jugados = partidos.where(jugado).toList()..sort((a, b) => b.fechaHora.compareTo(a.fechaHora));
  final proximos = partidos.where((p) => !jugado(p)).toList()..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
  return [...jugados, ...proximos];
}

/// Detalle de participante (20): avatar, nombre de usuario (RN-10: nunca correo ni teléfono), puesto,
/// puntos y sus pronósticos (los de rivales en partidos no iniciados salen "Oculto", RN-39).
/// `usuarioId` es el id de USUARIO (no el de participante).
class ParticipanteDetalleScreen extends ConsumerWidget {
  const ParticipanteDetalleScreen({super.key, required this.quinielaId, required this.usuarioId});

  final int quinielaId;
  final int usuarioId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clave = (quinielaId: quinielaId, usuarioId: usuarioId);
    final detalle = ref.watch(participanteDetalleProvider(clave));
    final vista = ref.watch(quinielaVistaProvider(quinielaId)).valueOrNull;
    final yo = ref.watch(authControllerProvider.select((s) => s.user?.id));

    Future<void> refrescar() async {
      ref.invalidate(participanteDetalleProvider(clave));
      await ref.read(participanteDetalleProvider(clave).future).then((_) {}, onError: (_) {});
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Participante')),
      body: detalle.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const CargandoTarjetas(),
        error: (e, _) => ErrorReintentar(error: e, onRetry: () => ref.invalidate(participanteDetalleProvider(clave))),
        data: (d) {
          final puesto = vista?.filaDe(d.usuarioId)?.posicion;
          final partidos = ordenarParaParticipante(d.partidos);
          return RefreshIndicator(
            onRefresh: refrescar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(StreakSize.screenPadding, 8, StreakSize.screenPadding, 24),
              children: [
                TarjetaStreak(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      AvatarUsuario(nombre: d.username, fotoUrl: d.foto, diametro: StreakSize.avatarGrande),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            NombreParticipante(
                                nombre: d.username, esPro: d.esPro, esYo: d.usuarioId == yo, estilo: StreakText.tituloGrande),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                DatoCifra(etiqueta: 'Puesto', valor: puesto == null ? '—' : etiquetaPuesto(puesto)),
                                const SizedBox(width: 28),
                                DatoCifra(etiqueta: 'Puntos', valor: '${d.puntosTotales}', puntos: true),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const EncabezadoSeccion('Pronósticos'),
                if (partidos.isEmpty) const MensajeVacio('El torneo aún no tiene partidos.'),
                for (final p in partidos)
                  _TarjetaPronostico(
                    partido: p,
                    vista: vista,
                    onTap: () => context.push('/quinielas/$quinielaId/partido/${p.id}'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TarjetaPronostico extends StatelessWidget {
  const _TarjetaPronostico({required this.partido, required this.vista, required this.onTap});

  final Partido partido;
  final QuinielaVista? vista;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = partido;
    final local = p.equipoLocal?.nombre ?? vista?.nombreEquipo(p.equipoLocalId) ?? 'Local';
    final visita = p.equipoVisita?.nombre ?? vista?.nombreEquipo(p.equipoVisitaId) ?? 'Visita';
    final oculto = p.estadoPronostico == EstadoPronostico.oculto;
    final String detalle;
    if (oculto) {
      detalle = 'Se mostrará cuando empiece el partido.';
    } else if (p.estado == 'FINALIZADO' && p.resultado != null) {
      detalle = 'Resultado ${textoMarcador(p.resultado)}';
    } else if (p.esResuelto || p.enJuego) {
      detalle = textoEstado(p);
    } else {
      detalle = fechaLocal(p.fechaHora);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TarjetaStreak(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('$local – $visita', style: StreakText.cuerpoMedio.copyWith(color: StreakColors.muted))),
                if (oculto)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const StreakIcon(StreakIcons.lock, size: StreakSize.iconSmall),
                      const SizedBox(width: 6),
                      Text('Oculto', style: StreakText.cuerpoMedio.copyWith(color: StreakColors.muted)),
                    ],
                  )
                else if (p.esResuelto)
                  ChipPuntosPartido(estado: p.estado, puntos: p.puntos)
                else if (p.enJuego)
                  const ChipStreak('En juego', variante: VarianteChip.live),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text(detalle, style: StreakText.pequeno)),
                if (!oculto)
                  Text(
                    p.estadoPronostico == EstadoPronostico.visible ? textoMarcador(p.pronostico) : 'Sin pronóstico',
                    style: p.estadoPronostico == EstadoPronostico.visible
                        ? StreakText.cifra
                        : StreakText.pequeno,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
