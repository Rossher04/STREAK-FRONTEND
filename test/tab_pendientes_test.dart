import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/errors/app_exception.dart';
import 'package:streak_mobile/core/network/server_clock.dart';
import 'package:streak_mobile/core/storage/cache_store.dart';
import 'package:streak_mobile/core/theme/streak_theme.dart';
import 'package:streak_mobile/core/widgets/botones.dart';
import 'package:streak_mobile/features/quinielas/application/quinielas_providers.dart';
import 'package:streak_mobile/features/quinielas/data/quinielas_repository.dart';
import 'package:streak_mobile/features/quinielas/domain/quiniela_vista.dart';
import 'package:streak_mobile/features/quinielas/presentation/screens/quiniela_activa_screen.dart';
import 'package:streak_mobile/features/quinielas/presentation/widgets/partido_pendiente_card.dart';
import 'package:streak_mobile/features/quinielas/presentation/widgets/quiniela_widgets.dart';
import 'package:streak_mobile/features/quinielas/presentation/widgets/tab_pendientes.dart';

// Mediodía LOCAL: los textos "hoy / mañana / mié 14" no dependen de la zona horaria de quien corra la prueba.
final _ahora = DateTime(2026, 10, 12, 12).toUtc();

Map<String, dynamic> _partido(int id, int fase, DateTime inicio,
        {String estado = 'PROGRAMADO', Map<String, dynamic>? pron, DateTime? cierre}) =>
    {
      'id': id,
      'torneo': 1,
      'fase': fase,
      'equipo_local': 1,
      'equipo_visita': 2,
      'fecha_hora': inicio.toIso8601String(),
      'cierre_pronosticos': (cierre ?? inicio.subtract(const Duration(minutes: 5))).toIso8601String(),
      'goles_local': null,
      'goles_visita': null,
      'estado': estado,
      'mi_pronostico': pron,
      'estado_pronostico': pron == null ? 'NO_REGISTRADO' : 'VISIBLE',
      'mis_puntos': 0,
    };

QuinielaVista _vista({
  String torneoEstado = 'ACTIVO',
  List<Map<String, dynamic>>? partidos,
  DateTime? offline,
  bool conResumen = true,
  List<Map<String, dynamic>>? fases,
}) {
  return QuinielaVista.fromRaw({
    'quiniela': {
      'id': 1,
      'nombre': 'Mi quiniela',
      'torneo': 1,
      'creador': 7,
      'codigo_unico': 'ABC234',
      'max_participantes': 10,
      if (conResumen) ...{'torneo_nombre': 'Copa Test', 'cantidad_inscritos': 4, 'mis_puntos': 6, 'mi_posicion': 2},
    },
    'torneo': {'id': 1, 'nombre': 'Copa Test', 'formato': 'GRUPOS_ELIMINATORIA', 'temporada': '2026', 'estado': torneoEstado},
    'equipos': [
      {'id': 1, 'nombre': 'Leones'},
      {'id': 2, 'nombre': 'Tigres'},
    ],
    'fases': fases ??
        [
          {'id': 1, 'nombre': 'Fase de grupos', 'orden': 1, 'tipo': 'GRUPOS'},
          {'id': 2, 'nombre': 'Semifinales', 'orden': 2, 'tipo': 'ELIMINATORIA'},
        ],
    'partidos': partidos ??
        [
          _partido(1, 1, _ahora.add(const Duration(hours: 5))), // abierto
          _partido(2, 1, _ahora.add(const Duration(minutes: 3)), pron: {'goles_local_pred': 2, 'goles_visita_pred': 1}), // cerrado
          _partido(3, 2, _ahora.add(const Duration(days: 2))), // eliminatoria
        ],
    'tabla': [
      {'id': 1, 'usuario': 5, 'username': 'a', 'puntos_totales': 9, 'posicion': 1},
      {'id': 2, 'usuario': 6, 'username': 'b', 'puntos_totales': 6, 'posicion': 2},
      {'id': 3, 'usuario': 7, 'username': 'yo', 'puntos_totales': 6, 'posicion': 2},
      {'id': 4, 'usuario': 8, 'username': 'd', 'puntos_totales': 0, 'posicion': 4},
    ],
  }, offlineDesde: offline);
}

/// Repositorio falso: guarda en memoria y falla para los partidos indicados.
class _RepoFalso extends QuinielasRepository {
  _RepoFalso({this.fallan = const {}}) : super(Dio(), MemoryCacheStore());

  final Map<int, AppException> fallan;
  final enviados = <int, Marcador>{};

  @override
  Future<void> guardarPronostico(int quinielaId, int partidoId, Marcador m) async {
    final e = fallan[partidoId];
    if (e != null) throw e;
    enviados[partidoId] = m;
  }
}

Future<void> _montar(WidgetTester tester, Widget hijo, {QuinielasRepository? repo}) async {
  tester.view.physicalSize = const Size(840, 3600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      serverClockProvider.overrideWithValue(ServerClock(reloj: () => _ahora)),
      if (repo != null) quinielasRepositoryProvider.overrideWithValue(repo),
      quinielaVistaProvider.overrideWith((ref, id) async => _vista()),
    ],
    child: MaterialApp(theme: StreakTheme.dark(), home: Scaffold(body: SingleChildScrollView(child: hijo))),
  ));
  await tester.pump();
}

Widget _tab(QuinielaVista v) => TabPendientes(vista: v, quinielaId: 1);

BotonPrimario _boton(WidgetTester t) => t.widget<BotonPrimario>(find.byType(BotonPrimario));

void main() {
  testWidgets('chips de cierre, casillas editables solo en los abiertos y cerrado con su pronóstico', (tester) async {
    await _montar(tester, _tab(_vista()));

    expect(find.byType(PartidoPendienteCard), findsNWidgets(3));
    expect(find.text('Cierra en 4 h 55 min'), findsOneWidget, reason: '+5 h: cierra 5 min antes');
    expect(find.text('Cierra mié 14 · 11:55'), findsOneWidget, reason: '+2 días: dice el día');
    expect(find.text('Cerrado'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4), reason: 'dos partidos abiertos × 2 casillas');
    // El cerrado muestra lo guardado, sin casillas editables.
    expect(find.bySemanticsLabel(RegExp('Tu pronóstico para Leones')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('usa cierre_pronosticos del servidor (RN-37)', (tester) async {
    // Empieza en 20 min, pero el servidor dice que ya cerró hace 1 min.
    await _montar(
        tester,
        _tab(_vista(partidos: [
          _partido(1, 1, _ahora.add(const Duration(minutes: 20)), cierre: _ahora.subtract(const Duration(minutes: 1))),
        ])));
    expect(find.text('Cerrado'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('en juego: chip "En juego" y sin casillas', (tester) async {
    await _montar(tester, _tab(_vista(partidos: [_partido(1, 1, _ahora.subtract(const Duration(minutes: 10)), estado: 'EN_JUEGO')])));
    expect(find.text('En juego'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('eliminatoria muestra "Cuenta el tiempo reglamentario (90 min)" (RN-23)', (tester) async {
    await _montar(tester, _tab(_vista()));
    expect(find.text(avisoNoventa), findsOneWidget);
    expect(find.text('Semifinales'), findsOneWidget);
    expect(find.text('Fase de grupos'), findsOneWidget);
  });

  testWidgets('el tipo normalizado del backend manda: LIGA llamada "Gran final" no lleva el aviso', (tester) async {
    await _montar(
        tester,
        _tab(_vista(
          fases: [
            {'id': 1, 'nombre': 'Gran final', 'orden': 1, 'tipo': 'LIGA'},
          ],
          partidos: [_partido(1, 1, _ahora.add(const Duration(hours: 5)))],
        )));
    expect(find.text(avisoNoventa), findsNothing);
  });

  testWidgets('UN solo botón amarillo, deshabilitado hasta que se escribe algo', (tester) async {
    await _montar(tester, _tab(_vista()), repo: _RepoFalso());
    expect(find.byType(BotonPrimario), findsOneWidget);
    expect(find.text(textoGuardarPronosticos), findsOneWidget);
    expect(_boton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(0), '2');
    await tester.pump();
    expect(_boton(tester).onPressed, isNotNull);
  });

  testWidgets('las casillas solo aceptan 0 a 20 (RN-35)', (tester) async {
    await _montar(tester, _tab(_vista()));
    final campo = find.byType(TextField).at(0);
    await tester.enterText(campo, '20');
    await tester.pump();
    expect(find.text('20'), findsOneWidget);
    await tester.enterText(campo, '21');
    await tester.pump();
    expect(find.text('21'), findsNothing);
    expect(const GolesFormatter().formatEditUpdate(const TextEditingValue(text: '7'), const TextEditingValue(text: '75')).text, '7');
  });

  testWidgets('guarda todos los cambiados; un fallo parcial se informa y conserva lo escrito', (tester) async {
    final repo = _RepoFalso(fallan: {
      3: const AppException(codigo: 'PRONOSTICOS_CERRADOS', mensaje: 'El plazo para pronosticar este partido ha terminado.'),
    });
    await _montar(tester, _tab(_vista()), repo: repo);
    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), '2');
    await tester.enterText(campos.at(1), '1');
    await tester.enterText(campos.at(2), '0');
    await tester.enterText(campos.at(3), '3');
    await tester.pump();

    await tester.tap(find.text(textoGuardarPronosticos));
    await tester.pump();
    await tester.pump();

    expect(repo.enviados, {1: const Marcador(2, 1)}, reason: 'un POST por partido; el 3 falló');
    expect(find.text('No se guardó: el plazo para este partido ya cerró.'), findsOneWidget);
    expect(find.text('Se guardaron 1 de 2. No se guardó: Leones – Tigres.'), findsOneWidget);
    // Lo escrito en el que falló sigue ahí.
    expect(tester.widget<TextField>(campos.at(2)).controller!.text, '0');
    expect(tester.widget<TextField>(campos.at(3)).controller!.text, '3');
  });

  testWidgets('marcador a medias: pide completar los dos y no envía nada', (tester) async {
    final repo = _RepoFalso();
    await _montar(tester, _tab(_vista()), repo: repo);
    await tester.enterText(find.byType(TextField).at(0), '2');
    await tester.pump();
    await tester.tap(find.text(textoGuardarPronosticos));
    await tester.pump();
    expect(repo.enviados, isEmpty);
    expect(find.text('Completa los dos marcadores.'), findsOneWidget);
  });

  testWidgets('sin conexión: el botón queda deshabilitado', (tester) async {
    await _montar(tester, _tab(_vista(offline: DateTime.utc(2026, 10, 12, 10))));
    await tester.enterText(find.byType(TextField).at(0), '2');
    await tester.pump();
    expect(_boton(tester).onPressed, isNull);
    expect(find.text('Sin conexión: no se puede guardar'), findsOneWidget);
  });

  testWidgets('torneo finalizado: solo lectura, sin casillas ni botón', (tester) async {
    await _montar(tester, _tab(_vista(torneoEstado: 'FINALIZADO')));
    expect(find.byType(BotonPrimario), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('sin partidos pendientes muestra el estado vacío', (tester) async {
    await _montar(tester, _tab(_vista(partidos: [])));
    expect(find.text('No hay partidos pendientes por ahora.'), findsOneWidget);
  });

  group('cabecera', () {
    testWidgets('usa el resumen del backend: torneo · participantes, código, puesto y puntos', (tester) async {
      await _montar(tester, CabeceraQuiniela(vista: _vista(), usuarioId: 7));
      expect(find.text('Mi quiniela'), findsOneWidget);
      expect(find.text('Copa Test · 4 participantes'), findsOneWidget);
      expect(find.text('ABC234'), findsOneWidget);
      expect(find.text('2.º'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('En juego'), findsNothing);
    });

    testWidgets('sin resumen recurre a /tabla/ (empate compartido 2.º)', (tester) async {
      await _montar(tester, CabeceraQuiniela(vista: _vista(conResumen: false), usuarioId: 7));
      expect(tester.widget<Text>(find.byKey(const ValueKey('puesto'))).data, '2.º');
      expect(tester.widget<Text>(find.byKey(const ValueKey('puntos'))).data, '6');
    });

    testWidgets('chip "En juego" si hay un partido en juego', (tester) async {
      await _montar(
          tester,
          CabeceraQuiniela(
              vista: _vista(partidos: [_partido(1, 1, _ahora.subtract(const Duration(minutes: 10)), estado: 'EN_JUEGO')]),
              usuarioId: 7));
      expect(find.text('En juego'), findsOneWidget);
    });
  });
}
