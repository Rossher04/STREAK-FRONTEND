import 'package:dio/dio.dart';

/// Modelo de error estandarizado según la regla RN-72:
/// { "error": { "codigo": "...", "mensaje": "..." } }
class AppException implements Exception {
  final String codigo;
  final String mensaje;

  const AppException({
    required this.codigo,
    required this.mensaje,
  });

  @override
  String toString() => 'AppException(codigo: $codigo, mensaje: $mensaje)';

  factory AppException.fromDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const AppException(
        codigo: 'TIMEOUT_ERROR',
        mensaje: 'El servidor tardó demasiado en responder. Revisa tu conexión.',
      );
    }

    if (error.type == DioExceptionType.connectionError ||
        (error.type == DioExceptionType.unknown && error.response == null)) {
      return const AppException(
        codigo: 'NETWORK_ERROR',
        mensaje: 'Sin conexión a internet. Mostrando datos en modo lectura.',
      );
    }

    final response = error.response;

    // Mensajes de DRF/simplejwt que llegan en inglés.
    if (response?.statusCode == 429) {
      return const AppException(
        codigo: 'DEMASIADOS_INTENTOS',
        mensaje: 'Demasiados intentos. Espera un minuto y vuelve a intentarlo.',
      );
    }
    if (response?.statusCode == 401 && error.requestOptions.path.contains('/auth/login')) {
      return const AppException(
        codigo: 'CREDENCIALES_INVALIDAS',
        mensaje: 'Usuario o contraseña incorrectos.',
      );
    }
    if (response != null && response.data != null) {
      final data = response.data;

      // 1. Formato oficial exigido por RN-72
      if (data is Map<String, dynamic> && data.containsKey('error')) {
        final errorObj = data['error'];
        if (errorObj is Map<String, dynamic>) {
          return AppException(
            codigo: errorObj['codigo']?.toString() ?? 'ERROR_GENERICO',
            mensaje: errorObj['mensaje']?.toString() ?? 'Ha ocurrido un error inesperado.',
          );
        } else if (errorObj is String) {
          return AppException(codigo: 'API_ERROR', mensaje: errorObj);
        }
      }

      // 2. Soporte para formato nativo simplejwt/DRF {"detail": "..."}
      if (data is Map<String, dynamic> && data.containsKey('detail')) {
        return AppException(
          codigo: 'AUTH_ERROR',
          mensaje: data['detail'].toString(),
        );
      }

      // 3. Diccionario de errores por campo de DRF {"username": ["..."]}
      if (data is Map<String, dynamic> && data.isNotEmpty) {
        final firstKey = data.keys.first;
        final firstVal = data[firstKey];
        if (firstVal is List && firstVal.isNotEmpty) {
          final campo = _nombresCampo[firstKey] ?? firstKey;
          return AppException(
            codigo: 'VALIDATION_ERROR',
            mensaje: '$campo: ${firstVal.first}',
          );
        }
      }
    }

    return AppException(
      codigo: 'HTTP_${response?.statusCode ?? 'UNKNOWN'}',
      mensaje: 'Ocurrió un error en el servidor (${response?.statusCode ?? 'sin respuesta'}).',
    );
  }

  static const _nombresCampo = {
    'username': 'Usuario',
    'email': 'Correo',
    'password': 'Contraseña',
    'old_password': 'Contraseña actual',
    'new_password': 'Nueva contraseña',
    'telefono': 'Teléfono',
    'first_name': 'Nombre',
    'last_name': 'Apellidos',
    'nombre': 'Nombre',
    'torneo': 'Torneo',
    'max_participantes': 'Participantes',
    'non_field_errors': 'Error',
  };
}
