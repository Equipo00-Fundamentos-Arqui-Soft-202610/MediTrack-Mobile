import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:meditrack_mobile/core/network/api_exception.dart';
import 'package:meditrack_mobile/core/constants/app_constants.dart';
import 'package:meditrack_mobile/core/session/session_controller.dart';
import 'package:meditrack_mobile/features/home/data/models/next_dose_model.dart';
import 'package:meditrack_mobile/features/home/data/services/home_service.dart';
import 'package:meditrack_mobile/features/home/domain/dose_visual_state.dart';
import 'package:meditrack_mobile/features/reminders/application/services/dose_reminder_coordinator.dart';
import 'package:meditrack_mobile/features/reminders/data/pending_dose_action_store.dart';
import 'package:meditrack_mobile/shared/widgets/app_drawer_menu.dart';
import 'package:meditrack_mobile/shared/widgets/user_avatar.dart';

class HomeScreen extends StatefulWidget {
  /// Inyectables solo para tests (widget tests con fakes); en producción
  /// siempre se usan las instancias reales por defecto.
  final HomeService? homeService;
  final DoseReminderCoordinator? reminderCoordinator;

  const HomeScreen({super.key, this.homeService, this.reminderCoordinator});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final HomeService _homeService = widget.homeService ?? HomeService();
  late final DoseReminderCoordinator _reminderCoordinator =
      widget.reminderCoordinator ?? DoseReminderCoordinator.instance;

  NextDoseModel? nextDose;
  double adherencePercentage = 0;
  List<dynamic> lowStockMedications = [];

  bool isLoading = true;

  String? nextDoseError;
  String? adherenceError;
  String? stockError;

  /// Reprograma la reconstrucción visual exacta al llegar al horario de la
  /// dosis (o al fin de la ventana de toma), sin esperar a que el usuario
  /// cambie de pantalla o refresque manualmente.
  Timer? _doseWindowTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reminderCoordinator.addListener(_onReminderCoordinatorChanged);
    final patientId = context.read<SessionController>().patientId;
    if (patientId != null) {
      loadHomeData(patientId);
    } else {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminderCoordinator.removeListener(_onReminderCoordinatorChanged);
    _doseWindowTimer?.cancel();
    super.dispose();
  }

  /// Se dispara cuando el coordinador cierra un ciclo como "no tomada":
  /// redibuja para mostrar ese estado en la tarjeta.
  void _onReminderCoordinatorChanged() {
    if (!mounted) return;
    setState(() {});
  }

  /// Si el paciente tocó la acción explícita "Tomar dosis" de la
  /// notificación (foreground, background o app terminada — ver
  /// `LocalNotificationService`/`PendingDoseActionStore`), abre
  /// automáticamente la evidencia de esa dosis exacta al cargar Home.
  Future<void> _openPendingEvidenceRequestIfAny(NextDoseModel? dose) async {
    if (dose == null) return;
    final matched = await PendingDoseActionStore.consumeIfMatches(
      dose.doseScheduleId,
      dose.scheduledAtUtc,
    );
    if (matched && mounted) {
      await _openDoseEvidence();
    }
  }

  /// Al volver de background (resume), se vuelve a consultar next-dose — sin
  /// esto, una app dejada abierta en segundo plano durante la hora de la
  /// dosis no se enteraría hasta que el usuario interactúe de nuevo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final patientId = context.read<SessionController>().patientId;
      if (patientId != null) {
        debugPrint('Home: resume desde background, recargando next-dose.');
        loadHomeData(patientId);
      }
    }
  }

  Future<void> loadHomeData(int patientId) async {
    setState(() {
      isLoading = true;
      nextDoseError = null;
      adherenceError = null;
      stockError = null;
    });

    NextDoseModel? loadedDose;
    double loadedAdherence = 0;
    List<dynamic> loadedLowStock = [];

    debugPrint('Home.loadHomeData -> patientId=$patientId');

    try {
      loadedDose = await _homeService.getNextDose(patientId);
      if (loadedDose != null) {
        final d = loadedDose;
        debugPrint(
          'Home next-dose response -> doseScheduleId=${d.doseScheduleId} '
          'medicationName=${d.medicationName} dose=${d.dose} '
          'scheduledTime=${d.scheduledTime} scheduledAtUtc=${d.scheduledAtUtc.toIso8601String()} '
          'scheduledAtLocal=${d.scheduledAtUtc.toLocal().toIso8601String()} '
          'minutesUntilDose=${d.minutesUntilDose} complianceId=${d.complianceId} '
          'validationStatus=${d.validationStatus} rejectionReason=${d.rejectionReason}',
        );
      } else {
        debugPrint(
          'Home next-dose response -> null (404: sin próxima dosis para hoy)',
        );
      }
    } on ApiException catch (error) {
      nextDoseError = error.message;
      debugPrint(
        'Home next-dose ApiException -> status=${error.statusCode} message=${error.message}',
      );
    } catch (error) {
      nextDoseError = 'No se pudo cargar la próxima dosis.';
      debugPrint('Home next-dose error inesperado -> $error');
    }

    try {
      loadedAdherence = await _homeService.getAdherencePercentage(patientId);
    } on ApiException catch (error) {
      adherenceError = error.message;
    } catch (error) {
      adherenceError = 'No se pudo cargar el progreso.';
    }

    try {
      loadedLowStock = await _homeService.getLowStockMedications(patientId);
    } on ApiException catch (error) {
      stockError = error.message;
    } catch (error) {
      stockError = 'No se pudo cargar el stock.';
    }

    try {
      await _reminderCoordinator.ensureCycleForNextDose(
        patientId: patientId,
        nextDose: loadedDose,
      );
    } catch (error) {
      debugPrint('DoseReminderCoordinator error: $error');
    }

    if (!mounted) return;
    setState(() {
      nextDose = loadedDose;
      adherencePercentage = loadedAdherence;
      lowStockMedications = loadedLowStock;
      isLoading = false;
    });

    _scheduleDoseWindowTimer();
    await _openPendingEvidenceRequestIfAny(loadedDose);
  }

  /// Programa (a lo sumo un) timer para el próximo instante en que cambia el
  /// estado visual de la dosis (inicio de ventana o fin de ventana), y se
  /// reprograma en cadena tras cada disparo mientras siga aplicando. Cancela
  /// siempre cualquier timer anterior primero — nunca deja timers duplicados.
  void _scheduleDoseWindowTimer() {
    _doseWindowTimer?.cancel();
    _doseWindowTimer = null;

    final dose = nextDose;
    // Con evidencia pendiente/rechazada no hay una transición de horario que
    // esperar aquí (esos estados se resuelven por el flujo de video / retry).
    if (dose == null || dose.validationStatus != null) return;

    final now = DateTime.now().toUtc();
    DateTime? nextBoundary;

    if (now.isBefore(dose.scheduledAtUtc)) {
      nextBoundary = dose.scheduledAtUtc;
    } else {
      final windowEnd = dose.scheduledAtUtc.add(
        const Duration(minutes: AppConstants.doseReminderCloseOffsetMinutes),
      );
      if (now.isBefore(windowEnd)) nextBoundary = windowEnd;
    }

    if (nextBoundary == null) return;

    final delay = nextBoundary.difference(now) + const Duration(seconds: 1);
    debugPrint(
      'Home: próxima transición de estado de dosis en ${delay.inSeconds}s (${nextBoundary.toIso8601String()})',
    );

    _doseWindowTimer = Timer(delay, () {
      if (!mounted) return;
      debugPrint(
        'Home: timer de ventana disparado, recomputando estado visual.',
      );
      setState(() {}); // recalcula computeDoseState() dentro de build()
      _scheduleDoseWindowTimer(); // encadena el siguiente límite si aplica
    });
  }

  /// Abre la pantalla de captura/envío de evidencia en video. Al volver, si
  /// hubo algún cambio (video enviado, aprobado, rechazado), se recarga Home.
  ///
  /// Solo abre la pantalla — no cancela avisos ni marca nada. Los avisos
  /// restantes del ciclo siguen programados hasta que el video se envíe con
  /// éxito (o el backend confirme otro estado resolutivo).
  Future<void> _openDoseEvidence() async {
    final dose = nextDose;
    final patientId = context.read<SessionController>().patientId;
    if (dose == null || patientId == null) return;

    final changed = await context.push<bool>('/dose-evidence', extra: dose);

    if (changed == true && mounted) {
      await loadHomeData(patientId);
    }
  }

  void _dismissMissedDoseCard(int patientId) {
    _reminderCoordinator.clearLastMissedDose();
    loadHomeData(patientId);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final patientId = session.patientId;
    final userName = session.current?.nombre.split(' ').first ?? '';

    return Scaffold(
      drawer: const AppDrawerMenu(),
      backgroundColor: const Color(0xFFF3FAF7),
      body: SafeArea(
        child: patientId == null
            ? _buildNoPatientState()
            : RefreshIndicator(
                onRefresh: () => loadHomeData(patientId),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                  children: [
                    _buildHeader(userName),
                    const SizedBox(height: 24),
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      _buildNextDoseCard(),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildAdherenceCard()),
                          const SizedBox(width: 14),
                          Expanded(child: _buildStockCard()),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildNoPatientState() {
    // TODO(backend): Identity-Service no vincula todavía un patientId real al
    // usuario logueado (ver SessionController._resolvePatientId). Esto solo
    // debería verse si ni el claim del JWT ni el id de usuario resolvieron.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No se pudo determinar tu perfil de paciente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Contacta a soporte o intenta cerrar sesión y volver a ingresar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF4B5563)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String userName) {
    return Column(
      children: [
        Row(
          children: [
            Builder(
              builder: (context) => IconButton(
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
                icon: const Icon(
                  Icons.menu,
                  color: Color(0xFF0F8B6E),
                  size: 24,
                ),
              ),
            ),
            const Spacer(),
            const Text(
              'MediTrack',
              style: TextStyle(
                color: Color(0xFF00856F),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            const UserAvatar(),
          ],
        ),
        const SizedBox(height: 26),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            userName.isEmpty ? 'Bienvenido' : 'Bienvenido, $userName',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Aquí tienes tu horario para hoy.',
            style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
          ),
        ),
      ],
    );
  }

  Widget _buildNextDoseCard() {
    final dose = nextDose;
    final missedDose = _reminderCoordinator.lastMissedDose;
    final cardState = computeDoseState(
      dose,
      DateTime.now().toUtc(),
      locallyMissedDose: missedDose,
    );

    String title;
    String subtitle;
    String buttonLabel;
    VoidCallback? onPressed;
    var isErrorState = false;

    if (nextDoseError != null) {
      // Distinto del caso "no hay dosis": esto es un fallo real (red, 500,
      // error de parseo, etc.), no debe verse igual a "sin dosis pendiente".
      isErrorState = true;
      title = 'No se pudo cargar tu dosis';
      subtitle = nextDoseError!;
      buttonLabel = 'Reintentar';
      onPressed = () =>
          loadHomeData(context.read<SessionController>().patientId!);
    } else if (cardState.state == DoseVisualState.notTaken) {
      // El backend ya no reporta esta ocurrencia (quedó correctamente
      // excluida de next-dose al registrarse como "skipped"): se muestra con
      // los datos que el coordinador confirmó localmente, una sola vez.
      title = missedDose?.medicationName ?? 'Dosis no tomada';
      subtitle =
          'No se registró ninguna acción a tiempo. Se marcó como no tomada.';
      buttonLabel = 'Ver próxima dosis';
      onPressed = () =>
          _dismissMissedDoseCard(context.read<SessionController>().patientId!);
    } else if (dose == null) {
      title = 'Sin dosis pendiente';
      subtitle = 'No tienes próxima dosis registrada';
      buttonLabel = 'Tomar dosis';
      onPressed = null;
    } else {
      switch (cardState.state) {
        case DoseVisualState.notTaken:
          // Cubierto arriba: nunca se llega aquí con `dose` no nulo y
          // `cardState.state == notTaken` porque ese caso ya retornó antes.
          title = dose.medicationName;
          subtitle = 'Dosis no tomada';
          buttonLabel = 'Ver próxima dosis';
          onPressed = null;
        case DoseVisualState.beforeWindow:
          title = dose.medicationName;
          subtitle = 'Próxima dosis: ${dose.scheduledTime}';
          buttonLabel = 'Tomar dosis';
          onPressed = null;
        case DoseVisualState.readyToTake:
          title = dose.medicationName;
          subtitle = 'Es hora de tu dosis (${dose.scheduledTime})';
          buttonLabel = 'Tomar dosis';
          onPressed = _openDoseEvidence;
        case DoseVisualState.pendingValidation:
          title = dose.medicationName;
          subtitle = 'Evidencia en validación';
          buttonLabel = 'En validación...';
          onPressed = null;
        case DoseVisualState.rejected:
          title = dose.medicationName;
          subtitle = dose.rejectionReason?.isNotEmpty == true
              ? 'Evidencia rechazada: ${dose.rejectionReason}'
              : 'Evidencia rechazada';
          buttonLabel = cardState.canRetry
              ? 'Volver a intentar'
              : 'Ventana finalizada';
          onPressed = cardState.canRetry ? _openDoseEvidence : null;
        case DoseVisualState.windowExpired:
          title = dose.medicationName;
          subtitle = 'La ventana de toma finalizó';
          buttonLabel = 'Tomar dosis';
          onPressed = null;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F4FF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isErrorState
                  ? Icons.error_outline
                  : cardState.state == DoseVisualState.pendingValidation
                  ? Icons.hourglass_top
                  : cardState.state == DoseVisualState.rejected
                  ? Icons.cancel_outlined
                  : cardState.state == DoseVisualState.notTaken
                  ? Icons.event_busy
                  : Icons.access_time_filled,
              color: const Color(0xFF07866D),
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isErrorState
                  ? const Color(0xFFB3261E)
                  : const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF07866D),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.restaurant, size: 15, color: Color(0xFF4B5563)),
              SizedBox(width: 6),
              Text(
                'Con alimentos',
                style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdherenceCard() {
    final percentage = adherencePercentage <= 0 ? 0 : adherencePercentage;
    final progress = percentage / 100;

    return Container(
      height: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: adherenceError != null
          ? Center(
              child: Text(
                adherenceError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12),
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 78,
                  height: 78,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress.clamp(0, 1),
                        strokeWidth: 9,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF07866D),
                        ),
                      ),
                      Center(
                        child: Text(
                          '${percentage.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFF07866D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Progreso del\ntratamiento',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
    );
  }

  Widget _buildStockCard() {
    final hasLowStock = lowStockMedications.isNotEmpty;
    final medication = hasLowStock ? lowStockMedications.first : null;

    return Container(
      height: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEAF0),
        borderRadius: BorderRadius.circular(22),
      ),
      child: stockError != null
          ? Center(
              child: Text(
                stockError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12),
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.medical_services,
                        color: Color(0xFFB55A42),
                      ),
                    ),
                    if (hasLowStock)
                      const Icon(
                        Icons.warning,
                        color: Color(0xFFE11D48),
                        size: 18,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  hasLowStock
                      ? 'Stock bajo:\n${medication['officialName'] ?? medication['name']}'
                      : 'Stock\nsuficiente',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    );
  }
}
