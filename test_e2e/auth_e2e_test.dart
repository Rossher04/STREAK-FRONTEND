// Prueba de punta a punta de B1 contra un backend real.
// Levantar el backend:  powershell -File test_e2e/backend/run_backend.ps1
// Ejecutar:  flutter test test_e2e --dart-define=API_BASE_URL=http://127.0.0.1:8000/api -j 1
// Datos sembrados por test_e2e/backend/seed.py: ana / Clave1234x, beto (Pro) / Clave1234x,
// caro / Temporal123 con pass_temporal_flag = true.
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/errors/app_exception.dart';
import 'package:streak_mobile/features/auth/application/auth_controller.dart';
import 'package:streak_mobile/features/auth/domain/usuario.dart';

import 'support/e2e_support.dart';

void main() {
  late AppE2E app;

  setUp(() async => app = await AppE2E.crear());
  tearDown(() => app.cerrar());

  test('login normal carga el perfil real desde /usuarios/me/', () async {
    await app.auth.login('ana', clave);
    expect(app.sesion.status, AuthStatus.authenticated);
    final u = app.sesion.user!;
    expect(u.username, 'ana');
    expect(u.id, greaterThan(0));
    expect(u.email, 'ana@e2e.test');
    expect(u.firstName, 'Ana');
    expect(u.esPro, isFalse);
    expect(app.storage.datos['access'], isNotNull);
  });

  test('usuario Pro trae es_pro = true', () async {
    await app.auth.login('beto', clave);
    expect(app.sesion.user?.esPro, isTrue);
  });

  test('credenciales malas dan error en español', () async {
    await expectLater(
      app.auth.login('ana', 'incorrecta1'),
      throwsA(isA<AppException>().having((e) => e.codigo, 'codigo', 'CREDENCIALES_INVALIDAS')),
    );
    expect(app.sesion.status, AuthStatus.unauthenticated);
  });

  test('contraseña temporal: cambio forzado y re-login automático (RN-07)', () async {
    await app.auth.login('caro', 'Temporal123');
    expect(app.sesion.status, AuthStatus.needsPasswordChange);
    final tokenViejo = app.storage.datos['access'];

    await app.auth.cambiarPassword(oldPassword: 'Temporal123', newPassword: 'Nueva12345');
    // El backend invalidó los tokens; la app entró de nuevo sola con la nueva clave.
    expect(app.sesion.status, AuthStatus.authenticated);
    expect(app.sesion.user?.username, 'caro');
    expect(app.sesion.user?.id, greaterThan(0));
    expect(app.storage.datos['access'], isNot(tokenViejo));

    // La clave temporal ya no sirve; la nueva sí.
    await app.auth.logout();
    await expectLater(app.auth.login('caro', 'Temporal123'), throwsA(isA<AppException>()));
    await app.auth.login('caro', 'Nueva12345');
    expect(app.sesion.status, AuthStatus.authenticated);
  });

  test('cambio con clave actual incorrecta muestra el error por campo', () async {
    final u = await app.registrarNuevo('cambio');
    await expectLater(
      app.auth.cambiarPassword(oldPassword: 'equivocada1', newPassword: 'Nueva12345'),
      throwsA(isA<AppException>().having((e) => e.mensaje, 'mensaje', startsWith('Contraseña actual: '))),
    );
    expect(app.sesion.status, AuthStatus.authenticated);
    expect(app.sesion.user?.username, u);
  });

  test('registro con usuario repetido da el error por campo en español', () async {
    await expectLater(
      app.auth.register(
        username: 'ana',
        email: 'otra@e2e.test',
        password: clave,
        firstName: 'A',
        lastName: 'B',
      ),
      throwsA(isA<AppException>().having((e) => e.mensaje, 'mensaje', startsWith('Usuario: '))),
    );
  });

  test('recuperar: sin correo configurado el backend responde CORREO_NO_CONFIGURADO (503)', () async {
    // En local no hay Resend ni PASSWORD_RESET_URL.
    await expectLater(
      app.auth.recuperar('ana@e2e.test'),
      throwsA(isA<AppException>().having((e) => e.codigo, 'codigo', 'CORREO_NO_CONFIGURADO')),
    );
  });

  test('restablecer con enlace inválido da TOKEN_INVALIDO', () async {
    await expectLater(
      app.auth.restablecer(uid: 'MQ', token: 'token-falso', newPassword: 'Nueva12345'),
      throwsA(isA<AppException>().having((e) => e.codigo, 'codigo', 'TOKEN_INVALIDO')),
    );
  });

  test('access token vencido se renueva solo con el refresh', () async {
    await app.auth.login('ana', clave);
    final refreshValido = app.storage.datos['refresh'];
    app.storage.datos['access'] = 'token-invalido';

    // restoreSession hace una llamada autenticada: el interceptor debe renovar.
    final user = await app.container.read(authRepositoryProvider).restoreSession();
    expect(user, isNotNull);
    expect(user!.usuario.username, 'ana');
    expect(user.offlineDesde, isNull);
    expect(app.storage.datos['access'], isNot('token-invalido'));
    expect(app.storage.datos['refresh'], refreshValido);
  });

  test('refresh inválido cierra la sesión', () async {
    await app.auth.login('ana', clave);
    app.storage.datos['access'] = 'token-invalido';
    app.storage.datos['refresh'] = 'refresh-invalido';
    final user = await app.container.read(authRepositoryProvider).restoreSession();
    expect(user, isNull);
    expect(app.sesion.status, AuthStatus.unauthenticated);
  });
}
