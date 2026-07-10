import 'package:flutter/material.dart';
import 'package:meditrack_mobile/shared/widgets/user_avatar.dart';

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
        const UserAvatar(radius: 19),
      ],
    );
  }
}
