import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditrack_mobile/core/network/api_exception.dart';
import 'package:meditrack_mobile/core/session/session_controller.dart';
import 'package:meditrack_mobile/features/medications/data/services/medication_service.dart';
import 'package:meditrack_mobile/features/medications/domain/models/medication_model.dart';
import 'package:meditrack_mobile/shared/widgets/app_drawer_menu.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  final MedicationService _medicationService = MedicationService();

  late Future<List<MedicationModel>> _medicationsFuture;

  @override
  void initState() {
    super.initState();

    final patientId = context.read<SessionController>().patientId;
    _medicationsFuture = patientId == null
        ? Future.error(ApiException(null, 'No se pudo determinar tu perfil de paciente.'))
        : _medicationService.getMedicationsByPatientId(patientId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawerMenu(),
      backgroundColor: const Color(0xFFF7FBF9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FBF9),
        elevation: 0,
        centerTitle: false,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF087D68)),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: const Text(
          'MediTrack',
          style: TextStyle(
            color: Color(0xFF087D68),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=47'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
          child: FutureBuilder<List<MedicationModel>>(
            future: _medicationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF087D68)),
                );
              }

              if (snapshot.hasError) {
                final error = snapshot.error;
                final message = error is ApiException
                    ? error.message
                    : 'No se pudieron cargar los medicamentos.';
                return Center(
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                      fontSize: 14,
                    ),
                  ),
                );
              }

              final medications = snapshot.data ?? [];

              if (medications.isEmpty) {
                return ListView(
                  children: const [
                    _MedicationsHeader(),
                    SizedBox(height: 40),
                    Center(
                      child: Text(
                        'No tienes medicamentos registrados.',
                        style: TextStyle(
                          color: Color(0xFF5F6C72),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                itemCount: medications.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  if (index == 0) return const _MedicationsHeader();

                  final medication = medications[index - 1];
                  final isLowStock =
                      medication.stockCount <= medication.stockAlertThreshold;

                  return _MedicationCard(
                    name: medication.officialName,
                    description:
                        '${medication.dose} • ${medication.category ?? 'Medication'}',
                    frequency: _formatFrequency(medication.frequencyHours),
                    nextDose: _getNextDose(medication.scheduledTimes),
                    isActive: true,
                    isLowStock: isLowStock,
                    stockMessage:
                        'Stock bajo: Solo quedan ${medication.stockCount}',
                    icon: Icons.medical_services,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatFrequency(int frequencyHours) {
    if (frequencyHours <= 0) return 'Sin frecuencia';

    final dosesPerDay = 24 ~/ frequencyHours;

    if (dosesPerDay <= 1) return 'Uno al día';

    return '$dosesPerDay al día';
  }

  String _getNextDose(List<String> scheduledTimes) {
    if (scheduledTimes.isEmpty) return 'Sin horario';

    return scheduledTimes.first;
  }
}

class _MedicationsHeader extends StatelessWidget {
  const _MedicationsHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Medicamentos',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2933),
          ),
        ),
        const SizedBox(height: 6),
        // La app mobile es solo para pacientes: los medicamentos/recetas los
        // registra el personal médico (Treatment-Service), no hay flujo de
        // creación desde aquí.
        Row(
          children: [
            const Icon(Icons.info_outline, size: 15, color: Color(0xFF5F6C72)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Los medicamentos son registrados por el personal médico.',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF5F6C72)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MedicationCard extends StatelessWidget {
  final String name;
  final String description;
  final String frequency;
  final String nextDose;
  final bool isActive;
  final bool isLowStock;
  final String? stockMessage;
  final IconData icon;

  const _MedicationCard({
    required this.name,
    required this.description,
    required this.frequency,
    required this.nextDose,
    required this.isActive,
    required this.isLowStock,
    required this.icon,
    this.stockMessage,
  });

  @override
  Widget build(BuildContext context) {
    final Color cardColor = isLowStock ? const Color(0xFFFFE8EE) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E6E3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE5F3F1),
                child: Icon(icon, color: const Color(0xFF087D68), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5F6C72),
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4EA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.circle, size: 7, color: Color(0xFF2E7D32)),
                      SizedBox(width: 5),
                      Text(
                        'Activo',
                        style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (isLowStock) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Alerta de stock bajo\n',
                      style: TextStyle(
                        color: Color(0xFFB42318),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: stockMessage ?? '',
                      style: const TextStyle(
                        color: Color(0xFF1F2933),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE7ECEA)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _InfoItem(label: 'Frecuencia', value: frequency),
                ),
                Expanded(
                  child: _InfoItem(label: 'Próxima dosis', value: nextDose),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF5F6C72)),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2933),
          ),
        ),
      ],
    );
  }
}
