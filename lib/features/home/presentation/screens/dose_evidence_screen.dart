import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:meditrack_mobile/core/constants/app_constants.dart';
import 'package:meditrack_mobile/core/network/api_exception.dart';
import 'package:meditrack_mobile/features/home/data/models/next_dose_model.dart';
import 'package:meditrack_mobile/features/home/data/services/home_service.dart';
import 'package:meditrack_mobile/features/reminders/application/services/dose_reminder_coordinator.dart';

enum _Stage {
  recording,
  preview,
  uploading,
  waiting,
  approved,
  rejected,
  error,
}

/// Flujo completo de evidencia en video para "Tomar dosis": grabar (máx. 30s)
/// -> previsualizar -> enviar -> esperar validación humana (MediTrack AI
/// Validator — Prototype, no hay IA real decidiendo en esta versión).
class DoseEvidenceScreen extends StatefulWidget {
  final NextDoseModel dose;

  const DoseEvidenceScreen({super.key, required this.dose});

  @override
  State<DoseEvidenceScreen> createState() => _DoseEvidenceScreenState();
}

class _DoseEvidenceScreenState extends State<DoseEvidenceScreen> {
  final HomeService _homeService = HomeService();
  final ImagePicker _picker = ImagePicker();

  _Stage _stage = _Stage.recording;
  XFile? _videoFile;
  VideoPlayerController? _videoController;
  double _uploadProgress = 0;
  int? _complianceId;
  String? _rejectionReason;
  String? _errorMessage;
  Timer? _pollingTimer;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    // "Al pulsar 'Tomar dosis', abrir la cámara" — se lanza apenas se entra a la pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordVideo());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _recordVideo() async {
    final file = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 30),
    );

    if (file == null) {
      // El usuario canceló la cámara: no hay nada que grabar, se vuelve a Home.
      if (mounted) context.pop(_changed);
      return;
    }

    _videoController?.dispose();
    final controller = VideoPlayerController.file(File(file.path));
    await controller.initialize();

    if (!mounted) return;
    setState(() {
      _videoFile = file;
      _videoController = controller;
      _stage = _Stage.preview;
    });
  }

  Future<void> _deleteLocalVideo() async {
    final path = _videoFile?.path;
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // No bloquea el flujo: es solo limpieza de almacenamiento local.
    }
  }

  Future<void> _handleSend() async {
    if (_videoFile == null || _stage == _Stage.uploading)
      return; // evita doble envío

    setState(() {
      _stage = _Stage.uploading;
      _uploadProgress = 0;
      _errorMessage = null;
    });

    try {
      final complianceId = await _homeService.uploadComplianceVideo(
        doseScheduleId: widget.dose.doseScheduleId,
        videoFile: File(_videoFile!.path),
        onSendProgress: (sent, total) {
          if (total <= 0 || !mounted) return;
          setState(() => _uploadProgress = sent / total);
        },
      );

      await _deleteLocalVideo();
      _changed = true;
      // Ya existe evidencia para esta dosis: no debe volver a sonar ninguna
      // alarma de este ciclo (regla: "al estar PendingValidation no se
      // programan nuevos avisos").
      await DoseReminderCoordinator.instance.cancelCycleForResolvedDose(
        doseScheduleId: widget.dose.doseScheduleId,
        scheduledAtUtc: widget.dose.scheduledAtUtc,
      );

      if (!mounted) return;
      setState(() {
        _complianceId = complianceId;
        _stage = _Stage.waiting;
      });
      _startPolling();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _errorMessage = 'No se pudo enviar la evidencia. Intenta de nuevo.';
      });
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: AppConstants.complianceStatusPollingSeconds),
      (_) => _checkStatus(),
    );
  }

  Future<void> _checkStatus() async {
    final complianceId = _complianceId;
    if (complianceId == null) return;

    try {
      final data = await _homeService.getComplianceStatus(complianceId);
      final status = data['status'] as String?;

      if (!mounted) return;

      if (status?.toLowerCase() == 'approved') {
        _pollingTimer?.cancel();
        setState(() => _stage = _Stage.approved);
      } else if (status?.toLowerCase() == 'rejected') {
        _pollingTimer?.cancel();
        setState(() {
          _stage = _Stage.rejected;
          _rejectionReason = data['rejectionReason'] as String?;
        });
      }
      // Si sigue "pendingvalidation", no hay nada que cambiar: se sigue esperando.
    } catch (_) {
      // Fallo transitorio de red: se reintenta en el próximo tick, no se
      // interrumpe el polling por un error puntual.
    }
  }

  Future<void> _handleRetry() async {
    _pollingTimer?.cancel();
    setState(() {
      _stage = _Stage.recording;
      _videoFile = null;
      _complianceId = null;
      _rejectionReason = null;
    });
    await _recordVideo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3FAF7),
      appBar: AppBar(
        title: Text(widget.dose.medicationName),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1F2937),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(_changed),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _checkStatus,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [_buildBody()],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_stage) {
      case _Stage.recording:
        return const Padding(
          padding: EdgeInsets.only(top: 120),
          child: Center(child: CircularProgressIndicator()),
        );

      case _Stage.preview:
        return _buildPreview();

      case _Stage.uploading:
        return _buildStatusCard(
          icon: Icons.cloud_upload_outlined,
          title: 'Enviando evidencia...',
          subtitle: '${(_uploadProgress * 100).toStringAsFixed(0)}%',
          child: LinearProgressIndicator(
            value: _uploadProgress == 0 ? null : _uploadProgress,
          ),
        );

      case _Stage.waiting:
        return _buildStatusCard(
          icon: Icons.hourglass_top,
          title: 'Evidencia en validación',
          subtitle:
              'Un validador revisará tu video en breve. Puedes cerrar esta pantalla;\n'
              'el estado se actualizará en Inicio.',
          child: const Padding(
            padding: EdgeInsets.only(top: 16),
            child: CircularProgressIndicator(),
          ),
        );

      case _Stage.approved:
        return _buildStatusCard(
          icon: Icons.check_circle,
          iconColor: const Color(0xFF2E7D32),
          title: 'Dosis completada',
          subtitle: 'Tu evidencia fue aprobada. ¡Buen trabajo!',
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF07866D),
                foregroundColor: Colors.white,
              ),
              child: const Text('Volver a inicio'),
            ),
          ),
        );

      case _Stage.rejected:
        return _buildStatusCard(
          icon: Icons.cancel_outlined,
          iconColor: const Color(0xFFB3261E),
          title: 'Evidencia rechazada',
          subtitle: _rejectionReason?.isNotEmpty == true
              ? _rejectionReason!
              : 'El validador no pudo aprobar tu evidencia.',
          child: Column(
            children: [
              if (_isStillWithinWindow())
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF07866D),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Volver a intentar'),
                  ),
                )
              else
                const Text(
                  'La ventana de toma de esta dosis ya finalizó.',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.pop(true),
                child: const Text('Volver a inicio'),
              ),
            ],
          ),
        );

      case _Stage.error:
        return _buildStatusCard(
          icon: Icons.error_outline,
          iconColor: const Color(0xFFB3261E),
          title: 'Error al enviar',
          subtitle: _errorMessage ?? 'Ocurrió un error inesperado.',
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _stage = _Stage.preview),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF07866D),
                foregroundColor: Colors.white,
              ),
              child: const Text('Reintentar envío'),
            ),
          ),
        );
    }
  }

  bool _isStillWithinWindow() {
    final windowEnd = widget.dose.scheduledAtUtc.add(
      const Duration(minutes: AppConstants.doseReminderCloseOffsetMinutes),
    );
    return !DateTime.now().toUtc().isAfter(windowEnd);
  }

  Widget _buildPreview() {
    final controller = _videoController;
    return Column(
      children: [
        if (controller != null && controller.value.isInitialized)
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: VideoPlayer(controller),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filled(
              onPressed: () {
                if (controller == null) return;
                setState(() {
                  controller.value.isPlaying
                      ? controller.pause()
                      : controller.play();
                });
              },
              icon: Icon(
                controller?.value.isPlaying == true
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF07866D),
              ),
              color: Colors.white,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _recordVideo,
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('Volver a grabar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _handleSend,
                icon: const Icon(Icons.send),
                label: const Text('Enviar evidencia'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF07866D),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Color iconColor = const Color(0xFF07866D),
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(icon, size: 64, color: iconColor),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}
