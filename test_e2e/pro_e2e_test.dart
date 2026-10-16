// B6 (Plan Pro) contra el backend real SIN Stripe configurado. El pago completo con tarjeta de
// prueba (4242 4242 4242 4242) requiere claves de prueba de Stripe: ver "Prueba manual del pago"
// en test_e2e/README.md. Ver instrucciones de ejecución en auth_e2e_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/errors/app_exception.dart';
import 'package:streak_mobile/features/pro/application/pago_pro_controller.dart';
import 'package:streak_mobile/features/pro/domain/pro_reglas.dart';
import 'package:streak_mobile/features/quinielas/application/quinielas_providers.dart';

import 'support/admin_django.dart';
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
    expect(estado.mensaje, mensajePago(const AppException(codigo: 'PAGOS_NO_CONFIGURADOS', mensaje: '')));
    // La clave de idempotencia queda guardada para el próximo intento.
    final id = app.sesion.user!.id;
    expect(await app.storage.getProIdempotencyKey(id), isNotNull);
  });

  test('GET /pro/estado/: importe, moneda y topes del plan (sustituyen a la constante de la app)', () async {
    await app.registrarNuevo('precio');
    final e = await app.container.read(estadoProProvider.future);
    expect(e.esPro, isFalse);
    expect(e.montoCentavos, 500);
    expect(e.moneda, 'USD');
    expect(e.importeConMoneda, r'$5.00 USD');
    expect(e.pagoUnico, isTrue);
    expect(e.maxParticipantes, 100);
    expect(e.maxParticipantesGratis, 50);
  });

  test('GET /pro/pago-pendiente/ sin compras: pago null; revisarPendiente no cambia nada', () async {
    await app.registrarNuevo('sinpendiente');
    expect(await app.container.read(proRepositoryProvider).pagoPendiente(), isNull);
    app.container.listen(pagoProControllerProvider, (_, __) {});
    await app.container.read(pagoProControllerProvider.notifier).revisarPendiente();
    expect(app.container.read(pagoProControllerProvider).pendiente, isNull);
    expect(await app.storage.getProIdempotencyKey(app.sesion.user!.id), isNull);
  });

  test('con una compra pendiente y Stripe sin configurar: pago-pendiente y cancelar dan 503; '
      'el historial la lista como PENDIENTE', () async {
    final u = await app.registrarNuevo('pendiente');
    await adminDjango(['pago-pendiente', u]);
    final repo = app.container.read(proRepositoryProvider);
    final pagos = await repo.pagos();
    expect(pagos.single.estado, 'PENDIENTE');
    expect(pagos.single.monto, '5.00');
    await expectLater(repo.pagoPendiente(),
        throwsA(isA<AppException>().having((e) => e.codigo, 'codigo', 'PAGOS_NO_CONFIGURADOS')));
    await expectLater(repo.cancelarPago(pagos.single.id),
        throwsA(isA<AppException>().having((e) => e.codigo, 'codigo', 'PAGOS_NO_CONFIGURADOS')));
    // La pantalla de pago no se rompe: revisarPendiente ignora el 503 y "Pagar" muestra el error claro.
    app.container.listen(pagoProControllerProvider, (_, __) {});
    final ctrl = app.container.read(pagoProControllerProvider.notifier);
    await ctrl.revisarPendiente();
    await ctrl.pagar();
    final estado = app.container.read(pagoProControllerProvider);
    expect(estado.fase, FasePago.error);
    expect(estado.codigo, 'PAGOS_NO_CONFIGURADOS');
  });

  test('POST /pro/pagos/{id}/cancelar/ de un pago ajeno o inexistente: 404', () async {
    await app.registrarNuevo('ajeno');
    await expectLater(app.container.read(proRepositoryProvider).cancelarPago(999999),
        throwsA(isA<AppException>().having((e) => e.codigo, 'codigo', 'NO_ENCONTRADO')));
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
