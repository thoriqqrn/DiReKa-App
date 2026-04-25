import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../models/activity_level.dart';
import '../../models/disease_type.dart';
import '../../models/hemodialysis_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/disease_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_overlay.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _addressVillageCtrl = TextEditingController();
  final _addressDistrictCtrl = TextEditingController();
  final _addressCityCtrl = TextEditingController();
  final _addressProvinceCtrl = TextEditingController();
  final _educationCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _urinOutputCtrl = TextEditingController();
  final _dmDurationCtrl = TextEditingController();

  DateTime? _dateOfBirth;
  DiseaseType? _diseaseType;
  String _gender = 'laki-laki';
  ActivityLevel? _activityLevel;
  bool _usesInsulinTherapy = false;
  bool _hasEdema = false; // riwayat pembengkakan — untuk pasien gagal jantung

  // Hemodialisis — untuk pasien penyakit ginjal
  DateTime? _hdStartDate;
  DateTime? _hdEndDate;
  final List<String> _hdDayOptions = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  final Set<String> _hdSelectedDays = {};
  final _hdLocationCtrl = TextEditingController();

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
    _diseaseType = context.read<DiseaseProvider>().selectedDisease;
    _weightCtrl.addListener(() => setState(() {}));
    _heightCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPassCtrl.dispose();
    _addressVillageCtrl.dispose();
    _addressDistrictCtrl.dispose();
    _addressCityCtrl.dispose();
    _addressProvinceCtrl.dispose();
    _educationCtrl.dispose();
    _occupationCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _urinOutputCtrl.dispose();
    _dmDurationCtrl.dispose();
    _hdLocationCtrl.dispose();
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
          title: const Text('Daftar Akun'),
          backgroundColor: AppColors.background,
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
                    'Buat Akun Baru',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Lengkapi data diri Anda untuk melanjutkan.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Error
                  if (auth.errorMessage != null) ...[
                    _ErrorBanner(message: auth.errorMessage!),
                    const SizedBox(height: 16),
                  ],

                  // Pilih Penyakit
                  _SectionLabel(label: 'Kondisi Kesehatan'),
                  const SizedBox(height: 10),
                  _DiseaseDropdown(
                    value: _diseaseType,
                    onChanged: (v) => setState(() => _diseaseType = v),
                  ),
                  const SizedBox(height: 20),

                  // Data Diri
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

                  // Gender
                  _GenderSelector(
                    value: _gender,
                    onChanged: (v) => setState(() => _gender = v),
                  ),
                  const SizedBox(height: 14),
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

                  // Tampilkan IMT jika sudah ada
                  if (_bmi != null) ...[
                    const SizedBox(height: 12),
                    _BmiInfo(bmi: _bmi!),
                  ],

                  // Pertanyaan pembengkakan — hanya untuk pasien gagal jantung
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

                  // Field urin output — hanya untuk pasien ginjal
                  if (_diseaseType == DiseaseType.chronicKidneyDisease) ...[
                    const SizedBox(height: 14),
                    _UrinOutputField(controller: _urinOutputCtrl),
                  ],

                  // Hemodialisis section — hanya untuk pasien ginjal
                  if (_diseaseType == DiseaseType.chronicKidneyDisease) ...[
                    const SizedBox(height: 20),
                    _SectionLabel(label: 'Data Hemodialisis'),
                    const SizedBox(height: 10),
                    // Tanggal Mulai
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                          cancelText: 'Batal',
                          confirmText: 'Pilih',
                        );
                        if (picked != null) {
                          setState(() => _hdStartDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tanggal Mulai',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _hdStartDate != null
                                      ? DateFormat(
                                          'dd MMM yyyy',
                                          'id_ID',
                                        ).format(_hdStartDate!)
                                      : 'Pilih tanggal',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.calendar_today_outlined,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Tanggal Berakhir
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _hdStartDate ?? DateTime.now(),
                          firstDate: _hdStartDate ?? DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 36500),
                          ),
                          cancelText: 'Batal',
                          confirmText: 'Pilih',
                        );
                        if (picked != null) {
                          setState(() => _hdEndDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tanggal Berakhir',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _hdEndDate != null
                                      ? DateFormat(
                                          'dd MMM yyyy',
                                          'id_ID',
                                        ).format(_hdEndDate!)
                                      : 'Pilih tanggal',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.calendar_today_outlined,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Jadwal dialisis (checkbox grid)
                    const Text(
                      'Jadwal Dialisis (pilih max 3 hari)',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1,
                      children: _hdDayOptions.map((day) {
                        final isSelected = _hdSelectedDays.contains(day);
                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _hdSelectedDays.remove(day);
                              } else if (_hdSelectedDays.length < 3) {
                                _hdSelectedDays.add(day);
                              }
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.surface,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                day.substring(0, 3),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    // Lokasi
                    CustomTextField(
                      label: 'Lokasi Dialisis (Rumah Sakit/Klinik)',
                      controller: _hdLocationCtrl,
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Lokasi wajib diisi';
                        return null;
                      },
                    ),
                  ],

                  // Field aktivitas — hanya untuk pasien DM
                  if (_diseaseType == DiseaseType.type2DiabetesMellitus) ...[
                    const SizedBox(height: 20),
                    _SectionLabel(label: 'Data Klinis Diabetes'),
                    const SizedBox(height: 10),
                    CustomTextField(
                      label: 'Lama menderita DM (tahun)',
                      controller: _dmDurationCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefixIcon: const Icon(Icons.timelapse_outlined),
                      validator: (v) {
                        final value = double.tryParse(v ?? '');
                        if (value == null || value < 0) {
                          return 'Lama DM wajib diisi';
                        }
                        return null;
                      },
                    ),
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
                    const SizedBox(height: 10),
                    _ActivityLevelSelector(
                      value: _activityLevel,
                      onChanged: (v) => setState(() => _activityLevel = v),
                    ),
                  ],

                  const SizedBox(height: 20),
                  _SectionLabel(label: 'Akun'),
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: 'Kata Sandi',
                    controller: _passwordCtrl,
                    obscureText: true,
                    prefixIcon: const Icon(Icons.lock_outline),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Kata sandi wajib diisi';
                      }
                      if (v.length < 6) return 'Minimal 6 karakter';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    label: 'Konfirmasi Kata Sandi',
                    controller: _confirmPassCtrl,
                    obscureText: true,
                    prefixIcon: const Icon(Icons.lock_outline),
                    validator: (v) {
                      if (v != _passwordCtrl.text) {
                        return 'Kata sandi tidak cocok';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  CustomButton(
                    label: 'Daftar',
                    onPressed: _onRegister,
                    isLoading: auth.isLoading,
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Sudah punya akun? ',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(
                          context,
                          AppConstants.routeLogin,
                        ),
                        child: const Text('Masuk'),
                      ),
                    ],
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

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_diseaseType == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kondisi kesehatan terlebih dahulu'),
        ),
      );
      return;
    }

    // Validasi hemodialisis jika penyakit ginjal
    if (_diseaseType == DiseaseType.chronicKidneyDisease) {
      if (_hdStartDate == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tanggal mulai dialisis wajib diisi')),
        );
        return;
      }
      if (_hdEndDate == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tanggal berakhir dialisis wajib diisi'),
          ),
        );
        return;
      }
      if (_hdSelectedDays.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pilih jadwal dialisis')));
        return;
      }
      if (_hdLocationCtrl.text.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lokasi dialisis wajib diisi')),
        );
        return;
      }
    }

    final authProv = context.read<AuthProvider>();
    final diseaseProv = context.read<DiseaseProvider>();
    authProv.clearError();
    await diseaseProv.setDisease(_diseaseType!);

    // Buat HemodialysisData jika ginjal
    HemodialysisData? hemodialysisData;
    if (_diseaseType == DiseaseType.chronicKidneyDisease) {
      hemodialysisData = HemodialysisData(
        startDate: _hdStartDate!,
        endDate: _hdEndDate!,
        scheduleDays: _hdSelectedDays.toList(),
        location: _hdLocationCtrl.text.trim(),
      );
    }

    final success = await authProv.register(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      name: _nameCtrl.text.trim(),
      addressVillage: _addressVillageCtrl.text.trim(),
      addressDistrict: _addressDistrictCtrl.text.trim(),
      addressCity: _addressCityCtrl.text.trim(),
      addressProvince: _addressProvinceCtrl.text.trim(),
      education: _educationCtrl.text.trim(),
      occupation: _occupationCtrl.text.trim(),
      dateOfBirth: _dateOfBirth!,
      weight: double.parse(_weightCtrl.text),
      height: double.parse(_heightCtrl.text),
      diseaseType: _diseaseType!,
      gender: _gender,
      urinOutput: double.tryParse(_urinOutputCtrl.text) ?? 300.0,
      activityLevel: _diseaseType == DiseaseType.type2DiabetesMellitus
          ? (_activityLevel ?? ActivityLevel.ringan)
          : null,
      diabetesDurationYears:
          double.tryParse(_dmDurationCtrl.text.trim()) ?? 0.0,
      usesInsulinTherapy: _usesInsulinTherapy,
      hemodialysisData: hemodialysisData,
      hasEdema: _hasEdema,
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, AppConstants.routeMain);
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

class _UrinOutputField extends StatelessWidget {
  final TextEditingController controller;
  const _UrinOutputField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(label: 'Data Klinis Ginjal'),
        const SizedBox(height: 10),
        CustomTextField(
          label: 'Output Urin 24 Jam (ml)',
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: const Icon(Icons.water_outlined),
          validator: (v) {
            if (v == null || v.isEmpty) return null; // opsional
            final val = double.tryParse(v);
            if (val == null || val < 0 || val > 5000) {
              return 'Nilai tidak valid';
            }
            return null;
          },
        ),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Jumlah urin yang dikeluarkan dalam 24 jam terakhir. Digunakan untuk menghitung kebutuhan cairan harian. Kosongkan jika belum diketahui (default 300 ml).',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textHint,
              height: 1.5,
            ),
          ),
        ),
      ],
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

// ─── Gender Selector ──────────────────────────────────────────────────────────────

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
            value: 'laki-laki',
            selected: value == 'laki-laki',
            onTap: () => onChanged('laki-laki'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GenderOption(
            label: 'Perempuan',
            icon: Icons.female,
            value: 'perempuan',
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
  final String value;
  final bool selected;
  final VoidCallback onTap;
  const _GenderOption({
    required this.label,
    required this.icon,
    required this.value,
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

// ─── Activity Level Selector ─────────────────────────────────────────────────

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
