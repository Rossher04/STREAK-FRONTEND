import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/screens/enlace_invalido_screen.dart';
import 'deep_links.dart';
import '../../features/auth/domain/usuario.dart';
import '../../features/auth/presentation/screens/cambio_password_forzado_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/perfil_screen.dart';
import '../../features/auth/presentation/screens/recuperar_password_screen.dart';
import '../../features/auth/presentation/screens/registro_screen.dart';
import '../../features/auth/presentation/screens/restablecer_password_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/pro/presentation/estadisticas_screen.dart';
import '../../features/pro/presentation/pago_pro_screen.dart';
import '../../features/pro/presentation/pro_screen.dart';
import '../../features/quinielas/presentation/screens/codigo_quiniela_screen.dart';
import '../../features/quinielas/presentation/screens/crear_quiniela_screen.dart';
import '../../features/quinielas/presentation/screens/historial_screen.dart';
import '../../features/quinielas/presentation/screens/home_screen.dart';
import '../../features/quinielas/presentation/screens/participante_detalle_screen.dart';
import '../../features/quinielas/presentation/screens/partido_detalle_screen.dart';
import '../../features/quinielas/presentation/screens/quiniela_activa_screen.dart';
import '../../features/quinielas/presentation/screens/unirse_quiniela_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      // Deep link de restablecer contraseña: se traduce a la ruta interna sin importar la sesión.
      final deepLink = rutaDesdeDeepLink(state.uri);
      if (deepLink != null) return deepLink;

      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      // Estas pantallas funcionan con cualquier estado de sesión (incluida la carga inicial).
      if (loc.startsWith('/restablecer/') || loc == rutaEnlaceInvalido) return null;
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
        path: rutaEnlaceInvalido,
        name: 'enlace_invalido',
        builder: (context, state) => const EnlaceInvalidoScreen(),
      ),
      GoRoute(
        path: '/cambio-password-forzado',
        name: 'cambio_password_forzado',
        builder: (context, state) => const CambioPasswordForzadoScreen(),
      ),
      GoRoute(path: '/home', name: 'home', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/historial', name: 'historial', builder: (context, state) => const HistorialScreen()),
      GoRoute(
        path: '/cambiar-password',
        name: 'cambiar_password',
        builder: (context, state) => const CambioPasswordForzadoScreen(temporal: false),
      ),
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
      GoRoute(path: '/pro', name: 'pro', builder: (context, state) => const ProScreen()),
      GoRoute(path: rutaPagoPro, name: 'pago_pro', builder: (context, state) => const PagoProScreen()),
      GoRoute(
        path: '/quinielas/:id/estadisticas',
        name: 'estadisticas',
        builder: (context, state) =>
            EstadisticasScreen(quinielaId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/quinielas/:id/partido/:pid',
        name: 'partido_detalle',
        builder: (context, state) => PartidoDetalleScreen(
          quinielaId: int.parse(state.pathParameters['id']!),
          partidoId: int.parse(state.pathParameters['pid']!),
        ),
      ),
      GoRoute(
        path: '/quinielas/:id/participante/:uid',
        name: 'participante_detalle',
        builder: (context, state) => ParticipanteDetalleScreen(
          quinielaId: int.parse(state.pathParameters['id']!),
          usuarioId: int.parse(state.pathParameters['uid']!),
        ),
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
