import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/features/auth/application/auth_controller.dart';
import 'package:streak_mobile/features/auth/domain/usuario.dart';
import 'package:streak_mobile/features/quinielas/application/quinielas_providers.dart';
import 'package:streak_mobile/features/quinielas/domain/models.dart';
import 'package:streak_mobile/features/quinielas/presentation/screens/crear_quiniela_screen.dart';

class _Auth extends AuthController {
  _Auth(this.pro);
  final bool pro;
  @override
  AuthSession build() => AuthSession(
        status: AuthStatus.authenticated,
        user: Usuario(id: 1, username: 'u', email: 'u@u.test', esPro: pro),
      );
}

Future<Slider> _slider(WidgetTester tester, {required bool pro}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => _Auth(pro)),
      torneosActivosProvider.overrideWith(
        (ref) async => [const Torneo(id: 1, nombre: 'Liga', formato: 'LIGA', temporada: '2026', estado: 'ACTIVO')],
      ),
    ],
    child: const MaterialApp(home: CrearQuinielaScreen()),
  ));
  await tester.pumpAndSettle();
  return tester.widget<Slider>(find.byType(Slider));
}

void main() {
  testWidgets('plan gratis: de 2 a 50 participantes', (tester) async {
    final s = await _slider(tester, pro: false);
    expect((s.min, s.max), (2.0, 50.0));
    expect(find.textContaining('máx. 50'), findsOneWidget);
  });

  testWidgets('plan PRO: de 2 a 100 participantes', (tester) async {
    final s = await _slider(tester, pro: true);
    expect((s.min, s.max), (2.0, 100.0));
    expect(find.textContaining('máx. 100'), findsOneWidget);
  });
}
