import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/home/data/models/next_dose_model.dart';
import '../../features/home/presentation/screens/dose_evidence_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/medications/presentation/screens/medications_screen.dart';
import '../../features/adherence/presentation/screens/adherence_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/appointments/presentation/screens/appointments_screen.dart';
import '../session/session_controller.dart';

const _publicRoutes = {'/login', '/register'};

/// Construye el router con `redirect` atado a [session] (vía
/// `refreshListenable`): sin sesión válida siempre termina en `/login`; con
/// sesión, `/login` y `/register` redirigen a Home.
GoRouter buildRouter(SessionController session) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: session,
    redirect: (context, state) {
      if (session.isRestoring) return null;

      final goingToPublicRoute = _publicRoutes.contains(state.matchedLocation);

      if (!session.isAuthenticated && !goingToPublicRoute) return '/login';
      if (session.isAuthenticated && goingToPublicRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      // Pantalla completa (sin bottom nav): captura/envío de evidencia en video.
      GoRoute(
        path: '/dose-evidence',
        builder: (c, s) => DoseEvidenceScreen(dose: s.extra as NextDoseModel),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
          GoRoute(
            path: '/medications',
            builder: (c, s) => const MedicationsScreen(),
          ),
          GoRoute(
            path: '/adherence',
            builder: (c, s) => const AdherenceScreen(),
          ),
          GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
          GoRoute(
            path: '/appointments',
            builder: (c, s) => const AppointmentsScreen(),
          ),
        ],
      ),
    ],
  );
}

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<String> _routes = ['/', '/medications', '/adherence', '/profile'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
          context.go(_routes[i]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication),
            label: 'Medicinas',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Progreso',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
