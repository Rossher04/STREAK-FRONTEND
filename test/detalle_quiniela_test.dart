import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/errors/app_exception.dart';
import 'package:streak_mobile/core/theme/streak_theme.dart';
import 'package:streak_mobile/core/widgets/chips.dart';
import 'package:streak_mobile/core/widgets/estructura.dart';
import 'package:streak_mobile/core/widgets/streak_icon.dart';
import 'package:streak_mobile/features/auth/application/auth_controller.dart';
import 'package:streak_mobile/features/auth/domain/usuario.dart';
import 'package:streak_mobile/features/quinielas/application/quinielas_providers.dart';
import 'package:streak_mobile/features/quinielas/domain/models.dart';
import 'package:streak_mobile/features/quinielas/domain/quiniela_vista.dart';
import 'package:streak_mobile/features/quinielas/presentation/screens/historial_screen.dart';
import 'package:streak_mobile/features/quinielas/presentation/screens/partido_detalle_screen.dart';
import 'package:streak_mobile/features/quinielas/presentation/widgets/tab_finalizados.dart';
import 'package:streak_mobile/features/quinielas/presentation/widgets/tab_tabla.dart';

Map<String, dynamic> _resuelto(int id, String estado, {List<int>? goles, List<int>? pron, int puntos = 0}) => {
      'id': id,
      'fase': 1,
      'equipo_local': 1,
      'equipo_visita': 2,
      'fecha_hora': DateTime.utc(2026, 10, 10, 18).subtract(Duration(days: id)).toIso8601String(),
      'estado': estado,
      'goles_local': goles?[0],
      'goles_visita': goles?[1],
      'mi_pronostico': pron == null ? null : {'goles_local_pred': pron[0], 'goles_visita_pred': pron[1]},
      'estado_pronostico': pron == null ? 'NO_REGISTRADO' : 'VISIBLE',
      'mis_puntos': puntos,
    };

QuinielaVista _vista({List<Map<String, dynamic>> partidos = const [], List<Map<String, dynamic>>? tabla}) =>
    QuinielaVista.fromRaw({
      'quiniela': {'id': 1, 'nombre': 'Q', 'torneo': 1, 'creador': 7, 'codigo_unico': 'ABC234', 'max_participantes': 10},
      'torneo': {'id': 1, 'nombre': 'Copa', 'formato': 'LIGA', 'temporada': '2026', 'estado': 'ACTIVO'},
      'equipos': [
        {'id': 1, 'nombre': 'Leones'},
        {'id': 2, 'nombre': 'Halcones'},
      ],
      'fases': [
        {'id': 1, 'nombre': 'Semifinales', 'orden': 1, 'tipo': 'ELIMINATORIA'},
      ],
      'partidos': partidos,
      'tabla': tabla ?? [],
    });

class _AuthFalso extends AuthController {
  @override
  AuthSession build() =>
      const AuthSession(status: AuthStatus.authenticated, user: Usuario(id: 7, username: 'yo', email: 'yo@e2e.test'));
}

Future<void> _montar(WidgetTester tester, Widget hijo, {List<Override> overrides = const [], bool scroll = true}) async {
  tester.view.physicalSize = const Size(840, 3000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [authControllerProvider.overrideWith(_AuthFalso.new), ...overrides],
    child: MaterialApp(
      theme: StreakTheme.dark(),
      home: scroll ? Scaffold(body: SingleChildScrollView(child: hijo)) : hijo,
    ),
  ));
  await tester.pump();
}

ChipStreak _chip(WidgetTester t, String texto) =>
    t.widget<ChipStreak>(find.ancestor(of: find.text(texto), matching: find.byType(ChipStreak)));

void main() {
  group('17 Resultados', () {
    testWidgets('marcador, tu pronóstico y chips de puntos del backend (+5 amarillo, +3 neutro, 0 contorno)',
        (tester) async {
      await _montar(
        tester,
        TabFinalizados(
          quinielaId: 1,
          vista: _vista(partidos: [
            _resuelto(1, 'FINALIZADO', goles: [3, 1], pron: [3, 1], puntos: 5),
            _resuelto(2, 'FINALIZADO', goles: [2, 2], pron: [1, 1], puntos: 4),
            _resuelto(3, 'FINALIZADO', goles: [2, 0], pron: [1, 0], puntos: 3),
            _resuelto(4, 'FINALIZADO', goles: [0, 1], pron: [2, 0]),
            _resuelto(5, 'SUSPENDIDO', pron: [1, 1]),
          ]),
        ),
      );
      expect(find.text('3 – 1'), findsNWidgets(2), reason: 'resultado y tu pronóstico');
      expect(find.text('Tu pronóstico'), findsNWidgets(5));
      expect(_chip(tester, '+5').variante, VarianteChip.pro);
      expect(_chip(tester, '+4').variante, VarianteChip.destacado, reason: 'empate no exacto: el backend da 4');
      expect(_chip(tester, '+3').variante, VarianteChip.destacado);
      expect(_chip(tester, '0').variante, VarianteChip.contorno);
      expect(find.text('0 pts · no cuenta'), findsOneWidget);
      expect(find.text('– –'), findsOneWidget, reason: 'suspendido sin marcador');
    });

    testWidgets('sin resultados: estado vacío', (tester) async {
      await _montar(tester, TabFinalizados(quinielaId: 1, vista: _vista()));
      expect(find.text('Todavía no hay partidos finalizados.'), findsOneWidget);
    });
  });

  group('19 Tabla', () {
    final tabla = [
      {'id': 1, 'usuario': 5, 'username': 'ana', 'puntos_totales': 152, 'posicion': 1, 'es_pro': true, 'foto': null},
      {'id': 2, 'usuario': 6, 'username': 'luis', 'puntos_totales': 152, 'posicion': 1, 'es_pro': false, 'foto': null},
      {'id': 3, 'usuario': 7, 'username': 'yo', 'puntos_totales': 145, 'posicion': 3, 'es_pro': false, 'foto': null},
    ];

    testWidgets('empates comparten puesto (1, 1, 3) tal como llegan del backend', (tester) async {
      await _montar(tester, TabTabla(vista: _vista(tabla: tabla), quinielaId: 1, usuarioId: 7));
      String pos(int u) => tester.widget<Text>(find.byKey(ValueKey('posicion-$u'))).data!;
      expect([pos(5), pos(6), pos(7)], ['1', '1', '3']);
      expect(find.text('152'), findsNWidgets(2));
    });

    testWidgets('fila propia resaltada con "(tú)" una sola vez y corona solo para PRO', (tester) async {
      await _montar(tester, TabTabla(vista: _vista(tabla: tabla), quinielaId: 1, usuarioId: 7));
      expect(find.text('(tú)'), findsOneWidget);
      expect(find.text('yo'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is StreakIcon && w.icono == StreakIcons.crownPro), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Puesto 3, yo, tú, 145 puntos')), findsOneWidget);
      final resaltadas = tester.widgetList<TarjetaStreak>(find.byType(TarjetaStreak)).where((t) => t.resaltada);
      expect(resaltadas, hasLength(1));
    });
  });

  group('18 Detalle de partido', () {
    testWidgets('oculto y sin pronóstico se distinguen; chips de puntos y "(tú)"', (tester) async {
      final detalle = PartidoDetalle.fromJson({
        'partido': {..._resuelto(1, 'FINALIZADO', goles: [3, 1]), 'mi_pronostico': null},
        'participantes': [
          {'usuario': 5, 'username': 'ana', 'es_pro': true, 'estado_pronostico': 'VISIBLE', 'pronostico': {'goles_local_pred': 2, 'goles_visita_pred': 1}, 'puntos_obtenidos': 3},
          {'usuario': 7, 'username': 'yo', 'es_pro': false, 'estado_pronostico': 'VISIBLE', 'pronostico': {'goles_local_pred': 3, 'goles_visita_pred': 1}, 'puntos_obtenidos': 5},
          {'usuario': 8, 'username': 'rosa', 'es_pro': false, 'estado_pronostico': 'NO_REGISTRADO', 'pronostico': null, 'puntos_obtenidos': 0},
        ],
      });
      await _montar(
        tester,
        const PartidoDetalleScreen(quinielaId: 1, partidoId: 1),
        scroll: false,
        overrides: [
          partidoDetalleProvider.overrideWith((ref, k) async => detalle),
          quinielaVistaProvider.overrideWith((ref, id) async => _vista()),
        ],
      );
      await tester.pump();
      expect(find.text('Semifinales · Finalizado'), findsOneWidget);
      expect(find.text('PRONÓSTICOS DEL GRUPO'), findsOneWidget);
      expect(find.text('(tú)'), findsOneWidget);
      expect(find.text('Sin pronóstico'), findsOneWidget);
      expect(find.text('Oculto hasta el inicio'), findsNothing);
      expect(_chip(tester, '+5').variante, VarianteChip.pro);
      expect(find.text('+3'), findsOneWidget);
    });

    testWidgets('antes del inicio los rivales salen "Oculto hasta el inicio", sin chips', (tester) async {
      final detalle = PartidoDetalle.fromJson({
        'partido': {..._resuelto(1, 'PROGRAMADO'), 'mi_pronostico': null},
        'participantes': [
          {'usuario': 7, 'username': 'yo', 'estado_pronostico': 'NO_REGISTRADO', 'pronostico': null, 'puntos_obtenidos': 0},
          {'usuario': 5, 'username': 'ana', 'estado_pronostico': 'OCULTO', 'pronostico': null, 'puntos_obtenidos': 0},
        ],
      });
      await _montar(
        tester,
        const PartidoDetalleScreen(quinielaId: 1, partidoId: 1),
        scroll: false,
        overrides: [
          partidoDetalleProvider.overrideWith((ref, k) async => detalle),
          quinielaVistaProvider.overrideWith((ref, id) async => _vista()),
        ],
      );
      await tester.pump();
      expect(find.text('Oculto hasta el inicio'), findsOneWidget);
      expect(find.text('Sin pronóstico'), findsOneWidget);
      expect(find.byType(ChipStreak), findsNothing);
    });

    testWidgets('error de carga: "Reintentar"', (tester) async {
      await _montar(
        tester,
        const PartidoDetalleScreen(quinielaId: 1, partidoId: 1),
        scroll: false,
        overrides: [
          partidoDetalleProvider
              .overrideWith((ref, k) async => throw const AppException(codigo: 'NETWORK_ERROR', mensaje: 'x')),
          quinielaVistaProvider.overrideWith((ref, id) async => _vista()),
        ],
      );
      await tester.pump();
      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('21 Historial', () {
    testWidgets('vacío: estado vacío con estela y barra inferior', (tester) async {
      await _montar(
        tester,
        const HistorialScreen(),
        scroll: false,
        overrides: [historialResumenProvider.overrideWith((ref) async => const Listado<ResumenQuiniela>(items: []))],
      );
      await tester.pump();
      expect(find.text('Aún no hay historial'), findsOneWidget);
      expect(find.byType(EstadoVacio), findsOneWidget);
      expect(find.text('Historial'), findsNWidgets(2), reason: 'título y barra inferior');
    });

    testWidgets('tarjetas con torneo · participantes, Finalizado, puesto final y puntos', (tester) async {
      await _montar(
        tester,
        const HistorialScreen(),
        scroll: false,
        overrides: [
          historialResumenProvider.overrideWith((ref) async => Listado<ResumenQuiniela>(items: [
                ResumenQuiniela.fromJson({
                  'id': 1,
                  'nombre': 'Liga Amigos',
                  'codigo_unico': 'K7P2XM',
                  'torneo': 4,
                  'torneo_nombre': 'Clausura E2E',
                  'cantidad_inscritos': 12,
                  'mis_puntos': 312,
                  'mi_posicion': 1,
                }),
              ])),
        ],
      );
      await tester.pump();
      expect(find.text('Liga Amigos'), findsOneWidget);
      expect(find.text('Clausura E2E · 12 participantes'), findsOneWidget);
      expect(find.text('Finalizado'), findsOneWidget);
      expect(find.text('PUESTO FINAL'), findsOneWidget);
      expect(find.text('1.º'), findsOneWidget);
      expect(find.text('312'), findsOneWidget);
    });
  });
}
