import 'package:dio/dio.dart';
import '../storage/secure_storage_service.dart';
import '../constants/api_constants.dart';

class AuthInterceptor extends QueuedInterceptor {
  final Dio _dio;
  final SecureStorageService _storage;
  final void Function()? onForcePasswordChange;

  AuthInterceptor(this._dio, this._storage, {this.onForcePasswordChange});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Si la ruta no es de auth público, adjuntar token JWT
    if (!options.path.contains('/auth/login') &&
        !options.path.contains('/auth/register') &&
        !options.path.contains('/auth/recuperar')) {
      final token = await _storage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    return handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    // RN-07: Si el backend detecta pass_temporal_flag = true
    if (response.data is Map<String, dynamic>) {
      if (response.data['pass_temporal_flag'] == true) {
        await _storage.setPassTemporal(true);
        onForcePasswordChange?.call();
      }
    }
    return handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Manejo de expiración de token (401 Unauthorized)
    if (err.response?.statusCode == 401 &&
        !err.requestOptions.path.contains('/auth/login')) {
      final refresh = await _storage.getRefreshToken();
      if (refresh != null) {
        try {
          // Intentar renovar el Access Token
          final refreshResponse = await _dio.post(
            ApiConstants.refreshToken,
            data: {'refresh': refresh},
          );

          if (refreshResponse.statusCode == 200) {
            final newAccess = refreshResponse.data['access'];
            await _storage.saveTokens(access: newAccess, refresh: refresh);

            // Reintentar la petición original con el nuevo token
            final clonedRequest = err.requestOptions;
            clonedRequest.headers['Authorization'] = 'Bearer $newAccess';
            final retryResponse = await _dio.fetch(clonedRequest);
            return handler.resolve(retryResponse);
          }
        } catch (_) {
          // Si el refresh falló, limpiar sesión para obligar a login
          await _storage.clearSession();
        }
      }
    }

    // RN-07: Detectar error de clave temporal bloqueada
    if (err.response?.data is Map &&
        (err.response?.data['codigo'] == 'PASSWORD_TEMPORAL_LOCK' ||
         err.response?.data['error']?['codigo'] == 'PASSWORD_TEMPORAL_LOCK')) {
      await _storage.setPassTemporal(true);
      onForcePasswordChange?.call();
    }

    return handler.next(err);
  }
}
