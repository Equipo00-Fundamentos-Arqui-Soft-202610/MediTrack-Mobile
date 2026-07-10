import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meditrack_mobile/core/network/api_exception.dart';
import 'package:meditrack_mobile/core/session/session_controller.dart';
import 'package:meditrack_mobile/shared/widgets/app_drawer_menu.dart';
import '../../data/services/adherence_service.dart';

class AdherenceScreen extends StatefulWidget {
  const AdherenceScreen({super.key});

  @override
  State<AdherenceScreen> createState() => _AdherenceScreenState();
}

class _AdherenceScreenState extends State<AdherenceScreen> {
  final AdherenceService _service = AdherenceService();

  bool _isLoading = true;
  String? _errorMessage;
  _AdherenceData _data = _AdherenceData.empty();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final patientId = context.read<SessionController>().patientId;
    if (patientId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo determinar tu perfil de paciente.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Se piden en paralelo: si una falla no debe ocultar las otras dos.
      final results = await Future.wait([
        _service.getAdherencePercentage(patientId),
        _service.getRecentCompliance(patientId: patientId, limit: 10),
        _service.getMedications(patientId),
      ]);

      if (!mounted) return;
      setState(() {
        _data = _AdherenceData(
          percentage: results[0] as double,
          recentCompliance: results[1] as List<dynamic>,
          medications: results[2] as List<dynamic>,
        );
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo cargar tu adherencia. Intenta de nuevo.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawerMenu(),
      backgroundColor: const Color(0xFFF3FAF7),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          Text(
            'No se pudo cargar la adherencia.\n$_errorMessage',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final data = _data;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        _AdherenceSummaryCard(percentage: data.percentage),
        const SizedBox(height: 20),
        _WeeklyCard(items: data.recentCompliance),
        const SizedBox(height: 20),
        const Text(
          'Historial reciente',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        if (data.recentCompliance.isEmpty)
          const _EmptyHistoryCard()
        else
          ...data.recentCompliance.map(
            (item) =>
                _HistoryItemCard(item: item, medications: data.medications),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Builder(
          builder: (context) => IconButton(
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
            icon: const Icon(Icons.menu, color: Color(0xFF0F8B6E), size: 24),
          ),
        ),
        const Spacer(),
        const Text(
          'MediTrack',
          style: TextStyle(
            color: Color(0xFF00856F),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFE1F3EE),
          child: ClipOval(
            child: Image.network(
              'https://i.pravatar.cc/100',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }
}

class _AdherenceSummaryCard extends StatelessWidget {
  final double percentage;

  const _AdherenceSummaryCard({required this.percentage});

  @override
  Widget build(BuildContext context) {
    final value = percentage.clamp(0, 100);
    final progress = value / 100;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Text(
            'Adherencia de 30 días',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            value >= 80
                ? '¡Excelente trabajo manteniéndote al día!'
                : 'Sigue registrando tus dosis para mejorar.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: 155,
            height: 155,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 145,
                  height: 145,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 18,
                    backgroundColor: const Color(0xFFE6EFEC),
                    color: const Color(0xFF00796B),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '${value.round()}%',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00796B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Cumplimiento general'),
        ],
      ),
    );
  }
}

class _WeeklyCard extends StatelessWidget {
  final List<dynamic> items;

  const _WeeklyCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final statuses = _buildWeekStatuses(items);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Esta semana',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
              ),
              Icon(Icons.stacked_line_chart, color: Color(0xFF00796B)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: statuses.entries.map((entry) {
              return _DayStatus(label: entry.key, status: entry.value);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Map<String, String> _buildWeekStatuses(List<dynamic> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final result = {
      'L': 'pending',
      'M': 'pending',
      'M ': 'pending',
      'J': 'pending',
      'V': 'pending',
      'S': 'pending',
      'D': 'pending',
    };

    final keys = result.keys.toList();

    for (final item in items) {
      final recordedAtRaw = item['recordedAt'];
      if (recordedAtRaw == null) continue;

      final recordedAt = DateTime.tryParse(recordedAtRaw.toString());
      if (recordedAt == null) continue;

      final day = DateTime(recordedAt.year, recordedAt.month, recordedAt.day);
      final diff = today.difference(day).inDays;

      if (diff < 0 || diff > 6) continue;

      final status = item['status']?.toString() ?? 'pending';

      result[keys[6 - diff]] = status;
    }

    return result;
  }
}

class _DayStatus extends StatelessWidget {
  final String label;
  final String status;

  const _DayStatus({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final isTaken = status == 'taken';
    final isSkipped = status == 'skipped';

    final bgColor = isTaken
        ? const Color(0xFF00796B)
        : isSkipped
        ? const Color(0xFFFFE0E0)
        : const Color(0xFFE6EFEC);

    final iconColor = isTaken
        ? Colors.white
        : isSkipped
        ? Colors.red
        : Colors.grey;

    final icon = isTaken
        ? Icons.check
        : isSkipped
        ? Icons.close
        : Icons.remove;

    return Column(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: bgColor,
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(height: 8),
        Text(label.trim(), style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _HistoryItemCard extends StatelessWidget {
  final dynamic item;
  final List<dynamic> medications;

  const _HistoryItemCard({required this.item, required this.medications});

  @override
  Widget build(BuildContext context) {
    final status = item['status']?.toString() ?? 'pending';
    final isTaken = status == 'taken';

    final recordedAt = DateTime.tryParse(item['recordedAt']?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(
        backgroundColor: isTaken ? Colors.white : const Color(0xFFFFEEEE),
        borderColor: isTaken ? null : const Color(0xFFFFCDD2),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: isTaken ? const Color(0xFFEAF2EF) : Colors.white,
            child: CircleAvatar(
              radius: 10,
              backgroundColor: isTaken ? const Color(0xFF2E7D32) : Colors.red,
              child: Icon(
                isTaken ? Icons.check : Icons.close,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(recordedAt),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _getMedicationLabel(),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          _StatusBadge(status: status),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sin fecha';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDay = DateTime(date.year, date.month, date.day);

    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:$minute $period';

    if (itemDay == today) return 'Hoy, $time';
    if (itemDay == today.subtract(const Duration(days: 1))) {
      return 'Ayer, $time';
    }

    const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return '${days[date.weekday - 1]}, $time';
  }

  String _getMedicationLabel() {
    final doseScheduleId = item['doseScheduleId'];

    for (final medication in medications) {
      final schedules = medication['schedules'] as List<dynamic>;

      for (final schedule in schedules) {
        if (schedule['id'] == doseScheduleId) {
          final name = medication['name'] ?? 'Medicamento';
          final dose = medication['dose'] ?? '';
          return '$name - $dose';
        }
      }
    }

    return 'Dosis programada #$doseScheduleId';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isTaken = status == 'taken';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isTaken ? const Color(0xFFE8F5E9) : const Color(0xFFFFDAD6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isTaken ? 'Tomado' : 'Omitido',
        style: TextStyle(
          color: isTaken ? const Color(0xFF2E7D32) : Colors.red,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: const Text(
        'Aún no hay registros de cumplimiento para mostrar.',
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _AdherenceData {
  final double percentage;
  final List<dynamic> recentCompliance;
  final List<dynamic> medications;

  const _AdherenceData({
    required this.percentage,
    required this.recentCompliance,
    required this.medications,
  });

  factory _AdherenceData.empty() {
    return const _AdherenceData(
      percentage: 0,
      recentCompliance: [],
      medications: [],
    );
  }
}

BoxDecoration _cardDecoration({
  Color backgroundColor = Colors.white,
  Color? borderColor,
}) {
  return BoxDecoration(
    color: backgroundColor,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: borderColor ?? const Color(0xFFE6E6E6)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ],
  );
}
