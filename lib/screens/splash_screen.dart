import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_constants.dart';
import '../providers/auth_provider.dart';
import '../providers/disease_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final diseaseProvider = context.read<DiseaseProvider>();

    // Tunggu auth state selesai
    await Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      return authProvider.status == AuthStatus.initial;
    });

    if (!mounted) return;

    if (authProvider.isAuthenticated) {
      // User sudah login: langsung ke main, disease diambil dari Firestore
      Navigator.pushReplacementNamed(context, AppConstants.routeMain);
    } else if (diseaseProvider.selectedDisease == null) {
      // Guest dan belum pilih penyakit: ke halaman pilih penyakit
      Navigator.pushReplacementNamed(
          context, AppConstants.routeDiseaseSelection);
    } else {
      // Guest dengan penyakit sudah dipilih: langsung ke main
      Navigator.pushReplacementNamed(context, AppConstants.routeMain);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.favorite,
                    color: AppColors.primary,
                    size: 56,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Direka',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pantau Kesehatan Anda',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 60),
              const CircularProgressIndicator(
                color: Colors.white70,
                strokeWidth: 2.5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
