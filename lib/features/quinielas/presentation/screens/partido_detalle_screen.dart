import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../../core/widgets/avatar_usuario.dart';
import '../../../../core/widgets/estructura.dart';
import '../../../../core/widgets/streak_icon.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/quinielas_providers.dart';
import '../../domain/quiniela_vista.dart';
import '../widgets/quiniela_widgets.dart';

/// Texto del pronóstico de un participante según `estado_pronostico` del backend (RN-39).
/// OCULTO (rival antes del inicio) y NO_REGISTRADO son estados distintos; no se deduce por la hora.
String textoPronosticoParticipante(EstadoPronostico estado, Marcador? pronostico) => switch (estado) {
      EstadoPronostico.oculto => 'Oculto hasta el inicio',
      EstadoPronostico.noRegistrado => 'Sin pronóstico',
      EstadoPronostico.visible => textoMarcador(pronostico),
    };

/// Detalle de partido (18): cabecera con fase · estado y marcador, y los pronósticos del grupo.
class PartidoDetalleScreen extends ConsumerWidget {
  const PartidoDetalleScreen({super.key, required this.quinielaId, required this.partidoId});

  final int quinielaId;
  final int partidoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clave = (quinielaId: quinielaId, partidoId: partidoId);
    final detalle = ref.watch(partidoDetalleProvider(clave));
    final vista = ref.watch(quinielaVistaProvider(quinielaId)).valueOrNull;
    final yo = ref.watch(authControllerProvider.select((s) => s.user?.id));

    Future<void> refrescar() async {
      ref.invalidate(partidoDetalleProvider(clave));
      await ref.read(partidoDetalleProvider(clave).future).then((_) {}, onError: (_) {});
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del partido')),
      body: detalle.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const CargandoTarjetas(),
        error: (e, _) => ErrorReintentar(error: e, onRetry: () => ref.invalidate(partidoDetalleProvider(clave))),
        data: (d) {
          final p = d.partido;
          // El yo primero (la maqueta lo muestra arriba), luego el orden del backend.
          final filas = [...d.participantes]..sort((a, b) => (b.usuarioId == yo ? 1 : 0) - (a.usuarioId == yo ? 1 : 0));
          return RefreshIndicator(
            onRefresh: refrescar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(StreakSize.screenPadding, 8, StreakSize.screenPadding, 24),
              children: [
                CabeceraPartido(partido: p, vista: vista),
                const EncabezadoSeccion('Pronósticos del grupo'),
                if (filas.isEmpty) const MensajeVacio('Esta quiniela no tiene participantes.'),
                for (final pa in filas)
                  FilaPronostico(
                    participante: pa,
                    partido: p,
                    esYo: pa.usuarioId == yo,
                    onTap: () => context.push('/quinielas/$quinielaId/participante/${pa.usuarioId}'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// "Semifinales · Finalizado", escudos y marcador en crema (o "vs" si aún no hay marcador).
class CabeceraPartido extends StatelessWidget {
  const CabeceraPartido({super.key, required this.partido, this.vista});

  final Partido partido;
  final QuinielaVista? vista;

  @override
  Widget build(BuildContext context) {
    final p = partido;
    final fase = vista?.fases[p.faseId]?.nombre;
    final local = p.equipoLocal?.nombre ?? vista?.nombreEquipo(p.equipoLocalId) ?? 'Local';
    final visita = p.equipoVisita?.nombre ?? vista?.nombreEquipo(p.equipoVisitaId) ?? 'Visita';
    final hayMarcador = (p.estado == 'FINALIZADO' || p.enJuego) && p.resultado != null;
    return TarjetaStreak(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        children: [
          Text(fase == null ? '${fechaLocal(p.fechaHora)} · ${textoEstado(p)}' : '$fase · ${textoEstado(p)}',
              textAlign: TextAlign.center, style: StreakText.pequeno),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: EquipoColumna(nombre: local, escudo: p.equipoLocal?.escudo ?? vista?.escudoEquipo(p.equipoLocalId))),
              Text(
                hayMarcador ? textoMarcador(p.resultado) : (p.noCuenta ? '– –' : 'vs'),
                style: hayMarcador ? StreakText.marcador : StreakText.marcador.copyWith(color: StreakColors.muted),
              ),
              Expanded(child: EquipoColumna(nombre: visita, escudo: p.equipoVisita?.escudo ?? vista?.escudoEquipo(p.equipoVisitaId))),
            ],
          ),
          if (fase != null) ...[
            const SizedBox(height: 8),
            Text(fechaLocal(p.fechaHora), style: StreakText.mini),
          ],
        ],
      ),
    );
  }
}

/// Fila de "Pronósticos del grupo": avatar, nombre (corona PRO, "(tú)"), pronóstico y chip de puntos.
class FilaPronostico extends StatelessWidget {
  const FilaPronostico({super.key, required this.participante, required this.partido, required this.esYo, this.onTap});

  final ParticipanteEnPartido participante;
  final Partido partido;
  final bool esYo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pa = participante;
    final visible = pa.estado == EstadoPronostico.visible;
    final subtitulo = visible ? null : textoPronosticoParticipante(pa.estado, null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TarjetaStreak(
        onTap: onTap,
        resaltada: esYo,
        radio: StreakRadius.fila,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            AvatarUsuario(nombre: pa.username, fotoUrl: pa.foto),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NombreParticipante(nombre: pa.username, esPro: pa.esPro, esYo: esYo),
                  if (subtitulo != null)
                    Row(
                      children: [
                        if (pa.estado == EstadoPronostico.oculto) ...[
                          const StreakIcon(StreakIcons.lock, size: StreakSize.iconMini),
                          const SizedBox(width: 4),
                        ],
                        Flexible(child: Text(subtitulo, style: StreakText.pequeno)),
                      ],
                    ),
                ],
              ),
            ),
            if (visible) ...[
              const SizedBox(width: 8),
              Text(textoMarcador(pa.pronostico), style: StreakText.marcadorFila),
            ],
            if (partido.esResuelto) ...[
              const SizedBox(width: 12),
              ChipPuntosPartido(estado: partido.estado, puntos: pa.puntos),
            ],
          ],
        ),
      ),
    );
  }
}
