import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/disease_type.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_overlay.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  DateTime? _dateOfBirth;
  DiseaseType? _diseaseType;
  bool _initialized = false;

  double? get _bmi {
    final w = double.tryParse(_weightCtrl.text);
    final h = double.tryParse(_heightCtrl.text);
    if (w == null || h == null || h == 0) return null;
    final hM = h / 100;
    return w / (hM * hM);
  }

  String get _ageString {
    if (_dateOfBirth == null) return '-';
    final now = DateTime.now();
    int years = now.year - _dateOfBirth!.year;
    int months = now.month - _dateOfBirth!.month;
    if (months < 0) {
      years--;
      months += 12;
    }
    return '$years tahun $months bulan';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final user = context.read<AuthProvider>().userModel;
      if (user != null) {
        _nameCtrl.text = user.name;
        _emailCtrl.text = user.email;
        _weightCtrl.text = user.weight.toString();
        _heightCtrl.text = user.height.toString();
        _dateOfBirth = user.dateOfBirth;
        _diseaseType = user.diseaseType;
      }
      _initialized = true;
      _weightCtrl.addListener(() => setState(() {}));
      _heightCtrl.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return LoadingOverlay(
      isLoading: auth.isLoading,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Edit Profil')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error
                  if (auth.errorMessage != null) ...[
                    _ErrorBanner(message: auth.errorMessage!),
                    const SizedBox(height: 16),
                  ],

                  _SectionLabel(label: 'Data Diri'),
                  const SizedBox(height: 10),
                  CustomTextField(
                    label: 'Nama Lengkap',
                    controller: _nameCtrl,
                    prefixIcon: const Icon(Icons.person_outline),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Nama wajib diisi' : null,
                  ),
                  const SizedBox(height: 14),

                  // Email (read-only)
                  CustomTextField(
                    label: 'Email',
                    controller: _emailCtrl,
                    enabled: false,
                    prefixIcon: const Icon(Icons.email_outlined),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),

                  // Tanggal lahir
                  GestureDetector(
                    onTap: _pickDate,
                    child: AbsorbPointer(
                      child: TextFormField(
                        initialValue: _dateOfBirth != null
                            ? DateFormat(
                                'dd MMMM yyyy',
                                'id',
                              ).format(_dateOfBirth!)
                            : '',
                        decoration: InputDecoration(
                          labelText: 'Tanggal Lahir',
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                          suffixIcon: _dateOfBirth != null
                              ? Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    _ageString,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        validator: (_) => _dateOfBirth == null
                            ? 'Tanggal lahir wajib dipilih'
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Berat & Tinggi
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'Berat (kg)',
                          controller: _weightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          prefixIcon: const Icon(Icons.monitor_weight_outlined),
                          validator: (v) {
                            final w = double.tryParse(v ?? '');
                            if (w == null) return 'Wajib diisi';
                            if (w <= 0 || w > 300) return 'Tidak valid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CustomTextField(
                          label: 'Tinggi (cm)',
                          controller: _heightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          prefixIcon: const Icon(Icons.height),
                          validator: (v) {
                            final h = double.tryParse(v ?? '');
                            if (h == null) return 'Wajib diisi';
                            if (h <= 0 || h > 300) return 'Tidak valid';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  // IMT
                  if (_bmi != null) ...[
                    const SizedBox(height: 12),
                    _BmiInfo(bmi: _bmi!),
                  ],
                  const SizedBox(height: 14),

                  // Penyakit (read-only untuk user terdaftar)
                  _SectionLabel(label: 'Kondisi Kesehatan'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.medical_services_outlined,
                          color: AppColors.textHint,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _diseaseType?.label ?? '-',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Kondisi penyakit tidak dapat diubah',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: AppColors.textHint,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  CustomButton(
                    label: 'Simpan Perubahan',
                    onPressed: _onSave,
                    isLoading: auth.isLoading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Pilih Tanggal Lahir',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final currentUser = auth.userModel;
    if (currentUser == null) return;

    final updated = currentUser.copyWith(
      name: _nameCtrl.text.trim(),
      dateOfBirth: _dateOfBirth,
      weight: double.parse(_weightCtrl.text),
      height: double.parse(_heightCtrl.text),
    );

    auth.clearError();
    final success = await auth.updateProfile(updated);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _BmiInfo extends StatelessWidget {
  final double bmi;
  const _BmiInfo({required this.bmi});

  String get _category {
    if (bmi < 18.5) return 'Kurus';
    if (bmi < 25.0) return 'Normal';
    if (bmi < 30.0) return 'Gemuk';
    return 'Obesitas';
  }

  Color get _color {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25.0) return AppColors.success;
    if (bmi < 30.0) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.calculate_outlined, color: _color, size: 20),
          const SizedBox(width: 10),
          Text(
            'IMT: ${bmi.toStringAsFixed(1)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _color,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Text('($_category)', style: TextStyle(color: _color, fontSize: 13)),
        ],
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
