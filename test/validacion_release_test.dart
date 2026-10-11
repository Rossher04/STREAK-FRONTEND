import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/config/validacion_release.dart';

void main() {
  group('problemasDeConfiguracion (release)', () {
    test('configuración completa: sin problemas', () {
      expect(
        problemasDeConfiguracion(correoSoporte: 'soporte@streak.app', apiBaseUrl: 'https://api.streak.app/api'),
        isEmpty,
      );
    });

    test('el marcador por defecto se detecta', () {
      final p = problemasDeConfiguracion(correoSoporte: marcadorCorreoSoporte, apiBaseUrl: 'https://x/api');
      expect(p, hasLength(1));
      expect(p.single, contains('SUPPORT_EMAIL'));
    });

    test('vacío, sin arroba o con corchetes también fallan', () {
      for (final c in ['', '  ', 'soporte', '[tu correo]@x.com']) {
        expect(problemasDeConfiguracion(correoSoporte: c, apiBaseUrl: 'https://x/api'), isNotEmpty, reason: c);
      }
    });

    test('sin API_BASE_URL https falla (evita apuntar al backend local)', () {
      for (final u in ['', 'http://10.0.2.2:8000/api', 'http://api.streak.app/api']) {
        final p = problemasDeConfiguracion(correoSoporte: 'a@b.co', apiBaseUrl: u);
        expect(p.single, contains('API_BASE_URL'), reason: u);
      }
    });

    test('informa los dos problemas a la vez', () {
      expect(problemasDeConfiguracion(correoSoporte: marcadorCorreoSoporte, apiBaseUrl: ''), hasLength(2));
    });
  });
}
