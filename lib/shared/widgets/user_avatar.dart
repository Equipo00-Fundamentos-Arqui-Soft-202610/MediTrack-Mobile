import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:meditrack_mobile/core/constants/app_constants.dart';
import 'package:meditrack_mobile/core/session/session_controller.dart';

/// Avatar único y consistente del usuario logueado — mismo widget en el
/// encabezado de Inicio, Medicinas, Progreso y Citas (donde toca navega a
/// Perfil), y también dentro de la propia pantalla de Perfil (con
/// [onTap] sobreescrito para abrir la edición de foto en vez de navegar).
///
/// Muestra la foto real vía `GET /identity/api/v1/profile/photo` (endpoint
/// autenticado: el token va en el header `Authorization`, nunca en la URL) o,
/// si no hay foto o falla la carga, la inicial del nombre — nunca una imagen
/// de prueba ni una URL fija.
class UserAvatar extends StatefulWidget {
  final double radius;
  final VoidCallback? onTap;

  const UserAvatar({super.key, this.radius = 18, this.onTap});

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  bool _imageFailed = false;
  String? _lastPhotoKey;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().current;
    final photoKey = user?.profilePhotoUrl;
    final hasPhoto = photoKey != null && photoKey.isNotEmpty;

    // Una foto nueva (subida/cambiada/eliminada) siempre limpia el error
    // previo: no debe quedar "pegado" el fallback tras un fallo pasado.
    if (photoKey != _lastPhotoKey) {
      _lastPhotoKey = photoKey;
      _imageFailed = false;
    }

    final initial = (user?.nombre.isNotEmpty == true ? user!.nombre[0] : '?')
        .toUpperCase();

    Widget content;
    if (hasPhoto && !_imageFailed) {
      content = ClipOval(
        child: Image.network(
          '${AppConstants.identityBaseUrl}/profile/photo?v=${Uri.encodeComponent(photoKey)}',
          key: ValueKey(photoKey),
          width: widget.radius * 2,
          height: widget.radius * 2,
          fit: BoxFit.cover,
          headers: {'Authorization': 'Bearer ${user!.token}'},
          errorBuilder: (context, error, stackTrace) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _imageFailed = true);
            });
            return _InitialLabel(radius: widget.radius, initial: initial);
          },
        ),
      );
    } else {
      content = _InitialLabel(radius: widget.radius, initial: initial);
    }

    return GestureDetector(
      onTap: widget.onTap ?? () => context.go('/profile'),
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: const Color(0xFFE1F3EE),
        child: content,
      ),
    );
  }
}

class _InitialLabel extends StatelessWidget {
  final double radius;
  final String initial;

  const _InitialLabel({required this.radius, required this.initial});

  @override
  Widget build(BuildContext context) {
    return Text(
      initial,
      style: TextStyle(
        color: const Color(0xFF07866D),
        fontWeight: FontWeight.bold,
        fontSize: radius * 0.85,
      ),
    );
  }
}
