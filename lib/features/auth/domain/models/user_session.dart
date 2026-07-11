/// Datos del usuario autenticado, combinando la respuesta de Identity-Service
/// (`usuario`) con el `patientId` resuelto (ver [UserSession.resolvePatientId]).
class UserSession {
  final String token;
  final int id;
  final String nombre;
  final String email;
  final String rol;
  final String? institucion;
  final String? phoneNumber;
  final String? profilePhotoUrl;
  final int? patientId;
  final String? dni;
  final DateTime? fechaNacimiento;

  const UserSession({
    required this.token,
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
    required this.institucion,
    required this.phoneNumber,
    required this.profilePhotoUrl,
    required this.patientId,
    this.dni,
    this.fechaNacimiento,
  });

  bool get isPaciente =>
      rol.toLowerCase() == 'paciente' || rol.toLowerCase() == 'patient';

  /// Edad calculada a partir de [fechaNacimiento], para no depender de un
  /// campo "edad" separado que el backend no expone (evita inconsistencias).
  int? get edad {
    final birth = fechaNacimiento;
    if (birth == null) return null;
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }

  UserSession copyWith({
    String? nombre,
    String? email,
    String? institucion,
    String? phoneNumber,
    String? profilePhotoUrl,
  }) {
    return UserSession(
      token: token,
      id: id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      rol: rol,
      institucion: institucion ?? this.institucion,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      patientId: patientId,
      dni: dni,
      fechaNacimiento: fechaNacimiento,
    );
  }

  Map<String, dynamic> toStorageJson() => {
    'id': id,
    'nombre': nombre,
    'email': email,
    'rol': rol,
    'institucion': institucion,
    'phoneNumber': phoneNumber,
    'profilePhotoUrl': profilePhotoUrl,
    'patientId': patientId,
    'dni': dni,
    'fechaNacimiento': fechaNacimiento?.toIso8601String(),
  };

  factory UserSession.fromStorageJson(String token, Map<String, dynamic> json) {
    return UserSession(
      token: token,
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      email: json['email'] as String,
      rol: json['rol'] as String,
      institucion: json['institucion'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      patientId: json['patientId'] as int?,
      dni: json['dni'] as String?,
      fechaNacimiento: json['fechaNacimiento'] != null
          ? DateTime.parse(json['fechaNacimiento'] as String)
          : null,
    );
  }
}
