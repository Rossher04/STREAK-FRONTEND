/// Enlaces profundos (Android): `streak://reset-password?uid=...&token=...`.
///
/// El backend arma el enlace como `PASSWORD_RESET_URL + '?' + urlencode({uid, token})`
/// (quinielas/views_auth.py), así que con `PASSWORD_RESET_URL=streak://reset-password` el correo trae
/// exactamente esa forma. go_router descarta el host del URI, por lo que al router puede llegar
/// `streak://reset-password?uid=..` (host conservado) o `/?uid=..` (host perdido): se aceptan ambas.
library;

const rutaEnlaceInvalido = '/enlace-invalido';

/// Ruta interna a la que se traduce un deep link de restablecer contraseña, o null si el URI no es
/// uno de esos enlaces. Sin `uid` o sin `token` (vacíos) devuelve [rutaEnlaceInvalido].
String? rutaDesdeDeepLink(Uri uri) {
  final esReset = (uri.scheme == 'streak' && uri.host == 'reset-password') || uri.path == '/reset-password';
  final traeParametros = uri.queryParameters.containsKey('uid') || uri.queryParameters.containsKey('token');
  final hostPerdido = (uri.path.isEmpty || uri.path == '/') && !uri.hasScheme && traeParametros;
  if (!esReset && !hostPerdido) return null;

  final uid = uri.queryParameters['uid']?.trim() ?? '';
  final token = uri.queryParameters['token']?.trim() ?? '';
  if (uid.isEmpty || token.isEmpty) return rutaEnlaceInvalido;
  return '/restablecer/${Uri.encodeComponent(uid)}/${Uri.encodeComponent(token)}';
}
