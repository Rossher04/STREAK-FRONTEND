import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  // URL del backend. Se define al compilar:
  //   flutter run --dart-define=API_BASE_URL=https://<app>.onrender.com/api
  // Sin ella se usa el backend local (10.0.2.2 = localhost de la PC desde el emulador Android).
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (kIsWeb) return 'http://localhost:8000/api';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000/api';
    return 'http://localhost:8000/api';
  }

  // Render (plan gratuito) puede tardar ~1 min en despertar: timeouts holgados.
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Endpoints de Autenticación (A2)
  static const String register = '/auth/register/';
  static const String login = '/auth/login/';
  static const String refreshToken = '/auth/login/refresh/';
  static const String recuperarPassword = '/auth/recuperar/';
  static const String cambiarPassword = '/auth/cambiar-password/';

  // Endpoints de Usuario (A2 / B2)
  static const String usuarioMe = '/usuarios/me/';

  // Endpoints de Torneos (A2)
  static const String torneos = '/torneos/';
  static String torneoPartidos(int torneoId) => '/torneos/$torneoId/partidos/';

  // Endpoints de Quinielas (A2 / B3 / B4 / B5)
  static const String quinielas = '/quinielas/';
  static const String quinielasUnirse = '/quinielas/unirse/';
  static const String quinielasMias = '/quinielas/mias/';
  static const String quinielasHistorial = '/quinielas/historial/';
  static String quinielaDetalle(int id) => '/quinielas/$id/';
  static String quinielaTabla(int id) => '/quinielas/$id/tabla/';
  static String quinielaPronosticos(int id) => '/quinielas/$id/pronosticos/';
  static String partidoDetalle(int qid, int pid) => '/quinielas/$qid/partidos/$pid/detalle/';

  // Endpoints de Plan Pro (A2 / B6)
  static const String proEstado = '/pro/estado/';
  static const String proSuscribir = '/pro/suscribir/';
}
