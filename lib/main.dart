import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/network/api_client.dart';
import 'core/session/session_controller.dart';
import 'package:meditrack_mobile/core/notifications/local_notification_service.dart';
import 'package:meditrack_mobile/core/notifications/push_notification_service.dart';
import 'package:alarm/alarm.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) =>
    PushNotificationService.onBackgroundMessage(message);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  await Alarm.init();
  await LocalNotificationService.instance.initialize();
  await PushNotificationService.instance.initialize();

  final sessionController = SessionController();
  await sessionController.restoreSession();

  runApp(MediTrackApp(sessionController: sessionController));
}

class MediTrackApp extends StatefulWidget {
  final SessionController sessionController;

  const MediTrackApp({super.key, required this.sessionController});

  @override
  State<MediTrackApp> createState() => _MediTrackAppState();
}

class _MediTrackAppState extends State<MediTrackApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(widget.sessionController);

    // Un 401 real durante el uso de la app (token vencido/inválido) limpia
    // la sesión; el redirect de go_router (refreshListenable) lleva a Login.
    ApiClient.instance.onUnauthorized = () {
      widget.sessionController.logout();
    };
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.sessionController,
      child: MaterialApp.router(
        title: 'MediTrack',
        theme: AppTheme.theme,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
