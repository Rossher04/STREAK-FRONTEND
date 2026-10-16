import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:streak_mobile/core/errors/app_exception.dart';
import 'package:streak_mobile/core/storage/secure_storage_service.dart';
import 'package:streak_mobile/core/theme/streak_theme.dart';
import 'package:streak_mobile/core/widgets/botones.dart';
import 'package:streak_mobile/features/auth/application/auth_controller.dart';
import 'package:streak_mobile/features/auth/domain/usuario.dart';
import 'package:streak_mobile/features/pro/application/pago_pro_controller.dart';
import 'package:streak_mobile/features/pro/data/pro_repository.dart';
import 'package:streak_mobile/features/pro/presentation/pago_pro_screen.dart';
import 'package:streak_mobile/features/pro/presentation/pro_screen.dart';
import 'package:streak_mobile/features/pro/presentation/pro_textos.dart';

class _Repo implements ProRepository {
  _Repo({this.plan = const EstadoPro(esPro: false, montoCentavos: 750, moneda: 'EUR'), this.pendiente, this.pagosLista = const []});

  final EstadoPro plan;
  final PagoPendiente? pendiente;
  final List<PagoPro> pagosLista;

  @override
  Future<EstadoPro> estado() async => plan;
  @override
  Future<bool> esPro() async => plan.esPro;
  @override
  Future<List<PagoPro>> pagos() async => pagosLista;
  @override
  Future<PagoPendiente?> pagoPendiente() async => pendiente;
  @override
  Future<PagoPro> cancelarPago(int pagoId) => throw UnimplementedError();
  @override
  Future<IntentoPago> iniciarPago(String claveIdempotencia) async =>
      throw const AppException(codigo: 'PAGOS_NO_CONFIGURADOS', mensaje: 'x');
}

class _Storage extends SecureStorageService {
  final claves = <int, String>{};
  @override
  Future<String?> getProIdempotencyKey(int userId) async => claves[userId];
  @override
  Future<void> saveProIdempotencyKey(int userId, String key) async => claves[userId] = key;
  @override
  Future<void> clearProIdempotencyKey(int userId) async => claves.remove(userId);
}

class _Auth extends AuthController {
  _Auth(this.esPro);
  final bool esPro;
  @override
  AuthSession build() => AuthSession(
        status: AuthStatus.authenticated,
        user: Usuario(id: 7, username: 'ana', email: 'a@a.test', esPro: esPro),
      );
}

Future<void> _montar(WidgetTester tester, Widget pantalla, {_Repo? repo, bool esPro = false, String? motivo}) async {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      proRepositoryProvider.overrideWithValue(repo ?? _Repo()),
      secureStorageProvider.overrideWithValue(_Storage()),
      authControllerProvider.overrideWith(() => _Auth(esPro)),
      motivoPagosNoDisponiblesProvider.overrideWithValue(motivo),
    ],
    child: MaterialApp(theme: StreakTheme.dark(), home: pantalla),
  ));
  await tester.pumpAndSettle();
}

double _y(WidgetTester tester, Key k) => tester.getTopLeft(find.byKey(k)).dy;

PagoPendiente _pendiente() => PagoPendiente(
      pago: PagoPro(id: 41, monto: '7.50', moneda: 'EUR', estado: 'PENDIENTE', fecha: DateTime.utc(2026, 10, 1)),
      claveIdempotencia: 'clave-pendiente',
      estadoStripe: 'requires_payment_method',
    );

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('22 · Plan Pro', () {
    testWidgets('el importe y la moneda salen de GET /pro/estado/ (no de una constante)', (tester) async {
      await _montar(tester, const ProScreen());
      expect(find.text(r'$7.50'), findsOneWidget);
      expect(find.text('EUR'), findsOneWidget);
      expect(find.text(r'$5'), findsNothing);
      expect(find.text('Obtener Plan Pro'), findsOneWidget);
    });

    testWidgets('solo beneficios reales: sin "Sin anuncios"', (tester) async {
      await _montar(tester, const ProScreen());
      expect(find.textContaining('anuncios'), findsNothing);
      expect(find.text('Hasta 100 participantes por quiniela'), findsOneWidget);
      expect(find.text('Insignia dorada en la tabla'), findsOneWidget);
      expect(find.textContaining('efectividad, racha y comparativa'), findsOneWidget);
      for (final b in beneficiosPro(const EstadoPro(esPro: false, montoCentavos: 500, moneda: 'USD'))) {
        expect(b.toLowerCase(), isNot(contains('anuncio')));
        expect(b.toLowerCase(), isNot(contains('puntos extra')));
      }
    });

    testWidgets('un solo botón amarillo y precio + periodo antes del botón', (tester) async {
      await _montar(tester, const ProScreen());
      expect(find.byType(BotonPrimario), findsOneWidget);
      final boton = _y(tester, const ValueKey('boton-obtener'));
      expect(_y(tester, const ValueKey('precio')), lessThan(boton));
      expect(_y(tester, const ValueKey('periodo')), lessThan(boton));
    });

    testWidgets('RN-65: el enlace abre una hoja con precio, periodo y cómo cancelar reales', (tester) async {
      await _montar(tester, const ProScreen());
      await tester.tap(find.byKey(const ValueKey('enlace-condiciones')));
      await tester.pumpAndSettle();
      expect(find.textContaining(r'$7.50 EUR, cobrado una sola vez'), findsOneWidget);
      expect(find.textContaining('sin renovación automática ni cargos posteriores'), findsOneWidget);
      expect(find.textContaining('No hay suscripción que cancelar. Si quieres un reembolso'), findsOneWidget);
      expect(find.text(textoSinVentaja), findsOneWidget);
    });

    testWidgets('si ya es PRO: "Tu plan PRO" con el historial de GET /pro/pagos/', (tester) async {
      final repo = _Repo(
        plan: const EstadoPro(esPro: true, montoCentavos: 500, moneda: 'USD'),
        pagosLista: [PagoPro(id: 1, monto: '5.00', moneda: 'USD', estado: 'COMPLETADO', fecha: DateTime.utc(2026, 9, 3, 15))],
      );
      await _montar(tester, const ProScreen(), repo: repo, esPro: true);
      expect(find.text('Tu plan PRO'), findsOneWidget);
      expect(find.text('HISTORIAL DE PAGOS'), findsOneWidget);
      expect(find.text(r'$5.00 USD'), findsOneWidget);
      expect(find.text('Completado'), findsOneWidget);
      expect(find.text('Obtener Plan Pro'), findsNothing);
    });
  });

  group('23 · Pago', () {
    testWidgets('resumen: RN-65 (precio, periodo, cómo cancelar) ANTES del botón y sin campos de tarjeta',
        (tester) async {
      await _montar(tester, const PagoProScreen());
      final boton = _y(tester, const ValueKey('boton-pagar'));
      expect(_y(tester, const ValueKey('precio')), lessThan(boton));
      expect(_y(tester, const ValueKey('periodo')), lessThan(boton));
      expect(_y(tester, const ValueKey('cancelar')), lessThan(boton));
      expect(find.text(r'Pagar $7.50 EUR'), findsOneWidget);
      expect(find.text(textoPagoUnico), findsOneWidget);
      expect(find.text(textoStripe), findsOneWidget);
      expect(find.byType(TextField), findsNothing, reason: 'la tarjeta la pide la hoja de Stripe');
      expect(find.byType(BotonPrimario), findsOneWidget);
      expect(find.byKey(const ValueKey('enlace-condiciones')), findsOneWidget);
    });

    testWidgets('sin pagos en este dispositivo: botón deshabilitado y motivo visible', (tester) async {
      await _montar(tester, const PagoProScreen(), motivo: 'Los pagos aún no están disponibles en esta versión de la app.');
      final boton = tester.widget<BotonPrimario>(find.byKey(const ValueKey('boton-pagar')));
      expect(boton.onPressed, isNull);
      expect(find.text('Los pagos aún no están disponibles en esta versión de la app.'), findsOneWidget);
    });

    testWidgets('compra pendiente (GET /pro/pago-pendiente/): aviso y opción de cancelarla', (tester) async {
      await _montar(tester, const PagoProScreen(), repo: _Repo(pendiente: _pendiente()));
      expect(find.byKey(const ValueKey('aviso-pendiente')), findsOneWidget);
      expect(find.textContaining('sin un segundo cobro'), findsOneWidget);
      expect(find.text('Cancelar compra pendiente'), findsOneWidget);
    });

    testWidgets('503 PAGOS_NO_CONFIGURADOS: pantalla de error con mensaje claro y Reintentar', (tester) async {
      await _montar(tester, const PagoProScreen());
      await tester.tap(find.byKey(const ValueKey('boton-pagar')));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo completar el pago'), findsOneWidget);
      expect(find.textContaining('Los pagos no están disponibles por ahora'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('boton-pagar')), findsOneWidget);
    });
  });

  group('24 · Pago confirmado y variantes', () {
    Future<void> resultado(WidgetTester tester, EstadoPago e) async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: StreakTheme.dark(),
        home: Scaffold(
          body: ResultadoPago(
            estado: e,
            maxParticipantes: 100,
            onListo: () {},
            onReintentar: () {},
            onComprobar: () {},
            onCancelarPendiente: () {},
            onVolver: () {},
          ),
        ),
      ));
    }

    testWidgets('éxito: "¡Ya eres PRO!", texto real y "Listo"', (tester) async {
      await resultado(tester, const EstadoPago(FasePago.activo));
      expect(find.text('¡Ya eres PRO!'), findsOneWidget);
      expect(find.textContaining('hasta 100 participantes y tu insignia dorada'), findsOneWidget);
      expect(find.text('Listo'), findsOneWidget);
      expect(find.byType(BotonPrimario), findsOneWidget);
    });

    testWidgets('En revisión: comprobar de nuevo y cancelar la compra pendiente', (tester) async {
      await resultado(
          tester, EstadoPago(FasePago.enRevision, mensajeEnRevision, _pendiente(), 'TIEMPO_AGOTADO'));
      expect(find.text('Pago en revisión'), findsOneWidget);
      expect(find.text(mensajeEnRevision), findsOneWidget);
      expect(find.text('Comprobar de nuevo'), findsOneWidget);
      expect(find.text('Cancelar compra pendiente'), findsOneWidget);
      expect(find.byType(BotonPrimario), findsOneWidget);
    });

    testWidgets('error: mensaje y "Reintentar"', (tester) async {
      await resultado(tester, const EstadoPago(FasePago.error, 'No se pudo contactar al proveedor de pagos.'));
      expect(find.text('No se pudo completar el pago'), findsOneWidget);
      expect(find.text('No se pudo contactar al proveedor de pagos.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}
