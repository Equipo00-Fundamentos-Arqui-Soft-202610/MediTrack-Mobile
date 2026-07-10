import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditrack_mobile/core/network/api_exception.dart';
import 'package:meditrack_mobile/core/alarms/medication_alarm_service.dart';
import 'package:meditrack_mobile/core/session/session_controller.dart';
import 'package:meditrack_mobile/features/home/data/models/next_dose_model.dart';
import 'package:meditrack_mobile/features/home/data/services/home_service.dart';
import 'package:meditrack_mobile/features/medications/data/services/medication_service.dart';
import 'package:meditrack_mobile/features/reminders/application/services/medication_alarm_scheduler.dart';
import 'package:meditrack_mobile/shared/widgets/app_drawer_menu.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeService _homeService = HomeService();
  final MedicationService _medicationService = MedicationService();

  late final MedicationAlarmScheduler _alarmScheduler =
      MedicationAlarmScheduler(alarmService: MedicationAlarmService.instance);

  NextDoseModel? nextDose;
  double adherencePercentage = 0;
  List<dynamic> lowStockMedications = [];

  bool isLoading = true;
  bool isTakingDose = false;

  String? nextDoseError;
  String? adherenceError;
  String? stockError;

  @override
  void initState() {
    super.initState();
    final patientId = context.read<SessionController>().patientId;
    if (patientId != null) {
      loadHomeData(patientId);
    } else {
      setState(() => isLoading = false);
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

    try {
      loadedDose = await _homeService.getNextDose(patientId);
    } on ApiException catch (error) {
      nextDoseError = error.message;
    } catch (error) {
      nextDoseError = 'No se pudo cargar la próxima dosis.';
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
      final medications = await _medicationService.getMedicationsByPatientId(
        patientId,
      );
      await _alarmScheduler.scheduleMedicationAlarms(medications);
    } catch (error) {
      debugPrint('Medication alarms error: $error');
    }

    if (!mounted) return;
    setState(() {
      nextDose = loadedDose;
      adherencePercentage = loadedAdherence;
      lowStockMedications = loadedLowStock;
      isLoading = false;
    });
  }

  Future<void> handleTakeDose() async {
    if (nextDose == null) return;
    final patientId = context.read<SessionController>().patientId;
    if (patientId == null) return;

    setState(() => isTakingDose = true);

    try {
      await _homeService.takeDose(
        patientId: patientId,
        doseScheduleId: nextDose!.doseScheduleId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dosis registrada correctamente')),
      );

      await loadHomeData(patientId);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error registrando la dosis')),
      );
    } finally {
      if (mounted) setState(() => isTakingDose = false);
    }
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
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFE1F3EE),
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                style: const TextStyle(color: Color(0xFF07866D), fontWeight: FontWeight.bold),
              ),
            ),
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
            child: const Icon(
              Icons.access_time_filled,
              color: Color(0xFF07866D),
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          if (nextDoseError != null) ...[
            Text(
              nextDoseError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13),
            ),
          ] else ...[
            Text(
              nextDose?.medicationName ?? 'Sin dosis pendiente',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              nextDose == null
                  ? 'No tienes próxima dosis registrada'
                  : 'Próxima dosis: ${nextDose!.scheduledTime}',
              style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: nextDose == null || isTakingDose
                  ? null
                  : handleTakeDose,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF07866D),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(
                isTakingDose ? 'Registrando...' : 'Tomar dosis',
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
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF07866D)),
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
                      const Icon(Icons.warning, color: Color(0xFFE11D48), size: 18),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  hasLowStock
                      ? 'Stock bajo:\n${medication['officialName'] ?? medication['name']}'
                      : 'Stock\nsuficiente',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
    );
  }
}
