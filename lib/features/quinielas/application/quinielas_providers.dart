import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/cache_store.dart';
import '../../auth/application/auth_controller.dart';
import '../data/quinielas_repository.dart';
import '../domain/models.dart';
import '../domain/quiniela_vista.dart';
import '../domain/resumen_inicio.dart';

final quinielasRepositoryProvider = Provider<QuinielasRepository>((ref) {
  return QuinielasRepository(ref.watch(dioProvider), ref.watch(cacheStoreProvider));
});

/// Todos los torneos publicados, por id (para mostrar el nombre del torneo de cada quiniela).
final torneosProvider = FutureProvider.autoDispose<List<Torneo>>((ref) {
  return ref.watch(quinielasRepositoryProvider).torneos();
});

/// Torneos ACTIVO: los únicos en los que se puede crear una quiniela (RN-16).
final torneosActivosProvider = FutureProvider.autoDispose<List<Torneo>>((ref) async {
  final torneos = await ref.watch(torneosProvider.future);
  return torneos.where((t) => t.esActivo).toList();
});

final misQuinielasProvider = FutureProvider.autoDispose<Listado<Quiniela>>((ref) {
  final usuarioId = ref.watch(authControllerProvider.select((s) => s.user?.id)) ?? 0;
  return ref.watch(quinielasRepositoryProvider).miasConCopia(usuarioId);
});

final historialProvider = FutureProvider.autoDispose<Listado<Quiniela>>((ref) {
  final usuarioId = ref.watch(authControllerProvider.select((s) => s.user?.id)) ?? 0;
  return ref.watch(quinielasRepositoryProvider).historialConCopia(usuarioId);
});

final quinielaProvider = FutureProvider.autoDispose.family<Quiniela, int>((ref, id) {
  return ref.watch(quinielasRepositoryProvider).detalle(id);
});

/// Refresca las listas del home tras crear o unirse a una quiniela.
void refrescarQuinielas(WidgetRef ref) {
  ref.invalidate(misQuinielasProvider);
  ref.invalidate(historialProvider);
}

/// Quiniela activa completa (B5): torneo, equipos, fases, partidos con mi pronóstico y tabla.
final quinielaVistaProvider = FutureProvider.autoDispose.family<QuinielaVista, int>((ref, id) {
  final usuarioId = ref.watch(authControllerProvider.select((s) => s.user?.id)) ?? 0;
  return ref.watch(quinielasRepositoryProvider).vista(id, usuarioId: usuarioId);
});

final partidoDetalleProvider =
    FutureProvider.autoDispose.family<PartidoDetalle, ({int quinielaId, int partidoId})>((ref, k) {
  return ref.watch(quinielasRepositoryProvider).partidoDetalle(k.quinielaId, k.partidoId);
});

final participanteDetalleProvider =
    FutureProvider.autoDispose.family<ParticipanteDetalle, ({int quinielaId, int usuarioId})>((ref, k) {
  return ref.watch(quinielasRepositoryProvider).participanteDetalle(k.quinielaId, k.usuarioId);
});

/// Partidos resumidos de una quiniela para el chip del Inicio (07). Si falla, la tarjeta simplemente no muestra
/// "Cierra en…" (no bloquea el Inicio).
final resumenPartidosProvider = FutureProvider.autoDispose.family<List<PartidoResumen>, int>((ref, id) {
  return ref.watch(quinielasRepositoryProvider).resumenPartidos(id);
});
