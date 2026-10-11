import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../domain/usuario.dart';

class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final SecureStorageService _storage;

  Future<Usuario> login({
    required String username,
    required String password,
  }) async {
    final user = username.trim();
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: {'username': user, 'password': password},
      );
      final data = response.data as Map<String, dynamic>;
      await _storage.saveTokens(
        access: data['access'] as String,
        refresh: data['refresh'] as String,
      );
      await _storage.saveUsername(user);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
    return _cargarEstado(user);
  }

  Future<Usuario> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String telefono = '',
  }) async {
    try {
      await _dio.post(
        ApiConstants.register,
        data: {
          'username': username.trim(),
          'email': email.trim(),
          'password': password,
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'telefono': telefono.trim(),
        },
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
    return login(username: username, password: password);
  }

  Future<void> recuperar(String email) async {
    try {
      await _dio.post(ApiConstants.recuperarPassword, data: {'email': email.trim()});
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  Future<void> cambiarPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        ApiConstants.cambiarPassword,
        data: {'old_password': oldPassword, 'new_password': newPassword},
      );
      await _storage.setPassTemporal(false);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  /// Restaura la sesión guardada. Sin conexión usa los últimos datos conocidos
  /// (modo lectura, RN-74); si el servidor rechaza el token devuelve null.
  Future<Usuario?> restoreSession() async {
    final token = await _storage.getAccessToken();
    final username = await _storage.getUsername();
    if (token == null || username == null) return null;
    try {
      return await _cargarEstado(username);
    } on AppException catch (e) {
      if (e.codigo == 'NETWORK_ERROR' || e.codigo == 'TIMEOUT_ERROR') {
        return Usuario(
          id: 0,
          username: username,
          email: '',
          esPro: await _storage.isPro(),
          passTemporal: await _storage.isPassTemporal(),
        );
      }
      if (await _storage.getAccessToken() == null) return null;
      rethrow;
    }
  }

  Future<void> logout() => _storage.clearSession();

  /// El login del backend solo devuelve tokens. /pro/estado/ indica es_pro, y si la
  /// contraseña es temporal responde 403 PASSWORD_TEMPORAL_LOCK (RN-07).
  Future<Usuario> _cargarEstado(String username) async {
    var esPro = false;
    var temporal = false;
    try {
      final resp = await _dio.get(ApiConstants.proEstado);
      esPro = resp.data['es_pro'] == true;
    } on DioException catch (e) {
      final ex = AppException.fromDioError(e);
      if (ex.codigo != 'PASSWORD_TEMPORAL_LOCK') throw ex;
      temporal = true;
    }
    await _storage.setIsPro(esPro);
    await _storage.setPassTemporal(temporal);
    return Usuario(
      id: 0,
      username: username,
      email: '',
      esPro: esPro,
      passTemporal: temporal,
    );
  }
}
