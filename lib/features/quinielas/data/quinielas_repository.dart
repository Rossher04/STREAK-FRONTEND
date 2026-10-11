import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/storage/cache_store.dart';
import '../domain/models.dart';
import '../domain/quiniela_vista.dart';

class QuinielasRepository {
  QuinielasRepository(this._dio, this._cache);

  final Dio _dio;
  final CacheStore _cache;

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

  Future<dynamic> _get(String ruta) async => (await _dio.get(ruta)).data;

  /// Carga todo lo de la quiniela activa. Sin red (RN-74) devuelve lo último guardado para
  /// ese usuario; si nunca se guardó nada, propaga el error de red.
  Future<QuinielaVista> vista(int quinielaId, {required int usuarioId}) async {
    final clave = 'u${usuarioId}_quiniela_$quinielaId';
    try {
      final quiniela = await _call(() => _get(ApiConstants.quinielaDetalle(quinielaId)));
      final torneoId = (quiniela as Map<String, dynamic>)['torneo'] as int;
      final resp = await _call(() => Future.wait([
            _get(ApiConstants.torneoDetalle(torneoId)),
            _get(ApiConstants.torneoEquipos(torneoId)),
            _get(ApiConstants.torneoFases(torneoId)),
            _get(ApiConstants.quinielaPartidos(quinielaId)),
            _get(ApiConstants.quinielaTabla(quinielaId)),
          ]));
      final raw = <String, dynamic>{
        'quiniela': quiniela,
        'torneo': resp[0],
        'equipos': resp[1],
        'fases': resp[2],
        'partidos': resp[3],
        'tabla': resp[4],
      };
      await _cache.guardar(clave, {'guardado': DateTime.now().toUtc().toIso8601String(), 'raw': raw});
      return QuinielaVista.fromRaw(raw);
    } on AppException catch (e) {
      if (e.codigo != 'NETWORK_ERROR' && e.codigo != 'TIMEOUT_ERROR') rethrow;
      final guardado = await _cache.leer(clave);
      if (guardado == null) rethrow;
      return QuinielaVista.fromRaw(
        guardado['raw'] as Map<String, dynamic>,
        offlineDesde: DateTime.parse(guardado['guardado'] as String),
      );
    }
  }

  /// POST /quinielas/{id}/pronosticos/ (201 si es nuevo, 200 si actualiza).
  /// Errores de negocio: PRONOSTICOS_CERRADOS, TORNEO_NO_ACTIVO.
  Future<void> guardarPronostico(int quinielaId, int partidoId, Marcador m) => _call(() async {
        await _dio.post(ApiConstants.quinielaPronosticos(quinielaId), data: {
          'partido': partidoId,
          'goles_local_pred': m.local,
          'goles_visita_pred': m.visita,
        });
      });

  Future<PartidoDetalle> partidoDetalle(int quinielaId, int partidoId) => _call(() async {
        final data = await _get(ApiConstants.partidoDetalle(quinielaId, partidoId));
        return PartidoDetalle.fromJson(data as Map<String, dynamic>);
      });

  Future<ParticipanteDetalle> participanteDetalle(int quinielaId, int usuarioId) => _call(() async {
        final data = await _get(ApiConstants.participanteDetalle(quinielaId, usuarioId));
        return ParticipanteDetalle.fromJson(data as Map<String, dynamic>);
      });
}
