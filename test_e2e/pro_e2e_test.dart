// B6 (Plan Pro) contra el backend real SIN Stripe configurado. El pago completo con tarjeta de
// prueba (4242 4242 4242 4242) requiere claves de prueba de Stripe: ver "Prueba manual del pago"
// en test_e2e/README.md. Ver instrucciones de ejecución en auth_e2e_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/errors/app_exception.dart';
import 'package:streak_mobile/features/pro/application/pago_pro_controller.dart';
import 'package:streak_mobile/features/pro/domain/pro_reglas.dart';
import 'package:streak_mobile/features/quinielas/application/quinielas_providers.dart';

import 'support/e2e_support.dart';

void main() {
  late AppE2E app;

  setUp(() async => app = await AppE2E.crear());
  tearDown(() => app.cerrar());

  test('GET /pro/estado/ y es_pro del perfil: ana no es Pro y beto sí', () async {
    await app.auth.login('ana', clave);
    expect(await app.container.read(proRepositoryProvider).esPro(), isFalse);
    expect(app.sesion.user?.esPro, isFalse);

    final otro = await AppE2E.crear();
    addTearDown(otro.cerrar);
    await otro.auth.login('beto', clave);
    expect(await otro.container.read(proRepositoryProvider).esPro(), isTrue);
    expect(otro.sesion.user?.esPro, isTrue);
  });

  test('GET /pro/pagos/ vacío para un usuario sin pagos', () async {
    await app.registrarNuevo('sinpagos');
    expect(await app.container.read(proRepositoryProvider).pagos(), isEmpty);
    expect(await app.container.read(pagosProProvider.future), isEmpty);
  });

  test('POST /pro/suscribir/ sin Stripe configurado da 503 PAGOS_NO_CONFIGURADOS', () async {
    await app.registrarNuevo('suscribe');
    await expectLater(
      app.container.read(proRepositoryProvider).iniciarPago(generarClaveIdempotencia()),
      throwsA(isA<AppException>().having((e) => e.codigo, 'codigo', 'PAGOS_NO_CONFIGURADOS')),
    );
  });

  test('el controlador muestra el mensaje del 503 y no abre el PaymentSheet', () async {
    await app.registrarNuevo('ctrl');
    final contenedor = app.container;
    final ctrl = contenedor.read(pagoProControllerProvider.notifier);
    contenedor.listen(pagoProControllerProvider, (_, __) {});
    // El PaymentSheet real no se abre porque el backend responde 503 antes.
    await ctrl.pagar();
    final estado = contenedor.read(pagoProControllerProvider);
    expect(estado.fase, FasePago.error);
    expect(estado.mensaje, 'Los pagos no están disponibles por ahora. Inténtalo más tarde.');
    // La clave de idempotencia queda guardada para el próximo intento.
    final id = app.sesion.user!.id;
    expect(await app.storage.getProIdempotencyKey(id), isNotNull);
  });

  test('estadísticas PRO con datos reales de la quiniela B5 (ana)', () async {
    await app.auth.login('ana', clave);
    final mias = await app.container.read(quinielasRepositoryProvider).mias();
    final id = mias.firstWhere((q) => q.nombre == 'Quiniela B5').id;
    final vista = await app.container.read(quinielasRepositoryProvider).vista(id, usuarioId: app.sesion.user!.id);

    final e = calcularEstadisticas(partidos: vista.partidos, tabla: vista.tabla, usuarioId: app.sesion.user!.id);
    // FINALIZADOS en orden: exacto (5), diferencia (4), fallo (0), resultado (3).
    expect(e.resueltosConPronostico, 4);
    expect(e.conPuntos, 3);
    expect(e.efectividad, 75);
    expect(e.exactos, 1);
    expect(e.rachaActual, 1);
    expect(e.mejorRacha, 2);
    expect(e.misPuntos, 12);
    expect(e.promedioTabla, closeTo(28 / 3, 0.001));
    expect(e.diferenciaConPromedio, closeTo(12 - 28 / 3, 0.001));
  });
}
