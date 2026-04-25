import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../models/activity_level.dart';
import '../../models/disease_type.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_overlay.dart';

class GoogleCompleteProfileScreen extends StatefulWidget {
  const GoogleCompleteProfileScreen({super.key});

  @override
  State<GoogleCompleteProfileScreen> createState() =>
      _GoogleCompleteProfileScreenState();
}

class _GoogleCompleteProfileScreenState
    extends State<GoogleCompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressVillageCtrl = TextEditingController();
  final _addressDistrictCtrl = TextEditingController();
  final _addressCityCtrl = TextEditingController();
  final _addressProvinceCtrl = TextEditingController();
  final _educationCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _dmDurationCtrl = TextEditingController();
  final _heartDurationCtrl = TextEditingController();
  final _insulinDurationCtrl = TextEditingController();

  DateTime? _dateOfBirth;
  DiseaseType? _diseaseType;
  String _gender = 'laki-laki';
  ActivityLevel? _activityLevel;
  bool _usesInsulinTherapy = false;
  bool _hasEdema = false; // riwayat pembengkakan — untuk pasien Jantung Koroner

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
  void initState() {
    super.initState();
    _weightCtrl.addListener(() => setState(() {}));
    _heightCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _addressVillageCtrl.dispose();
    _addressDistrictCtrl.dispose();
    _addressCityCtrl.dispose();
    _addressProvinceCtrl.dispose();
    _educationCtrl.dispose();
    _occupationCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _dmDurationCtrl.dispose();
    _heartDurationCtrl.dispose();
    _insulinDurationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.firebaseUser;

    return LoadingOverlay(
      isLoading: auth.isLoading,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Lengkapi Profil'),
          backgroundColor: AppColors.background,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hampir Selesai! 🎉',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Lengkapi data kesehatan Anda untuk memulai.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Error message
                  if (auth.errorMessage != null) ...[
                    _ErrorBanner(message: auth.errorMessage!),
                    const SizedBox(height: 16),
                  ],

                  // Info akun Google (readonly)
                  const _SectionLabel(label: 'Akun Google'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        if (user?.photoURL != null)
                          CircleAvatar(
                            backgroundImage: NetworkImage(user!.photoURL!),
                            radius: 22,
                          )
                        else
                          const CircleAvatar(
                            radius: 22,
                            child: Icon(Icons.person),
                          ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                user?.email ?? '-',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Kondisi Kesehatan
                  const _SectionLabel(label: 'Kondisi Kesehatan'),
                  const SizedBox(height: 10),
                  _DiseaseDropdown(
                    value: _diseaseType,
                    onChanged: (v) => setState(() => _diseaseType = v),
                  ),
                  const SizedBox(height: 20),

                  // Data Fisik
                  const _SectionLabel(label: 'Data Fisik'),
                  const SizedBox(height: 10),

                  // Tanggal Lahir
                  GestureDetector(
                    onTap: _pickDate,
                    child: AbsorbPointer(
                      child: TextFormField(
                        key: ValueKey(_dateOfBirth),
                        initialValue: _dateOfBirth != null
                            ? DateFormat(
                                'dd MMMM yyyy',
                                'id',
                              ).format(_dateOfBirth!)
                            : '',
                        decoration: InputDecoration(
                          labelText: 'Tanggal Lahir',
                          hintText: 'Pilih tanggal lahir',
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
                  CustomTextField(
                    label: 'Desa',
                    controller: _addressVillageCtrl,
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Desa wajib diisi' : null,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: 'Kecamatan',
                    controller: _addressDistrictCtrl,
                    prefixIcon: const Icon(Icons.map_outlined),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Kecamatan wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: 'Kab/Kota',
                    controller: _addressCityCtrl,
                    prefixIcon: const Icon(Icons.location_city_outlined),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Kab/Kota wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: 'Provinsi',
                    controller: _addressProvinceCtrl,
                    prefixIcon: const Icon(Icons.public_outlined),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Provinsi wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: 'Pendidikan Terakhir',
                    controller: _educationCtrl,
                    prefixIcon: const Icon(Icons.school_outlined),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Pendidikan terakhir wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: 'Pekerjaan',
                    controller: _occupationCtrl,
                    prefixIcon: const Icon(Icons.work_outline),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Pekerjaan wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  // Berat & Tinggi
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'Berat Badan (kg)',
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
                          label: 'Tinggi Badan (cm)',
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

                  if (_bmi != null) ...[
                    const SizedBox(height: 12),
                    _BmiInfo(bmi: _bmi!),
                  ],

                  // Pertanyaan pembengkakan — hanya untuk pasien Jantung Koroner
                  if (_diseaseType == DiseaseType.heartFailure) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Apakah ada riwayat pembengkakan?',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _hasEdema ? 'Ya, ada' : 'Tidak ada',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _hasEdema
                                        ? Colors.orange
                                        : Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _hasEdema,
                            onChanged: (val) => setState(() => _hasEdema = val),
                            activeThumbColor: Colors.orange,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Jenis Kelamin
                  const _SectionLabel(label: 'Jenis Kelamin'),
                  const SizedBox(height: 10),
                  _GenderSelector(
                    value: _gender,
                    onChanged: (v) => setState(() => _gender = v),
                  ),

                  // Field aktivitas — untuk pasien DM & Jantung Koroner
                  if (_diseaseType == DiseaseType.type2DiabetesMellitus ||
                      _diseaseType == DiseaseType.heartFailure) ...[
                    const SizedBox(height: 20),
                    _SectionLabel(
                      label:
                          _diseaseType == DiseaseType.type2DiabetesMellitus
                              ? 'Data Klinis Diabetes'
                              : 'Data Klinis Jantung Koroner',
                    ),
                    const SizedBox(height: 10),
                    CustomTextField(
                      label:
                          _diseaseType == DiseaseType.type2DiabetesMellitus
                              ? 'Lama menderita DM (tahun)'
                              : 'Lama menderita Jantung Koroner (tahun)',
                      controller:
                          _diseaseType == DiseaseType.type2DiabetesMellitus
                              ? _dmDurationCtrl
                              : _heartDurationCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefixIcon: const Icon(Icons.timelapse_outlined),
                      validator: (v) {
                        final value = double.tryParse(v ?? '');
                        if (value == null || value < 0) {
                          return 'Lama penyakit wajib diisi';
                        }
                        return null;
                      },
                    ),
                    if (_diseaseType == DiseaseType.type2DiabetesMellitus) ...[
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        value: _usesInsulinTherapy,
                        onChanged: (value) =>
                            setState(() => _usesInsulinTherapy = value),
                        title: const Text('Sedang menjalani insulin'),
                        subtitle: const Text(
                          'Aktifkan jika pasien saat ini menggunakan terapi insulin.',
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_usesInsulinTherapy) ...[
                        const SizedBox(height: 10),
                        CustomTextField(
                          label: 'Lama menggunakan insulin (tahun)',
                          controller: _insulinDurationCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          prefixIcon: const Icon(Icons.history_edu_outlined),
                          validator: (v) {
                            final value = double.tryParse(v ?? '');
                            if (value == null || value < 0) {
                              return 'Wajib diisi jika menjalani insulin';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                    const SizedBox(height: 10),
                    const _SectionLabel(label: 'Tingkat Aktivitas Fisik'),
                    const SizedBox(height: 10),
                    _ActivityLevelSelector(
                      value: _activityLevel,
                      onChanged: (v) => setState(() => _activityLevel = v),
                    ),
                  ],

                  const SizedBox(height: 36),

                  CustomButton(
                    label: 'Mulai Sekarang',
                    onPressed: _onSubmit,
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
      initialDate: DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Pilih Tanggal Lahir',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_diseaseType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kondisi kesehatan terlebih dahulu'),
        ),
      );
      return;
    }

    final success = await context.read<AuthProvider>().completeGoogleProfile(
      diseaseType: _diseaseType!,
      dateOfBirth: _dateOfBirth!,
      weight: double.parse(_weightCtrl.text),
      height: double.parse(_heightCtrl.text),
      addressVillage: _addressVillageCtrl.text.trim(),
      addressDistrict: _addressDistrictCtrl.text.trim(),
      addressCity: _addressCityCtrl.text.trim(),
      addressProvince: _addressProvinceCtrl.text.trim(),
      education: _educationCtrl.text.trim(),
      occupation: _occupationCtrl.text.trim(),
      gender: _gender,
      activityLevel: (_diseaseType == DiseaseType.type2DiabetesMellitus ||
              _diseaseType == DiseaseType.heartFailure)
          ? (_activityLevel ?? ActivityLevel.ringan)
          : null,
      diabetesDurationYears:
          double.tryParse(_dmDurationCtrl.text.trim()) ?? 0.0,
      heartDiseaseDurationYears:
          double.tryParse(_heartDurationCtrl.text.trim()) ?? 0.0,
      usesInsulinTherapy: _usesInsulinTherapy,
      insulinDurationYears: _usesInsulinTherapy
          ? (double.tryParse(_insulinDurationCtrl.text.trim()) ?? 0.0)
          : 0.0,
      hasEdema: _hasEdema,
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, AppConstants.routeMain);
    }
  }
}

// --- Helper Widgets ---

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

class _DiseaseDropdown extends StatelessWidget {
  final DiseaseType? value;
  final void Function(DiseaseType?) onChanged;
  const _DiseaseDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<DiseaseType>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: 'Kondisi Penyakit',
        prefixIcon: const Icon(Icons.medical_services_outlined),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      items: DiseaseType.values
          .map((d) => DropdownMenuItem(value: d, child: Text(d.label)))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Pilih kondisi penyakit' : null,
    );
  }
}

class _BmiInfo extends StatelessWidget {
  final double bmi;
  const _BmiInfo({required this.bmi});

  String get _category {
    if (bmi < 18.5) return 'Kurus';
    if (bmi < 25.0) return 'Normal';
    return 'Gemuk';
  }

  Color get _color {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 25.0) return AppColors.success;
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

class _GenderSelector extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;
  const _GenderSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GenderOption(
            label: 'Laki-laki',
            icon: Icons.male,
            selected: value == 'laki-laki',
            onTap: () => onChanged('laki-laki'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GenderOption(
            label: 'Perempuan',
            icon: Icons.female,
            selected: value == 'perempuan',
            onTap: () => onChanged('perempuan'),
          ),
        ),
      ],
    );
  }
}

class _GenderOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _GenderOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityLevelSelector extends StatelessWidget {
  final ActivityLevel? value;
  final void Function(ActivityLevel) onChanged;
  const _ActivityLevelSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: ActivityLevel.values.map((level) {
        final sel = value == level;
        return GestureDetector(
          onTap: () => onChanged(level),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: sel
                  ? AppColors.diabetesColor.withValues(alpha: 0.08)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel ? AppColors.diabetesColor : AppColors.border,
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sel ? AppColors.diabetesColor : AppColors.border,
                      width: sel ? 6 : 2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel
                              ? AppColors.diabetesColor
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        level.description,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
