// Acciones de administrador para las e2e: ejecuta test_e2e/backend/admin.py con el venv del backend
// local (no modifica el repo del backend; solo escribe en la BD SQLite desechable de las e2e).
import 'dart:io';

/// Carpeta del clon del backend (por defecto ../streak_backend_main, como en run_backend.ps1).
String get _backend => Platform.environment['STREAK_BACKEND_DIR'] ?? '../streak_backend_main';

Future<void> adminDjango(List<String> args) async {
  final backend = Directory(_backend).absolute.path;
  final windows = Platform.isWindows;
  final python = '$backend${Platform.pathSeparator}venv${Platform.pathSeparator}${windows ? 'Scripts${Platform.pathSeparator}python.exe' : 'bin${Platform.pathSeparator}python'}';
  final aqui = Directory('test_e2e/backend').absolute.path;
  // STREAK_E2E_DB / STREAK_E2E_MEDIA permiten apuntar a un backend local propio (otro puerto y BD).
  final bd = (Platform.environment['STREAK_E2E_DB'] ?? '$backend${Platform.pathSeparator}e2e.sqlite3')
      .replaceAll(r'\', '/');
  final media = Platform.environment['STREAK_E2E_MEDIA'] ?? '$backend${Platform.pathSeparator}e2e_media';

  final r = await Process.run(
    python,
    ['-B', '$aqui${Platform.pathSeparator}admin.py', ...args],
    workingDirectory: backend,
    environment: {
      'DEBUG': 'True',
      'SECRET_KEY': 'e2e-local-key-only',
      'DATABASE_URL': 'sqlite:///$bd',
      'MEDIA_ROOT': media,
      'PYTHONPATH': '$aqui${windows ? ';' : ':'}$backend',
      'DJANGO_SETTINGS_MODULE': 'e2e_settings',
    },
  );
  if (r.exitCode != 0) {
    throw StateError('admin.py ${args.join(' ')} falló (${r.exitCode}): ${r.stderr}');
  }
}
