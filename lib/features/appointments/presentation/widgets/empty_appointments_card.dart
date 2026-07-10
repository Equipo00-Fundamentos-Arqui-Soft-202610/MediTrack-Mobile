import 'package:flutter/material.dart';

class EmptyAppointmentsCard extends StatelessWidget {
  const EmptyAppointmentsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.calendar_month_outlined,
            color: Color(0xFF00796B),
            size: 38,
          ),
          SizedBox(height: 12),
          Text(
            'No tienes citas médicas registradas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}
