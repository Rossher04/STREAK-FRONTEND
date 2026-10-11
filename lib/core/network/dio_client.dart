import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/application/auth_controller.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';
import 'actividad_red.dart';
import 'auth_interceptor.dart';
import 'server_clock.dart';

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(ServerClockInterceptor(ref.read(serverClockProvider)));
  // Avisa "Despertando el servidor…" si una petición pasa de 5 s y reintenta una vez ante un timeout.
  dio.interceptors.add(ActividadRedInterceptor((lento) {
    // El interceptor puede disparar tras cerrarse el contenedor (fin de pruebas); se ignora.
    try {
      ref.read(servidorLentoProvider.notifier).fijar(lento);
    } on Object {
      // nada
    }
  }));
  dio.interceptors.add(ReintentoTimeoutInterceptor(dio));

  // Los callbacks leen el controlador al momento de usarse (no al construir Dio)
  // para no crear una dependencia circular entre providers.
  dio.interceptors.add(
    AuthInterceptor(
      dio,
      storage,
      onForcePasswordChange: () =>
          ref.read(authControllerProvider.notifier).forzarCambioPassword(),
      onSessionExpired: () =>
          ref.read(authControllerProvider.notifier).sesionExpirada(),
    ),
  );

  return dio;
});
