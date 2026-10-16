// B3 y B4 contra el backend real: crear, unirse, mis quinielas e historial.
// Ver instrucciones de ejecución en auth_e2e_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/errors/app_exception.dart';
import 'package:streak_mobile/features/quinielas/application/quinielas_providers.dart';
import 'package:streak_mobile/features/quinielas/presentation/screens/unirse_quiniela_screen.dart';

import 'support/e2e_support.dart';

Matcher _error(String codigo) => isA<AppException>().having((e) => e.codigo, 'codigo', codigo);

void main() {
  late AppE2E a; // creador
  late AppE2E b; // otro usuario

  setUp(() async {
    a = await AppE2E.crear();
    b = await AppE2E.crear();
  });
  tearDown(() {
    a.cerrar();
    b.cerrar();
  });

  test('torneos: los activos se pueden elegir y el borrador no se publica', () async {
    await a.registrarNuevo('tor');
    final torneos = await a.container.read(quinielasRepositoryProvider).torneos();
    final activos = torneos.where((t) => t.esActivo).map((t) => t.nombre);
    expect(activos, containsAll(['Liga E2E En Curso', 'Copa E2E Nueva']));
    expect(torneos.map((t) => t.nombre), isNot(contains('Borrador E2E')));
    expect(torneos.any((t) => t.esFinalizado), isTrue);
  });

  test('crear: el creador queda inscrito y la quiniela aparece en /mias', () async {
    final usuario = await a.registrarNuevo('crea');
    expect(await a.mias(), isEmpty);

    final torneo = await a.torneoActivo('Liga E2E En Curso');
    final q = await a.crear('Mi quiniela e2e', torneo.id, 8);
    expect(q.codigoUnico, matches(RegExp(r'^[A-Z1-9]{6}$')));
    expect(q.codigoUnico, isNot(matches(RegExp('[0OIL1]'))), reason: 'RN-27: el backend ya no genera el 1');
    expect(q.maxParticipantes, 8);
    expect(q.torneoId, torneo.id);
    expect(q.creadorId, a.sesion.user!.id);

    final mias = await a.mias();
    expect(mias.map((e) => e.id), [q.id]);
    final parts = await a.participantes(q.id);
    expect(parts, hasLength(1));
    expect((parts.first as Map)['username'], usuario);

    final detalle = await a.container.read(quinielasRepositoryProvider).detalle(q.id);
    expect(detalle.codigoUnico, q.codigoUnico);
  });

  test('crear en un torneo que no está activo se rechaza con mensaje por campo', () async {
    await a.registrarNuevo('inact');
    final torneos = await a.container.read(quinielasRepositoryProvider).torneos();
    final finalizado = torneos.firstWhere((t) => t.esFinalizado);
    await expectLater(
      a.crear('No debería', finalizado.id, 5),
      throwsA(isA<AppException>().having((e) => e.mensaje, 'mensaje', startsWith('Torneo: '))),
    );
  });

  test('unirse con otro usuario: aparece en su /mias y en los participantes', () async {
    await a.registrarNuevo('dueno');
    final torneo = await a.torneoActivo('Copa E2E Nueva');
    final q = await a.crear('Para unirse', torneo.id, 5);

    final segundo = await b.registrarNuevo('socio');
    expect(await b.mias(), isEmpty);
    // El código se envía en mayúsculas aunque se escriba en minúsculas.
    await b.container.read(quinielasRepositoryProvider).unirse(q.codigoUnico.toLowerCase());

    expect((await b.mias()).map((e) => e.id), [q.id]);
    final nombres = (await a.participantes(q.id)).map((p) => (p as Map)['username']);
    expect(nombres, contains(segundo));
    expect(nombres, hasLength(2));
  });

  test('YA_PARTICIPA: el creador y el que ya se unió no pueden repetir', () async {
    await a.registrarNuevo('dup');
    final torneo = await a.torneoActivo('Liga E2E En Curso');
    final q = await a.crear('Doble ingreso', torneo.id, 5);
    final repoA = a.container.read(quinielasRepositoryProvider);
    await expectLater(repoA.unirse(q.codigoUnico), throwsA(_error('YA_PARTICIPA')));

    await b.registrarNuevo('dup2');
    final repoB = b.container.read(quinielasRepositoryProvider);
    await repoB.unirse(q.codigoUnico, aceptarIngresoTardio: true);
    await expectLater(repoB.unirse(q.codigoUnico), throwsA(_error('YA_PARTICIPA')));
    expect(await a.participantes(q.id), hasLength(2));
  });

  test('QUINIELA_LLENA cuando se alcanza max_participantes', () async {
    await a.registrarNuevo('llena');
    final torneo = await a.torneoActivo('Liga E2E En Curso');
    final q = await a.crear('Solo dos', torneo.id, 2);

    await b.registrarNuevo('llena2');
    await b.container.read(quinielasRepositoryProvider).unirse(q.codigoUnico, aceptarIngresoTardio: true);

    final c = await AppE2E.crear();
    addTearDown(c.cerrar);
    await c.registrarNuevo('llena3');
    final error = await c.container
        .read(quinielasRepositoryProvider)
        .unirse(q.codigoUnico)
        .then<AppException?>((_) => null, onError: (Object e) => e as AppException);
    expect(error?.codigo, 'QUINIELA_LLENA');
    expect(mensajeUnirse(error!), 'Esta quiniela ya está llena.');
    expect(await c.mias(), isEmpty);
  });

  test('código inexistente da NO_ENCONTRADO con mensaje claro', () async {
    await a.registrarNuevo('noexiste');
    final error = await a.container
        .read(quinielasRepositoryProvider)
        .unirse('ZZZZZZ')
        .then<AppException?>((_) => null, onError: (Object e) => e as AppException);
    expect(error?.codigo, 'NO_ENCONTRADO');
    expect(mensajeUnirse(error!), startsWith('No existe ninguna quiniela con ese código.'));
  });

  test('historial: solo quinielas de torneos finalizados; /mias conserva todas', () async {
    await a.auth.login('ana', clave);
    final repo = a.container.read(quinielasRepositoryProvider);
    final historial = await repo.historial();
    expect(historial.map((q) => q.nombre), ['Quiniela Clausura']);
    expect((await repo.mias()).map((q) => q.nombre), contains('Quiniela Clausura'));

    // Una quiniela de un torneo activo no entra al historial.
    final torneo = await a.torneoActivo('Copa E2E Nueva');
    final nueva = await a.crear('Activa de ana', torneo.id, 5);
    expect((await repo.historial()).map((q) => q.id), isNot(contains(nueva.id)));
    expect((await repo.mias()).map((q) => q.id), contains(nueva.id));
  });

  test('providers: misQuinielasProvider y torneosActivosProvider leen la API real', () async {
    await a.registrarNuevo('prov');
    expect((await a.container.read(misQuinielasProvider.future)).items, isEmpty);
    final activos = await a.container.read(torneosActivosProvider.future);
    expect(activos.every((t) => t.esActivo), isTrue);
    expect(activos, isNotEmpty);
  });

  // ---- Fase 3: validar-codigo, ingreso tardío y topes (backend a86fe6d) ----

  test('validar-codigo sin partidos cerrados: no requiere confirmación ni inscribe', () async {
    await a.registrarNuevo('val');
    final q = await a.crear('Copa sin cerrar', (await a.torneoActivo('Copa E2E Nueva')).id, 6);
    await b.registrarNuevo('val2');
    final v = await b.repo.validarCodigo(q.codigoUnico.toLowerCase());
    expect(v.quinielaId, q.id);
    expect(v.nombre, 'Copa sin cerrar');
    expect(v.torneoNombre, 'Copa E2E Nueva');
    expect((v.cantidadInscritos, v.maxParticipantes), (1, 6));
    expect(v.requiereConfirmacion, isFalse);
    expect(v.partidosCerrados, 0);
    expect(await b.mias(), isEmpty, reason: 'la consulta previa no inscribe');
    await b.repo.unirse(q.codigoUnico);
    expect((await b.mias()).map((e) => e.id), [q.id]);
  });

  test('validar-codigo con partidos cerrados: confirmación obligatoria, sin penalización', () async {
    await a.registrarNuevo('tard');
    final q = await a.crear('Liga empezada', (await a.torneoActivo('Liga E2E En Curso')).id, 12);
    await b.registrarNuevo('tard2');
    final v = await b.repo.validarCodigo(q.codigoUnico);
    expect(v.requiereConfirmacion, isTrue);
    expect(v.ingresoTardio, isTrue);
    expect(v.partidosCerrados, 1);
    expect(v.penalizacionPuntos, 0);
    expect(v.quinielaId, q.id);

    await expectLater(b.repo.unirse(q.codigoUnico), throwsA(_error('CONFIRMACION_INGRESO_TARDIO')));
    expect(await b.mias(), isEmpty);
    await b.repo.unirse(q.codigoUnico, aceptarIngresoTardio: true);
    expect((await b.mias()).map((e) => e.id), [q.id]);
    expect(await a.participantes(q.id), hasLength(2));
  });

  test('validar-codigo: errores reales del backend con mensaje claro', () async {
    await a.registrarNuevo('verr');
    final q = await a.crear('Para errores', (await a.torneoActivo('Copa E2E Nueva')).id, 2);
    Future<AppException?> err(AppE2E app, String codigo) =>
        app.repo.validarCodigo(codigo).then<AppException?>((_) => null, onError: (Object e) => e as AppException);

    expect((await err(a, 'ZZZZZZ'))?.codigo, 'NO_ENCONTRADO');
    final ya = await err(a, q.codigoUnico);
    expect(ya?.codigo, 'YA_PARTICIPA');
    expect(mensajeUnirse(ya!), startsWith('Ya participas'));

    await b.registrarNuevo('verr2');
    await b.repo.unirse(q.codigoUnico);
    final c = await AppE2E.crear();
    addTearDown(c.cerrar);
    await c.registrarNuevo('verr3');
    expect((await err(c, q.codigoUnico))?.codigo, 'QUINIELA_LLENA');
    expect((await err(c, 'CLAU25'))?.codigo, 'TORNEO_NO_ACTIVO');
  });

  test('tope RN-26: 51 se rechaza sin Pro con mensaje por campo; Pro llega a 100', () async {
    await a.registrarNuevo('tope');
    final torneo = await a.torneoActivo('Copa E2E Nueva');
    await expectLater(
      a.crear('Demasiados', torneo.id, 51),
      throwsA(isA<AppException>().having((e) => e.mensaje, 'mensaje', startsWith('Participantes: '))),
    );
    expect((await a.crear('Cincuenta', torneo.id, 50)).maxParticipantes, 50);

    await b.auth.login('beto', clave);
    expect((await b.crear('Cien', torneo.id, 100)).maxParticipantes, 100);
    await expectLater(b.crear('Ciento uno', torneo.id, 101), throwsA(_error('DATOS_INVALIDOS')));
  });
}
