import 'package:flutter/material.dart';
import 'package:meditrack_mobile/features/appointments/domain/models/appointment_model.dart';

class AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;
  final bool isHighlighted;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    final date = appointment.scheduledAt;
    final dayText = _formatDate(date);
    final timeText = _formatTime(date);
    final firstRequirement = appointment.requirements.isNotEmpty
        ? appointment.requirements.first.description
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFFE5F4FF) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: isHighlighted
            ? null
            : Border.all(color: const Color(0xFFD1D5DB), width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: Icon(
                  _getAppointmentIcon(appointment.type),
                  color: const Color(0xFF00796B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.type,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      appointment.location ?? 'Sin ubicación registrada',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: Color(0xFF00796B),
                size: 17,
              ),
              const SizedBox(width: 6),
              Text(
                dayText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 22),
              const Icon(Icons.access_time, color: Color(0xFF00796B), size: 17),
              const SizedBox(width: 6),
              Text(
                timeText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          if (firstRequirement != null) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFD1D5DB), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFFC85C32),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      firstRequirement,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getAppointmentIcon(String type) {
    final normalizedType = type.toLowerCase();

    if (normalizedType.contains('cardio')) {
      return Icons.favorite;
    }

    if (normalizedType.contains('oftalmo') ||
        normalizedType.contains('visión') ||
        normalizedType.contains('vision')) {
      return Icons.visibility;
    }

    if (normalizedType.contains('dental')) {
      return Icons.medical_services_outlined;
    }

    if (normalizedType.contains('laboratorio') ||
        normalizedType.contains('examen')) {
      return Icons.science_outlined;
    }

    return Icons.local_hospital;
  }

  String _formatDate(DateTime date) {
    const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];

    final dayName = days[date.weekday - 1];
    final monthName = months[date.month - 1];

    return '$dayName, ${date.day.toString().padLeft(2, '0')} $monthName';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }
}
