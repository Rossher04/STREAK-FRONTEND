import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../domain/usuario.dart';

/// Foto elegida en el selector de imágenes, lista para enviarse como multipart.
class FotoPerfil {
  const FotoPerfil({required this.bytes, required this.nombre});
  final List<int> bytes;
  final String nombre;
}

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
    return _cargarPerfil(user);
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

  /// Devuelve el mensaje genérico del backend (no revela si el correo existe).
  /// Si el correo no está configurado responde 503 CORREO_NO_CONFIGURADO.
  Future<String> recuperar(String email) async {
    try {
      final resp = await _dio.post(ApiConstants.recuperarPassword, data: {'email': email.trim()});
      return _detalle(resp.data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  /// Confirma el enlace de recuperación (uid y token vienen del correo).
  Future<String> restablecer({
    required String uid,
    required String token,
    required String newPassword,
  }) async {
    try {
      final resp = await _dio.post(
        ApiConstants.restablecerPassword,
        data: {'uid': uid, 'token': token, 'new_password': newPassword},
      );
      return _detalle(resp.data);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  /// El backend invalida access y refresh al cambiar la contraseña: la sesión
  /// guardada deja de servir y quien llama debe volver a iniciar sesión.
  Future<void> cambiarPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        ApiConstants.cambiarPassword,
        data: {'old_password': oldPassword, 'new_password': newPassword},
      );
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
    await _storage.clearSession();
  }

  /// Restaura la sesión guardada. Sin conexión usa los últimos datos conocidos
  /// (modo lectura, RN-74); si el servidor rechaza el token devuelve null.
  Future<Usuario?> restoreSession() async {
    final token = await _storage.getAccessToken();
    final username = await _storage.getUsername();
    if (token == null || username == null) return null;
    try {
      return await _cargarPerfil(username);
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

  /// B2: PATCH /usuarios/me/. Con foto se envía multipart/form-data.
  Future<Usuario> actualizarPerfil({
    required String firstName,
    required String lastName,
    required String telefono,
    FotoPerfil? foto,
  }) async {
    try {
      final campos = {'first_name': firstName, 'last_name': lastName, 'telefono': telefono};
      final Object body;
      Options? options;
      if (foto != null) {
        body = FormData.fromMap({
          ...campos,
          'foto': MultipartFile.fromBytes(foto.bytes, filename: foto.nombre),
        });
        options = Options(contentType: Headers.multipartFormDataContentType);
      } else {
        body = campos;
      }
      final resp = await _dio.patch(ApiConstants.usuarioMe, data: body, options: options);
      return Usuario.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  Future<void> logout() => _storage.clearSession();

  /// GET /usuarios/me/. Con contraseña temporal (RN-07) el backend responde
  /// 403 ACCESO_DENEGADO también aquí; no hay datos de perfil hasta cambiarla.
  Future<Usuario> _cargarPerfil(String username) async {
    Usuario user;
    try {
      final resp = await _dio.get(ApiConstants.usuarioMe);
      user = Usuario.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final ex = AppException.fromDioError(e);
      if (e.response?.statusCode != 403 || ex.codigo != 'ACCESO_DENEGADO') throw ex;
      await _storage.setPassTemporal(true);
      return Usuario(id: 0, username: username, email: '', passTemporal: true);
    }
    await _storage.setIsPro(user.esPro);
    await _storage.setPassTemporal(user.passTemporal);
    await _storage.saveUsername(user.username);
    return user;
  }

  static String _detalle(dynamic data) =>
      (data is Map ? data['detail']?.toString() : null) ?? 'Solicitud enviada.';
}
