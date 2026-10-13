import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/theme/streak_theme.dart';
import 'package:streak_mobile/core/widgets/streak_icon.dart';
import 'package:streak_mobile/features/pro/data/pro_repository.dart';

String _hex(Color c) {
  String dos(double v) => (v * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
  final rgb = '#${dos(c.r)}${dos(c.g)}${dos(c.b)}';
  return c.a < 1 ? '$rgb${dos(c.a)}' : rgb;
}

void main() {
  test('StreakColors coincide con design/tokens.json (incluidos hint, navBg y scrim)', () {
    final tokens = (jsonDecode(File('design/tokens.json').readAsStringSync())['color'] as Map).cast<String, String>();
    final app = {
      'bg': StreakColors.bg,
      'surface1': StreakColors.surface1,
      'surface2': StreakColors.surface2,
      'line': StreakColors.line,
      'brand': StreakColors.brand,
      'brandBorder': StreakColors.brandBorder,
      'text': StreakColors.text,
      'cream': StreakColors.cream,
      'muted': StreakColors.muted,
      'accent': StreakColors.accent,
      'accentInk': StreakColors.accentInk,
      'orange': StreakColors.orange,
      'orangeText': StreakColors.orangeText,
      'scrim': StreakColors.scrim,
      'hint': StreakColors.hint,
      'navBg': StreakColors.navBg,
    };
    expect(app.keys.toSet(), tokens.keys.toSet());
    for (final e in app.entries) {
      expect(_hex(e.value), tokens[e.key]!.toUpperCase(), reason: e.key);
    }
  });

  test('guardia: ningún color, familia de fuente ni Colors.* suelto fuera de lib/core/theme/', () {
    final prohibidos = [RegExp(r'Color\(0x'), RegExp(r'fontFamily:'), RegExp(r'(?<![A-Za-z])Colors\.(?!transparent)')];
    final culpables = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final ruta = f.path.replaceAll(r'\', '/');
      if (!ruta.endsWith('.dart') || ruta.contains('lib/core/theme/')) continue;
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        if (prohibidos.any((r) => r.hasMatch(lineas[i]))) culpables.add('$ruta:${i + 1}: ${lineas[i].trim()}');
      }
    }
    expect(culpables, isEmpty);
  });

  test('google_fonts y Rubik ya no están', () {
    expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('google_fonts')));
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      expect(f.readAsStringSync().toLowerCase(), isNot(contains('rubik')), reason: f.path);
    }
  });

  test('fuentes con licencia OFL en el repo y cada ícono existe como SVG', () {
    for (final l in ['LICENSES/Sora-OFL.txt', 'LICENSES/Inter-OFL.txt']) {
      expect(File(l).existsSync(), isTrue, reason: l);
    }
    for (final i in StreakIcons.values) {
      expect(File(i.ruta).existsSync(), isTrue, reason: i.ruta);
    }
    expect(File('assets/logo/streak_logo_boceto.svg').existsSync(), isTrue);
  });

  test('importe del plan desde /pro/estado/', () {
    final e = EstadoPro.fromJson({
      'es_pro': false,
      'plan': {'monto_centavos': 500, 'moneda': 'usd', 'tipo': 'PAGO_UNICO', 'max_participantes': 100},
    });
    expect(e.importe, r'$5.00');
    expect(e.importeCorto, r'$5');
    expect(e.moneda, 'USD');
    expect(const EstadoPro(esPro: false, montoCentavos: 550, moneda: 'USD').importeCorto, r'$5.50');
  });
}
