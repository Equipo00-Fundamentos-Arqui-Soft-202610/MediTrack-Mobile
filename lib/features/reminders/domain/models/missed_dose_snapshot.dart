/// Información mínima de una ocurrencia de dosis que el coordinador acaba de
/// cerrar automáticamente como "no tomada" (registrada con éxito en
/// FollowUp-Service como `skipped`), para que Home pueda mostrarla una vez
/// aunque el backend ya no la incluya en la respuesta de `next-dose`
/// (next-dose la excluye correctamente tras quedar resuelta).
class MissedDoseSnapshot {
  final int doseScheduleId;
  final DateTime scheduledAtUtc;
  final String medicationName;
  final String dose;

  const MissedDoseSnapshot({
    required this.doseScheduleId,
    required this.scheduledAtUtc,
    required this.medicationName,
    required this.dose,
  });
}
