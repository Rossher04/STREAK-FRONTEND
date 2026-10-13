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

enum FasePago { inactivo, procesando, activando, pendienteActivacion, activo, error }

class EstadoPago {
  const EstadoPago(this.fase, [this.mensaje]);

  final FasePago fase;
  final String? mensaje;

  static const inactivo = EstadoPago(FasePago.inactivo);
}

final pagoProControllerProvider =
    NotifierProvider.autoDispose<PagoProController, EstadoPago>(PagoProController.new);

class PagoProController extends AutoDisposeNotifier<EstadoPago> {
  @override
  EstadoPago build() => EstadoPago.inactivo;

  int? get _usuarioId => ref.read(authControllerProvider).user?.id;

  /// Flujo completo: clave de idempotencia → POST /pro/suscribir/ → PaymentSheet → consulta de
  /// /pro/estado/ con backoff (PRO lo activa el webhook de Stripe).
  Future<void> pagar() async {
    final usuarioId = _usuarioId;
    if (usuarioId == null || state.fase == FasePago.procesando || state.fase == FasePago.activando) return;
    state = const EstadoPago(FasePago.procesando);
    final storage = ref.read(secureStorageProvider);
    try {
      // La misma clave se conserva entre reintentos (y reinicios) hasta que PRO queda activo.
      var clave = await storage.getProIdempotencyKey(usuarioId);
      if (clave == null) {
        clave = generarClaveIdempotencia();
        await storage.saveProIdempotencyKey(usuarioId, clave);
      }
      final IntentoPago intento;
      try {
        intento = await ref.read(proRepositoryProvider).iniciarPago(clave);
      } on AppException catch (e) {
        if (e.codigo == 'YA_ES_PRO') return _activar();
        state = EstadoPago(FasePago.error, mensajePago(e));
        return;
      }
      final resultado = await ref.read(pasarelaPagoProvider).cobrar(intento.clientSecret);
      if (resultado == ResultadoPasarela.cancelado) {
        state = const EstadoPago(FasePago.inactivo, 'Pago cancelado. Puedes volver a intentarlo cuando quieras.');
        return;
      }
      await verificar();
    } on AppException catch (e) {
      state = EstadoPago(FasePago.error, mensajePago(e));
    }
  }

  /// Consulta /pro/estado/ con backoff (~30 s). Si se acaba el tiempo queda "activando".
  Future<void> verificar() async {
    state = const EstadoPago(FasePago.activando);
    final espera = ref.read(esperaProProvider);
    final repo = ref.read(proRepositoryProvider);
    for (final pausa in planEspera()) {
      try {
        if (await repo.esPro()) return _activar();
      } on AppException {
        // Sin red por un momento: se sigue intentando hasta agotar el tiempo.
      }
      await espera(pausa);
    }
    state = const EstadoPago(
      FasePago.pendienteActivacion,
      'Pago recibido, activando PRO…',
    );
  }

  Future<void> _activar() async {
    final usuarioId = _usuarioId;
    if (usuarioId != null) await ref.read(secureStorageProvider).clearProIdempotencyKey(usuarioId);
    await ref.read(authControllerProvider.notifier).refrescarPerfil();
    ref.invalidate(pagosProProvider);
    state = const EstadoPago(FasePago.activo);
  }
}

/// Mensajes claros para los errores de POST /pro/suscribir/.
String mensajePago(AppException e) {
  switch (e.codigo) {
    case 'PAGOS_NO_CONFIGURADOS':
      return 'Los pagos no están disponibles por ahora. Inténtalo más tarde.';
    case 'PAGO_PENDIENTE':
      return 'Tienes un pago pendiente de otro intento. Espera unos minutos y revisa tu plan; '
          'si persiste, escribe a soporte.';
    case 'PAGO_REQUIERE_REVISION':
      return 'Tu pago anterior requiere revisión. Escribe a soporte para resolverlo.';
    case 'PROVEEDOR_PAGO_NO_DISPONIBLE':
      return 'No se pudo contactar al proveedor de pagos. Inténtalo de nuevo en un momento.';
    default:
      return e.mensaje;
  }
}
