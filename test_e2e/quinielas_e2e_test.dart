// B3 y B4 contra el backend real: crear, unirse, mis quinielas e historial.
// Ver instrucciones de ejecución en auth_e2e_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/errors/app_exception.dart';
import 'package:streak_mobile/core/network/dio_client.dart';
import 'package:streak_mobile/features/quinielas/application/quinielas_providers.dart';
import 'package:streak_mobile/features/quinielas/domain/models.dart';
import 'package:streak_mobile/features/quinielas/presentation/screens/unirse_quiniela_screen.dart';

import 'support/e2e_support.dart';

Matcher _error(String codigo) =>
    isA<AppException>().having((e) => e.codigo, 'codigo', codigo);

extension on AppE2E {
  Future<List<Quiniela>> mias() => container.read(quinielasRepositoryProvider).mias();

  Future<List<dynamic>> participantes(int quinielaId) async {
    final resp = await container.read(dioProvider).get('/quinielas/$quinielaId/participantes/');
    return resp.data as List<dynamic>;
  }

  Future<Quiniela> crear(String nombre, int torneoId, int max) => container
      .read(quinielasRepositoryProvider)
      .crear(nombre: nombre, torneoId: torneoId, maxParticipantes: max);

  Future<Torneo> torneoActivo(String nombre) async {
    final torneos = await container.read(quinielasRepositoryProvider).torneos();
    return torneos.firstWhere((t) => t.nombre == nombre && t.esActivo);
  }
}

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
    expect(q.codigoUnico, isNot(matches(RegExp('[0OIL]'))));
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
    await repoB.unirse(q.codigoUnico);
    await expectLater(repoB.unirse(q.codigoUnico), throwsA(_error('YA_PARTICIPA')));
    expect(await a.participantes(q.id), hasLength(2));
  });

  test('QUINIELA_LLENA cuando se alcanza max_participantes', () async {
    await a.registrarNuevo('llena');
    final torneo = await a.torneoActivo('Liga E2E En Curso');
    final q = await a.crear('Solo dos', torneo.id, 2);

    await b.registrarNuevo('llena2');
    await b.container.read(quinielasRepositoryProvider).unirse(q.codigoUnico);

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
    expect(mensajeUnirse(error!), 'No existe ninguna quiniela con ese código.');
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
    expect(await a.container.read(misQuinielasProvider.future), isEmpty);
    final activos = await a.container.read(torneosActivosProvider.future);
    expect(activos.every((t) => t.esActivo), isTrue);
    expect(activos, isNotEmpty);
  });
}
