import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/cache_store.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../data/auth_repository.dart';
import '../domain/usuario.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    ref.watch(secureStorageProvider),
    ref.watch(cacheStoreProvider),
  );
});

final authControllerProvider =
    NotifierProvider<AuthController, AuthSession>(AuthController.new);

class AuthController extends Notifier<AuthSession> {
  @override
  AuthSession build() {
    Future.microtask(_restore);
    return AuthSession.unknown;
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _restore() async {
    ({Usuario usuario, DateTime? offlineDesde})? restaurada;
    try {
      restaurada = await _repo.restoreSession();
    } catch (_) {
      restaurada = null;
    }
    if (restaurada == null) {
      state = AuthSession.loggedOut;
      return;
    }
    final user = restaurada.usuario;
    state = AuthSession(
      status: user.passTemporal
          ? AuthStatus.needsPasswordChange
          : AuthStatus.authenticated,
      user: user,
      offlineDesde: restaurada.offlineDesde,
    );
  }

  /// Llamado por el interceptor ante un 403 PASSWORD_TEMPORAL (RN-07).
  void forzarCambioPassword() {
    if (state.status == AuthStatus.needsPasswordChange) return;
    state = AuthSession(
      status: AuthStatus.needsPasswordChange,
      user: state.user?.copyWith(passTemporal: true),
    );
  }

  /// Llamado por el interceptor cuando el refresh token ya no es válido.
  void sesionExpirada() {
    if (state.status == AuthStatus.unauthenticated) return;
    // La sesión ya no es válida: no se deja en el teléfono la copia offline de esa cuenta.
    ref.read(cacheStoreProvider).limpiar();
    state = const AuthSession(
      status: AuthStatus.unauthenticated,
      message: 'Tu sesión expiró. Vuelve a iniciar sesión.',
    );
  }

  Future<void> login(String username, String password) async {
    final user = await _repo.login(username: username, password: password);
    state = AuthSession(
      status: user.passTemporal
          ? AuthStatus.needsPasswordChange
          : AuthStatus.authenticated,
      user: user,
    );
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String telefono = '',
    DateTime? fechaNacimiento,
  }) async {
    final user = await _repo.register(
      username: username,
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      telefono: telefono,
      fechaNacimiento: fechaNacimiento,
    );
    state = AuthSession(status: AuthStatus.authenticated, user: user);
  }

  Future<String> recuperar(String email) => _repo.recuperar(email);

  Future<String> restablecer({
    required String uid,
    required String token,
    required String newPassword,
  }) =>
      _repo.restablecer(uid: uid, token: token, newPassword: newPassword);

  /// Cambia la contraseña y vuelve a iniciar sesión (el backend invalida los tokens).
  Future<void> cambiarPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final username = state.user?.username;
    if (username == null) return;
    await _repo.cambiarPassword(oldPassword: oldPassword, newPassword: newPassword);
    try {
      final user = await _repo.login(username: username, password: newPassword);
      state = AuthSession(status: AuthStatus.authenticated, user: user);
    } on AppException {
      // La contraseña ya cambió pero el re-login falló: hay que entrar de nuevo a mano.
      state = const AuthSession(
        status: AuthStatus.unauthenticated,
        message: 'Contraseña actualizada. Inicia sesión con la nueva.',
      );
    }
  }

  Future<void> refrescarPerfil() async {
    final user = await _repo.refrescarPerfil(); // si falla, se conserva la copia actual
    state = AuthSession(
      status: user.passTemporal ? AuthStatus.needsPasswordChange : AuthStatus.authenticated,
      user: user,
    );
  }

  Future<void> actualizarPerfil({
    required String firstName,
    required String lastName,
    required String telefono,
    DateTime? fechaNacimiento,
    bool borrarFechaNacimiento = false,
    FotoPerfil? foto,
  }) async {
    final user = await _repo.actualizarPerfil(
      firstName: firstName,
      lastName: lastName,
      telefono: telefono,
      fechaNacimiento: fechaNacimiento,
      borrarFechaNacimiento: borrarFechaNacimiento,
      foto: foto,
    );
    state = AuthSession(status: AuthStatus.authenticated, user: user);
  }

  /// Elimina la cuenta (DELETE /usuarios/me/) y borra TODO lo local de esa cuenta: tokens, perfil,
  /// Idempotency-Key del pago PRO y caché Hive. Vuelve al login con un mensaje.
  Future<void> eliminarCuenta(String password) async {
    final usuarioId = state.user?.id;
    await _repo.eliminarCuenta(password);
    final storage = ref.read(secureStorageProvider);
    if (usuarioId != null) await storage.clearProIdempotencyKey(usuarioId);
    await storage.clearSession();
    await ref.read(cacheStoreProvider).limpiar();
    state = const AuthSession(
      status: AuthStatus.unauthenticated,
      message: 'Tu cuenta se eliminó. Gracias por haber jugado en STREAK.',
    );
  }

  Future<void> logout() async {
    await _repo.logout();
    await ref.read(cacheStoreProvider).limpiar();
    state = AuthSession.loggedOut;
  }
}
