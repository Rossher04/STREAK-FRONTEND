import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';

/// Respuesta de POST /pro/suscribir/. El client_secret es sensible: no se imprime ni se guarda.
class IntentoPago {
  const IntentoPago({required this.pagoId, required this.referencia, required this.clientSecret, required this.estado});

  factory IntentoPago.fromJson(Map<String, dynamic> j) => IntentoPago(
        pagoId: j['pago_id'] as int,
        referencia: j['referencia'] as String? ?? '',
        clientSecret: j['client_secret'] as String,
        estado: j['estado'] as String? ?? '',
      );

  final int pagoId;
  final String referencia;
  final String clientSecret;
  final String estado;

  @override
  String toString() => 'IntentoPago(pagoId: $pagoId, estado: $estado)'; // sin client_secret
}

/// Fila de GET /pro/pagos/ (PagoSerializer).
class PagoPro {
  const PagoPro({
    required this.id,
    required this.monto,
    required this.moneda,
    required this.estado,
    required this.fecha,
    this.referencia = '',
  });

  factory PagoPro.fromJson(Map<String, dynamic> j) => PagoPro(
        id: j['id'] as int,
        monto: j['monto'].toString(),
        moneda: (j['moneda'] as String? ?? '').toUpperCase(),
        estado: j['estado'] as String? ?? '',
        fecha: DateTime.parse(j['fecha'] as String).toUtc(),
        referencia: j['referencia'] as String? ?? '',
      );

  final int id;
  final String monto; // DecimalField llega como texto, p. ej. "5.00"
  final String moneda;
  final String estado;
  final DateTime fecha;
  final String referencia;
}

/// GET /pro/pago-pendiente/ cuando hay una orden PENDIENTE o FALLIDA: permite recuperar la
/// Idempotency-Key (si el teléfono la perdió) y ofrecer cancelar la compra. El client_secret
/// no se guarda: se vuelve a obtener con POST /pro/suscribir/ y la clave recuperada.
class PagoPendiente {
  const PagoPendiente({required this.pago, required this.claveIdempotencia, required this.estadoStripe});

  factory PagoPendiente.fromJson(Map<String, dynamic> j) => PagoPendiente(
        pago: PagoPro.fromJson((j['pago'] as Map).cast<String, dynamic>()),
        claveIdempotencia: j['clave_idempotencia'] as String?,
        estadoStripe: j['estado'] as String? ?? '',
      );

  final PagoPro pago;
  final String? claveIdempotencia;
  final String estadoStripe;

  @override
  String toString() => 'PagoPendiente(pago: ${pago.id}, estado: $estadoStripe)'; // sin clave ni secreto
}

/// GET /pro/estado/: `{es_pro, plan: {monto_centavos, moneda, tipo, modo_prueba, max_participantes,
/// max_participantes_gratis}}`. El precio sale de aquí (RN-65), no de una constante de la app.
class EstadoPro {
  const EstadoPro({
    required this.esPro,
    required this.montoCentavos,
    required this.moneda,
    this.pagoUnico = true,
    this.modoPrueba = false,
    this.maxParticipantes = 100,
    this.maxParticipantesGratis = 50,
  });

  factory EstadoPro.fromJson(Map<String, dynamic> j) {
    final plan = (j['plan'] as Map?)?.cast<String, dynamic>() ?? const {};
    return EstadoPro(
      esPro: j['es_pro'] == true,
      montoCentavos: plan['monto_centavos'] as int? ?? 0,
      moneda: (plan['moneda'] as String? ?? '').toUpperCase(),
      pagoUnico: (plan['tipo'] ?? 'PAGO_UNICO') == 'PAGO_UNICO',
      modoPrueba: plan['modo_prueba'] == true,
      maxParticipantes: plan['max_participantes'] as int? ?? 100,
      maxParticipantesGratis: plan['max_participantes_gratis'] as int? ?? 50,
    );
  }

  final bool esPro;
  final int montoCentavos;
  final String moneda;
  final bool pagoUnico;
  final bool modoPrueba;
  final int maxParticipantes;
  final int maxParticipantesGratis;

  /// "$5.00".
  String get importe => '\$${(montoCentavos / 100).toStringAsFixed(2)}';

  /// "$5.00 USD" (resumen y botón de pagar).
  String get importeConMoneda => '$importe $moneda';

  /// "$5" si es entero, si no "$5.50" (chip del panel lateral).
  String get importeCorto =>
      montoCentavos % 100 == 0 ? '\$${montoCentavos ~/ 100}' : importe;
}

const _proPagoPendiente = '/pro/pago-pendiente/';
String _proCancelarPago(int id) => '/pro/pagos/$id/cancelar/';

class ProRepository {
  ProRepository(this._dio);

  final Dio _dio;

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  Future<EstadoPro> estado() => _call(() async {
        final resp = await _dio.get(ApiConstants.proEstado);
        return EstadoPro.fromJson(resp.data as Map<String, dynamic>);
      });

  Future<bool> esPro() => _call(() async {
        final resp = await _dio.get(ApiConstants.proEstado);
        return (resp.data as Map<String, dynamic>)['es_pro'] == true;
      });

  /// Errores: 503 PAGOS_NO_CONFIGURADOS, 400 YA_ES_PRO, 409 PAGO_PENDIENTE / PAGO_REQUIERE_REVISION,
  /// 502 PROVEEDOR_PAGO_NO_DISPONIBLE.
  Future<IntentoPago> iniciarPago(String claveIdempotencia) => _call(() async {
        final resp = await _dio.post(
          ApiConstants.proSuscribir,
          options: Options(headers: {'Idempotency-Key': claveIdempotencia}),
        );
        return IntentoPago.fromJson(resp.data as Map<String, dynamic>);
      });

  Future<List<PagoPro>> pagos() => _call(() async {
        final resp = await _dio.get(ApiConstants.proPagos);
        return (resp.data as List).cast<Map<String, dynamic>>().map(PagoPro.fromJson).toList();
      });

  /// null si no hay compra pendiente (`{"pago": null}`). Con una orden pendiente y Stripe sin
  /// configurar: 503 PAGOS_NO_CONFIGURADOS; 409 PAGO_REQUIERE_REVISION si no se puede conciliar.
  Future<PagoPendiente?> pagoPendiente() => _call(() async {
        final resp = await _dio.get(_proPagoPendiente);
        final data = resp.data as Map<String, dynamic>;
        return data['pago'] == null ? null : PagoPendiente.fromJson(data);
      });

  /// Cancela una orden propia no liquidada. 409 PAGO_NO_CANCELABLE si ya se liquidó.
  Future<PagoPro> cancelarPago(int pagoId) => _call(() async {
        final resp = await _dio.post(_proCancelarPago(pagoId));
        return PagoPro.fromJson(resp.data as Map<String, dynamic>);
      });
}
