import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../data/auth_repository.dart';
import '../domain/usuario.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider), ref.watch(secureStorageProvider));
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
    Usuario? user;
    try {
      user = await _repo.restoreSession();
    } catch (_) {
      user = null;
    }
    if (user == null) {
      state = AuthSession.loggedOut;
      return;
    }
    state = AuthSession(
      status: user.passTemporal
          ? AuthStatus.needsPasswordChange
          : AuthStatus.authenticated,
      user: user,
    );
  }

  /// Llamado por el interceptor ante un 403 PASSWORD_TEMPORAL_LOCK (RN-07).
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
  }) async {
    final user = await _repo.register(
      username: username,
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      telefono: telefono,
    );
    state = AuthSession(status: AuthStatus.authenticated, user: user);
  }

  Future<void> recuperar(String email) => _repo.recuperar(email);

  Future<void> cambiarPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _repo.cambiarPassword(oldPassword: oldPassword, newPassword: newPassword);
    final user = state.user?.copyWith(passTemporal: false);
    state = AuthSession(status: AuthStatus.authenticated, user: user);
  }

  void updateProfile(Usuario user) {
    state = AuthSession(status: AuthStatus.authenticated, user: user);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = AuthSession.loggedOut;
  }
}
