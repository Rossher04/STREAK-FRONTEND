import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../domain/usuario.dart';

class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final SecureStorageService _storage;

  static const _demoAccess = 'demo-access-token';
  static const _demoRefresh = 'demo-refresh-token';

  Future<Usuario> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: {'username': username.trim(), 'password': password},
      );
      final data = response.data as Map<String, dynamic>;
      await _storage.saveTokens(
        access: data['access'] as String,
        refresh: data['refresh'] as String,
        passTemporal: data['pass_temporal_flag'] == true,
      );
      return Usuario(
        id: 0,
        username: username.trim(),
        email: '',
        passTemporal: data['pass_temporal_flag'] == true,
      );
    } on DioException catch (e) {
      if (_isUnreachable(e)) {
        return await _loginDemo(username.trim(), password);
      }
      throw AppException.fromDioError(e);
    }
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
      return login(username: username, password: password);
    } on DioException catch (e) {
      if (_isUnreachable(e)) {
        return await _loginDemo(username.trim(), password, email: email, firstName: firstName, lastName: lastName, telefono: telefono);
      }
      throw AppException.fromDioError(e);
    }
  }

  Future<void> recuperar(String email) async {
    try {
      await _dio.post(ApiConstants.recuperarPassword, data: {'email': email.trim()});
    } on DioException catch (e) {
      if (_isUnreachable(e)) return;
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
      if (_isUnreachable(e)) {
        await _storage.setPassTemporal(false);
        return;
      }
      throw AppException.fromDioError(e);
    }
  }

  Future<Usuario?> restoreSession() async {
    final token = await _storage.getAccessToken();
    if (token == null) return null;
    final temporal = await _storage.isPassTemporal();
    final pro = await _storage.isPro();
    return Usuario(
      id: 1,
      username: token == _demoAccess ? 'demo' : 'usuario',
      email: 'demo@streak.app',
      firstName: 'Alex',
      lastName: 'Rivas',
      telefono: '5555-0101',
      fechaNacimiento: DateTime(1998, 5, 12),
      esPro: pro,
      passTemporal: temporal,
    );
  }

  Future<void> logout() => _storage.clearSession();

  Future<Usuario> _loginDemo(
    String username,
    String password, {
    String email = 'demo@streak.app',
    String firstName = 'Alex',
    String lastName = 'Rivas',
    String telefono = '',
  }) async {
    final temporal = username.toLowerCase() == 'temp' || password == 'temporal10';
    await _storage.saveTokens(
      access: _demoAccess,
      refresh: _demoRefresh,
      passTemporal: temporal,
    );
    return Usuario(
      id: 1,
      username: username,
      email: email,
      firstName: firstName,
      lastName: lastName,
      telefono: telefono,
      fechaNacimiento: DateTime(1998, 5, 12),
      passTemporal: temporal,
    );
  }

  bool _isUnreachable(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.unknown;
  }
}
