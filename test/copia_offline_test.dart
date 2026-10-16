import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:streak_mobile/core/errors/app_exception.dart';
import 'package:streak_mobile/core/network/dio_client.dart';
import 'package:streak_mobile/core/storage/cache_store.dart';
import 'package:streak_mobile/core/storage/secure_storage_service.dart';
import 'package:streak_mobile/features/auth/application/auth_controller.dart';
import 'package:streak_mobile/features/auth/data/auth_repository.dart';
import 'package:streak_mobile/features/auth/domain/usuario.dart';
import 'package:streak_mobile/features/auth/presentation/screens/perfil_screen.dart';
import 'package:streak_mobile/features/quinielas/application/quinielas_providers.dart';
import 'package:streak_mobile/features/quinielas/data/quinielas_repository.dart';
import 'package:streak_mobile/features/quinielas/domain/models.dart';
import 'package:streak_mobile/features/quinielas/presentation/screens/home_screen.dart';
import 'package:streak_mobile/features/quinielas/presentation/widgets/quiniela_widgets.dart';

/// Servidor simulado: responde con JSON fijo o, con `enLinea = false`, falla como un teléfono sin red.
class _Servidor implements HttpClientAdapter {
  _Servidor(this.respuestas);

  final Map<String, Object> respuestas;
  bool enLinea = true;
  int? estado; // fuerza un código HTTP (p. ej. 500)

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (!enLinea) throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    final cuerpo = jsonEncode(respuestas[options.path] ?? []);
    return ResponseBody.fromString(cuerpo, estado ?? 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_Servidor s) => Dio(BaseOptions(baseUrl: 'http://x/api'))..httpClientAdapter = s;

Map<String, dynamic> _q(int id, String nombre) =>
    {'id': id, 'nombre': nombre, 'torneo': 1, 'creador': 7, 'codigo_unico': 'ABC23$id', 'max_participantes': 10};

const _perfil = {
  'id': 7,
  'username': 'ana',
  'email': 'ana@e2e.test',
  'first_name': 'Ana',
  'last_name': 'Prueba',
  'telefono': '5555',
  'foto': null,
  'es_pro': true,
  'pass_temporal_flag': false,
};

class _Storage extends SecureStorageService {
  String? access = 'a';
  String? username = 'ana';
  bool limpiada = false;
  @override
  Future<String?> getAccessToken() async => access;
  @override
  Future<String?> getUsername() async => username;
  @override
  Future<void> saveUsername(String u) async => username = u;
  @override
  Future<void> setIsPro(bool v) async {}
  @override
  Future<void> setPassTemporal(bool v) async {}
  @override
  Future<bool> isPro() async => false;
  @override
  Future<bool> isPassTemporal() async => false;
  @override
  Future<void> clearSession() async {
    limpiada = true;
    access = null;
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('Quinielas: copia offline por usuario (RN-74)', () {
    late _Servidor servidor;
    late MemoryCacheStore cache;
    late QuinielasRepository repo;

    setUp(() {
      servidor = _Servidor({
        '/quinielas/mias/': [_q(1, 'Una'), _q(2, 'Dos')],
        '/quinielas/historial/': [_q(3, 'Vieja')],
        '/torneos/': [
          {'id': 1, 'nombre': 'Liga', 'formato': 'LIGA', 'temporada': '2026', 'estado': 'ACTIVO'},
        ],
      });
      cache = MemoryCacheStore();
      repo = QuinielasRepository(_dio(servidor), cache);
    });

    test('mias: con red no marca offline; sin red devuelve la última copia con su hora', () async {
      final enLinea = await repo.miasConCopia(7);
      expect(enLinea.offline, isFalse);
      expect(enLinea.items.map((q) => q.nombre), ['Una', 'Dos']);

      servidor.enLinea = false;
      final sinRed = await repo.miasConCopia(7);
      expect(sinRed.offline, isTrue);
      expect(sinRed.items.map((q) => q.nombre), ['Una', 'Dos']);
      expect(sinRed.offlineDesde!.difference(DateTime.now().toUtc()).abs(), lessThan(const Duration(minutes: 1)));
    });

    test('historial tiene su propia copia', () async {
      await repo.historialConCopia(7);
      servidor.enLinea = false;
      final sinRed = await repo.historialConCopia(7);
      expect(sinRed.offline, isTrue);
      expect(sinRed.items.single.nombre, 'Vieja');
    });

    test('la copia es por usuario: otro usuario sin copia recibe el error de red', () async {
      await repo.miasConCopia(7);
      servidor.enLinea = false;
      await expectLater(
        repo.miasConCopia(8),
        throwsA(isA<AppException>().having((e) => e.codigo, 'codigo', 'NETWORK_ERROR')),
      );
      expect(cache.datos.keys, ['u7_mias']);
    });

    test('sin copia previa el error de red se propaga', () async {
      servidor.enLinea = false;
      await expectLater(repo.miasConCopia(7), throwsA(isA<AppException>()));
    });

    test('un error del servidor (500) NO se disfraza con la copia', () async {
      await repo.miasConCopia(7);
      servidor.estado = 500;
      await expectLater(
        repo.miasConCopia(7),
        throwsA(isA<AppException>().having((e) => e.codigo, 'codigo', 'HTTP_500')),
      );
    });

    test('torneos usa la copia sin red (para mostrar nombres)', () async {
      await repo.torneos();
      servidor.enLinea = false;
      expect((await repo.torneos()).single.nombre, 'Liga');
    });
  });

  group('Perfil: copia offline y borrado de caché', () {
    test('restoreSession en línea guarda el perfil; sin red lo devuelve completo y marcado', () async {
      final servidor = _Servidor({'/usuarios/me/': _perfil});
      final cache = MemoryCacheStore();
      final repo = AuthRepository(_dio(servidor), _Storage(), cache);

      final conRed = await repo.restoreSession();
      expect(conRed!.offlineDesde, isNull);
      expect(conRed.usuario.email, 'ana@e2e.test');
      expect(cache.datos.keys, ['perfil_ana']);

      servidor.enLinea = false;
      final sinRed = await repo.restoreSession();
      expect(sinRed!.offlineDesde, isNotNull);
      expect(sinRed.usuario.id, 7);
      expect(sinRed.usuario.email, 'ana@e2e.test', reason: 'antes se perdían correo, nombre y id');
      expect(sinRed.usuario.firstName, 'Ana');
      expect(sinRed.usuario.esPro, isTrue);
    });

    test('sin red y sin copia solo se conoce el usuario (no se inventan datos)', () async {
      final servidor = _Servidor({})..enLinea = false;
      final r = await AuthRepository(_dio(servidor), _Storage(), MemoryCacheStore()).restoreSession();
      expect(r!.offlineDesde, isNull);
      expect(r.usuario.username, 'ana');
      expect(r.usuario.email, '');
    });

    Future<ProviderContainer> contenedor(MemoryCacheStore cache) async {
      final c = ProviderContainer(overrides: [
        secureStorageProvider.overrideWithValue(_Storage()),
        cacheStoreProvider.overrideWithValue(cache),
        // Sin red y sin copia: la sesión se restaura solo con el usuario guardado (queda autenticada).
        dioProvider.overrideWithValue(_dio(_Servidor({})..enLinea = false)),
      ]);
      addTearDown(c.dispose);
      c.listen(authControllerProvider, (_, __) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return c;
    }

    test('cerrar sesión borra la caché', () async {
      final cache = MemoryCacheStore()
        ..datos['u7_mias'] = '{}'
        ..datos['perfil_ana'] = '{}';
      final c = await contenedor(cache);
      await c.read(authControllerProvider.notifier).logout();
      expect(cache.datos, isEmpty);
    });

    test('al expirar la sesión también se borra la caché', () async {
      final cache = MemoryCacheStore()..datos['u7_historial'] = '{}';
      final c = await contenedor(cache);
      expect(c.read(authControllerProvider).status, AuthStatus.authenticated);
      c.read(authControllerProvider.notifier).sesionExpirada();
      await Future<void>.delayed(Duration.zero);
      expect(cache.datos, isEmpty);
    });
  });

  group('Widgets', () {
    final desde = DateTime.utc(2026, 10, 12, 15, 30);

    Future<void> montarHome(WidgetTester tester, {DateTime? offline}) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      Listado<Quiniela> lista(List<Quiniela> q) => Listado(items: q, offlineDesde: offline);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => _AuthFalso(const Usuario(id: 7, username: 'ana', email: 'a@a'))),
          misQuinielasProvider.overrideWith((ref) async => lista([
                const Quiniela(id: 1, nombre: 'Mi quiniela', torneoId: 1, creadorId: 7, codigoUnico: 'ABC234', maxParticipantes: 10),
              ])),
          historialProvider.overrideWith((ref) async => lista([])),
          torneosProvider.overrideWith((ref) async => [
                const Torneo(id: 1, nombre: 'Liga', formato: 'LIGA', temporada: '2026', estado: 'ACTIVO'),
              ]),
          resumenPartidosProvider.overrideWith((ref, id) async => const []),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('Home con copia offline: banner con la hora y datos guardados', (tester) async {
      await montarHome(tester, offline: desde);
      expect(find.text('Sin conexión · datos de ${horaLocal(desde)}'), findsOneWidget);
      expect(find.text('Mi quiniela'), findsOneWidget);
    });

    testWidgets('Home en línea: sin banner', (tester) async {
      await montarHome(tester);
      expect(find.textContaining('Sin conexión'), findsNothing);
      expect(find.text('Mi quiniela'), findsOneWidget);
    });

    testWidgets('Perfil sin conexión: banner y guardar deshabilitado', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _AuthFalso(const Usuario(id: 7, username: 'ana', email: 'ana@e2e.test'), offlineDesde: desde),
          ),
        ],
        child: const MaterialApp(home: PerfilScreen()),
      ));
      expect(find.text('Sin conexión · datos de ${horaLocal(desde)}'), findsOneWidget);
      final boton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(boton.onPressed, isNull);
      expect(find.text('Sin conexión'), findsOneWidget);
    });
  });
}

class _AuthFalso extends AuthController {
  _AuthFalso(this.usuario, {this.offlineDesde});
  final Usuario usuario;
  final DateTime? offlineDesde;

  @override
  AuthSession build() => AuthSession(status: AuthStatus.authenticated, user: usuario, offlineDesde: offlineDesde);

  @override
  Future<void> refrescarPerfil() async {}
}
