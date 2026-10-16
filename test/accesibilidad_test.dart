import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:streak_mobile/core/network/server_clock.dart';
import 'package:streak_mobile/core/theme/streak_theme.dart';
import 'package:streak_mobile/features/pro/application/pago_pro_controller.dart';
import 'package:streak_mobile/features/pro/data/pro_repository.dart';
import 'package:streak_mobile/features/pro/presentation/pago_pro_screen.dart';
import 'package:streak_mobile/features/pro/presentation/pro_screen.dart';
import 'package:streak_mobile/features/quinielas/domain/quiniela_vista.dart';
import 'package:streak_mobile/features/quinielas/presentation/widgets/tab_pendientes.dart';

double _lum(Color c) {
  double lin(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

double contraste(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (max(x, y) + 0.05) / (min(x, y) + 0.05);
}

final _ahora = DateTime.utc(2026, 10, 12, 12, 0);

QuinielaVista _vista() => QuinielaVista.fromRaw({
      'quiniela': {'id': 1, 'nombre': 'Q', 'torneo': 1, 'creador': 7, 'codigo_unico': 'ABC234', 'max_participantes': 10},
      'torneo': {'id': 1, 'nombre': 'Copa', 'formato': 'LIGA', 'temporada': '2026', 'estado': 'ACTIVO'},
      'equipos': [
        {'id': 1, 'nombre': 'Leones'},
        {'id': 2, 'nombre': 'Tigres'},
      ],
      'fases': [
        {'id': 1, 'nombre': 'Fase de grupos', 'orden': 1, 'tipo': 'GRUPOS'},
      ],
      'partidos': [
        {
          'id': 1,
          'torneo': 1,
          'fase': 1,
          'equipo_local': 1,
          'equipo_visita': 2,
          'fecha_hora': _ahora.add(const Duration(hours: 5)).toIso8601String(),
          'goles_local': null,
          'goles_visita': null,
          'estado': 'PROGRAMADO',
          'mi_pronostico': null,
          'mis_puntos': 0,
        },
      ],
      'tabla': [],
    });

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('contraste de la paleta oscura (WCAG AA = 4.5:1 en texto normal)', () {
    const fondos = [StreakColors.bg, StreakColors.surface1];
    test('texto, crema, secundario, amarillo y orangeText sirven como texto sobre bg y surface1', () {
      for (final fondo in fondos) {
        for (final c in [StreakColors.text, StreakColors.cream, StreakColors.muted, StreakColors.accent, StreakColors.orangeText]) {
          expect(contraste(c, fondo), greaterThan(4.5), reason: '$c sobre $fondo');
        }
      }
    });
    test('los valores de PALETA.md: texto 15.8, crema 15.3, secundario 8.3, amarillo 9.8, orangeText 5.8', () {
      expect(contraste(StreakColors.text, StreakColors.bg), closeTo(15.8, 0.1));
      expect(contraste(StreakColors.cream, StreakColors.bg), closeTo(15.3, 0.1));
      expect(contraste(StreakColors.muted, StreakColors.bg), closeTo(8.3, 0.1));
      expect(contraste(StreakColors.accent, StreakColors.bg), closeTo(9.8, 0.1));
      expect(contraste(StreakColors.orangeText, StreakColors.bg), closeTo(5.8, 0.1));
    });
    test('texto sobre botón amarillo y texto en surface2 (chips)', () {
      expect(contraste(StreakColors.accentInk, StreakColors.accent), greaterThan(4.5));
      expect(contraste(StreakColors.text, StreakColors.surface2), greaterThan(4.5));
      expect(contraste(StreakColors.muted, StreakColors.surface2), greaterThan(4.5));
      expect(contraste(StreakColors.text, StreakColors.brand), greaterThan(4.5), reason: 'iniciales del avatar');
    });
    test('documenta lo que NO sirve como texto pequeño: orange (3.99) y hint', () {
      expect(contraste(StreakColors.orange, StreakColors.bg), lessThan(4.5));
      expect(contraste(StreakColors.orange, StreakColors.bg), closeTo(3.99, 0.05));
    });
  });

  test('guardia: StreakColors.orange nunca es color de texto (para texto pequeño se usa orangeText)', () {
    final culpables = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final l = lineas[i];
        if (l.contains('TextStyle(') && l.contains('StreakColors.orange,')) culpables.add('${f.path}:${i + 1}');
        if (l.contains('copyWith(color: StreakColors.orange)')) culpables.add('${f.path}:${i + 1}');
      }
    }
    expect(culpables, isEmpty);
  });

  group('guías de accesibilidad de Flutter', () {
    Future<void> montar(WidgetTester tester, Widget hijo) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [serverClockProvider.overrideWithValue(ServerClock(reloj: () => _ahora))],
        child: MaterialApp(theme: StreakTheme.dark(), home: Scaffold(body: hijo)),
      ));
      await tester.pump();
    }

    testWidgets('Pendientes: botones con etiqueta y tamaño de toque de 48 dp', (tester) async {
      final handle = tester.ensureSemantics();
      await montar(tester, TabPendientes(vista: _vista(), quinielaId: 1, onRefresh: () async {}));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('Pendientes: los goles tienen etiqueta semántica con su valor', (tester) async {
      final handle = tester.ensureSemantics();
      await montar(tester, TabPendientes(vista: _vista(), quinielaId: 1, onRefresh: () async {}));
      expect(find.bySemanticsLabel(RegExp('Goles de Leones')), findsOneWidget);
      expect(find.byTooltip('Sumar gol a Tigres'), findsOneWidget);
      expect(find.byTooltip('Restar gol a Tigres'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Plan Pro (22): contraste de texto, etiquetas y tamaño de toque', (tester) async {
      final handle = tester.ensureSemantics();
      await montar(tester, const PlanProContenido(estado: EstadoPro(esPro: false, montoCentavos: 500, moneda: 'USD')));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('Pago (23): contraste de texto, etiquetas y tamaño de toque', (tester) async {
      final handle = tester.ensureSemantics();
      await montar(
        tester,
        ResumenPago(
          plan: const EstadoPro(esPro: false, montoCentavos: 500, moneda: 'USD'),
          estado: EstadoPago.inactivo,
          motivoNoDisponible: null,
          onPagar: () {},
          onCancelarPendiente: () {},
        ),
      );
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('Pendientes: contraste de texto', (tester) async {
      final handle = tester.ensureSemantics();
      await montar(tester, TabPendientes(vista: _vista(), quinielaId: 1, onRefresh: () async {}));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });
}
