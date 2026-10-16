// Fase 7 · Eliminar cuenta contra el backend real (DELETE /usuarios/me/). Usa un usuario creado en
// la propia prueba. Ver instrucciones de ejecución en test_e2e/README.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/errors/app_exception.dart';
import 'package:streak_mobile/features/auth/domain/usuario.dart';

import 'support/e2e_support.dart';

void main() {
  late AppE2E app;

  setUp(() async => app = await AppE2E.crear());
  tearDown(() => app.cerrar());

  test('contraseña errónea: 400 CREDENCIALES_INVALIDAS y la cuenta sigue intacta', () async {
    final u = await app.registrarNuevo('borrarmal');
    await expectLater(
      app.auth.eliminarCuenta('NoEsLaClave99'),
      throwsA(isA<AppException>().having((e) => e.codigo, 'codigo', 'CREDENCIALES_INVALIDAS')),
    );
    expect(app.sesion.status, AuthStatus.authenticated);
    expect(await app.storage.getAccessToken(), isNotNull);
    // Sigue pudiendo entrar.
    final otra = await AppE2E.crear();
    addTearDown(otra.cerrar);
    await otra.auth.login(u, clave);
    expect(otra.sesion.status, AuthStatus.authenticated);
  });

  test('contraseña correcta: 204, se borra todo lo local y el login posterior falla', () async {
    final u = await app.registrarNuevo('borrarbien');
    final id = app.sesion.user!.id;
    await app.storage.saveProIdempotencyKey(id, 'clave-de-prueba-e2e');
    await app.cache.guardar('otra_clave', {'x': 1});

    await app.auth.eliminarCuenta(clave);

    expect(app.sesion.status, AuthStatus.unauthenticated);
    expect(app.sesion.message, contains('Tu cuenta se eliminó'));
    expect(app.storage.datos, isEmpty, reason: 'tokens, usuario e Idempotency-Key borrados');
    expect(app.cache.datos, isEmpty);

    final otra = await AppE2E.crear();
    addTearDown(otra.cerrar);
    await expectLater(
      otra.auth.login(u, clave),
      throwsA(isA<AppException>().having((e) => e.codigo, 'codigo', 'CREDENCIALES_INVALIDAS')),
    );
  });
}
