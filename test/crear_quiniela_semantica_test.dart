import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/features/auth/application/auth_controller.dart';
import 'package:streak_mobile/features/auth/domain/usuario.dart';
import 'package:streak_mobile/features/quinielas/application/quinielas_providers.dart';
import 'package:streak_mobile/features/quinielas/domain/models.dart';
import 'package:streak_mobile/features/quinielas/presentation/screens/crear_quiniela_screen.dart';

class _Auth extends AuthController {
  @override
  AuthSession build() => const AuthSession(
        status: AuthStatus.authenticated,
        user: Usuario(id: 1, username: 'u', email: 'u@u.test'),
      );
}

void main() {
  testWidgets('Crear quiniela: torneo, participantes y botón son nodos semánticos distintos', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_Auth.new),
        torneosActivosProvider.overrideWith(
          (ref) async => [const Torneo(id: 1, nombre: 'Liga', formato: 'LIGA', temporada: '2026', estado: 'ACTIVO')],
        ),
      ],
      child: const MaterialApp(home: CrearQuinielaScreen()),
    ));
    await tester.pumpAndSettle();

    final torneo = tester.getSemantics(find.byType(DropdownButtonFormField<int>));
    expect(torneo.label, contains('Torneo'));
    expect(torneo.label, isNot(contains('Participantes')), reason: 'antes se leía junto con el deslizador');
    expect(torneo.label, isNot(contains('CREAR')));

    final participantes = tester.getSemantics(find.text('Participantes: 12 (mín. 2, máx. 50)'));
    expect(participantes.label, contains('Participantes: 12'));
    expect(participantes.label, isNot(contains('Torneo')));

    final deslizador = tester.getSemantics(find.byType(Slider));
    expect(deslizador.label, isNot(contains('Torneo')));
    expect(deslizador.value, isNotEmpty);

    final boton = tester.getSemantics(find.text('CREAR Y VER CÓDIGO'));
    expect(boton.label, 'CREAR Y VER CÓDIGO');

    // Son nodos diferentes.
    expect({torneo.id, participantes.id, deslizador.id, boton.id}, hasLength(4));
    handle.dispose();
  });
}
