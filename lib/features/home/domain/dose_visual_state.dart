import 'package:flutter/foundation.dart';
import 'package:meditrack_mobile/core/constants/app_constants.dart';
import 'package:meditrack_mobile/features/home/data/models/next_dose_model.dart';
import 'package:meditrack_mobile/features/reminders/domain/models/missed_dose_snapshot.dart';

/// Los estados visuales del bloque de dosis en Home, derivados de forma pura
/// a partir de lo que devuelve el backend en `next-dose` (más, para
/// [notTaken], el último cierre automático que reportó localmente
/// `DoseReminderCoordinator`) — sin horas hardcodeadas ni lógica de fecha
/// repartida por la UI.
enum DoseVisualState {
  /// A. Antes del horario programado.
  beforeWindow,

  /// B. Dentro de la ventana de toma (horario hasta T+10, igual que el
  /// cierre del ciclo de recordatorios). Botón habilitado.
  readyToTake,

  /// C. Evidencia enviada, esperando validación humana.
  pendingValidation,

  /// D/E. Evidencia rechazada — puede reintentar si sigue en ventana.
  rejected,

  /// Pasó la ventana y nunca se envió evidencia (no es uno de los 5 estados
  /// pedidos explícitamente, pero evita dejar el botón habilitado fuera de
  /// ventana): se trata igual que "antes del horario" a efectos de UI (botón
  /// deshabilitado), solo cambia el mensaje.
  windowExpired,

  /// El ciclo de recordatorios (alarma inicial + 2 avisos) cerró sin ninguna
  /// acción del paciente: la dosis quedó registrada como no tomada en
  /// FollowUp-Service. "Tomar dosis" queda deshabilitado y no se puede abrir
  /// la cámara para esta ocurrencia.
  notTaken,
}

class DoseCardState {
  final DoseVisualState state;

  /// Solo aplica a [DoseVisualState.rejected]: si sigue dentro de la ventana
  /// de toma y por lo tanto puede volver a grabar.
  final bool canRetry;

  const DoseCardState(this.state, {this.canRetry = false});
}

DoseCardState computeDoseState(
  NextDoseModel? nextDose,
  DateTime nowUtc, {
  MissedDoseSnapshot? locallyMissedDose,
}) {
  // El backend ya no reporta esta ocurrencia en `next-dose` una vez resuelta
  // (correctamente excluida tras registrarse como "skipped"), así que la
  // única forma de mostrar "no tomada" es con el último cierre que el propio
  // coordinador confirmó contra el backend. Solo aplica mientras `next-dose`
  // no haya avanzado ya a esa misma ocurrencia con evidencia real.
  if (locallyMissedDose != null &&
      (nextDose == null ||
          nextDose.doseScheduleId != locallyMissedDose.doseScheduleId ||
          !nextDose.scheduledAtUtc.isAtSameMomentAs(
            locallyMissedDose.scheduledAtUtc,
          ))) {
    return const DoseCardState(DoseVisualState.notTaken);
  }

  if (nextDose == null) {
    return const DoseCardState(DoseVisualState.beforeWindow);
  }

  if (nextDose.isPendingValidation) {
    return const DoseCardState(DoseVisualState.pendingValidation);
  }

  final windowEnd = nextDose.scheduledAtUtc.add(
    const Duration(minutes: AppConstants.doseReminderCloseOffsetMinutes),
  );
  final withinWindow =
      !nowUtc.isBefore(nextDose.scheduledAtUtc) && !nowUtc.isAfter(windowEnd);

  if (nextDose.isRejected) {
    return DoseCardState(DoseVisualState.rejected, canRetry: withinWindow);
  }

  if (nowUtc.isBefore(nextDose.scheduledAtUtc)) {
    return const DoseCardState(DoseVisualState.beforeWindow);
  }

  if (withinWindow) {
    return const DoseCardState(DoseVisualState.readyToTake);
  }

  return const DoseCardState(DoseVisualState.windowExpired);
}

@visibleForTesting
DateTime windowEndFor(NextDoseModel nextDose) => nextDose.scheduledAtUtc.add(
  const Duration(minutes: AppConstants.doseReminderCloseOffsetMinutes),
);
