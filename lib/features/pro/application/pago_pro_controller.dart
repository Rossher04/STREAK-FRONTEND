import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../auth/application/auth_controller.dart';
import '../data/pro_repository.dart';
import '../domain/pro_reglas.dart';

final proRepositoryProvider = Provider<ProRepository>((ref) => ProRepository(ref.watch(dioProvider)));

/// Estado y precio del plan (GET /pro/estado/).
final estadoProProvider = FutureProvider.autoDispose<EstadoPro>((ref) {
  return ref.watch(proRepositoryProvider).estado();
});

/// Historial de pagos (GET /pro/pagos/).
final pagosProProvider = FutureProvider.autoDispose<List<PagoPro>>((ref) {
  return ref.watch(proRepositoryProvider).pagos();
});

enum ResultadoPasarela { pagado, cancelado }

/// La tarjeta jamás pasa por nuestro código: la captura el PaymentSheet de Stripe.
abstract class PasarelaPago {
  Future<ResultadoPasarela> cobrar(String clientSecret);
}

class StripePasarela implements PasarelaPago {
  @override
  Future<ResultadoPasarela> cobrar(String clientSecret) async {
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: AppConstants.appName,
      ),
    );
    try {
      await Stripe.instance.presentPaymentSheet();
      return ResultadoPasarela.pagado;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return ResultadoPasarela.cancelado;
      throw AppException(
        codigo: 'PAGO_FALLIDO',
        mensaje: e.error.localizedMessage ?? 'No se pudo completar el pago. Revisa los datos e inténtalo de nuevo.',
      );
    }
  }
}

final pasarelaPagoProvider = Provider<PasarelaPago>((ref) => StripePasarela());

/// Permite sustituir la espera real en pruebas.
final esperaProProvider = Provider<Future<void> Function(Duration)>((ref) => (d) => Future<void>.delayed(d));

/// ¿Se puede cobrar en este dispositivo? Falta la clave publicable o la plataforma no soporta
/// PaymentSheet (solo Android e iOS).
String? motivoPagosNoDisponibles() {
  if (AppConstants.stripePublishableKey.isEmpty) {
    // El detalle técnico (falta --dart-define=STRIPE_PUBLISHABLE_KEY) no se muestra al usuario final.
    return 'Los pagos aún no están disponibles en esta versión de la app.';
  }
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
    return 'El pago con tarjeta solo está disponible en la app de Android o iOS.';
  }
  return null;
}

/// Motivo por el que no se puede cobrar en este dispositivo (null si se puede). Se sustituye en pruebas.
final motivoPagosNoDisponiblesProvider = Provider<String?>((ref) => motivoPagosNoDisponibles());

/// Fases del pago. Pantalla 23 (resumen): inactivo / procesando / activando.
/// Pantalla 24: activo ("¡Ya eres PRO!"), enRevision ("En revisión") y error (con "Reintentar").
enum FasePago { inactivo, procesando, activando, enRevision, activo, error }

class EstadoPago {
  const EstadoPago(this.fase, [this.mensaje, this.pendiente, this.codigo]);

  final FasePago fase;
  final String? mensaje;

  /// Compra pendiente recuperada con GET /pro/pago-pendiente/ (se puede cancelar).
  final PagoPendiente? pendiente;

  /// Código del backend del último error (p. ej. PAGOS_NO_CONFIGURADOS) o TIEMPO_AGOTADO.
  final String? codigo;

  bool get ocupado => fase == FasePago.procesando || fase == FasePago.activando;

  /// ¿Se muestra la pantalla 24 (resultado) en lugar del resumen?
  bool get esResultado => fase == FasePago.activo || fase == FasePago.enRevision || fase == FasePago.error;

  static const inactivo = EstadoPago(FasePago.inactivo);
}

const mensajeEnRevision = 'Recibimos tu pago y lo estamos confirmando con Stripe. Puede tardar unos minutos; '
    'tu plan se activará solo, sin un segundo cobro.';

final pagoProControllerProvider =
    NotifierProvider.autoDispose<PagoProController, EstadoPago>(PagoProController.new);

class PagoProController extends AutoDisposeNotifier<EstadoPago> {
  @override
  EstadoPago build() => EstadoPago.inactivo;

  int? get _usuarioId => ref.read(authControllerProvider).user?.id;

  ProRepository get _repo => ref.read(proRepositoryProvider);

  /// Al abrir la pantalla de pago: ¿hay una compra pendiente de otro intento u otro teléfono?
  /// Si la hay, se recupera su Idempotency-Key (cubre la pérdida de la clave local) para que
  /// "Pagar" reanude ESA orden sin crear un segundo cobro, y se ofrece cancelarla.
  Future<void> revisarPendiente() async {
    final usuarioId = _usuarioId;
    if (usuarioId == null) return;
    try {
      final pendiente = await _repo.pagoPendiente();
      if (pendiente == null) {
        if (state.pendiente != null) state = EstadoPago(state.fase, state.mensaje, null, state.codigo);
        return;
      }
      await _guardarClaveRecuperada(usuarioId, pendiente);
      if (!state.ocupado) state = EstadoPago(state.fase, state.mensaje, pendiente, state.codigo);
    } on AppException {
      // 503 sin pagos configurados, 502 o sin red: el resumen se muestra igual; el error real
      // (si lo hay) aparece al pulsar "Pagar".
    }
  }

  Future<void> _guardarClaveRecuperada(int usuarioId, PagoPendiente p) async {
    final clave = p.claveIdempotencia;
    if (clave != null && clave.isNotEmpty) {
      await ref.read(secureStorageProvider).saveProIdempotencyKey(usuarioId, clave);
    }
  }

  /// Flujo completo: clave de idempotencia → POST /pro/suscribir/ → PaymentSheet → consulta de
  /// /pro/estado/ con backoff (PRO lo activa el webhook de Stripe).
  Future<void> pagar() async {
    final usuarioId = _usuarioId;
    if (usuarioId == null || state.ocupado) return;
    final pendiente = state.pendiente;
    state = EstadoPago(FasePago.procesando, null, pendiente);
    final storage = ref.read(secureStorageProvider);
    try {
      // La misma clave se conserva entre reintentos (y reinicios) hasta que PRO queda activo.
      var clave = await storage.getProIdempotencyKey(usuarioId);
      if (clave == null) {
        clave = generarClaveIdempotencia();
        await storage.saveProIdempotencyKey(usuarioId, clave);
      }
      IntentoPago intento;
      try {
        intento = await _repo.iniciarPago(clave);
      } on AppException catch (e) {
        if (e.codigo == 'YA_ES_PRO') return _activar();
        if (e.codigo != 'PAGO_PENDIENTE') return _fallo(e, pendiente);
        // Hay otra orden pendiente con una clave que este teléfono no tiene: se recupera y se
        // reintenta UNA vez con ella (misma orden, sin segundo cobro).
        final recuperada = await _recuperarPendiente(usuarioId);
        final otra = recuperada?.claveIdempotencia;
        if (recuperada == null || otra == null || otra == clave) {
          state = EstadoPago(FasePago.enRevision, mensajePago(e), recuperada ?? pendiente, e.codigo);
          return;
        }
        intento = await _repo.iniciarPago(otra);
      }
      final resultado = await ref.read(pasarelaPagoProvider).cobrar(intento.clientSecret);
      if (resultado == ResultadoPasarela.cancelado) {
        state = EstadoPago(
            FasePago.inactivo, 'Pago cancelado. Puedes volver a intentarlo cuando quieras.', state.pendiente);
        return;
      }
      await verificar();
    } on AppException catch (e) {
      _fallo(e, state.pendiente);
    }
  }

  Future<PagoPendiente?> _recuperarPendiente(int usuarioId) async {
    try {
      final p = await _repo.pagoPendiente();
      if (p != null) await _guardarClaveRecuperada(usuarioId, p);
      return p;
    } on AppException {
      return null;
    }
  }

  void _fallo(AppException e, PagoPendiente? pendiente) {
    final revision = e.codigo == 'PAGO_REQUIERE_REVISION' || e.codigo == 'PAGO_PENDIENTE';
    state = EstadoPago(revision ? FasePago.enRevision : FasePago.error, mensajePago(e), pendiente, e.codigo);
  }

  /// Consulta /pro/estado/ con backoff (~30 s). Si se acaba el tiempo queda "En revisión".
  Future<void> verificar() async {
    final pendiente = state.pendiente;
    state = EstadoPago(FasePago.activando, null, pendiente);
    final espera = ref.read(esperaProProvider);
    for (final pausa in planEspera()) {
      try {
        if (await _repo.esPro()) return _activar();
      } on AppException {
        // Sin red por un momento: se sigue intentando hasta agotar el tiempo.
      }
      await espera(pausa);
    }
    state = EstadoPago(FasePago.enRevision, mensajeEnRevision, pendiente, 'TIEMPO_AGOTADO');
  }

  /// Cancela la compra pendiente (POST /pro/pagos/{id}/cancelar/). Si Stripe ya la liquidó
  /// (409 PAGO_NO_CANCELABLE) se comprueba el plan: puede que ya seas PRO.
  Future<void> cancelarPendiente() async {
    final usuarioId = _usuarioId;
    final pendiente = state.pendiente;
    if (usuarioId == null || pendiente == null || state.ocupado) return;
    state = EstadoPago(FasePago.procesando, null, pendiente);
    try {
      await _repo.cancelarPago(pendiente.pago.id);
      await ref.read(secureStorageProvider).clearProIdempotencyKey(usuarioId);
      ref.invalidate(pagosProProvider);
      state = const EstadoPago(FasePago.inactivo, 'Compra pendiente cancelada. No se hizo ningún cobro.');
    } on AppException catch (e) {
      if (e.codigo == 'PAGO_NO_CANCELABLE') return verificar();
      state = EstadoPago(FasePago.error, mensajePago(e), pendiente, e.codigo);
    }
  }

  /// Vuelve al resumen (pantalla 23) desde el resultado.
  void volverAlResumen() => state = EstadoPago(FasePago.inactivo, null, state.pendiente);

  Future<void> _activar() async {
    final usuarioId = _usuarioId;
    if (usuarioId != null) await ref.read(secureStorageProvider).clearProIdempotencyKey(usuarioId);
    try {
      await ref.read(authControllerProvider.notifier).refrescarPerfil();
    } on AppException {
      // El plan ya está activo en el servidor; el perfil se refresca en la próxima carga.
    }
    ref.invalidate(pagosProProvider);
    ref.invalidate(estadoProProvider);
    state = const EstadoPago(FasePago.activo);
  }
}

/// Mensajes claros para los errores de /pro/suscribir/, /pro/pago-pendiente/ y cancelar.
String mensajePago(AppException e) {
  switch (e.codigo) {
    case 'PAGOS_NO_CONFIGURADOS':
      return 'Los pagos no están disponibles por ahora. No se hizo ningún cobro; inténtalo más tarde.';
    case 'PAGO_PENDIENTE':
      return 'Tienes una compra pendiente de otro intento. Espera unos minutos y comprueba tu plan, '
          'o cancela esa compra para empezar de nuevo.';
    case 'PAGO_REQUIERE_REVISION':
      return 'Tu compra anterior necesita una revisión manual. No se creará otro cobro: '
          'escribe a ${AppConstants.correoSoporte} para resolverlo.';
    case 'PAGO_NO_CANCELABLE':
      return 'Ese pago ya se procesó y no se puede cancelar.';
    case 'PAGO_INCONSISTENTE':
      return 'No pudimos verificar el pago. No se creará otro cobro: escribe a ${AppConstants.correoSoporte}.';
    case 'PROVEEDOR_PAGO_NO_DISPONIBLE':
      return 'No se pudo contactar al proveedor de pagos. Inténtalo de nuevo en un momento.';
    default:
      return e.mensaje;
  }
}
