import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:streak_mobile/core/network/server_clock.dart';
import 'package:streak_mobile/features/quinielas/domain/quiniela_vista.dart';
import 'package:streak_mobile/features/quinielas/presentation/screens/quiniela_activa_screen.dart';
import 'package:streak_mobile/features/quinielas/presentation/widgets/partido_pendiente_card.dart';
import 'package:streak_mobile/features/quinielas/presentation/widgets/tab_pendientes.dart';

final _ahora = DateTime.utc(2026, 10, 12, 12, 0);

Map<String, dynamic> _partido(int id, int fase, DateTime inicio, {String estado = 'PROGRAMADO', Map<String, dynamic>? pron}) => {
      'id': id,
      'torneo': 1,
      'fase': fase,
      'equipo_local': 1,
      'equipo_visita': 2,
      'fecha_hora': inicio.toIso8601String(),
      'goles_local': null,
      'goles_visita': null,
      'estado': estado,
      'mi_pronostico': pron,
      'mis_puntos': 0,
    };

QuinielaVista _vista({String torneoEstado = 'ACTIVO', List<Map<String, dynamic>>? partidos, DateTime? offline}) {
  return QuinielaVista.fromRaw({
    'quiniela': {'id': 1, 'nombre': 'Mi quiniela', 'torneo': 1, 'creador': 7, 'codigo_unico': 'ABC234', 'max_participantes': 10},
    'torneo': {'id': 1, 'nombre': 'Copa Test', 'formato': 'GRUPOS_ELIMINATORIA', 'temporada': '2026', 'estado': torneoEstado},
    'equipos': [
      {'id': 1, 'nombre': 'Leones'},
      {'id': 2, 'nombre': 'Tigres'},
    ],
    'fases': [
      {'id': 1, 'nombre': 'Fase de grupos', 'orden': 1, 'tipo': 'GRUPOS'},
      {'id': 2, 'nombre': 'Semifinales', 'orden': 2, 'tipo': 'ELIMINATORIA'},
    ],
    'partidos': partidos ??
        [
          _partido(1, 1, _ahora.add(const Duration(hours: 5))), // abierto
          _partido(2, 1, _ahora.add(const Duration(minutes: 3)), pron: {'goles_local_pred': 2, 'goles_visita_pred': 1}), // cerrado (<5 min)
          _partido(3, 2, _ahora.add(const Duration(days: 2))), // eliminatoria
        ],
    'tabla': [
      {'id': 1, 'usuario': 5, 'username': 'a', 'puntos_totales': 9, 'fecha_union': '2026-01-01T00:00:00Z', 'posicion': 1},
      {'id': 2, 'usuario': 6, 'username': 'b', 'puntos_totales': 6, 'fecha_union': '2026-01-01T00:00:00Z', 'posicion': 2},
      {'id': 3, 'usuario': 7, 'username': 'yo', 'puntos_totales': 6, 'fecha_union': '2026-01-01T00:00:00Z', 'posicion': 2},
      {'id': 4, 'usuario': 8, 'username': 'd', 'puntos_totales': 0, 'fecha_union': '2026-01-01T00:00:00Z', 'posicion': 4},
    ],
  }, offlineDesde: offline);
}

Future<void> _montar(WidgetTester tester, Widget hijo) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [serverClockProvider.overrideWithValue(ServerClock(reloj: () => _ahora))],
    child: MaterialApp(home: Scaffold(body: hijo)),
  ));
  await tester.pump();
}

Finder _boton(String tooltip) =>
    find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(IconButton));

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  Widget tab(QuinielaVista v) => TabPendientes(vista: v, quinielaId: 1, onRefresh: () async {});

  testWidgets('un partido abierto se edita y uno cerrado no', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _montar(tester, tab(_vista()));

    expect(find.byType(PartidoPendienteCard), findsNWidgets(3));
    expect(find.text('GUARDAR PRONÓSTICO'), findsNWidgets(2)); // abierto + eliminatoria (sin pronóstico)
    expect(find.textContaining('Cierra a las'), findsNWidgets(2));

    // El de +3 min ya está cerrado (cierra 5 min antes) y muestra el pronóstico guardado.
    expect(find.textContaining('Cerrado · los pronósticos cierran 5 min antes'), findsOneWidget);
    expect(find.text('Tu pronóstico: 2 - 1'), findsOneWidget);

    // Steppers: en el abierto suben; en el cerrado están deshabilitados.
    final sumar = _boton('Sumar gol a Leones');
    expect(sumar, findsNWidgets(3));
    final botones = tester.widgetList<IconButton>(sumar).toList();
    expect(botones.where((b) => b.onPressed != null), hasLength(2));
  });

  testWidgets('los steppers van de 0 a 20 y habilitan guardar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _montar(tester, tab(_vista(partidos: [_partido(1, 1, _ahora.add(const Duration(hours: 5)), pron: {'goles_local_pred': 20, 'goles_visita_pred': 0})])));

    IconButton boton(String tooltip) => tester.widget<IconButton>(_boton(tooltip));
    expect(boton('Sumar gol a Leones').onPressed, isNull, reason: 'tope 20');
    expect(boton('Restar gol a Tigres').onPressed, isNull, reason: 'piso 0');
    expect(find.text('GUARDADO ✓'), findsOneWidget);

    await tester.tap(find.byTooltip('Restar gol a Leones'));
    await tester.pump();
    expect(find.text('19'), findsOneWidget);
    expect(find.text('GUARDAR PRONÓSTICO'), findsOneWidget);
  });

  testWidgets('eliminatoria muestra el aviso de los 90 minutos (RN-23)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _montar(tester, tab(_vista()));
    // Solo el partido de Semifinales lo lleva.
    expect(find.text(avisoNoventa), findsOneWidget);
    expect(find.text('SEMIFINALES'), findsOneWidget);
    expect(find.text('FASE DE GRUPOS'), findsOneWidget);
  });

  testWidgets('sin conexión no se puede guardar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _montar(tester, tab(_vista(offline: DateTime.utc(2026, 10, 12, 10))));
    expect(find.text('GUARDAR PRONÓSTICO'), findsNothing);
    expect(find.text('Sin conexión: no se puede guardar'), findsWidgets);
  });

  testWidgets('torneo finalizado: solo lectura', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _montar(tester, tab(_vista(torneoEstado: 'FINALIZADO')));
    expect(find.text('GUARDAR PRONÓSTICO'), findsNothing);
    expect(find.text('Quiniela finalizada · solo lectura'), findsWidgets);
  });

  testWidgets('sin partidos pendientes muestra el estado vacío', (tester) async {
    await _montar(tester, tab(_vista(partidos: [])));
    expect(find.text('No hay partidos pendientes por ahora.'), findsOneWidget);
  });

  testWidgets('encabezado: "2.º de 4" con empate compartido y puntos', (tester) async {
    await _montar(tester, Encabezado(vista: _vista(), usuarioId: 7));
    expect(find.text('2.º de 4'), findsOneWidget);
    expect(find.text('6 pts'), findsOneWidget);
    expect(find.text('Copa Test'), findsOneWidget);
    expect(find.text('Mi quiniela'), findsOneWidget);
  });
}
