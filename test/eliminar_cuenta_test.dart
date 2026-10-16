import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/network/dio_client.dart';
import 'package:streak_mobile/core/storage/cache_store.dart';
import 'package:streak_mobile/core/storage/secure_storage_service.dart';
import 'package:streak_mobile/core/theme/streak_theme.dart';
import 'package:streak_mobile/features/auth/application/auth_controller.dart';
import 'package:streak_mobile/features/auth/domain/usuario.dart';
import 'package:streak_mobile/features/auth/presentation/screens/eliminar_cuenta_screen.dart';

/// Servidor falso: responde DELETE /usuarios/me/ con 400 si la contraseña no es "correcta".
class _Servidor implements HttpClientAdapter {
  final peticiones = <RequestOptions>[];
  final cuerpos = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    peticiones.add(options);
    final body = (options.data is String ? jsonDecode(options.data as String) : options.data) as Map<String, dynamic>;
    cuerpos.add(body);
    if (body['password'] == 'correcta' && body['confirmar'] == true) return ResponseBody.fromString('', 204);
    return ResponseBody.fromString(
      jsonEncode({'error': {'codigo': 'CREDENCIALES_INVALIDAS', 'mensaje': 'La contrasena no es correcta.'}}),
      400,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Storage extends SecureStorageService {
  final datos = <String, String>{'access': 'a', 'refresh': 'r', 'username': 'ana', 'pro_1': 'clave-pago'};

  @override
  Future<String?> getAccessToken() async => datos['access'];
  @override
  Future<String?> getRefreshToken() async => datos['refresh'];
  @override
  Future<String?> getUsername() async => datos['username'];
  @override
  Future<String?> getProIdempotencyKey(int userId) async => datos['pro_$userId'];
  @override
  Future<void> clearProIdempotencyKey(int userId) async => datos.remove('pro_$userId');
  @override
  Future<void> clearSession() async => datos.removeWhere((k, _) => !k.startsWith('pro_'));
}

class _Auth extends AuthController {
  @override
  AuthSession build() => const AuthSession(
        status: AuthStatus.authenticated,
        user: Usuario(id: 1, username: 'ana', email: 'ana@e2e.test'),
      );
}

void main() {
  late _Servidor servidor;
  late _Storage storage;
  late MemoryCacheStore cache;
  late ProviderContainer container;

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    servidor = _Servidor();
    storage = _Storage();
    cache = MemoryCacheStore()..datos['perfil_ana'] = '{"raw": {}}';
    final dio = Dio(BaseOptions(baseUrl: 'http://local.test/api'))..httpClientAdapter = servidor;
    container = ProviderContainer(overrides: [
      dioProvider.overrideWithValue(dio),
      secureStorageProvider.overrideWithValue(storage),
      cacheStoreProvider.overrideWithValue(cache),
      authControllerProvider.overrideWith(_Auth.new),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: StreakTheme.dark(), home: const EliminarCuentaScreen()),
    ));
  }

  Future<void> eliminar(WidgetTester tester, String password) async {
    await tester.enterText(find.byKey(const ValueKey('campo-password')), password);
    await tester.tap(find.byKey(const ValueKey('boton-eliminar')));
    await tester.pumpAndSettle();
    // Doble confirmación.
    expect(find.text('¿Eliminar tu cuenta definitivamente?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirmar-eliminar')));
    await tester.pumpAndSettle();
  }

  testWidgets('pantalla 11: advertencia, contraseña y botones antes de cualquier llamada', (tester) async {
    await montar(tester);
    expect(find.text(textoAdvertenciaEliminar), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Eliminar mi cuenta'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    // Sin contraseña no se pide confirmación ni se llama a la API.
    await tester.tap(find.byKey(const ValueKey('boton-eliminar')));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa tu contraseña actual.'), findsOneWidget);
    expect(servidor.peticiones, isEmpty);
  });

  testWidgets('cancelar la segunda confirmación no llama a la API', (tester) async {
    await montar(tester);
    await tester.enterText(find.byKey(const ValueKey('campo-password')), 'correcta');
    await tester.tap(find.byKey(const ValueKey('boton-eliminar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar').last);
    await tester.pumpAndSettle();
    expect(servidor.peticiones, isEmpty);
    expect(container.read(authControllerProvider).status, AuthStatus.authenticated);
  });

  testWidgets('400: el error aparece en el campo de contraseña y no se borra nada local', (tester) async {
    await montar(tester);
    await eliminar(tester, 'equivocada');
    expect(servidor.peticiones.single.method, 'DELETE');
    expect(servidor.peticiones.single.path, '/usuarios/me/');
    expect(servidor.cuerpos.single, {'password': 'equivocada', 'confirmar': true});
    expect(find.text('La contraseña no es correcta.'), findsOneWidget);
    expect(container.read(authControllerProvider).status, AuthStatus.authenticated);
    expect(storage.datos['access'], 'a');
    expect(storage.datos['pro_1'], 'clave-pago');
    expect(cache.datos, isNotEmpty);
  });

  testWidgets('204: borra tokens, Idempotency-Key y caché, y deja la sesión cerrada con mensaje', (tester) async {
    await montar(tester);
    await eliminar(tester, 'correcta');
    expect(servidor.cuerpos.single, {'password': 'correcta', 'confirmar': true});
    expect(storage.datos, isEmpty, reason: 'tokens, usuario y clave de pago PRO borrados');
    expect(cache.datos, isEmpty);
    final sesion = container.read(authControllerProvider);
    expect(sesion.status, AuthStatus.unauthenticated);
    expect(sesion.user, isNull);
    expect(sesion.message, contains('Tu cuenta se eliminó'));
  });
}
