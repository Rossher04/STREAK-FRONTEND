import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:streak_mobile/core/network/server_clock.dart';
import 'package:streak_mobile/core/theme/app_colors.dart';
import 'package:streak_mobile/features/pro/application/pago_pro_controller.dart';
import 'package:streak_mobile/features/pro/presentation/paywall_contenido.dart';
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

  group('contraste de la paleta (WCAG AA = 4.5:1 en texto normal)', () {
    const blanco = Colors.white;
    test('el texto principal sobre los fondos de la app', () {
      for (final fondo in [blanco, AppColors.lightGraySurface, AppColors.creamBackground]) {
        expect(contraste(AppColors.textPrimary, fondo), greaterThan(4.5));
      }
    });
    test('blanco y dorado sobre el azul de las cabeceras', () {
      expect(contraste(Colors.white, AppColors.primaryBlue), greaterThan(4.5));
      expect(contraste(AppColors.goldAccent, AppColors.primaryBlue), greaterThan(4.5));
    });
    test('el azul principal sobre blanco y crema', () {
      expect(contraste(AppColors.primaryBlue, blanco), greaterThan(4.5));
      expect(contraste(AppColors.primaryBlue, AppColors.creamBackground), greaterThan(4.5));
    });
    test('el error sobre blanco y gris', () {
      expect(contraste(AppColors.error, blanco), greaterThan(4.5));
      expect(contraste(AppColors.error, AppColors.lightGraySurface), greaterThan(4.5));
    });
    test('documenta lo que NO sirve como texto: textSecondary, dorado y naranja sobre claro', () {
      expect(contraste(AppColors.textSecondary, blanco), lessThan(4.5));
      expect(contraste(AppColors.goldAccent, blanco), lessThan(3));
      expect(contraste(AppColors.sportsOrange, AppColors.lightGraySurface), lessThan(4.5));
    });
  });

  test('guardia: textSecondary solo se usa en iconos (nunca como color de texto)', () {
    final culpables = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('app_colors.dart')) continue;
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        if (lineas[i].contains('AppColors.textSecondary') && !lineas[i].contains('Icon(')) {
          culpables.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(culpables, isEmpty, reason: 'contraste 4.0:1 sobre blanco; usar textPrimary');
  });

  group('guías de accesibilidad de Flutter', () {
    Future<void> montar(WidgetTester tester, Widget hijo) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [serverClockProvider.overrideWithValue(ServerClock(reloj: () => _ahora))],
        child: MaterialApp(home: Scaffold(body: hijo)),
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

    testWidgets('Paywall: contraste de texto, etiquetas y tamaño de toque', (tester) async {
      final handle = tester.ensureSemantics();
      await montar(
        tester,
        PaywallContenido(
          estado: EstadoPago.inactivo,
          motivoNoDisponible: null,
          onPagar: () {},
          onVerificar: () {},
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
