import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:meditrack_mobile/core/session/session_controller.dart';

class AppDrawerMenu extends StatelessWidget {
  const AppDrawerMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.current;

    return Drawer(
      backgroundColor: const Color(0xFFF6FAF8),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFD9EAF6),
                    child: Text(
                      (user?.nombre.isNotEmpty == true ? user!.nombre[0] : '?').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF27445C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.nombre ?? 'Invitado',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(user?.rol ?? ''),
                    ],
                  ),
                ],
              ),
            ),

            _DrawerItem(
              icon: Icons.home_outlined,
              title: 'Inicio',
              routeName: '/',
            ),
            _DrawerItem(
              icon: Icons.medication_outlined,
              title: 'Mis Medicinas',
              routeName: '/medications',
            ),
            _DrawerItem(
              icon: Icons.analytics_outlined,
              title: 'Mi Progreso',
              routeName: '/adherence',
            ),
            _DrawerItem(
              icon: Icons.calendar_month_outlined,
              title: 'Citas Médicas',
              routeName: '/appointments',
            ),
            _DrawerItem(
              icon: Icons.person_outline,
              title: 'Perfil',
              routeName: '/profile',
            ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.all(24),
              child: OutlinedButton.icon(
                onPressed: () async {
                  final router = GoRouter.of(context);
                  await context.read<SessionController>().logout();
                  router.go('/login');
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String routeName;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.routeName,
  });

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final isSelected = currentRoute == routeName;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFD9EAF6) : Colors.transparent,
        borderRadius: BorderRadius.circular(28),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF27445C)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        onTap: () {
          Navigator.pop(context);

          if (!isSelected) {
            context.go(routeName);
          }
        },
      ),
    );
  }
}
