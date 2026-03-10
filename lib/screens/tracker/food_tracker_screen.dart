// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/disease_type.dart';
import '../../models/food_item.dart';
import '../../models/food_log_entry.dart';
import '../../models/nutrition_needs.dart';
import '../../providers/auth_provider.dart';
import '../../services/food_database_service.dart';
import '../../services/food_log_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN UTAMA
// ─────────────────────────────────────────────────────────────────────────────

class FoodTrackerScreen extends StatefulWidget {
  const FoodTrackerScreen({super.key});

  @override
  State<FoodTrackerScreen> createState() => _FoodTrackerScreenState();
}

class _FoodTrackerScreenState extends State<FoodTrackerScreen> {
  DateTime _selectedDate = DateTime.now();
  List<FoodLogEntry> _entries = [];
  bool _isLoading = true;
  late AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = context.read<AuthProvider>();
    // Listener: reload entries setiap kali userModel selesai load dari Firestore
    _authProvider.addListener(_onAuthChanged);
    _loadEntries();
  }

  void _onAuthChanged() {
    // Jika sebelumnya uid kosong (userModel belum load), reload entries sekarang
    final uid = _authProvider.currentUser?.uid ?? _authProvider.firebaseUser?.uid ?? '';
    if (uid.isNotEmpty && _entries.isEmpty && !_isLoading) {
      _loadEntries();
    }
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  String get _uid {
    final auth = context.read<AuthProvider>();
    // firebaseUser tersedia lebih cepat dari userModel (Firestore async)
    return auth.currentUser?.uid ?? auth.firebaseUser?.uid ?? '';
  }

  /// Jumlahkan semua nutrisi dari entri hari ini
  NutritionIntake get _totalIntake {
    double e = 0, p = 0, l = 0, k = 0, na = 0, ka = 0, fo = 0, air = 0, serat = 0;
    for (final entry in _entries) {
      e += entry.energi;
      p += entry.protein;
      l += entry.lemak;
      k += entry.karbohidrat;
      na += entry.natrium;
      ka += entry.kalium;
      fo += entry.fosfor;
      air += entry.air;
      serat += entry.serat;
    }
    return NutritionIntake(
      energi: e, protein: p, lemak: l, karbohidrat: k,
      natrium: na, kalium: ka, fosfor: fo, cairan: air, serat: serat,
    );
  }

  Future<void> _loadEntries() async {
    if (_uid.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final entries = await FoodLogService.getEntries(_uid, _selectedDate);
      if (mounted) setState(() => _entries = entries);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeDate(int days) {
    final newDate = _selectedDate.add(Duration(days: days));
    if (newDate.isBefore(DateTime.now().add(const Duration(days: 1)))) {
      setState(() => _selectedDate = newDate);
      _loadEntries();
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _deleteEntry(FoodLogEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Makanan'),
        content: Text('Hapus "${entry.foodName}" dari log hari ini?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FoodLogService.deleteEntry(_uid, _selectedDate, entry.id);
      _loadEntries();
    }
  }

  Future<void> _editEntry(FoodLogEntry entry) async {
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.uid ?? auth.firebaseUser?.uid ?? '';

    // Cari FoodItem dari cache TKPI untuk dapat nilai per-100g
    final allFoods = await FoodDatabaseService.getAll();
    final food = allFoods.firstWhere(
      (f) => f.id == entry.foodId,
      // Fallback: rekonstruksi per-100g dari nilai yang tersimpan
      orElse: () => FoodItem(
        id: entry.foodId,
        nama: entry.foodName,
        kategori: '',
        energi: entry.grams > 0 ? entry.energi / entry.grams * 100 : 0,
        protein: entry.grams > 0 ? entry.protein / entry.grams * 100 : 0,
        lemak: entry.grams > 0 ? entry.lemak / entry.grams * 100 : 0,
        karbohidrat:
            entry.grams > 0 ? entry.karbohidrat / entry.grams * 100 : 0,
        natrium: entry.grams > 0 ? entry.natrium / entry.grams * 100 : 0,
        kalium: entry.grams > 0 ? entry.kalium / entry.grams * 100 : 0,
        fosfor: entry.grams > 0 ? entry.fosfor / entry.grams * 100 : 0,
        air: entry.grams > 0 ? entry.air / entry.grams * 100 : 0,
      ),
    );

    if (!mounted) return;

    // Helper: simpan entry baru dengan gram yang diperbarui
    Future<void> doUpdate(double newGrams) async {
      final n = food.calcFor(newGrams);
      final updated = FoodLogEntry(
        id: entry.id,
        foodId: entry.foodId,
        foodName: entry.foodName,
        grams: newGrams,
        loggedAt: entry.loggedAt,
        energi: n['energi']!,
        protein: n['protein']!,
        lemak: n['lemak']!,
        karbohidrat: n['karbohidrat']!,
        natrium: n['natrium']!,
        kalium: n['kalium']!,
        fosfor: n['fosfor']!,
        air: n['air']!,
        serat: n['serat'] ?? 0.0,
      );
      await FoodLogService.updateEntry(uid, _selectedDate, updated);
      if (mounted) _loadEntries();
    }

    // Gunakan UI takaran saji jika tersedia, fallback ke dialog gram
    if (food.takaranSaji.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: _TakaranSajiContent(
            food: food,
            onSave: (newGrams) async {
              Navigator.pop(ctx);
              await doUpdate(newGrams);
            },
            onCancel: () => Navigator.pop(ctx),
          ),
        ),
      );
    } else {
      await showDialog(
        context: context,
        builder: (ctx) => _EditGramDialog(
          entry: entry,
          food: food,
          onSave: (newGrams) async {
            await doUpdate(newGrams);
          },
        ),
      );
    }
  }

  void _showAddFoodSheet() {
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.uid ?? auth.firebaseUser?.uid ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddFoodSheet(
        onAdd: (food, grams) async {
          final entry = FoodLogEntry.create(food: food, grams: grams);
          await FoodLogService.addEntry(uid, _selectedDate, entry);
          if (mounted) _loadEntries();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid = auth.currentUser?.uid ?? auth.firebaseUser?.uid ?? '';
    final needs = auth.currentUser?.nutritionNeeds;
    // True jika user sudah login Firebase tapi userModel belum selesai load
    final isUserModelLoading =
        auth.firebaseUser != null && auth.currentUser == null;
    final intake = _totalIntake;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _DateHeader(
            date: _selectedDate,
            isToday: _isToday,
            onPrev: () => _changeDate(-1),
            onNext: () => _changeDate(1),
            canGoNext: !_isToday,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadEntries,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isUserModelLoading)
                            const _NutritionLoadingCard()
                          else if (needs != null)
                            _NutritionSummaryCard(
                                needs: needs,
                                intake: intake,
                                diseaseType: auth.currentUser?.diseaseType)
                          else
                            const _NoFormulaCard(),
                          const SizedBox(height: 16),
                          _FoodListSection(
                            entries: _entries,
                            onDelete: _deleteEntry,
                            onEdit: _editEntry,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: uid.isEmpty
            ? () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Silakan login untuk mencatat makanan'),
                    behavior: SnackBarBehavior.floating,
                  ),
                )
            : _showAddFoodSheet,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
        label: const Text('Tambah Makanan',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATE HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _DateHeader({
    required this.date,
    required this.isToday,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final label = isToday
        ? 'Hari Ini · ${DateFormat('d MMM y').format(date)}'
        : DateFormat('EEE, d MMM y').format(date);

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left),
            color: AppColors.textPrimary,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: canGoNext ? onNext : null,
            icon: const Icon(Icons.chevron_right),
            color: canGoNext ? AppColors.textPrimary : AppColors.textHint,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NUTRITION LOADING CARD (skeleton saat userModel belum selesai load)
// ─────────────────────────────────────────────────────────────────────────────

class _NutritionLoadingCard extends StatelessWidget {
  const _NutritionLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 12),
          Text(
            'Memuat data nutrisi...',
            style:
                TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NUTRITION SUMMARY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _NutritionSummaryCard extends StatelessWidget {
  final NutritionNeeds needs;
  final NutritionIntake intake;
  final DiseaseType? diseaseType;

  const _NutritionSummaryCard(
      {required this.needs, required this.intake, this.diseaseType});

  bool get _isDM => diseaseType == DiseaseType.type2DiabetesMellitus;

  Color get _themeColor =>
      _isDM ? AppColors.diabetesColor : AppColors.kidneyColor;

  @override
  Widget build(BuildContext context) {
    final energyRatio =
        needs.energi > 0 ? intake.energi / needs.energi : 0.0;

    // Nutrisi dasar (semua penyakit)
    final nutrients = [
      _NutrientData('Energi', intake.energi, needs.energi, 'kkal',
          Icons.local_fire_department_outlined),
      _NutrientData('Protein', intake.protein, needs.protein, 'g',
          Icons.egg_outlined),
      _NutrientData(
          'Lemak', intake.lemak, needs.lemak, 'g', Icons.water_drop_outlined),
      _NutrientData('Karbohidrat', intake.karbohidrat, needs.karbohidrat,
          'g', Icons.grain),
      // DM: serat + tidak ada Na/K/P/cairan
      if (_isDM)
        _NutrientData('Serat', intake.serat, needs.serat, 'g',
            Icons.grass_outlined)
      else ...[
        _NutrientData('Natrium', intake.natrium, needs.natrium, 'mg',
            Icons.science_outlined),
        _NutrientData('Kalium', intake.kalium, needs.kalium, 'mg',
            Icons.bolt_outlined),
        _NutrientData('Fosfor', intake.fosfor, needs.fosfor, 'mg',
            Icons.circle_outlined),
        _NutrientData('Cairan', intake.cairan, needs.cairan, 'ml',
            Icons.opacity_outlined),
      ],
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.bar_chart_rounded,
                      color: _themeColor, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Ringkasan Nutrisi Harian',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(energyRatio * 100).toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _progressColor(energyRatio),
                      ),
                    ),
                    const Text('energi',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // ── Nutrient rows ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: nutrients
                  .map((n) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _NutrientRow(data: n),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  static Color _progressColor(double ratio) {
    if (ratio >= 1.0) return AppColors.error;
    if (ratio >= 0.8) return AppColors.warning;
    return AppColors.success;
  }
}

class _NutrientData {
  final String label;
  final double intake;
  final double target;
  final String unit;
  final IconData icon;

  const _NutrientData(
      this.label, this.intake, this.target, this.unit, this.icon);

  double get ratio => target > 0 ? intake / target : 0;
  bool get exceeded => intake > target;
}

class _NutrientRow extends StatelessWidget {
  final _NutrientData data;
  const _NutrientRow({required this.data});

  Color get _barColor {
    if (data.exceeded) return AppColors.error;
    if (data.ratio >= 0.8) return AppColors.warning;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(data.icon, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(data.label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const Spacer(),
            if (data.exceeded)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Melebihi!',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppColors.error,
                        fontWeight: FontWeight.w700)),
              ),
            Text(
              '${_fmt(data.intake)} / ${_fmt(data.target)} ${data.unit}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: data.ratio.clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation<Color>(_barColor),
          ),
        ),
      ],
    );
  }

  String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NO FORMULA CARD
// ─────────────────────────────────────────────────────────────────────────────

class _NoFormulaCard extends StatelessWidget {
  const _NoFormulaCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppColors.textHint, size: 36),
          const SizedBox(height: 10),
          const Text(
            'Formula nutrisi untuk penyakit Anda\nsedang dikembangkan.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOOD LIST SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _FoodListSection extends StatelessWidget {
  final List<FoodLogEntry> entries;
  final Future<void> Function(FoodLogEntry) onDelete;
  final Future<void> Function(FoodLogEntry) onEdit;

  const _FoodListSection(
      {required this.entries, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Makanan Hari Ini',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${entries.length} item',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const _EmptyFoodState()
        else
          ...entries.map((e) => _FoodEntryCard(
                entry: e,
                onDelete: () => onDelete(e),
                onEdit: () => onEdit(e),
              )),
      ],
    );
  }
}

class _EmptyFoodState extends StatelessWidget {
  const _EmptyFoodState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.restaurant_menu_outlined,
              size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          const Text('Belum ada makanan dicatat',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          const Text('Tap tombol + untuk menambahkan',
              style:
                  TextStyle(fontSize: 12, color: AppColors.textHint)),
        ],
      ),
    );
  }
}

class _FoodEntryCard extends StatelessWidget {
  final FoodLogEntry entry;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _FoodEntryCard(
      {required this.entry, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1))
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: onEdit,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.restaurant_outlined,
              color: Colors.orange, size: 22),
        ),
        title: Text(entry.foodName,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary)),
        subtitle: Text(
          '${entry.grams.toInt()} g  ·  ${entry.energi.toStringAsFixed(0)} kkal',
          style:
              const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('P: ${entry.protein.toStringAsFixed(1)} g',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)),
                Text('Na: ${entry.natrium.toStringAsFixed(1)} mg',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  size: 20, color: AppColors.textSecondary),
              onSelected: (val) {
                if (val == 'edit') onEdit();
                if (val == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined,
                          size: 18, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text('Edit Gram'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          size: 18, color: AppColors.error),
                      SizedBox(width: 10),
                      Text('Hapus',
                          style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD FOOD BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _AddFoodSheet extends StatefulWidget {
  final Future<void> Function(FoodItem food, double grams) onAdd;
  const _AddFoodSheet({required this.onAdd});

  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  final _searchCtrl = TextEditingController();
  List<FoodItem> _results = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() => _isSearching = true);
    final results = await FoodDatabaseService.search(q);
    if (mounted) setState(() { _results = results; _isSearching = false; });
  }

  void _selectFood(FoodItem food) {
    if (food.takaranSaji.isNotEmpty) {
      _showTakaranDialog(food);
    } else {
      _showGramDialog(food);
    }
  }

  void _showTakaranDialog(FoodItem food) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        child: _TakaranSajiContent(
          food: food,
          onSave: (grams) async {
            Navigator.pop(ctx);
            Navigator.pop(context);
            await widget.onAdd(food, grams);
          },
          onCancel: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _showGramDialog(FoodItem food) {
    final gramCtrl = TextEditingController(text: '100');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final grams = double.tryParse(gramCtrl.text) ?? 0;
          final n = food.calcFor(grams);

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.nama,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                Text(food.kategori,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.normal)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Input gram
                  TextField(
                    controller: gramCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Berat (gram)',
                      suffixText: 'g',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    onChanged: (_) => setS(() {}),
                  ),
                  const SizedBox(height: 14),
                  // Preview nutrisi
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _previewRow('Energi', n['energi']!, 'kkal'),
                        _previewRow('Protein', n['protein']!, 'g'),
                        _previewRow('Lemak', n['lemak']!, 'g'),
                        _previewRow('Karbohidrat', n['karbohidrat']!, 'g'),
                        _previewRow('Natrium', n['natrium']!, 'mg'),
                        _previewRow('Kalium', n['kalium']!, 'mg'),
                        _previewRow('Fosfor', n['fosfor']!, 'mg'),
                        _previewRow('Cairan (Air)', n['air']!, 'ml',
                            isLast: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal')),
              FilledButton(
                onPressed: grams > 0
                    ? () async {
                        Navigator.pop(ctx);   // tutup dialog
                        Navigator.pop(context); // tutup sheet
                        await widget.onAdd(food, grams);
                      }
                    : null,
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _previewRow(String label, double value, String unit,
      {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          Text('${value.toStringAsFixed(1)} $unit',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 14),
              const Text('Tambah Makanan',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Cari bahan makanan...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              const SizedBox(height: 8),
              // Results
              Expanded(
                child: _isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? Center(
                            child: Text('Tidak ditemukan',
                                style: TextStyle(
                                    color: AppColors.textHint)),
                          )
                        : ListView.separated(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final food = _results[i];
                              return ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        vertical: 4),
                                title: Text(food.nama,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary)),
                                subtitle: Text(
                                  '${food.energi.toInt()} kkal  ·  P: ${food.protein}g  ·  Na: ${food.natrium.toInt()}mg',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                                trailing: const Icon(
                                    Icons.add_circle_outline,
                                    color: AppColors.primary),
                                onTap: () => _selectFood(food),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

// ─── Dialog Edit Gram ────────────────────────────────────────────────────────

class _EditGramDialog extends StatefulWidget {
  final FoodLogEntry entry;
  final FoodItem food;
  final Future<void> Function(double newGrams) onSave;

  const _EditGramDialog(
      {required this.entry, required this.food, required this.onSave});

  @override
  State<_EditGramDialog> createState() => _EditGramDialogState();
}

class _EditGramDialogState extends State<_EditGramDialog> {
  late final TextEditingController _gramCtrl;
  Map<String, double> _preview = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _gramCtrl =
        TextEditingController(text: widget.entry.grams.toInt().toString());
    _recalc();
  }

  @override
  void dispose() {
    _gramCtrl.dispose();
    super.dispose();
  }

  void _recalc() {
    final g = double.tryParse(_gramCtrl.text) ?? 0;
    setState(() => _preview = widget.food.calcFor(g));
  }

  Future<void> _save() async {
    final g = double.tryParse(_gramCtrl.text) ?? 0;
    if (g <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gram harus lebih dari 0')));
      return;
    }
    setState(() => _saving = true);
    await widget.onSave(g);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final g = double.tryParse(_gramCtrl.text) ?? 0;
    return AlertDialog(
      title: Text('Edit ${widget.food.nama}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Jumlah (gram)',
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            TextField(
              controller: _gramCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                suffixText: 'g',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (_) => _recalc(),
            ),
            if (g > 0) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 4),
              const Text('Perkiraan Gizi',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              _row(
                  'Energi',
                  '${(_preview['energi'] ?? 0).toStringAsFixed(1)} kkal'),
              _row(
                  'Protein',
                  '${(_preview['protein'] ?? 0).toStringAsFixed(1)} g'),
              _row('Lemak',
                  '${(_preview['lemak'] ?? 0).toStringAsFixed(1)} g'),
              _row(
                  'Karbohidrat',
                  '${(_preview['karbohidrat'] ?? 0).toStringAsFixed(1)} g'),
              _row(
                  'Natrium',
                  '${(_preview['natrium'] ?? 0).toStringAsFixed(1)} mg'),
              _row(
                  'Kalium',
                  '${(_preview['kalium'] ?? 0).toStringAsFixed(1)} mg'),
              _row(
                  'Fosfor',
                  '${(_preview['fosfor'] ?? 0).toStringAsFixed(1)} mg'),
              _row('Air',
                  '${(_preview['air'] ?? 0).toStringAsFixed(1)} ml'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

// ─── Takaran Saji Input ──────────────────────────────────────────────────────

class _TakaranSajiContent extends StatefulWidget {
  final FoodItem food;
  final Future<void> Function(double grams) onSave;
  final VoidCallback onCancel;

  const _TakaranSajiContent(
      {required this.food, required this.onSave, required this.onCancel});

  @override
  State<_TakaranSajiContent> createState() => _TakaranSajiContentState();
}

class _TakaranSajiContentState extends State<_TakaranSajiContent> {
  int _takaranIdx = 1; // default: sedang
  int _count = 1;
  int _sisaPercent = 0; // default: habis semua
  bool _saving = false;

  static const _sisaPercentages = [0, 5, 25, 50, 75, 100];
  static const _sisaLabels = [
    'Habis',
    'Sisa\n5%',
    'Sisa\n25%',
    'Sisa\n50%',
    'Sisa\n75%',
    'Tidak\nmakan'
  ];

  double get _gramDimakan {
    final t = widget.food.takaranSaji[_takaranIdx];
    return t.gram * _count * (1 - _sisaPercent / 100);
  }

  Map<String, double> get _preview => widget.food.calcFor(_gramDimakan);

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
      );

  Widget _previewRow(String label, double value, String unit) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            Text('${value.toStringAsFixed(1)} $unit',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final takaran = widget.food.takaranSaji;
    final gram = _gramDimakan;
    final preview = _preview;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Text(widget.food.nama,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const Text('Berapa yang kamu makan?',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 18),

          // ── Pilih ukuran takaran ─────────────────────────────────────
          _sectionLabel('Ukuran ${widget.food.satuanNama}'),
          const SizedBox(height: 8),
          Row(
            children: List.generate(takaran.length, (i) {
              final t = takaran[i];
              final sel = _takaranIdx == i;
              final emojiSize = [20.0, 27.0, 34.0][i.clamp(0, 2)];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _takaranIdx = i),
                  child: Container(
                    margin: EdgeInsets.only(
                        right: i < takaran.length - 1 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel
                            ? AppColors.primary
                            : Colors.grey.shade200,
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(widget.food.emoji,
                            style: TextStyle(fontSize: emojiSize)),
                        const SizedBox(height: 4),
                        Text(t.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 10,
                                color: sel
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w500)),
                        Text('${t.gram.toInt()} g',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: sel
                                    ? AppColors.primary
                                    : AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),

          // ── Jumlah takaran ───────────────────────────────────────────
          _sectionLabel('Jumlah ${widget.food.satuanNama}'),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 36),
                color: _count > 1
                    ? AppColors.primary
                    : Colors.grey.shade300,
                onPressed:
                    _count > 1 ? () => setState(() => _count--) : null,
              ),
              SizedBox(
                width: 60,
                child: Text('$_count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 36),
                color: AppColors.primary,
                onPressed: () => setState(() => _count++),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Sisa di piring ───────────────────────────────────────────
          _sectionLabel('Sisa di Piring'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_sisaPercentages.length, (i) {
              final sisa = _sisaPercentages[i];
              final label = _sisaLabels[i];
              final sel = _sisaPercent == sisa;
              return GestureDetector(
                onTap: () => setState(() => _sisaPercent = sisa),
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sel
                              ? AppColors.primary
                              : Colors.grey.shade300,
                          width: sel ? 2.5 : 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: CustomPaint(
                          painter: _PiePainter(
                            eatFraction: 1 - sisa / 100,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9,
                            height: 1.2,
                            color: sel
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: sel
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 18),

          // ── Ringkasan gizi ───────────────────────────────────────────
          if (gram > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${gram.toStringAsFixed(0)} g dimakan',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                  const SizedBox(height: 6),
                  _previewRow('Energi', preview['energi']!, 'kkal'),
                  _previewRow('Protein', preview['protein']!, 'g'),
                  _previewRow('Lemak', preview['lemak']!, 'g'),
                  _previewRow(
                      'Karbohidrat', preview['karbohidrat']!, 'g'),
                  _previewRow('Natrium', preview['natrium']!, 'mg'),
                  _previewRow('Kalium', preview['kalium']!, 'mg'),
                  _previewRow('Fosfor', preview['fosfor']!, 'mg'),
                  _previewRow('Cairan', preview['air']!, 'ml'),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('Makanan tidak dicatat (sisa 100%)',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ),
            ),
          const SizedBox(height: 18),

          // ── Tombol ───────────────────────────────────────────────────
          Row(
            children: [
              TextButton(
                onPressed: _saving ? null : widget.onCancel,
                child: const Text('Batal'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: (gram > 0 && !_saving)
                      ? () async {
                          setState(() => _saving = true);
                          await widget.onSave(gram);
                        }
                      : null,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Simpan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Pie Painter untuk visualisasi sisa makanan ──────────────────────────────

class _PiePainter extends CustomPainter {
  final double eatFraction; // 1.0 = habis semua, 0.0 = tidak dimakan
  final Color color;

  const _PiePainter({required this.eatFraction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Latar: bagian yang tidak dimakan (abu-abu)
    canvas.drawCircle(
        center, radius, Paint()..color = Colors.grey.shade100);

    // Bagian yang dimakan (warna primary)
    if (eatFraction > 0) {
      canvas.drawArc(
        rect,
        -pi / 2,
        2 * pi * eatFraction,
        true,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_PiePainter old) => old.eatFraction != eatFraction;
}
