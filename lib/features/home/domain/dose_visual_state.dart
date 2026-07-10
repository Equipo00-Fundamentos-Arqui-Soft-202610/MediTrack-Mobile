import 'package:flutter/foundation.dart';
import 'package:meditrack_mobile/core/constants/app_constants.dart';
import 'package:meditrack_mobile/features/home/data/models/next_dose_model.dart';

/// Los 5 estados visuales del bloque de dosis en Home, derivados de forma
/// pura a partir de lo que ya devuelve el backend en `next-dose` — sin horas
/// hardcodeadas ni lógica de fecha repartida por la UI.
enum DoseVisualState {
  /// A. Antes del horario programado.
  beforeWindow,

  /// B. Dentro de la ventana de toma (horario + tolerancia). Botón habilitado.
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
}

class DoseCardState {
  final DoseVisualState state;

  /// Solo aplica a [DoseVisualState.rejected]: si sigue dentro de la ventana
  /// de toma y por lo tanto puede volver a grabar.
  final bool canRetry;

  const DoseCardState(this.state, {this.canRetry = false});
}

DoseCardState computeDoseState(NextDoseModel? nextDose, DateTime nowUtc) {
  if (nextDose == null) {
    return const DoseCardState(DoseVisualState.beforeWindow);
  }

  if (nextDose.isPendingValidation) {
    return const DoseCardState(DoseVisualState.pendingValidation);
  }

  final windowEnd = nextDose.scheduledAtUtc.add(
    const Duration(minutes: AppConstants.takeDoseToleranceMinutes),
  );
  final withinWindow = !nowUtc.isBefore(nextDose.scheduledAtUtc) && !nowUtc.isAfter(windowEnd);

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
      const Duration(minutes: AppConstants.takeDoseToleranceMinutes),
    );
