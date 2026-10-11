/// Configuración que NO puede quedar con valores de desarrollo en una app publicada.
///
/// Se valida en dos sitios con las mismas reglas: al compilar (android/app/build.gradle.kts,
/// tareas de release) y, como segunda red, al arrancar un build de release (main.dart).
library;

const marcadorCorreoSoporte = '[CORREO_SOPORTE]';

/// Devuelve los problemas encontrados (lista vacía = configuración publicable).
List<String> problemasDeConfiguracion({
  required String correoSoporte,
  required String apiBaseUrl,
}) {
  final problemas = <String>[];
  final correo = correoSoporte.trim();
  if (correo.isEmpty || correo == marcadorCorreoSoporte || correo.contains('[') || !correo.contains('@')) {
    problemas.add('SUPPORT_EMAIL falta o es un marcador: compila con --dart-define=SUPPORT_EMAIL=<correo-de-soporte>');
  }
  if (!apiBaseUrl.startsWith('https://')) {
    problemas.add(
      'API_BASE_URL falta o no es https (en release sería el backend local): '
      'compila con --dart-define=API_BASE_URL=https://<tu-backend>/api',
    );
  }
  return problemas;
}
