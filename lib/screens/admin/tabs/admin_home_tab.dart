import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_constants.dart';
import '../../../models/disease_type.dart';
import '../../../services/admin_service.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminHomeTab extends StatefulWidget {
  final AdminService adminService;
  const AdminHomeTab({super.key, required this.adminService});

  @override
  State<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<AdminHomeTab> {
  static const Color _diseaseGreen = Color(0xFF34A853);
  static const Color _diseaseBlue = Color(0xFF4285F4);
  static const Color _diseaseYellow = Color(0xFFFBBC04);

  Color _diseaseChartColor(DiseaseType disease) {
    switch (disease) {
      case DiseaseType.chronicKidneyDisease:
        return _diseaseGreen;
      case DiseaseType.type2DiabetesMellitus:
        return _diseaseBlue;
      case DiseaseType.heartFailure:
        return _diseaseYellow;
    }
  }

  bool _isLoading = false;
  String? _error;
  int _totalUsers = 0;
  Map<DiseaseType, int> _usersByDisease = {};
  int _foodLogCount = 0;
  int _healthRecordCount = 0;
  int _educationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final total = await widget.adminService.getTotalUsers();
      final byDisease = await widget.adminService.getUsersByDisease();
      final foodLogs = await widget.adminService.getRecentFoodLogs(limit: 100);
      final healthRecords = await widget.adminService.getRecentHealthRecords(maxUsers: 50);
      final education = await widget.adminService.getEducationPosts();

      if (!mounted) return;
      setState(() {
        _totalUsers = total;
        _usersByDisease = byDisease;
        _foodLogCount = foodLogs.length;
        _healthRecordCount = healthRecords.length;
        _educationCount = education.length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat dashboard: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return AdminErrorView(message: _error!, onRetry: _loadData);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Ikhtisar Aktivitas',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              AdminMetricCard(
                title: 'Data Makanan',
                value: '$_foodLogCount',
                icon: Icons.restaurant_menu_rounded,
                colors: [const Color(0xFF43A047), const Color(0xFF66BB6A)],
              ),
              AdminMetricCard(
                title: 'Rekam Medis',
                value: '$_healthRecordCount',
                icon: Icons.health_and_safety_rounded,
                colors: [const Color(0xFFE53935), const Color(0xFFEF5350)],
              ),
              AdminMetricCard(
                title: 'Total User',
                value: '$_totalUsers',
                icon: Icons.people_alt_rounded,
                colors: [const Color(0xFF1E88E5), const Color(0xFF42A5F5)],
              ),
              AdminMetricCard(
                title: 'Konten Edukasi',
                value: '$_educationCount',
                icon: Icons.school_rounded,
                colors: [const Color(0xFFFB8C00), const Color(0xFFFFA726)],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Button Katalog Makanan
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, AppConstants.routeAdminFoodCatalog),
              icon: const Icon(Icons.library_books_outlined),
              label: const Text('Kelola Katalog Makanan (TKPI)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Chart
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Distribusi Penyakit Pengguna',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 4,
                            centerSpaceRadius: 40,
                            sections: DiseaseType.values.map((disease) {
                              final count = _usersByDisease[disease] ?? 0;
                              final percentage = _totalUsers > 0 ? (count / _totalUsers * 100) : 0.0;
                              
                              final color = _diseaseChartColor(disease);

                              return PieChartSectionData(
                                color: color,
                                value: count.toDouble(),
                                title: count > 0 ? '${percentage.toStringAsFixed(0)}%' : '',
                                radius: 50,
                                titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: DiseaseType.values.map((disease) {
                            final count = _usersByDisease[disease] ?? 0;
                            final color = _diseaseChartColor(disease);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      DiseaseTypeExtension.getLabel(disease),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '$count',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
