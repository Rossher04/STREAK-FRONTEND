// Fase 3 del diseño: pantallas 12 Crear, 13 Código creado, 14 Unirme con código y 15 Ingreso tardío.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:streak_mobile/core/errors/app_exception.dart';
import 'package:streak_mobile/core/storage/cache_store.dart';
import 'package:streak_mobile/core/theme/streak_theme.dart';
import 'package:streak_mobile/features/auth/application/auth_controller.dart';
import 'package:streak_mobile/features/auth/domain/usuario.dart';
import 'package:streak_mobile/features/quinielas/application/quinielas_providers.dart';
import 'package:streak_mobile/features/quinielas/data/quinielas_repository.dart';
import 'package:streak_mobile/features/quinielas/domain/models.dart';
import 'package:streak_mobile/features/quinielas/presentation/screens/codigo_quiniela_screen.dart';
import 'package:streak_mobile/features/quinielas/presentation/screens/crear_quiniela_screen.dart';
import 'package:streak_mobile/features/quinielas/presentation/screens/unirse_quiniela_screen.dart';
import 'package:streak_mobile/features/quinielas/presentation/widgets/resumen_puntaje.dart';

class _Auth extends AuthController {
  _Auth({this.pro = false});
  final bool pro;
  @override
  AuthSession build() => AuthSession(
        status: AuthStatus.authenticated,
        user: Usuario(id: 1, username: 'u', email: 'u@u.test', esPro: pro),
      );
}

ValidacionCodigo _validacion({int cerrados = 0}) => ValidacionCodigo(
      quinielaId: 77,
      nombre: 'Liga Amigos',
      torneoNombre: 'Apertura 2026',
      cantidadInscritos: 8,
      maxParticipantes: 12,
      ingresoTardio: cerrados > 0,
      requiereConfirmacion: cerrados > 0,
      partidosCerrados: cerrados,
      penalizacionPuntos: 0,
      advertencia: cerrados > 0 ? 'No podras pronosticar partidos cuyo plazo ya cerro.' : '',
    );

/// Repositorio falso: registra llamadas y responde lo configurado.
class _Repo extends QuinielasRepository {
  _Repo() : super(Dio(), MemoryCacheStore());

  ValidacionCodigo validacion = _validacion();
  AppException? errorValidar;
  AppException? errorUnirse;
  AppException? errorCrear;
  final llamadas = <String>[];
  ({String nombre, int torneoId, int max})? creada;

  @override
  Future<ValidacionCodigo> validarCodigo(String codigo) async {
    llamadas.add('validar $codigo');
    if (errorValidar != null) throw errorValidar!;
    return validacion;
  }

  @override
  Future<void> unirse(String codigo, {bool aceptarIngresoTardio = false}) async {
    llamadas.add('unirse $codigo tardio=$aceptarIngresoTardio');
    if (errorUnirse != null) throw errorUnirse!;
  }

  @override
  Future<Quiniela> crear({required String nombre, required int torneoId, required int maxParticipantes}) async {
    llamadas.add('crear');
    if (errorCrear != null) throw errorCrear!;
    creada = (nombre: nombre, torneoId: torneoId, max: maxParticipantes);
    return Quiniela(
        id: 5,
        nombre: nombre,
        torneoId: torneoId,
        creadorId: 1,
        codigoUnico: 'K7P2XM',
        maxParticipantes: maxParticipantes);
  }
}

const _torneos = [
  Torneo(id: 1, nombre: 'Apertura 2026', formato: 'LIGA', temporada: '2026', estado: 'ACTIVO'),
  Torneo(id: 2, nombre: 'Copa 2026', formato: 'GRUPOS_ELIMINATORIA', temporada: '2026', estado: 'ACTIVO'),
];

Future<_Repo> _montar(WidgetTester tester, String inicial, {bool pro = false, List<Override> extra = const []}) async {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final repo = _Repo();
  final router = GoRouter(initialLocation: inicial, routes: [
    GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('INICIO'))),
    GoRoute(path: '/pro', builder: (_, __) => const Scaffold(body: Text('PRO'))),
    GoRoute(path: '/quinielas/crear', builder: (_, __) => const CrearQuinielaScreen()),
    GoRoute(path: '/quinielas/unirse', builder: (_, __) => const UnirseQuinielaScreen()),
    GoRoute(
      path: '/quinielas/:id',
      builder: (_, s) => Scaffold(body: Text('QUINIELA ${s.pathParameters['id']}')),
    ),
    GoRoute(
      path: '/quinielas/:id/codigo',
      builder: (_, s) => CodigoQuinielaScreen(quinielaId: int.parse(s.pathParameters['id']!)),
    ),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => _Auth(pro: pro)),
      quinielasRepositoryProvider.overrideWithValue(repo),
      torneosActivosProvider.overrideWith((ref) async => _torneos),
      ...extra,
    ],
    child: MaterialApp.router(theme: StreakTheme.dark(), routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _escribirCodigo(WidgetTester tester, String texto) async {
  await tester.enterText(find.byKey(const Key('unirse.codigo')), texto);
  await tester.pump();
}

int _botonesAmarillos(WidgetTester tester) => find.byType(ElevatedButton).evaluate().length;

void main() {
  group('12 · Crear quiniela', () {
    testWidgets('muestra la línea de puntaje y abre el detalle con ⓘ', (tester) async {
      await _montar(tester, '/quinielas/crear');
      expect(find.text('Exacto 5 · Resultado y diferencia 4 · Resultado 3'), findsOneWidget);
      expect(ResumenPuntaje.texto, 'Exacto 5 · Resultado y diferencia 4 · Resultado 3');
      await tester.tap(find.byTooltip('Ver sistema de puntaje'));
      await tester.pumpAndSettle();
      expect(find.text('Sistema de puntaje'), findsOneWidget);
      expect(find.text('Marcador exacto'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      expect(find.text('+4'), findsOneWidget);
      expect(find.text('+3'), findsOneWidget);
    });

    testWidgets('gratis: tope 50 y chip "Hasta 100 con Pro"; un solo botón amarillo', (tester) async {
      await _montar(tester, '/quinielas/crear');
      final s = tester.widget<Slider>(find.byType(Slider));
      expect((s.min, s.max), (2.0, 50.0));
      expect(find.text('Hasta 100 con Pro'), findsOneWidget);
      expect(find.text('Apertura 2026 · Liga'), findsOneWidget);
      expect(_botonesAmarillos(tester), 1);
    });

    testWidgets('Pro: tope 100 y sin chip', (tester) async {
      await _montar(tester, '/quinielas/crear', pro: true);
      final s = tester.widget<Slider>(find.byType(Slider));
      expect((s.min, s.max), (2.0, 100.0));
      expect(find.text('Hasta 100 con Pro'), findsNothing);
    });

    testWidgets('valida el nombre y crea con el máximo elegido; abre el código', (tester) async {
      final repo = await _montar(tester, '/quinielas/crear');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear quiniela'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe al menos 3 caracteres.'), findsOneWidget);
      expect(repo.llamadas, isEmpty);

      await tester.enterText(find.byType(TextFormField), 'Liga Amigos');
      // Arrastra el deslizador hasta el final: 50.
      await tester.drag(find.byType(Slider), const Offset(600, 0));
      await tester.pump();
      expect(find.byKey(const Key('crear.maximo')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('crear.maximo'))).data, '50');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear quiniela'));
      await tester.pumpAndSettle();
      expect(repo.creada, (nombre: 'Liga Amigos', torneoId: 1, max: 50));
    });

    testWidgets('muestra el error 400 del backend (tope)', (tester) async {
      final repo = await _montar(tester, '/quinielas/crear');
      repo.errorCrear = const AppException(
          codigo: 'DATOS_INVALIDOS', mensaje: 'Participantes: El limite de tu plan es de 50 participantes.');
      await tester.enterText(find.byType(TextFormField), 'Liga Amigos');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear quiniela'));
      await tester.pumpAndSettle();
      expect(find.text('Participantes: El limite de tu plan es de 50 participantes.'), findsOneWidget);
    });
  });

  group('13 · Código creado', () {
    testWidgets('código en crema con Sora, compartir (primario) y copiar', (tester) async {
      final compartidos = <String>[];
      final copiados = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copiados.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          quinielaProvider(5).overrideWith((ref) async => const Quiniela(
              id: 5, nombre: 'Liga Amigos', torneoId: 1, creadorId: 1, codigoUnico: 'K7P2XM', maxParticipantes: 12)),
        ],
        child: MaterialApp(
          theme: StreakTheme.dark(),
          home: CodigoQuinielaScreen(quinielaId: 5, compartir: (t) async => compartidos.add(t)),
        ),
      ));
      await tester.pumpAndSettle();

      final codigo = tester.widget<SelectableText>(find.byKey(const Key('codigo.valor')));
      expect(codigo.data, 'K7P2XM');
      expect(codigo.style!.color, StreakColors.cream);
      expect(codigo.style!.fontFamily, StreakText.display);
      expect(find.text('Sin 0, O, 1, I ni L para dictarlo sin confusión'), findsOneWidget);
      expect(_botonesAmarillos(tester), 1);

      await tester.tap(find.text('Compartir código'));
      await tester.pump();
      expect(compartidos, ['Únete a mi quiniela en STREAK con el código K7P2XM']);

      await tester.tap(find.text('Copiar código'));
      await tester.pumpAndSettle();
      expect(copiados, ['K7P2XM']);
      expect(find.text('Código K7P2XM copiado'), findsOneWidget);
    });
  });

  group('14 · Unirme con código', () {
    testWidgets('6 casillas: mayúsculas y filtro RN-27 (sin 0 O 1 I L)', (tester) async {
      await _montar(tester, '/quinielas/unirse');
      await _escribirCodigo(tester, 'k7o0p1il2xmz');
      final campo = tester.widget<TextField>(find.byKey(const Key('unirse.codigo')));
      expect(campo.controller!.text, 'K7P2XM');
      for (final c in 'K7P2XM'.split('')) {
        expect(find.text(c), findsOneWidget);
      }
      expect(_botonesAmarillos(tester), 1);
    });

    testWidgets('código incompleto: error sin llamar al backend', (tester) async {
      final repo = await _montar(tester, '/quinielas/unirse');
      await _escribirCodigo(tester, 'K7P');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('El código tiene 6 caracteres.'), findsOneWidget);
      expect(repo.llamadas, isEmpty);
    });

    testWidgets('sin confirmación: valida, se une directo (sin hoja) y abre la quiniela', (tester) async {
      final repo = await _montar(tester, '/quinielas/unirse');
      await _escribirCodigo(tester, 'K7P2XM');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Este torneo ya empezó'), findsNothing);
      expect(repo.llamadas, ['validar K7P2XM', 'unirse K7P2XM tardio=false']);
      expect(find.text('QUINIELA 77'), findsOneWidget);
    });

    for (final (codigo, mensaje) in [
      ('NO_ENCONTRADO', 'No existe ninguna quiniela con ese código. Revísalo con quien te lo compartió.'),
      ('QUINIELA_LLENA', 'Esta quiniela ya está llena.'),
      ('YA_PARTICIPA', 'Ya participas en esta quiniela. La encuentras en Inicio.'),
      ('TORNEO_NO_ACTIVO', 'El torneo de esta quiniela ya no admite nuevas inscripciones.'),
    ]) {
      testWidgets('error $codigo con mensaje claro', (tester) async {
        final repo = await _montar(tester, '/quinielas/unirse');
        repo.errorValidar = AppException(codigo: codigo, mensaje: 'backend');
        await _escribirCodigo(tester, 'K7P2XM');
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();
        expect(find.text(mensaje), findsOneWidget);
        expect(repo.llamadas, ['validar K7P2XM'], reason: 'no intenta unirse');
      });
    }
  });

  group('15 · Ingreso tardío', () {
    testWidgets('solo con requiere_confirmacion: hoja con datos; aceptar envía aceptar_ingreso_tardio', (tester) async {
      final repo = await _montar(tester, '/quinielas/unirse');
      repo.validacion = _validacion(cerrados: 3);
      await _escribirCodigo(tester, 'K7P2XM');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.text('Este torneo ya empezó'), findsOneWidget);
      expect(
        find.text('Los 3 partidos que ya cerraron cuentan 0 puntos para ti. Puedes pronosticar los que faltan.'),
        findsOneWidget,
      );
      expect(find.text('Liga Amigos'), findsOneWidget);
      expect(find.text('8 de 12'), findsOneWidget);
      expect(find.text('Apertura 2026 · 3 partidos cerrados'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.textContaining('descuento'), findsNothing);
      expect(repo.llamadas, ['validar K7P2XM']);

      await tester.tap(find.text('Unirme de todos modos'));
      await tester.pumpAndSettle();
      expect(repo.llamadas, ['validar K7P2XM', 'unirse K7P2XM tardio=true']);
      expect(find.text('QUINIELA 77'), findsOneWidget);
    });

    testWidgets('cancelar no se une', (tester) async {
      final repo = await _montar(tester, '/quinielas/unirse');
      repo.validacion = _validacion(cerrados: 1);
      await _escribirCodigo(tester, 'K7P2XM');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('El partido que ya cerró cuenta 0 puntos para ti. Puedes pronosticar los que faltan.'),
          findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Este torneo ya empezó'), findsNothing);
      expect(repo.llamadas, ['validar K7P2XM']);
      expect(find.text('Unirme con código'), findsOneWidget);
    });
  });
}
