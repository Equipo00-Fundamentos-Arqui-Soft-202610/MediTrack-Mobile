import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditrack_mobile/core/network/api_exception.dart';
import 'package:meditrack_mobile/core/session/session_controller.dart';
import 'package:meditrack_mobile/features/appointments/data/services/appointment_service.dart';
import 'package:meditrack_mobile/features/appointments/domain/models/appointment_model.dart';

/// Formulario único para crear (APT-RF1) o editar (APT-RF4, solo si
/// [existing] es una cita con `canBeModified == true`) una cita médica.
/// Valida fecha futura en cliente (APT-RF2) antes de llamar al backend, que
/// también la valida server-side.
class CreateAppointmentScreen extends StatefulWidget {
  final AppointmentModel? existing;

  const CreateAppointmentScreen({super.key, this.existing});

  @override
  State<CreateAppointmentScreen> createState() => _CreateAppointmentScreenState();
}

class _CreateAppointmentScreenState extends State<CreateAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _typeController;
  late final TextEditingController _locationController;
  late final TextEditingController _notesController;
  late final TextEditingController _requirementsController;

  DateTime? _scheduledAt;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _typeController = TextEditingController(text: existing?.type ?? '');
    _locationController = TextEditingController(text: existing?.location ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _requirementsController = TextEditingController(
      text: existing?.requirements.map((r) => r.description).join(', ') ?? '',
    );
    _scheduledAt = existing?.scheduledAt;
  }

  @override
  void dispose() {
    _typeController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _requirementsController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt != null && _scheduledAt!.isAfter(now)
          ? _scheduledAt!
          : now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _scheduledAt != null
          ? TimeOfDay.fromDateTime(_scheduledAt!)
          : const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null) return;

    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  List<String>? _parseRequirements() {
    final raw = _requirementsController.text.trim();
    if (raw.isEmpty) return null;
    return raw.split(',').map((r) => r.trim()).where((r) => r.isNotEmpty).toList();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final scheduledAt = _scheduledAt;
    if (scheduledAt == null) {
      setState(() => _errorMessage = 'Selecciona una fecha y hora para la cita.');
      return;
    }
    // APT-RF2: validar fecha futura antes de enviar.
    if (!scheduledAt.isAfter(DateTime.now())) {
      setState(() => _errorMessage = 'La fecha de la cita debe ser en el futuro.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final service = AppointmentService();

    try {
      if (_isEditing) {
        await service.updateAppointment(
          id: widget.existing!.id,
          type: _typeController.text.trim(),
          scheduledAt: scheduledAt,
          location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          requirements: _parseRequirements(),
        );
      } else {
        final patientId = context.read<SessionController>().patientId;
        if (patientId == null) {
          setState(() {
            _errorMessage = 'No se pudo determinar tu perfil de paciente.';
            _isSubmitting = false;
          });
          return;
        }
        await service.createAppointment(
          patientId: patientId,
          type: _typeController.text.trim(),
          scheduledAt: scheduledAt,
          location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          requirements: _parseRequirements(),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Ocurrió un error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3FAF7),
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar cita' : 'Agendar cita'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1F2937),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                TextFormField(
                  controller: _typeController,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de cita',
                    hintText: 'Ej. Cardiología, Control general',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Ingresa el tipo de cita' : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDateTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha y hora',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    child: Text(
                      _scheduledAt == null
                          ? 'Selecciona fecha y hora'
                          : '${_scheduledAt!.day}/${_scheduledAt!.month}/${_scheduledAt!.year} · '
                              '${_scheduledAt!.hour.toString().padLeft(2, '0')}:${_scheduledAt!.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Ubicación (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _requirementsController,
                  decoration: const InputDecoration(
                    labelText: 'Requisitos previos (opcional, separados por coma)',
                    hintText: 'Ej. Ayuno de 8 horas, traer exámenes previos',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00796B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(_isEditing ? 'Guardar cambios' : 'Agendar cita',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
