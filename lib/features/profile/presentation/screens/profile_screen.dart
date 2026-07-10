import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:meditrack_mobile/core/network/api_exception.dart';
import 'package:meditrack_mobile/core/session/session_controller.dart';
import 'package:meditrack_mobile/features/profile/presentation/screens/change_password_screen.dart';
import 'package:meditrack_mobile/shared/widgets/app_drawer_menu.dart';
import 'package:meditrack_mobile/shared/widgets/user_avatar.dart';

const int _maxPhotoSizeBytes = 5 * 1024 * 1024;
const Set<String> _allowedPhotoExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

enum _PhotoAction { camera, gallery, delete }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUpdatingPhoto = false;
  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _nombreController;
  late final TextEditingController _emailController;
  late final TextEditingController _institucionController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final user = context.read<SessionController>().current;
    _nombreController = TextEditingController(text: user?.nombre ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _institucionController = TextEditingController(text: user?.institucion ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _institucionController.dispose();
    _phoneController.dispose();
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
            phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
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

  Future<void> _openPhotoOptions() async {
    if (_isUpdatingPhoto) return;

    final hasPhoto = context.read<SessionController>().current?.profilePhotoUrl?.isNotEmpty == true;

    final choice = await showModalBottomSheet<_PhotoAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: Color(0xFF07866D)),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(sheetContext).pop(_PhotoAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF07866D)),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.of(sheetContext).pop(_PhotoAction.gallery),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Eliminar foto', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.of(sheetContext).pop(_PhotoAction.delete),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    switch (choice) {
      case _PhotoAction.camera:
        await _pickAndUploadPhoto(ImageSource.camera);
        break;
      case _PhotoAction.gallery:
        await _pickAndUploadPhoto(ImageSource.gallery);
        break;
      case _PhotoAction.delete:
        await _confirmAndDeletePhoto();
        break;
    }
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    // `maxWidth` + `imageQuality` le piden a image_picker que ya entregue la
    // imagen redimensionada/comprimida — sin agregar otra librería de imágenes.
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1080,
    );
    if (picked == null || !mounted) return;

    final lowerPath = picked.path.toLowerCase();
    final dotIndex = lowerPath.lastIndexOf('.');
    final extension = dotIndex == -1 ? '' : lowerPath.substring(dotIndex);
    if (!_allowedPhotoExtensions.contains(extension)) {
      _showSnack('Formato no soportado. Usa JPG, PNG o WEBP.');
      return;
    }

    final file = File(picked.path);
    final sizeBytes = await file.length();
    if (sizeBytes > _maxPhotoSizeBytes) {
      _showSnack('La imagen no debe superar 5MB.');
      return;
    }

    final confirmed = await _showPreviewDialog(file);
    if (confirmed != true || !mounted) return;

    setState(() {
      _isUpdatingPhoto = true;
      _errorMessage = null;
    });

    try {
      await context.read<SessionController>().uploadProfilePhoto(file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada')),
      );
    } on ApiException catch (e) {
      // La sesión/foto anterior se conserva: SessionController solo aplica
      // el cambio si el backend confirma éxito.
      if (!mounted) return;
      _showSnack(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnack('No se pudo subir la foto. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isUpdatingPhoto = false);
    }
  }

  Future<bool?> _showPreviewDialog(File file) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar foto'),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(file, height: 220, fit: BoxFit.cover),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF07866D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Usar esta foto'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDeletePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text('¿Seguro que quieres eliminar tu foto de perfil?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isUpdatingPhoto = true;
      _errorMessage = null;
    });

    try {
      await context.read<SessionController>().deleteProfilePhoto();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil eliminada')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnack('No se pudo eliminar la foto. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isUpdatingPhoto = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatar(radius: 40, onTap: _isUpdatingPhoto ? null : _openPhotoOptions),
                    if (_isUpdatingPhoto)
                      Positioned.fill(
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.black.withValues(alpha: 0.35),
                          child: const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          ),
                        ),
                      )
                    else
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: GestureDetector(
                          onTap: _openPhotoOptions,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF07866D),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _isUpdatingPhoto ? null : _openPhotoOptions,
                  child: const Text('Cambiar foto'),
                ),
              ),
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
                        controller: _phoneController,
                        enabled: _isEditing,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
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
                                          _phoneController.text = user.phoneNumber ?? '';
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
                child: ListTile(
                  leading: const Icon(Icons.lock_reset_outlined, color: Color(0xFF07866D)),
                  title: const Text('Cambiar contraseña'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                  ),
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
