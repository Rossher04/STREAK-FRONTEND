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
  group('CodigoFormatter (RN-27)', () {
    test('pasa a mayúsculas', () {
      expect(_formatear('k7p2xm'), 'K7P2XM');
    });

    test('descarta 0, O, I y L', () {
      expect(_formatear('0OILAB'), 'AB');
    });

    test('admite el 1 porque el backend lo genera', () {
      expect(_formatear('ab1c2d'), 'AB1C2D');
    });

    test('descarta espacios y símbolos', () {
      expect(_formatear(' a-b c!'), 'ABC');
    });
  });
}
