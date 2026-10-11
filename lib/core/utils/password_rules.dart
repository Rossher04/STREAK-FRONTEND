/// RN-03: mínimo 8 caracteres, al menos una letra y un número.
class PasswordRules {
  static final _letter = RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]');
  static final _digit = RegExp(r'[0-9]');

  static String? validate(String? value, {String label = 'Contraseña'}) {
    if (value == null || value.isEmpty) return 'Ingresa $label'.toLowerCase();
    if (value.length < 8) return 'Mínimo 8 caracteres (RN-03)';
    if (!_letter.hasMatch(value) || !_digit.hasMatch(value)) {
      return 'Debe incluir al menos una letra y un número (RN-03)';
    }
    return null;
  }
}
