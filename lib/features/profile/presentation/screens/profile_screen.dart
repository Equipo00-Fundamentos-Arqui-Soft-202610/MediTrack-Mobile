import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:meditrack_mobile/core/network/api_exception.dart';
import 'package:meditrack_mobile/core/session/session_controller.dart';
import 'package:meditrack_mobile/shared/widgets/app_drawer_menu.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  String? _errorMessage;

  late final TextEditingController _nombreController;
  late final TextEditingController _emailController;
  late final TextEditingController _institucionController;

  @override
  void initState() {
    super.initState();
    final user = context.read<SessionController>().current;
    _nombreController = TextEditingController(text: user?.nombre ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _institucionController = TextEditingController(text: user?.institucion ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _institucionController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await context.read<SessionController>().updateProfile(
            nombre: _nombreController.text.trim(),
            email: _emailController.text.trim(),
            institucion: _institucionController.text.trim().isEmpty
                ? null
                : _institucionController.text.trim(),
          );
      if (!mounted) return;
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente')),
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'No se pudo actualizar el perfil. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleLogout() async {
    final router = GoRouter.of(context);
    await context.read<SessionController>().logout();
    router.go('/login');
  }

  void _showUnavailableNotice(String feature, String todo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: Text(todo),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().current;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3FAF7),
      drawer: const AppDrawerMenu(),
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1F2937),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFFD9EAF6),
                  child: Text(
                    user.nombre.isNotEmpty ? user.nombre[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF27445C)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  user.rol,
                  style: const TextStyle(color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEAEA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFB3261E))),
                ),
                const SizedBox(height: 16),
              ],
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _nombreController,
                        enabled: _isEditing,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emailController,
                        enabled: _isEditing,
                        decoration: const InputDecoration(labelText: 'Correo electrónico'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _institucionController,
                        enabled: _isEditing,
                        decoration: const InputDecoration(labelText: 'Institución (opcional)'),
                      ),
                      if (_isEditing) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSaving
                                    ? null
                                    : () => setState(() {
                                          _isEditing = false;
                                          _errorMessage = null;
                                          _nombreController.text = user.nombre;
                                          _emailController.text = user.email;
                                          _institucionController.text = user.institucion ?? '';
                                        }),
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _handleSave,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF07866D),
                                  foregroundColor: Colors.white,
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Guardar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_reset_outlined, color: Colors.grey),
                      title: const Text('Cambiar contraseña'),
                      subtitle: const Text('No disponible aún'),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () => _showUnavailableNotice(
                        'Cambiar contraseña',
                        'Identity-Service todavía no expone un endpoint para cambiar contraseña.\n\n'
                            'TODO técnico: conectar a PUT/POST /identity/api/v1/auth/change-password '
                            'cuando exista en el backend.',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.phone_outlined, color: Colors.grey),
                      title: const Text('Teléfono'),
                      subtitle: const Text('No disponible aún'),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () => _showUnavailableNotice(
                        'Teléfono',
                        'El modelo de usuario de Identity-Service no tiene campo de teléfono todavía.\n\n'
                            'TODO técnico: agregar el campo en ProfileUpdateRequest/User cuando el '
                            'backend lo soporte.',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.photo_camera_outlined, color: Colors.grey),
                      title: const Text('Foto de perfil'),
                      subtitle: const Text('No disponible aún'),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () => _showUnavailableNotice(
                        'Foto de perfil',
                        'El modelo de usuario de Identity-Service no tiene campo de foto todavía.\n\n'
                            'TODO técnico: agregar el campo (y almacenamiento de imagen) cuando el '
                            'backend lo soporte.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
