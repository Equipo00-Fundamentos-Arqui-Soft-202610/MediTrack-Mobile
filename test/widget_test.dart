// Smoke test: sin sesión guardada, la app debe arrancar en la pantalla de
// Login (antes probaba el contador por defecto de Flutter, que no existe en
// esta app).

import 'package:flutter_test/flutter_test.dart';

import 'package:meditrack_mobile/core/session/session_controller.dart';
import 'package:meditrack_mobile/main.dart';

void main() {
  testWidgets('Sin sesión guardada, arranca en Login', (WidgetTester tester) async {
    final sessionController = SessionController();
    await sessionController.restoreSession();

    await tester.pumpWidget(MediTrackApp(sessionController: sessionController));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsWidgets);
  });
}
