import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/constants/app_constants.dart';
import 'package:streak_mobile/features/auth/application/auth_controller.dart';
import 'package:streak_mobile/features/auth/domain/usuario.dart';
import 'package:streak_mobile/features/auth/presentation/screens/perfil_screen.dart';

class _Auth extends AuthController {
  @override
  AuthSession build() => const AuthSession(
        status: AuthStatus.authenticated,
        user: Usuario(id: 1, username: 'ana', email: 'ana@e2e.test'),
      );
}

void main() {
  testWidgets('Perfil: "Eliminar mi cuenta" explica que se pide por correo a soporte', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [authControllerProvider.overrideWith(_Auth.new)],
      child: const MaterialApp(home: PerfilScreen()),
    ));

    await tester.tap(find.text('Eliminar mi cuenta'));
    await tester.pumpAndSettle();

    expect(find.textContaining('se solicita por correo a ${AppConstants.correoSoporte}'), findsOneWidget);
    expect(find.textContaining('ana@e2e.test'), findsWidgets);
    expect(find.text('Copiar correo'), findsOneWidget);

    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
