import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_overlay.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return LoadingOverlay(
      isLoading: auth.isLoading,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Lupa Password')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reset kata sandi akun DIREKA',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.titleLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Masukkan email terdaftar. Kami akan mengirim link reset password yang aman ke email tersebut.',
                          style: TextStyle(
                            color: theme.hintColor,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (auth.errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Text(
                              auth.errorMessage!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        CustomTextField(
                          label: 'Email terdaftar',
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(Icons.email_outlined),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) {
                              return 'Email wajib diisi';
                            }
                            final valid = RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(email);
                            if (!valid) {
                              return 'Format email tidak valid';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        CustomButton(
                          label: 'Kirim Link Reset Password',
                          onPressed: _submit,
                          isLoading: auth.isLoading,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Link reset akan mengikuti pengaturan keamanan Firebase dan hanya boleh dipakai dalam waktu terbatas.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.hintColor,
                            height: 1.5,
                          ),
                        ),
                      ],
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    auth.clearError();
    final success = await auth.requestPasswordReset(_emailCtrl.text.trim());
    if (!mounted) return;

    if (success) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Email Terkirim'),
          content: const Text(
            'Jika email terhubung dengan akun DIREKA, link reset password akan dikirim beberapa saat lagi. Silakan cek inbox atau folder spam.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.errorMessage ?? 'Gagal mengirim link reset password.',
          ),
        ),
      );
    }
  }
}
