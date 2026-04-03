import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/disease_type.dart';
import '../../providers/auth_provider.dart';

class HealthTrackerScreen extends StatelessWidget {
  const HealthTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final diseaseType = auth.currentUser?.diseaseType;
          final label = diseaseType == DiseaseType.heartFailure
              ? 'Monitoring Gagal Jantung'
              : diseaseType == DiseaseType.chronicKidneyDisease
                  ? 'Monitoring Gagal Ginjal'
                  : 'Monitoring Kesehatan';

          return Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          );
        },
      ),
    );
  }
}
