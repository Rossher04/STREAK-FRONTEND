import 'package:flutter/services.dart';

/// Fecha de nacimiento (RN-09): se muestra como dd/mm/aaaa y viaja a la API como ISO `YYYY-MM-DD`.
/// Es solo fecha, sin hora ni zona horaria: se construye con `DateTime(a, m, d)` y nunca se convierte a UTC.
class FechaNacimiento {
  FechaNacimiento._();

  /// Edad máxima aceptada; el backend aplica el mismo tope.
  static const edadMaxima = 120;

  /// dd/mm/aaaa -> fecha. Devuelve null si el texto no es una fecha real (p. ej. 31/02/2000).
  static DateTime? parseVista(String texto) {
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(texto.trim());
    if (m == null) return null;
    return _armar(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  }

  /// YYYY-MM-DD (lo que devuelve la API) -> fecha. Null si viene vacío o inválido.
  static DateTime? parseIso(String? texto) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(texto ?? '');
    if (m == null) return null;
    return _armar(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  static DateTime? _armar(int a, int m, int d) {
    final f = DateTime(a, m, d);
    return (f.year == a && f.month == m && f.day == d) ? f : null;
  }

  static String _dos(int n) => n.toString().padLeft(2, '0');

  /// Fecha -> dd/mm/aaaa.
  static String aVista(DateTime f) => '${_dos(f.day)}/${_dos(f.month)}/${f.year.toString().padLeft(4, '0')}';

  /// Fecha -> YYYY-MM-DD.
  static String aIso(DateTime f) => '${f.year.toString().padLeft(4, '0')}-${_dos(f.month)}-${_dos(f.day)}';

  /// Primera fecha válida (hoy menos [edadMaxima] años).
  static DateTime minima([DateTime? hoy]) {
    final h = hoy ?? DateTime.now();
    return DateTime(h.year - edadMaxima, h.month, h.day);
  }

  /// Validador del campo: vacío es válido (el campo es opcional).
  static String? validar(String? texto, {DateTime? hoy}) {
    final t = texto?.trim() ?? '';
    if (t.isEmpty) return null;
    final f = parseVista(t);
    if (f == null) return 'Escribe una fecha válida (dd/mm/aaaa)';
    final h = hoy ?? DateTime.now();
    if (f.isAfter(DateTime(h.year, h.month, h.day))) return 'La fecha no puede ser futura';
    if (f.isBefore(minima(h))) return 'Revisa el año de nacimiento';
    return null;
  }
}

/// Deja solo dígitos (máx. 8) y agrega las diagonales de dd/mm/aaaa mientras se escribe.
class FormatoFechaVista extends TextInputFormatter {
  const FormatoFechaVista();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue anterior, TextEditingValue nuevo) {
    final d = nuevo.text.replaceAll(RegExp(r'\D'), '');
    final dig = d.length > 8 ? d.substring(0, 8) : d;
    final sb = StringBuffer();
    for (var i = 0; i < dig.length; i++) {
      if (i == 2 || i == 4) sb.write('/');
      sb.write(dig[i]);
    }
    final t = sb.toString();
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}
