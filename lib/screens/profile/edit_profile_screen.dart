import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/activity_level.dart';
import '../../models/disease_type.dart';
import '../../models/hemodialysis_data.dart';
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
  final _addressVillageCtrl = TextEditingController();
  final _addressDistrictCtrl = TextEditingController();
  final _addressCityCtrl = TextEditingController();
  final _addressProvinceCtrl = TextEditingController();
  final _educationCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _urinOutputCtrl = TextEditingController();
  final _dmDurationCtrl = TextEditingController();
  final _heartDurationCtrl = TextEditingController();
  final _insulinDurationCtrl = TextEditingController();
  final _htDurationCtrl = TextEditingController();

  DateTime? _dateOfBirth;
  DiseaseType? _diseaseType;
  String _gender = 'laki-laki';
  ActivityLevel? _activityLevel;
  bool _usesInsulinTherapy = false;

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
        _addressVillageCtrl.text = user.addressVillage;
        _addressDistrictCtrl.text = user.addressDistrict;
        _addressCityCtrl.text = user.addressCity;
        _addressProvinceCtrl.text = user.addressProvince;
        _educationCtrl.text = user.education;
        _occupationCtrl.text = user.occupation;
        _weightCtrl.text = user.weight.toString();
        _heightCtrl.text = user.height.toString();
        _urinOutputCtrl.text = user.urinOutput > 0
            ? user.urinOutput.toStringAsFixed(0)
            : '';
        _dmDurationCtrl.text = user.diabetesDurationYears > 0
            ? user.diabetesDurationYears.toString()
            : '';
        _heartDurationCtrl.text = user.heartDiseaseDurationYears > 0
            ? user.heartDiseaseDurationYears.toString()
            : '';
        _insulinDurationCtrl.text = user.insulinDurationYears > 0
            ? user.insulinDurationYears.toString()
            : '';
        _htDurationCtrl.text = user.hypertensionDurationYears > 0
            ? user.hypertensionDurationYears.toString()
            : '';
        _dateOfBirth = user.dateOfBirth;
        _diseaseType = user.diseaseType;
        _gender = user.gender;
        _activityLevel = user.activityLevel;
        _usesInsulinTherapy = user.usesInsulinTherapy;
        _hypertensionFamilyHistory = user.hypertensionFamilyHistory;
        _hypertensionRoutineMeds = user.hypertensionRoutineMeds;
        _isPregnant = user.isPregnant;
        _pregnancyTrimester = user.pregnancyTrimester > 0 ? user.pregnancyTrimester : 1;

        // Load hemodialysis data jika ada
        if (user.hemodialysisData != null) {
          final hd = user.hemodialysisData!;
          _hdStartDate = hd.startDate;
          _hdSelectedDays.addAll(hd.scheduleDays);
          _hdLocationCtrl.text = hd.location;
        }
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
    _addressVillageCtrl.dispose();
    _addressDistrictCtrl.dispose();
    _addressCityCtrl.dispose();
    _addressProvinceCtrl.dispose();
    _educationCtrl.dispose();
    _occupationCtrl.dispose();
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

    return LoadingOverlay(
      isLoading: auth.isLoading,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
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

                  // Gender
                  _GenderSelector(
                    value: _gender,
                    onChanged: (v) => setState(() => _gender = v),
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
                                    style: TextStyle(
                                      color: theme.primaryColor,
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

                  // Field urin output — hanya untuk pasien ginjal
                  if (_diseaseType == DiseaseType.chronicKidneyDisease) ...[
                    const SizedBox(height: 20),
                    _SectionLabel(label: 'Data Klinis Ginjal'),
                    const SizedBox(height: 10),
                    CustomTextField(
                      label: 'Output Urin 24 Jam (ml)',
                      controller: _urinOutputCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefixIcon: const Icon(Icons.water_outlined),
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        final val = double.tryParse(v);
                        if (val == null || val < 0 || val > 5000) {
                          return 'Nilai tidak valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Jumlah urin 24 jam terakhir. Mempengaruhi target cairan harian. Kosongkan jika belum diketahui.',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.hintColor,
                          height: 1.5,
                        ),
                      ),
                    ),
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
                          initialDate: _hdStartDate ?? DateTime.now(),
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
                          color: theme.cardTheme.color ?? theme.cardColor,
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
                                  'Bulan Mulai',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.hintColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _hdStartDate != null
                                      ? DateFormat(
                                          'MMMM yyyy',
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
                              color: theme.primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Tanggal berakhir dihapus
                    const SizedBox(height: 14),
                    Text(
                      'Jadwal Dialisis',
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
                                  : (theme.cardTheme.color ?? theme.cardColor),
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
                                      : (theme.textTheme.bodyLarge?.color ??
                                          AppColors.textPrimary),
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
                    ),
                  ],

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
                    _ActivityLevelSelector(
                      value: _activityLevel,
                      onChanged: (v) => setState(() => _activityLevel = v),
                    ),
                  ],

                  // Hipertensi section
                  if (_diseaseType == DiseaseType.hypertension) ...[
                    const SizedBox(height: 20),
                    _SectionLabel(label: 'Data Klinis Hipertensi'),
                    const SizedBox(height: 10),
                    CustomTextField(
                      label: 'Lama menderita hipertensi (tahun)',
                      controller: _htDurationCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefixIcon: const Icon(Icons.timelapse_outlined),
                      validator: (v) {
                        final value = double.tryParse(v ?? '');
                        if (value == null || value < 0) {
                          return 'Lama hipertensi wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: _hypertensionFamilyHistory,
                      onChanged: (val) =>
                          setState(() => _hypertensionFamilyHistory = val),
                      title: const Text('Riwayat hipertensi keluarga'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile.adaptive(
                      value: _hypertensionRoutineMeds,
                      onChanged: (val) =>
                          setState(() => _hypertensionRoutineMeds = val),
                      title: const Text('Rutin konsumsi obat hipertensi'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_gender == 'perempuan') ...[
                      SwitchListTile.adaptive(
                        value: _isPregnant,
                        onChanged: (val) => setState(() {
                          _isPregnant = val;
                          if (!val) _pregnancyTrimester = 1;
                        }),
                        title: const Text('Sedang hamil'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_isPregnant) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Trimester kehamilan',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [1, 2, 3].map((t) {
                            final sel = _pregnancyTrimester == t;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _pregnancyTrimester = t),
                                child: Container(
                                  margin: EdgeInsets.only(right: t < 3 ? 8 : 0),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? AppColors.primary.withValues(
                                            alpha: 0.1,
                                          )
                                        : (theme.cardTheme.color ??
                                            theme.cardColor),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: sel
                                          ? AppColors.primary
                                          : theme.dividerColor,
                                      width: sel ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Trimester $t',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: sel
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: sel
                                            ? AppColors.primary
                                            : (theme.textTheme.bodyMedium
                                                    ?.color ??
                                                AppColors.textSecondary),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                    const SizedBox(height: 10),
                    _ActivityLevelSelector(
                      value: _activityLevel,
                      onChanged: (v) => setState(() => _activityLevel = v),
                    ),
                  ],

                  const SizedBox(height: 20),
                  _SectionLabel(label: 'Kondisi Kesehatan'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color ?? theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.medical_services_outlined,
                          color: theme.hintColor,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _diseaseType?.label ?? '-',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Kondisi penyakit tidak dapat diubah',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.hintColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: theme.hintColor,
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

    // Buat HemodialysisData jika ginjal dan semua field terisi
    HemodialysisData? hemodialysisData;
    if (_diseaseType == DiseaseType.chronicKidneyDisease &&
        _hdStartDate != null &&
        _hdSelectedDays.isNotEmpty &&
        _hdLocationCtrl.text.isNotEmpty) {
      hemodialysisData = HemodialysisData(
        startDate: _hdStartDate!,
        scheduleDays: _hdSelectedDays.toList(),
        location: _hdLocationCtrl.text.trim(),
      );
    }

    final updated = currentUser.copyWith(
      name: _nameCtrl.text.trim(),
      addressVillage: _addressVillageCtrl.text.trim(),
      addressDistrict: _addressDistrictCtrl.text.trim(),
      addressCity: _addressCityCtrl.text.trim(),
      addressProvince: _addressProvinceCtrl.text.trim(),
      education: _educationCtrl.text.trim(),
      occupation: _occupationCtrl.text.trim(),
      dateOfBirth: _dateOfBirth,
      weight: double.parse(_weightCtrl.text),
      height: double.parse(_heightCtrl.text),
      gender: _gender,
      urinOutput:
          double.tryParse(_urinOutputCtrl.text) ?? currentUser.urinOutput,
      activityLevel: (_diseaseType == DiseaseType.type2DiabetesMellitus ||
              _diseaseType == DiseaseType.heartFailure ||
              _diseaseType == DiseaseType.hypertension)
          ? (_activityLevel ?? ActivityLevel.lansiaPekerjaKantor)
          : null,
      diabetesDurationYears:
          double.tryParse(_dmDurationCtrl.text.trim()) ??
              currentUser.diabetesDurationYears,
      heartDiseaseDurationYears:
          double.tryParse(_heartDurationCtrl.text.trim()) ??
              currentUser.heartDiseaseDurationYears,
      usesInsulinTherapy: _usesInsulinTherapy,
      insulinDurationYears: _usesInsulinTherapy
          ? (double.tryParse(_insulinDurationCtrl.text.trim()) ?? 0.0)
          : 0.0,
      clearActivityLevel: !(_diseaseType == DiseaseType.type2DiabetesMellitus ||
          _diseaseType == DiseaseType.heartFailure ||
          _diseaseType == DiseaseType.hypertension),
      hemodialysisData: hemodialysisData,
      clearHemodialysisData: _diseaseType != DiseaseType.chronicKidneyDisease,
      hypertensionDurationYears: _diseaseType == DiseaseType.hypertension
          ? (double.tryParse(_htDurationCtrl.text.trim()) ??
              currentUser.hypertensionDurationYears)
          : currentUser.hypertensionDurationYears,
      hypertensionFamilyHistory: _hypertensionFamilyHistory,
      hypertensionRoutineMeds: _hypertensionRoutineMeds,
      isPregnant: _isPregnant && _gender == 'perempuan',
      pregnancyTrimester:
          (_isPregnant && _gender == 'perempuan') ? _pregnancyTrimester : 0,
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

class _BmiInfo extends StatelessWidget {
  final double bmi;
  const _BmiInfo({required this.bmi});

  String get _category {
    if (bmi < 18.5) return 'Berat Badan Kurang';
    if (bmi < 23.0) return 'Normal';
    if (bmi < 30.0) return 'Berat Badan Berlebih';
    return 'Obesitas';
  }

  Color get _color {
    if (bmi < 18.5) return Colors.blue;
    if (bmi < 23.0) return AppColors.success;
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
              : (theme.cardTheme.color ?? theme.cardColor),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : theme.dividerColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? AppColors.primary
                  : (theme.textTheme.bodyMedium?.color ??
                      AppColors.textSecondary),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? AppColors.primary
                    : (theme.textTheme.bodyMedium?.color ??
                        AppColors.textSecondary),
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
                  : (theme.cardTheme.color ?? theme.cardColor),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel ? AppColors.diabetesColor : theme.dividerColor,
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
                      color: sel ? AppColors.diabetesColor : theme.dividerColor,
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
                              : (theme.textTheme.bodyLarge?.color ??
                                  AppColors.textPrimary),
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
