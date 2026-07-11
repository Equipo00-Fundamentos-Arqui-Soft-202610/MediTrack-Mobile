// Smoke test: sin sesión guardada, la app debe arrancar en la pantalla de
// Login (antes probaba el contador por defecto de Flutter, que no existe en
// esta app).

import 'package:flutter_test/flutter_test.dart';

import 'package:meditrack_mobile/core/session/session_controller.dart';
import 'package:meditrack_mobile/core/session/session_storage.dart';
import 'package:meditrack_mobile/main.dart';

/// `flutter_secure_storage` usa un MethodChannel real: en `flutter test` (sin
/// plataforma) esa llamada nunca resuelve y cuelga el test. Se evita tocando
/// el plugin real — el objetivo del smoke test es la navegación, no el storage.
class _NoopSessionStorage extends SessionStorage {
  @override
  Future<String?> readToken() async => null;

  @override
  Future<Map<String, dynamic>?> readUser() async => null;
}

void main() {
  testWidgets('Sin sesión guardada, arranca en Login', (
    WidgetTester tester,
  ) async {
    final sessionController = SessionController(storage: _NoopSessionStorage());
    await sessionController.restoreSession();

    await tester.pumpWidget(MediTrackApp(sessionController: sessionController));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsWidgets);
  });
}
