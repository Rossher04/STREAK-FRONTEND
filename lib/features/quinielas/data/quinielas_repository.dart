import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/storage/cache_store.dart';
import '../domain/models.dart';
import '../domain/quiniela_vista.dart';
import '../domain/resumen_inicio.dart';

class QuinielasRepository {
  QuinielasRepository(this._dio, this._cache);

  final Dio _dio;
  final CacheStore _cache;

  Future<dynamic> _get(String ruta) async => (await _dio.get(ruta)).data;

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw AppException.fromDioError(e);
    }
  }

  List<Map<String, dynamic>> _lista(dynamic data) =>
      (data as List).cast<Map<String, dynamic>>();

  /// GET /torneos/ (activos y finalizados; los borradores no se publican). Datos públicos: sin red
  /// se usa la última copia (solo sirve para mostrar nombres de torneo).
  Future<List<Torneo>> torneos() async {
    try {
      final raw = await _call(() => _get(ApiConstants.torneos));
      await _guardarCopia('torneos', raw);
      return _lista(raw).map(Torneo.fromJson).toList();
    } on AppException catch (e) {
      final copia = await _copiaSiSinRed(e, 'torneos');
      if (copia == null) rethrow;
      return _lista(copia.raw).map(Torneo.fromJson).toList();
    }
  }

  Future<void> _guardarCopia(String clave, dynamic raw) =>
      _cache.guardar(clave, {'guardado': DateTime.now().toUtc().toIso8601String(), 'raw': raw});

  /// La copia guardada si el error es de red (RN-74); null si es otro error o no hay copia.
  Future<({dynamic raw, DateTime desde})?> _copiaSiSinRed(AppException e, String clave) async {
    if (e.codigo != 'NETWORK_ERROR' && e.codigo != 'TIMEOUT_ERROR') return null;
    final guardado = await _cache.leer(clave);
    if (guardado == null) return null;
    return (raw: guardado['raw'], desde: DateTime.parse(guardado['guardado'] as String));
  }

  Future<Listado<Quiniela>> _listadoConCopia(String clave, String ruta) async {
    try {
      final raw = await _call(() => _get(ruta));
      await _guardarCopia(clave, raw);
      return Listado(items: _lista(raw).map(Quiniela.fromJson).toList());
    } on AppException catch (e) {
      final copia = await _copiaSiSinRed(e, clave);
      if (copia == null) rethrow;
      return Listado(items: _lista(copia.raw).map(Quiniela.fromJson).toList(), offlineDesde: copia.desde);
    }
  }

  /// /quinielas/mias/ con copia por usuario para el modo lectura sin conexión.
  Future<Listado<Quiniela>> miasConCopia(int usuarioId) =>
      _listadoConCopia('u${usuarioId}_mias', ApiConstants.quinielasMias);

  /// /quinielas/historial/ con copia por usuario.
  Future<Listado<Quiniela>> historialConCopia(int usuarioId) =>
      _listadoConCopia('u${usuarioId}_historial', ApiConstants.quinielasHistorial);

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

  /// Partidos de una quiniela reducidos a lo que necesita el chip del Inicio (estado, cierre y si ya pronostiqué).
  Future<List<PartidoResumen>> resumenPartidos(int quinielaId) => _call(() async {
        final data = await _get(ApiConstants.quinielaPartidos(quinielaId));
        return _lista(data).map(PartidoResumen.fromJson).toList();
      });
}
