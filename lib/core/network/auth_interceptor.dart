import 'package:dio/dio.dart';
import '../storage/secure_storage_service.dart';
import '../constants/api_constants.dart';

/// Adjunta el JWT, renueva el access token ante un 401 y detecta la
/// contraseña temporal (RN-07).
/// Código del 403 que el backend usa cuando la contraseña es temporal (RN-07).
const codigoPasswordTemporal = 'PASSWORD_TEMPORAL';

class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor(
    Dio dio,
    this._storage, {
    this.onForcePasswordChange,
    this.onSessionExpired,
  }) : _plainDio = Dio(BaseOptions(
          baseUrl: dio.options.baseUrl,
          connectTimeout: dio.options.connectTimeout,
          receiveTimeout: dio.options.receiveTimeout,
        ));

  /// Cliente sin interceptores para el refresh y el reintento: usar el Dio principal
  /// aquí bloquearía la cola del QueuedInterceptor si esa petición también falla.
  final Dio _plainDio;
  final SecureStorageService _storage;
  final void Function()? onForcePasswordChange;
  final void Function()? onSessionExpired;

  static const _rutasPublicas = ['/auth/login', '/auth/register', '/auth/recuperar', '/auth/restablecer'];

  bool _esPublica(String path) => _rutasPublicas.any(path.contains);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_esPublica(options.path)) {
      final token = await _storage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;

    // RN-07: con contraseña temporal el backend responde 403 con el código específico PASSWORD_TEMPORAL
    // (permissions.py, commit 91ebd2a). Cualquier otro 403 es un acceso denegado normal y se propaga tal cual.
    if (status == 403 && !_esPublica(path) && _codigoError(err.response?.data) == codigoPasswordTemporal) {
      await _storage.setPassTemporal(true);
      onForcePasswordChange?.call();
      return handler.next(err);
    }

    final yaReintentado = err.requestOptions.extra['reintentado'] == true;
    if (status == 401 && !_esPublica(path) && !yaReintentado) {
      final refresh = await _storage.getRefreshToken();
      if (refresh != null) {
        try {
          final resp = await _plainDio.post(
            ApiConstants.refreshToken,
            data: {'refresh': refresh},
          );
          final newAccess = resp.data['access'] as String;
          await _storage.saveAccessToken(newAccess);

          final retry = err.requestOptions
            ..headers['Authorization'] = 'Bearer $newAccess'
            ..extra['reintentado'] = true;
          return handler.resolve(await _plainDio.fetch(retry));
        } on DioException catch (e) {
          // Solo se cierra sesión ante un 401; por falta de red o error del reintento se propaga el error.
          if (e.response?.statusCode != 401) return handler.next(e.response != null ? e : err);
        }
      }
      await _storage.clearSession();
      onSessionExpired?.call();
    }

    handler.next(err);
  }

  static String? _codigoError(dynamic data) {
    if (data is Map && data['error'] is Map) {
      return (data['error'] as Map)['codigo']?.toString();
    }
    return null;
  }
}
