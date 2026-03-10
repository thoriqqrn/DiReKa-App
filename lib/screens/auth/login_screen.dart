import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/disease_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_overlay.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return LoadingOverlay(
      isLoading: auth.isLoading,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Masuk'),
          backgroundColor: AppColors.background,
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    'Selamat Datang Kembali 👋',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Masuk untuk mulai memantau kesehatan Anda.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Error message
                  if (auth.errorMessage != null) ...[
                    _ErrorBanner(message: auth.errorMessage!),
                    const SizedBox(height: 16),
                  ],

                  CustomTextField(
                    label: 'Email',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Email wajib diisi';
                      if (!v.contains('@')) return 'Format email tidak valid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Kata Sandi',
                    controller: _passwordCtrl,
                    obscureText: true,
                    prefixIcon: const Icon(Icons.lock_outline),
                    validator: (v) {
                      if (v == null || v.isEmpty)
                        return 'Kata sandi wajib diisi';
                      if (v.length < 6) return 'Kata sandi minimal 6 karakter';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _onLupaPassword,
                      child: const Text('Lupa kata sandi?'),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Tombol Masuk
                  CustomButton(
                    label: 'Masuk',
                    onPressed: _onLogin,
                    isLoading: auth.isLoading,
                  ),
                  const SizedBox(height: 16),

                  // Divider
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'atau',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tombol Google
                  CustomButton(
                    label: 'Masuk dengan Google',
                    isOutlined: true,
                    onPressed: _onGoogleSignIn,
                    icon: Image.network(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      height: 20,
                      width: 20,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.g_mobiledata, size: 24),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Daftar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Belum punya akun? ',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(
                          context,
                          AppConstants.routeRegister,
                        ),
                        child: const Text('Daftar Sekarang'),
                      ),
                    ],
                  ),

                  // Skip (lanjut sebagai tamu)
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(
                        context,
                        AppConstants.routeMain,
                      ),
                      child: const Text(
                        'Lanjutkan tanpa akun',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;

    // Cek apakah login sebagai admin
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email == AppConstants.adminEmail &&
        password == AppConstants.adminPassword) {
      Navigator.pushReplacementNamed(context, AppConstants.routeAdmin);
      return;
    }

    context.read<AuthProvider>().clearError();
    final success = await context.read<AuthProvider>().login(
          email: email,
          password: password,
        );
    if (success && mounted) {
      // Sync DiseaseProvider dengan disease dari akun yang baru login,
      // supaya SharedPreferences tidak menyimpan disease dari akun lain.
      final userDisease =
          context.read<AuthProvider>().currentUser?.diseaseType;
      if (userDisease != null) {
        await context.read<DiseaseProvider>().setDisease(userDisease);
      }
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppConstants.routeMain);
      }
    }
  }

  Future<void> _onGoogleSignIn() async {
    context.read<AuthProvider>().clearError();
    final success = await context.read<AuthProvider>().signInWithGoogle();
    if (success && mounted) {
      final isNewUser = context.read<AuthProvider>().isNewGoogleUser;
      if (isNewUser) {
        Navigator.pushReplacementNamed(
          context,
          AppConstants.routeGoogleCompleteProfile,
        );
      } else {
        // Sync DiseaseProvider untuk Google login yang sudah punya profil
        final userDisease =
            context.read<AuthProvider>().currentUser?.diseaseType;
        if (userDisease != null) {
          await context.read<DiseaseProvider>().setDisease(userDisease);
        }
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppConstants.routeMain);
        }
      }
    }
  }

  void _onLupaPassword() {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan email terlebih dahulu')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link reset kata sandi telah dikirim ke email Anda'),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
