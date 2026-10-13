import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/router/app_router.dart';
import 'package:streak_mobile/core/router/deep_links.dart';
import 'package:streak_mobile/features/auth/application/auth_controller.dart';
import 'package:streak_mobile/features/auth/domain/usuario.dart';
import 'package:streak_mobile/features/auth/presentation/screens/enlace_invalido_screen.dart';
import 'package:streak_mobile/features/auth/presentation/screens/restablecer_password_screen.dart';

class _SinSesion extends AuthController {
  @override
  AuthSession build() => AuthSession.loggedOut;
}

void main() {
  group('rutaDesdeDeepLink', () {
    test('streak://reset-password?uid&token → /restablecer/:uid/:token', () {
      expect(
        rutaDesdeDeepLink(Uri.parse('streak://reset-password?uid=MQ&token=cx9-abc123')),
        '/restablecer/MQ/cx9-abc123',
      );
    });

    test('host perdido por go_router (/?uid=..&token=..) también se traduce', () {
      expect(rutaDesdeDeepLink(Uri.parse('/?uid=Mg&token=tok-1')), '/restablecer/Mg/tok-1');
    });

    test('lo que arma el backend (urlencode) se decodifica y se vuelve a codificar', () {
      // views_auth.py: PASSWORD_RESET_URL + '?' + urlencode({'uid': ..., 'token': ...})
      expect(
        rutaDesdeDeepLink(Uri.parse('streak://reset-password?uid=MQ&token=a%2Fb%3Dc')),
        '/restablecer/MQ/a%2Fb%3Dc',
      );
    });

    test('sin uid, sin token o vacíos → enlace inválido', () {
      expect(rutaDesdeDeepLink(Uri.parse('streak://reset-password?token=abc')), rutaEnlaceInvalido);
      expect(rutaDesdeDeepLink(Uri.parse('streak://reset-password?uid=MQ')), rutaEnlaceInvalido);
      expect(rutaDesdeDeepLink(Uri.parse('streak://reset-password')), rutaEnlaceInvalido);
      expect(rutaDesdeDeepLink(Uri.parse('streak://reset-password?uid=&token=')), rutaEnlaceInvalido);
      expect(rutaDesdeDeepLink(Uri.parse('/?uid=MQ')), rutaEnlaceInvalido);
    });

    test('las rutas normales no se tocan', () {
      expect(rutaDesdeDeepLink(Uri.parse('/home')), isNull);
      expect(rutaDesdeDeepLink(Uri.parse('/')), isNull);
      expect(rutaDesdeDeepLink(Uri.parse('/restablecer/MQ/abc')), isNull);
      expect(rutaDesdeDeepLink(Uri.parse('/quinielas/3?uid=1')), isNull);
    });
  });

  group('router', () {
    Future<GoRouterLike> montar(WidgetTester tester) async {
      final container = ProviderContainer(overrides: [authControllerProvider.overrideWith(_SinSesion.new)]);
      addTearDown(container.dispose);
      final router = container.read(appRouterProvider);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      return GoRouterLike(router.go);
    }

    testWidgets('un enlace completo abre la pantalla de restablecer', (tester) async {
      final r = await montar(tester);
      r.go('streak://reset-password?uid=MQ&token=cx9-abc123');
      await tester.pumpAndSettle();
      expect(find.byType(RestablecerPasswordScreen), findsOneWidget);
      final pantalla = tester.widget<RestablecerPasswordScreen>(find.byType(RestablecerPasswordScreen));
      expect((pantalla.uid, pantalla.token), ('MQ', 'cx9-abc123'));
    });

    testWidgets('un enlace sin token muestra "Enlace inválido"', (tester) async {
      final r = await montar(tester);
      r.go('streak://reset-password?uid=MQ');
      await tester.pumpAndSettle();
      expect(find.byType(EnlaceInvalidoScreen), findsOneWidget);
      expect(find.text('Enlace inválido o vencido'), findsWidgets);
    });

    testWidgets('un enlace sin uid muestra "Enlace inválido"', (tester) async {
      final r = await montar(tester);
      r.go('streak://reset-password?token=abc');
      await tester.pumpAndSettle();
      expect(find.byType(EnlaceInvalidoScreen), findsOneWidget);
    });
  });
}

/// Solo expone `go` para no importar GoRouter en cada prueba.
class GoRouterLike {
  GoRouterLike(this.go);
  final void Function(String, {Object? extra}) go;
}
