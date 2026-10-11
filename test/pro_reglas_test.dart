import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/features/pro/domain/pro_reglas.dart';
import 'package:streak_mobile/features/auth/domain/usuario.dart';
import 'package:streak_mobile/features/quinielas/domain/quiniela_vista.dart';

Partido _p(int id, int dia, {String estado = 'FINALIZADO', int? pts, Marcador? pron = const Marcador(1, 0)}) => Partido(
      id: id,
      faseId: 1,
      equipoLocalId: 1,
      equipoVisitaId: 2,
      fechaHora: DateTime.utc(2026, 10, dia),
      estado: estado,
      golesLocal: 1,
      golesVisita: 0,
      pronostico: pts == null ? null : pron,
      puntos: pts ?? 0,
    );

FilaTabla _f(int usuario, int pts) =>
    FilaTabla(participanteId: usuario, usuarioId: usuario, username: 'u$usuario', puntos: pts, posicion: 1);

void main() {
  test('puedeVerEstadisticas: solo con plan PRO', () {
    expect(puedeVerEstadisticas(null), isFalse);
    expect(puedeVerEstadisticas(const Usuario(id: 1, username: 'a', email: 'a@a')), isFalse);
    expect(puedeVerEstadisticas(const Usuario(id: 1, username: 'a', email: 'a@a', esPro: true)), isTrue);
  });

  group('planEspera (backoff)', () {
    test('suma exactamente 30 s y empieza en 1 s', () {
      final e = planEspera();
      expect(e.first, const Duration(seconds: 1));
      expect(e.fold(Duration.zero, (a, b) => a + b), const Duration(seconds: 30));
    });
    test('crece y se acota al máximo (salvo el último tramo)', () {
      final e = planEspera();
      expect(e.take(4), [
        const Duration(seconds: 1),
        const Duration(seconds: 2),
        const Duration(seconds: 4),
        const Duration(seconds: 6),
      ]);
      expect(e.every((d) => d <= const Duration(seconds: 6)), isTrue);
    });
    test('respeta otros parámetros', () {
      final e = planEspera(total: const Duration(seconds: 5), inicial: const Duration(seconds: 2));
      expect(e, [const Duration(seconds: 2), const Duration(seconds: 3)]);
    });
  });

  group('generarClaveIdempotencia', () {
    test('cumple el formato del backend (8 a 128 letras, números, guiones)', () {
      final k = generarClaveIdempotencia();
      expect(k, matches(RegExp(r'^[A-Za-z0-9_-]{8,128}$')));
      expect(k.length, 32);
    });
    test('es distinta en cada intento y reproducible con la misma semilla', () {
      expect(generarClaveIdempotencia(), isNot(generarClaveIdempotencia()));
      expect(generarClaveIdempotencia(Random(1)), generarClaveIdempotencia(Random(1)));
    });
  });

  group('calcularEstadisticas', () {
    test('efectividad = partidos con puntos / resueltos con pronóstico', () {
      final e = calcularEstadisticas(
        partidos: [_p(1, 1, pts: 5), _p(2, 2, pts: 0), _p(3, 3, pts: 3), _p(4, 4, pts: 0)],
        tabla: [_f(7, 8)],
        usuarioId: 7,
      );
      expect(e.resueltosConPronostico, 4);
      expect(e.conPuntos, 2);
      expect(e.efectividad, 50);
      expect(e.exactos, 1);
    });

    test('sin datos: efectividad nula y racha 0', () {
      final e = calcularEstadisticas(partidos: [], tabla: [], usuarioId: 7);
      expect(e.efectividad, isNull);
      expect(e.rachaActual, 0);
      expect(e.promedioTabla, isNull);
      expect(e.diferenciaConPromedio, isNull);
    });

    test('racha actual cuenta hacia atrás desde el último partido y se rompe con un 0', () {
      final e = calcularEstadisticas(
        partidos: [_p(1, 1, pts: 5), _p(2, 2, pts: 0), _p(3, 3, pts: 3), _p(4, 4, pts: 4), _p(5, 5, pts: 5)],
        tabla: [],
        usuarioId: 7,
      );
      expect(e.rachaActual, 3);
      expect(e.mejorRacha, 3);
    });

    test('mejor racha puede ser anterior a la actual', () {
      final e = calcularEstadisticas(
        partidos: [_p(1, 1, pts: 5), _p(2, 2, pts: 4), _p(3, 3, pts: 3), _p(4, 4, pts: 0), _p(5, 5, pts: 3)],
        tabla: [],
        usuarioId: 7,
      );
      expect(e.rachaActual, 1);
      expect(e.mejorRacha, 3);
    });

    test('el orden de la lista no importa (se ordena por fecha)', () {
      final e = calcularEstadisticas(
        partidos: [_p(3, 3, pts: 3), _p(1, 1, pts: 0), _p(2, 2, pts: 5)],
        tabla: [],
        usuarioId: 7,
      );
      expect(e.rachaActual, 2);
    });

    test('finalizado sin pronóstico vale 0 y rompe la racha, pero no cuenta en la efectividad', () {
      final e = calcularEstadisticas(
        partidos: [_p(1, 1, pts: 5), _p(2, 2), _p(3, 3, pts: 4)],
        tabla: [],
        usuarioId: 7,
      );
      expect(e.rachaActual, 1);
      expect(e.resueltosConPronostico, 2);
      expect(e.efectividad, 100);
    });

    test('suspendido, cancelado y pendientes no cuentan', () {
      final e = calcularEstadisticas(
        partidos: [
          _p(1, 1, pts: 5),
          _p(2, 2, estado: 'SUSPENDIDO', pts: 0),
          _p(3, 3, estado: 'CANCELADO', pts: 0),
          _p(4, 4, estado: 'PROGRAMADO', pts: 0),
        ],
        tabla: [],
        usuarioId: 7,
      );
      expect(e.resueltosConPronostico, 1);
      expect(e.rachaActual, 1);
    });

    test('promedio de la tabla y diferencia con mis puntos', () {
      final e = calcularEstadisticas(
        partidos: [],
        tabla: [_f(7, 12), _f(8, 8), _f(9, 4)],
        usuarioId: 7,
      );
      expect(e.misPuntos, 12);
      expect(e.promedioTabla, 8);
      expect(e.diferenciaConPromedio, 4);
    });
  });
}
