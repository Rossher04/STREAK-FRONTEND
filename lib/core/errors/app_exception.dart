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

    if (error.type == DioExceptionType.connectionError) {
      return const AppException(
        codigo: 'NETWORK_ERROR',
        mensaje: 'Sin conexión a internet. Mostrando datos en modo lectura.',
      );
    }

    final response = error.response;
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
      if (data is Map<String, dynamic>) {
        final firstKey = data.keys.first;
        final firstVal = data[firstKey];
        if (firstVal is List && firstVal.isNotEmpty) {
          return AppException(
            codigo: 'VALIDATION_ERROR',
            mensaje: '$firstKey: ${firstVal.first}',
          );
        }
      }
    }

    return AppException(
      codigo: 'HTTP_${response?.statusCode ?? 'UNKNOWN'}',
      mensaje: 'Ocurrió un error en el servidor (${response?.statusCode ?? 'sin respuesta'}).',
    );
  }
}
