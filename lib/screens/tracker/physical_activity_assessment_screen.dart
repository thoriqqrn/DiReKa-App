import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/app_colors.dart';
import '../../data/mets_data.dart';
import '../../models/diabetes_health_record.dart';
import '../../services/diabetes_health_service.dart';

// ── Konstanta kalori ───────────────────────────────────────────────────────
// Estimasi berat badan default 65 kg jika tidak diketahui
const _defaultWeightKg = 65.0;

// Kalori = METs × berat (kg) × durasi (jam)
double _hitungKalori(double metsPerHour, double menit, {double kg = _defaultWeightKg}) {
  return metsPerHour * kg * (menit / 60.0);
}

// ── Intensitas dari metsPerHour ────────────────────────────────────────────
IpaqIntensity _intensitasFromMets(double metsPerHour) {
  if (metsPerHour >= 6) return IpaqIntensity.berat;
  if (metsPerHour >= 3) return IpaqIntensity.sedang;
  return IpaqIntensity.ringan;
}

Color _intensityColor(IpaqIntensity i) {
  switch (i) {
    case IpaqIntensity.berat:  return const Color(0xFFEA4335);
    case IpaqIntensity.sedang: return const Color(0xFFFBBC04);
    case IpaqIntensity.ringan: return const Color(0xFF34A853);
  }
}

Color _intensityBg(IpaqIntensity i) {
  switch (i) {
    case IpaqIntensity.berat:  return const Color(0xFFFFEBEA);
    case IpaqIntensity.sedang: return const Color(0xFFFFF9E0);
    case IpaqIntensity.ringan: return const Color(0xFFE6F9EE);
  }
}

String _intensityLabel(IpaqIntensity i) {
  switch (i) {
    case IpaqIntensity.berat:  return 'Berat';
    case IpaqIntensity.sedang: return 'Sedang';
    case IpaqIntensity.ringan: return 'Ringan';
  }
}

// ── Main Screen ────────────────────────────────────────────────────────────
class PhysicalActivityAssessmentScreen extends StatefulWidget {
  final String uid;
  final DiabetesHealthRecord? existing;
  final void Function()? onSaved;

  const PhysicalActivityAssessmentScreen({
    super.key,
    required this.uid,
    this.existing,
    this.onSaved,
  });

  @override
  State<PhysicalActivityAssessmentScreen> createState() =>
      _PhysicalActivityAssessmentScreenState();
}

class _PhysicalActivityAssessmentScreenState
    extends State<PhysicalActivityAssessmentScreen> {
  final _dateFmt = DateFormat('dd/MM/yyyy', 'id_ID');

  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  // ── Form state ─────────────────────────────────────────────────────────
  MetsActivity? _selectedActivity;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _showDropdown = false;

  int _jamCtrl = 0;
  int _menitCtrl = 0;

  // keluhan dihapus dari UI — nilai default 'Normal' tetap disimpan ke payload

  // ── Kalkulasi real-time ────────────────────────────────────────────────
  double get _totalMenitInput => _jamCtrl * 60.0 + _menitCtrl.toDouble();
  double get _metsMin =>
      _selectedActivity != null && _totalMenitInput > 0
          ? _selectedActivity!.metsPerMin * _totalMenitInput
          : 0;
  double get _kaloriEstimasi =>
      _selectedActivity != null && _totalMenitInput > 0
          ? _hitungKalori(_selectedActivity!.metsPerHour, _totalMenitInput)
          : 0;
  IpaqIntensity? get _intensitas =>
      _selectedActivity != null
          ? _intensitasFromMets(_selectedActivity!.metsPerHour)
          : null;

  // ── Filtered search list ───────────────────────────────────────────────
  List<MetsActivity> get _filteredActivities {
    final q = _searchQuery.toLowerCase().trim();
    if (q.isEmpty) return kMetsActivities;
    return kMetsActivities.where(
      (a) => a.name.toLowerCase().contains(q) ||
             a.category.toLowerCase().contains(q),
    ).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  void _loadExisting() {
    if (widget.existing == null) return;
    final p = widget.existing!.payload;
    _selectedDate = widget.existing!.date;

    final name = p['activityName']?.toString() ?? '';
    if (name.isNotEmpty) {
      _selectedActivity = findMetsActivity(name);
      _searchCtrl.text = _selectedActivity?.name ?? '';
      _searchQuery = _searchCtrl.text;
    }
    final durMenit = int.tryParse(p['duration']?.toString() ?? '0') ?? 0;
    _jamCtrl = durMenit ~/ 60;
    _menitCtrl = durMenit % 60;
    // keluhan tidak lagi digunakan di UI
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Save ───────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_selectedActivity == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pilih jenis aktivitas terlebih dahulu.'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    if (_totalMenitInput <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Masukkan durasi aktivitas.'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final metsHariIni = _metsMin;
      final kalori = _kaloriEstimasi;
      final intensitas = _intensitas!;

      // Rekap METs mingguan
      final weeklyRecords = await DiabetesHealthService.getRecords(
        widget.uid,
        fromDate: DateTime.now().subtract(const Duration(days: 6)),
      );
      double metsMingguan = metsHariIni;
      for (final r in weeklyRecords) {
        if (r.type != DiabetesInputType.aktivitas) continue;
        if (widget.existing != null &&
            r.date.year == _selectedDate.year &&
            r.date.month == _selectedDate.month &&
            r.date.day == _selectedDate.day) {
          continue;
        }
        metsMingguan +=
            double.tryParse(r.payload['totalMetsMin']?.toString() ?? '0') ?? 0;
      }

      final weeklyCategory = categorizeWeeklyMets(metsMingguan);

      final payload = <String, dynamic>{
        'activityName':    _selectedActivity!.name,
        'activityCategory': _selectedActivity!.category,
        'metsPerHour':     _selectedActivity!.metsPerHour,
        'metsPerMin':      _selectedActivity!.metsPerMin,
        'duration':        _totalMenitInput.toInt().toString(),
        'durationJam':     _jamCtrl,
        'durationMenit':   _menitCtrl,
        'totalMetsMin':    metsHariIni,
        'kalori':          kalori,
        'intensitas':      _intensityLabel(intensitas),
        'weeklyMetsMin':   metsMingguan,
        'weeklyCategory':  weeklyCategory.name,
        'keluhan':         'Normal',
        'status':          'Normal / Aman',
        'category':        weeklyCategory.label,
      };

      final record = DiabetesHealthRecord(
        id: widget.existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        type: DiabetesInputType.aktivitas,
        date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
        payload: payload,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );

      if (widget.existing != null) {
        await DiabetesHealthService.updateRecord(widget.uid, record);
      } else {
        await DiabetesHealthService.addRecord(widget.uid, record);
      }

      widget.onSaved?.call();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal menyimpan: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.existing != null ? 'Edit Aktivitas' : 'Log Aktivitas Fisik'),
        backgroundColor: AppColors.diabetesColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => setState(() => _showDropdown = false),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Tanggal ──────────────────────────────────────────────
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Tanggal Aktivitas'),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 18, color: AppColors.diabetesColor),
                          const SizedBox(width: 10),
                          Text(
                            _dateFmt.format(_selectedDate),
                            style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down,
                              color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Cari Aktivitas ───────────────────────────────────────
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Jenis Aktivitas'),
                  const SizedBox(height: 6),
                  // Search field
                  TextField(
                    controller: _searchCtrl,
                    onTap: () => setState(() => _showDropdown = true),
                    onChanged: (v) {
                      setState(() {
                        _searchQuery = v;
                        _showDropdown = true;
                        if (v.isEmpty) _selectedActivity = null;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Cari aktivitas (mis: berlari, bersepeda…)',
                      prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() {
                                _searchCtrl.clear();
                                _searchQuery = '';
                                _selectedActivity = null;
                                _showDropdown = false;
                              }),
                            )
                          : null,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                    ),
                  ),

                  // Dropdown list
                  if (_showDropdown && _filteredActivities.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: math.min(_filteredActivities.length, 40),
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final a = _filteredActivities[i];
                          final isSelected = _selectedActivity?.no == a.no;
                          return ListTile(
                            dense: true,
                            selected: isSelected,
                            selectedTileColor: AppColors.diabetesColor
                                .withValues(alpha: 0.07),
                            title: Text(a.name,
                                style: const TextStyle(fontSize: 13)),
                            subtitle: Text(
                              a.category,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: AppColors.diabetesColor, size: 18)
                                : null,
                            onTap: () => setState(() {
                              _selectedActivity = a;
                              _searchCtrl.text = a.name;
                              _searchQuery = a.name;
                              _showDropdown = false;
                            }),
                          );
                        },
                      ),
                    ),

                  if (_selectedActivity != null) ...[
                    const SizedBox(height: 12),
                    _IntensityBadge(
                        intensitas: _intensitasFromMets(
                            _selectedActivity!.metsPerHour),
                        metsValue: _selectedActivity!.metsPerHour),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Durasi Jam:Menit ────────────────────────────────────
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Durasi Aktivitas'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Jam
                      Expanded(
                        child: _DurationPicker(
                          label: 'Jam',
                          value: _jamCtrl,
                          max: 23,
                          onChanged: (v) => setState(() => _jamCtrl = v),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(':',
                            style: TextStyle(
                                fontSize: 28, fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary)),
                      ),
                      // Menit
                      Expanded(
                        child: _DurationPicker(
                          label: 'Menit',
                          value: _menitCtrl,
                          max: 59,
                          onChanged: (v) => setState(() => _menitCtrl = v),
                        ),
                      ),
                    ],
                  ),

                  // Kalkulasi real-time
                  if (_selectedActivity != null && _totalMenitInput > 0) ...[
                    const SizedBox(height: 14),
                    _CalcResultRow(
                        metsPerHour: _selectedActivity!.metsPerHour,
                        metsMin: _metsMin,
                        kalori: _kaloriEstimasi),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            const SizedBox(height: 24),

            // ── Simpan ──────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isSaving
                      ? 'Menyimpan...'
                      : widget.existing != null
                          ? 'Perbarui'
                          : 'Simpan Aktivitas',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.diabetesColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

// ── FieldLabel ─────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: AppColors.textSecondary),
      );
}

// ── Badge Intensitas Real-time ──────────────────────────────────────────────
class _IntensityBadge extends StatelessWidget {
  final IpaqIntensity intensitas;
  final double metsValue; // nilai METs ketetapan (tidak berubah)

  const _IntensityBadge({required this.intensitas, required this.metsValue});

  @override
  Widget build(BuildContext context) {
    final color = _intensityColor(intensitas);
    final bg = _intensityBg(intensitas);
    final label = _intensityLabel(intensitas);

    IconData icon;
    String desc;
    switch (intensitas) {
      case IpaqIntensity.ringan:
        icon = Icons.directions_walk;
        desc = 'Aktivitas ringan, napas normal';
        break;
      case IpaqIntensity.sedang:
        icon = Icons.directions_bike;
        desc = 'Aktivitas sedang, napas sedikit cepat';
        break;
      case IpaqIntensity.berat:
        icon = Icons.fitness_center;
        desc = 'Aktivitas berat, napas jauh lebih cepat';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Intensitas ',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(label,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                    const Spacer(),
                    // Nilai METs ketetapan — tidak berubah berapapun durasi
                    Text(
                      'METs: ${metsValue % 1 == 0 ? metsValue.toInt() : metsValue}',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(desc,
                    style: TextStyle(
                        fontSize: 11, color: color,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Duration Picker (spinner-style) ────────────────────────────────────────
class _DurationPicker extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final void Function(int) onChanged;

  const _DurationPicker({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // +
              InkWell(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(7)),
                onTap: () {
                  if (value < max) onChanged(value + 1);
                },
                child: const SizedBox(
                  height: 36, width: double.infinity,
                  child: Icon(Icons.keyboard_arrow_up_rounded,
                      color: AppColors.diabetesColor),
                ),
              ),
              const Divider(height: 1),
              // value
              Container(
                height: 44,
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () => _showNumberInput(context),
                  child: Text(
                    value.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                  ),
                ),
              ),
              const Divider(height: 1),
              // -
              InkWell(
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(7)),
                onTap: () {
                  if (value > 0) onChanged(value - 1);
                },
                child: const SizedBox(
                  height: 36, width: double.infinity,
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.diabetesColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showNumberInput(BuildContext context) {
    final ctrl = TextEditingController(text: value.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Masukkan $label'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: '0 – $max',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text) ?? 0;
              onChanged(v.clamp(0, max));
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ── Real-time Calc Row ──────────────────────────────────────────────────────
class _CalcResultRow extends StatelessWidget {
  final double metsPerHour; // nilai METs ketetapan aktivitas (tidak berubah)
  final double metsMin;     // METs × durasi (berubah sesuai durasi)
  final double kalori;

  const _CalcResultRow({
    required this.metsPerHour,
    required this.metsMin,
    required this.kalori,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.diabetesColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppColors.diabetesColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _CalcChip(
                  icon: Icons.bolt,
                  label: 'Total METs-menit',
                  sublabel: '(METs × durasi)',
                  value: metsMin.toStringAsFixed(1),
                  color: AppColors.diabetesColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CalcChip(
                  icon: Icons.local_fire_department,
                  label: 'Est. Kalori Terbakar',
                  sublabel: '(METs × BB × durasi jam)',
                  value: '${kalori.toStringAsFixed(0)} kkal',
                  color: Colors.deepOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalcChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final String value;
  final Color color;

  const _CalcChip({
    required this.icon, required this.label,
    this.sublabel,
    required this.value, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary)),
        if (sublabel != null)
          Text(sublabel!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 9, color: AppColors.textHint)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WEEKLY SUMMARY WIDGET — dipanggil dari health_tracker_screen.dart
// ════════════════════════════════════════════════════════════════════════════
class DmActivityWeeklySummary extends StatelessWidget {
  final List<DiabetesHealthRecord> weeklyRecords;
  final DateTime? startDate;

  const DmActivityWeeklySummary({
    super.key,
    required this.weeklyRecords,
    this.startDate,
  });

  @override
  Widget build(BuildContext context) {
    // Bangun peta hari (Sabtu = start siklus)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Kalau parent memberi rentang minggu, pakai itu. Jika tidak, fallback ke minggu berjalan.
    final startOfCycle = startDate ?? _lastSaturday(today);
    final endOfCycle = startOfCycle.add(const Duration(days: 6));
    final rangeLabel = '${DateFormat('d MMM', 'id_ID').format(startOfCycle)} - '
        '${DateFormat('d MMM yyyy', 'id_ID').format(endOfCycle)}';

    // 7 hari dari Sabtu
    final days = List.generate(7, (i) => startOfCycle.add(Duration(days: i)));
    final dayLabels = ['Sab', 'Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum'];

    // Map date → record (ambil yang paling baru per hari)
    final Map<String, DiabetesHealthRecord> dayMap = {};
    for (final r in weeklyRecords) {
      final key = '${r.date.year}-${r.date.month}-${r.date.day}';
      dayMap[key] = r;
    }

    // Hitung ringkasan
    int hariBerat = 0, hariSedang = 0;
    double totalKalori = 0, totalMetsMin = 0;

    for (final r in weeklyRecords) {
      final intStr = r.payload['intensitas']?.toString() ?? '';
      if (intStr == 'Berat') hariBerat++;
      else if (intStr == 'Sedang') hariSedang++;
      totalKalori +=
          double.tryParse(r.payload['kalori']?.toString() ?? '0') ?? 0;
      totalMetsMin +=
          double.tryParse(r.payload['totalMetsMin']?.toString() ?? '0') ?? 0;
    }

    final weeklyCategory = categorizeWeeklyMets(totalMetsMin);
    final catColor = _categoryColor(weeklyCategory);
    final progress = (totalMetsMin / 3000).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.calendar_view_week,
                    color: AppColors.diabetesColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rekapan Mingguan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        rangeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      weeklyCategory.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: catColor),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Timeline 7 Bulatan ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final day = days[i];
                final key = '${day.year}-${day.month}-${day.day}';
                final rec = dayMap[key];
                final isToday = day == today;
                final isFuture = day.isAfter(today);

                Color dotColor;
                Color dotBorder;
                Widget? dotChild;
                String? tooltipText;

                if (isFuture) {
                  dotColor = Colors.transparent;
                  dotBorder = AppColors.border;
                } else if (rec == null) {
                  dotColor = const Color(0xFFE0E0E0);
                  dotBorder = const Color(0xFFBDBDBD);
                  tooltipText = 'Tidak ada data';
                } else {
                  final intStr = rec.payload['intensitas']?.toString() ?? '';
                  switch (intStr) {
                    case 'Berat':
                      dotColor = const Color(0xFFEA4335);
                      dotBorder = const Color(0xFFC62828);
                      break;
                    case 'Sedang':
                      dotColor = const Color(0xFFFBBC04);
                      dotBorder = const Color(0xFFF9A825);
                      break;
                    default:
                      dotColor = const Color(0xFF34A853);
                      dotBorder = const Color(0xFF2E7D32);
                  }
                  tooltipText = rec.payload['activityName']?.toString();
                }

                if (!isFuture && rec != null) {
                  dotChild = const Icon(Icons.check, color: Colors.white, size: 12);
                }

                return Column(
                  children: [
                    Tooltip(
                      message: tooltipText ?? '',
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isToday ? 38 : 32,
                        height: isToday ? 38 : 32,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: isToday
                                  ? AppColors.diabetesColor
                                  : dotBorder,
                              width: isToday ? 2.5 : 1.5),
                          boxShadow: isToday
                              ? [
                                  BoxShadow(
                                    color: AppColors.diabetesColor
                                        .withValues(alpha: 0.3),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                        child: dotChild,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dayLabels[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday
                            ? AppColors.diabetesColor
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (isToday)
                      Container(
                        width: 4, height: 4,
                        decoration: const BoxDecoration(
                          color: AppColors.diabetesColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 4),

          // Legenda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _Dot(color: const Color(0xFF34A853), label: 'Ringan'),
                const SizedBox(width: 10),
                _Dot(color: const Color(0xFFFBBC04), label: 'Sedang'),
                const SizedBox(width: 10),
                _Dot(color: const Color(0xFFEA4335), label: 'Berat'),
                const SizedBox(width: 10),
                _Dot(color: const Color(0xFFE0E0E0), label: 'Tidak ada'),
              ],
            ),
          ),

          const Divider(height: 20),

          // ── Ringkasan Performa ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _SummaryTile(
                  label: 'Hari Berat',
                  value: '$hariBerat hari',
                  color: const Color(0xFFEA4335),
                  icon: Icons.fitness_center,
                ),
                _SummaryTile(
                  label: 'Hari Sedang',
                  value: '$hariSedang hari',
                  color: const Color(0xFFF9A825),
                  icon: Icons.directions_bike,
                ),
                _SummaryTile(
                  label: 'Total Kalori',
                  value: '${totalKalori.toStringAsFixed(0)} kkal',
                  color: Colors.deepOrange,
                  icon: Icons.local_fire_department,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Skor total METs + Progress ─────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt,
                            size: 16, color: AppColors.diabetesColor),
                        const SizedBox(width: 4),
                        const Text('Total MET-min Minggu Ini',
                            style: TextStyle(fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                    Text(
                      '${totalMetsMin.toStringAsFixed(0)} / 3.000',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: catColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(catColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _categoryHint(weeklyCategory),
                  style: TextStyle(
                      fontSize: 11, color: catColor,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  DateTime _lastSaturday(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final daysFromSaturday = d.weekday == DateTime.saturday
        ? 0
        : d.weekday == DateTime.sunday
            ? 1
            : d.weekday + 1;
    return d.subtract(Duration(days: daysFromSaturday));
  }

  Color _categoryColor(PhysicalActivityCategory c) {
    switch (c) {
      case PhysicalActivityCategory.rendah:  return AppColors.error;
      case PhysicalActivityCategory.sedang:  return AppColors.warning;
      case PhysicalActivityCategory.tinggi:  return AppColors.success;
    }
  }

  String _categoryHint(PhysicalActivityCategory c) {
    switch (c) {
      case PhysicalActivityCategory.rendah:
        return 'Kurang aktif — tingkatkan aktivitas harian Anda!';
      case PhysicalActivityCategory.sedang:
        return 'Cukup aktif — pertahankan dan tambah sedikit lagi!';
      case PhysicalActivityCategory.tinggi:
        return 'Sangat aktif — bagus untuk kontrol gula darah!';
    }
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final String label;
  const _Dot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(
                fontSize: 9, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryTile({
    required this.label, required this.value,
    required this.color, required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
