import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../data/quinielas_repository.dart';
import '../domain/models.dart';

final quinielasRepositoryProvider = Provider<QuinielasRepository>((ref) {
  return QuinielasRepository(ref.watch(dioProvider));
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

final misQuinielasProvider = FutureProvider.autoDispose<List<Quiniela>>((ref) {
  return ref.watch(quinielasRepositoryProvider).mias();
});

final historialProvider = FutureProvider.autoDispose<List<Quiniela>>((ref) {
  return ref.watch(quinielasRepositoryProvider).historial();
});

final quinielaProvider = FutureProvider.autoDispose.family<Quiniela, int>((ref, id) {
  return ref.watch(quinielasRepositoryProvider).detalle(id);
});

/// Refresca las listas del home tras crear o unirse a una quiniela.
void refrescarQuinielas(WidgetRef ref) {
  ref.invalidate(misQuinielasProvider);
  ref.invalidate(historialProvider);
}
