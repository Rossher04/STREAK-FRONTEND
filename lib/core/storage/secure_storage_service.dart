import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Almacenamiento seguro en Keychain (iOS) y EncryptedSharedPreferences (Android)
/// Cumplimiento estricto de la regla RN-04
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        );

  static const String _keyAccess = 'streak_access_token';
  static const String _keyRefresh = 'streak_refresh_token';
  static const String _keyPassTemporal = 'streak_pass_temporal_flag';
  static const String _keyIsPro = 'streak_is_pro';
  static const String _keyUsername = 'streak_username';
  static const String _keyProIdem = 'streak_pro_idempotency';

  Future<void> saveTokens({
    required String access,
    required String refresh,
    bool passTemporal = false,
  }) async {
    await _storage.write(key: _keyAccess, value: access);
    await _storage.write(key: _keyRefresh, value: refresh);
    await _storage.write(key: _keyPassTemporal, value: passTemporal.toString());
  }

  Future<void> saveAccessToken(String access) =>
      _storage.write(key: _keyAccess, value: access);

  /// Último usuario con sesión; permite mostrar algo sin conexión (modo lectura, RN-74).
  Future<void> saveUsername(String username) =>
      _storage.write(key: _keyUsername, value: username);

  Future<String?> getUsername() => _storage.read(key: _keyUsername);

  Future<String?> getAccessToken() async => await _storage.read(key: _keyAccess);
  Future<String?> getRefreshToken() async => await _storage.read(key: _keyRefresh);

  Future<bool> isPassTemporal() async {
    final val = await _storage.read(key: _keyPassTemporal);
    return val == 'true';
  }

  Future<void> setPassTemporal(bool value) async {
    await _storage.write(key: _keyPassTemporal, value: value.toString());
  }

  Future<bool> isPro() async {
    final val = await _storage.read(key: _keyIsPro);
    return val == 'true';
  }

  Future<void> setIsPro(bool value) async {
    await _storage.write(key: _keyIsPro, value: value.toString());
  }

  /// Clave de idempotencia del pago PRO en curso, por usuario. El backend solo deja reintentar
  /// una orden pendiente con SU misma clave (409 PAGO_PENDIENTE si no), así que sobrevive a
  /// reinicios de la app y al cierre de sesión.
  Future<String?> getProIdempotencyKey(int userId) => _storage.read(key: '${_keyProIdem}_$userId');

  Future<void> saveProIdempotencyKey(int userId, String key) =>
      _storage.write(key: '${_keyProIdem}_$userId', value: key);

  Future<void> clearProIdempotencyKey(int userId) => _storage.delete(key: '${_keyProIdem}_$userId');

  Future<void> clearSession() async {
    for (final k in [_keyAccess, _keyRefresh, _keyPassTemporal, _keyIsPro, _keyUsername]) {
      await _storage.delete(key: k);
    }
  }
}
