import 'dart:async';

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

  static final List<String> _activityOptions = [
    'Senam',
    'Jalan cepat',
    'Bersepeda',
    'Berenang',
    'Jogging/Lari',
  ];
  static final List<String> _activityComplaintOptions = [
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

  Color get _inputButtonForeground =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : const Color(0xFF0F172A);

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
      final fromDate = DateTime.now().subtract(Duration(days: 31));
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
      final fromDate = DateTime.now().subtract(Duration(days: 45));
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
      final fromDate = DateTime.now().subtract(Duration(days: 60));
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
        SnackBar(
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
        SnackBar(
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
        title: Text('Hapus data'),
        content: Text('Yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus', style: TextStyle(color: AppColors.error)),
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
        SnackBar(
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
        SnackBar(
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
        SnackBar(
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
        title: Text('Hapus data'),
        content: Text('Yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus', style: TextStyle(color: AppColors.error)),
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
        SnackBar(
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
        SnackBar(
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
        SnackBar(
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
        title: Text('Hapus data'),
        content: Text('Yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus', style: TextStyle(color: AppColors.error)),
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
        SnackBar(
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
      case DiabetesInputType.obat:
        updated = await _showDiabetesMedicationDialog(existing: record);
        break;
    }
    if (updated != null) {
      await _updateDmRecord(updated);
    }
  }

  Future<void> _showDmInputTypeSheet() async {
    final usesInsulinTherapy =
        context.read<AuthProvider>().currentUser?.usesInsulinTherapy ?? false;
    final type = await showModalBottomSheet<DiabetesInputType>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 14),
              Text(
                'Tambah Input Kesehatan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              ...DiabetesInputType.values
                  .where(
                    (t) =>
                        usesInsulinTherapy ||
                        t != DiabetesInputType.insulin,
                  )
                  .map(
                (t) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.diabetesColor.withValues(alpha: 0.12),
                    child: Icon(_dmTypeIcon(t), color: AppColors.diabetesColor),
                  ),
                  title: Text(t.label),
                  trailing: Icon(Icons.chevron_right),
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
        if (!usesInsulinTherapy) break;
        record = await _showInsulinAnalysisDialog();
        break;
      case DiabetesInputType.aktivitas:
        record = await _showDiabetesActivityDialog();
        break;
      case DiabetesInputType.obat:
        record = await _showDiabetesMedicationDialog();
        break;
    }

    if (record != null) {
      await _addDmRecord(record);
    }
  }

  Future<void> _showHeartInputTypeSheet() async {
    final type = await showModalBottomSheet<HeartInputType>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 14),
              Text(
                'Tambah Input Kesehatan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              ...HeartInputType.values
                  .where((t) => t != HeartInputType.beratBadan)
                  .map(
                (t) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.heartColor.withValues(alpha: 0.12),
                    child: Icon(_heartTypeIcon(t), color: AppColors.heartColor),
                  ),
                  title: Text(t.label),
                  trailing: Icon(Icons.chevron_right),
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
                      lastDate: DateTime.now().add(Duration(days: 1)),
                    );
                    if (picked != null) setLocalState(() => date = picked);
                  },
                ),
                SizedBox(height: 10),
                TextField(
                  controller: weightController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Berat badan (kg)'),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: idealController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Berat badan ideal (kg)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal')),
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
              child: Text('Simpan'),
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
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                      lastDate: DateTime.now().add(Duration(days: 1)),
                    );
                    if (picked != null) setLocalState(() => date = picked);
                  },
                ),
                SizedBox(height: 10),
                _HeartOptionField(
                  label: 'Sesak napas',
                  value: sesak,
                  options: ['Tidak', 'Ringan', 'Berat'],
                  onChanged: (v) => setLocalState(() => sesak = v),
                ),
                SizedBox(height: 8),
                _HeartOptionField(
                  label: 'Bagian tubuh bengkak',
                  value: bengkak,
                  options: ['Tidak', 'Ringan', 'Berat'],
                  onChanged: (v) => setLocalState(() => bengkak = v),
                ),
                SizedBox(height: 8),
                _HeartOptionField(
                  label: 'Cepat lelah',
                  value: cepatLelah,
                  options: ['Ya', 'Tidak'],
                  onChanged: (v) => setLocalState(() => cepatLelah = v),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: bbController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'BB (kg)'),
                ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal')),
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
              child: Text('Simpan'),
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
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                      lastDate: DateTime.now().add(Duration(days: 1)),
                    );
                    if (picked != null) setLocalState(() => date = picked);
                  },
                ),
                SizedBox(height: 10),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Nama obat'),
                ),
                SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: formType,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: 'Bentuk'),
                  items: [
                    DropdownMenuItem(value: 'Tablet', child: Text('Tablet')),
                    DropdownMenuItem(value: 'Kapsul', child: Text('Kapsul')),
                    DropdownMenuItem(value: 'Sirup', child: Text('Sirup')),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocalState(() => formType = v);
                  },
                ),
                SizedBox(height: 8),
                Text(
                  'Format dosis: ... x ... (... mg/ml/g)',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: doseFreqController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Frekuensi'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('x'),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: doseQtyController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Jumlah'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: doseStrengthController,
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'Kadar'),
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 110,
                      child: DropdownButtonFormField<String>(
                        initialValue: doseUnit,
                        decoration: InputDecoration(labelText: 'Satuan'),
                        items: [
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
                SizedBox(height: 8),
                _HeartOptionField(
                  label: 'Waktu minum',
                  value: period,
                  options: ['Pagi', 'Siang', 'Malam'],
                  onChanged: (v) => setLocalState(() => period = v),
                ),
                SizedBox(height: 8),
                _HeartOptionField(
                  label: 'Sudah diminum',
                  value: consumed,
                  options: ['Ya', 'Tidak'],
                  onChanged: (v) => setLocalState(() => consumed = v),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(labelText: 'Catatan'),
                ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal')),
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
              child: Text('Simpan'),
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
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                      lastDate: DateTime.now().add(Duration(days: 1)),
                    );
                    if (picked != null) setLocalState(() => date = picked);
                  },
                ),
                SizedBox(height: 10),
                Text(
                  'Jenis pemeriksaan',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 6),
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
                SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: examId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: 'Pemeriksaan'),
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
                SizedBox(height: 10),
                Builder(
                  builder: (_) {
                    final exam = selectedExam();
                    return Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Satuan: ${exam.unit.isEmpty ? '-' : exam.unit}',
                            style: TextStyle(fontSize: 12),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Nilai normal: ${exam.normal}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (examType == 'Urin') ...[
                  SizedBox(height: 10),
                  _HeartOptionField(
                    label: 'Waktu pengambilan urin',
                    value: sampleTime,
                    options: ['Pagi', 'Siang', 'Sore', 'Malam'],
                    onChanged: (v) => setLocalState(() => sampleTime = v),
                  ),
                ],
                SizedBox(height: 10),
                TextField(
                  controller: resultController,
                  onChanged: (_) => setLocalState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Hasil',
                    hintText: 'Contoh: 130/80, 5.2, Negatif',
                  ),
                ),
                SizedBox(height: 10),
                Builder(
                  builder: (_) {
                    final autoCategory = _autoExamCategory(
                      selectedExam(),
                      resultController.text.trim(),
                    );
                    return Row(
                      children: [
                        Text(
                          'Kategori otomatis: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        _StatusBadge(
                          text: autoCategory,
                          color: _checkupCategoryColor(context, autoCategory),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal')),
            ElevatedButton(
              onPressed: () {
                final exam = selectedExam();
                if (resultController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
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
              child: Text('Simpan'),
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
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                        lastDate: DateTime.now().add(Duration(days: 1)),
                      );
                      if (picked != null) setLocalState(() => date = picked);
                    },
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Jenis pemeriksaan',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
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
                  SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: examId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: 'Pemeriksaan'),
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
                  SizedBox(height: 10),
                  Builder(
                    builder: (_) {
                      final exam = selectedExam();
                      return Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Satuan: ${exam.unit.isEmpty ? '-' : exam.unit}',
                              style: TextStyle(fontSize: 12),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Nilai normal: ${exam.normal}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (examType == 'Urin') ...[
                    SizedBox(height: 10),
                    _HeartOptionField(
                      label: 'Waktu pengambilan urin',
                      value: sampleTime,
                      options: ['Pagi', 'Siang', 'Sore', 'Malam'],
                      onChanged: (v) => setLocalState(() => sampleTime = v),
                    ),
                  ],
                  SizedBox(height: 10),
                  TextField(
                    controller: resultController,
                    onChanged: (_) => setLocalState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Hasil',
                      hintText: 'Contoh: 95, 180, 5.9, Negatif',
                    ),
                  ),
                  SizedBox(height: 10),
                  Builder(
                    builder: (_) {
                      final autoCategory = _autoExamCategory(
                        selectedExam(),
                        resultController.text.trim(),
                      );
                      return Row(
                        children: [
                          Text(
                            'Kategori otomatis: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                          _StatusBadge(
                            text: autoCategory,
                            color: _checkupCategoryColor(context, autoCategory),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal')),
            ElevatedButton(
              onPressed: () {
                final exam = selectedExam();
                if (resultController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
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
              child: Text('Simpan'),
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
          return [MealType.sarapan];
        case 'Selingan Pagi':
          return [MealType.selinganPagi];
        case 'Makan Siang':
          return [MealType.makanSiang];
        case 'Selingan Siang':
          return [MealType.selinganSiang];
        case 'Makan Malam':
          return [MealType.makanMalam];
        case 'Selingan Malam':
          return [MealType.selinganMalam];
        default:
          return [MealType.sarapan];
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
            insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.diabetesColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.diabetesColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        'Isi data insulin harian dan karbohidrat makan. Sistem akan menghitung otomatis: total insulin harian, ICR, estimasi insulin makan, selisih, dan kategori.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          height: 1.35,
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setLocalState(() {
                                date = date.subtract(Duration(days: 1));
                              });
                              syncMealFromFood(
                                setLocalState: setLocalState,
                                targetDate: date,
                                mealLabel: meal,
                              );
                            },
                            icon: Icon(Icons.chevron_left),
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: date,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(Duration(days: 1)),
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Tap untuk pilih tanggal',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).textTheme.bodyMedium?.color,
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
                                      date = date.add(Duration(days: 1));
                                    });
                                    syncMealFromFood(
                                      setLocalState: setLocalState,
                                      targetDate: date,
                                      mealLabel: meal,
                                    );
                                  },
                            icon: Icon(Icons.chevron_right),
                            color: isTodayDate(date)
                                ? AppColors.textHint
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: meal,
                      decoration: InputDecoration(labelText: 'Waktu makan'),
                      items: [
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
                    SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              autoInfoText.isEmpty
                                  ? 'Sinkronisasi karbo/GL dari Food Tracker.'
                                  : autoInfoText,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                          if (isAutoLoading) ...[
                            SizedBox(width: 8),
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                          SizedBox(width: 8),
                          TextButton(
                            onPressed: isAutoLoading
                                ? null
                                : () => syncMealFromFood(
                                      setLocalState: setLocalState,
                                      targetDate: date,
                                      mealLabel: meal,
                                    ),
                            child: Text('Sinkronkan'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: basalController,
                      onChanged: (_) => setLocalState(() {}),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Insulin basal harian (A) unit'),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Contoh: total insulin kerja panjang dalam 1 hari. Isi angka saja (mis. 12).',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium?.color),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: prandialController,
                      onChanged: (_) => setLocalState(() {}),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Insulin prandial harian (B) unit'),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Contoh: total insulin sebelum makan selama 1 hari. Isi angka saja (mis. 18).',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium?.color),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: carbsController,
                      readOnly: true,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Total karbohidrat makan (gram)',
                        helperText: 'Otomatis dari Food Tracker',
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Nilai ini otomatis sesuai tanggal + waktu makan yang dipilih.',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium?.color),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: glController,
                      readOnly: true,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'GL',
                        helperText: 'Otomatis dari Food Tracker',
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Nilai GL dihitung otomatis dari log makanan pada waktu makan tersebut.',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium?.color),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: actualController,
                      onChanged: (_) => setLocalState(() {}),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Dosis insulin aktual (F) unit'),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Isi dosis insulin yang benar-benar diberikan sebelum makan.',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium?.color),
                    ),
                    SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total insulin harian (C = A+B): ${c.toStringAsFixed(2)} unit'),
                          Text('ICR (D = 500/C): ${d.toStringAsFixed(2)}'),
                          Text('Estimasi insulin makan (E = karbohidrat/D): ${e.toStringAsFixed(2)} unit'),
                          Text('Selisih (F-E): ${diff.toStringAsFixed(2)} unit'),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              Text('Kategori: '),
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
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal')),
              ElevatedButton(
                onPressed: () {
                  if (actualController.text.trim().isEmpty || carbsController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
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
                child: Text('Simpan'),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 14),
              Text(
                'Tambah Input Kesehatan Ginjal',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              ...KidneyInputType.values.map(
                (t) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.kidneyColor.withValues(alpha: 0.12),
                    child: Icon(_typeIcon(t), color: AppColors.kidneyColor),
                  ),
                  title: Text(t.label),
                  trailing: Icon(Icons.chevron_right),
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
      activity = _activityOptions.first;
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
            insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                          lastDate: DateTime.now().add(Duration(days: 1)),
                        );
                        if (picked != null) setLocalState(() => date = picked);
                      },
                    ),
                    SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _activityOptions.contains(activity) ? activity : _activityOptions.first,
                      decoration: InputDecoration(labelText: 'Jenis aktivitas'),
                      items: _activityOptions.toSet().map((v) {
                        return DropdownMenuItem(value: v, child: Text(v));
                      }).toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setLocalState(() => activity = v);
                      },
                    ),
                    SizedBox(height: 14),
                    TextField(
                      controller: durationCtrl,
                      keyboardType: TextInputType.numberWithOptions(decimal: false),
                      decoration: InputDecoration(
                        labelText: 'Durasi (menit)',
                        hintText: 'contoh: 30',
                        suffixText: 'menit',
                      ),
                    ),
                    SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _activityComplaintOptions.contains(complaint) ? complaint : _activityComplaintOptions.first,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: 'Status Keluhan'),
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
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal')),
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
                child: Text('Simpan'),
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

  Future<DiabetesHealthRecord?> _showDiabetesMedicationDialog({
    DiabetesHealthRecord? existing,
  }) {
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

    return showDialog<DiabetesHealthRecord>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: Text(existing == null ? 'Input Obat Diabetes' : 'Edit Obat Diabetes'),
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
                        lastDate: DateTime.now().add(Duration(days: 1)),
                      );
                      if (picked != null) setLocalState(() => date = picked);
                    },
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: 'Nama obat'),
                  ),
                  SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: formType,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: 'Bentuk'),
                    items: [
                      DropdownMenuItem(value: 'Tablet', child: Text('Tablet')),
                      DropdownMenuItem(value: 'Kapsul', child: Text('Kapsul')),
                      DropdownMenuItem(value: 'Sirup', child: Text('Sirup')),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocalState(() => formType = v);
                    },
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Format dosis: ... x ... (... mg/ml/g)',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: doseFreqController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: 'Frekuensi'),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('x'),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: doseQtyController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: 'Jumlah'),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: doseStrengthController,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(labelText: 'Kadar'),
                        ),
                      ),
                      SizedBox(width: 8),
                      SizedBox(
                        width: 110,
                        child: DropdownButtonFormField<String>(
                          initialValue: doseUnit,
                          decoration: InputDecoration(labelText: 'Satuan'),
                          items: [
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
                  SizedBox(height: 8),
                  _HeartOptionField(
                    label: 'Waktu minum',
                    value: period,
                    options: ['Pagi', 'Siang', 'Malam'],
                    onChanged: (v) => setLocalState(() => period = v),
                  ),
                  SizedBox(height: 8),
                  _HeartOptionField(
                    label: 'Sudah diminum',
                    value: consumed,
                    options: ['Ya', 'Tidak'],
                    onChanged: (v) => setLocalState(() => consumed = v),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(labelText: 'Catatan'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Batal')),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(
                  ctx,
                  DiabetesHealthRecord(
                    id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                    type: DiabetesInputType.obat,
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
              child: Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
  void _showNormalValuesDialog(DiseaseType diseaseType) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Daftar Nilai Normal"),
        content: SizedBox(
          width: double.maxFinite,
          child: _NormalValuesTableContent(diseaseType: diseaseType),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Tutup"),
          ),
        ],
        ),
    );
  }

  void _showInsulinGuideDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Panduan Analisis Insulin"),
        content: SingleChildScrollView(
          child: _InsulinGuideContent(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Tutup"),
          ),
        ],
      ),
    );
  }


  void _showLoginRequired() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Icon(Icons.lock_outline, size: 52, color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Login Diperlukan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Kamu bisa lihat tracker sebagai guest. Untuk menambah data kesehatan, silakan login dulu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, AppConstants.routeLogin);
                },
                child: Text('Masuk'),
              ),
            ),
            SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, AppConstants.routeRegister);
                },
                child: Text('Daftar Akun'),
              ),
            ),
            SizedBox(height: 8),
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
                      lastDate: DateTime.now().add(Duration(days: 1)),
                    );
                    if (picked != null) {
                      setLocalState(() => date = picked);
                    }
                  },
                ),
                SizedBox(height: 10),
                TextField(
                  controller: postController,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'BB setelah hemodialisa I (kg)',
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: preController,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'BB sebelum hemodialisa II (kg)',
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
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
              child: Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final post = double.tryParse(postController.text.trim()) ?? -1;
                final pre = double.tryParse(preController.text.trim()) ?? -1;
                if (post <= 0 || pre <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
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
              child: Text('Simpan'),
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
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                        lastDate: DateTime.now().add(Duration(days: 1)),
                      );
                      if (picked != null) {
                        setLocalState(() => date = picked);
                      }
                    },
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: 'Nama obat'),
                  ),
                  SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: formType,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: 'Bentuk'),
                    items: [
                      DropdownMenuItem(value: 'Tablet', child: Text('Tablet')),
                      DropdownMenuItem(value: 'Kapsul', child: Text('Kapsul')),
                      DropdownMenuItem(value: 'Sirup', child: Text('Sirup')),
                    ],
                    onChanged: (v) {
                      if (v != null) setLocalState(() => formType = v);
                    },
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Format dosis: ... x ... (... mg/ml/g)',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: doseFreqController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Frekuensi',
                            hintText: '1',
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('x'),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: doseQtyController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Jumlah',
                            hintText: '1',
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: doseStrengthController,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Kadar',
                            hintText: '500',
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      SizedBox(
                        width: 110,
                        child: DropdownButtonFormField<String>(
                          initialValue: doseUnit,
                          decoration: InputDecoration(labelText: 'Satuan'),
                          items: [
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
                  SizedBox(height: 12),
                  Text(
                    'Waktu minum',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
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
                  SizedBox(height: 10),
                  Text(
                    'Kaitan dengan makan',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
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
                  SizedBox(height: 10),
                  Text(
                    'Kaitan dengan HD',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 6),
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
                  SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    decoration:
                        InputDecoration(labelText: 'Catatan/efek keluh'),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
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
              child: Text('Simpan'),
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
                      lastDate: DateTime.now().add(Duration(days: 1)),
                    );
                    if (picked != null) {
                      setLocalState(() => date = picked);
                    }
                  },
                ),
                SizedBox(height: 10),
                TextField(
                  controller: symptomController,
                  decoration: InputDecoration(labelText: 'Gejala utama'),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: intensityController,
                  decoration:
                      InputDecoration(labelText: 'Intensitas (Ringan/Sedang/Berat)'),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(labelText: 'Catatan'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (symptomController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
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
              child: Text('Simpan'),
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
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                      lastDate: DateTime.now().add(Duration(days: 1)),
                    );
                    if (picked != null) {
                      setLocalState(() => date = picked);
                    }
                  },
                ),
                SizedBox(height: 10),
                Text(
                  'Jenis pemeriksaan',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 6),
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
                SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: examId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: 'Pemeriksaan'),
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
                SizedBox(height: 10),
                Builder(
                  builder: (_) {
                    final exam = selectedExam();
                    return Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Satuan: ${exam.unit.isEmpty ? '-' : exam.unit}',
                            style: TextStyle(fontSize: 12),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Nilai normal: ${exam.normal}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (examType == 'Urin') ...[
                  SizedBox(height: 10),
                  _HeartOptionField(
                    label: 'Waktu pengambilan urin',
                    value: sampleTime,
                    options: ['Pagi', 'Siang', 'Sore', 'Malam'],
                    onChanged: (v) => setLocalState(() => sampleTime = v),
                  ),
                ],
                SizedBox(height: 10),
                TextField(
                  controller: resultController,
                  onChanged: (_) => setLocalState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Hasil',
                    hintText: 'Contoh: 130/80, 13.2, Negatif',
                  ),
                ),
                SizedBox(height: 10),
                Builder(
                  builder: (_) {
                    final autoCategory = _autoExamCategory(
                      selectedExam(),
                      resultController.text.trim(),
                    );
                    return Row(
                      children: [
                        Text(
                          'Kategori otomatis: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        _StatusBadge(
                          text: autoCategory,
                          color: _checkupCategoryColor(context, autoCategory),
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
              child: Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final exam = selectedExam();
                if (resultController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
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
              child: Text('Simpan'),
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
      case DiabetesInputType.obat:
        return Icons.medication_outlined;
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
        return fromRange(max: 200);
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

  List<DiabetesHealthRecord> get _dmMedicationRecords {
    final list = _dmRecords.where((e) => e.type == DiabetesInputType.obat).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final guestDisease = context.watch<DiseaseProvider>().selectedDisease;
          final diseaseType = auth.currentUser?.diseaseType ?? guestDisease;

          if (diseaseType == null) {
            return Center(
              child: Text(
                'Pilih penyakit terlebih dulu untuk melihat tracker kesehatan.',
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                textAlign: TextAlign.center,
              ),
            );
          }

          if (diseaseType == DiseaseType.heartFailure) {
            if (_isHeartLoading) {
              return Center(child: CircularProgressIndicator());
            }

            return RefreshIndicator(
              onRefresh: _loadHeartRecords,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 16, 16, 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeartHeader(onInput: _showHeartInputTypeSheet),
                    SizedBox(height: 16),
                    if (_uid.isEmpty) ...[
                      _GuestReadOnlyBanner(
                        message:
                            'Mode Guest (Read-only). Kamu bisa buka form, tapi tidak bisa menyimpan input tanpa login.',
                      ),
                      SizedBox(height: 12),
                    ],
                    if (_heartError != null)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _heartError!,
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    if (_heartError != null) SizedBox(height: 14),
                    _HeartTrendCard(
                      records: _heartWeightRecords,
                      idealWeight: auth.currentUser?.bbi ?? auth.currentUser?.weight ?? 0,
                    ),
                    SizedBox(height: 16),
                    // Activity Gauge for Heart
                    () {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final sevenDaysAgo = today.subtract(Duration(days: 6));
                      
                      final weeklyRecords = _heartActivityRecords.where((r) =>
                          r.date.isAfter(sevenDaysAgo.subtract(Duration(seconds: 1))) &&
                          r.date.isBefore(today.add(Duration(days: 1))));

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
                    SizedBox(height: 16),
                    _heartSymptomRecords.isEmpty
                        ? _EmptyTableState(
                            message: 'Belum ada input gejala jantung.',
                          )
                        : _HeartSymptomTable(
                            records: _heartSymptomRecords,
                            dateFmt: _dateFmt,
                            onEdit: _editHeartRecord,
                            onDelete: _deleteHeartRecord,
                          ),
                    SizedBox(height: 16),
                    _heartActivityRecords.isEmpty
                        ? _EmptyTableState(
                            message: 'Belum ada input aktivitas jantung.',
                          )
                        : _HeartActivityTable(
                            records: _heartActivityRecords,
                            dateFmt: _dateFmt,
                            onEdit: _editHeartRecord,
                            onDelete: _deleteHeartRecord,
                          ),
                    SizedBox(height: 16),
                    _heartMedicationRecords.isEmpty
                        ? _EmptyTableState(
                            message: 'Belum ada input obat jantung.',
                          )
                        : _HeartMedicationTable(
                            records: _heartMedicationRecords,
                            dateFmt: _dateFmt,
                            onEdit: _editHeartRecord,
                            onDelete: _deleteHeartRecord,
                          ),
                    SizedBox(height: 16),
                    _heartCheckupRecords.isEmpty
                        ? _EmptyTableState(
                            message: 'Belum ada input pemeriksaan jantung.',
                          )
                        : _HeartCheckupTable(
                            records: _heartCheckupRecords,
                            dateFmt: _dateFmt,
                            onEdit: _editHeartRecord,
                            onDelete: _deleteHeartRecord,
                          ),
                    SizedBox(height: 16),
                      _NormalValuesButtonCard(onTap: () => _showNormalValuesDialog(DiseaseType.heartFailure)),
                  ],
                ),
              ),
            );
          }

          if (diseaseType == DiseaseType.type2DiabetesMellitus) {
            if (_isDmLoading) {
              return Center(child: CircularProgressIndicator());
            }
            final usesInsulinTherapy = auth.currentUser?.usesInsulinTherapy ?? false;

            return RefreshIndicator(
              onRefresh: _loadDmRecords,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 16, 16, 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DiabetesHeader(onInput: _showDmInputTypeSheet),
                    SizedBox(height: 16),
                    if (_uid.isEmpty) ...[
                      _GuestReadOnlyBanner(
                        message:
                            'Mode Guest (Read-only). Kamu bisa buka form, tapi tidak bisa menyimpan input tanpa login.',
                      ),
                      SizedBox(height: 12),
                    ],
                    if (_dmError != null)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _dmError!,
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    if (_dmError != null) SizedBox(height: 14),
                    _DiabetesCheckupTrendCards(records: _dmCheckupRecords),
                    if (usesInsulinTherapy) ...[
                      SizedBox(height: 16),
                      _DiabetesInsulinSummaryTable(
                        records: _dmInsulinRecords,
                        dateFmt: _dateFmt,
                        uid: _uid,
                        onDataChanged: _loadDmRecords,
                        onEdit: _editDmRecord,
                        onDelete: _deleteDmRecord,
                      ),
                    ],
                    SizedBox(height: 16),
                    // Activity Gauge for Diabetes
                    () {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final sevenDaysAgo = today.subtract(Duration(days: 6));

                      final weeklyRecords = _dmActivityRecords.where((r) =>
                          r.date.isAfter(sevenDaysAgo.subtract(Duration(seconds: 1))) &&
                          r.date.isBefore(today.add(Duration(days: 1))));
                      
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
                    SizedBox(height: 16),
                    _dmActivityRecords.isEmpty
                        ? _EmptyTableState(
                            message: 'Belum ada input aktivitas diabetes.',
                          )
                        : _DiabetesActivityTable(
                            records: _dmActivityRecords,
                            dateFmt: _dateFmt,
                            onEdit: _editDmRecord,
                            onDelete: _deleteDmRecord,
                          ),
                    SizedBox(height: 16),
                    _dmMedicationRecords.isEmpty
                        ? _EmptyTableState(
                            message: 'Belum ada input obat diabetes.',
                          )
                        : _DiabetesMedicationTable(
                            records: _dmMedicationRecords,
                            dateFmt: _dateFmt,
                            onEdit: _editDmRecord,
                            onDelete: _deleteDmRecord,
                          ),
                    SizedBox(height: 16),
                    _dmCheckupRecords.isEmpty
                        ? _EmptyTableState(
                            message: 'Belum ada input pemeriksaan diabetes.',
                          )
                        : _DiabetesCheckupTable(
                            records: _dmCheckupRecords,
                            dateFmt: _dateFmt,
                            onEdit: _editDmRecord,
                            onDelete: _deleteDmRecord,
                          ),
                      SizedBox(height: 16),
                      _NormalValuesButtonCard(onTap: () => _showNormalValuesDialog(DiseaseType.type2DiabetesMellitus)),
                      if (usesInsulinTherapy) ...[
                        SizedBox(height: 16),
                        _InsulinGuideButtonCard(onTap: _showInsulinGuideDialog),
                      ],
                    ],
                  ),
                ),
              );
          }

          if (diseaseType != DiseaseType.chronicKidneyDisease) {
            return SizedBox.shrink();
          }

          if (_isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _loadRecords,
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 16, 16, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(14),
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
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.health_and_safety,
                            color: AppColors.kidneyColor,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Health Tracker Ginjal',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Pantau hemodialisa, gejala, dan obat',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: _showInputTypeSheet,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: EdgeInsets.symmetric(
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
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 16, color: _inputButtonForeground),
                                SizedBox(width: 4),
                                Text(
                                  'Input',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _inputButtonForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  if (_uid.isEmpty) ...[
                    _GuestReadOnlyBanner(
                      message:
                          'Mode Guest (Read-only). Kamu bisa buka form, tapi tidak bisa menyimpan input tanpa login.',
                    ),
                    SizedBox(height: 12),
                  ],
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  if (_error != null) SizedBox(height: 14),
                  _TrendCard(
                    records: _hemodialysisRecords,
                    riskCategory: _riskCategory,
                    riskColor: _riskColor,
                  ),
                  SizedBox(height: 16),
                  _HemodialysisTable(
                    records: _hemodialysisRecords,
                    dateFmt: _dateFmt,
                    riskCategory: _riskCategory,
                    riskColor: _riskColor,
                    onEdit: _editRecord,
                    onDelete: _deleteRecord,
                  ),
                  SizedBox(height: 16),
                  _MedicationTable(
                    records: _medicationRecords,
                    dateFmt: _dateFmt,
                    onEdit: _editRecord,
                    onDelete: _deleteRecord,
                  ),
                  SizedBox(height: 16),
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
                  SizedBox(height: 16),
                  _KidneyCheckupTable(
                    records: _checkupRecords,
                    dateFmt: _dateFmt,
                    onEdit: _editRecord,
                    onDelete: _deleteRecord,
                  ),
                  SizedBox(height: 16),
                    _NormalValuesButtonCard(onTap: () => _showNormalValuesDialog(DiseaseType.chronicKidneyDisease)),
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
            Icon(Icons.calendar_month, size: 18),
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
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trend % kenaikan BB antar dialisis (1 bulan)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          SizedBox(height: 6),
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
                    decoration: BoxDecoration(
                      color: AppColors.kidneyColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'BB kurva',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          SizedBox(height: 10),
          SizedBox(
            height: 170,
            child: spots.isEmpty
                ? Center(
                    child: Text(
                      'Belum ada data hemodialisa.',
                      style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      clipData: FlClipData.all(),
                      minX: 0,
                      maxX: (spots.length - 1).toDouble(),
                      minY: minY,
                      maxY: maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Theme.of(context).dividerColor,
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= spots.length) {
                                return SizedBox();
                              }
                              if (spots.length > 5 && idx.isOdd) {
                                return SizedBox();
                              }
                              return Text(
                                xLabelFmt.format(trendData[idx].date),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
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
                              style: TextStyle(fontSize: 10),
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
          ? Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Belum ada input hemodialisa.',
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                dataTextStyle: TextStyle(fontSize: 12),
                columnSpacing: 18,
                columns: [
                  DataColumn(label: Text('Tanggal')),
                  DataColumn(label: Text('BB setelah\nHemodialisa I')),
                  DataColumn(label: Text('BB sebelum\nHemodialisa II')),
                  DataColumn(label: Text('Kenaikan\nBB')),
                  DataColumn(label: Text('%')),
                  DataColumn(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Kategori'),
                        SizedBox(width: 4),
                        Tooltip(
                          triggerMode: TooltipTriggerMode.tap,
                          showDuration: Duration(seconds: 4),
                          padding: EdgeInsets.all(10),
                          textStyle: TextStyle(color: Colors.white, fontSize: 12),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          message: 'Kategori % IDWG:\nRingan: < 2%\nSedang: 2% - 4%\nBerat: > 4%',
                          child: Icon(
                            Icons.info_outline,
                            size: 15,
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataColumn(label: Text('Aksi')),
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
                              icon: Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => onEdit(e),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
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
          ? Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Belum ada input obat.',
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingTextStyle:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                dataTextStyle: TextStyle(fontSize: 12),
                columnSpacing: 18,
                columns: [
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
                              icon: Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => onEdit(e),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
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
              padding: EdgeInsets.all(16),
              child: Text(
                emptyText,
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
            )
          : Column(
              children: records.take(5).map((r) {
                return ListTile(
                  dense: true,
                  leading: Icon(icon, size: 18, color: Theme.of(context).textTheme.bodyMedium?.color),
                  title: Text(buildLine(r), style: TextStyle(fontSize: 12.5)),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit(r);
                      } else if (value == 'delete') {
                        onDelete(r);
                      }
                    },
                    itemBuilder: (ctx) => [
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
        Text(label, style: TextStyle(fontWeight: FontWeight.w600)),
        SizedBox(height: 6),
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
    final inputForeground = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF0F172A);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14),
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
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.health_and_safety, color: AppColors.heartColor),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health Tracker Jantung',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Pantau gejala, aktivitas, obat, pemeriksaan, dan BB',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onInput,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: inputForeground),
                  SizedBox(width: 4),
                  Text('Input', style: TextStyle(fontWeight: FontWeight.w700, color: inputForeground)),
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
            ? Center(
                child: Text(
                  'Belum ada data berat badan.',
                  style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
              )
            : Padding(
                padding: EdgeInsets.fromLTRB(10, 8, 14, 8),
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (spots.length - 1).toDouble(),
                    minY: 0,
                    maxY: maxY,
                    clipData: FlClipData.all(),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Theme.of(context).dividerColor,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= records.length) return SizedBox();
                            if (records.length > 6 && i.isOdd) return SizedBox();
                            return Text(
                              dateFmt.format(records[i].date),
                              style: TextStyle(fontSize: 9),
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
                            style: TextStyle(fontSize: 9),
                          ),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: Color(0xFF6B1414).withValues(alpha: 0.18),
                        barWidth: 7,
                        dotData: FlDotData(show: false),
                      ),
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: Color(0xFF6B1414),
                        barWidth: 2.4,
                        belowBarData: BarAreaData(
                          show: true,
                          color: Color(0xFF6B1414).withValues(alpha: 0.08),
                        ),
                        dotData: FlDotData(show: true),
                      ),
                      LineChartBarData(
                        spots: idealSpots,
                        isCurved: false,
                        color: Colors.redAccent,
                        barWidth: 2,
                        dotData: FlDotData(show: true),
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
          ? Padding(
              padding: EdgeInsets.all(16),
              child: Text('Belum ada input gejala.', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: [
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
                          icon: Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => onEdit(r),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.delete_outline, size: 18, color: AppColors.error),
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
          ? Padding(
              padding: EdgeInsets.all(16),
              child: Text('Belum ada input obat.', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: [
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
                          icon: Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => onEdit(r),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.delete_outline, size: 18, color: AppColors.error),
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
          columns: [
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
                      icon: Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => onEdit(r),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
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
          ? Padding(
              padding: EdgeInsets.all(16),
              child: Text('Belum ada input pemeriksaan.', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: [
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
                          context,
                          (p['category'] ?? '').toString(),
                        ),
                      ),
                    ),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => onEdit(r),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.delete_outline, size: 18, color: AppColors.error),
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
          ? Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Belum ada input pemeriksaan.',
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: [
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
                        color: _checkupCategoryColor(context, category),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => onEdit(r),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
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
    final inputForeground = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF0F172A);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14),
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
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.health_and_safety, color: AppColors.diabetesColor),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health Tracker Diabetes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Pantau aktivitas, pemeriksaan, dan analisis insulin',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onInput,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: inputForeground),
                  SizedBox(width: 4),
                  Text('Input', style: TextStyle(fontWeight: FontWeight.w700, color: inputForeground)),
                ],
              ),
            ),
          ),
        ],
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
  _ExamReference({
    required this.id,
    required this.group,
    required this.name,
    required this.unit,
    required this.normal,
    this.forKidney = false,
    this.forHeart = false,
    this.forDiabetes = false,
  });
}

List<_ExamReference> _examReferenceCatalog = [
  _ExamReference(id: "bb", group: "Fisik", name: "Berat Badan", unit: "kg", normal: "-", forKidney: true, forHeart: true, forDiabetes: true),
  _ExamReference(id: "tb", group: "Fisik", name: "Tinggi Badan", unit: "cm", normal: "-", forKidney: true, forHeart: true, forDiabetes: true),
  _ExamReference(id: "suhu", group: "Fisik", name: "Suhu", unit: "°C", normal: "36,5 - 37,5", forKidney: true, forHeart: true, forDiabetes: true),
  _ExamReference(id: "td", group: "Fisik", name: "Tekanan Darah", unit: "mmHg", normal: "< 120/80", forKidney: true, forHeart: true, forDiabetes: true),
  _ExamReference(id: "spo2", group: "Fisik", name: "Saturasi Oksigen", unit: "%", normal: "95 - 100", forKidney: true, forHeart: true, forDiabetes: true),
  _ExamReference(id: "nadi", group: "Fisik", name: "Denyut Nadi", unit: "x/mnt", normal: "60 - 100", forKidney: true, forHeart: true, forDiabetes: true),

  _ExamReference(id: "urin_protein", group: "Urin", name: "Protein", unit: "", normal: "Negatif", forKidney: true, forHeart: false, forDiabetes: false),
  _ExamReference(id: "urin_ph", group: "Urin", name: "pH", unit: "", normal: "4,5 - 8,0", forKidney: true, forHeart: false, forDiabetes: false),
  _ExamReference(id: "urin_hb", group: "Urin", name: "Hb", unit: "", normal: "Negatif", forKidney: true, forHeart: false, forDiabetes: false),

  _ExamReference(id: "chol_total", group: "Darah", name: "Kolesterol Total", unit: "mg/dL", normal: "< 200", forKidney: true, forHeart: true, forDiabetes: true),
  _ExamReference(id: "hdl", group: "Darah", name: "HDL", unit: "mg/dL", normal: "< 4,5", forKidney: true, forHeart: true, forDiabetes: true),
  _ExamReference(id: "ldl", group: "Darah", name: "LDL", unit: "mg/dL", normal: "< 100", forKidney: true, forHeart: true, forDiabetes: true),
  _ExamReference(id: "trigliserida", group: "Darah", name: "Trigliserida", unit: "mg/dL", normal: "< 150", forKidney: true, forHeart: true, forDiabetes: true),
  _ExamReference(id: "bun", group: "Darah", name: "BUN", unit: "mg/dL", normal: "-", forKidney: true, forHeart: true, forDiabetes: true),
  _ExamReference(id: "natrium", group: "Darah", name: "Natrium", unit: "mmol/L", normal: "135 - 145", forKidney: true, forHeart: true, forDiabetes: true),
  _ExamReference(id: "gdp", group: "Darah", name: "Gula darah puasa", unit: "mg/dL", normal: "70 - 110", forKidney: true, forHeart: true, forDiabetes: true),
  _ExamReference(id: "gds", group: "Darah", name: "Gula darah sewaktu", unit: "mg/dL", normal: "< 200", forKidney: true, forHeart: true, forDiabetes: true),
  _ExamReference(id: "hba1c", group: "Darah", name: "HbA1c", unit: "%", normal: "< 5,7%", forKidney: true, forHeart: true, forDiabetes: true),
  _ExamReference(id: "ureum", group: "Darah", name: "Ureum", unit: "mg/dL", normal: "10 - 50", forKidney: true, forHeart: true, forDiabetes: true),
  _ExamReference(id: "kreatinin", group: "Darah", name: "Kreatinin", unit: "mg/dL", normal: "L: 0,7 - 1,3 | P: 0,6 - 1,1", forKidney: true, forHeart: true, forDiabetes: true),
  _ExamReference(id: "kalium", group: "Darah", name: "Kalium", unit: "mmol/L", normal: "3,5 - 5,1", forKidney: true, forHeart: true, forDiabetes: true),
  _ExamReference(id: "fosfat", group: "Darah", name: "Fosfat", unit: "mg/dL", normal: "2,5 - 4,5", forKidney: true, forHeart: true, forDiabetes: true),
  _ExamReference(id: "albumin", group: "Darah", name: "Albumin", unit: "g/dL", normal: "3,5 - 5,0", forKidney: true, forHeart: true, forDiabetes: true),
  _ExamReference(id: "hb_darah", group: "Darah", name: "Hemoglobin (Hb)", unit: "g/dL", normal: "L: 13,0 - 16,0 | P: 12,0 - 14,0", forKidney: true, forHeart: true, forDiabetes: true),
  _ExamReference(id: "ht", group: "Darah", name: "Hematokrit (Ht)", unit: "%", normal: "L: 40 - 50 | P: 36 - 44", forKidney: true, forHeart: true, forDiabetes: true),
];

List<_ExamReference> _examReferencesForDiseaseType(DiseaseType diseaseType) {
  return _examReferenceCatalog.where((e) {
    if (diseaseType == DiseaseType.chronicKidneyDisease) return e.forKidney;
    if (diseaseType == DiseaseType.heartFailure) return e.forHeart;
    if (diseaseType == DiseaseType.type2DiabetesMellitus) return e.forDiabetes;
    return false;
  }).toList();
}

class _ActivityInputResult {
  final DateTime date;
  final Map<String, dynamic> payload;
  _ActivityInputResult({required this.date, required this.payload});
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusBadge({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

Color _checkupCategoryColor(BuildContext context, String category) {
  final theme = Theme.of(context);
  switch (category.trim().toLowerCase()) {
    case "tinggi": case "tidak normal": return theme.colorScheme.error;
    case "rendah": return Colors.orange;
    case "normal": return Colors.green;
    default: return theme.hintColor;
  }
}

class _NormalValuesButtonCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NormalValuesButtonCard({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3))),
        child: Row(children: [Icon(Icons.info_outline, color: theme.primaryColor), SizedBox(width: 12), Text("Lihat Daftar Nilai Normal", style: TextStyle(fontWeight: FontWeight.bold))]),
      ),
    );
  }
}

class _InsulinGuideButtonCard extends StatelessWidget {
  final VoidCallback onTap;
  const _InsulinGuideButtonCard({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3))),
        child: Row(children: [Icon(Icons.help_outline, color: theme.primaryColor), SizedBox(width: 12), Text("Panduan Analisis Insulin", style: TextStyle(fontWeight: FontWeight.bold))]),
      ),
    );
  }
}

class _InsulinGuideContent extends StatelessWidget {
  const _InsulinGuideContent();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Panduan Terapi Insulin", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.primaryColor)),
        SizedBox(height: 12),
        Text("Langkah-langkah Analisis:", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text("1. Masukkan dosis Insulin Basal dan Prandial sesuai resep dokter."),
        Text("2. Masukkan total Karbohidrat yang dikonsumsi (bisa otomatis dari Food Tracker)."),
        Text("3. Sistem akan menghitung estimasi kebutuhan insulin berdasarkan ICR (Insulin to Carb Ratio)."),
        Text("4. Bandingkan Dosis Aktual dengan Estimasi sistem untuk melihat keseimbangan."),
        SizedBox(height: 16),
        Text("Kategori Status:", style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text("• Balance: Selisih dosis aktual dan estimasi ≤ 1 unit."),
        Text("• Lebih: Dosis aktual lebih tinggi > 1 unit dari estimasi."),
        Text("• Kurang: Dosis aktual lebih rendah > 1 unit dari estimasi."),
      ],
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
  static final List<String> _mealOrder = [
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
        return [MealType.sarapan];
      case 'Selingan Pagi':
        return [MealType.selinganPagi];
      case 'Makan Siang':
        return [MealType.makanSiang];
      case 'Selingan Siang':
        return [MealType.selinganSiang];
      case 'Makan Malam':
        return [MealType.makanMalam];
      case 'Selingan Malam':
        return [MealType.selinganMalam];
      default:
        return [MealType.sarapan];
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
        SnackBar(content: Text('Sinkronisasi gagal. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _isSyncLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();
    final isDark = theme.brightness == Brightness.dark;

    final dateRecords = widget.records.where((r) => _isSameDay(r.date, _normalizedSelectedDate)).toList();
    final visibleMeals = _mealOrder.where((mealLabel) => _foodCountForMeal(mealLabel) > 0).toList();

    return _TableCard(
      title: 'Analisis Insulin (DM)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Navigation Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.subtract(Duration(days: 1));
                      });
                      _loadFoodEntriesForDate();
                    },
                    icon: Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          _isToday
                              ? 'Hari Ini · ${widget.dateFmt.format(_selectedDate)}'
                              : widget.dateFmt.format(_selectedDate),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        Text(
                          '${dateRecords.length} data insulin',
                          style: TextStyle(fontSize: 11, color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isToday
                        ? null
                        : () {
                            setState(() {
                              _selectedDate = _selectedDate.add(Duration(days: 1));
                            });
                            _loadFoodEntriesForDate();
                          },
                    icon: Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),

          if (_syncError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                _syncError!,
                style: TextStyle(fontSize: 11, color: AppColors.error),
              ),
            ),

          if (_isTableLoading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (visibleMeals.isEmpty)
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Belum ada data makan pada tanggal ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                ),
              ),
            )
          else ...[
            // Legend
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
                ),
                child: Text(
                  'Keterangan: Biru (belum input), Kuning (perlu update), Hijau (sinkron/aman).',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textTheme.bodyMedium?.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Table
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 14,
                  columns: [
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
                    final p = r?.payload ?? <String, dynamic>{};

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
                      color: (statusText == 'Perlu update' || statusText == 'Belum input')
                          ? WidgetStatePropertyAll<Color?>(
                              statusText == 'Belum input' 
                                ? Colors.blue.withValues(alpha: isDark ? 0.25 : 0.12)
                                : (ext?.diabetesColor ?? Colors.orange).withValues(alpha: 0.14),
                            )
                          : null,
                      cells: [
                        DataCell(Text(mealLabel, style: TextStyle(color: theme.textTheme.bodyMedium?.color))),
                        DataCell(Text('${auto.carb.toStringAsFixed(1)} g', style: TextStyle(color: theme.textTheme.bodyMedium?.color))),
                        DataCell(Text(auto.gl.toStringAsFixed(1), style: TextStyle(color: theme.textTheme.bodyMedium?.color))),
                        DataCell(Text(r == null ? '-' : basal.toStringAsFixed(1), style: TextStyle(color: theme.textTheme.bodyMedium?.color))),
                        DataCell(Text(r == null ? '-' : prandial.toStringAsFixed(1), style: TextStyle(color: theme.textTheme.bodyMedium?.color))),
                        DataCell(Text(r == null ? '-' : aktual.toStringAsFixed(1), style: TextStyle(color: theme.textTheme.bodyMedium?.color))),
                        DataCell(Text(r == null ? '-' : estimasi.toStringAsFixed(1), style: TextStyle(color: theme.textTheme.bodyMedium?.color))),
                        DataCell(Text(r == null ? '-' : diff.toStringAsFixed(1), style: TextStyle(color: theme.textTheme.bodyMedium?.color))),
                        DataCell(_StatusBadge(text: statusText, color: statusColor)),
                        DataCell(
                          r == null
                              ? Text('-', style: TextStyle(color: theme.hintColor))
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
                                  icon: Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () => widget.onEdit(r),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Sinkronkan dari food',
                                  icon: _isSyncLoading
                                      ? SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Icon(Icons.sync, size: 18),
                                  onPressed: _isSyncLoading ? null : () => _syncRow(r, mealLabel),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  tooltip: 'Hapus',
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppColors.error,
                                  ),
                                  onPressed: () => widget.onDelete(r),
                                ),
                              ] else
                                Text(
                                  'Isi via form',
                                  style: TextStyle(fontSize: 11, color: theme.textTheme.bodyMedium?.color),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
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
    final todayCheckups = records
        .where((record) => record.type == DiabetesInputType.pemeriksaan)
        .toList();

    return _TableCard(
      title: 'Pemeriksaan Kesehatan',
      child: todayCheckups.isEmpty
          ? _EmptyTableState(message: 'Belum ada data pemeriksaan hari ini.')
          : Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 14, right: 14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                columnSpacing: 20,
                columns: [
                  DataColumn(label: Text('Tgl')),
                  DataColumn(label: Text('Jenis')),
                  DataColumn(label: Text('Parameter')),
                  DataColumn(label: Text('Hasil')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Aksi')),
                ],
                rows: todayCheckups.map((r) {
                  final p = r.payload;
                  final examType = (p['examType'] ?? '-').toString();
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
                          context,
                          (p['category'] ?? '').toString(),
                        ),
                      ),
                    ),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Edit',
                          icon: Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => onEdit(r),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Hapus',
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.error,
                          ),
                          onPressed: () => onDelete(r),
                        ),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ),
    );
  }
}

class _DiabetesCheckupTrendCards extends StatelessWidget {
  final List<DiabetesHealthRecord> records;

  const _DiabetesCheckupTrendCards({required this.records});

  double? _readNumericResult(Map<String, dynamic> payload) {
    final raw = (payload['result'] ?? '').toString().trim();
    if (raw.isEmpty) return null;
    final normalized = raw.replaceAll(',', '.');
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(normalized);
    return match == null ? null : double.tryParse(match.group(0)!);
  }

  DateTime _dayOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  @override
  Widget build(BuildContext context) {
    final sorted = List<DiabetesHealthRecord>.from(records)
      ..sort((a, b) => a.date.compareTo(b.date));

    final Map<DateTime, double> gdpByDay = {};
    final Map<DateTime, double> gdsByDay = {};
    final Map<DateTime, double> hba1cByDay = {};

    for (final r in sorted) {
      final examId = (r.payload['examId'] ?? '').toString();
      final value = _readNumericResult(r.payload);
      if (value == null) continue;
      final day = _dayOnly(r.date);
      if (examId == 'gdp') gdpByDay[day] = value;
      if (examId == 'gds') gdsByDay[day] = value;
      if (examId == 'hba1c') hba1cByDay[day] = value;
    }

    final glucoseDates = {...gdpByDay.keys, ...gdsByDay.keys}.toList()
      ..sort((a, b) => a.compareTo(b));
    final visibleGlucoseDates = glucoseDates.length > 7
        ? glucoseDates.sublist(glucoseDates.length - 7)
        : glucoseDates;

    final glucoseSpotsGdp = <FlSpot>[];
    final glucoseSpotsGds = <FlSpot>[];
    for (int i = 0; i < visibleGlucoseDates.length; i++) {
      final day = visibleGlucoseDates[i];
      final gdp = gdpByDay[day];
      final gds = gdsByDay[day];
      if (gdp != null) glucoseSpotsGdp.add(FlSpot(i.toDouble(), gdp));
      if (gds != null) glucoseSpotsGds.add(FlSpot(i.toDouble(), gds));
    }

    final hba1cDates = hba1cByDay.keys.toList()..sort((a, b) => a.compareTo(b));
    final visibleHba1cDates = hba1cDates.length > 7
        ? hba1cDates.sublist(hba1cDates.length - 7)
        : hba1cDates;
    final hba1cSpots = <FlSpot>[];
    for (int i = 0; i < visibleHba1cDates.length; i++) {
      final day = visibleHba1cDates[i];
      final value = hba1cByDay[day];
      if (value != null) hba1cSpots.add(FlSpot(i.toDouble(), value));
    }

    return Column(
      children: [
        _GlucoseTrendCard(
          dates: visibleGlucoseDates,
          gdpSpots: glucoseSpotsGdp,
          gdsSpots: glucoseSpotsGds,
        ),
        const SizedBox(height: 16),
        _Hba1cTrendCard(
          dates: visibleHba1cDates,
          spots: hba1cSpots,
        ),
      ],
    );
  }
}

class _GlucoseTrendCard extends StatelessWidget {
  final List<DateTime> dates;
  final List<FlSpot> gdpSpots;
  final List<FlSpot> gdsSpots;

  const _GlucoseTrendCard({
    required this.dates,
    required this.gdpSpots,
    required this.gdsSpots,
  });

  @override
  Widget build(BuildContext context) {
    if (gdpSpots.isEmpty && gdsSpots.isEmpty) {
      return _TableCard(
        title: 'Grafik Tren Gula Darah (GDP & GDS)',
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: _EmptyTableState(
            message: 'Belum ada data GDP/GDS untuk ditampilkan.',
          ),
        ),
      );
    }

    final allY = [
      ...gdpSpots.map((e) => e.y),
      ...gdsSpots.map((e) => e.y),
    ];
    final maxY = allY.reduce((a, b) => a > b ? a : b);
    final safeMaxY = maxY <= 0 ? 10.0 : maxY * 1.15;
    final interval = safeMaxY <= 50 ? 10.0 : (safeMaxY / 5).ceilToDouble();

    return _TableCard(
      title: 'Grafik Tren Gula Darah (GDP & GDS)',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
        child: Column(
          children: [
            SizedBox(
              height: 190,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (dates.length - 1).toDouble(),
                  minY: 0,
                  maxY: safeMaxY,
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: interval,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
                      strokeWidth: 0.8,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: interval,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= dates.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              DateFormat('d/M').format(dates[idx]),
                              style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      left: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                      bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: gdpSpots,
                      isCurved: true,
                      color: Colors.blue.shade600,
                      barWidth: 2.4,
                      dotData: FlDotData(show: true),
                    ),
                    LineChartBarData(
                      spots: gdsSpots,
                      isCurved: true,
                      color: Colors.orange.shade700,
                      barWidth: 2.4,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: Colors.blue.shade600, label: 'GDP'),
                const SizedBox(width: 16),
                _LegendDot(color: Colors.orange.shade700, label: 'GDS'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Hba1cTrendCard extends StatelessWidget {
  final List<DateTime> dates;
  final List<FlSpot> spots;

  const _Hba1cTrendCard({required this.dates, required this.spots});

  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty) {
      return _TableCard(
        title: 'Grafik Tren HbA1c',
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: _EmptyTableState(
            message: 'Belum ada data HbA1c untuk ditampilkan.',
          ),
        ),
      );
    }

    final minPoint = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    final maxPoint = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final safeMinY = (minPoint - 1.0).clamp(0.0, 20.0);
    final safeMaxY = (maxPoint + 1.0).clamp(3.0, 25.0);
    final interval = ((safeMaxY - safeMinY) / 4).clamp(0.5, 5.0);

    return _TableCard(
      title: 'Grafik Tren HbA1c',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
        child: SizedBox(
          height: 190,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (dates.length - 1).toDouble(),
              minY: safeMinY.toDouble(),
              maxY: safeMaxY.toDouble(),
              gridData: FlGridData(
                show: true,
                horizontalInterval: interval.toDouble(),
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
                  strokeWidth: 0.8,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: interval.toDouble(),
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(1),
                      style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= dates.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('d/M').format(dates[idx]),
                          style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  left: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                  bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.green.shade600,
                  barWidth: 2.6,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.green.shade600.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
    final todayActivities = records
        .where((record) => record.type == DiabetesInputType.aktivitas)
        .toList();

    return _TableCard(
      title: 'Riwayat Aktivitas Fisik',
      child: todayActivities.isEmpty
          ? _EmptyTableState(message: 'Belum ada data aktivitas hari ini.')
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 24,
                columns: [
                  DataColumn(label: Text('Tgl')),
                  DataColumn(label: Text('Aktivitas')),
                  DataColumn(label: Text('Durasi')),
                  DataColumn(label: Text('Keluhan')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Aksi')),
                ],
                rows: todayActivities.map((r) {
                  final p = r.payload;
                  final category = (p['category'] ?? '-').toString();
                  return DataRow(cells: [
                    DataCell(Text(dateFmt.format(r.date))),
                    DataCell(Text((p['activityName'] ?? '-').toString())),
                    DataCell(Text('${p['duration'] ?? '-'} mnt')),
                    DataCell(Text((p['complaint'] ?? '-').toString())),
                    DataCell(
                      _StatusBadge(
                        text: category,
                        color: _checkupCategoryColor(context, category),
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Edit',
                            icon: Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => onEdit(r),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Hapus',
                            icon: Icon(
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

class _DiabetesMedicationTable extends StatelessWidget {
  final List<DiabetesHealthRecord> records;
  final DateFormat dateFmt;
  final void Function(DiabetesHealthRecord) onEdit;
  final void Function(DiabetesHealthRecord) onDelete;

  const _DiabetesMedicationTable({
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
          ? Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Belum ada input obat.',
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: [
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
                          icon: Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => onEdit(r),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.delete_outline, size: 18, color: AppColors.error),
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

class _NormalValuesTableContent extends StatelessWidget {
  final DiseaseType diseaseType;

  const _NormalValuesTableContent({required this.diseaseType});

  @override
  Widget build(BuildContext context) {
    final refs = _examReferencesForDiseaseType(diseaseType);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        headingRowHeight: 40,
        dataRowMinHeight: 40,
        columns: [
          DataColumn(label: Text('Parameter')),
          DataColumn(label: Text('Satuan')),
          DataColumn(label: Text('Nilai Normal')),
        ],
        rows: refs
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
    );
  }
}

class _TableCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _TableCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: isDark ? Border.all(color: theme.dividerColor) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.textTheme.titleSmall?.color,
              ),
            ),
          ),
          SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: child,
            ),
          ),
          SizedBox(height: 8),
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
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 140),
      padding: EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              color: theme.hintColor,
              size: 28,
            ),
            SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6)),
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
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_outlined, color: theme.primaryColor, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color,
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

class _ActivityGauge extends StatelessWidget {
  final double totalDuration;
  final double target;
  final Color themeColor;
  final bool isWeekly;

  const _ActivityGauge({
    required this.totalDuration,
    this.target = 150.0,
    required this.themeColor,
    this.isWeekly = true,
  });

  double get _ratio => target > 0 ? totalDuration / target : 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.directions_run_outlined, color: themeColor, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  isWeekly ? 'Progres Aktivitas Mingguan' : 'Progres Aktivitas Harian',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 14,
                    color: theme.dividerColor.withValues(alpha: 0.1),
                  ),
                  CircularProgressIndicator(
                    value: _ratio.clamp(0, 1),
                    strokeWidth: 14,
                    color: themeColor,
                    strokeCap: StrokeCap.round,
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(_ratio * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                      Text(
                        '${totalDuration.toInt()} / ${target.toInt()} mnt',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}
