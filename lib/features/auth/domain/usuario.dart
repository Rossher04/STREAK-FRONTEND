class Usuario {
  const Usuario({
    required this.id,
    required this.username,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.telefono = '',
    this.fotoUrl,
    this.esPro = false,
    this.passTemporal = false,
  });

  /// Construye el usuario desde la respuesta de GET/PATCH /usuarios/me/.
  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      telefono: json['telefono'] as String? ?? '',
      fotoUrl: json['foto'] as String?,
      esPro: json['es_pro'] == true,
      passTemporal: json['pass_temporal_flag'] == true,
    );
  }

  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String telefono;
  final String? fotoUrl;
  final bool esPro;
  final bool passTemporal;

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isEmpty ? username : full;
  }

  Usuario copyWith({bool? passTemporal}) {
    return Usuario(
      id: id,
      username: username,
      email: email,
      firstName: firstName,
      lastName: lastName,
      telefono: telefono,
      fotoUrl: fotoUrl,
      esPro: esPro,
      passTemporal: passTemporal ?? this.passTemporal,
    );
  }
}

enum AuthStatus { unknown, unauthenticated, needsPasswordChange, authenticated }

class AuthSession {
  const AuthSession({
    required this.status,
    this.user,
    this.message,
    this.offlineDesde,
  });

  final AuthStatus status;
  final Usuario? user;
  final String? message;

  /// != null: el usuario sale de la copia guardada (sin conexión, RN-74) de ese instante (UTC).
  final DateTime? offlineDesde;

  static const unknown = AuthSession(status: AuthStatus.unknown);
  static const loggedOut = AuthSession(status: AuthStatus.unauthenticated);
}
