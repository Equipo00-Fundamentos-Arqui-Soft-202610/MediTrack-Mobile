import 'dart:convert';

/// Decodifica el payload de un JWT sin verificar la firma (solo lectura de
/// claims en cliente; la verificación real ocurre en el backend).
/// No se agrega un paquete externo porque el decodificado es trivial: un JWT
/// es `header.payload.signature` en base64url.
Map<String, dynamic> decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    throw const FormatException('Token JWT con formato inválido');
  }

  final normalized = base64Url.normalize(parts[1]);
  final decoded = utf8.decode(base64Url.decode(normalized));
  final payload = jsonDecode(decoded);

  if (payload is! Map<String, dynamic>) {
    throw const FormatException('Payload de JWT inválido');
  }

  return payload;
}
