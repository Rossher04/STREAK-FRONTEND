import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/models.dart';

class QuinielasRepository {
  QuinielasRepository(this._dio);

  final Dio _dio;

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  List<Map<String, dynamic>> _lista(dynamic data) =>
      (data as List).cast<Map<String, dynamic>>();

  /// GET /torneos/ (activos y finalizados; los borradores no se publican).
  Future<List<Torneo>> torneos() => _call(() async {
        final resp = await _dio.get(ApiConstants.torneos);
        return _lista(resp.data).map(Torneo.fromJson).toList();
      });

  Future<List<Quiniela>> mias() => _call(() async {
        final resp = await _dio.get(ApiConstants.quinielasMias);
        return _lista(resp.data).map(Quiniela.fromJson).toList();
      });

  Future<List<Quiniela>> historial() => _call(() async {
        final resp = await _dio.get(ApiConstants.quinielasHistorial);
        return _lista(resp.data).map(Quiniela.fromJson).toList();
      });

  Future<Quiniela> detalle(int id) => _call(() async {
        final resp = await _dio.get(ApiConstants.quinielaDetalle(id));
        return Quiniela.fromJson(resp.data as Map<String, dynamic>);
      });

  /// POST /quinielas/. El creador queda inscrito automáticamente.
  Future<Quiniela> crear({
    required String nombre,
    required int torneoId,
    required int maxParticipantes,
  }) =>
      _call(() async {
        final resp = await _dio.post(ApiConstants.quinielas, data: {
          'nombre': nombre,
          'torneo': torneoId,
          'max_participantes': maxParticipantes,
        });
        return Quiniela.fromJson(resp.data as Map<String, dynamic>);
      });

  /// POST /quinielas/unirse/. Errores: QUINIELA_LLENA, YA_PARTICIPA, TORNEO_NO_ACTIVO
  /// y 404 NO_ENCONTRADO si el código no existe.
  Future<void> unirse(String codigo) => _call(() async {
        await _dio.post(ApiConstants.quinielasUnirse, data: {'codigo': codigo.trim().toUpperCase()});
      });
}
