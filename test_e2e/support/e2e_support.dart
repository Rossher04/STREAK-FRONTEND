// Utilidades compartidas por las pruebas e2e (backend real, almacenamiento en memoria).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streak_mobile/core/storage/cache_store.dart';
import 'package:streak_mobile/core/storage/secure_storage_service.dart';
import 'package:streak_mobile/features/auth/application/auth_controller.dart';
import 'package:streak_mobile/core/network/dio_client.dart';
import 'package:streak_mobile/features/auth/domain/usuario.dart';
import 'package:streak_mobile/features/quinielas/application/quinielas_providers.dart';
import 'package:streak_mobile/features/quinielas/data/quinielas_repository.dart';
import 'package:streak_mobile/features/quinielas/domain/models.dart';
import 'package:streak_mobile/features/quinielas/domain/quiniela_vista.dart';

const clave = 'Clave1234x';

/// Sustituye al almacenamiento seguro (que necesita el teléfono) por un mapa en memoria.
class MemoriaStorage extends SecureStorageService {
  final datos = <String, String>{};

  @override
  Future<void> saveTokens({required String access, required String refresh, bool passTemporal = false}) async {
    datos['access'] = access;
    datos['refresh'] = refresh;
    datos['temporal'] = '$passTemporal';
  }

  @override
  Future<void> saveAccessToken(String access) async => datos['access'] = access;
  @override
  Future<void> saveUsername(String username) async => datos['username'] = username;
  @override
  Future<String?> getUsername() async => datos['username'];
  @override
  Future<String?> getAccessToken() async => datos['access'];
  @override
  Future<String?> getRefreshToken() async => datos['refresh'];
  @override
  Future<bool> isPassTemporal() async => datos['temporal'] == 'true';
  @override
  Future<void> setPassTemporal(bool value) async => datos['temporal'] = '$value';
  @override
  Future<bool> isPro() async => datos['pro'] == 'true';
  @override
  Future<void> setIsPro(bool value) async => datos['pro'] = '$value';
  @override
  Future<String?> getProIdempotencyKey(int userId) async => datos['pro_$userId'];
  @override
  Future<void> saveProIdempotencyKey(int userId, String key) async => datos['pro_$userId'] = key;
  @override
  Future<void> clearProIdempotencyKey(int userId) async => datos.remove('pro_$userId');
  @override
  Future<void> clearSession() async => datos.removeWhere((k, _) => !k.startsWith('pro_'));
}

/// Una "app" independiente: su propio almacenamiento y su propio contenedor Riverpod.
class AppE2E {
  AppE2E._(this.storage, this.container, this.cache);

  final MemoriaStorage storage;
  final ProviderContainer container;
  final MemoryCacheStore cache;

  static Future<AppE2E> crear() async {
    final storage = MemoriaStorage();
    final cache = MemoryCacheStore();
    final container = ProviderContainer(overrides: [
      secureStorageProvider.overrideWithValue(storage),
      cacheStoreProvider.overrideWithValue(cache),
    ]);
    container.listen(authControllerProvider, (_, __) {});
    // Espera a que termine la restauración inicial (sin sesión guardada).
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return AppE2E._(storage, container, cache);
  }

  AuthController get auth => container.read(authControllerProvider.notifier);
  AuthSession get sesion => container.read(authControllerProvider);

  /// Registra un usuario nuevo (queda con sesión iniciada) y devuelve su username.
  Future<String> registrarNuevo(String prefijo, {DateTime? fechaNacimiento}) async {
    final u = '$prefijo${DateTime.now().microsecondsSinceEpoch}';
    await auth.register(
      username: u,
      email: '$u@e2e.test',
      password: clave,
      firstName: 'Nombre',
      lastName: 'Apellido',
      fechaNacimiento: fechaNacimiento,
    );
    return u;
  }

  void cerrar() => container.dispose();
}

/// Atajos para escribir las pruebas e2e sin repetir llamadas al repositorio.
extension AtajosE2E on AppE2E {
  QuinielasRepository get repo => container.read(quinielasRepositoryProvider);
  int get usuarioId => sesion.user!.id;

  Future<List<Quiniela>> mias() => repo.mias();

  /// Respuesta cruda de GET /quinielas/{id}/participantes/.
  Future<List<dynamic>> participantes(int quinielaId) async {
    final resp = await container.read(dioProvider).get('/quinielas/$quinielaId/participantes/');
    return resp.data as List<dynamic>;
  }

  Future<Quiniela> crear(String nombre, int torneoId, int max) =>
      repo.crear(nombre: nombre, torneoId: torneoId, maxParticipantes: max);

  Future<Torneo> torneoActivo(String nombre) async {
    final torneos = await repo.torneos();
    return torneos.firstWhere((t) => t.nombre == nombre && t.esActivo);
  }

  Future<int> idQuiniela(String nombre) async => (await mias()).firstWhere((q) => q.nombre == nombre).id;

  Future<QuinielaVista> vista(String nombre) async => repo.vista(await idQuiniela(nombre), usuarioId: usuarioId);
}
