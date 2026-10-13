import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streak_mobile/core/errors/app_exception.dart';
import 'package:streak_mobile/core/storage/secure_storage_service.dart';
import 'package:streak_mobile/features/auth/application/auth_controller.dart';
import 'package:streak_mobile/features/auth/domain/usuario.dart';
import 'package:streak_mobile/features/pro/application/pago_pro_controller.dart';
import 'package:streak_mobile/features/pro/data/pro_repository.dart';

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
  int refrescos = 0;

  @override
  AuthSession build() => const AuthSession(
        status: AuthStatus.authenticated,
        user: Usuario(id: 7, username: 'ana', email: 'a@a.test'),
      );

  @override
  Future<void> refrescarPerfil() async {
    refrescos++;
    state = const AuthSession(
      status: AuthStatus.authenticated,
      user: Usuario(id: 7, username: 'ana', email: 'a@a.test', esPro: true),
    );
  }
}

class _Repo implements ProRepository {
  _Repo({this.respuestasEstado = const [], this.errorAlIniciar});

  final List<bool> respuestasEstado;
  final AppException? errorAlIniciar;
  final clavesUsadas = <String>[];
  int consultas = 0;

  @override
  Future<bool> esPro() async {
    final i = consultas++;
    return i < respuestasEstado.length ? respuestasEstado[i] : respuestasEstado.isNotEmpty && respuestasEstado.last;
  }

  @override
  Future<IntentoPago> iniciarPago(String claveIdempotencia) async {
    clavesUsadas.add(claveIdempotencia);
    if (errorAlIniciar != null) throw errorAlIniciar!;
    return const IntentoPago(pagoId: 1, referencia: 'pi_1', clientSecret: 'secreto', estado: 'requires_payment_method');
  }

  @override
  Future<List<PagoPro>> pagos() async => [];

  @override
  Future<EstadoPro> estado() async => const EstadoPro(esPro: false, montoCentavos: 500, moneda: 'USD');
}

class _Pasarela implements PasarelaPago {
  _Pasarela(this.resultado);

  final ResultadoPasarela resultado;
  int cobros = 0;

  @override
  Future<ResultadoPasarela> cobrar(String clientSecret) async {
    cobros++;
    return resultado;
  }
}

void main() {
  late _Storage storage;
  late _Repo repo;
  late _Pasarela pasarela;
  late List<Duration> esperas;

  ProviderContainer crear({_Repo? r, ResultadoPasarela res = ResultadoPasarela.pagado}) {
    repo = r ?? _Repo(respuestasEstado: [false, false, true]);
    pasarela = _Pasarela(res);
    esperas = [];
    final c = ProviderContainer(overrides: [
      secureStorageProvider.overrideWithValue(storage),
      authControllerProvider.overrideWith(_Auth.new),
      proRepositoryProvider.overrideWithValue(repo),
      pasarelaPagoProvider.overrideWithValue(pasarela),
      esperaProProvider.overrideWithValue((d) async => esperas.add(d)),
    ]);
    c.listen(pagoProControllerProvider, (_, __) {});
    addTearDown(c.dispose);
    return c;
  }

  setUp(() => storage = _Storage());

  test('flujo feliz: clave, PaymentSheet, backoff hasta que el webhook activa PRO', () async {
    final c = crear();
    await c.read(pagoProControllerProvider.notifier).pagar();

    expect(c.read(pagoProControllerProvider).fase, FasePago.activo);
    expect(pasarela.cobros, 1);
    expect(repo.consultas, 3);
    expect(esperas, [const Duration(seconds: 1), const Duration(seconds: 2)]);
    expect(storage.claves, isEmpty, reason: 'la clave se descarta cuando PRO queda activo');
    expect((c.read(authControllerProvider.notifier) as _Auth).refrescos, 1);
    expect(c.read(authControllerProvider).user?.esPro, isTrue);
  });

  test('cancelar el PaymentSheet conserva la clave y el reintento la reutiliza', () async {
    final c = crear(res: ResultadoPasarela.cancelado);
    final ctrl = c.read(pagoProControllerProvider.notifier);
    await ctrl.pagar();
    expect(c.read(pagoProControllerProvider).fase, FasePago.inactivo);
    expect(c.read(pagoProControllerProvider).mensaje, contains('cancelado'));
    expect(repo.consultas, 0, reason: 'no se consulta el estado si el usuario canceló');
    final primera = storage.claves[7];
    expect(primera, isNotNull);

    await ctrl.pagar();
    expect(repo.clavesUsadas, [primera, primera]);
  });

  test('si el webhook tarda más de 30 s queda "activando PRO" y se puede reintentar', () async {
    final c = crear(r: _Repo(respuestasEstado: [false]));
    final ctrl = c.read(pagoProControllerProvider.notifier);
    await ctrl.pagar();

    final estado = c.read(pagoProControllerProvider);
    expect(estado.fase, FasePago.pendienteActivacion);
    expect(estado.mensaje, 'Pago recibido, activando PRO…');
    expect(esperas.fold(Duration.zero, (a, b) => a + b), const Duration(seconds: 30));
    expect(storage.claves[7], isNotNull, reason: 'la clave sigue hasta confirmar PRO');

    // Llega el webhook: la siguiente comprobación activa PRO.
    final c2 = crear(r: _Repo(respuestasEstado: [true]));
    await c2.read(pagoProControllerProvider.notifier).verificar();
    expect(c2.read(pagoProControllerProvider).fase, FasePago.activo);
  });

  test('503 PAGOS_NO_CONFIGURADOS: mensaje claro y no se abre el PaymentSheet', () async {
    final c = crear(r: _Repo(errorAlIniciar: const AppException(codigo: 'PAGOS_NO_CONFIGURADOS', mensaje: 'x')));
    await c.read(pagoProControllerProvider.notifier).pagar();
    final estado = c.read(pagoProControllerProvider);
    expect(estado.fase, FasePago.error);
    expect(estado.mensaje, contains('no están disponibles'));
    expect(pasarela.cobros, 0);
  });

  test('409 PAGO_PENDIENTE: explica qué hacer', () async {
    final c = crear(r: _Repo(errorAlIniciar: const AppException(codigo: 'PAGO_PENDIENTE', mensaje: 'x')));
    await c.read(pagoProControllerProvider.notifier).pagar();
    expect(c.read(pagoProControllerProvider).mensaje, contains('pago pendiente'));
  });

  test('YA_ES_PRO se trata como éxito', () async {
    final c = crear(r: _Repo(errorAlIniciar: const AppException(codigo: 'YA_ES_PRO', mensaje: 'x')));
    await c.read(pagoProControllerProvider.notifier).pagar();
    expect(c.read(pagoProControllerProvider).fase, FasePago.activo);
  });

  test('un fallo de red al consultar el estado no aborta el sondeo', () async {
    final repoRed = _RepoConFallo();
    final c = crear(r: repoRed);
    await c.read(pagoProControllerProvider.notifier).pagar();
    expect(c.read(pagoProControllerProvider).fase, FasePago.activo);
  });
}

class _RepoConFallo extends _Repo {
  _RepoConFallo() : super(respuestasEstado: [true]);
  bool _fallo = false;

  @override
  Future<bool> esPro() async {
    if (!_fallo) {
      _fallo = true;
      throw const AppException(codigo: 'NETWORK_ERROR', mensaje: 'sin red');
    }
    return super.esPro();
  }
}
