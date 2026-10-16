import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/errors/app_exception.dart';
import 'package:streak_mobile/core/network/auth_interceptor.dart';
import 'package:streak_mobile/core/storage/secure_storage_service.dart';
import 'package:streak_mobile/core/theme/streak_theme.dart';
import 'package:streak_mobile/core/widgets/campo_texto.dart';
import 'package:streak_mobile/features/auth/application/auth_controller.dart';
import 'package:streak_mobile/features/auth/domain/usuario.dart';
import 'package:streak_mobile/features/auth/presentation/screens/cambio_password_forzado_screen.dart';
import 'package:streak_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:streak_mobile/features/auth/presentation/screens/recuperar_password_screen.dart';
import 'package:streak_mobile/features/auth/presentation/screens/registro_screen.dart';

class _AuthFalso extends AuthController {
  _AuthFalso({this.error, this.temporal = false});

  final AppException? error;
  final bool temporal;
  int registros = 0;
  DateTime? ultimaFecha;

  @override
  AuthSession build() => temporal
      ? const AuthSession(
          status: AuthStatus.needsPasswordChange,
          user: Usuario(id: 3, username: 'caro', email: 'c@e2e.test', passTemporal: true),
        )
      : AuthSession.loggedOut;

  @override
  Future<void> login(String username, String password) async {
    if (error != null) throw error!;
  }

  @override
  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String telefono = '',
    DateTime? fechaNacimiento,
  }) async {
    registros++;
    ultimaFecha = fechaNacimiento;
    if (error != null) throw error!;
  }

  @override
  Future<String> recuperar(String email) async {
    if (error != null) throw error!;
    return 'ok';
  }
}

Future<void> _montar(WidgetTester tester, Widget pantalla, _AuthFalso auth) async {
  tester.view.physicalSize = const Size(780, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [authControllerProvider.overrideWith(() => auth)],
    child: MaterialApp(theme: StreakTheme.dark(), home: pantalla),
  ));
  await tester.pump();
}

Future<void> _escribir(WidgetTester tester, String etiqueta, String texto) async {
  final campo = find.descendant(
    of: find.ancestor(of: find.text(etiqueta), matching: find.byType(CampoTexto)),
    matching: find.byType(TextFormField),
  );
  await tester.enterText(campo, texto);
}

void main() {
  group('01 Login', () {
    testWidgets('marca, campos con etiqueta arriba y enlaces', (tester) async {
      await _montar(tester, const LoginScreen(), _AuthFalso());
      expect(find.text('STREAK'), findsOneWidget);
      expect(find.text('NO ROMPAS LA RACHA'), findsOneWidget);
      expect(find.text('Usuario'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget, reason: 'un solo botón amarillo');
    });

    testWidgets('credenciales incorrectas: error bajo la contraseña', (tester) async {
      await _montar(
        tester,
        const LoginScreen(),
        _AuthFalso(error: const AppException(codigo: 'CREDENCIALES_INVALIDAS', mensaje: 'Usuario o contraseña incorrectos.')),
      );
      await _escribir(tester, 'Usuario', 'ana');
      await _escribir(tester, 'Contraseña', 'mala12345');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Usuario o contraseña incorrectos.'), findsOneWidget);
    });

    testWidgets('campos vacíos: validación local', (tester) async {
      await _montar(tester, const LoginScreen(), _AuthFalso());
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe tu usuario'), findsOneWidget);
      expect(find.text('Escribe tu contraseña'), findsOneWidget);
    });
  });

  group('02 Registro', () {
    testWidgets('fecha de nacimiento habilitada, opcional y con selector (backend #18)', (tester) async {
      await _montar(tester, const RegistroScreen(), _AuthFalso());
      expect(find.text('Fecha de nacimiento'), findsOneWidget);
      final campo = tester.widget<TextFormField>(find.byKey(const Key('fecha_nacimiento')));
      expect(campo.enabled, isNot(isFalse));
      expect(find.byTooltip('Elegir fecha de nacimiento'), findsOneWidget);
    });

    Future<void> enviarRegistro(WidgetTester tester) async {
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      final boton = find.widgetWithText(ElevatedButton, 'Crear cuenta');
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();
    }

    testWidgets('con fecha dd/mm/aaaa se envía como fecha', (tester) async {
      final auth = _AuthFalso();
      await _montar(tester, const RegistroScreen(), auth);
      await _escribir(tester, 'Usuario', 'nuevo');
      await _escribir(tester, 'Correo electrónico', 'n@correo.com');
      await _escribir(tester, 'Contraseña', 'Clave1234x');
      await tester.enterText(find.byKey(const Key('fecha_nacimiento')), '23041995');
      await tester.pump();
      expect(find.text('23/04/1995'), findsOneWidget, reason: 'el formateador agrega las diagonales');
      await enviarRegistro(tester);
      expect(auth.registros, 1);
      expect(auth.ultimaFecha, DateTime(1995, 4, 23));
    });

    testWidgets('sin fecha se registra igual (opcional)', (tester) async {
      final auth = _AuthFalso();
      await _montar(tester, const RegistroScreen(), auth);
      await _escribir(tester, 'Usuario', 'nuevo');
      await _escribir(tester, 'Correo electrónico', 'n@correo.com');
      await _escribir(tester, 'Contraseña', 'Clave1234x');
      await enviarRegistro(tester);
      expect(auth.registros, 1);
      expect(auth.ultimaFecha, isNull);
    });

    testWidgets('fecha inválida o futura: error local y no se envía', (tester) async {
      final auth = _AuthFalso();
      await _montar(tester, const RegistroScreen(), auth);
      await _escribir(tester, 'Usuario', 'nuevo');
      await _escribir(tester, 'Correo electrónico', 'n@correo.com');
      await _escribir(tester, 'Contraseña', 'Clave1234x');
      await tester.enterText(find.byKey(const Key('fecha_nacimiento')), '31022000');
      await enviarRegistro(tester);
      expect(find.text('Escribe una fecha válida (dd/mm/aaaa)'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('fecha_nacimiento')), '01012999');
      await enviarRegistro(tester);
      expect(find.text('La fecha no puede ser futura'), findsOneWidget);
      expect(auth.registros, 0);
    });

    testWidgets('el selector de fecha llena el campo en dd/mm/aaaa', (tester) async {
      await _montar(tester, const RegistroScreen(), _AuthFalso());
      await tester.ensureVisible(find.byTooltip('Elegir fecha de nacimiento'));
      await tester.tap(find.byTooltip('Elegir fecha de nacimiento'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final hoy = DateTime.now();
      final esperado = '${hoy.day.toString().padLeft(2, '0')}/${hoy.month.toString().padLeft(2, '0')}/${hoy.year - 25}';
      expect(tester.widget<TextFormField>(find.byKey(const Key('fecha_nacimiento'))).controller!.text, esperado);
    });

    testWidgets('sin aceptar los términos no se envía', (tester) async {
      final auth = _AuthFalso();
      await _montar(tester, const RegistroScreen(), auth);
      await _escribir(tester, 'Usuario', 'nuevo');
      await _escribir(tester, 'Correo electrónico', 'n@correo.com');
      await _escribir(tester, 'Contraseña', 'Clave1234x');
      final boton = find.widgetWithText(ElevatedButton, 'Crear cuenta');
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(find.text('Debes aceptar los términos para crear la cuenta'), findsOneWidget);
      expect(auth.registros, 0);
    });

    testWidgets('error por campo del backend (RN-72) bajo su campo', (tester) async {
      final auth = _AuthFalso(
        error: const AppException(
          codigo: 'DATOS_INVALIDOS',
          mensaje: 'Correo: Este correo ya esta registrado.',
          campos: {'email': 'Este correo ya esta registrado.'},
        ),
      );
      await _montar(tester, const RegistroScreen(), auth);
      await _escribir(tester, 'Usuario', 'nuevo');
      await _escribir(tester, 'Correo electrónico', 'ana@e2e.test');
      await _escribir(tester, 'Contraseña', 'Clave1234x');
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      final boton = find.widgetWithText(ElevatedButton, 'Crear cuenta');
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(auth.registros, 1);
      expect(find.text('Este correo ya esta registrado.'), findsOneWidget);
    });
  });

  group('03 Recuperar', () {
    testWidgets('503 CORREO_NO_CONFIGURADO: mensaje claro', (tester) async {
      await _montar(
        tester,
        const RecuperarPasswordScreen(),
        _AuthFalso(error: const AppException(codigo: 'CORREO_NO_CONFIGURADO', mensaje: 'x')),
      );
      await _escribir(tester, 'Correo electrónico', 'ana@e2e.test');
      await tester.tap(find.text('Enviar instrucciones'));
      await tester.pumpAndSettle();
      expect(find.textContaining('no está disponible por ahora'), findsOneWidget);
    });

    testWidgets('correo inválido: error del campo con ejemplo', (tester) async {
      await _montar(tester, const RecuperarPasswordScreen(), _AuthFalso());
      await _escribir(tester, 'Correo electrónico', 'nombre@correo');
      await tester.tap(find.text('Enviar instrucciones'));
      await tester.pumpAndSettle();
      expect(find.text('Escribe un correo válido, por ejemplo nombre@correo.com'), findsOneWidget);
    });
  });

  group('06 Cambiar contraseña', () {
    testWidgets('temporal: aviso naranja y sin flecha atrás', (tester) async {
      await _montar(tester, const CambioPasswordForzadoScreen(), _AuthFalso(temporal: true));
      expect(find.text('Cambia tu contraseña'), findsOneWidget);
      expect(find.byKey(const ValueKey('aviso-temporal')), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('voluntaria: sin aviso de temporal', (tester) async {
      await _montar(tester, const CambioPasswordForzadoScreen(temporal: false), _AuthFalso());
      expect(find.text('Cambiar contraseña'), findsWidgets);
      expect(find.byKey(const ValueKey('aviso-temporal')), findsNothing);
    });
  });

  group('AuthInterceptor (RN-07)', () {
    Future<int> llamadas(String codigo) async {
      var forzado = 0;
      final dio = Dio(BaseOptions(baseUrl: 'http://x/api'))..httpClientAdapter = _Respuesta403(codigo);
      dio.interceptors.add(AuthInterceptor(dio, _Storage(), onForcePasswordChange: () => forzado++));
      await expectLater(dio.get('/quinielas/mias/'), throwsA(isA<DioException>()));
      return forzado;
    }

    test('403 PASSWORD_TEMPORAL fuerza el cambio', () async => expect(await llamadas('PASSWORD_TEMPORAL'), 1));
    test('otro 403 (ACCESO_DENEGADO) ya NO se trata como contraseña temporal',
        () async => expect(await llamadas('ACCESO_DENEGADO'), 0));
  });
}

class _Storage extends SecureStorageService {
  @override
  Future<String?> getAccessToken() async => 'a';
  @override
  Future<void> setPassTemporal(bool value) async {}
}

class _Respuesta403 implements HttpClientAdapter {
  _Respuesta403(this.codigo);
  final String codigo;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString('{"error":{"codigo":"$codigo","mensaje":"x"}}', 403, headers: {
        Headers.contentTypeHeader: ['application/json'],
      });

  @override
  void close({bool force = false}) {}
}
