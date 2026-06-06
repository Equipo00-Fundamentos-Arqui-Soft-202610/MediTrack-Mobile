import 'package:flutter/material.dart';

import 'package:meditrack_mobile/features/home/data/models/next_dose_model.dart';
import 'package:meditrack_mobile/features/home/data/services/home_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeService _homeService = HomeService();

  final int patientId = 1;

  NextDoseModel? nextDose;
  double adherencePercentage = 0;
  List<dynamic> lowStockMedications = [];

  bool isLoading = true;
  bool isTakingDose = false;

  @override
  void initState() {
    super.initState();
    loadHomeData();
  }

  Future<void> loadHomeData() async {
    setState(() => isLoading = true);

    NextDoseModel? loadedDose;
    double loadedAdherence = 0;
    List<dynamic> loadedLowStock = [];

    try {
      loadedDose = await _homeService.getNextDose(patientId);
    } catch (error) {
      debugPrint('Next dose error: $error');
    }

    try {
      loadedAdherence = await _homeService.getAdherencePercentage(patientId);
    } catch (error) {
      debugPrint('Adherence error: $error');
    }

    try {
      loadedLowStock = await _homeService.getLowStockMedications(patientId);
    } catch (error) {
      debugPrint('Low stock error: $error');
    }

    setState(() {
      nextDose = loadedDose;
      adherencePercentage = loadedAdherence;
      lowStockMedications = loadedLowStock;
      isLoading = false;
    });
  }

  Future<void> handleTakeDose() async {
    if (nextDose == null) return;

    setState(() => isTakingDose = true);

    try {
      await _homeService.takeDose(
        patientId: patientId,
        doseScheduleId: nextDose!.doseScheduleId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dosis registrada correctamente')),
      );

      await loadHomeData();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error registrando la dosis')),
      );
    } finally {
      setState(() => isTakingDose = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3FAF7),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadHomeData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
            children: [
              _buildHeader(),
              const SizedBox(height: 24),

              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                _buildNextDoseCard(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: _buildAdherenceCard()),
                    const SizedBox(width: 14),
                    Expanded(child: _buildStockCard()),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.menu, color: Color(0xFF0F8B6E), size: 22),
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
        ),
        const SizedBox(height: 26),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Bienvenido, Ricardo',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Aquí tienes tu horario para hoy.',
            style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
          ),
        ),
      ],
    );
  }

  Widget _buildNextDoseCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F4FF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.access_time_filled,
              color: Color(0xFF07866D),
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            nextDose?.medicationName ?? 'Sin dosis pendiente',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            nextDose == null
                ? 'No tienes próxima dosis registrada'
                : 'Próxima dosis: ${nextDose!.scheduledTime}',
            style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: nextDose == null || isTakingDose
                  ? null
                  : handleTakeDose,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF07866D),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(
                isTakingDose ? 'Registrando...' : 'Tomar dosis',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.restaurant, size: 15, color: Color(0xFF4B5563)),
              SizedBox(width: 6),
              Text(
                'Con alimentos',
                style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdherenceCard() {
    final percentage = adherencePercentage <= 0 ? 0 : adherencePercentage;
    final progress = percentage / 100;

    return Container(
      height: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 78,
            height: 78,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress.clamp(0, 1),
                  strokeWidth: 9,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF07866D)),
                ),
                Center(
                  child: Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF07866D),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Progreso del\ntratamiento',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Últimos 36 días',
            style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildStockCard() {
    final hasLowStock = lowStockMedications.isNotEmpty;
    final medication = hasLowStock ? lowStockMedications.first : null;

    return Container(
      height: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEAF0),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.medical_services,
                  color: Color(0xFFB55A42),
                ),
              ),
              if (hasLowStock)
                const Icon(Icons.warning, color: Color(0xFFE11D48), size: 18),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            hasLowStock
                ? 'Stock bajo:\n${medication['name']}'
                : 'Stock\nsuficiente',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 34,
            child: ElevatedButton(
              onPressed: hasLowStock ? () {} : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB65A45),
                disabledBackgroundColor: const Color(0xFFD1D5DB),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Comprar',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
