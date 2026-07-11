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
  final _heartDurationCtrl = TextEditingController();
  final _insulinDurationCtrl = TextEditingController();
  final _htDurationCtrl = TextEditingController(); // Hipertensi

  DateTime? _dateOfBirth;
  DiseaseType? _diseaseType;
  String _gender = 'laki-laki';
  ActivityLevel? _activityLevel;
  bool _usesInsulinTherapy = false;
  bool _hasEdema = false; // riwayat pembengkakan — untuk pasien Jantung Koroner
  // Hipertensi
  bool _hypertensionFamilyHistory = false;
  bool _hypertensionRoutineMeds = false;
  bool _isPregnant = false;
  int _pregnancyTrimester = 1;

  // Hemodialisis — untuk pasien penyakit ginjal
  DateTime? _hdStartDate;
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
    _heartDurationCtrl.dispose();
    _insulinDurationCtrl.dispose();
    _htDurationCtrl.dispose();
    _hdLocationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LoadingOverlay(
      isLoading: auth.isLoading,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Daftar Akun'),
          backgroundColor: theme.scaffoldBackgroundColor,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -70,
                left: -30,
                child: _AuthBackdropBlob(
                  size: 200,
                  color: theme.colorScheme.primary.withValues(
                    alpha: isDark ? 0.18 : 0.12,
                  ),
                ),
              ),
              Positioned(
                top: 180,
                right: -40,
                child: _AuthBackdropBlob(
                  size: 160,
                  color: theme.colorScheme.secondary.withValues(
                    alpha: isDark ? 0.16 : 0.10,
                  ),
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: _AnimatedPulseIcon(),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Buat Akun Baru',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.titleLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Lengkapi data diri Anda untuk melanjutkan.',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.hintColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: theme.dividerColor.withValues(
                              alpha: isDark ? 0.55 : 0.20,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.18 : 0.06,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

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

                  // Pertanyaan pembengkakan — hanya untuk pasien Jantung Koroner
                  if (_diseaseType == DiseaseType.heartFailure) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(
                          alpha: theme.brightness == Brightness.dark
                              ? 0.12
                              : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withValues(
                            alpha: theme.brightness == Brightness.dark
                                ? 0.35
                                : 0.22,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Apakah ada riwayat pembengkakan?',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: theme.textTheme.bodyLarge?.color,
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
                          color: theme.cardTheme.color,
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tanggal Mulai',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.hintColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _hdStartDate != null
                                      ? DateFormat(
                                          'MMMM yyyy', // Hanya bulan dan tahun
                                          'id_ID',
                                        ).format(_hdStartDate!)
                                      : 'Pilih bulan & tahun',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.calendar_today_outlined,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // (Tanggal berakhir dihapus sesuai requirement)
                    const SizedBox(height: 14),
                    Text(
                      'Jadwal Dialisis (Bisa pilih lebih dari satu)',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.hintColor,
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
                              } else {
                                _hdSelectedDays.add(day);
                              }
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : theme.cardTheme.color,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : theme.dividerColor,
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
                                      : theme.textTheme.bodyLarge?.color,
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

                  // Field aktivitas — untuk pasien DM & Jantung Koroner & Hipertensi
                  if (_diseaseType == DiseaseType.type2DiabetesMellitus ||
                      _diseaseType == DiseaseType.heartFailure ||
                      _diseaseType == DiseaseType.hypertension) ...[
                    const SizedBox(height: 20),
                    _SectionLabel(
                      label:
                          _diseaseType == DiseaseType.type2DiabetesMellitus
                              ? 'Data Klinis Diabetes'
                              : _diseaseType == DiseaseType.hypertension
                                  ? 'Data Klinis Hipertensi'
                                  : 'Data Klinis Jantung Koroner (tahun)',
                    ),
                    const SizedBox(height: 10),
                    CustomTextField(
                      label:
                          _diseaseType == DiseaseType.type2DiabetesMellitus
                              ? 'Lama menderita DM (tahun)'
                              : _diseaseType == DiseaseType.hypertension
                                  ? 'Lama menderita hipertensi (tahun)'
                                  : 'Lama menderita Jantung Koroner (tahun)',
                      controller:
                          _diseaseType == DiseaseType.type2DiabetesMellitus
                              ? _dmDurationCtrl
                              : _diseaseType == DiseaseType.hypertension
                                  ? _htDurationCtrl
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
                    // Blok khusus Hipertensi
                    if (_diseaseType == DiseaseType.hypertension) ...[
                      const SizedBox(height: 16),
                      const _SectionLabel(label: 'Riwayat Hipertensi'),
                      const SizedBox(height: 10),
                      _HypertensionToggleCard(
                        title: 'Riwayat hipertensi dari keluarga?',
                        value: _hypertensionFamilyHistory,
                        onChanged: (v) => setState(() => _hypertensionFamilyHistory = v),
                      ),
                      const SizedBox(height: 10),
                      _HypertensionToggleCard(
                        title: 'Rutin konsumsi obat hipertensi harian?',
                        value: _hypertensionRoutineMeds,
                        onChanged: (v) => setState(() => _hypertensionRoutineMeds = v),
                      ),
                      if (_gender == 'perempuan') ...[
                        const SizedBox(height: 10),
                        _HypertensionToggleCard(
                          title: 'Sedang hamil?',
                          value: _isPregnant,
                          onChanged: (v) => setState(() { _isPregnant = v; if (!v) _pregnancyTrimester = 1; }),
                        ),
                        if (_isPregnant) ...[
                          const SizedBox(height: 10),
                          const Text('Trimester kehamilan:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Row(
                            children: [1, 2, 3].map((t) {
                              final sel = _pregnancyTrimester == t;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _pregnancyTrimester = t),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: sel ? AppColors.primary.withValues(alpha: 0.12) : null,
                                      border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 1.5 : 1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(child: Text('Trimester $t', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? AppColors.primary : null))),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ],
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 2,
                        children: [
                          Text(
                            'Sudah punya akun?',
                            style: TextStyle(color: theme.hintColor),
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
            ],
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
      // endDate removed
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
      activityLevel: (_diseaseType == DiseaseType.type2DiabetesMellitus ||
              _diseaseType == DiseaseType.heartFailure ||
              _diseaseType == DiseaseType.hypertension)
          ? (_activityLevel ?? ActivityLevel.lansiaPekerjaKantor)
          : null,
      diabetesDurationYears:
          double.tryParse(_dmDurationCtrl.text.trim()) ?? 0.0,
      heartDiseaseDurationYears:
          double.tryParse(_heartDurationCtrl.text.trim()) ?? 0.0,
      usesInsulinTherapy: _usesInsulinTherapy,
      insulinDurationYears: _usesInsulinTherapy
          ? (double.tryParse(_insulinDurationCtrl.text.trim()) ?? 0.0)
          : 0.0,
      hemodialysisData: hemodialysisData,
      hasEdema: _hasEdema,
      hypertensionDurationYears: double.tryParse(_htDurationCtrl.text.trim()) ?? 0.0,
      hypertensionFamilyHistory: _hypertensionFamilyHistory,
      hypertensionRoutineMeds: _hypertensionRoutineMeds,
      isPregnant: _gender == 'perempuan' ? _isPregnant : false,
      pregnancyTrimester: (_gender == 'perempuan' && _isPregnant) ? _pregnancyTrimester : 0,
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
    final theme = Theme.of(context);
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: theme.hintColor,
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
    final theme = Theme.of(context);
    return DropdownButtonFormField<DiseaseType>(
      initialValue: value,
      isExpanded: true,
      menuMaxHeight: 320,
      decoration: InputDecoration(
        labelText: 'Kondisi Penyakit',
        prefixIcon: const Icon(Icons.medical_services_outlined),
        filled: true,
        fillColor: theme.inputDecorationTheme.fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      items: DiseaseType.values
          .map(
            (d) => DropdownMenuItem(
              value: d,
              child: Text(
                d.label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          )
          .toList(),
      selectedItemBuilder: (context) => DiseaseType.values
          .map(
            (d) => Align(
              alignment: Alignment.centerLeft,
              child: Text(
                d.label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          )
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
    final theme = Theme.of(context);
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
          child: SizedBox.shrink(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Jumlah urin yang dikeluarkan dalam 24 jam terakhir. Digunakan untuk menghitung kebutuhan cairan harian. Kosongkan jika belum diketahui (default 300 ml).',
            style: TextStyle(
              fontSize: 11,
              color: theme.hintColor,
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
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'IMT: ${bmi.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _color,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '($_category)',
                  style: TextStyle(color: _color, fontSize: 13),
                ),
              ],
            ),
          ),
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
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : theme.cardTheme.color,
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
              color: selected ? AppColors.primary : theme.hintColor,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected
                      ? AppColors.primary
                      : theme.textTheme.bodyLarge?.color,
                ),
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
    final theme = Theme.of(context);
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
                  : theme.cardTheme.color,
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
                              : theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      Text(
                        level.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.hintColor,
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

class _AnimatedPulseIcon extends StatefulWidget {
  const _AnimatedPulseIcon();

  @override
  State<_AnimatedPulseIcon> createState() => _AnimatedPulseIconState();
}

class _AnimatedPulseIconState extends State<_AnimatedPulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ScaleTransition(
      scale: _animation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.14),
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.24),
            width: 2,
          ),
        ),
        child: Icon(
          Icons.monitor_heart_rounded,
          size: 40,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _AuthBackdropBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _AuthBackdropBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _HypertensionToggleCard extends StatelessWidget {
  final String title;
  final bool value;
  final void Function(bool) onChanged;
  const _HypertensionToggleCard({required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: value
            ? AppColors.primary.withValues(alpha: 0.07)
            : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? AppColors.primary.withValues(alpha: 0.35)
              : theme.dividerColor,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value ? 'Ya' : 'Tidak',
                  style: TextStyle(
                    fontSize: 13,
                    color: value ? AppColors.primary : theme.hintColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
