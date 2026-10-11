// Prueba de punta a punta del login (B1) contra un backend real.
// No corre con `flutter test` normal; se ejecuta así:
//   flutter test test_e2e --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
// Requiere en el backend: ana / Clave1234x (normal), beto / Clave1234x (Pro)
// y caro / Temporal123 con pass_temporal_flag = true.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/errors/app_exception.dart';
import 'package:streak_mobile/core/storage/secure_storage_service.dart';
import 'package:streak_mobile/features/auth/application/auth_controller.dart';
import 'package:streak_mobile/features/auth/domain/usuario.dart';

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
  Future<void> clearSession() async => datos.clear();
}

void main() {
  late MemoriaStorage storage;
  late ProviderContainer container;

  setUp(() async {
    storage = MemoriaStorage();
    container = ProviderContainer(overrides: [
      secureStorageProvider.overrideWithValue(storage),
    ]);
    container.listen(authControllerProvider, (_, __) {});
    // Espera a que termine la restauración inicial (sin sesión guardada).
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });

  tearDown(() => container.dispose());

  AuthController ctrl() => container.read(authControllerProvider.notifier);
  AuthSession sesion() => container.read(authControllerProvider);

  test('login normal queda autenticado y guarda tokens', () async {
    await ctrl().login('ana', 'Clave1234x');
    expect(sesion().status, AuthStatus.authenticated);
    expect(sesion().user?.esPro, isFalse);
    expect(storage.datos['access'], isNotNull);
  });

  test('usuario Pro trae es_pro = true', () async {
    await ctrl().login('beto', 'Clave1234x');
    expect(sesion().user?.esPro, isTrue);
  });

  test('credenciales malas dan error en español', () async {
    await expectLater(
      ctrl().login('ana', 'incorrecta1'),
      throwsA(isA<AppException>().having((e) => e.codigo, 'codigo', 'CREDENCIALES_INVALIDAS')),
    );
    expect(sesion().status, AuthStatus.unauthenticated);
  });

  test('contraseña temporal fuerza el cambio y luego libera (RN-07)', () async {
    await ctrl().login('caro', 'Temporal123');
    expect(sesion().status, AuthStatus.needsPasswordChange);

    await ctrl().cambiarPassword(oldPassword: 'Temporal123', newPassword: 'Nueva12345');
    expect(sesion().status, AuthStatus.authenticated);

    // Con la nueva contraseña el backend ya no bloquea.
    await ctrl().logout();
    await ctrl().login('caro', 'Nueva12345');
    expect(sesion().status, AuthStatus.authenticated);
  });

  test('access token vencido se renueva solo con el refresh', () async {
    await ctrl().login('ana', 'Clave1234x');
    final refreshValido = storage.datos['refresh'];
    storage.datos['access'] = 'token-invalido';

    // restoreSession hace una llamada autenticada: el interceptor debe renovar.
    final user = await container.read(authRepositoryProvider).restoreSession();
    expect(user, isNotNull);
    expect(storage.datos['access'], isNot('token-invalido'));
    expect(storage.datos['refresh'], refreshValido);
  });

  test('refresh inválido cierra la sesión', () async {
    await ctrl().login('ana', 'Clave1234x');
    storage.datos['access'] = 'token-invalido';
    storage.datos['refresh'] = 'refresh-invalido';
    final user = await container.read(authRepositoryProvider).restoreSession();
    expect(user, isNull);
    expect(sesion().status, AuthStatus.unauthenticated);
  });
}
