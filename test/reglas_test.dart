import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/network/server_clock.dart';
import 'package:streak_mobile/features/quinielas/domain/reglas.dart';

void main() {
  group('etiquetaPuesto (RN-53)', () {
    test('sin total', () => expect(etiquetaPuesto(1), '1.º'));
    test('con total', () => expect(etiquetaPuesto(3, 12), '3.º de 12'));
    test('empates comparten posición (1, 1, 3)', () {
      expect([1, 1, 3].map((p) => etiquetaPuesto(p, 3)), ['1.º de 3', '1.º de 3', '3.º de 3']);
    });
  });

  group('etiquetaPuntos', () {
    String e(int pts, {String estado = 'FINALIZADO', bool pron = true}) =>
        etiquetaPuntos(estado: estado, tienePronostico: pron, puntos: pts);

    test('5, 4, 3 y 0', () {
      expect(e(5), 'Exacto · 5 pts');
      expect(e(4), 'Diferencia · 4 pts');
      expect(e(3), 'Resultado · 3 pts');
      expect(e(0), 'Fallo · 0 pts');
    });
    test('suspendido o cancelado no cuenta (RN-22)', () {
      expect(e(0, estado: 'SUSPENDIDO'), '0 pts · no cuenta');
      expect(e(0, estado: 'CANCELADO', pron: false), '0 pts · no cuenta');
    });
    test('sin pronóstico', () => expect(e(0, pron: false), 'Sin pronóstico · 0 pts'));
  });

  group('esFaseEliminatoria (heurística)', () {
    test('palabras clave en tipo o nombre', () {
      expect(esFaseEliminatoria('ELIMINATORIA', 'x'), isTrue);
      expect(esFaseEliminatoria('', 'Octavos de final'), isTrue);
      expect(esFaseEliminatoria('', 'Cuartos'), isTrue);
      expect(esFaseEliminatoria('', 'Semifinales'), isTrue);
      expect(esFaseEliminatoria('', 'Final'), isTrue);
    });
    test('sin distinguir tildes ni mayúsculas', () {
      expect(esFaseEliminatoria('eliminación', ''), isTrue);
    });
    test('liga y grupos no son eliminatoria', () {
      expect(esFaseEliminatoria('LIGA', 'Jornada 1'), isFalse);
      expect(esFaseEliminatoria('GRUPOS', 'Fase de grupos'), isFalse);
    });
  });

  group('esFaseEliminatoria con el tipo normalizado del backend', () {
    test('el tipo manda sobre el nombre', () {
      expect(esFaseEliminatoria('LIGA', 'Ronda final'), isFalse);
      expect(esFaseEliminatoria('GRUPOS', 'Semifinal de grupo'), isFalse);
      expect(esFaseEliminatoria('ELIMINATORIA', 'Ronda 2'), isTrue);
    });
    test('tipo desconocido: heurística de respaldo', () {
      expect(esFaseEliminatoria('KO', 'Cuartos de final'), isTrue);
      expect(esFaseEliminatoria('', 'Jornada 3'), isFalse);
    });
  });

  group('cierre del servidor y texto "Cierra en…"', () {
    final inicio = DateTime.utc(2026, 10, 12, 20, 0);
    test('cierre_pronosticos del servidor tiene prioridad', () {
      final servidor = inicio.subtract(const Duration(minutes: 30));
      expect(cierreDe(inicio, cierreServidor: servidor), servidor);
      expect(cierreDe(inicio), inicio.subtract(const Duration(minutes: 5)));
      expect(
        puedeEditarPronostico(
          estadoPartido: 'PROGRAMADO',
          fechaHora: inicio,
          ahoraServidor: inicio.subtract(const Duration(minutes: 20)),
          torneoFinalizado: false,
          cierreServidor: servidor,
        ),
        isFalse,
      );
    });
    test('pronosticos_abiertos=false del servidor cierra', () {
      expect(
        puedeEditarPronostico(
          estadoPartido: 'PROGRAMADO',
          fechaHora: inicio,
          ahoraServidor: inicio.subtract(const Duration(hours: 2)),
          torneoFinalizado: false,
          abiertoServidor: false,
        ),
        isFalse,
      );
    });
    test('textos', () {
      final cierre = inicio.subtract(const Duration(minutes: 5));
      expect(textoCierraEn(cierre, cierre.subtract(const Duration(hours: 1, minutes: 20))), 'Cierra en 1 h 20 min');
      expect(textoCierraEn(cierre, cierre.subtract(const Duration(hours: 3))), 'Cierra en 3 h');
      expect(textoCierraEn(cierre, cierre.subtract(const Duration(minutes: 8))), 'Cierra en 8 min');
      expect(textoCierraEn(cierre, cierre.subtract(const Duration(seconds: 20))), 'Cierra en menos de 1 min');
      expect(textoCierraEn(cierre, cierre.subtract(const Duration(hours: 25))), isNull);
      expect(textoCierraEn(cierre, cierre), isNull);
    });
  });

  group('puedeEditarPronostico (RN-37, RN-33)', () {
    final inicio = DateTime.utc(2026, 10, 12, 20, 0);
    bool editable({
      String estado = 'PROGRAMADO',
      Duration antes = const Duration(minutes: 30),
      bool finalizado = false,
    }) =>
        puedeEditarPronostico(
          estadoPartido: estado,
          fechaHora: inicio,
          ahoraServidor: inicio.subtract(antes),
          torneoFinalizado: finalizado,
        );

    test('con tiempo de sobra', () => expect(editable(), isTrue));
    test('a 5 min exactos ya está cerrado', () => expect(editable(antes: const Duration(minutes: 5)), isFalse));
    test('a 5 min y 1 s sigue abierto', () {
      expect(editable(antes: const Duration(minutes: 5, seconds: 1)), isTrue);
    });
    test('estado distinto de PROGRAMADO', () {
      for (final e in ['EN_JUEGO', 'FINALIZADO', 'SUSPENDIDO', 'CANCELADO']) {
        expect(editable(estado: e), isFalse, reason: e);
      }
    });
    test('torneo finalizado', () => expect(editable(finalizado: true), isFalse));
  });

  group('textoCierre (hora local, con día)', () {
    String t(DateTime ahoraLocal, DateTime cierreLocal) =>
        textoCierre(cierre: cierreLocal.toUtc(), ahora: ahoraLocal.toUtc());

    test('hoy', () {
      expect(t(DateTime(2026, 10, 11, 10), DateTime(2026, 10, 11, 17, 13)), 'Cierra hoy a las 17:13');
    });
    test('mañana', () {
      expect(t(DateTime(2026, 10, 11, 10), DateTime(2026, 10, 12, 9, 5)), 'Cierra mañana a las 09:05');
    });
    test('otro día: dice el día de la semana y el número (el caso que parecía "hoy")', () {
      expect(t(DateTime(2026, 10, 11, 17, 0), DateTime(2026, 10, 13, 17, 13)), 'Cierra mar 13 · 17:13');
      expect(t(DateTime(2026, 10, 11, 17, 0), DateTime(2026, 10, 14, 11, 55)), 'Cierra mié 14 · 11:55');
    });
    test('cruzar la medianoche es mañana aunque falten pocos minutos', () {
      expect(t(DateTime(2026, 10, 11, 23, 59), DateTime(2026, 10, 12, 0, 5)), 'Cierra mañana a las 00:05');
    });
    test('cambio de mes', () {
      expect(t(DateTime(2026, 10, 31, 12), DateTime(2026, 11, 1, 8)), 'Cierra mañana a las 08:00');
      expect(t(DateTime(2026, 10, 31, 12), DateTime(2026, 11, 2, 8)), 'Cierra lun 2 · 08:00');
    });
    test('acepta instantes en UTC y compara los días en hora local', () {
      final ahora = DateTime(2026, 10, 11, 10);
      final cierre = DateTime(2026, 10, 11, 17, 13);
      expect(textoCierre(cierre: cierre.toUtc(), ahora: ahora.toUtc()), 'Cierra hoy a las 17:13');
      expect(cierre.toUtc().isUtc, isTrue);
    });
  });

  group('cuentaRegresiva', () {
    final inicio = DateTime.utc(2026, 10, 12, 20, 0);
    test('más de una hora: no hay cuenta', () {
      expect(cuentaRegresiva(inicio, inicio.subtract(const Duration(hours: 3))), isNull);
    });
    test('en la última hora cuenta hasta el cierre (5 min antes)', () {
      expect(cuentaRegresiva(inicio, inicio.subtract(const Duration(minutes: 15))), '10:00');
      expect(cuentaRegresiva(inicio, inicio.subtract(const Duration(minutes: 30, seconds: 5))), '25:05');
    });
    test('ya cerrado: null', () {
      expect(cuentaRegresiva(inicio, inicio.subtract(const Duration(minutes: 4))), isNull);
    });
  });

  group('ServerClock (reloj del servidor)', () {
    test('calcula el desfase con el header Date', () {
      final local = DateTime.utc(2026, 10, 12, 12, 0, 0);
      final reloj = ServerClock(reloj: () => local);
      // El servidor va 10 min por delante del teléfono.
      reloj.actualizar('Mon, 12 Oct 2026 12:10:00 GMT');
      expect(reloj.sincronizado, isTrue);
      expect(reloj.desfase, const Duration(minutes: 10));
      expect(reloj.ahora(), DateTime.utc(2026, 10, 12, 12, 10));
    });
    test('teléfono adelantado da desfase negativo', () {
      final reloj = ServerClock(reloj: () => DateTime.utc(2026, 10, 12, 12, 0, 0));
      reloj.actualizar('Mon, 12 Oct 2026 11:55:00 GMT');
      expect(reloj.desfase, const Duration(minutes: -5));
    });
    test('header nulo o inválido conserva el desfase', () {
      final reloj = ServerClock(reloj: () => DateTime.utc(2026, 10, 12, 12, 0, 0));
      expect(reloj.sincronizado, isFalse);
      reloj.actualizar(null);
      reloj.actualizar('no es una fecha');
      expect(reloj.sincronizado, isFalse);
      expect(reloj.desfase, Duration.zero);
    });
  });
}
