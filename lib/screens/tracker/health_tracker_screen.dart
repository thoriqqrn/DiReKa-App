import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/disease_type.dart';
import '../../providers/auth_provider.dart';
import '../../services/nutrition_history_service.dart';
import '../../widgets/nutrition_line_chart.dart';

class HealthTrackerScreen extends StatefulWidget {
  const HealthTrackerScreen({super.key});

  @override
  State<HealthTrackerScreen> createState() => _HealthTrackerScreenState();
}

class _HealthTrackerScreenState extends State<HealthTrackerScreen> {
  late Future<List<DailyNutrition>> _weeklyDataFuture;

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
  }

  void _loadWeeklyData() {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    final uid = user?.uid ?? '';
    final needs = user?.nutritionNeeds;

    if (uid.isNotEmpty && needs != null) {
      _weeklyDataFuture = NutritionHistoryService.getWeeklyNutrition(
        uid: uid,
        endDate: DateTime.now(),
        targets: needs,
      );
    } else {
      _weeklyDataFuture = Future.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pelacak Kesehatan'),
        elevation: 0,
        backgroundColor: AppColors.primary,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final user = auth.currentUser;

          // Cek jika belum login atau belum ada nutrition needs
          if (user == null || user.nutritionNeeds == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Data kesehatan Anda belum lengkap. Silakan update profil terlebih dahulu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          // Hanya tampilkan untuk HF patients
          if (user.diseaseType != DiseaseType.heartFailure) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Grafik kesehatan hanya tersedia untuk pasien Gagal Jantung.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          return FutureBuilder<List<DailyNutrition>>(
            future: _weeklyDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Belum ada data nutrisi. Mulai catat makanan Anda!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }

              final weeklyData = snapshot.data!;

              return SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Energi Chart
                    NutritionLineChart(
                      title: 'Energi',
                      unit: 'kkal',
                      weeklyData: weeklyData,
                      lineColor: Colors.black87,
                      getActual: (data) => data.energi,
                      getTarget: (data) => data.targetEnergi,
                      minY: 0,
                      maxY: (weeklyData.fold<double>(
                              0,
                              (max, data) =>
                                  data.energi > max ? data.energi : max) *
                            1.2)
                          .toDouble(),
                    ),
                    // Lemak Chart
                    NutritionLineChart(
                      title: 'Lemak',
                      unit: 'g',
                      weeklyData: weeklyData,
                      lineColor: Colors.amber,
                      getActual: (data) => data.lemak,
                      getTarget: (data) => data.targetLemak,
                      minY: 0,
                      maxY: (weeklyData.fold<double>(
                              0,
                              (max, data) =>
                                  data.lemak > max ? data.lemak : max) *
                            1.2)
                          .toDouble(),
                    ),
                    // Natrium Chart
                    NutritionLineChart(
                      title: 'Natrium',
                      unit: 'mg',
                      weeklyData: weeklyData,
                      lineColor: Colors.orange,
                      getActual: (data) => data.natrium,
                      getTarget: (data) => data.targetNatrium,
                      minY: 0,
                      maxY: (weeklyData.fold<double>(
                              0,
                              (max, data) =>
                                  data.natrium > max ? data.natrium : max) *
                            1.2)
                          .toDouble(),
                    ),
                    // Cairan Chart
                    NutritionLineChart(
                      title: 'Cairan',
                      unit: 'ml',
                      weeklyData: weeklyData,
                      lineColor: Colors.blue,
                      getActual: (data) => data.cairan,
                      getTarget: (data) => data.targetCairan,
                      minY: 0,
                      maxY: (weeklyData.fold<double>(
                              0,
                              (max, data) =>
                                  data.cairan > max ? data.cairan : max) *
                            1.2)
                          .toDouble(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
