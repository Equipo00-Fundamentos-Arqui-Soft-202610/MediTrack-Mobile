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
  });

  bool get isPaciente => rol.toLowerCase() == 'paciente' || rol.toLowerCase() == 'patient';

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
    );
  }
}
