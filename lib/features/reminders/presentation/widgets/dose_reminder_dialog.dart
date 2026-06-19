import 'package:flutter/material.dart';
import 'package:meditrack_mobile/features/reminders/presentation/widgets/dose_reminder_popup.dart';

Future<void> showDoseReminderDialog({
  required BuildContext context,
  required String medicationName,
  required String dose,
  required VoidCallback onTakeDose,
  required VoidCallback onPostpone,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.35),
    builder: (_) {
      return DoseReminderPopup(
        medicationName: medicationName,
        dose: dose,
        onTakeDose: onTakeDose,
        onPostpone: onPostpone,
      );
    },
  );
}
