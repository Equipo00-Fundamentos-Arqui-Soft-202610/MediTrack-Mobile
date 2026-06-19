import 'package:flutter/material.dart';

class AppointmentsHeader extends StatelessWidget {
  const AppointmentsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Builder(
          builder: (context) => IconButton(
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
            icon: const Icon(Icons.menu, color: Color(0xFF4B5563), size: 24),
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'MediTrack',
          style: TextStyle(
            color: Color(0xFF00796B),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        CircleAvatar(
          radius: 19,
          backgroundColor: const Color(0xFFE5EAE7),
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {},
            icon: const Icon(
              Icons.person_outline,
              size: 21,
              color: Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }
}
