import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/features/quinielas/presentation/screens/unirse_quiniela_screen.dart';

String _formatear(String texto) {
  final resultado = CodigoFormatter().formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length)),
  );
  return resultado.text;
}

void main() {
  group('CodigoFormatter (RN-27: sin 0 O 1 I L)', () {
    test('pasa a mayúsculas', () {
      expect(_formatear('k7p2xm'), 'K7P2XM');
    });

    test('descarta 0, O, I y L', () {
      expect(_formatear('0OILAB'), 'AB');
    });

    test('descarta también el 1 (el backend ya no lo genera)', () {
      expect(_formatear('ab1c2d'), 'ABC2D');
    });

    test('corta en 6 caracteres', () {
      expect(_formatear('k7p2xmab'), 'K7P2XM');
    });

    test('descarta espacios y símbolos', () {
      expect(_formatear(' a-b c!'), 'ABC');
    });
  });
}
