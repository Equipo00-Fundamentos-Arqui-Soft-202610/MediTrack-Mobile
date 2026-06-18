import 'package:flutter/material.dart';
import 'package:meditrack_mobile/features/appointments/data/services/appointment_service.dart';
import 'package:meditrack_mobile/features/appointments/domain/models/appointment_model.dart';
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

  static const int patientId = 1;

  late Future<List<AppointmentModel>> _appointmentsFuture;

  @override
  void initState() {
    super.initState();
    _appointmentsFuture = _loadAppointments();
  }

  Future<List<AppointmentModel>> _loadAppointments() {
    return _appointmentService.getAppointmentsByPatientId(patientId);
  }

  Future<void> _refreshAppointments() async {
    setState(() {
      _appointmentsFuture = _loadAppointments();
    });

    await _appointmentsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawerMenu(),
      backgroundColor: const Color(0xFFF3FAF7),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Función para agregar cita próximamente'),
            ),
          );
        },
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
                    return AppointmentsErrorCard(
                      message:
                          'No se pudieron cargar las citas.\n${snapshot.error}',
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
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
