import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/errors/app_exception.dart';
import 'package:streak_mobile/core/utils/password_rules.dart';

DioException _err(int status, dynamic data, {String path = '/quinielas/'}) {
  final req = RequestOptions(path: path);
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: req, statusCode: status, data: data),
  );
}

void main() {
  group('AppException.fromDioError', () {
    test('formato RN-72', () {
      final e = AppException.fromDioError(_err(403, {
        'error': {'codigo': 'PASSWORD_TEMPORAL_LOCK', 'mensaje': 'Cambia tu contraseña'}
      }));
      expect(e.codigo, 'PASSWORD_TEMPORAL_LOCK');
      expect(e.mensaje, 'Cambia tu contraseña');
    });

    test('formato viejo {"error": "texto"}', () {
      final e = AppException.fromDioError(_err(400, {'error': 'La quiniela está llena'}));
      expect(e.mensaje, 'La quiniela está llena');
    });

    test('errores por campo de DRF con nombre en español', () {
      final e = AppException.fromDioError(
          _err(400, {'username': ['A user with that username already exists.']}));
      expect(e.codigo, 'VALIDATION_ERROR');
      expect(e.mensaje, startsWith('Usuario: '));
    });

    test('login fallido se traduce', () {
      final e = AppException.fromDioError(
          _err(401, {'detail': 'No active account found'}, path: '/auth/login/'));
      expect(e.codigo, 'CREDENCIALES_INVALIDAS');
    });

    test('429 se traduce', () {
      final e = AppException.fromDioError(_err(429, {'detail': 'Request was throttled.'}));
      expect(e.codigo, 'DEMASIADOS_INTENTOS');
    });

    test('sin respuesta = error de red', () {
      final e = AppException.fromDioError(DioException(
        requestOptions: RequestOptions(path: '/torneos/'),
        type: DioExceptionType.connectionError,
      ));
      expect(e.codigo, 'NETWORK_ERROR');
    });

    test('mapa vacío no revienta', () {
      final e = AppException.fromDioError(_err(500, <String, dynamic>{}));
      expect(e.codigo, 'HTTP_500');
    });
  });

  group('PasswordRules (RN-03)', () {
    test('rechaza corta, sin número o sin letra', () {
      expect(PasswordRules.validate('abc1'), isNotNull);
      expect(PasswordRules.validate('abcdefgh'), isNotNull);
      expect(PasswordRules.validate('12345678'), isNotNull);
    });
    test('acepta 8+ con letra y número', () {
      expect(PasswordRules.validate('Clave1234'), isNull);
    });
  });
}
