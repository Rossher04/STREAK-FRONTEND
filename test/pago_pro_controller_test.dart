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
  _Repo({this.respuestasEstado = const [], this.errorAlIniciar, this.pendiente, this.errorAlCancelar});

  final List<bool> respuestasEstado;
  AppException? errorAlIniciar;
  final PagoPendiente? pendiente;
  final AppException? errorAlCancelar;
  final clavesUsadas = <String>[];
  final cancelados = <int>[];
  int consultas = 0;

  @override
  Future<PagoPendiente?> pagoPendiente() async => pendiente;

  @override
  Future<PagoPro> cancelarPago(int pagoId) async {
    if (errorAlCancelar != null) throw errorAlCancelar!;
    cancelados.add(pagoId);
    return PagoPro(id: pagoId, monto: '5.00', moneda: 'USD', estado: 'CANCELADO', fecha: DateTime.utc(2026));
  }

  @override
  Future<bool> esPro() async {
    final i = consultas++;
    return i < respuestasEstado.length ? respuestasEstado[i] : respuestasEstado.isNotEmpty && respuestasEstado.last;
  }

  @override
  Future<IntentoPago> iniciarPago(String claveIdempotencia) async {
    clavesUsadas.add(claveIdempotencia);
    if (errorAlIniciar != null) {
      final e = errorAlIniciar!;
      // PAGO_PENDIENTE solo para claves que no son la de la orden pendiente.
      if (e.codigo != 'PAGO_PENDIENTE' || claveIdempotencia != pendiente?.claveIdempotencia) throw e;
    }
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

  test('si el webhook tarda más de 30 s queda "En revisión" y se puede comprobar de nuevo', () async {
    final c = crear(r: _Repo(respuestasEstado: [false]));
    final ctrl = c.read(pagoProControllerProvider.notifier);
    await ctrl.pagar();

    final estado = c.read(pagoProControllerProvider);
    expect(estado.fase, FasePago.enRevision);
    expect(estado.esResultado, isTrue);
    expect(estado.mensaje, mensajeEnRevision);
    expect(estado.codigo, 'TIEMPO_AGOTADO');
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

  test('409 PAGO_PENDIENTE sin orden recuperable: "En revisión" con explicación', () async {
    final c = crear(r: _Repo(errorAlIniciar: const AppException(codigo: 'PAGO_PENDIENTE', mensaje: 'x')));
    await c.read(pagoProControllerProvider.notifier).pagar();
    final estado = c.read(pagoProControllerProvider);
    expect(estado.fase, FasePago.enRevision);
    expect(estado.mensaje, contains('compra pendiente'));
    expect(pasarela.cobros, 0);
  });

  test('409 PAGO_PENDIENTE con la clave perdida: se recupera de /pro/pago-pendiente/ y se reintenta con ella',
      () async {
    final r = _Repo(
      respuestasEstado: [true],
      errorAlIniciar: const AppException(codigo: 'PAGO_PENDIENTE', mensaje: 'x'),
      pendiente: _pendiente('clave-del-otro-telefono'),
    );
    final c = crear(r: r);
    await c.read(pagoProControllerProvider.notifier).pagar();
    expect(r.clavesUsadas.length, 2);
    expect(r.clavesUsadas.last, 'clave-del-otro-telefono');
    expect(pasarela.cobros, 1, reason: 'se abre la hoja de Stripe de la MISMA orden');
    expect(c.read(pagoProControllerProvider).fase, FasePago.activo);
  });

  test('revisarPendiente guarda la clave recuperada y expone la compra para cancelarla', () async {
    final r = _Repo(pendiente: _pendiente('clave-recuperada'));
    final c = crear(r: r);
    await c.read(pagoProControllerProvider.notifier).revisarPendiente();
    expect(storage.claves[7], 'clave-recuperada');
    expect(c.read(pagoProControllerProvider).pendiente?.pago.id, 41);
  });

  test('cancelar la compra pendiente: POST cancelar, borra la clave y vuelve al resumen', () async {
    final r = _Repo(pendiente: _pendiente('k-pendiente-1'));
    final c = crear(r: r);
    final ctrl = c.read(pagoProControllerProvider.notifier);
    await ctrl.revisarPendiente();
    await ctrl.cancelarPendiente();
    expect(r.cancelados, [41]);
    expect(storage.claves, isEmpty);
    final estado = c.read(pagoProControllerProvider);
    expect(estado.fase, FasePago.inactivo);
    expect(estado.pendiente, isNull);
    expect(estado.mensaje, contains('cancelada'));
  });

  test('409 PAGO_NO_CANCELABLE al cancelar: se comprueba el plan (ya estaba pagado)', () async {
    final r = _Repo(
      respuestasEstado: [true],
      pendiente: _pendiente('k-pendiente-1'),
      errorAlCancelar: const AppException(codigo: 'PAGO_NO_CANCELABLE', mensaje: 'x'),
    );
    final c = crear(r: r);
    final ctrl = c.read(pagoProControllerProvider.notifier);
    await ctrl.revisarPendiente();
    await ctrl.cancelarPendiente();
    expect(c.read(pagoProControllerProvider).fase, FasePago.activo);
  });

  test('409 PAGO_REQUIERE_REVISION: "En revisión" sin abrir la hoja', () async {
    final c = crear(r: _Repo(errorAlIniciar: const AppException(codigo: 'PAGO_REQUIERE_REVISION', mensaje: 'x')));
    await c.read(pagoProControllerProvider.notifier).pagar();
    final estado = c.read(pagoProControllerProvider);
    expect(estado.fase, FasePago.enRevision);
    expect(estado.mensaje, contains('revisión manual'));
    expect(pasarela.cobros, 0);
  });

  test('502 del proveedor: variante de error (Reintentar)', () async {
    final c = crear(r: _Repo(errorAlIniciar: const AppException(codigo: 'PROVEEDOR_PAGO_NO_DISPONIBLE', mensaje: 'x')));
    await c.read(pagoProControllerProvider.notifier).pagar();
    expect(c.read(pagoProControllerProvider).fase, FasePago.error);
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

PagoPendiente _pendiente(String clave) => PagoPendiente(
      pago: PagoPro(id: 41, monto: '5.00', moneda: 'USD', estado: 'PENDIENTE', fecha: DateTime.utc(2026, 10, 1)),
      claveIdempotencia: clave,
      estadoStripe: 'requires_payment_method',
    );

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
