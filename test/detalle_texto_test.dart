import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/features/quinielas/domain/quiniela_vista.dart';
import 'package:streak_mobile/features/quinielas/presentation/screens/partido_detalle_screen.dart';

void main() {
  final inicio = DateTime.utc(2026, 10, 12, 20);
  String texto({Marcador? pron, bool propio = false, required Duration antes}) =>
      textoPronosticoParticipante(
        pronostico: pron,
        esPropio: propio,
        fechaHora: inicio,
        ahoraServidor: inicio.subtract(antes),
      );

  group('pronóstico de otro participante (RN-39)', () {
    test('visible: muestra el marcador', () {
      expect(texto(pron: const Marcador(2, 1), antes: const Duration(hours: -1)), '2 - 1');
    });
    test('null antes del inicio: oculto', () {
      expect(texto(antes: const Duration(hours: 2)), 'Oculto hasta el inicio del partido');
    });
    test('null después del inicio: no pronosticó', () {
      expect(texto(antes: const Duration(minutes: -5)), 'Sin pronóstico');
    });
    test('el propio nunca está "oculto"', () {
      expect(texto(propio: true, antes: const Duration(hours: 2)), 'Sin pronóstico');
    });
  });
}
