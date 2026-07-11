import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditrack_mobile/core/network/api_exception.dart';
import 'package:meditrack_mobile/core/session/session_controller.dart';
import 'package:meditrack_mobile/features/appointments/data/services/appointment_service.dart';
import 'package:meditrack_mobile/features/appointments/domain/models/appointment_model.dart';
import 'package:meditrack_mobile/features/appointments/domain/models/clinical_exam_model.dart';
import 'package:meditrack_mobile/features/appointments/presentation/screens/create_appointment_screen.dart';
import 'package:meditrack_mobile/features/appointments/presentation/widgets/appointment_card.dart';
import 'package:meditrack_mobile/features/appointments/presentation/widgets/appointments_error_card.dart';
import 'package:meditrack_mobile/features/appointments/presentation/widgets/appointments_header.dart';
import 'package:meditrack_mobile/features/appointments/presentation/widgets/empty_appointments_card.dart';
import 'package:meditrack_mobile/shared/widgets/app_drawer_menu.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final AppointmentService _appointmentService = AppointmentService();

  late Future<List<AppointmentModel>> _appointmentsFuture;
  List<ClinicalExamModel> _pendingExams = [];
  String? _examsError;

  @override
  void initState() {
    super.initState();
    _appointmentsFuture = _loadAppointments();
    _loadPendingExams();
  }

  int? get _patientId => context.read<SessionController>().patientId;

  Future<List<AppointmentModel>> _loadAppointments() {
    final patientId = _patientId;
    if (patientId == null) {
      return Future.error(
        ApiException(null, 'No se pudo determinar tu perfil de paciente.'),
      );
    }
    return _appointmentService.getAppointmentsByPatientId(patientId);
  }

  Future<void> _loadPendingExams() async {
    final patientId = _patientId;
    if (patientId == null) return;

    try {
      final exams = await _appointmentService.getPendingClinicalExams(
        patientId,
      );
      if (!mounted) return;
      setState(() {
        _pendingExams = exams;
        _examsError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _examsError = e.message);
    } catch (_) {
      // No bloquea la pantalla de citas: sección secundaria.
    }
  }

  Future<void> _refreshAppointments() async {
    setState(() {
      _appointmentsFuture = _loadAppointments();
    });

    await _appointmentsFuture;
    await _loadPendingExams();
  }

  Future<void> _openCreateAppointment({AppointmentModel? existing}) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateAppointmentScreen(existing: existing),
      ),
    );
    if (created == true) {
      _refreshAppointments();
    }
  }

  Future<void> _handleCancel(AppointmentModel appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: Text(
          '¿Seguro que quieres cancelar la cita de ${appointment.type}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Sí, cancelar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _appointmentService.cancelAppointment(appointment.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cita cancelada correctamente')),
      );
      _refreshAppointments();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cancelar la cita.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawerMenu(),
      backgroundColor: const Color(0xFFF3FAF7),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreateAppointment(),
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.add, size: 30),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAppointments,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 90),
            children: [
              const AppointmentsHeader(),
              const SizedBox(height: 24),
              const Text(
                'Próximas Citas',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tus compromisos médicos agendados.',
                style: TextStyle(fontSize: 14, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 22),
              FutureBuilder<List<AppointmentModel>>(
                future: _appointmentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00796B),
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    final message = error is ApiException
                        ? error.message
                        : 'No se pudieron cargar las citas.';
                    return AppointmentsErrorCard(
                      message: message,
                      onRetry: _refreshAppointments,
                    );
                  }

                  final appointments = snapshot.data ?? [];

                  if (appointments.isEmpty) {
                    return const EmptyAppointmentsCard();
                  }

                  return Column(
                    children: appointments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final appointment = entry.value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppointmentCard(
                          appointment: appointment,
                          isHighlighted: index == 0,
                          onEdit: appointment.canBeModified
                              ? () => _openCreateAppointment(
                                  existing: appointment,
                                )
                              : null,
                          onCancel: appointment.canBeModified
                              ? () => _handleCancel(appointment)
                              : null,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 28),
              _buildPendingExamsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingExamsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Exámenes Pendientes',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Exámenes clínicos por realizar o recoger.',
          style: TextStyle(fontSize: 14, color: Color(0xFF374151)),
        ),
        const SizedBox(height: 16),
        if (_examsError != null)
          AppointmentsErrorCard(
            message: _examsError!,
            onRetry: _loadPendingExams,
          )
        else if (_pendingExams.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD1D5DB)),
            ),
            child: const Text(
              'No tienes exámenes clínicos pendientes.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF374151)),
            ),
          )
        else
          ..._pendingExams.map(
            (exam) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined, color: Color(0xFF00796B)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exam.examType,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          exam.scheduledDate != null
                              ? 'Programado: ${exam.scheduledDate!.day}/${exam.scheduledDate!.month}/${exam.scheduledDate!.year}'
                              : 'Sin fecha programada',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
