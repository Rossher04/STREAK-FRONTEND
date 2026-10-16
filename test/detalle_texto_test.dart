import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/features/quinielas/domain/quiniela_vista.dart';
import 'package:streak_mobile/features/quinielas/presentation/screens/partido_detalle_screen.dart';
import 'package:streak_mobile/features/quinielas/presentation/screens/participante_detalle_screen.dart';

Map<String, dynamic> _fila(int usuario, String estado, {Map<String, dynamic>? pron}) => {
      'id': usuario,
      'usuario': usuario,
      'username': 'u$usuario',
      'foto': null,
      'es_pro': usuario == 2,
      'puntos_totales': 0,
      'fecha_union': '2026-01-01T00:00:00Z',
      'estado_pronostico': estado,
      'pronostico': pron,
      'puntos_obtenidos': pron?['puntos_obtenidos'] ?? 0,
    };

Map<String, dynamic> _partido(int id, String estado, DateTime inicio, {String? estadoPron}) => {
      'id': id,
      'fase': 1,
      'equipo_local': 1,
      'equipo_visita': 2,
      'fecha_hora': inicio.toIso8601String(),
      'estado': estado,
      'goles_local': null,
      'goles_visita': null,
      if (estadoPron != null) 'estado_pronostico': estadoPron,
      'pronostico': null,
    };

void main() {
  group('pronóstico de otro participante (RN-39): OCULTO y NO_REGISTRADO son distintos', () {
    test('textos', () {
      expect(textoPronosticoParticipante(EstadoPronostico.visible, const Marcador(2, 1)), '2 – 1');
      expect(textoPronosticoParticipante(EstadoPronostico.oculto, null), 'Oculto hasta el inicio');
      expect(textoPronosticoParticipante(EstadoPronostico.noRegistrado, null), 'Sin pronóstico');
    });

    test('se leen del campo estado_pronostico del backend, no de la hora', () {
      final d = PartidoDetalle.fromJson({
        'partido': _partido(1, 'PROGRAMADO', DateTime.utc(2030)),
        'participantes': [
          _fila(1, 'VISIBLE', pron: {'goles_local_pred': 1, 'goles_visita_pred': 0, 'puntos_obtenidos': 0}),
          _fila(2, 'OCULTO'),
          _fila(3, 'NO_REGISTRADO'),
        ],
      });
      expect(d.participantes.map((p) => p.estado),
          [EstadoPronostico.visible, EstadoPronostico.oculto, EstadoPronostico.noRegistrado]);
      expect(d.participantes[1].esPro, isTrue);
      expect(d.participantes[0].pronostico, const Marcador(1, 0));
    });

    test('sin el campo (respuesta antigua) no se inventa "oculto"', () {
      expect(EstadoPronostico.desde(null, hayMarcador: false), EstadoPronostico.noRegistrado);
      expect(EstadoPronostico.desde(null, hayMarcador: true), EstadoPronostico.visible);
    });
  });

  test('detalle de participante: jugados primero (recientes arriba) y luego próximos', () {
    final base = DateTime.utc(2026, 10, 12);
    final lista = [
      Partido.fromJson(_partido(1, 'PROGRAMADO', base.add(const Duration(days: 3)), estadoPron: 'OCULTO')),
      Partido.fromJson(_partido(2, 'FINALIZADO', base.subtract(const Duration(days: 3)))),
      Partido.fromJson(_partido(3, 'PROGRAMADO', base.add(const Duration(days: 1)), estadoPron: 'OCULTO')),
      Partido.fromJson(_partido(4, 'SUSPENDIDO', base.subtract(const Duration(days: 1)))),
    ];
    expect(ordenarParaParticipante(lista).map((p) => p.id), [4, 2, 3, 1]);
    expect(lista.first.estadoPronostico, EstadoPronostico.oculto);
  });
}
