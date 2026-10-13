import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/streak_theme.dart';

/// Texto que se muestra cuando el servidor tarda en responder (el plan gratuito de Render se duerme y
/// la primera petición puede tardar ~45 s).
const textoServidorDespertando = 'Despertando el servidor, puede tardar hasta un minuto…';

/// ¿Hay alguna petición en curso que ya pasó del umbral "lento"?
final servidorLentoProvider = NotifierProvider<ServidorLentoNotifier, bool>(ServidorLentoNotifier.new);

class ServidorLentoNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void fijar(bool lento) {
    if (state != lento) state = lento;
  }
}

/// Marca el servidor como "lento" cuando una petición supera [umbral] sin respuesta.
class ActividadRedInterceptor extends Interceptor {
  ActividadRedInterceptor(this._alCambiar, {this.umbral = const Duration(seconds: 5)});

  final void Function(bool lento) _alCambiar;
  final Duration umbral;
  final _temporizadores = <RequestOptions, Timer>{};
  final _lentas = <RequestOptions>{};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _temporizadores[options] = Timer(umbral, () {
      _lentas.add(options);
      _alCambiar(true);
    });
    handler.next(options);
  }

  void _terminar(RequestOptions options) {
    _temporizadores.remove(options)?.cancel();
    _lentas.remove(options);
    _alCambiar(_lentas.isNotEmpty);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _terminar(response.requestOptions);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _terminar(err.requestOptions);
    handler.next(err);
  }
}

/// Reintenta UNA vez ante un timeout: siempre si ni siquiera se logró conectar (la petición no llegó al
/// servidor) y, si ya se envió, solo en GET (idempotente). Evita fallar justo en el arranque en frío.
class ReintentoTimeoutInterceptor extends Interceptor {
  ReintentoTimeoutInterceptor(this._dio);

  final Dio _dio;
  static const _marca = 'reintento_timeout';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final o = err.requestOptions;
    final sinConectar = err.type == DioExceptionType.connectionTimeout;
    final tardo = sinConectar ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout;
    final reintentable = sinConectar || o.method.toUpperCase() == 'GET';
    if (tardo && reintentable && o.extra[_marca] != true) {
      o.extra[_marca] = true;
      try {
        return handler.resolve(await _dio.fetch<dynamic>(o));
      } on DioException catch (e) {
        return handler.next(e);
      }
    }
    handler.next(err);
  }
}

/// Aviso "Despertando el servidor…" (se usa en splash y login).
class AvisoServidorLento extends ConsumerWidget {
  const AvisoServidorLento({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(servidorLentoProvider)) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('aviso-servidor-lento'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: StreakColors.surface1,
        borderRadius: StreakRadius.campo,
        border: Border.all(color: StreakColors.line),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: StreakSize.iconSmall,
            height: StreakSize.iconSmall,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Flexible(child: Text(textoServidorDespertando, style: StreakText.cuerpoMedio)),
        ],
      ),
    );
  }
}
