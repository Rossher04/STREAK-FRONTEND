import 'package:dio/dio.dart';

/// Modelo de error estandarizado según la regla RN-72:
/// { "error": { "codigo": "...", "mensaje": "...", "detalles": {campo: [..]}? } }
class AppException implements Exception {
  final String codigo;
  final String mensaje;

  /// Errores por campo de `detalles` (RN-72): nombre del campo de la API → primer mensaje, sin prefijo.
  /// Las pantallas los muestran bajo su campo (`CampoTexto.errorServidor`).
  final Map<String, String> campos;

  const AppException({
    required this.codigo,
    required this.mensaje,
    this.campos = const {},
  });

  /// Error por campo de la API para [campo] (p. ej. 'username'), o null.
  String? campo(String campo) => campos[campo];

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
    final data = response?.data;
    if (data is Map && data['error'] is Map) {
      final errorObj = data['error'] as Map;
      final codigo = errorObj['codigo']?.toString() ?? 'ERROR_GENERICO';
      var mensaje = errorObj['mensaje']?.toString() ?? 'Ha ocurrido un error inesperado.';
      // Errores por campo: se muestra el primero con su nombre en español.
      final detalle = _primerDetalle(errorObj['detalles']);
      if (detalle != null) mensaje = detalle;
      // RN-06: la contraseña temporal vence a las 24 horas.
      if (codigo == 'PASSWORD_TEMPORAL_VENCIDA') {
        mensaje = 'Tu contraseña temporal venció. Pide una nueva en "¿Olvidaste tu contraseña?".';
      }
      return AppException(codigo: codigo, mensaje: mensaje, campos: _porCampo(errorObj['detalles']));
    }

    return AppException(
      codigo: 'HTTP_${response?.statusCode ?? 'UNKNOWN'}',
      mensaje: 'Ocurrió un error en el servidor (${response?.statusCode ?? 'sin respuesta'}).',
    );
  }

  /// Recorre `detalles` ({campo: [mensajes]}, anidado o lista) y devuelve el primer mensaje.
  static String? _primerDetalle(dynamic detalles, [String? campo]) {
    if (detalles is String) {
      final nombre = campo == null ? null : (_nombresCampo[campo] ?? campo);
      return (nombre == null || campo == 'non_field_errors') ? detalles : '$nombre: $detalles';
    }
    if (detalles is List) {
      for (final item in detalles) {
        final r = _primerDetalle(item, campo);
        if (r != null) return r;
      }
    }
    if (detalles is Map) {
      for (final entry in detalles.entries) {
        final r = _primerDetalle(entry.value, entry.key.toString());
        if (r != null) return r;
      }
    }
    return null;
  }

  static Map<String, String> _porCampo(dynamic detalles) {
    if (detalles is! Map) return const {};
    final r = <String, String>{};
    for (final e in detalles.entries) {
      final m = _primerDetalle(e.value);
      if (m != null) r[e.key.toString()] = m;
    }
    return r;
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
    'uid': 'Enlace',
    'token': 'Enlace',
    'foto': 'Foto',
    'codigo': 'Código',
    'codigo_unico': 'Código',
  };
}
