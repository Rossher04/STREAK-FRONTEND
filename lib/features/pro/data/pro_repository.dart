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
  });

  factory PagoPro.fromJson(Map<String, dynamic> j) => PagoPro(
        id: j['id'] as int,
        monto: j['monto'].toString(),
        moneda: (j['moneda'] as String? ?? '').toUpperCase(),
        estado: j['estado'] as String? ?? '',
        fecha: DateTime.parse(j['fecha'] as String).toUtc(),
      );

  final int id;
  final String monto; // DecimalField llega como texto, p. ej. "5.00"
  final String moneda;
  final String estado;
  final DateTime fecha;
}

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
}
