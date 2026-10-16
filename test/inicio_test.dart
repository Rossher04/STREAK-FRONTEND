import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:streak_mobile/core/network/server_clock.dart';
import 'package:streak_mobile/core/theme/streak_theme.dart';
import 'package:streak_mobile/core/widgets/campo_texto.dart';
import 'package:streak_mobile/features/auth/application/auth_controller.dart';
import 'package:streak_mobile/features/auth/domain/usuario.dart';
import 'package:streak_mobile/features/auth/presentation/screens/perfil_screen.dart';
import 'package:streak_mobile/features/pro/application/pago_pro_controller.dart';
import 'package:streak_mobile/features/pro/data/pro_repository.dart';
import 'package:streak_mobile/features/quinielas/application/quinielas_providers.dart';
import 'package:streak_mobile/features/quinielas/domain/models.dart';
import 'package:streak_mobile/features/quinielas/domain/resumen_inicio.dart';
import 'package:streak_mobile/features/quinielas/presentation/screens/home_screen.dart';

final _ahora = DateTime.utc(2026, 10, 13, 12);

class _Auth extends AuthController {
  _Auth(this.usuario);
  final Usuario usuario;

  @override
  AuthSession build() => AuthSession(status: AuthStatus.authenticated, user: usuario);

  @override
  Future<void> refrescarPerfil() async {}
}

const _ana = Usuario(id: 7, username: 'ana_m', email: 'a@e2e.test', firstName: 'Ana', lastName: 'Morales');

Future<void> _montarHome(
  WidgetTester tester, {
  required List<Quiniela> quinielas,
  List<PartidoResumen> partidos = const [],
  Usuario usuario = _ana,
}) async {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => _Auth(usuario)),
      misQuinielasProvider.overrideWith((ref) async => Listado(items: quinielas)),
      torneosProvider.overrideWith((ref) async => [
            const Torneo(id: 1, nombre: 'Apertura 2026', formato: 'LIGA', temporada: '2026', estado: 'ACTIVO'),
            const Torneo(id: 2, nombre: 'Clausura 2025', formato: 'LIGA', temporada: '2025', estado: 'FINALIZADO'),
          ]),
      resumenPartidosProvider.overrideWith((ref, id) async => partidos),
      serverClockProvider.overrideWithValue(ServerClock(reloj: () => _ahora)),
      estadoProProvider.overrideWith(
        (ref) async => EstadoPro(esPro: usuario.esPro, montoCentavos: 500, moneda: 'USD'),
      ),
    ],
    child: MaterialApp(theme: StreakTheme.dark(), home: const HomeScreen()),
  ));
  await tester.pumpAndSettle();
}

const _liga = Quiniela(
  id: 1,
  nombre: 'Liga Amigos',
  torneoId: 1,
  codigoUnico: 'K7P2XM',
  maxParticipantes: 12,
  torneoNombre: 'Apertura 2026',
  cantidadInscritos: 8,
  misPuntos: 145,
  miPosicion: 2,
);

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('chipInicio (07)', () {
    PartidoResumen p(Duration cierre, {String estado = 'PROGRAMADO', bool pron = false}) =>
        PartidoResumen(estado: estado, cierre: _ahora.add(cierre), conPronostico: pron);

    test('torneo activo sin cierres próximos: "En juego"', () {
      final c = chipInicio(torneoActivo: true, partidos: [p(const Duration(days: 3))], ahoraServidor: _ahora);
      expect((c.tipo, c.texto), (TipoChipInicio.enJuego, 'En juego'));
    });
    test('un partido sin pronóstico que cierra en menos de 24 h: "Cierra en …"', () {
      final c = chipInicio(
        torneoActivo: true,
        partidos: [p(const Duration(hours: 5)), p(const Duration(hours: 2))],
        ahoraServidor: _ahora,
      );
      expect((c.tipo, c.texto), (TipoChipInicio.cierraPronto, 'Cierra en 2 h'));
    });
    test('si ya pronosticaste, no avisa', () {
      final c = chipInicio(torneoActivo: true, partidos: [p(const Duration(hours: 2), pron: true)], ahoraServidor: _ahora);
      expect(c.tipo, TipoChipInicio.enJuego);
    });
    test('cerrados o finalizados no cuentan; torneo no activo: sin chip', () {
      expect(chipInicio(torneoActivo: true, partidos: [p(const Duration(minutes: -1))], ahoraServidor: _ahora).tipo,
          TipoChipInicio.enJuego);
      expect(chipInicio(torneoActivo: false, partidos: [p(const Duration(hours: 1))], ahoraServidor: _ahora).tipo,
          TipoChipInicio.ninguno);
    });
    test('textos', () {
      expect(textoCierraEn(const Duration(hours: 1, minutes: 20)), 'Cierra en 1 h 20 min');
      expect(textoCierraEn(const Duration(minutes: 45)), 'Cierra en 45 min');
    });
  });

  group('Inicio', () {
    testWidgets('tarjeta con datos reales de /mias/: torneo, inscritos, puesto y puntos', (tester) async {
      await _montarHome(tester, quinielas: [_liga]);
      expect(find.text('MIS QUINIELAS'), findsOneWidget);
      expect(find.text('Liga Amigos'), findsOneWidget);
      expect(find.text('Apertura 2026 · 8 participantes'), findsOneWidget);
      expect(find.text('2.º'), findsOneWidget);
      expect(find.text('145'), findsOneWidget);
      expect(find.text('En juego'), findsOneWidget);
      expect(find.text('Inicio'), findsOneWidget, reason: 'barra inferior');
      expect(find.text('Historial'), findsOneWidget);
    });

    testWidgets('las quinielas de torneos finalizados no salen en Inicio', (tester) async {
      await _montarHome(tester, quinielas: [
        _liga,
        const Quiniela(id: 2, nombre: 'Vieja', torneoId: 2, codigoUnico: 'AAAAAA', maxParticipantes: 5),
      ]);
      expect(find.text('Vieja'), findsNothing);
    });

    testWidgets('vacío (08): estela, un botón primario y uno secundario', (tester) async {
      await _montarHome(tester, quinielas: []);
      expect(find.text('Aún no tienes quinielas'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Crear quiniela'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Unirme con código'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });

  group('Panel lateral (09)', () {
    testWidgets('se abre con el avatar: datos, opciones y chip de precio de /pro/estado/', (tester) async {
      await _montarHome(tester, quinielas: [_liga]);
      await tester.tap(find.bySemanticsLabel('Abrir menú'));
      await tester.pumpAndSettle();
      expect(find.text('Ana Morales'), findsOneWidget);
      expect(find.text('@ana_m'), findsOneWidget);
      expect(find.text('Plan gratuito'), findsOneWidget);
      for (final o in ['Mi perfil', 'Cambiar contraseña', 'Plan Pro', 'Eliminar cuenta', 'Cerrar sesión']) {
        expect(find.text(o), findsOneWidget, reason: o);
      }
      expect(find.text(r'$5 USD'), findsOneWidget);
    });

    testWidgets('usuario PRO: chip "PRO" en vez del precio', (tester) async {
      await _montarHome(tester, quinielas: [_liga], usuario: const Usuario(id: 8, username: 'beto', email: 'b@b', esPro: true));
      await tester.tap(find.bySemanticsLabel('Abrir menú'));
      await tester.pumpAndSettle();
      expect(find.text('PRO'), findsOneWidget);
      expect(find.text(r'$5 USD'), findsNothing);
    });
  });

  testWidgets('Perfil (10): usuario de solo lectura y fecha de nacimiento deshabilitada (backend #18)', (tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [authControllerProvider.overrideWith(() => _Auth(_ana))],
      child: MaterialApp(theme: StreakTheme.dark(), home: const PerfilScreen()),
    ));
    TextFormField campo(String etiqueta) => tester.widget<TextFormField>(find.descendant(
          of: find.ancestor(of: find.text(etiqueta), matching: find.byType(CampoTexto)),
          matching: find.byType(TextFormField),
        ));
    expect(campo('Usuario').enabled, isFalse);
    expect(find.text('ana_m'), findsOneWidget);
    expect(campo('Nombre').enabled, isNot(isFalse));
    expect(campo('Fecha de nacimiento').enabled, isFalse);
    expect(find.text('Guardar cambios'), findsOneWidget);
  });
}
