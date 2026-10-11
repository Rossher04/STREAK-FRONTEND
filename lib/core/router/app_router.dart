import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/usuario.dart';
import '../../features/auth/presentation/screens/cambio_password_forzado_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/perfil_screen.dart';
import '../../features/auth/presentation/screens/recuperar_password_screen.dart';
import '../../features/auth/presentation/screens/registro_screen.dart';
import '../../features/auth/presentation/screens/restablecer_password_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/quinielas/presentation/screens/codigo_quiniela_screen.dart';
import '../../features/quinielas/presentation/screens/crear_quiniela_screen.dart';
import '../../features/quinielas/presentation/screens/home_screen.dart';
import '../../features/quinielas/presentation/screens/quiniela_activa_screen.dart';
import '../../features/quinielas/presentation/screens/unirse_quiniela_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      final public = loc == '/login' ||
          loc == '/register' ||
          loc == '/recuperar' ||
          loc.startsWith('/restablecer/');

      if (auth.status == AuthStatus.unknown) {
        return loc == '/' ? null : '/';
      }
      if (auth.status == AuthStatus.unauthenticated) {
        return public ? null : '/login';
      }
      if (auth.status == AuthStatus.needsPasswordChange) {
        return loc == '/cambio-password-forzado' ? null : '/cambio-password-forzado';
      }
      if (public || loc == '/' || loc == '/cambio-password-forzado') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', name: 'splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', name: 'login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', name: 'register', builder: (context, state) => const RegistroScreen()),
      GoRoute(path: '/recuperar', name: 'recuperar', builder: (context, state) => const RecuperarPasswordScreen()),
      GoRoute(
        path: '/restablecer/:uid/:token',
        name: 'restablecer',
        builder: (context, state) => RestablecerPasswordScreen(
          uid: state.pathParameters['uid']!,
          token: state.pathParameters['token']!,
        ),
      ),
      GoRoute(
        path: '/cambio-password-forzado',
        name: 'cambio_password_forzado',
        builder: (context, state) => const CambioPasswordForzadoScreen(),
      ),
      GoRoute(path: '/home', name: 'home', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/perfil', name: 'perfil', builder: (context, state) => const PerfilScreen()),
      GoRoute(
        path: '/quinielas/crear',
        name: 'crear_quiniela',
        builder: (context, state) => const CrearQuinielaScreen(),
      ),
      GoRoute(
        path: '/quinielas/unirse',
        name: 'unirse_quiniela',
        builder: (context, state) => const UnirseQuinielaScreen(),
      ),
      GoRoute(
        path: '/quinielas/:id',
        name: 'quiniela_activa',
        builder: (context, state) =>
            QuinielaActivaScreen(quinielaId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/quinielas/:id/codigo',
        name: 'codigo_quiniela',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return CodigoQuinielaScreen(quinielaId: id);
        },
      ),
    ],
  );
});
