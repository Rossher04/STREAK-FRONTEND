class Usuario {
  const Usuario({
    required this.id,
    required this.username,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.telefono = '',
    this.fechaNacimiento,
    this.fotoPath,
    this.esPro = false,
    this.passTemporal = false,
  });

  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String telefono;
  final DateTime? fechaNacimiento;
  final String? fotoPath;
  final bool esPro;
  final bool passTemporal;

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isEmpty ? username : full;
  }

  Usuario copyWith({
    String? firstName,
    String? lastName,
    String? telefono,
    DateTime? fechaNacimiento,
    String? fotoPath,
    bool? esPro,
    bool? passTemporal,
  }) {
    return Usuario(
      id: id,
      username: username,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      telefono: telefono ?? this.telefono,
      fechaNacimiento: fechaNacimiento ?? this.fechaNacimiento,
      fotoPath: fotoPath ?? this.fotoPath,
      esPro: esPro ?? this.esPro,
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
  });

  final AuthStatus status;
  final Usuario? user;
  final String? message;

  static const unknown = AuthSession(status: AuthStatus.unknown);
  static const loggedOut = AuthSession(status: AuthStatus.unauthenticated);
}
