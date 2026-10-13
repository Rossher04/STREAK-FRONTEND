import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/server_clock.dart';
import '../../../../core/theme/streak_theme.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/quinielas_providers.dart';
import '../../domain/quiniela_vista.dart';
import '../widgets/quiniela_widgets.dart';

/// Texto del pronóstico de otro participante (RN-39, RN-10: solo username).
/// null puede significar "oculto hasta el inicio" o "no pronosticó"; se distingue por la hora
/// del servidor: antes de fecha_hora el backend oculta los pronósticos ajenos.
String textoPronosticoParticipante({
  required Marcador? pronostico,
  required bool esPropio,
  required DateTime fechaHora,
  required DateTime ahoraServidor,
}) {
  if (pronostico != null) return textoMarcador(pronostico);
  if (!esPropio && ahoraServidor.isBefore(fechaHora)) return 'Oculto hasta el inicio del partido';
  return 'Sin pronóstico';
}

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
    final ahora = ref.watch(serverClockProvider).ahora();

    Future<void> refrescar() async {
      ref.invalidate(partidoDetalleProvider(clave));
      await ref.read(partidoDetalleProvider(clave).future).then((_) {}, onError: (_) {});
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del partido')),
      body: detalle.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorReintentar(error: e, onRetry: () => ref.invalidate(partidoDetalleProvider(clave))),
        data: (d) {
          final p = d.partido;
          final local = vista?.nombreEquipo(p.equipoLocalId) ?? 'Local';
          final visita = vista?.nombreEquipo(p.equipoVisitaId) ?? 'Visita';
          final resuelto = p.esResuelto;
          return RefreshIndicator(
            onRefresh: refrescar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Container(
                  color: StreakColors.brand,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('${fechaLocal(p.fechaHora)} · ${textoEstado(p)}',
                          style: const TextStyle(color: StreakColors.muted, fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(local,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: StreakColors.text, fontWeight: FontWeight.w800, fontSize: 16)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              p.estado == 'FINALIZADO' ? textoMarcador(p.resultado) : 'vs',
                              style: const TextStyle(color: StreakColors.accent, fontSize: 26, fontWeight: FontWeight.w900),
                            ),
                          ),
                          Expanded(
                            child: Text(visita,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: StreakColors.text, fontWeight: FontWeight.w800, fontSize: 16)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (d.participantes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Esta quiniela no tiene participantes.', textAlign: TextAlign.center),
                  ),
                for (final pa in d.participantes)
                  ListTile(
                    selected: pa.usuarioId == yo,
                    selectedTileColor: StreakColors.accent.withValues(alpha: 0.18),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: StreakColors.surface2,
                      child: Text(pa.username.isEmpty ? '?' : pa.username[0].toUpperCase(),
                          style: const TextStyle(color: StreakColors.cream, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(pa.usuarioId == yo ? '${pa.username} (tú)' : pa.username,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(textoPronosticoParticipante(
                      pronostico: pa.pronostico,
                      esPropio: pa.usuarioId == yo,
                      fechaHora: p.fechaHora,
                      ahoraServidor: ahora,
                    )),
                    trailing: resuelto
                        ? Text(
                            p.estado == 'FINALIZADO' ? '${pa.puntos} pts' : 'no cuenta',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          )
                        : null,
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
