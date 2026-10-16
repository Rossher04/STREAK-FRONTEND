// RN-09: fecha de nacimiento (dd/mm/aaaa en pantalla, ISO en la API) y quiniela_id de unirse (backend #15 y #18).
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/storage/cache_store.dart';
import 'package:streak_mobile/core/storage/secure_storage_service.dart';
import 'package:streak_mobile/core/theme/streak_theme.dart';
import 'package:streak_mobile/core/utils/fecha_nacimiento.dart';
import 'package:streak_mobile/features/auth/application/auth_controller.dart';
import 'package:streak_mobile/features/auth/data/auth_repository.dart';
import 'package:streak_mobile/features/auth/domain/usuario.dart';
import 'package:streak_mobile/features/auth/presentation/screens/perfil_screen.dart';
import 'package:streak_mobile/features/quinielas/data/quinielas_repository.dart';

class _Peticion {
  _Peticion(this.metodo, this.ruta, this.datos);
  final String metodo;
  final String ruta;
  final Object? datos;
}

/// Dio sin red: registra la petición y responde [respuesta].
Dio _dioFalso(List<_Peticion> log, Object? respuesta) {
  final dio = Dio(BaseOptions(baseUrl: 'http://x.test/api'));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
    log.add(_Peticion(o.method, o.path, o.data));
    h.resolve(Response(requestOptions: o, statusCode: 200, data: respuesta));
  }));
  return dio;
}

class _AuthPerfil extends AuthController {
  _AuthPerfil(this.usuario);
  final Usuario usuario;
  DateTime? fecha;
  bool? borrar;
  int guardados = 0;

  @override
  AuthSession build() => AuthSession(status: AuthStatus.authenticated, user: usuario);

  @override
  Future<void> refrescarPerfil() async {}

  @override
  Future<void> actualizarPerfil({
    required String firstName,
    required String lastName,
    required String telefono,
    DateTime? fechaNacimiento,
    bool borrarFechaNacimiento = false,
    FotoPerfil? foto,
  }) async {
    guardados++;
    fecha = fechaNacimiento;
    borrar = borrarFechaNacimiento;
  }
}

Future<_AuthPerfil> _montarPerfil(WidgetTester tester, Usuario u) async {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final auth = _AuthPerfil(u);
  await tester.pumpWidget(ProviderScope(
    overrides: [authControllerProvider.overrideWith(() => auth)],
    child: MaterialApp(theme: StreakTheme.dark(), home: const PerfilScreen()),
  ));
  await tester.pump();
  return auth;
}

void main() {
  group('FechaNacimiento', () {
    test('dd/mm/aaaa <-> fecha <-> ISO', () {
      final f = FechaNacimiento.parseVista('05/03/1998');
      expect(f, DateTime(1998, 3, 5));
      expect(FechaNacimiento.aIso(f!), '1998-03-05');
      expect(FechaNacimiento.aVista(f), '05/03/1998');
      expect(FechaNacimiento.parseIso('1998-03-05'), DateTime(1998, 3, 5));
      expect(FechaNacimiento.aVista(FechaNacimiento.parseIso('2000-02-29')!), '29/02/2000');
    });

    test('fechas imposibles o mal formadas dan null', () {
      expect(FechaNacimiento.parseVista('31/02/2000'), isNull);
      expect(FechaNacimiento.parseVista('1998-03-05'), isNull);
      expect(FechaNacimiento.parseVista('5/3/1998'), isNull);
      expect(FechaNacimiento.parseIso(null), isNull);
      expect(FechaNacimiento.parseIso(''), isNull);
    });

    test('validar: vacío ok, futura y demasiado antigua no', () {
      final hoy = DateTime(2026, 10, 16);
      expect(FechaNacimiento.validar('', hoy: hoy), isNull);
      expect(FechaNacimiento.validar('16/10/2026', hoy: hoy), isNull);
      expect(FechaNacimiento.validar('17/10/2026', hoy: hoy), 'La fecha no puede ser futura');
      expect(FechaNacimiento.validar('16/10/1906', hoy: hoy), isNull);
      expect(FechaNacimiento.validar('15/10/1906', hoy: hoy), 'Revisa el año de nacimiento');
      expect(FechaNacimiento.validar('12/04', hoy: hoy), 'Escribe una fecha válida (dd/mm/aaaa)');
    });

    test('el formateador agrega diagonales y limita a 8 dígitos', () {
      String f(String s) => const FormatoFechaVista()
          .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: s))
          .text;
      expect(f('2304'), '23/04');
      expect(f('23041995'), '23/04/1995');
      expect(f('230419951234'), '23/04/1995');
      expect(f('23/04/1995'), '23/04/1995');
    });
  });

  group('Usuario', () {
    test('lee fecha_nacimiento ISO, null o ausente', () {
      const base = {'id': 1, 'username': 'a', 'email': 'a@a.test'};
      expect(Usuario.fromJson({...base, 'fecha_nacimiento': '1998-03-05'}).fechaNacimiento, DateTime(1998, 3, 5));
      expect(Usuario.fromJson({...base, 'fecha_nacimiento': null}).fechaNacimiento, isNull);
      expect(Usuario.fromJson(base).fechaNacimiento, isNull);
    });

    test('copyWith conserva la fecha', () {
      final u = Usuario(id: 1, username: 'a', email: 'a@a.test', fechaNacimiento: DateTime(1998, 3, 5));
      expect(u.copyWith(passTemporal: true).fechaNacimiento, DateTime(1998, 3, 5));
    });
  });

  group('AuthRepository', () {
    test('registro envía fecha_nacimiento en ISO solo si hay fecha', () async {
      final log = <_Peticion>[];
      final repo = AuthRepository(_dioFalso(log, {'access': 'a', 'refresh': 'r', 'id': 1, 'username': 'n', 'email': 'e'}), _Storage());
      try {
        await repo.register(
            username: 'n', email: 'n@a.test', password: 'Clave1234x', firstName: '', lastName: '', fechaNacimiento: DateTime(1995, 4, 23));
      } catch (_) {/* el login posterior no importa aquí */}
      expect((log.first.datos as Map)['fecha_nacimiento'], '1995-04-23');
      log.clear();
      try {
        await repo.register(username: 'n', email: 'n@a.test', password: 'Clave1234x', firstName: '', lastName: '');
      } catch (_) {}
      expect((log.first.datos as Map).containsKey('fecha_nacimiento'), isFalse);
    });

    test('PATCH de perfil: envía la fecha, la borra solo si se pide y si no la omite', () async {
      final log = <_Peticion>[];
      final repo = AuthRepository(
          _dioFalso(log, {'id': 1, 'username': 'a', 'email': 'a@a.test', 'fecha_nacimiento': '1995-04-23'}), _Storage());
      await repo.actualizarPerfil(firstName: 'A', lastName: 'B', telefono: '', fechaNacimiento: DateTime(1995, 4, 23));
      expect((log.last.datos as Map)['fecha_nacimiento'], '1995-04-23');
      await repo.actualizarPerfil(firstName: 'A', lastName: 'B', telefono: '', borrarFechaNacimiento: true);
      expect((log.last.datos as Map).containsKey('fecha_nacimiento'), isTrue);
      expect((log.last.datos as Map)['fecha_nacimiento'], isNull);
      await repo.actualizarPerfil(firstName: 'A', lastName: 'B', telefono: '');
      expect((log.last.datos as Map).containsKey('fecha_nacimiento'), isFalse);
    });
  });

  group('QuinielasRepository.unirse', () {
    test('devuelve quiniela_id cuando viene y null cuando no', () async {
      final log = <_Peticion>[];
      final conId = QuinielasRepository(_dioFalso(log, {'id': 5, 'quiniela_id': 91, 'quiniela': {'id': 91}}), MemoryCacheStore());
      expect(await conId.unirse('abc123'), 91);
      expect((log.single.datos as Map)['codigo'], 'ABC123');
      final sinId = QuinielasRepository(_dioFalso(<_Peticion>[], {'id': 5, 'usuario': 1}), MemoryCacheStore());
      expect(await sinId.unirse('abc123'), isNull);
    });
  });

  group('10 Perfil con fecha de nacimiento', () {
    testWidgets('muestra la fecha guardada en dd/mm/aaaa y la envía al guardar', (tester) async {
      final auth = await _montarPerfil(
          tester, Usuario(id: 1, username: 'ana', email: 'a@a.test', fechaNacimiento: DateTime(1995, 4, 23)));
      expect(find.text('23/04/1995'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('fecha_nacimiento')), '01022000');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(auth.guardados, 1);
      expect(auth.fecha, DateTime(2000, 2, 1));
      expect(auth.borrar, isFalse);
    });

    testWidgets('campo vacío pide borrar la fecha', (tester) async {
      final auth = await _montarPerfil(
          tester, Usuario(id: 1, username: 'ana', email: 'a@a.test', fechaNacimiento: DateTime(1995, 4, 23)));
      await tester.enterText(find.byKey(const Key('fecha_nacimiento')), '');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(auth.fecha, isNull);
      expect(auth.borrar, isTrue);
    });

    testWidgets('fecha inválida: no guarda y avisa bajo el campo', (tester) async {
      final auth = await _montarPerfil(tester, const Usuario(id: 1, username: 'ana', email: 'a@a.test'));
      await tester.enterText(find.byKey(const Key('fecha_nacimiento')), '3102');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(auth.guardados, 0);
      expect(find.text('Revisa la fecha de nacimiento (dd/mm/aaaa).'), findsOneWidget);
    });
  });
}

class _Storage extends SecureStorageService {
  @override
  Future<void> saveTokens({required String access, required String refresh, bool passTemporal = false}) async {}
  @override
  Future<void> saveUsername(String username) async {}
  @override
  Future<String?> getAccessToken() async => 'a';
}
