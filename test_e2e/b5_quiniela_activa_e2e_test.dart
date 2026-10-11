// B5 (quiniela activa) contra el backend real. Usa la quiniela "Quiniela B5" sembrada por seed.py:
// ana 12 pts (1.º), beto 8 y dani 8 (empatados en el 2.º). Ver instrucciones en auth_e2e_test.dart.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/errors/app_exception.dart';
import 'package:streak_mobile/core/network/server_clock.dart';
import 'package:streak_mobile/features/quinielas/data/quinielas_repository.dart';
import 'package:streak_mobile/features/quinielas/domain/quiniela_vista.dart';
import 'package:streak_mobile/features/quinielas/domain/reglas.dart';

import 'support/e2e_support.dart';

/// Adaptador que simula un teléfono sin conexión.
class _SinRed implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) {
    throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
  }

  @override
  void close({bool force = false}) {}
}

Partido _partido(QuinielaVista v, String local, String visita, {String? estado}) => v.partidos.firstWhere(
      (p) =>
          v.nombreEquipo(p.equipoLocalId) == local &&
          v.nombreEquipo(p.equipoVisitaId) == visita &&
          (estado == null || p.estado == estado),
    );

String _etiqueta(Partido p) =>
    etiquetaPuntos(estado: p.estado, tienePronostico: p.pronostico != null, puntos: p.puntos);

void main() {
  late AppE2E ana;
  late AppE2E beto;

  setUp(() async {
    ana = await AppE2E.crear();
    beto = await AppE2E.crear();
    await ana.auth.login('ana', clave);
    await beto.auth.login('beto', clave);
  });
  tearDown(() {
    ana.cerrar();
    beto.cerrar();
  });

  test('encabezado: torneo, quiniela, puesto y puntos salen de /tabla/', () async {
    final v = await ana.vista('Quiniela B5');
    expect(v.torneo.nombre, 'Torneo B5 E2E');
    expect(v.quiniela.nombre, 'Quiniela B5');
    expect(v.torneoFinalizado, isFalse);
    expect(v.offline, isFalse);

    final fila = v.filaDe(ana.usuarioId)!;
    expect(etiquetaPuesto(fila.posicion, v.tabla.length), '1.º de 3');
    expect(fila.puntos, 12);
  });

  test('tabla: empates comparten posición (1, 2, 2) y orden por puntos', () async {
    final v = await ana.vista('Quiniela B5');
    expect(v.tabla.map((f) => f.username), ['ana', 'beto', 'dani']);
    expect(v.tabla.map((f) => f.posicion), [1, 2, 2]);
    expect(v.tabla.map((f) => f.puntos), [12, 8, 8]);
  });

  test('partidos: nombres de equipos, fases y separación pendientes / resueltos', () async {
    final v = await ana.vista('Quiniela B5');
    expect(v.pendientes, hasLength(5)); // cierre, futuro, semi, vencido, en juego
    expect(v.resueltos, hasLength(5)); // 4 finalizados + 1 suspendido
    expect(v.pendientes.map((p) => p.estado), containsAll(['PROGRAMADO', 'EN_JUEGO']));

    final semi = _partido(v, 'Leones', 'Aguilas', estado: 'PROGRAMADO');
    expect(v.fases[semi.faseId]!.esEliminatoria, isTrue);
    final grupos = _partido(v, 'Aguilas', 'Lobos');
    expect(v.fases[grupos.faseId]!.esEliminatoria, isFalse);
  });

  test('finalizados: resultado, mi pronóstico y etiqueta de puntos 5 / 4 / 3 / 0 / no cuenta', () async {
    final v = await ana.vista('Quiniela B5');
    final exacto = _partido(v, 'Tigres', 'Lobos');
    expect(exacto.resultado, const Marcador(2, 1));
    expect(exacto.pronostico, const Marcador(2, 1));
    expect(_etiqueta(exacto), 'Exacto · 5 pts');
    expect(_etiqueta(_partido(v, 'Lobos', 'Leones')), 'Diferencia · 4 pts');
    expect(_etiqueta(_partido(v, 'Leones', 'Lobos', estado: 'FINALIZADO')), 'Resultado · 3 pts');
    expect(_etiqueta(_partido(v, 'Tigres', 'Aguilas')), 'Fallo · 0 pts');
    final susp = _partido(v, 'Aguilas', 'Tigres');
    expect(susp.estado, 'SUSPENDIDO');
    expect(_etiqueta(susp), '0 pts · no cuenta');
  });

  test('guardar y editar un pronóstico', () async {
    final id = await ana.idQuiniela('Quiniela B5');
    var v = await ana.repo.vista(id, usuarioId: ana.usuarioId);
    final futuro = _partido(v, 'Aguilas', 'Lobos');

    await ana.repo.guardarPronostico(id, futuro.id, const Marcador(1, 0));
    v = await ana.repo.vista(id, usuarioId: ana.usuarioId);
    expect(_partido(v, 'Aguilas', 'Lobos').pronostico, const Marcador(1, 0));

    await ana.repo.guardarPronostico(id, futuro.id, const Marcador(3, 2));
    v = await ana.repo.vista(id, usuarioId: ana.usuarioId);
    expect(_partido(v, 'Aguilas', 'Lobos').pronostico, const Marcador(3, 2));
  });

  test('cierre: el backend rechaza PRONOSTICOS_CERRADOS y la app decide con la hora del servidor', () async {
    final id = await ana.idQuiniela('Quiniela B5');
    final v = await ana.repo.vista(id, usuarioId: ana.usuarioId);
    final reloj = ana.container.read(serverClockProvider);
    expect(reloj.sincronizado, isTrue, reason: 'el header Date debe haber llegado');
    expect(reloj.desfase.abs(), lessThan(const Duration(seconds: 5)));
    final ahora = reloj.ahora();

    bool editable(Partido p) => puedeEditarPronostico(
          estadoPartido: p.estado,
          fechaHora: p.fechaHora,
          ahoraServidor: ahora,
          torneoFinalizado: v.torneoFinalizado,
        );

    // Partido que ya empezó pero sigue PROGRAMADO: el backend lo rechaza.
    final vencido = _partido(v, 'Lobos', 'Aguilas');
    expect(editable(vencido), isFalse);
    await expectLater(
      ana.repo.guardarPronostico(id, vencido.id, const Marcador(1, 1)),
      throwsA(isA<AppException>().having((e) => e.codigo, 'codigo', 'PRONOSTICOS_CERRADOS')),
    );

    // A ~4 min del inicio el backend aún aceptaría, pero la app ya lo cierra (RN-37: 5 min antes).
    final cierre = _partido(v, 'Leones', 'Tigres');
    expect(cierre.fechaHora.difference(ahora), lessThan(const Duration(minutes: 5)));
    expect(editable(cierre), isFalse);

    expect(editable(_partido(v, 'Aguilas', 'Lobos')), isTrue);
    expect(editable(_partido(v, 'Lobos', 'Tigres')), isFalse, reason: 'EN_JUEGO');
    expect(editable(_partido(v, 'Tigres', 'Lobos')), isFalse, reason: 'FINALIZADO');
  });

  test('detalle de partido: pronósticos ocultos antes del inicio y visibles después', () async {
    final id = await ana.idQuiniela('Quiniela B5');
    final v = await ana.repo.vista(id, usuarioId: ana.usuarioId);

    // Aún no empieza: el de beto existe en la BD pero el backend lo oculta (null).
    final futuro = _partido(v, 'Aguilas', 'Lobos');
    final oculto = await ana.repo.partidoDetalle(id, futuro.id);
    expect(oculto.participantes.map((p) => p.username), containsAll(['ana', 'beto', 'dani']));
    final deBeto = oculto.participantes.firstWhere((p) => p.username == 'beto');
    expect(deBeto.pronostico, isNull);
    expect(deBeto.puntos, 0);
    expect(futuro.fechaHora.isAfter(ana.container.read(serverClockProvider).ahora()), isTrue);

    // Ya jugado: se ven los de todos, con sus puntos.
    final exacto = _partido(v, 'Tigres', 'Lobos');
    final visible = await ana.repo.partidoDetalle(id, exacto.id);
    final porNombre = {for (final p in visible.participantes) p.username: p};
    expect(porNombre['ana']!.pronostico, const Marcador(2, 1));
    expect(porNombre['ana']!.puntos, 5);
    expect(porNombre['beto']!.pronostico, const Marcador(3, 0));
    expect(porNombre['beto']!.puntos, 3);
    expect(porNombre['dani']!.puntos, 5);
    expect(visible.partido.resultado, const Marcador(2, 1));
  });

  test('detalle de participante (uid = id de usuario): sus partidos y puntos', () async {
    final id = await ana.idQuiniela('Quiniela B5');
    final v = await ana.repo.vista(id, usuarioId: ana.usuarioId);
    final fila = v.tabla.firstWhere((f) => f.username == 'beto');

    final d = await ana.repo.participanteDetalle(id, fila.usuarioId);
    expect(d.username, 'beto');
    expect(d.puntosTotales, 8);
    expect(d.partidos, hasLength(10)); // todos los partidos aunque no haya pronóstico

    final exacto = d.partidos.firstWhere((p) => p.resultado == const Marcador(2, 1));
    expect(exacto.pronostico, const Marcador(3, 0));
    expect(exacto.puntos, 3);
    // El pronóstico futuro de beto sigue oculto para ana.
    expect(d.partidos.where((p) => p.estado == 'PROGRAMADO').every((p) => p.pronostico == null), isTrue);

    // Y él sí ve el suyo.
    final propio = await beto.repo.participanteDetalle(id, beto.usuarioId);
    expect(propio.partidos.any((p) => p.estado == 'PROGRAMADO' && p.pronostico == const Marcador(2, 2)), isTrue);
  });

  test('quien no es miembro recibe NO_ENCONTRADO', () async {
    final extra = await AppE2E.crear();
    addTearDown(extra.cerrar);
    await extra.registrarNuevo('ajeno');
    final id = await ana.idQuiniela('Quiniela B5');
    await expectLater(
      extra.repo.vista(id, usuarioId: extra.usuarioId),
      throwsA(isA<AppException>().having((e) => e.codigo, 'codigo', 'NO_ENCONTRADO')),
    );
  });

  test('torneo finalizado: la vista lo indica y nada es editable (RN-33)', () async {
    final v = await ana.vista('Quiniela Clausura');
    expect(v.torneoFinalizado, isTrue);
    final ahora = ana.container.read(serverClockProvider).ahora();
    for (final p in v.partidos) {
      expect(
        puedeEditarPronostico(
          estadoPartido: p.estado,
          fechaHora: p.fechaHora,
          ahoraServidor: ahora,
          torneoFinalizado: v.torneoFinalizado,
        ),
        isFalse,
      );
    }
  });

  test('sin conexión (RN-74): devuelve lo último guardado con la hora de la copia', () async {
    final id = await ana.idQuiniela('Quiniela B5');
    final enLinea = await ana.repo.vista(id, usuarioId: ana.usuarioId);
    expect(enLinea.offline, isFalse);
    expect(ana.cache.datos.keys, contains('u${ana.usuarioId}_quiniela_$id'));

    final sinRed = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:8000/api'))..httpClientAdapter = _SinRed();
    final repoOffline = QuinielasRepository(sinRed, ana.cache);
    final guardada = await repoOffline.vista(id, usuarioId: ana.usuarioId);
    expect(guardada.offline, isTrue);
    expect(guardada.offlineDesde!.isBefore(DateTime.now().toUtc().add(const Duration(seconds: 1))), isTrue);
    expect(guardada.tabla.map((f) => f.username), enLinea.tabla.map((f) => f.username));
    expect(guardada.partidos, hasLength(enLinea.partidos.length));

    // Otro usuario en el mismo teléfono no ve la copia de ana.
    await expectLater(
      repoOffline.vista(id, usuarioId: ana.usuarioId + 999),
      throwsA(isA<AppException>().having((e) => e.codigo, 'codigo', 'NETWORK_ERROR')),
    );
  });
}
