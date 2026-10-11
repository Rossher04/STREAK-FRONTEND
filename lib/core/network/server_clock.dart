import 'dart:io' show HttpDate;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hora del servidor (RN-37): el cierre de pronósticos no debe depender del reloj del
/// teléfono. El desfase se calcula con el header `Date` de cada respuesta.
class ServerClock {
  ServerClock({DateTime Function()? reloj}) : _reloj = reloj ?? DateTime.now;

  final DateTime Function() _reloj;
  Duration _desfase = Duration.zero;
  bool _sincronizado = false;

  /// ¿Ya se recibió al menos un header Date válido?
  bool get sincronizado => _sincronizado;

  Duration get desfase => _desfase;

  /// Actualiza el desfase (servidor − teléfono) con un valor de header `Date`.
  /// Ignora valores nulos o con formato inválido.
  void actualizar(String? headerDate) {
    if (headerDate == null) return;
    try {
      final servidor = HttpDate.parse(headerDate);
      _desfase = servidor.difference(_reloj().toUtc());
      _sincronizado = true;
    } on Exception {
      // Header ilegible: se conserva el desfase anterior.
    }
  }

  /// Ahora, según el servidor, en UTC.
  DateTime ahora() => _reloj().toUtc().add(_desfase);
}

final serverClockProvider = Provider<ServerClock>((ref) => ServerClock());

/// Alimenta el [ServerClock] con el header Date de cada respuesta (también de las de error).
class ServerClockInterceptor extends Interceptor {
  ServerClockInterceptor(this._clock);

  final ServerClock _clock;

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _clock.actualizar(response.headers.value('date'));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _clock.actualizar(err.response?.headers.value('date'));
    handler.next(err);
  }
}
