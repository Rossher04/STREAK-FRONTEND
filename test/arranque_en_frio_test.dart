import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/constants/api_constants.dart';
import 'package:streak_mobile/core/network/actividad_red.dart';
import 'package:streak_mobile/core/widgets/avatar_usuario.dart';

/// Servidor simulado: falla las primeras [fallos] veces con [tipoFallo] y luego responde 200 (o [estado]).
class _Servidor implements HttpClientAdapter {
  _Servidor({this.fallos = 0, this.tipoFallo = DioExceptionType.connectionTimeout, this.demora = Duration.zero, this.estado = 200});

  int fallos;
  final DioExceptionType tipoFallo;
  final Duration demora;
  final int estado;
  int intentos = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    intentos++;
    if (demora > Duration.zero) await Future<void>.delayed(demora);
    if (intentos <= fallos) throw DioException(requestOptions: options, type: tipoFallo);
    return ResponseBody.fromString('{"ok":true}', estado, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_Servidor s, {List<Interceptor> Function(Dio)? interceptores}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://x/api', validateStatus: (c) => c != null && c < 400))
    ..httpClientAdapter = s;
  dio.interceptors.addAll(interceptores?.call(dio) ?? const []);
  return dio;
}

void main() {
  test('los timeouts cubren el arranque en frío de Render (~45 s)', () {
    expect(ApiConstants.connectTimeout, greaterThanOrEqualTo(const Duration(seconds: 60)));
    expect(ApiConstants.receiveTimeout, greaterThanOrEqualTo(const Duration(seconds: 60)));
  });

  group('ReintentoTimeoutInterceptor', () {
    test('un GET con timeout se reintenta una vez y sale bien', () async {
      final s = _Servidor(fallos: 1, tipoFallo: DioExceptionType.receiveTimeout);
      final r = await _dio(s, interceptores: (d) => [ReintentoTimeoutInterceptor(d)]).get('/torneos/');
      expect(r.statusCode, 200);
      expect(s.intentos, 2);
    });

    test('solo se reintenta UNA vez: si vuelve a fallar, el error llega', () async {
      final s = _Servidor(fallos: 5, tipoFallo: DioExceptionType.receiveTimeout);
      await expectLater(
        _dio(s, interceptores: (d) => [ReintentoTimeoutInterceptor(d)]).get('/torneos/'),
        throwsA(isA<DioException>().having((e) => e.type, 'type', DioExceptionType.receiveTimeout)),
      );
      expect(s.intentos, 2);
    });

    test('un POST que ya se envió y tardó NO se reintenta (podría duplicarse)', () async {
      final s = _Servidor(fallos: 1, tipoFallo: DioExceptionType.receiveTimeout);
      await expectLater(
        _dio(s, interceptores: (d) => [ReintentoTimeoutInterceptor(d)]).post('/quinielas/', data: {}),
        throwsA(isA<DioException>()),
      );
      expect(s.intentos, 1);
    });

    test('un POST que ni siquiera conectó sí se reintenta', () async {
      final s = _Servidor(fallos: 1, tipoFallo: DioExceptionType.connectionTimeout);
      final r = await _dio(s, interceptores: (d) => [ReintentoTimeoutInterceptor(d)]).post('/auth/login/', data: {});
      expect(r.statusCode, 200);
      expect(s.intentos, 2);
    });

    test('un error HTTP (500) no se reintenta', () async {
      final s = _Servidor(estado: 500);
      await expectLater(
        _dio(s, interceptores: (d) => [ReintentoTimeoutInterceptor(d)]).get('/torneos/'),
        throwsA(isA<DioException>()),
      );
      expect(s.intentos, 1);
    });
  });

  group('ActividadRedInterceptor ("Despertando el servidor…")', () {
    test('una petición que pasa del umbral marca lento y al terminar lo quita', () async {
      final cambios = <bool>[];
      final s = _Servidor(demora: const Duration(milliseconds: 250));
      await _dio(s, interceptores: (_) => [
            ActividadRedInterceptor(cambios.add, umbral: const Duration(milliseconds: 60)),
          ]).get('/torneos/');
      expect(cambios, [true, false]);
    });

    test('una petición rápida nunca lo marca', () async {
      final cambios = <bool>[];
      await _dio(_Servidor(), interceptores: (_) => [
            ActividadRedInterceptor(cambios.add, umbral: const Duration(milliseconds: 200)),
          ]).get('/torneos/');
      expect(cambios, [false]);
    });

    test('también se quita si la petición falla', () async {
      final cambios = <bool>[];
      final s = _Servidor(fallos: 1, tipoFallo: DioExceptionType.receiveTimeout, demora: const Duration(milliseconds: 150));
      await expectLater(
        _dio(s, interceptores: (_) => [
              ActividadRedInterceptor(cambios.add, umbral: const Duration(milliseconds: 40)),
            ]).get('/torneos/'),
        throwsA(isA<DioException>()),
      );
      expect(cambios, [true, false]);
    });
  });

  group('Widgets', () {
    testWidgets('AvisoServidorLento aparece solo cuando el servidor está lento', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: AvisoServidorLento())),
      ));
      expect(find.text(textoServidorDespertando), findsNothing);

      container.read(servidorLentoProvider.notifier).fijar(true);
      await tester.pump();
      expect(find.text(textoServidorDespertando), findsOneWidget);
      expect(find.textContaining('hasta un minuto'), findsOneWidget);

      container.read(servidorLentoProvider.notifier).fijar(false);
      await tester.pump();
      expect(find.text(textoServidorDespertando), findsNothing);
    });

    testWidgets('AvatarUsuario: si la imagen da error muestra la inicial, sin error visual', (tester) async {
      // En flutter_test toda petición HTTP responde 400: equivale a un 404 del servidor.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AvatarUsuario(nombre: 'ana', fotoUrl: 'http://x/media/perfiles/a.jpg')),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.text('A'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AvatarUsuario sin foto muestra la inicial', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AvatarUsuario(nombre: 'beto'))));
      expect(find.text('B'), findsOneWidget);
    });
  });
}
