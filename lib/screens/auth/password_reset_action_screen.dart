import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_overlay.dart';

class PasswordResetActionScreen extends StatefulWidget {
  const PasswordResetActionScreen({super.key});

  @override
  State<PasswordResetActionScreen> createState() =>
      _PasswordResetActionScreenState();
}

class _PasswordResetActionScreenState extends State<PasswordResetActionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  String? _oobCode;
  String? _accountEmail;
  String? _continueUrl;
  bool _isCheckingCode = true;
  bool _isLinkInvalid = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final params = Uri.base.queryParameters;
    final mode = params['mode'] ?? '';
    final code = params['oobCode'] ?? '';
    _continueUrl = params['continueUrl'];

    if (mode != 'resetPassword' || code.isEmpty) {
      setState(() {
        _isLinkInvalid = true;
        _isCheckingCode = false;
      });
      return;
    }

    _oobCode = code;
    final email = await context.read<AuthProvider>().verifyResetPasswordCode(
      code,
    );
    if (!mounted) return;

    setState(() {
      _accountEmail = email;
      _isLinkInvalid = email == null;
      _isCheckingCode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return LoadingOverlay(
      isLoading: auth.isLoading,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Ganti Password')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: _isCheckingCode
                      ? const Center(child: CircularProgressIndicator())
                      : _isLinkInvalid
                      ? _InvalidResetState(
                          message:
                              auth.errorMessage ??
                              'Link reset password tidak valid atau sudah kedaluwarsa.',
                        )
                      : Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Buat kata sandi baru',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.titleLarge?.color,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _accountEmail == null
                                    ? 'Masukkan kata sandi baru untuk akun Anda.'
                                    : 'Masukkan kata sandi baru untuk akun $_accountEmail.',
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
                                    color: AppColors.error.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.error.withValues(
                                        alpha: 0.28,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    auth.errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              CustomTextField(
                                label: 'Password baru',
                                controller: _newPasswordCtrl,
                                obscureText: true,
                                prefixIcon: const Icon(Icons.lock_outline),
                                validator: (value) {
                                  final password = value?.trim() ?? '';
                                  if (password.isEmpty) {
                                    return 'Password baru wajib diisi';
                                  }
                                  if (password.length < 6) {
                                    return 'Password baru minimal 6 karakter';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              CustomTextField(
                                label: 'Konfirmasi password baru',
                                controller: _confirmPasswordCtrl,
                                obscureText: true,
                                prefixIcon: const Icon(Icons.lock_reset_outlined),
                                validator: (value) {
                                  final confirm = value?.trim() ?? '';
                                  if (confirm.isEmpty) {
                                    return 'Konfirmasi password wajib diisi';
                                  }
                                  if (confirm != _newPasswordCtrl.text.trim()) {
                                    return 'Konfirmasi password tidak sama';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              CustomButton(
                                label: 'Simpan Password Baru',
                                onPressed: _submit,
                                isLoading: auth.isLoading,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final code = _oobCode;
    if (code == null || code.isEmpty) return;

    final auth = context.read<AuthProvider>();
    auth.clearError();
    final success = await auth.confirmResetPassword(
      code: code,
      newPassword: _newPasswordCtrl.text.trim(),
    );
    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Gagal memperbarui password.'),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Password Berhasil Diubah'),
        content: const Text(
          'Password baru sudah tersimpan. Silakan kembali ke halaman login dan masuk dengan password baru Anda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );

    final continueUrl = _continueUrl;
    if (continueUrl != null && continueUrl.isNotEmpty) {
      final uri = Uri.tryParse(continueUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppConstants.routeLogin,
        (_) => false,
      );
    }
  }
}

class _InvalidResetState extends StatelessWidget {
  final String message;

  const _InvalidResetState({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.link_off, color: AppColors.error, size: 54),
        const SizedBox(height: 16),
        Text(
          'Link Reset Tidak Bisa Dipakai',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleLarge?.color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          message,
          style: TextStyle(color: theme.hintColor, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
