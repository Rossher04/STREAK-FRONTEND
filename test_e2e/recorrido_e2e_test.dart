// Recorrido completo de punta a punta (el flujo que se demuestra al catedrático), en UN test contra el
// backend real: registro → login → crear quiniela → ver código → segundo usuario se une → ambos
// pronostican → el admin finaliza los partidos → tabla con puntos y puesto → detalle de partido →
// estadísticas PRO bloqueadas para quien no es Pro.
//
// El paso de administrador se hace con test_e2e/backend/admin.py (misma lógica que el admin de Django,
// sin tocar el repo del backend). Ver instrucciones de ejecución en auth_e2e_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/network/dio_client.dart';
import 'package:streak_mobile/core/network/server_clock.dart';
import 'package:streak_mobile/features/auth/domain/usuario.dart';
import 'package:streak_mobile/features/pro/domain/pro_reglas.dart';
import 'package:streak_mobile/features/quinielas/application/quinielas_providers.dart';
import 'package:streak_mobile/features/quinielas/domain/quiniela_vista.dart';
import 'package:streak_mobile/features/quinielas/domain/reglas.dart';

import 'support/admin_django.dart';
import 'support/e2e_support.dart';

const _torneo = 'Torneo Recorrido E2E';

Partido _partido(QuinielaVista v, String local, String visita) => v.partidos.firstWhere(
      (p) => v.nombreEquipo(p.equipoLocalId) == local && v.nombreEquipo(p.equipoVisitaId) == visita,
    );

void main() {
  test('recorrido completo: de registrarse a ver puntos, puesto y estadísticas', () async {
    await adminDjango(['preparar-recorrido']); // deja el torneo listo para repetir el recorrido

    final a = await AppE2E.crear(); // la creadora
    final b = await AppE2E.crear(); // la segunda participante
    addTearDown(() {
      a.cerrar();
      b.cerrar();
    });

    // 1. Registro → cierre de sesión → login (el registro ya deja la sesión abierta).
    final usuarioA = await a.registrarNuevo('prof');
    expect(a.sesion.status, AuthStatus.authenticated);
    await a.auth.logout();
    expect(a.sesion.status, AuthStatus.unauthenticated);
    await a.auth.login(usuarioA, clave);
    expect(a.sesion.status, AuthStatus.authenticated);
    expect(a.sesion.user!.username, usuarioA);
    expect(a.sesion.user!.esPro, isFalse);

    // 2. Crear la quiniela en un torneo activo: la creadora queda inscrita.
    final torneo = await a.torneoActivo(_torneo);
    final q = await a.crear('Recorrido completo', torneo.id, 5);
    expect((await a.mias()).map((e) => e.id), contains(q.id));
    expect(await a.participantes(q.id), hasLength(1));

    // 3. Ver el código (lo que muestra la pantalla de compartir).
    final conCodigo = await a.container.read(quinielaProvider(q.id).future);
    expect(conCodigo.codigoUnico, q.codigoUnico);
    expect(conCodigo.codigoUnico, matches(RegExp(r'^[A-Z1-9]{6}$')));

    // 4. La segunda usuaria se registra y se une con el código.
    final usuarioB = await b.registrarNuevo('alum');
    await b.repo.unirse(q.codigoUnico);
    expect((await b.mias()).map((e) => e.id), contains(q.id));
    expect((await a.participantes(q.id)).map((p) => (p as Map)['username']), containsAll([usuarioA, usuarioB]));

    // 5. Ambas pronostican los dos partidos (abiertos según la hora del servidor).
    var vistaA = await a.repo.vista(q.id, usuarioId: a.usuarioId);
    final p1 = _partido(vistaA, 'Halcones', 'Pumas');
    final p2 = _partido(vistaA, 'Osos', 'Zorros');
    final ahora = a.container.read(serverClockProvider).ahora();
    for (final p in [p1, p2]) {
      expect(
        puedeEditarPronostico(
          estadoPartido: p.estado,
          fechaHora: p.fechaHora,
          ahoraServidor: ahora,
          torneoFinalizado: vistaA.torneoFinalizado,
        ),
        isTrue,
      );
    }
    await a.repo.guardarPronostico(q.id, p1.id, const Marcador(2, 1));
    await a.repo.guardarPronostico(q.id, p2.id, const Marcador(0, 0));
    await b.repo.guardarPronostico(q.id, p1.id, const Marcador(1, 0));
    await b.repo.guardarPronostico(q.id, p2.id, const Marcador(1, 1));

    vistaA = await a.repo.vista(q.id, usuarioId: a.usuarioId);
    expect(_partido(vistaA, 'Halcones', 'Pumas').pronostico, const Marcador(2, 1));
    expect(vistaA.filaDe(a.usuarioId)!.puntos, 0, reason: 'aún no hay partidos finalizados');

    // Antes del inicio el pronóstico ajeno está oculto; el propio se ve (RN-39).
    final antes = await a.repo.partidoDetalle(q.id, p1.id);
    final deB = antes.participantes.firstWhere((p) => p.username == usuarioB);
    expect(deB.pronostico, isNull);
    expect(antes.participantes.firstWhere((p) => p.username == usuarioA).pronostico, const Marcador(2, 1));

    // 6. El administrador finaliza los partidos: 2-1 y 3-3.
    await adminDjango(['finalizar', _torneo, 'Halcones', 'Pumas', '2', '1']);
    await adminDjango(['finalizar', _torneo, 'Osos', 'Zorros', '3', '3']);

    // 7. Tabla con puntos y puesto. A: exacto (5) + empate con diferencia (4) = 9. B: 4 + 4 = 8.
    vistaA = await a.repo.vista(q.id, usuarioId: a.usuarioId);
    expect(vistaA.tabla.map((f) => f.username), [usuarioA, usuarioB]);
    expect(vistaA.tabla.map((f) => f.puntos), [9, 8]);
    expect(vistaA.tabla.map((f) => f.posicion), [1, 2]);
    final filaA = vistaA.filaDe(a.usuarioId)!;
    expect(etiquetaPuesto(filaA.posicion, vistaA.tabla.length), '1.º de 2');
    expect(filaA.puntos, 9);

    final vistaB = await b.repo.vista(q.id, usuarioId: b.usuarioId);
    final filaB = vistaB.filaDe(b.usuarioId)!;
    expect(etiquetaPuesto(filaB.posicion, vistaB.tabla.length), '2.º de 2');
    expect(filaB.puntos, 8);

    // Finalizados: resultado, mi pronóstico y etiqueta de puntos; ya no se puede editar.
    final fin1 = _partido(vistaA, 'Halcones', 'Pumas');
    expect(fin1.estado, 'FINALIZADO');
    expect(fin1.resultado, const Marcador(2, 1));
    expect(etiquetaPuntos(estado: fin1.estado, tienePronostico: true, puntos: fin1.puntos), 'Exacto · 5 pts');
    final fin2 = _partido(vistaA, 'Osos', 'Zorros');
    expect(etiquetaPuntos(estado: fin2.estado, tienePronostico: true, puntos: fin2.puntos), 'Diferencia · 4 pts');
    expect(
      puedeEditarPronostico(
        estadoPartido: fin1.estado,
        fechaHora: fin1.fechaHora,
        ahoraServidor: a.container.read(serverClockProvider).ahora(),
        torneoFinalizado: vistaA.torneoFinalizado,
      ),
      isFalse,
    );

    // 8. Detalle de partido: ya finalizado, se ven los pronósticos de las dos con sus puntos.
    final detalle = await a.repo.partidoDetalle(q.id, p1.id);
    final porNombre = {for (final p in detalle.participantes) p.username: p};
    expect(porNombre[usuarioA]!.pronostico, const Marcador(2, 1));
    expect(porNombre[usuarioA]!.puntos, 5);
    expect(porNombre[usuarioB]!.pronostico, const Marcador(1, 0));
    expect(porNombre[usuarioB]!.puntos, 4);

    // Detalle de participante (uid = id de usuario).
    final dB = await a.repo.participanteDetalle(q.id, b.usuarioId);
    expect(dB.puntosTotales, 8);

    // 9. Estadísticas PRO: bloqueadas para quien no es Pro; para ellas el cálculo existe pero no se muestra.
    expect(puedeVerEstadisticas(a.sesion.user), isFalse);
    expect(puedeVerEstadisticas(b.sesion.user), isFalse);
    final pro = await AppE2E.crear();
    addTearDown(pro.cerrar);
    await pro.auth.login('beto', clave); // sembrado como PRO
    expect(puedeVerEstadisticas(pro.sesion.user), isTrue);
    final e = calcularEstadisticas(partidos: vistaA.partidos, tabla: vistaA.tabla, usuarioId: a.usuarioId);
    expect(e.efectividad, 100);
    expect(e.rachaActual, 2);
    expect(e.exactos, 1);

    // La sesión de A sigue usando la API real con su token (nada quedó a medias).
    expect(await a.container.read(dioProvider).get('/usuarios/me/').then((r) => r.data['username']), usuarioA);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
