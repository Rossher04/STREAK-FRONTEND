import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/server_clock.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/quinielas_providers.dart';
import '../../domain/quiniela_vista.dart';
import '../widgets/quiniela_widgets.dart';
import 'partido_detalle_screen.dart' show textoPronosticoParticipante;

/// Detalle de un participante: todos los partidos con su pronóstico y puntos.
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
    final ahora = ref.watch(serverClockProvider).ahora();

    Future<void> refrescar() async {
      ref.invalidate(participanteDetalleProvider(clave));
      await ref.read(participanteDetalleProvider(clave).future).then((_) {}, onError: (_) {});
    }

    return Scaffold(
      appBar: AppBar(title: Text(detalle.valueOrNull?.username ?? 'Participante')),
      body: detalle.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            ErrorReintentar(error: e, onRetry: () => ref.invalidate(participanteDetalleProvider(clave))),
        data: (d) {
          final partidos = [...d.partidos]..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
          final grupos = vista == null ? <(Fase?, List<Partido>)>[(null, partidos)] : agruparPorFase(vista, partidos);
          return RefreshIndicator(
            onRefresh: refrescar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Container(
                  color: StreakColors.brand,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(d.usuarioId == yo ? '${d.username} (tú)' : d.username,
                          style: const TextStyle(color: StreakColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('${d.puntosTotales} pts',
                          style: const TextStyle(color: StreakColors.accent, fontSize: 20, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                if (partidos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('El torneo aún no tiene partidos.', textAlign: TextAlign.center),
                  ),
                for (final (fase, lista) in grupos) ...[
                  EncabezadoFase(fase),
                  for (final p in lista)
                    Card(
                      child: ListTile(
                        onTap: () => context.push('/quinielas/$quinielaId/partido/${p.id}'),
                        title: Text(
                          '${vista?.nombreEquipo(p.equipoLocalId) ?? 'Local'}  ${p.estado == 'FINALIZADO' ? textoMarcador(p.resultado) : 'vs'}  ${vista?.nombreEquipo(p.equipoVisitaId) ?? 'Visita'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${fechaLocal(p.fechaHora)} · ${textoEstado(p)}'),
                            Text(_lineaPronostico(textoPronosticoParticipante(
                              pronostico: p.pronostico,
                              esPropio: d.usuarioId == yo,
                              fechaHora: p.fechaHora,
                              ahoraServidor: ahora,
                            ))),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: p.esResuelto
                            ? Text(
                                p.estado == 'FINALIZADO' ? '${p.puntos} pts' : 'no cuenta',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              )
                            : null,
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// "Pronóstico: 2 - 1", pero sin repetir la palabra cuando el texto ya es una frase ("Sin pronóstico").
String _lineaPronostico(String texto) =>
    (texto.startsWith('Sin ') || texto.startsWith('Oculto')) ? texto : 'Pronóstico: $texto';
