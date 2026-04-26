import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../models/diabetes_health_record.dart';
import '../../models/disease_type.dart';
import '../../models/food_log_entry.dart';
import '../../models/heart_health_record.dart';
import '../../models/kidney_health_record.dart';
import '../../models/meal_type.dart';
import '../../providers/auth_provider.dart';
import '../../providers/disease_provider.dart';
import '../../services/diabetes_health_service.dart';
import '../../services/food_log_service.dart';
import '../../services/app_notification_service.dart';
import '../../services/heart_health_service.dart';
import '../../services/kidney_health_service.dart';

class HealthTrackerScreen extends StatefulWidget {
  const HealthTrackerScreen({super.key});

  @override
  State<HealthTrackerScreen> createState() => _HealthTrackerScreenState();
}

class _HealthTrackerScreenState extends State<HealthTrackerScreen> {
  final DateFormat _dateFmt = DateFormat('d MMM yyyy', 'id_ID');

  static const List<String> _activityOptions = [
    'Senam',
    'Jalan cepat',
    'Bersepeda',
    'Berenang',
    'Jogging/Lari',
    'Memasak',
    'Pekerjaan rumah tangga',
    'Berkebun',
    'Lainnya',
  ];
  static const List<String> _activityComplaintOptions = [
    'Normal',
    'Sesak nafas/terengah-engah',
    'Pusing',
    'Mata berkunang',
    'Kelelahan',
    'Gemetar',
    'Keringat dingin',
    'Nyeri dada',
  ];

  List<KidneyHealthRecord> _records = [];
  List<HeartHealthRecord> _heartRecords = [];
  List<DiabetesHealthRecord> _dmRecords = [];
  bool _isLoading = true;
  bool _isHeartLoading = true;
  bool _isDmLoading = true;
  String? _error;
  String? _heartError;
  String? _dmError;

  bool _canSubmitHealthInput() {
    if (_uid.isNotEmpty) return true;
    _showLoginRequired();
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _loadHeartRecords();
    _loadDmRecords();
  }

  String get _uid {
    final auth = context.read<AuthProvider>();
    return auth.currentUser?.uid ?? auth.firebaseUser?.uid ?? '';
  }

  Future<void> _loadRecords() async {
    if (_uid.isEmpty) {
      if (mounted) {
        setState(() {
          _records = [];
          _isLoading = false;
          _error = null;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fromDate = DateTime.now().subtract(const Duration(days: 31));
      final records = await KidneyHealthService.getRecords(
        _uid,
        fromDate: fromDate,
      );
      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error =
              'Data kesehatan belum bisa dimuat. Cek izin Firestore lalu coba lagi.';
        });
      }
    }
  }

  Future<void> _loadHeartRecords() async {
    if (_uid.isEmpty) {
      if (mounted) {
        setState(() {
          _heartRecords = [];
          _isHeartLoading = false;
          _heartError = null;
        });
      }
      return;
    }

    setState(() {
      _isHeartLoading = true;
      _heartError = null;
    });

    try {
      final fromDate = DateTime.now().subtract(const Duration(days: 45));
      final records = await HeartHealthService.getRecords(
        _uid,
        fromDate: fromDate,
      );
      if (mounted) {
        setState(() {
          _heartRecords = records;
          _isHeartLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isHeartLoading = false;
          _heartError =
              'Data jantung belum bisa dimuat. Cek izin Firestore lalu coba lagi.';
        });
      }
    }
  }

  Future<void> _loadDmRecords() async {
    if (_uid.isEmpty) {
      if (mounted) {
        setState(() {
          _dmRecords = [];
          _isDmLoading = false;
          _dmError = null;
        });
      }
      return;
    }

    setState(() {
      _isDmLoading = true;
      _dmError = null;
    });

    try {
      final fromDate = DateTime.now().subtract(const Duration(days: 60));
      final records = await DiabetesHealthService.getRecords(
        _uid,
        fromDate: fromDate,
      );
      if (mounted) {
        setState(() {
          _dmRecords = records;
          _isDmLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isDmLoading = false;
          _dmError =
              'Data diabetes belum bisa dimuat. Cek izin Firestore lalu coba lagi.';
        });
      }
    }
  }

  Future<void> _addRecord(KidneyHealthRecord record) async {
    if (!_canSubmitHealthInput()) return;
    try {
      await KidneyHealthService.addRecord(_uid, record);
      if (mounted) {
        final auth = context.read<AuthProvider>();
        auth.updateActivityStreak();
        if (auth.currentUser != null) {
          AppNotificationService.refreshForUser(auth.currentUser!);
        }
      }
      await _loadRecords();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan data. Periksa koneksi/izin akses.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _updateRecord(KidneyHealthRecord record) async {
    if (!_canSubmitHealthInput()) return;
    try {
      await KidneyHealthService.updateRecord(_uid, record);
      await _loadRecords();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memperbarui data.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteRecord(KidneyHealthRecord record) async {
    if (!_canSubmitHealthInput()) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus data'),
        content: const Text('Yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await KidneyHealthService.deleteRecord(_uid, record.id);
      await _loadRecords();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menghapus data.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editRecord(KidneyHealthRecord record) async {
    KidneyHealthRecord? updated;
    switch (record.type) {
      case KidneyInputType.hemodialisa:
        updated = await _showHemodialysisDialog(existing: record);
        break;
      case KidneyInputType.obat:
        updated = await _showMedicationDialog(existing: record);
        break;
      case KidneyInputType.gejala:
        updated = await _showSymptomDialog(existing: record);
        break;
      case KidneyInputType.pemeriksaan:
        updated = await _showCheckupDialog(existing: record);
        break;
    }

    if (updated != null) {
      await _updateRecord(updated);
    }
  }

  Future<void> _addHeartRecord(HeartHealthRecord record) async {
    if (!_canSubmitHealthInput()) return;
    try {
      await HeartHealthService.addRecord(_uid, record);
      if (mounted) {
        final auth = context.read<AuthProvider>();
        auth.updateActivityStreak();
        if (auth.currentUser != null) {
          AppNotificationService.refreshForUser(auth.currentUser!);
        }
      }
      await _loadHeartRecords();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan data jantung.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _updateHeartRecord(HeartHealthRecord record) async {
    if (!_canSubmitHealthInput()) return;
    try {
      await HeartHealthService.updateRecord(_uid, record);
      await _loadHeartRecords();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memperbarui data jantung.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteHeartRecord(HeartHealthRecord record) async {
    if (!_canSubmitHealthInput()) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus data'),
        content: const Text('Yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await HeartHealthService.deleteRecord(_uid, record.id);
      await _loadHeartRecords();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menghapus data jantung.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editHeartRecord(HeartHealthRecord record) async {
    HeartHealthRecord? updated;
    switch (record.type) {
      case HeartInputType.beratBadan:
        updated = await _showHeartWeightDialog(existing: record);
        break;
      case HeartInputType.gejala:
        updated = await _showHeartSymptomDialog(existing: record);
        break;
      case HeartInputType.obat:
        updated = await _showHeartMedicationDialog(existing: record);
        break;
      case HeartInputType.pemeriksaan:
        updated = await _showHeartCheckupDialog(existing: record);
        break;
      case HeartInputType.aktivitas:
        updated = await _showHeartActivityDialog(existing: record);
        break;
    }
    if (updated != null) {
      await _updateHeartRecord(updated);
    }
  }

  Future<void> _addDmRecord(DiabetesHealthRecord record) async {
    if (!_canSubmitHealthInput()) return;
    try {
      await DiabetesHealthService.addRecord(_uid, record);
      if (mounted) {
        final auth = context.read<AuthProvider>();
        auth.updateActivityStreak();
        if (auth.currentUser != null) {
          AppNotificationService.refreshForUser(auth.currentUser!);
        }
      }
      await _loadDmRecords();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan data diabetes.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _updateDmRecord(DiabetesHealthRecord record) async {
    if (!_canSubmitHealthInput()) return;
    try {
      await DiabetesHealthService.updateRecord(_uid, record);
      await _loadDmRecords();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memperbarui data diabetes.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteDmRecord(DiabetesHealthRecord record) async {
    if (!_canSubmitHealthInput()) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus data'),
        content: const Text('Yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await DiabetesHealthService.deleteRecord(_uid, record.id);
      await _loadDmRecords();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menghapus data diabetes.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editDmRecord(DiabetesHealthRecord record) async {
    DiabetesHealthRecord? updated;
    switch (record.type) {
      case DiabetesInputType.pemeriksaan:
        updated = await _showDiabetesCheckupDialog(existing: record);
        break;
      case DiabetesInputType.insulin:
        updated = await _showInsulinAnalysisDialog(existing: record);
        break;
      case DiabetesInputType.aktivitas:
        updated = await _showDiabetesActivityDialog(existing: record);
        break;
    }
    if (updated != null) {
      await _updateDmRecord(updated);
    }
  }

  Future<void> _showDmInputTypeSheet() async {
    final type = await showModalBottomSheet<DiabetesInputType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Tambah Input Kesehatan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...DiabetesInputType.values.map(
                (t) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.diabetesColor.withValues(alpha: 0.12),
                    child: Icon(_dmTypeIcon(t), color: AppColors.diabetesColor),
                  ),
                  title: Text(t.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(ctx, t),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || type == null) return;

    DiabetesHealthRecord? record;
    switch (type) {
      case DiabetesInputType.pemeriksaan:
        record = await _showDiabetesCheckupDialog();
        break;
      case DiabetesInputType.insulin:
        record = await _showInsulinAnalysisDialog();
        break;
      case DiabetesInputType.aktivitas:
        record = await _showDiabetesActivityDialog();
        break;
    }

    if (record != null) {
      await _addDmRecord(record);
    }
  }

  Future<void> _showHeartInputTypeSheet() async {
    final type = await showModalBottomSheet<HeartInputType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Tambah Input Kesehatan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...HeartInputType.values
                  .where((t) => t != HeartInputType.beratBadan)
                  .map(
                (t) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.heartColor.withValues(alpha: 0.12),
                    child: Icon(_heartTypeIcon(t), color: AppColors.heartColor),
                  ),
                  title: Text(t.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(ctx, t),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || type == null) return;

    HeartHealthRecord? record;
    switch (type) {
      case HeartInputType.gejala:
        record = await _showHeartSymptomDialog();
        break;
      case HeartInputType.obat:
        record = await _showHeartMedicationDialog();
        break;
      case HeartInputType.pemeriksaan:
        record = await _showHeartCheckupDialog();
        break;
      case HeartInputType.aktivitas:
        record = await _showHeartActivityDialog();
        break;
      case HeartInputType.beratBadan:
        // Tidak dipakai lagi pada alur input baru.
        return;
    }

    if (record != null) {
      await _addHeartRecord(record);
    }
  }

  Future<HeartHealthRecord?> _showHeartWeightDialog({HeartHealthRecord? existing}) {
    final payload = existing?.payload ?? {};
    final weightController = TextEditingController(
      text: (payload['weight'] ?? '').toString(),
    );
    final idealController = TextEditingController(
      text: (payload['idealWeight'] ??
              context.read<AuthProvider>().currentUser?.weight ??
              '')
          .toString(),
    );
    DateTime date = existing?.date ?? DateTime.now();

    return showDialog<HeartHealthRecord>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text(existing == null ? 'Input Berat Badan' : 'Edit Berat Badan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DatePickerField(
                  label: 'Tanggal',
                  value: _dateFmt.format(date),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setLocalState(() => date = picked);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Berat badan (kg)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: idealController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Berat badan ideal (kg)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                final w = double.tryParse(weightController.text.trim()) ?? -1;
                final iw = double.tryParse(idealController.text.trim()) ?? -1;
                if (w <= 0 || iw <= 0) return;
                Navigator.pop(
                  ctx,
                  HeartHealthRecord(
                    id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                    type: HeartInputType.beratBadan,
                    date: DateTime(date.year, date.month, date.day),
                    payload: {'weight': w, 'idealWeight': iw},
                    createdAt: existing?.createdAt ?? DateTime.now(),
                  ),
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<HeartHealthRecord?> _showHeartSymptomDialog({HeartHealthRecord? existing}) {
    final payload = existing?.payload ?? {};
    DateTime date = existing?.date ?? DateTime.now();
    String sesak = (payload['sesakNafas'] ?? 'Tidak').toString();
    String bengkak = (payload['bengkak'] ?? 'Tidak').toString();
    String cepatLelah = (payload['cepatLelah'] ?? 'Tidak').toString();
    final bbController = TextEditingController(text: (payload['bb'] ?? '').toString());

    return showDialog<HeartHealthRecord>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Text(existing == null ? 'Input Gejala Jantung' : 'Edit Gejala Jantung'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                _DatePickerField(
                  label: 'Tanggal',
                  value: _dateFmt.format(date),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setLocalState(() => date = picked);
                  },
                ),
                const SizedBox(height: 10),
                _HeartOptionField(
                  label: 'Sesak napas',
                  value: sesak,
                  options: const ['Tidak', 'Ringan', 'Berat'],
                  onChanged: (v) => setLocalState(() => sesak = v),
                ),
                const SizedBox(height: 8),
                _HeartOptionField(
                  label: 'Bagian tubuh bengkak',
                  value: bengkak,
                  options: const ['Tidak', 'Ringan', 'Berat'],
                  onChanged: (v) => setLocalState(() => bengkak = v),
                ),
                const SizedBox(height: 8),
                _HeartOptionField(
                  label: 'Cepat lelah',
                  value: cepatLelah,
                  options: const ['Ya', 'Tidak'],
                  onChanged: (v) => setLocalState(() => cepatLelah = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bbController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'BB (kg)'),
                ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                final category = _heartSymptomCategory(
                  sesak: sesak,
                  bengkak: bengkak,
                  cepatLelah: cepatLelah,
                );
                Navigator.pop(
                  ctx,
                  HeartHealthRecord(
                    id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                    type: HeartInputType.gejala,
                    date: DateTime(date.year, date.month, date.day),
                    payload: {
                      'sesakNafas': sesak,
                      'bengkak': bengkak,
                      'cepatLelah': cepatLelah,
                      'bb': bbController.text.trim(),
                      'category': category,
                    },
                    createdAt: existing?.createdAt ?? DateTime.now(),
                  ),
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<HeartHealthRecord?> _showHeartMedicationDialog({HeartHealthRecord? existing}) {
    final payload = existing?.payload ?? {};
    DateTime date = existing?.date ?? DateTime.now();
    final nameController = TextEditingController(text: (payload['name'] ?? '').toString());
    final doseFreqController = TextEditingController(
      text: (payload['doseFreq'] ?? '1').toString(),
    );
    final doseQtyController = TextEditingController(
      text: (payload['doseQty'] ?? '1').toString(),
    );
    final doseStrengthController = TextEditingController(
      text: (payload['doseStrength'] ?? '').toString(),
    );
    final noteController = TextEditingController(text: (payload['note'] ?? '').toString());
    String formType = (payload['form'] ?? 'Tablet').toString();
    String doseUnit = (payload['doseUnit'] ?? 'mg').toString();
    String period = (payload['period'] ?? 'Pagi').toString();
    String consumed = (payload['consumed'] ?? 'Ya').toString();

    if (!['Tablet', 'Kapsul', 'Sirup'].contains(formType)) {
      formType = 'Tablet';
    }
    if (!['mg', 'ml', 'g'].contains(doseUnit)) {
      doseUnit = 'mg';
    }

    return showDialog<HeartHealthRecord>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Text(existing == null ? 'Input Obat Jantung' : 'Edit Obat Jantung'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                _DatePickerField(
                  label: 'Tanggal',
                  value: _dateFmt.format(date),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setLocalState(() => date = picked);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nama obat'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: formType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Bentuk'),
                  items: const [
                    DropdownMenuItem(value: 'Tablet', child: Text('Tablet')),
                    DropdownMenuItem(value: 'Kapsul', child: Text('Kapsul')),
                    DropdownMenuItem(value: 'Sirup', child: Text('Sirup')),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocalState(() => formType = v);
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Format dosis: ... x ... (... mg/ml/g)',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: doseFreqController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Frekuensi'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('x'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: doseQtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Jumlah'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: doseStrengthController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Kadar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 110,
                      child: DropdownButtonFormField<String>(
                        value: doseUnit,
                        decoration: const InputDecoration(labelText: 'Satuan'),
                        items: const [
                          DropdownMenuItem(value: 'mg', child: Text('mg')),
                          DropdownMenuItem(value: 'ml', child: Text('ml')),
                          DropdownMenuItem(value: 'g', child: Text('g')),
                        ],
                        onChanged: (v) {
                          if (v != null) setLocalState(() => doseUnit = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _HeartOptionField(
                  label: 'Waktu minum',
                  value: period,
                  options: const ['Pagi', 'Siang', 'Malam'],
                  onChanged: (v) => setLocalState(() => period = v),
                ),
                const SizedBox(height: 8),
                _HeartOptionField(
                  label: 'Sudah diminum',
                  value: consumed,
                  options: const ['Ya', 'Tidak'],
                  onChanged: (v) => setLocalState(() => consumed = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Catatan'),
                ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(
                  ctx,
                  HeartHealthRecord(
                    id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                    type: HeartInputType.obat,
                    date: DateTime(date.year, date.month, date.day),
                    payload: {
                      'name': nameController.text.trim(),
                      'form': formType,
                      'dose':
                          '${doseFreqController.text.trim()} x ${doseQtyController.text.trim()} (${doseStrengthController.text.trim()} $doseUnit)',
                      'doseFreq': doseFreqController.text.trim(),
                      'doseQty': doseQtyController.text.trim(),
                      'doseStrength': doseStrengthController.text.trim(),
                      'doseUnit': doseUnit,
                      'period': period,
                      'consumed': consumed,
                      'note': noteController.text.trim(),
                    },
                    createdAt: existing?.createdAt ?? DateTime.now(),
                  ),
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<HeartHealthRecord?> _showHeartCheckupDialog({HeartHealthRecord? existing}) {
    final payload = existing?.payload ?? {};
    DateTime date = existing?.date ?? DateTime.now();
    final refs = _examReferencesForDiseaseType(DiseaseType.heartFailure);
    final groups = refs.map((e) => e.group).toSet().toList();

    String examType = (payload['examType'] ?? 'Fisik').toString();
    if (!groups.contains(examType)) examType = groups.first;

    String examId = (payload['examId'] ?? '').toString();
    final typeRefs = refs.where((e) => e.group == examType).toList();
    if (examId.isEmpty || !typeRefs.any((e) => e.id == examId)) {
      final examName = (payload['exam'] ?? '').toString();
      examId = typeRefs
              .firstWhere(
                (e) => e.name.toLowerCase() == examName.toLowerCase(),
                orElse: () => typeRefs.first,
              )
              .id;
    }

    final resultController = TextEditingController(text: (payload['result'] ?? '').toString());
    String sampleTime = (payload['sampleTime'] ?? 'Pagi').toString();
    if (!['Pagi', 'Siang', 'Sore', 'Malam'].contains(sampleTime)) {
      sampleTime = 'Pagi';
    }

    _ExamReference selectedExam() {
      final selectedRefs = refs.where((e) => e.group == examType).toList();
      return selectedRefs.firstWhere(
        (e) => e.id == examId,
        orElse: () => selectedRefs.first,
      );
    }

    return showDialog<HeartHealthRecord>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Text(existing == null ? 'Input Pemeriksaan' : 'Edit Pemeriksaan'),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                _DatePickerField(
                  label: 'Tanggal',
                  value: _dateFmt.format(date),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) setLocalState(() => date = picked);
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  'Jenis pemeriksaan',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: groups
                      .map(
                        (g) => ChoiceChip(
                          selected: examType == g,
                          label: Text(g),
                          onSelected: (_) {
                            setLocalState(() {
                              examType = g;
                              final nextRefs = refs.where((e) => e.group == examType).toList();
                              examId = nextRefs.first.id;
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: examId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Pemeriksaan'),
                  items: refs
                      .where((e) => e.group == examType)
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(e.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setLocalState(() => examId = value);
                  },
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (_) {
                    final exam = selectedExam();
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Satuan: ${exam.unit.isEmpty ? '-' : exam.unit}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Nilai normal: ${exam.normal}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (examType == 'Urin') ...[
                  const SizedBox(height: 10),
                  _HeartOptionField(
                    label: 'Waktu pengambilan urin',
                    value: sampleTime,
                    options: const ['Pagi', 'Siang', 'Sore', 'Malam'],
                    onChanged: (v) => setLocalState(() => sampleTime = v),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: resultController,
                  onChanged: (_) => setLocalState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Hasil',
                    hintText: 'Contoh: 130/80, 5.2, Negatif',
                  ),
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (_) {
                    final autoCategory = _autoExamCategory(
                      selectedExam(),
                      resultController.text.trim(),
                    );
                    return Row(
                      children: [
                        const Text(
                          'Kategori otomatis: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        _StatusBadge(
                          text: autoCategory,
                          color: _checkupCategoryColor(autoCategory),
                        ),
                      ],
                    );
                  },
                ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                final exam = selectedExam();
                if (resultController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hasil pemeriksaan wajib diisi.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.pop(
                  ctx,
                  HeartHealthRecord(
                    id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                    type: HeartInputType.pemeriksaan,
                    date: DateTime(date.year, date.month, date.day),
                    payload: {
                      'examType': examType,
                      'examId': exam.id,
                      'exam': exam.name,
                      'result': resultController.text.trim(),
                      'unit': exam.unit,
                      'normalRange': exam.normal,
                      'category': _autoExamCategory(
                        exam,
                        resultController.text.trim(),
                      ),
                      if (examType == 'Urin') 'sampleTime': sampleTime,
                    },
                    createdAt: existing?.createdAt ?? DateTime.now(),
                  ),
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<DiabetesHealthRecord?> _showDiabetesCheckupDialog({DiabetesHealthRecord? existing}) {
    final payload = existing?.payload ?? {};
    DateTime date = existing?.date ?? DateTime.now();
    final refs = _examReferencesForDiseaseType(DiseaseType.type2DiabetesMellitus);
    final groups = refs.map((e) => e.group).toSet().toList();

    String examType = (payload['examType'] ?? 'Fisik').toString();
    if (!groups.contains(examType)) examType = groups.first;

    String examId = (payload['examId'] ?? '').toString();
    final typeRefs = refs.where((e) => e.group == examType).toList();
    if (examId.isEmpty || !typeRefs.any((e) => e.id == examId)) {
      final examName = (payload['exam'] ?? '').toString();
      examId = typeRefs
              .firstWhere(
                (e) => e.name.toLowerCase() == examName.toLowerCase(),
                orElse: () => typeRefs.first,
              )
              .id;
    }

    final resultController = TextEditingController(text: (payload['result'] ?? '').toString());
    String sampleTime = (payload['sampleTime'] ?? 'Pagi').toString();
    if (!['Pagi', 'Siang', 'Sore', 'Malam'].contains(sampleTime)) {
      sampleTime = 'Pagi';
    }

    _ExamReference selectedExam() {
      final selectedRefs = refs.where((e) => e.group == examType).toList();
      return selectedRefs.firstWhere(
        (e) => e.id == examId,
        orElse: () => selectedRefs.first,
      );
    }

    return showDialog<DiabetesHealthRecord>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Text(existing == null ? 'Input Pemeriksaan' : 'Edit Pemeriksaan'),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DatePickerField(
                    label: 'Tanggal',
                    value: _dateFmt.format(date),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) setLocalState(() => date = picked);
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Jenis pemeriksaan',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: groups
                        .map(
                          (g) => ChoiceChip(
                            selected: examType == g,
                            label: Text(g),
                            onSelected: (_) {
                              setLocalState(() {
                                examType = g;
                                final nextRefs = refs.where((e) => e.group == examType).toList();
                                examId = nextRefs.first.id;
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: examId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Pemeriksaan'),
                    items: refs
                        .where((e) => e.group == examType)
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(e.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setLocalState(() => examId = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (_) {
                      final exam = selectedExam();
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Satuan: ${exam.unit.isEmpty ? '-' : exam.unit}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Nilai normal: ${exam.normal}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (examType == 'Urin') ...[
                    const SizedBox(height: 10),
                    _HeartOptionField(
                      label: 'Waktu pengambilan urin',
                      value: sampleTime,
                      options: const ['Pagi', 'Siang', 'Sore', 'Malam'],
                      onChanged: (v) => setLocalState(() => sampleTime = v),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: resultController,
                    onChanged: (_) => setLocalState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Hasil',
                      hintText: 'Contoh: 95, 180, 5.9, Negatif',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (_) {
                      final autoCategory = _autoExamCategory(
                        selectedExam(),
                        resultController.text.trim(),
                      );
                      return Row(
                        children: [
                          const Text(
                            'Kategori otomatis: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          _StatusBadge(
                            text: autoCategory,
                            color: _checkupCategoryColor(autoCategory),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                final exam = selectedExam();
                if (resultController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hasil pemeriksaan wajib diisi.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.pop(
                  ctx,
                  DiabetesHealthRecord(
                    id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                    type: DiabetesInputType.pemeriksaan,
                    date: DateTime(date.year, date.month, date.day),
                    payload: {
                      'examType': examType,
                      'examId': exam.id,
                      'exam': exam.name,
                      'result': resultController.text.trim(),
                      'unit': exam.unit,
                      'normalRange': exam.normal,
                      'category': _autoExamCategory(
                        exam,
                        resultController.text.trim(),
                      ),
                      if (examType == 'Urin') 'sampleTime': sampleTime,
                    },
                    createdAt: existing?.createdAt ?? DateTime.now(),
                  ),
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<DiabetesHealthRecord?> _showInsulinAnalysisDialog({
    DiabetesHealthRecord? existing,
  }) {
    final payload = existing?.payload ?? {};
    DateTime date = existing?.date ?? DateTime.now();

    final basalController = TextEditingController(
      text: (payload['insulinBasal'] ?? '').toString(),
    );
    final prandialController = TextEditingController(
      text: (payload['insulinPrandial'] ?? '').toString(),
    );
    final carbsController = TextEditingController(
      text: (payload['karbohidratMakan'] ?? '').toString(),
    );
    final glController = TextEditingController(
      text: (payload['gl'] ?? '').toString(),
    );
    final actualController = TextEditingController(
      text: (payload['dosisAktual'] ?? '').toString(),
    );

    String meal = (payload['meal'] ?? 'Sarapan').toString();
    if (meal == 'Snack') {
      meal = 'Selingan Siang';
    }
    if (![
      'Sarapan',
      'Selingan Pagi',
      'Makan Siang',
      'Selingan Siang',
      'Makan Malam',
      'Selingan Malam',
    ].contains(meal)) {
      meal = 'Sarapan';
    }
    bool isAutoLoading = false;
    String autoInfoText = '';
    bool didAutoInit = false;

    List<MealType> mapMealLabelToTypes(String mealLabel) {
      switch (mealLabel) {
        case 'Sarapan':
          return const [MealType.sarapan];
        case 'Selingan Pagi':
          return const [MealType.selinganPagi];
        case 'Makan Siang':
          return const [MealType.makanSiang];
        case 'Selingan Siang':
          return const [MealType.selinganSiang];
        case 'Makan Malam':
          return const [MealType.makanMalam];
        case 'Selingan Malam':
          return const [MealType.selinganMalam];
        default:
          return const [MealType.sarapan];
      }
    }

    bool isTodayDate(DateTime target) {
      final now = DateTime.now();
      return target.year == now.year &&
          target.month == now.month &&
          target.day == now.day;
    }

    Future<void> syncMealFromFood({
      required StateSetter setLocalState,
      required DateTime targetDate,
      required String mealLabel,
    }) async {
      if (_uid.isEmpty) {
        setLocalState(() {
          carbsController.text = '0';
          glController.text = '0';
          autoInfoText = 'Login untuk sinkronisasi data makanan.';
        });
        return;
      }

      setLocalState(() => isAutoLoading = true);
      try {
        final entries = await FoodLogService.getEntries(
          _uid,
          DateTime(targetDate.year, targetDate.month, targetDate.day),
        );
        final allowedTypes = mapMealLabelToTypes(mealLabel);
        final mealEntries = entries
            .where((entry) => allowedTypes.contains(entry.mealType))
            .toList();

        final totalCarb = mealEntries.fold<double>(
          0.0,
          (sum, entry) => sum + entry.karbohidrat,
        );
        final totalFiber = mealEntries.fold<double>(
          0.0,
          (sum, entry) => sum + entry.serat,
        );
        final netCarb = (totalCarb - totalFiber).clamp(0.0, double.infinity);
        final gl = netCarb * 0.5;

        setLocalState(() {
          carbsController.text = totalCarb.toStringAsFixed(1);
          glController.text = gl.toStringAsFixed(1);
          autoInfoText = mealEntries.isEmpty
              ? 'Belum ada log makanan untuk $mealLabel pada tanggal ini.'
              : 'Auto dari Food Tracker: ${mealEntries.length} item makanan.';
        });
      } catch (_) {
        setLocalState(() {
          autoInfoText = 'Gagal mengambil data dari Food Tracker.';
        });
      } finally {
        setLocalState(() => isAutoLoading = false);
      }
    }

    double v(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

    String categoryFromDiff(double diff) {
      if (diff.abs() <= 1.0) return 'Balance';
      if (diff > 1.0) return 'Lebih';
      return 'Kurang';
    }

    return showDialog<DiabetesHealthRecord>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          if (!didAutoInit) {
            didAutoInit = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              syncMealFromFood(
                setLocalState: setLocalState,
                targetDate: date,
                mealLabel: meal,
              );
            });
          }

          final a = v(basalController);
          final b = v(prandialController);
          final c = a + b;
          final d = c <= 0 ? 0.0 : 500 / c;
          final carb = v(carbsController);
          final e = d <= 0 ? 0.0 : carb / d;
          final f = v(actualController);
          final diff = f - e;
          final category = categoryFromDiff(diff);

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Text(
              existing == null
                  ? 'Input Analisis Keseimbangan Insulin'
                  : 'Edit Analisis Keseimbangan Insulin',
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.diabetesColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.diabetesColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Text(
                        'Isi data insulin harian dan karbohidrat makan. Sistem akan menghitung otomatis: total insulin harian, ICR, estimasi insulin makan, selisih, dan kategori.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setLocalState(() {
                                date = date.subtract(const Duration(days: 1));
                              });
                              syncMealFromFood(
                                setLocalState: setLocalState,
                                targetDate: date,
                                mealLabel: meal,
                              );
                            },
                            icon: const Icon(Icons.chevron_left),
                            color: AppColors.textPrimary,
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: date,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 1)),
                                );
                                if (picked != null) {
                                  setLocalState(() => date = picked);
                                  await syncMealFromFood(
                                    setLocalState: setLocalState,
                                    targetDate: date,
                                    mealLabel: meal,
                                  );
                                }
                              },
                              child: Column(
                                children: [
                                  Text(
                                    isTodayDate(date)
                                        ? 'Hari Ini · ${_dateFmt.format(date)}'
                                        : _dateFmt.format(date),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Tap untuk pilih tanggal',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: isTodayDate(date)
                                ? null
                                : () {
                                    setLocalState(() {
                                      date = date.add(const Duration(days: 1));
                                    });
                                    syncMealFromFood(
                                      setLocalState: setLocalState,
                                      targetDate: date,
                                      mealLabel: meal,
                                    );
                                  },
                            icon: const Icon(Icons.chevron_right),
                            color: isTodayDate(date)
                                ? AppColors.textHint
                                : AppColors.textPrimary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: meal,
                      decoration: const InputDecoration(labelText: 'Waktu makan'),
                      items: const [
                        DropdownMenuItem(value: 'Sarapan', child: Text('Sarapan')),
                        DropdownMenuItem(value: 'Selingan Pagi', child: Text('Selingan Pagi')),
                        DropdownMenuItem(value: 'Makan Siang', child: Text('Makan Siang')),
                        DropdownMenuItem(value: 'Selingan Siang', child: Text('Selingan Siang')),
                        DropdownMenuItem(value: 'Makan Malam', child: Text('Makan Malam')),
                        DropdownMenuItem(value: 'Selingan Malam', child: Text('Selingan Malam')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setLocalState(() => meal = value);
                          syncMealFromFood(
                            setLocalState: setLocalState,
                            targetDate: date,
                            mealLabel: meal,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              autoInfoText.isEmpty
                                  ? 'Sinkronisasi karbo/GL dari Food Tracker.'
                                  : autoInfoText,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (isAutoLoading) ...[
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: isAutoLoading
                                ? null
                                : () => syncMealFromFood(
                                      setLocalState: setLocalState,
                                      targetDate: date,
                                      mealLabel: meal,
                                    ),
                            child: const Text('Sinkronkan'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: basalController,
                      onChanged: (_) => setLocalState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Insulin basal harian (A) unit'),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Contoh: total insulin kerja panjang dalam 1 hari. Isi angka saja (mis. 12).',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: prandialController,
                      onChanged: (_) => setLocalState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Insulin prandial harian (B) unit'),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Contoh: total insulin sebelum makan selama 1 hari. Isi angka saja (mis. 18).',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: carbsController,
                      readOnly: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Total karbohidrat makan (gram)',
                        helperText: 'Otomatis dari Food Tracker',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Nilai ini otomatis sesuai tanggal + waktu makan yang dipilih.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: glController,
                      readOnly: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'GL',
                        helperText: 'Otomatis dari Food Tracker',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Nilai GL dihitung otomatis dari log makanan pada waktu makan tersebut.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: actualController,
                      onChanged: (_) => setLocalState(() {}),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Dosis insulin aktual (F) unit'),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Isi dosis insulin yang benar-benar diberikan sebelum makan.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total insulin harian (C = A+B): ${c.toStringAsFixed(2)} unit'),
                          Text('ICR (D = 500/C): ${d.toStringAsFixed(2)}'),
                          Text('Estimasi insulin makan (E = karbohidrat/D): ${e.toStringAsFixed(2)} unit'),
                          Text('Selisih (F-E): ${diff.toStringAsFixed(2)} unit'),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Text('Kategori: '),
                              _StatusBadge(
                                text: category,
                                color: category == 'Balance'
                                    ? AppColors.success
                                    : category == 'Lebih'
                                        ? AppColors.warning
                                        : AppColors.error,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () {
                  if (actualController.text.trim().isEmpty || carbsController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Isi karbohidrat dan dosis aktual terlebih dahulu.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(
                    ctx,
                    DiabetesHealthRecord(
                      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                      type: DiabetesInputType.insulin,
                      date: DateTime(date.year, date.month, date.day),
                      payload: {
                        'meal': meal,
                        'insulinBasal': a,
                        'insulinPrandial': b,
                        'totalInsulin': c,
                        'icr': d,
                        'karbohidratMakan': carb,
                        'estimasiInsulin': e,
                        'dosisAktual': f,
                        'selisih': diff,
                        'category': category,
                        'gl': v(glController),
                      },
                      createdAt: existing?.createdAt ?? DateTime.now(),
                    ),
                  );
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showInputTypeSheet() async {
    final type = await showModalBottomSheet<KidneyInputType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Tambah Input Kesehatan Ginjal',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...KidneyInputType.values.map(
                (t) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.kidneyColor.withValues(alpha: 0.12),
                    child: Icon(_typeIcon(t), color: AppColors.kidneyColor),
                  ),
                  title: Text(t.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(ctx, t),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || type == null) return;

    KidneyHealthRecord? record;
    if (type == KidneyInputType.hemodialisa) {
      record = await _showHemodialysisDialog();
    } else if (type == KidneyInputType.obat) {
      record = await _showMedicationDialog();
    } else if (type == KidneyInputType.gejala) {
      record = await _showSymptomDialog();
    } else {
      record = await _showCheckupDialog();
    }

    if (record != null) {
      await _addRecord(record);
    }
  }

  String _activityGroup(String activity) {
    const daily = {'Mencuci', 'Mengepel', 'Memasak', 'Menyetrika', 'Berkebun'};
    return daily.contains(activity) ? 'Aktivitas sehari-hari' : 'Olahraga';
  }

  String _baseActivityCategory(String activity) {
    const light = {'Mencuci', 'Memasak', 'Menyetrika', 'Berkebun'};
    const moderate = {'Mengepel', 'Jalan kaki', 'Bersepeda', 'Senam'};
    if (light.contains(activity)) return 'Aktivitas ringan yang masih ditoleransi';
    if (moderate.contains(activity)) return 'Aktivitas sedang';
    return 'Aktivitas berat';
  }

  ({String category, String analysis, String status}) _activitySystemResult({
    required String activity,
    required String complaint,
  }) {
    final baseCategory = _baseActivityCategory(activity);
    final hasComplaint = complaint != 'Normal';
    const severeComplaints = {'Nyeri dada', 'Keringat dingin'};

    if (severeComplaints.contains(complaint)) {
      return (
        category: 'Aktivitas berat',
        analysis: 'Sesak, palpitasi, nyeri dada, kelelahan jelas',
        status: 'Tidak normal / tidak disarankan',
      );
    }

    if (!hasComplaint) {
      if (baseCategory == 'Aktivitas ringan yang masih ditoleransi') {
        return (
          category: baseCategory,
          analysis: 'Tidak ada sesak, palpitasi, atau kelelahan berlebihan',
          status: 'Normal / aman',
        );
      }
      if (baseCategory == 'Aktivitas sedang') {
        return (
          category: baseCategory,
          analysis: 'Gejala muncul saat aktivitas dan membaik saat istirahat',
          status: 'Perlu pemantauan',
        );
      }
      return (
        category: baseCategory,
        analysis: 'Sesak ringan, cepat capek, jantung berdebar',
        status: 'Waspada / mulai tidak normal',
      );
    }

    if (baseCategory == 'Aktivitas ringan yang masih ditoleransi') {
      return (
        category: 'Aktivitas ringan tetapi mulai memberatkan',
        analysis: 'Sesak ringan, cepat capek, jantung berdebar',
        status: 'Waspada / mulai tidak normal',
      );
    }
    if (baseCategory == 'Aktivitas sedang') {
      return (
        category: baseCategory,
        analysis: 'Gejala muncul saat aktivitas dan membaik saat istirahat',
        status: 'Perlu pemantauan',
      );
    }
    return (
      category: baseCategory,
      analysis: 'Sesak, palpitasi, nyeri dada, kelelahan jelas',
      status: 'Tidak normal / tidak disarankan',
    );
  }

  Future<_ActivityInputResult?> _showActivityDialog({
    required String title,
    Map<String, dynamic>? existingPayload,
    DateTime? existingDate,
  }) {
    final payload = existingPayload ?? {};
    DateTime date = existingDate ?? DateTime.now();
    
    String activity = (payload['activityName'] ?? _activityOptions.first).toString();
    // Ensure the initial value exists in options to prevent DropdownButton error
    if (!_activityOptions.contains(activity)) {
      activity = 'Lainnya';
    }

    String complaint = (payload['complaint'] ?? _activityComplaintOptions.first).toString();
    if (!_activityComplaintOptions.contains(complaint)) {
      complaint = _activityComplaintOptions.first;
    }
    
    final durationCtrl = TextEditingController(
      text: (payload['duration'] ?? '').toString(),
    );

    return showDialog<_ActivityInputResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            title: Text(title),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DatePickerField(
                      label: 'Tanggal',
                      value: _dateFmt.format(date),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (picked != null) setLocalState(() => date = picked);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _activityOptions.contains(activity) ? activity : _activityOptions.first,
                      decoration: const InputDecoration(labelText: 'Jenis aktivitas'),
                      items: _activityOptions.toSet().map((v) {
                        return DropdownMenuItem(value: v, child: Text(v));
                      }).toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setLocalState(() => activity = v);
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: durationCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: false),
                      decoration: const InputDecoration(
                        labelText: 'Durasi (menit)',
                        hintText: 'contoh: 30',
                        suffixText: 'menit',
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _activityComplaintOptions.contains(complaint) ? complaint : _activityComplaintOptions.first,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Status Keluhan'),
                      items: _activityComplaintOptions.toSet().map((v) {
                        return DropdownMenuItem(
                          value: v,
                          child: Text(
                            v,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      selectedItemBuilder: (context) {
                        return _activityComplaintOptions.toSet().map((v) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              v,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList();
                      },
                      onChanged: (v) {
                        if (v == null) return;
                        setLocalState(() => complaint = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () {
                  final durationValue = durationCtrl.text.trim();
                  if (durationValue.isEmpty) return;

                  final payloadOut = <String, dynamic>{
                    'activityName': activity,
                    'duration': durationValue,
                    'complaint': complaint,
                    'status': complaint == 'Normal' ? 'Normal / Aman' : 'Perlu Waspada',
                  };
                  Navigator.pop(
                    ctx,
                    _ActivityInputResult(
                      date: DateTime(date.year, date.month, date.day),
                      payload: payloadOut,
                    ),
                  );
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<HeartHealthRecord?> _showHeartActivityDialog({HeartHealthRecord? existing}) async {
    final result = await _showActivityDialog(
      title: existing == null ? 'Input Aktivitas Jantung' : 'Edit Aktivitas Jantung',
      existingPayload: existing?.payload,
      existingDate: existing?.date,
    );
    if (result == null) return null;

    return HeartHealthRecord(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      type: HeartInputType.aktivitas,
      date: result.date,
      payload: result.payload,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
  }

  Future<DiabetesHealthRecord?> _showDiabetesActivityDialog({
    DiabetesHealthRecord? existing,
  }) async {
    final result = await _showActivityDialog(
      title: existing == null
          ? 'Input Aktivitas Diabetes'
          : 'Edit Aktivitas Diabetes',
      existingPayload: existing?.payload,
      existingDate: existing?.date,
    );
    if (result == null) return null;

    return DiabetesHealthRecord(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      type: DiabetesInputType.aktivitas,
      date: result.date,
      payload: result.payload,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
  }

  void _showLoginRequired() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.lock_outline, size: 52, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'Login Diperlukan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kamu bisa lihat tracker sebagai guest. Untuk menambah data kesehatan, silakan login dulu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, AppConstants.routeLogin);
                },
                child: const Text('Masuk'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, AppConstants.routeRegister);
                },
                child: const Text('Daftar Akun'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<KidneyHealthRecord?> _showHemodialysisDialog({
    KidneyHealthRecord? existing,
  }) {
    final postController = TextEditingController(
      text: existing != null
          ? (existing.payload['postHd1'] ?? '').toString()
          : '',
    );
    final preController = TextEditingController(
      text: existing != null
          ? (existing.payload['preHd2'] ?? '').toString()
          : '',
    );
    final noteController = TextEditingController(
      text: existing != null ? (existing.payload['note'] ?? '').toString() : '',
    );
    DateTime date = existing?.date ?? DateTime.now();

    return showDialog<KidneyHealthRecord>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text(existing == null ? 'Input Hemodialisa' : 'Edit Hemodialisa'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DatePickerField(
                  label: 'Tanggal',
                  value: _dateFmt.format(date),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) {
                      setLocalState(() => date = picked);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: postController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'BB setelah hemodialisa I (kg)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: preController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'BB sebelum hemodialisa II (kg)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final post = double.tryParse(postController.text.trim()) ?? -1;
                final pre = double.tryParse(preController.text.trim()) ?? -1;
                if (post <= 0 || pre <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Isi berat badan dengan benar.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.pop(
                  ctx,
                  KidneyHealthRecord(
                    id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                    type: KidneyInputType.hemodialisa,
                    date: DateTime(date.year, date.month, date.day),
                    payload: {
                      'postHd1': post,
                      'preHd2': pre,
                      'note': noteController.text.trim(),
                    },
                    createdAt: existing?.createdAt ?? DateTime.now(),
                  ),
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<KidneyHealthRecord?> _showMedicationDialog({
    KidneyHealthRecord? existing,
  }) {
    final payload = existing?.payload ?? {};
    final nameController = TextEditingController(
      text: (payload['name'] ?? '').toString(),
    );
    final doseFreqController = TextEditingController(
      text: (payload['doseFreq'] ?? '1').toString(),
    );
    final doseQtyController = TextEditingController(
      text: (payload['doseQty'] ?? '1').toString(),
    );
    final doseStrengthController = TextEditingController(
      text: (payload['doseStrength'] ?? '').toString(),
    );
    final noteController = TextEditingController(
      text: (payload['note'] ?? '').toString(),
    );
    DateTime date = existing?.date ?? DateTime.now();
    String formType = (payload['form'] ?? 'Tablet').toString();
    String doseUnit = (payload['doseUnit'] ?? 'mg').toString();
    String period = (payload['period'] ?? 'Pagi').toString();
    String mealTiming = (payload['mealTiming'] ?? 'Sebelum makan').toString();
    String hdTiming = (payload['hdTiming'] ?? 'Sebelum HD').toString();

    if (!['Tablet', 'Kapsul', 'Sirup'].contains(formType)) {
      formType = 'Tablet';
    }
    if (!['mg', 'ml', 'g'].contains(doseUnit)) {
      doseUnit = 'mg';
    }
    if (!['Pagi', 'Siang', 'Malam'].contains(period)) {
      period = 'Pagi';
    }
    if (!['Sebelum makan', 'Saat makan', 'Setelah makan'].contains(mealTiming)) {
      mealTiming = 'Sebelum makan';
    }
    if (!['Sebelum HD', 'Saat HD', 'Setelah HD'].contains(hdTiming)) {
      hdTiming = 'Sebelum HD';
    }

    return showDialog<KidneyHealthRecord>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Text(existing == null ? 'Input Obat' : 'Edit Obat'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DatePickerField(
                    label: 'Tanggal',
                    value: _dateFmt.format(date),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) {
                        setLocalState(() => date = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nama obat'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: formType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Bentuk'),
                    items: const [
                      DropdownMenuItem(value: 'Tablet', child: Text('Tablet')),
                      DropdownMenuItem(value: 'Kapsul', child: Text('Kapsul')),
                      DropdownMenuItem(value: 'Sirup', child: Text('Sirup')),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocalState(() => formType = v);
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Format dosis: ... x ... (... mg/ml/g)',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: doseFreqController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Frekuensi',
                            hintText: '1',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('x'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: doseQtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Jumlah',
                            hintText: '1',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: doseStrengthController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Kadar',
                            hintText: '500',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 110,
                        child: DropdownButtonFormField<String>(
                          value: doseUnit,
                          decoration: const InputDecoration(labelText: 'Satuan'),
                          items: const [
                            DropdownMenuItem(value: 'mg', child: Text('mg')),
                            DropdownMenuItem(value: 'ml', child: Text('ml')),
                            DropdownMenuItem(value: 'g', child: Text('g')),
                          ],
                          onChanged: (v) {
                            if (v != null) setLocalState(() => doseUnit = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Waktu minum',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Pagi', 'Siang', 'Malam'].map((item) {
                      return ChoiceChip(
                        selected: period == item,
                        label: Text(item),
                        onSelected: (_) => setLocalState(() => period = item),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Kaitan dengan makan',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Sebelum makan', 'Saat makan', 'Setelah makan']
                        .map((item) {
                      return ChoiceChip(
                        selected: mealTiming == item,
                        label: Text(item),
                        onSelected: (_) => setLocalState(() => mealTiming = item),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Kaitan dengan HD',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Sebelum HD', 'Saat HD', 'Setelah HD']
                        .map((item) {
                      return ChoiceChip(
                        selected: hdTiming == item,
                        label: Text(item),
                        onSelected: (_) => setLocalState(() => hdTiming = item),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    decoration:
                        const InputDecoration(labelText: 'Catatan/efek keluh'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nama obat wajib diisi.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.pop(
                  ctx,
                  KidneyHealthRecord(
                    id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                    type: KidneyInputType.obat,
                    date: DateTime(date.year, date.month, date.day),
                    payload: {
                      'name': nameController.text.trim(),
                      'form': formType,
                      'dose':
                          '${doseFreqController.text.trim()} x ${doseQtyController.text.trim()} (${doseStrengthController.text.trim()} $doseUnit)',
                      'doseFreq': doseFreqController.text.trim(),
                      'doseQty': doseQtyController.text.trim(),
                      'doseStrength': doseStrengthController.text.trim(),
                      'doseUnit': doseUnit,
                      'period': period,
                      'mealTiming': mealTiming,
                      'hdTiming': hdTiming,
                      'time': '$period • $mealTiming • $hdTiming',
                      'note': noteController.text.trim(),
                    },
                    createdAt: existing?.createdAt ?? DateTime.now(),
                  ),
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<KidneyHealthRecord?> _showSymptomDialog({
    KidneyHealthRecord? existing,
  }) {
    final payload = existing?.payload ?? {};
    final symptomController = TextEditingController(
      text: (payload['symptom'] ?? '').toString(),
    );
    final intensityController = TextEditingController(
      text: (payload['intensity'] ?? 'Ringan').toString(),
    );
    final noteController = TextEditingController(
      text: (payload['note'] ?? '').toString(),
    );
    DateTime date = existing?.date ?? DateTime.now();

    return showDialog<KidneyHealthRecord>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text(existing == null ? 'Input Gejala' : 'Edit Gejala'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DatePickerField(
                  label: 'Tanggal',
                  value: _dateFmt.format(date),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) {
                      setLocalState(() => date = picked);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: symptomController,
                  decoration: const InputDecoration(labelText: 'Gejala utama'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: intensityController,
                  decoration:
                      const InputDecoration(labelText: 'Intensitas (Ringan/Sedang/Berat)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Catatan'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (symptomController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Gejala utama wajib diisi.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.pop(
                  ctx,
                  KidneyHealthRecord(
                    id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                    type: KidneyInputType.gejala,
                    date: DateTime(date.year, date.month, date.day),
                    payload: {
                      'symptom': symptomController.text.trim(),
                      'intensity': intensityController.text.trim(),
                      'note': noteController.text.trim(),
                    },
                    createdAt: existing?.createdAt ?? DateTime.now(),
                  ),
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<KidneyHealthRecord?> _showCheckupDialog({
    KidneyHealthRecord? existing,
  }) {
    final payload = existing?.payload ?? {};
    final refs = _examReferencesForDiseaseType(DiseaseType.chronicKidneyDisease);
    final groups = refs.map((e) => e.group).toSet().toList();

    String examType = (payload['examType'] ?? 'Fisik').toString();
    if (!groups.contains(examType)) examType = groups.first;

    String examId = (payload['examId'] ?? '').toString();
    final typeRefs = refs.where((e) => e.group == examType).toList();
    if (examId.isEmpty || !typeRefs.any((e) => e.id == examId)) {
      final examName = (payload['exam'] ?? '').toString();
      examId = typeRefs
              .firstWhere(
                (e) => e.name.toLowerCase() == examName.toLowerCase(),
                orElse: () => typeRefs.first,
              )
              .id;
    }

    final resultController = TextEditingController(
      text: (payload['result'] ?? '').toString().isNotEmpty
          ? (payload['result'] ?? '').toString()
          : (payload['bloodPressure'] ?? '').toString().isNotEmpty
              ? (payload['bloodPressure'] ?? '').toString()
              : (payload['hb'] ?? '').toString().isNotEmpty
                  ? (payload['hb'] ?? '').toString()
                  : (payload['ureum'] ?? '').toString().isNotEmpty
                      ? (payload['ureum'] ?? '').toString()
                      : (payload['kreatinin'] ?? '').toString(),
    );
    String sampleTime = (payload['sampleTime'] ?? 'Pagi').toString();
    if (!['Pagi', 'Siang', 'Sore', 'Malam'].contains(sampleTime)) {
      sampleTime = 'Pagi';
    }
    DateTime date = existing?.date ?? DateTime.now();

    _ExamReference selectedExam() {
      final selectedRefs = refs.where((e) => e.group == examType).toList();
      return selectedRefs.firstWhere(
        (e) => e.id == examId,
        orElse: () => selectedRefs.first,
      );
    }

    return showDialog<KidneyHealthRecord>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Text(existing == null ? 'Input Pemeriksaan' : 'Edit Pemeriksaan'),
          content: SizedBox(
            width: 430,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                _DatePickerField(
                  label: 'Tanggal',
                  value: _dateFmt.format(date),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) {
                      setLocalState(() => date = picked);
                    }
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  'Jenis pemeriksaan',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: groups
                      .map(
                        (g) => ChoiceChip(
                          selected: examType == g,
                          label: Text(g),
                          onSelected: (_) {
                            setLocalState(() {
                              examType = g;
                              final nextRefs = refs.where((e) => e.group == examType).toList();
                              examId = nextRefs.first.id;
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: examId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Pemeriksaan'),
                  items: refs
                      .where((e) => e.group == examType)
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.id,
                          child: Text(e.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setLocalState(() => examId = value);
                  },
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (_) {
                    final exam = selectedExam();
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Satuan: ${exam.unit.isEmpty ? '-' : exam.unit}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Nilai normal: ${exam.normal}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (examType == 'Urin') ...[
                  const SizedBox(height: 10),
                  _HeartOptionField(
                    label: 'Waktu pengambilan urin',
                    value: sampleTime,
                    options: const ['Pagi', 'Siang', 'Sore', 'Malam'],
                    onChanged: (v) => setLocalState(() => sampleTime = v),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: resultController,
                  onChanged: (_) => setLocalState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Hasil',
                    hintText: 'Contoh: 130/80, 13.2, Negatif',
                  ),
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (_) {
                    final autoCategory = _autoExamCategory(
                      selectedExam(),
                      resultController.text.trim(),
                    );
                    return Row(
                      children: [
                        const Text(
                          'Kategori otomatis: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        _StatusBadge(
                          text: autoCategory,
                          color: _checkupCategoryColor(autoCategory),
                        ),
                      ],
                    );
                  },
                ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final exam = selectedExam();
                if (resultController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hasil pemeriksaan wajib diisi.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.pop(
                  ctx,
                  KidneyHealthRecord(
                    id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                    type: KidneyInputType.pemeriksaan,
                    date: DateTime(date.year, date.month, date.day),
                    payload: {
                      'examType': examType,
                      'examId': exam.id,
                      'exam': exam.name,
                      'result': resultController.text.trim(),
                      'unit': exam.unit,
                      'normalRange': exam.normal,
                      'category': _autoExamCategory(
                        exam,
                        resultController.text.trim(),
                      ),
                      if (examType == 'Urin') 'sampleTime': sampleTime,
                    },
                    createdAt: existing?.createdAt ?? DateTime.now(),
                  ),
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  List<KidneyHealthRecord> get _hemodialysisRecords {
    final list = _records
        .where((e) => e.type == KidneyInputType.hemodialisa)
        .toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  List<KidneyHealthRecord> get _medicationRecords {
    final list = _records.where((e) => e.type == KidneyInputType.obat).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<KidneyHealthRecord> get _symptomRecords {
    final list = _records.where((e) => e.type == KidneyInputType.gejala).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<KidneyHealthRecord> get _checkupRecords {
    final list = _records
        .where((e) => e.type == KidneyInputType.pemeriksaan)
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  String _riskCategory(double percent) {
    if (percent < 2.0) return 'Ringan';
    if (percent <= 4.0) return 'Sedang';
    return 'Berat';
  }

  Color _riskColor(double percent) {
    if (percent < 2.0) return AppColors.success;
    if (percent <= 4.0) return AppColors.warning;
    return AppColors.error;
  }

  IconData _typeIcon(KidneyInputType type) {
    switch (type) {
      case KidneyInputType.pemeriksaan:
        return Icons.monitor_heart;
      case KidneyInputType.hemodialisa:
        return Icons.water_drop;
      case KidneyInputType.gejala:
        return Icons.sick;
      case KidneyInputType.obat:
        return Icons.medication;
    }
  }

  IconData _heartTypeIcon(HeartInputType type) {
    switch (type) {
      case HeartInputType.beratBadan:
        return Icons.monitor_weight_outlined;
      case HeartInputType.gejala:
        return Icons.sick_outlined;
      case HeartInputType.obat:
        return Icons.medication_outlined;
      case HeartInputType.pemeriksaan:
        return Icons.fact_check_outlined;
      case HeartInputType.aktivitas:
        return Icons.directions_run_outlined;
    }
  }

  IconData _dmTypeIcon(DiabetesInputType type) {
    switch (type) {
      case DiabetesInputType.pemeriksaan:
        return Icons.monitor_heart;
      case DiabetesInputType.insulin:
        return Icons.calculate_outlined;
      case DiabetesInputType.aktivitas:
        return Icons.directions_walk_outlined;
    }
  }

  String _heartSymptomCategory({
    required String sesak,
    required String bengkak,
    required String cepatLelah,
  }) {
    if (sesak == 'Berat' || bengkak == 'Berat') return 'Berat';
    if (sesak == 'Ringan' || bengkak == 'Ringan' || cepatLelah == 'Ya') {
      return 'Sedang';
    }
    return 'Ringan';
  }

  String _autoExamCategory(_ExamReference exam, String rawResult) {
    final result = rawResult.trim();
    if (result.isEmpty) return '-';

    final lower = result.toLowerCase();
    final numbers = _extractAllNumbers(result);

    String fromRange({double? min, double? max}) {
      if (numbers.isEmpty) {
        if (lower.contains('negatif') || lower.contains('normal')) return 'Normal';
        return 'Tidak normal';
      }
      final value = numbers.first;
      if (min != null && value < min) return 'Rendah';
      if (max != null && value > max) return 'Tinggi';
      return 'Normal';
    }

    switch (exam.id) {
      case 'td':
        final values = _extractAllNumbers(result);
        if (values.length >= 2) {
          final sistol = values[0];
          final diastol = values[1];
          if (sistol < 90 || diastol < 60) return 'Rendah';
          if (sistol > 120 || diastol > 80) return 'Tinggi';
          return 'Normal';
        }
        return 'Tidak normal';
      case 'urin_protein':
      case 'urin_hb':
        return lower.contains('negatif') ? 'Normal' : 'Tidak normal';
      case 'urin_ph':
        return fromRange(min: 4.5, max: 8.0);
      case 'suhu':
        return fromRange(min: 36.5, max: 37.5);
      case 'spo2':
        return fromRange(min: 95, max: 100);
      case 'nadi':
        return fromRange(min: 60, max: 100);
      case 'chol_total':
        return fromRange(max: 200);
      case 'hdl':
        return fromRange(max: 4.5);
      case 'ldl':
        return fromRange(max: 100);
      case 'trigliserida':
        return fromRange(max: 150);
      case 'natrium':
        return fromRange(min: 135, max: 145);
      case 'gdp':
        return fromRange(min: 70, max: 110);
      case 'gds':
        return fromRange(min: 70, max: 200);
      case 'hba1c':
        return fromRange(max: 5.7);
      case 'ureum':
        return fromRange(min: 10, max: 50);
      case 'kreatinin':
        return fromRange(min: 0.6, max: 1.3);
      case 'kalium':
        return fromRange(min: 3.5, max: 5.1);
      case 'fosfat':
        return fromRange(min: 2.5, max: 4.5);
      case 'albumin':
        return fromRange(min: 3.5, max: 5.0);
      case 'hb_darah':
        return fromRange(min: 12.0, max: 16.0);
      case 'ht':
        return fromRange(min: 36.0, max: 50.0);
      default:
        if (lower.contains('normal') || lower.contains('negatif')) {
          return 'Normal';
        }
        if (lower.contains('tinggi')) return 'Tinggi';
        if (lower.contains('rendah')) return 'Rendah';
        return numbers.isEmpty ? 'Tidak normal' : 'Normal';
    }
  }

  List<double> _extractAllNumbers(String value) {
    final normalized = value.replaceAll(',', '.');
    final regex = RegExp(r'-?\d+(?:\.\d+)?');
    return regex
        .allMatches(normalized)
        .map((e) => double.tryParse(e.group(0) ?? ''))
        .whereType<double>()
        .toList();
  }

  List<HeartHealthRecord> get _heartWeightRecords {
    final list = _heartRecords.where((e) {
      if (e.type == HeartInputType.beratBadan) return true; // legacy
      if (e.type != HeartInputType.gejala) return false;
      final raw = e.payload['bb'];
      if (raw is num) return raw.toDouble() > 0;
      return double.tryParse((raw ?? '').toString()) != null;
    }).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  List<HeartHealthRecord> get _heartSymptomRecords {
    final list =
        _heartRecords.where((e) => e.type == HeartInputType.gejala).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<HeartHealthRecord> get _heartMedicationRecords {
    final list = _heartRecords.where((e) => e.type == HeartInputType.obat).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<HeartHealthRecord> get _heartCheckupRecords {
    final list =
        _heartRecords.where((e) => e.type == HeartInputType.pemeriksaan).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<HeartHealthRecord> get _heartActivityRecords {
    final list = _heartRecords.where((e) => e.type == HeartInputType.aktivitas).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<DiabetesHealthRecord> get _dmCheckupRecords {
    final list =
        _dmRecords.where((e) => e.type == DiabetesInputType.pemeriksaan).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<DiabetesHealthRecord> get _dmInsulinRecords {
    final list = _dmRecords.where((e) => e.type == DiabetesInputType.insulin).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<DiabetesHealthRecord> get _dmActivityRecords {
    final list = _dmRecords.where((e) => e.type == DiabetesInputType.aktivitas).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final guestDisease = context.watch<DiseaseProvider>().selectedDisease;
          final diseaseType = auth.currentUser?.diseaseType ?? guestDisease;

          if (diseaseType == null) {
            return const Center(
              child: Text(
                'Pilih penyakit terlebih dulu untuk melihat tracker kesehatan.',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            );
          }

          if (diseaseType == DiseaseType.heartFailure) {
            if (_isHeartLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return RefreshIndicator(
              onRefresh: _loadHeartRecords,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeartHeader(onInput: _showHeartInputTypeSheet),
                    const SizedBox(height: 16),
                    if (_uid.isEmpty) ...[
                      const _GuestReadOnlyBanner(
                        message:
                            'Mode Guest (Read-only). Kamu bisa buka form, tapi tidak bisa menyimpan input tanpa login.',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_heartError != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _heartError!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    if (_heartError != null) const SizedBox(height: 14),
                    _HeartTrendCard(
                      records: _heartWeightRecords,
                      idealWeight: auth.currentUser?.bbi ?? auth.currentUser?.weight ?? 0,
                    ),
                    const SizedBox(height: 16),
                    // Activity Gauge for Heart
                    () {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final sevenDaysAgo = today.subtract(const Duration(days: 6));
                      
                      final weeklyRecords = _heartActivityRecords.where((r) =>
                          r.date.isAfter(sevenDaysAgo.subtract(const Duration(seconds: 1))) &&
                          r.date.isBefore(today.add(const Duration(days: 1))));

                      final totalDuration = weeklyRecords.fold<double>(
                          0,
                          (sum, r) =>
                              sum +
                              (double.tryParse(r.payload['duration']?.toString() ?? '0') ??
                                  0));
                      return _ActivityGauge(
                        totalDuration: totalDuration,
                        target: 150.0,
                        themeColor: AppColors.primary,
                        isWeekly: true,
                      );
                    }(),
                    const SizedBox(height: 16),
                    _heartSymptomRecords.isEmpty
                        ? const _EmptyTableState(
                            message: 'Belum ada input gejala jantung.',
                          )
                        : _HeartSymptomTable(
                            records: _heartSymptomRecords,
                            dateFmt: _dateFmt,
                            onEdit: _editHeartRecord,
                            onDelete: _deleteHeartRecord,
                          ),
                    const SizedBox(height: 16),
                    _heartActivityRecords.isEmpty
                        ? const _EmptyTableState(
                            message: 'Belum ada input aktivitas jantung.',
                          )
                        : _HeartActivityTable(
                            records: _heartActivityRecords,
                            dateFmt: _dateFmt,
                            onEdit: _editHeartRecord,
                            onDelete: _deleteHeartRecord,
                          ),
                    const SizedBox(height: 16),
                    _heartMedicationRecords.isEmpty
                        ? const _EmptyTableState(
                            message: 'Belum ada input obat jantung.',
                          )
                        : _HeartMedicationTable(
                            records: _heartMedicationRecords,
                            dateFmt: _dateFmt,
                            onEdit: _editHeartRecord,
                            onDelete: _deleteHeartRecord,
                          ),
                    const SizedBox(height: 16),
                    _heartCheckupRecords.isEmpty
                        ? const _EmptyTableState(
                            message: 'Belum ada input pemeriksaan jantung.',
                          )
                        : _HeartCheckupTable(
                            records: _heartCheckupRecords,
                            dateFmt: _dateFmt,
                            onEdit: _editHeartRecord,
                            onDelete: _deleteHeartRecord,
                          ),
                    const SizedBox(height: 16),
                    const _NormalValuesButtonCard(
                      diseaseType: DiseaseType.heartFailure,
                    ),
                  ],
                ),
              ),
            );
          }

          if (diseaseType == DiseaseType.type2DiabetesMellitus) {
            if (_isDmLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return RefreshIndicator(
              onRefresh: _loadDmRecords,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DiabetesHeader(onInput: _showDmInputTypeSheet),
                    const SizedBox(height: 16),
                    if (_uid.isEmpty) ...[
                      const _GuestReadOnlyBanner(
                        message:
                            'Mode Guest (Read-only). Kamu bisa buka form, tapi tidak bisa menyimpan input tanpa login.',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_dmError != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _dmError!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    if (_dmError != null) const SizedBox(height: 14),
                    _DiabetesInsulinSummaryTable(
                      records: _dmInsulinRecords,
                      dateFmt: _dateFmt,
                      uid: _uid,
                      onDataChanged: _loadDmRecords,
                      onEdit: _editDmRecord,
                      onDelete: _deleteDmRecord,
                    ),
                    const SizedBox(height: 16),
                    // Activity Gauge for Diabetes
                    () {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final sevenDaysAgo = today.subtract(const Duration(days: 6));

                      final weeklyRecords = _dmActivityRecords.where((r) =>
                          r.date.isAfter(sevenDaysAgo.subtract(const Duration(seconds: 1))) &&
                          r.date.isBefore(today.add(const Duration(days: 1))));
                      
                      final totalDuration = weeklyRecords.fold<double>(
                          0,
                          (sum, r) =>
                              sum +
                              (double.tryParse(r.payload['duration']?.toString() ?? '0') ??
                                  0));
                      return _ActivityGauge(
                        totalDuration: totalDuration,
                        target: 150.0,
                        themeColor: Colors.orange.shade700,
                        isWeekly: true,
                      );
                    }(),
                    const SizedBox(height: 16),
                    _dmActivityRecords.isEmpty
                        ? const _EmptyTableState(
                            message: 'Belum ada input aktivitas diabetes.',
                          )
                        : _DiabetesActivityTable(
                            records: _dmActivityRecords,
                            dateFmt: _dateFmt,
                            onEdit: _editDmRecord,
                            onDelete: _deleteDmRecord,
                          ),
                    const SizedBox(height: 16),
                    _dmCheckupRecords.isEmpty
                        ? const _EmptyTableState(
                            message: 'Belum ada input pemeriksaan diabetes.',
                          )
                        : _DiabetesCheckupTable(
                            records: _dmCheckupRecords,
                            dateFmt: _dateFmt,
                            onEdit: _editDmRecord,
                            onDelete: _deleteDmRecord,
                          ),
                    const SizedBox(height: 16),
                    const _NormalValuesButtonCard(
                      diseaseType: DiseaseType.type2DiabetesMellitus,
                    ),
                    const SizedBox(height: 16),
                    const _InsulinGuideButtonCard(),
                  ],
                ),
              ),
            );
          }

          if (diseaseType != DiseaseType.chronicKidneyDisease) {
            return const SizedBox.shrink();
          }

          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _loadRecords,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.kidneyColor.withValues(alpha: 0.12),
                          AppColors.primary.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.health_and_safety,
                            color: AppColors.kidneyColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Health Tracker Ginjal',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Pantau hemodialisa, gejala, dan obat',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: _showInputTypeSheet,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 16, color: Colors.black),
                                SizedBox(width: 4),
                                Text(
                                  'Input',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_uid.isEmpty) ...[
                    const _GuestReadOnlyBanner(
                      message:
                          'Mode Guest (Read-only). Kamu bisa buka form, tapi tidak bisa menyimpan input tanpa login.',
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  if (_error != null) const SizedBox(height: 14),
                  _TrendCard(
                    records: _hemodialysisRecords,
                    riskCategory: _riskCategory,
                    riskColor: _riskColor,
                  ),
                  const SizedBox(height: 16),
                  _HemodialysisTable(
                    records: _hemodialysisRecords,
                    dateFmt: _dateFmt,
                    riskCategory: _riskCategory,
                    riskColor: _riskColor,
                    onEdit: _editRecord,
                    onDelete: _deleteRecord,
                  ),
                  const SizedBox(height: 16),
                  _MedicationTable(
                    records: _medicationRecords,
                    dateFmt: _dateFmt,
                    onEdit: _editRecord,
                    onDelete: _deleteRecord,
                  ),
                  const SizedBox(height: 16),
                  _SimpleListCard(
                    title: 'Riwayat Gejala',
                    emptyText: 'Belum ada input gejala.',
                    records: _symptomRecords,
                    icon: Icons.sick,
                    onEdit: _editRecord,
                    onDelete: _deleteRecord,
                    buildLine: (r) =>
                        '${_dateFmt.format(r.date)} • ${(r.payload['symptom'] ?? '-')} (${r.payload['intensity'] ?? '-'})',
                  ),
                  const SizedBox(height: 16),
                  _KidneyCheckupTable(
                    records: _checkupRecords,
                    dateFmt: _dateFmt,
                    onEdit: _editRecord,
                    onDelete: _deleteRecord,
                  ),
                  const SizedBox(height: 16),
                  const _NormalValuesButtonCard(
                    diseaseType: DiseaseType.chronicKidneyDisease,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value),
            const Icon(Icons.calendar_month, size: 18),
          ],
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final List<KidneyHealthRecord> records;
  final String Function(double) riskCategory;
  final Color Function(double) riskColor;

  const _TrendCard({
    required this.records,
    required this.riskCategory,
    required this.riskColor,
  });

  @override
  Widget build(BuildContext context) {
    final xLabelFmt = DateFormat('d/M');
    final last = records.isNotEmpty ? records.last : null;
    final lastPercent = last?.gainPercent ?? 0;
    final trendData = records.length > 8
        ? records.sublist(records.length - 8)
        : records;
    final spots = <FlSpot>[];
    for (int i = 0; i < trendData.length; i++) {
      spots.add(FlSpot(i.toDouble(), trendData[i].gainPercent));
    }

    final (minY, maxY, interval) = spots.isEmpty
      ? ( -5.0, 5.0, 2.0 )
      : () {
        final minValue = spots
          .map((e) => e.y)
          .reduce((a, b) => a < b ? a : b);
        final maxValue = spots
          .map((e) => e.y)
          .reduce((a, b) => a > b ? a : b);

        final absBound = [minValue.abs(), maxValue.abs(), 2.0]
          .reduce((a, b) => a > b ? a : b);
        final padded = (absBound * 1.2).clamp(2.0, 30.0).toDouble();
        final step = padded <= 8 ? 2.0 : 5.0;
        return (-padded, padded, step);
        }();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trend % kenaikan BB antar dialisis (1 bulan)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.kidneyColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'BB kurva',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor(lastPercent).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${lastPercent.toStringAsFixed(1)}% • ${riskCategory(lastPercent)}',
                  style: TextStyle(
                    color: riskColor(lastPercent),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 170,
            child: spots.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada data hemodialisa.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      clipData: const FlClipData.all(),
                      minX: 0,
                      maxX: (spots.length - 1).toDouble(),
                      minY: minY,
                      maxY: maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: AppColors.divider,
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= spots.length) {
                                return const SizedBox();
                              }
                              if (spots.length > 5 && idx.isOdd) {
                                return const SizedBox();
                              }
                              return Text(
                                xLabelFmt.format(trendData[idx].date),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.textSecondary,
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) => Text(
                              '${value.toInt()}%',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppColors.kidneyColor,
                          barWidth: 2.2,
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.kidneyColor.withValues(alpha: 0.08),
                          ),
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              final color = riskColor(spot.y);
                              return FlDotCirclePainter(
                                radius: 3.8,
                                color: color,
                                strokeWidth: 1.5,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HemodialysisTable extends StatelessWidget {
  final List<KidneyHealthRecord> records;
  final DateFormat dateFmt;
  final String Function(double) riskCategory;
  final Color Function(double) riskColor;
  final void Function(KidneyHealthRecord) onEdit;
  final void Function(KidneyHealthRecord) onDelete;

  const _HemodialysisTable({
    required this.records,
    required this.dateFmt,
    required this.riskCategory,
    required this.riskColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _TableCard(
      title: 'Tabel kenaikan berat badan antar dialisis',
      child: records.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Belum ada input hemodialisa.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                dataTextStyle: const TextStyle(fontSize: 12),
                columnSpacing: 18,
                columns: [
                  const DataColumn(label: Text('Tanggal')),
                  const DataColumn(label: Text('BB setelah\nHemodialisa I')),
                  const DataColumn(label: Text('BB sebelum\nHemodialisa II')),
                  const DataColumn(label: Text('Kenaikan\nBB')),
                  const DataColumn(label: Text('%')),
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Kategori'),
                        const SizedBox(width: 4),
                        Tooltip(
                          triggerMode: TooltipTriggerMode.tap,
                          showDuration: const Duration(seconds: 4),
                          padding: const EdgeInsets.all(10),
                          textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          message: 'Kategori % IDWG:\nRingan: < 2%\nSedang: 2% - 4%\nBerat: > 4%',
                          child: const Icon(
                            Icons.info_outline,
                            size: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const DataColumn(label: Text('Aksi')),
                ],
                rows: records.reversed.map((e) {
                  return DataRow(
                    cells: [
                      DataCell(Text(dateFmt.format(e.date))),
                      DataCell(Text('${e.postHd1.toStringAsFixed(1)} kg')),
                      DataCell(Text('${e.preHd2.toStringAsFixed(1)} kg')),
                      DataCell(Text('${e.gain.toStringAsFixed(1)} kg')),
                      DataCell(Text('${e.gainPercent.toStringAsFixed(1)}%')),
                      DataCell(
                        _StatusBadge(
                          text: riskCategory(e.gainPercent),
                          color: riskColor(e.gainPercent),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => onEdit(e),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppColors.error,
                              ),
                              onPressed: () => onDelete(e),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }
}

class _MedicationTable extends StatelessWidget {
  final List<KidneyHealthRecord> records;
  final DateFormat dateFmt;
  final void Function(KidneyHealthRecord) onEdit;
  final void Function(KidneyHealthRecord) onDelete;

  const _MedicationTable({
    required this.records,
    required this.dateFmt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _TableCard(
      title: 'Tabel riwayat konsumsi obat',
      child: records.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Belum ada input obat.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                dataTextStyle: const TextStyle(fontSize: 12),
                columnSpacing: 18,
                columns: const [
                  DataColumn(label: Text('Tanggal')),
                  DataColumn(label: Text('Nama obat')),
                  DataColumn(label: Text('Bentuk')),
                  DataColumn(label: Text('Dosis')),
                  DataColumn(label: Text('Waktu minum')),
                  DataColumn(label: Text('Kaitan\nMakan')),
                  DataColumn(label: Text('Kaitan\nHD')),
                  DataColumn(label: Text('Catatan')),
                  DataColumn(label: Text('Aksi')),
                ],
                rows: records.map((e) {
                  final p = e.payload;
                  final period = (p['period'] ?? '').toString();
                  final mealTiming = (p['mealTiming'] ?? '').toString();
                  final hdTiming = (p['hdTiming'] ?? '').toString();
                  return DataRow(
                    cells: [
                      DataCell(Text(dateFmt.format(e.date))),
                      DataCell(Text((p['name'] ?? '-').toString())),
                      DataCell(Text((p['form'] ?? '-').toString())),
                      DataCell(Text((p['dose'] ?? '-').toString())),
                      DataCell(Text(period.isNotEmpty ? period : '-')),
                      DataCell(Text(mealTiming.isNotEmpty ? mealTiming : '-')),
                      DataCell(Text(hdTiming.isNotEmpty ? hdTiming : '-')),
                      DataCell(Text((p['note'] ?? '-').toString())),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => onEdit(e),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: AppColors.error,
                              ),
                              onPressed: () => onDelete(e),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
    );
  }
}

class _SimpleListCard extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<KidneyHealthRecord> records;
  final IconData icon;
  final String Function(KidneyHealthRecord) buildLine;
  final void Function(KidneyHealthRecord) onEdit;
  final void Function(KidneyHealthRecord) onDelete;

  const _SimpleListCard({
    required this.title,
    required this.emptyText,
    required this.records,
    required this.icon,
    required this.buildLine,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _TableCard(
      title: title,
      child: records.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                emptyText,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            )
          : Column(
              children: records.take(5).map((r) {
                return ListTile(
                  dense: true,
                  leading: Icon(icon, size: 18, color: AppColors.textSecondary),
                  title: Text(buildLine(r), style: const TextStyle(fontSize: 12.5)),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit(r);
                      } else if (value == 'delete') {
                        onDelete(r);
                      }
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Hapus')),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _HeartOptionField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _HeartOptionField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (e) => ChoiceChip(
                  selected: value == e,
                  label: Text(e),
                  onSelected: (_) => onChanged(e),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _HeartHeader extends StatelessWidget {
  final VoidCallback onInput;

  const _HeartHeader({required this.onInput});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.heartColor.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.health_and_safety, color: AppColors.heartColor),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health Tracker Jantung',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Pantau gejala, aktivitas, obat, pemeriksaan, dan BB',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onInput,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: Colors.black),
                  SizedBox(width: 4),
                  Text('Input', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeartTrendCard extends StatelessWidget {
  final List<HeartHealthRecord> records;
  final double idealWeight;

  const _HeartTrendCard({required this.records, required this.idealWeight});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d/M');
    final spots = <FlSpot>[];
    final idealSpots = <FlSpot>[];
    for (var i = 0; i < records.length; i++) {
      final p = records[i].payload;
      final dynamic rawBb = p['bb'];
      final double bb = (rawBb is num ? rawBb.toDouble() : null) ??
          (double.tryParse((p['bb'] ?? '').toString()) ??
              records[i].weight);
      spots.add(FlSpot(i.toDouble(), bb));
      idealSpots.add(FlSpot(i.toDouble(), idealWeight));
    }

    final maxActual = spots.isEmpty
        ? 60.0
        : spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final maxIdeal = idealSpots.isEmpty
        ? 60.0
        : idealSpots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final maxY = ((maxActual > maxIdeal ? maxActual : maxIdeal) * 1.2)
        .clamp(10.0, 200.0)
        .toDouble();

    return _TableCard(
      title: 'Trend BB Mingguan',
      child: SizedBox(
        height: 240,
        child: records.isEmpty
            ? const Center(
                child: Text(
                  'Belum ada data berat badan.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (spots.length - 1).toDouble(),
                    minY: 0,
                    maxY: maxY,
                    clipData: const FlClipData.all(),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: AppColors.divider,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= records.length) return const SizedBox();
                            if (records.length > 6 && i.isOdd) return const SizedBox();
                            return Text(
                              dateFmt.format(records[i].date),
                              style: const TextStyle(fontSize: 9),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (v, m) => Text(
                            v.toInt().toString(),
                            style: const TextStyle(fontSize: 9),
                          ),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: const Color(0xFF6B1414).withValues(alpha: 0.18),
                        barWidth: 7,
                        dotData: const FlDotData(show: false),
                      ),
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: const Color(0xFF6B1414),
                        barWidth: 2.4,
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFF6B1414).withValues(alpha: 0.08),
                        ),
                        dotData: const FlDotData(show: true),
                      ),
                      LineChartBarData(
                        spots: idealSpots,
                        isCurved: false,
                        color: Colors.redAccent,
                        barWidth: 2,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _HeartSymptomTable extends StatelessWidget {
  final List<HeartHealthRecord> records;
  final DateFormat dateFmt;
  final void Function(HeartHealthRecord) onEdit;
  final void Function(HeartHealthRecord) onDelete;

  const _HeartSymptomTable({
    required this.records,
    required this.dateFmt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _TableCard(
      title: 'Tabel gejala jantung',
      child: records.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Belum ada input gejala.', style: TextStyle(color: AppColors.textSecondary)),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('Tgl')),
                  DataColumn(label: Text('Sesak\nNafas')),
                  DataColumn(label: Text('Bagian\nBengkak')),
                  DataColumn(label: Text('Cepat\nLelah')),
                  DataColumn(label: Text('BB')),
                  DataColumn(label: Text('Kategori')),
                  DataColumn(label: Text('Aksi')),
                ],
                rows: records.map((r) {
                  final p = r.payload;
                  final sesak = (p['sesakNafas'] ?? '-').toString();
                  final bengkak = (p['bengkak'] ?? '-').toString();
                  final cepatLelah = (p['cepatLelah'] ?? '-').toString();
                  final category = (p['category'] ?? '').toString().isNotEmpty
                      ? (p['category'] ?? '').toString()
                      : (sesak == 'Berat' || bengkak == 'Berat')
                          ? 'Berat'
                          : (sesak == 'Ringan' ||
                                  bengkak == 'Ringan' ||
                                  cepatLelah == 'Ya')
                              ? 'Sedang'
                              : 'Ringan';
                  final categoryColor = category == 'Berat'
                      ? AppColors.error
                      : category == 'Sedang'
                          ? AppColors.warning
                          : AppColors.success;
                  return DataRow(cells: [
                    DataCell(Text(dateFmt.format(r.date))),
                    DataCell(Text(sesak)),
                    DataCell(Text(bengkak)),
                    DataCell(Text(cepatLelah)),
                    DataCell(Text((p['bb'] ?? '-').toString())),
                    DataCell(_StatusBadge(text: category, color: categoryColor)),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => onEdit(r),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                          onPressed: () => onDelete(r),
                        ),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
    );
  }
}

class _HeartMedicationTable extends StatelessWidget {
  final List<HeartHealthRecord> records;
  final DateFormat dateFmt;
  final void Function(HeartHealthRecord) onEdit;
  final void Function(HeartHealthRecord) onDelete;

  const _HeartMedicationTable({
    required this.records,
    required this.dateFmt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _TableCard(
      title: 'Tabel riwayat konsumsi obat',
      child: records.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Belum ada input obat.', style: TextStyle(color: AppColors.textSecondary)),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('Tgl')),
                  DataColumn(label: Text('Nama\nobat')),
                  DataColumn(label: Text('Dosis')),
                  DataColumn(label: Text('Waktu\nminum')),
                  DataColumn(label: Text('Sudah\ndiminum')),
                  DataColumn(label: Text('Catatan')),
                  DataColumn(label: Text('Aksi')),
                ],
                rows: records.map((r) {
                  final p = r.payload;
                  return DataRow(cells: [
                    DataCell(Text(dateFmt.format(r.date))),
                    DataCell(Text((p['name'] ?? '-').toString())),
                    DataCell(Text((p['dose'] ?? '-').toString())),
                    DataCell(Text((p['period'] ?? '-').toString())),
                    DataCell(Text((p['consumed'] ?? '-').toString())),
                    DataCell(Text((p['note'] ?? '-').toString())),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => onEdit(r),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                          onPressed: () => onDelete(r),
                        ),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
    );
  }
}

class _HeartActivityTable extends StatelessWidget {
  final List<HeartHealthRecord> records;
  final DateFormat dateFmt;
  final void Function(HeartHealthRecord) onEdit;
  final void Function(HeartHealthRecord) onDelete;

  const _HeartActivityTable({
    required this.records,
    required this.dateFmt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _TableCard(
      title: 'Tabel Aktivitas',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 14,
          columns: const [
            DataColumn(label: Text('Tgl')),
            DataColumn(label: Text('Jenis aktivitas')),
            DataColumn(label: Text('Durasi')),
            DataColumn(label: Text('Keluhan')),
            DataColumn(label: Text('Aksi')),
          ],
          rows: records.map((r) {
            final p = r.payload;
            final complaint = (p['complaint'] ?? 'Normal').toString();
            final complaintColor =
                complaint == 'Normal' ? AppColors.success : AppColors.error;

            return DataRow(cells: [
              DataCell(Text(dateFmt.format(r.date))),
              DataCell(Text((p['activityName'] ?? '-').toString())),
              DataCell(Text('${p['duration'] ?? '-'} mnt')),
              DataCell(_StatusBadge(text: complaint, color: complaintColor)),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => onEdit(r),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AppColors.error,
                      ),
                      onPressed: () => onDelete(r),
                    ),
                  ],
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

class _HeartCheckupTable extends StatelessWidget {
  final List<HeartHealthRecord> records;
  final DateFormat dateFmt;
  final void Function(HeartHealthRecord) onEdit;
  final void Function(HeartHealthRecord) onDelete;

  const _HeartCheckupTable({
    required this.records,
    required this.dateFmt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _TableCard(
      title: 'Riwayat Pemeriksaan',
      child: records.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Belum ada input pemeriksaan.', style: TextStyle(color: AppColors.textSecondary)),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('Tgl')),
                  DataColumn(label: Text('Jenis')),
                  DataColumn(label: Text('Pemeriksaan')),
                  DataColumn(label: Text('Hasil')),
                  DataColumn(label: Text('Kategori')),
                  DataColumn(label: Text('Aksi')),
                ],
                rows: records.map((r) {
                  final p = r.payload;
                  String examType = (p['examType'] ?? '-').toString();
                  if ((p['sampleTime'] ?? '').toString().isNotEmpty) {
                    examType = '$examType (${p['sampleTime']})';
                  }
                  final result = (p['result'] ?? '-').toString();
                  final unit = (p['unit'] ?? '').toString();
                  return DataRow(cells: [
                    DataCell(Text(dateFmt.format(r.date))),
                    DataCell(Text(examType)),
                    DataCell(Text((p['exam'] ?? '-').toString())),
                    DataCell(Text(unit.isNotEmpty ? '$result $unit' : result)),
                    DataCell(
                      _StatusBadge(
                        text: (p['category'] ?? '-').toString(),
                        color: _checkupCategoryColor(
                          (p['category'] ?? '').toString(),
                        ),
                      ),
                    ),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => onEdit(r),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                          onPressed: () => onDelete(r),
                        ),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
    );
  }
}

class _KidneyCheckupTable extends StatelessWidget {
  final List<KidneyHealthRecord> records;
  final DateFormat dateFmt;
  final void Function(KidneyHealthRecord) onEdit;
  final void Function(KidneyHealthRecord) onDelete;

  const _KidneyCheckupTable({
    required this.records,
    required this.dateFmt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _TableCard(
      title: 'Riwayat Pemeriksaan',
      child: records.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Belum ada input pemeriksaan.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('Tgl')),
                  DataColumn(label: Text('Jenis')),
                  DataColumn(label: Text('Pemeriksaan')),
                  DataColumn(label: Text('Hasil')),
                  DataColumn(label: Text('Kategori')),
                  DataColumn(label: Text('Aksi')),
                ],
                rows: records.map((r) {
                  final p = r.payload;

                  final isLegacy = !(p.containsKey('exam') || p.containsKey('examType'));
                  final examType = isLegacy
                      ? 'Fisik'
                      : (p['examType'] ?? '-').toString();
                  final exam = isLegacy ? 'Paket CKD' : (p['exam'] ?? '-').toString();
                  final legacy = <String>[];
                  if ((p['bloodPressure'] ?? '').toString().isNotEmpty) {
                    legacy.add('TD ${(p['bloodPressure'] ?? '-')}');
                  }
                  if ((p['hb'] ?? '').toString().isNotEmpty) {
                    legacy.add('Hb ${(p['hb'] ?? '-')}');
                  }
                  if ((p['ureum'] ?? '').toString().isNotEmpty) {
                    legacy.add('Ureum ${(p['ureum'] ?? '-')}');
                  }
                  if ((p['kreatinin'] ?? '').toString().isNotEmpty) {
                    legacy.add('Kreatinin ${(p['kreatinin'] ?? '-')}');
                  }

                  final result = isLegacy
                      ? (legacy.isEmpty ? '-' : legacy.join(' • '))
                      : (p['result'] ?? '-').toString();
                  final unit = isLegacy ? '' : (p['unit'] ?? '').toString();
                  final category = (p['category'] ?? '-').toString();

                  return DataRow(cells: [
                    DataCell(Text(dateFmt.format(r.date))),
                    DataCell(Text(examType)),
                    DataCell(Text(exam)),
                    DataCell(Text(unit.isNotEmpty ? '$result $unit' : result)),
                    DataCell(
                      _StatusBadge(
                        text: category,
                        color: _checkupCategoryColor(category),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => onEdit(r),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppColors.error,
                            ),
                            onPressed: () => onDelete(r),
                          ),
                        ],
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
    );
  }
}

class _DiabetesHeader extends StatelessWidget {
  final VoidCallback onInput;

  const _DiabetesHeader({required this.onInput});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.diabetesColor.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.health_and_safety, color: AppColors.diabetesColor),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health Tracker Diabetes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Pantau aktivitas, pemeriksaan, dan analisis insulin',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onInput,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: Colors.black),
                  SizedBox(width: 4),
                  Text('Input', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiabetesInsulinSummaryTable extends StatefulWidget {
  final List<DiabetesHealthRecord> records;
  final DateFormat dateFmt;
  final String uid;
  final Future<void> Function() onDataChanged;
  final void Function(DiabetesHealthRecord) onEdit;
  final void Function(DiabetesHealthRecord) onDelete;

  const _DiabetesInsulinSummaryTable({
    required this.records,
    required this.dateFmt,
    required this.uid,
    required this.onDataChanged,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_DiabetesInsulinSummaryTable> createState() =>
      _DiabetesInsulinSummaryTableState();
}

class _DiabetesInsulinSummaryTableState extends State<_DiabetesInsulinSummaryTable> {
  static const List<String> _mealOrder = [
    'Sarapan',
    'Selingan Pagi',
    'Makan Siang',
    'Selingan Siang',
    'Makan Malam',
    'Selingan Malam',
  ];

  DateTime _selectedDate = DateTime.now();
  bool _isSyncLoading = false;
  bool _isTableLoading = false;
  List<FoodLogEntry> _entriesOnDate = [];
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _loadFoodEntriesForDate();
  }

  @override
  void didUpdateWidget(covariant _DiabetesInsulinSummaryTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _loadFoodEntriesForDate();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _isToday {
    final now = DateTime.now();
    return _isSameDay(now, _selectedDate);
  }

  DateTime get _normalizedSelectedDate =>
      DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

  Future<void> _loadFoodEntriesForDate() async {
    if (widget.uid.isEmpty) {
      setState(() {
        _entriesOnDate = [];
        _isTableLoading = false;
        _syncError = null;
      });
      return;
    }

    setState(() {
      _isTableLoading = true;
      _syncError = null;
    });

    try {
      final entries = await FoodLogService.getEntries(widget.uid, _normalizedSelectedDate);
      if (!mounted) return;
      setState(() {
        _entriesOnDate = entries;
        _isTableLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _entriesOnDate = [];
        _isTableLoading = false;
        _syncError = 'Gagal sinkronisasi data makanan untuk tanggal ini.';
      });
    }
  }

  List<MealType> _mapMealLabelToTypes(String mealLabel) {
    switch (mealLabel) {
      case 'Sarapan':
        return const [MealType.sarapan];
      case 'Selingan Pagi':
        return const [MealType.selinganPagi];
      case 'Makan Siang':
        return const [MealType.makanSiang];
      case 'Selingan Siang':
        return const [MealType.selinganSiang];
      case 'Makan Malam':
        return const [MealType.makanMalam];
      case 'Selingan Malam':
        return const [MealType.selinganMalam];
      default:
        return const [MealType.sarapan];
    }
  }

  int _foodCountForMeal(String mealLabel) {
    final targetTypes = _mapMealLabelToTypes(mealLabel);
    return _entriesOnDate.where((entry) => targetTypes.contains(entry.mealType)).length;
  }

  ({double carb, double gl}) _autoCarbAndGl(String mealLabel) {
    final targetTypes = _mapMealLabelToTypes(mealLabel);
    final rows = _entriesOnDate.where((entry) => targetTypes.contains(entry.mealType));
    final carb = rows.fold<double>(0.0, (sum, e) => sum + e.karbohidrat);
    final fiber = rows.fold<double>(0.0, (sum, e) => sum + e.serat);
    final netCarb = (carb - fiber).clamp(0.0, double.infinity);
    return (carb: carb, gl: netCarb * 0.5);
  }

  DiabetesHealthRecord? _recordByMeal(String mealLabel) {
    final dateRecords = widget.records.where((r) => _isSameDay(r.date, _normalizedSelectedDate));
    final allowedLabels = <String>{mealLabel};
    if (mealLabel == 'Selingan Siang') {
      // Backward compatibility: old records used a single "Snack" label.
      allowedLabels.add('Snack');
    }
    final byMeal = dateRecords.where((r) => allowedLabels.contains((r.payload['meal'] ?? '').toString())).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return byMeal.isEmpty ? null : byMeal.first;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0.0;
  }

  String _categoryFromDiff(double diff) {
    if (diff.abs() <= 1.0) return 'Balance';
    if (diff > 1.0) return 'Lebih';
    return 'Kurang';
  }

  Future<void> _syncRow(DiabetesHealthRecord record, String mealLabel) async {
    if (widget.uid.isEmpty) return;
    setState(() => _isSyncLoading = true);
    try {
      final auto = _autoCarbAndGl(mealLabel);
      final p = record.payload;
      final basal = _toDouble(p['insulinBasal']);
      final prandial = _toDouble(p['insulinPrandial']);
      final totalInsulin = basal + prandial;
      final icr = totalInsulin <= 0 ? 0.0 : 500 / totalInsulin;
      final estimasi = icr <= 0 ? 0.0 : auto.carb / icr;
      final aktual = _toDouble(p['dosisAktual']);
      final diff = aktual - estimasi;
      final category = _categoryFromDiff(diff);

      final updated = DiabetesHealthRecord(
        id: record.id,
        type: record.type,
        date: record.date,
        createdAt: record.createdAt,
        payload: {
          ...p,
          'meal': mealLabel,
          'totalInsulin': totalInsulin,
          'icr': icr,
          'karbohidratMakan': auto.carb,
          'gl': auto.gl,
          'estimasiInsulin': estimasi,
          'selisih': diff,
          'category': category,
        },
      );

      await DiabetesHealthService.updateRecord(widget.uid, updated);
      await widget.onDataChanged();
      await _loadFoodEntriesForDate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sinkronisasi $mealLabel berhasil.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sinkronisasi gagal. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _isSyncLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateRecords = widget.records.where((r) => _isSameDay(r.date, _normalizedSelectedDate)).toList();
    final visibleMeals = _mealOrder.where((mealLabel) => _foodCountForMeal(mealLabel) > 0).toList();

    return _TableCard(
      title: 'Analisis Insulin (DM)',
      child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                          });
                          _loadFoodEntriesForDate();
                        },
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              _isToday
                                  ? 'Hari Ini · ${widget.dateFmt.format(_selectedDate)}'
                                  : widget.dateFmt.format(_selectedDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${dateRecords.length} data insulin',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _isToday
                            ? null
                            : () {
                                setState(() {
                                  _selectedDate = _selectedDate.add(const Duration(days: 1));
                                });
                                _loadFoodEntriesForDate();
                              },
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                if (_syncError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _syncError!,
                    style: const TextStyle(fontSize: 11, color: AppColors.error),
                  ),
                ],
                const SizedBox(height: 10),
                if (_isTableLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (visibleMeals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Belum ada input makanan pada tanggal ini, jadi tabel analisis belum ditampilkan.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Text(
                          'Keterangan: Biru (belum input), Kuning (perlu update), Hijau (sinkron/aman).',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                      columnSpacing: 14,
                      columns: const [
                        DataColumn(label: Text('Makan')),
                        DataColumn(label: Text('Karbo\n(Auto)')),
                        DataColumn(label: Text('GL\n(Auto)')),
                        DataColumn(label: Text('Basal')),
                        DataColumn(label: Text('Prandial')),
                        DataColumn(label: Text('Aktual')),
                        DataColumn(label: Text('Estimasi')),
                        DataColumn(label: Text('Selisih')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Kategori')),
                        DataColumn(label: Text('Aksi')),
                      ],
                      rows: visibleMeals.map((mealLabel) {
                        final auto = _autoCarbAndGl(mealLabel);
                        final r = _recordByMeal(mealLabel);
                        final p = r?.payload ?? const <String, dynamic>{};

                        final basal = _toDouble(p['insulinBasal']);
                        final prandial = _toDouble(p['insulinPrandial']);
                        final aktual = _toDouble(p['dosisAktual']);
                        final totalInsulin = basal + prandial;
                        final icr = totalInsulin <= 0 ? 0.0 : 500 / totalInsulin;
                        final estimasi = icr <= 0 ? 0.0 : auto.carb / icr;
                        final diff = aktual - estimasi;
                        final computedCategory = _categoryFromDiff(diff);

                        final storedCarb = _toDouble(p['karbohidratMakan']);
                        final storedGl = _toDouble(p['gl']);
                        final isSynced = r != null &&
                            (storedCarb - auto.carb).abs() < 0.1 &&
                            (storedGl - auto.gl).abs() < 0.1;
                        final statusText = r == null
                            ? 'Belum input'
                            : isSynced
                                ? 'Sinkron'
                                : 'Perlu update';
                        final statusColor = r == null
                            ? AppColors.warning
                            : isSynced
                                ? AppColors.success
                                : AppColors.warning;

                        return DataRow(
                          color: (statusText == 'Perlu update' ||
                                  statusText == 'Belum input')
                              ? MaterialStatePropertyAll<Color?>(
                                  statusText == 'Belum input' 
                                    ? Colors.blue.withValues(alpha: 0.12)
                                    : AppColors.warning.withValues(alpha: 0.14),
                                )
                              : null,
                          cells: [
                            DataCell(Text(mealLabel)),
                            DataCell(Text('${auto.carb.toStringAsFixed(1)} g')),
                            DataCell(Text(auto.gl.toStringAsFixed(1))),
                            DataCell(Text(r == null ? '-' : basal.toStringAsFixed(1))),
                            DataCell(Text(r == null ? '-' : prandial.toStringAsFixed(1))),
                            DataCell(Text(r == null ? '-' : aktual.toStringAsFixed(1))),
                            DataCell(Text(r == null ? '-' : estimasi.toStringAsFixed(1))),
                            DataCell(Text(r == null ? '-' : diff.toStringAsFixed(1))),
                            DataCell(_StatusBadge(text: statusText, color: statusColor)),
                            DataCell(
                              r == null
                                  ? const Text('-')
                                  : _StatusBadge(
                                      text: computedCategory,
                                      color: computedCategory == 'Balance'
                                          ? AppColors.success
                                          : computedCategory == 'Lebih'
                                              ? AppColors.warning
                                              : AppColors.error,
                                    ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (r != null) ...[
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Edit',
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      onPressed: () => widget.onEdit(r),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Sinkronkan dari food',
                                      icon: _isSyncLoading
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.sync, size: 18),
                                      onPressed: _isSyncLoading ? null : () => _syncRow(r, mealLabel),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Hapus',
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: AppColors.error,
                                      ),
                                      onPressed: () => widget.onDelete(r),
                                    ),
                                  ] else
                                    const Text(
                                      'Isi via form',
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}

class _DiabetesCheckupTable extends StatelessWidget {
  final List<DiabetesHealthRecord> records;
  final DateFormat dateFmt;
  final void Function(DiabetesHealthRecord) onEdit;
  final void Function(DiabetesHealthRecord) onDelete;

  const _DiabetesCheckupTable({
    required this.records,
    required this.dateFmt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _TableCard(
      title: 'Riwayat Pemeriksaan',
      child: records.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Belum ada input pemeriksaan.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('Tgl')),
                  DataColumn(label: Text('Jenis')),
                  DataColumn(label: Text('Pemeriksaan')),
                  DataColumn(label: Text('Hasil')),
                  DataColumn(label: Text('Kategori')),
                  DataColumn(label: Text('Aksi')),
                ],
                rows: records.map((r) {
                  final p = r.payload;
                  String examType = (p['examType'] ?? '-').toString();
                  if ((p['sampleTime'] ?? '').toString().isNotEmpty) {
                    examType = '$examType (${p['sampleTime']})';
                  }
                  final result = (p['result'] ?? '-').toString();
                  final unit = (p['unit'] ?? '').toString();
                  final category = (p['category'] ?? '-').toString();

                  return DataRow(cells: [
                    DataCell(Text(dateFmt.format(r.date))),
                    DataCell(Text(examType)),
                    DataCell(Text((p['exam'] ?? '-').toString())),
                    DataCell(Text(unit.isNotEmpty ? '$result $unit' : result)),
                    DataCell(
                      _StatusBadge(
                        text: category,
                        color: _checkupCategoryColor(category),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => onEdit(r),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppColors.error,
                            ),
                            onPressed: () => onDelete(r),
                          ),
                        ],
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
    );
  }
}

class _DiabetesActivityTable extends StatelessWidget {
  final List<DiabetesHealthRecord> records;
  final DateFormat dateFmt;
  final void Function(DiabetesHealthRecord) onEdit;
  final void Function(DiabetesHealthRecord) onDelete;

  const _DiabetesActivityTable({
    required this.records,
    required this.dateFmt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _TableCard(
      title: 'Tabel Aktivitas',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 14,
          columns: const [
            DataColumn(label: Text('Tgl')),
            DataColumn(label: Text('Jenis aktivitas')),
            DataColumn(label: Text('Durasi')),
            DataColumn(label: Text('Keluhan')),
            DataColumn(label: Text('Aksi')),
          ],
          rows: records.map((r) {
            final p = r.payload;
            final complaint = (p['complaint'] ?? 'Normal').toString();
            final complaintColor =
                complaint == 'Normal' ? AppColors.success : AppColors.error;

            return DataRow(cells: [
              DataCell(Text(dateFmt.format(r.date))),
              DataCell(Text((p['activityName'] ?? '-').toString())),
              DataCell(Text('${p['duration'] ?? '-'} mnt')),
              DataCell(_StatusBadge(text: complaint, color: complaintColor)),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => onEdit(r),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AppColors.error,
                      ),
                      onPressed: () => onDelete(r),
                    ),
                  ],
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

class _InsulinGuideButtonCard extends StatelessWidget {
  const _InsulinGuideButtonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Panduan Analisis Insulin',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  title: const Text('Analisis Keseimbangan Insulin (Detail)'),
                  content: SizedBox(
                    width: 760,
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 14,
                          columns: [
                            DataColumn(label: Text('No')),
                            DataColumn(label: Text('Komponen Perhitungan')),
                            DataColumn(label: Text('Simbol')),
                            DataColumn(label: Text('Cara Perolehan Data')),
                            DataColumn(label: Text('Rumus / Keterangan')),
                            DataColumn(label: Text('Skala')),
                          ],
                          rows: [
                            DataRow(cells: [
                              DataCell(Text('1')),
                              DataCell(Text('Insulin basal harian')),
                              DataCell(Text('A')),
                              DataCell(Text('Input manual responden')),
                              DataCell(Text('Total insulin basal per hari (unit)')),
                              DataCell(Text('Rasio')),
                            ]),
                            DataRow(cells: [
                              DataCell(Text('2')),
                              DataCell(Text('Insulin prandial harian')),
                              DataCell(Text('B')),
                              DataCell(Text('Input manual responden')),
                              DataCell(Text('Total insulin prandial per hari (unit)')),
                              DataCell(Text('Rasio')),
                            ]),
                            DataRow(cells: [
                              DataCell(Text('3')),
                              DataCell(Text('Total dosis insulin harian')),
                              DataCell(Text('C')),
                              DataCell(Text('Otomatis aplikasi')),
                              DataCell(Text('C = A + B')),
                              DataCell(Text('Rasio')),
                            ]),
                            DataRow(cells: [
                              DataCell(Text('4')),
                              DataCell(Text('Insulin to Carbohydrate Ratio')),
                              DataCell(Text('D')),
                              DataCell(Text('Otomatis aplikasi')),
                              DataCell(Text('D = 500 / C')),
                              DataCell(Text('Rasio')),
                            ]),
                            DataRow(cells: [
                              DataCell(Text('5')),
                              DataCell(Text('Total karbohidrat makan')),
                              DataCell(Text('-')),
                              DataCell(Text('Input/estimasi makanan')),
                              DataCell(Text('Gram karbohidrat per waktu makan')),
                              DataCell(Text('Rasio')),
                            ]),
                            DataRow(cells: [
                              DataCell(Text('6')),
                              DataCell(Text('Estimasi dosis insulin makan')),
                              DataCell(Text('E')),
                              DataCell(Text('Otomatis aplikasi')),
                              DataCell(Text('Karbohidrat / D')),
                              DataCell(Text('Rasio')),
                            ]),
                            DataRow(cells: [
                              DataCell(Text('7')),
                              DataCell(Text('Dosis insulin aktual')),
                              DataCell(Text('F')),
                              DataCell(Text('Input manual responden')),
                              DataCell(Text('Dosis insulin sebelum makan')),
                              DataCell(Text('Rasio')),
                            ]),
                            DataRow(cells: [
                              DataCell(Text('8')),
                              DataCell(Text('Selisih dosis insulin')),
                              DataCell(Text('F-E')),
                              DataCell(Text('Otomatis aplikasi')),
                              DataCell(Text('Aktual dikurangi estimasi')),
                              DataCell(Text('Rasio')),
                            ]),
                            DataRow(cells: [
                              DataCell(Text('9')),
                              DataCell(Text('Kategori kesesuaian')),
                              DataCell(Text('-')),
                              DataCell(Text('Otomatis aplikasi')),
                              DataCell(Text('Berdasarkan nilai selisih')),
                              DataCell(Text('Ordinal')),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Lihat detail analisis insulin'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.diabetesColor,
              side: BorderSide(color: AppColors.diabetesColor.withValues(alpha: 0.45)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NormalValuesButtonCard extends StatelessWidget {
  final DiseaseType diseaseType;

  const _NormalValuesButtonCard({required this.diseaseType});

  @override
  Widget build(BuildContext context) {
    final accent = diseaseType == DiseaseType.heartFailure
        ? AppColors.heartColor
        : diseaseType == DiseaseType.type2DiabetesMellitus
            ? AppColors.diabetesColor
        : AppColors.kidneyColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Referensi Pemeriksaan',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  title: const Text('Tabel nilai normal pemeriksaan'),
                  content: SizedBox(
                    width: 680,
                    child: _NormalValuesTableContent(diseaseType: diseaseType),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.table_view_outlined),
            label: const Text('Lihat tabel nilai normal'),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent.withValues(alpha: 0.45)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NormalValuesTableContent extends StatelessWidget {
  final DiseaseType diseaseType;

  const _NormalValuesTableContent({required this.diseaseType});

  @override
  Widget build(BuildContext context) {
    final rows = _examReferencesForDiseaseType(diseaseType);

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 18,
          columns: [
            DataColumn(label: Text('Pemeriksaan')),
            DataColumn(label: Text('Satuan')),
            DataColumn(label: Text('Nilai normal')),
          ],
          rows: rows
              .map(
                (e) => DataRow(
                  cells: [
                    DataCell(Text('${e.group} • ${e.name}')),
                    DataCell(Text(e.unit.isEmpty ? '-' : e.unit)),
                    DataCell(Text(e.normal)),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _ExamReference {
  final String id;
  final String group;
  final String name;
  final String unit;
  final String normal;
  final bool forKidney;
  final bool forHeart;
  final bool forDiabetes;

  const _ExamReference({
    required this.id,
    required this.group,
    required this.name,
    required this.unit,
    required this.normal,
    required this.forKidney,
    required this.forHeart,
    this.forDiabetes = false,
  });
}

const List<_ExamReference> _examReferenceCatalog = [
  _ExamReference(
    id: 'bb',
    group: 'Fisik',
    name: 'Berat Badan',
    unit: 'kg',
    normal: '-',
    forKidney: false,
    forHeart: true,
    forDiabetes: true,
  ),
  _ExamReference(
    id: 'tb',
    group: 'Fisik',
    name: 'Tinggi badan',
    unit: 'cm',
    normal: '-',
    forKidney: true,
    forHeart: true,
    forDiabetes: true,
  ),
  _ExamReference(
    id: 'suhu',
    group: 'Fisik',
    name: 'Suhu',
    unit: '°C',
    normal: '36,5–37,5',
    forKidney: true,
    forHeart: true,
    forDiabetes: true,
  ),
  _ExamReference(
    id: 'td',
    group: 'Fisik',
    name: 'Tekanan Darah',
    unit: 'mmHg',
    normal: '< 120/80',
    forKidney: true,
    forHeart: true,
    forDiabetes: true,
  ),
  _ExamReference(
    id: 'spo2',
    group: 'Fisik',
    name: 'Saturasi Oksigen',
    unit: '%',
    normal: '95 - 100',
    forKidney: true,
    forHeart: true,
    forDiabetes: true,
  ),
  _ExamReference(
    id: 'nadi',
    group: 'Fisik',
    name: 'Denyut nadi',
    unit: 'x/menit',
    normal: '60 - 100',
    forKidney: true,
    forHeart: true,
    forDiabetes: true,
  ),
  _ExamReference(
    id: 'urin_protein',
    group: 'Urin',
    name: 'Protein urin',
    unit: '',
    normal: 'Negatif',
    forKidney: true,
    forHeart: false,
  ),
  _ExamReference(
    id: 'urin_ph',
    group: 'Urin',
    name: 'pH urin',
    unit: '',
    normal: '4,5 - 8,0',
    forKidney: true,
    forHeart: false,
  ),
  _ExamReference(
    id: 'urin_hb',
    group: 'Urin',
    name: 'Hb urin',
    unit: '',
    normal: 'Negatif',
    forKidney: true,
    forHeart: false,
  ),
  _ExamReference(
    id: 'gdp',
    group: 'Darah',
    name: 'Gula darah puasa',
    unit: 'mg/dL',
    normal: '70 - 110',
    forKidney: false,
    forHeart: false,
    forDiabetes: true,
  ),
  _ExamReference(
    id: 'gds',
    group: 'Darah',
    name: 'Gula darah sewaktu',
    unit: 'mg/dL',
    normal: '< 200',
    forKidney: false,
    forHeart: false,
    forDiabetes: true,
  ),
  _ExamReference(
    id: 'hba1c',
    group: 'Darah',
    name: 'HbA1c',
    unit: '%',
    normal: '< 5,7',
    forKidney: false,
    forHeart: false,
    forDiabetes: true,
  ),
  _ExamReference(
    id: 'chol_total',
    group: 'Darah',
    name: 'Kolesterol Total',
    unit: 'mg/dL',
    normal: '<200',
    forKidney: false,
    forHeart: true,
  ),
  _ExamReference(
    id: 'hdl',
    group: 'Darah',
    name: 'HDL',
    unit: 'mg/dL',
    normal: '<4,5',
    forKidney: false,
    forHeart: true,
  ),
  _ExamReference(
    id: 'ldl',
    group: 'Darah',
    name: 'LDL',
    unit: 'mg/dL',
    normal: '<100',
    forKidney: false,
    forHeart: true,
  ),
  _ExamReference(
    id: 'trigliserida',
    group: 'Darah',
    name: 'Trigliserida',
    unit: 'mg/dL',
    normal: '<150',
    forKidney: false,
    forHeart: true,
  ),
  _ExamReference(
    id: 'natrium',
    group: 'Darah',
    name: 'Natrium',
    unit: 'mmol/L',
    normal: '135 - 145',
    forKidney: true,
    forHeart: true,
  ),
  _ExamReference(
    id: 'ureum',
    group: 'Darah',
    name: 'Ureum',
    unit: 'mg/dL',
    normal: '10 - 50',
    forKidney: true,
    forHeart: true,
  ),
  _ExamReference(
    id: 'kreatinin',
    group: 'Darah',
    name: 'Kreatinin',
    unit: 'mg/dL',
    normal: 'L: 0,7 - 1,3 • P: 0,6 - 1,1',
    forKidney: true,
    forHeart: true,
  ),
  _ExamReference(
    id: 'kalium',
    group: 'Darah',
    name: 'Kalium',
    unit: 'mmol/L',
    normal: '3,5 - 5,1',
    forKidney: true,
    forHeart: true,
  ),
  _ExamReference(
    id: 'fosfat',
    group: 'Darah',
    name: 'Fosfat',
    unit: 'mg/dL',
    normal: '2,5 - 4,5',
    forKidney: true,
    forHeart: false,
  ),
  _ExamReference(
    id: 'albumin',
    group: 'Darah',
    name: 'Albumin',
    unit: 'g/dL',
    normal: '3,5 - 5,0',
    forKidney: true,
    forHeart: false,
  ),
  _ExamReference(
    id: 'hb_darah',
    group: 'Darah',
    name: 'Hemoglobin (Hb)',
    unit: 'g/dL',
    normal: 'L: 13,0 - 16,0 • P: 12,0 - 14,0',
    forKidney: true,
    forHeart: true,
  ),
  _ExamReference(
    id: 'ht',
    group: 'Darah',
    name: 'Hematokrit (Ht)',
    unit: '%',
    normal: 'L: 40 - 50 • P: 36 - 44',
    forKidney: true,
    forHeart: true,
  ),
];

List<_ExamReference> _examReferencesForDiseaseType(DiseaseType diseaseType) {
  return _examReferenceCatalog.where((e) {
    if (diseaseType == DiseaseType.chronicKidneyDisease) {
      return e.forKidney;
    }
    if (diseaseType == DiseaseType.heartFailure) {
      return e.forHeart;
    }
    if (diseaseType == DiseaseType.type2DiabetesMellitus) {
      return e.forDiabetes;
    }
    return false;
  }).toList();
}

class _ActivityInputResult {
  final DateTime date;
  final Map<String, dynamic> payload;

  const _ActivityInputResult({required this.date, required this.payload});
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

Color _checkupCategoryColor(String category) {
  switch (category.trim().toLowerCase()) {
    case 'tinggi':
    case 'tidak normal':
      return AppColors.error;
    case 'rendah':
      return AppColors.warning;
    case 'normal':
      return AppColors.success;
    default:
      return AppColors.textSecondary;
  }
}

class _TableCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _TableCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: child,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _EmptyTableState extends StatelessWidget {
  final String message;

  const _EmptyTableState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inbox_outlined,
              color: AppColors.textHint,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestReadOnlyBanner extends StatelessWidget {
  final String message;

  const _GuestReadOnlyBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.visibility_outlined, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY GAUGE WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityGauge extends StatelessWidget {
  final double totalDuration;
  final double target;
  final Color themeColor;
  final bool isWeekly;

  const _ActivityGauge({
    required this.totalDuration,
    this.target = 150.0, // Default 150 menit per minggu
    required this.themeColor,
    this.isWeekly = true,
  });

  double get _ratio => target > 0 ? totalDuration / target : 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            themeColor.withValues(alpha: 0.15),
            themeColor.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.directions_run_outlined, color: themeColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isWeekly ? 'Progres Aktivitas Mingguan' : 'Progres Aktivitas Harian',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.divider.withValues(alpha: 0.3),
                    ),
                  ),
                  CustomPaint(
                    painter: _CircleProgressPainter(
                      progress: _ratio.clamp(0.0, 1.0),
                      color: themeColor,
                      backgroundColor: AppColors.divider.withValues(alpha: 0.2),
                      strokeWidth: 12,
                    ),
                    size: const Size(180, 180),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        totalDuration.toInt().toString(),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'dari ${target.toInt()} mnt',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _statusText(),
        ],
      ),
    );
  }

  Widget _statusText() {
    String message = 'Yuk, mulai beraktivitas!';
    if (_ratio >= 1.0) {
      message = 'Target hari ini tercapai! Luar biasa.';
    } else if (_ratio >= 0.5) {
      message = 'Sedikit lagi mencapai target.';
    } else if (totalDuration > 0) {
      message = 'Terus bergerak, kamu pasti bisa!';
    }

    return Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _CircleProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // BG circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
