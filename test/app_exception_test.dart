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
    test('formato RN-72 muestra el mensaje', () {
      final e = AppException.fromDioError(_err(409, {
        'error': {'codigo': 'QUINIELA_LLENA', 'mensaje': 'La quiniela esta llena'}
      }));
      expect(e.codigo, 'QUINIELA_LLENA');
      expect(e.mensaje, 'La quiniela esta llena');
    });

    test('con detalles muestra el primer campo con nombre en español', () {
      final e = AppException.fromDioError(_err(400, {
        'error': {
          'codigo': 'DATOS_INVALIDOS',
          'mensaje': 'Revisa los datos enviados.',
          'detalles': {
            'username': ['Ya existe un usuario con ese nombre.'],
            'email': ['Correo inválido.'],
          },
        }
      }));
      expect(e.codigo, 'DATOS_INVALIDOS');
      expect(e.mensaje, 'Usuario: Ya existe un usuario con ese nombre.');
      // Por campo, sin prefijo, para mostrarlos bajo cada campo (RN-72).
      expect(e.campo('username'), 'Ya existe un usuario con ese nombre.');
      expect(e.campo('email'), 'Correo inválido.');
      expect(e.campo('password'), isNull);
    });

    test('detalles sin campo (lista o non_field_errors) no antepone nombre', () {
      final lista = AppException.fromDioError(_err(400, {
        'error': {'codigo': 'DATOS_INVALIDOS', 'mensaje': 'x', 'detalles': ['Algo falló.']}
      }));
      expect(lista.mensaje, 'Algo falló.');
      final nf = AppException.fromDioError(_err(400, {
        'error': {
          'codigo': 'DATOS_INVALIDOS',
          'mensaje': 'x',
          'detalles': {'non_field_errors': ['Combinación inválida.']}
        }
      }));
      expect(nf.mensaje, 'Combinación inválida.');
    });

    test('campo desconocido usa su nombre tal cual', () {
      final e = AppException.fromDioError(_err(400, {
        'error': {'codigo': 'DATOS_INVALIDOS', 'mensaje': 'x', 'detalles': {'otro': ['Mal.']}}
      }));
      expect(e.mensaje, 'otro: Mal.');
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
