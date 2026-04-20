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
import '../../models/meal_type.dart';
import '../../models/nutrition_needs.dart';
import '../../providers/auth_provider.dart';
import '../../services/food_database_service.dart';
import '../../services/food_log_service.dart';
import '../../services/nutrition_history_service.dart';
import '../../widgets/nutrition_line_chart.dart';

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
  MealType? _selectedMealType; // ← Track selected meal time
  List<DailyNutrition>? _weeklyData; // ← Weekly data for HF charts

  @override
  void initState() {
    super.initState();
    _authProvider = context.read<AuthProvider>();
    // Listener: reload entries setiap kali userModel selesai load dari Firestore
    _authProvider.addListener(_onAuthChanged);
    _loadEntries();
    _loadWeeklyData(); // ← Load weekly data on init
  }

  void _onAuthChanged() {
    // Jika sebelumnya uid kosong (userModel belum load), reload entries sekarang
    final uid =
        _authProvider.currentUser?.uid ?? _authProvider.firebaseUser?.uid ?? '';
    if (uid.isNotEmpty && _entries.isEmpty && !_isLoading) {
      _loadEntries();
      _loadWeeklyData(); // ← Reload weekly data when auth changes
    }
  }

  /// Load weekly nutrition data for HF patients' charts
  Future<void> _loadWeeklyData() async {
    try {
      final uid = _uid;
      final needs = _authProvider.currentUser?.nutritionNeeds;

      if (uid.isEmpty || needs == null) {
        setState(() => _weeklyData = []);
        return;
      }

      final data = await NutritionHistoryService.getWeeklyNutrition(
        uid: uid,
        endDate: DateTime.now(),
        targets: needs,
      );

      if (mounted) {
        setState(() => _weeklyData = data);
      }
    } catch (e) {
      // Silently fail, weekly data is optional
      if (mounted) {
        setState(() => _weeklyData = []);
      }
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
    double e = 0,
        p = 0,
        l = 0,
        k = 0,
        na = 0,
        ka = 0,
        fo = 0,
        air = 0,
        serat = 0;
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
      energi: e,
      protein: p,
      lemak: l,
      karbohidrat: k,
      natrium: na,
      kalium: ka,
      fosfor: fo,
      cairan: air,
      serat: serat,
    );
  }

  /// Group entries by meal type for DM table display
  Map<MealType, List<FoodLogEntry>> _groupEntriesByMeal(
    List<FoodLogEntry> entries,
  ) {
    final grouped = <MealType, List<FoodLogEntry>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(entry.mealType, () => []).add(entry);
    }
    return grouped;
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
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: AppColors.error),
            ),
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
        karbohidrat: entry.grams > 0
            ? entry.karbohidrat / entry.grams * 100
            : 0,
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
        mealType: entry.mealType, // ← PRESERVE existing meal type
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
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
    _showMealTimeSelector();
  }

  void _showMealTimeSelector() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: const Text(
                'Pilih Waktu Makan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ...MealType.values
                .map(
                  (meal) => InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _selectedMealType = meal);
                      _proceedToFoodSearch();
                    },
                    child: Container(
                      color: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Text(
                            meal.emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  meal.label,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  meal.timeRange,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _proceedToFoodSearch() {
    if (_selectedMealType == null) return;
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.uid ?? auth.firebaseUser?.uid ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddFoodSheet(
        mealType: _selectedMealType!,
        onAdd: (food, grams) async {
          final entry = FoodLogEntry.create(
            food: food,
            grams: grams,
            mealType: _selectedMealType!,
          );
          await FoodLogService.addEntry(uid, _selectedDate, entry);
          if (mounted) _loadEntries();
        },
      ),
    );
  }

  /// Build HF weekly charts section
  Widget _HFWeeklyChartsSection({required List<DailyNutrition> weeklyData}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Grafik Nutrisi Mingguan',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        // Energi Chart
        _buildHFNutritionChart(
          title: 'Energi',
          unit: 'kkal',
          weeklyData: weeklyData,
          lineColor: Colors.black87,
          getActual: (data) => data.energi,
          getTarget: (data) => data.targetEnergi,
        ),
        const SizedBox(height: 12),
        // Lemak Chart
        _buildHFNutritionChart(
          title: 'Lemak',
          unit: 'g',
          weeklyData: weeklyData,
          lineColor: Colors.amber.shade700,
          getActual: (data) => data.lemak,
          getTarget: (data) => data.targetLemak,
        ),
        const SizedBox(height: 12),
        // Natrium Chart
        _buildHFNutritionChart(
          title: 'Natrium',
          unit: 'mg',
          weeklyData: weeklyData,
          lineColor: Colors.orange,
          getActual: (data) => data.natrium,
          getTarget: (data) => data.targetNatrium,
        ),
        const SizedBox(height: 12),
        // Cairan Chart
        _buildHFNutritionChart(
          title: 'Cairan',
          unit: 'ml',
          weeklyData: weeklyData,
          lineColor: Colors.blue.shade600,
          getActual: (data) => data.cairan,
          getTarget: (data) => data.targetCairan,
        ),
      ],
    );
  }

  /// Build individual HF nutrition chart with improved styling
  Widget _buildHFNutritionChart({
    required String title,
    required String unit,
    required List<DailyNutrition> weeklyData,
    required Color lineColor,
    required double Function(DailyNutrition) getActual,
    required double Function(DailyNutrition) getTarget,
  }) {
    final actualMax = weeklyData.fold<double>(
      0,
      (max, data) => getActual(data) > max ? getActual(data) : max,
    );
    final safeMaxY = actualMax <= 0 ? 10.0 : (actualMax * 1.2);

    return NutritionLineChart(
      title: title,
      unit: unit,
      weeklyData: weeklyData,
      lineColor: lineColor,
      getActual: getActual,
      getTarget: getTarget,
      minY: 0,
      maxY: safeMaxY,
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
                          else if (needs != null) ...[
                            // 1. Weekly fluid chart for kidney patients
                            if (auth.currentUser?.diseaseType ==
                                DiseaseType.chronicKidneyDisease) ...[
                              _WeeklyFluidChart(target: needs.cairan),
                              const SizedBox(height: 16),
                              // 2. Daily circular gauge for kidney patients
                              _KidneyFluidGauge(
                                intake: intake.cairan,
                                target: needs.cairan,
                              ),
                              const SizedBox(height: 16),
                            ],
                            // 2. HF Patients: Show weekly nutrition charts
                            if (auth.currentUser?.diseaseType ==
                                    DiseaseType.heartFailure &&
                                _weeklyData != null &&
                                _weeklyData!.isNotEmpty) ...[
                              _HFWeeklyChartsSection(weeklyData: _weeklyData!),
                              const SizedBox(height: 16),
                            ],
                            // 3. DM Patients: Show hierarchical meal table
                            if (auth.currentUser?.diseaseType ==
                                DiseaseType.type2DiabetesMellitus)
                              _DMDailyMealTable(
                                entriesByMeal: _groupEntriesByMeal(_entries),
                                needs: needs,
                              )
                            // 3. Other patients: Show nutrition summary
                            else
                              _NutritionSummaryCard(
                                needs: needs,
                                intake: intake,
                                diseaseType: auth.currentUser?.diseaseType,
                              ),
                          ] else
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
        label: const Text(
          'Tambah Makanan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
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
            offset: const Offset(0, 2),
          ),
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
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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

  const _NutritionSummaryCard({
    required this.needs,
    required this.intake,
    this.diseaseType,
  });

  bool get _isDM => diseaseType == DiseaseType.type2DiabetesMellitus;

  Color get _themeColor =>
      _isDM ? AppColors.diabetesColor : AppColors.kidneyColor;

  @override
  Widget build(BuildContext context) {
    final energyRatio = needs.energi > 0 ? intake.energi / needs.energi : 0.0;

    // Nutrisi dasar (semua penyakit)
    final nutrients = [
      _NutrientData(
        'Energi',
        intake.energi,
        needs.energi,
        'kkal',
        Icons.local_fire_department_outlined,
      ),
      _NutrientData(
        'Protein',
        intake.protein,
        needs.protein,
        'g',
        Icons.egg_outlined,
      ),
      _NutrientData(
        'Lemak',
        intake.lemak,
        needs.lemak,
        'g',
        Icons.water_drop_outlined,
      ),
      _NutrientData(
        'Karbohidrat',
        intake.karbohidrat,
        needs.karbohidrat,
        'g',
        Icons.grain,
      ),
      // DM: serat + tidak ada Na/K/P/cairan
      if (_isDM)
        _NutrientData(
          'Serat',
          intake.serat,
          needs.serat,
          'g',
          Icons.grass_outlined,
        )
      else ...[
        _NutrientData(
          'Natrium',
          intake.natrium,
          needs.natrium,
          'mg',
          Icons.science_outlined,
        ),
        _NutrientData(
          'Kalium',
          intake.kalium,
          needs.kalium,
          'mg',
          Icons.bolt_outlined,
        ),
        _NutrientData(
          'Fosfor',
          intake.fosfor,
          needs.fosfor,
          'mg',
          Icons.circle_outlined,
        ),
        _NutrientData(
          'Cairan',
          intake.cairan,
          needs.cairan,
          'ml',
          Icons.opacity_outlined,
        ),
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
            offset: const Offset(0, 2),
          ),
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
                  child: Icon(
                    Icons.bar_chart_rounded,
                    color: _themeColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Ringkasan Nutrisi Harian',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
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
                    const Text(
                      'energi',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
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
                  .map(
                    (n) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _NutrientRow(data: n),
                    ),
                  )
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

// ─────────────────────────────────────────────────────────────────────────────
// WEEKLY FLUID CHART (Bar diagram for past 7 days)
// ─────────────────────────────────────────────────────────────────────────────

class _WeeklyFluidChart extends StatelessWidget {
  final double target;

  const _WeeklyFluidChart({required this.target});

  List<_DayFluidData> _getWeeklyData() {
    // Simulate last 7 days of fluid intake (in real app, fetch from Firestore)
    // For now, return mock data with different values per day
    final now = DateTime.now();
    final data = <_DayFluidData>[];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayOfWeek = [
        'Min',
        'Sen',
        'Sel',
        'Rab',
        'Kam',
        'Jum',
        'Sab',
      ][date.weekday % 7];

      // Mock intake values (0-target * 1.3 for variety)
      double intake = target * (0.4 + (i * 0.15).clamp(0, 1.3));
      if (i == 0) intake = target * 0.65; // Today's partial intake

      data.add(_DayFluidData(day: dayOfWeek, intake: intake, date: date));
    }

    return data;
  }

  @override
  Widget build(BuildContext context) {
    final weeklyData = _getWeeklyData();
    final maxValue =
        (weeklyData.map((d) => d.intake).reduce((a, b) => a > b ? a : b) * 1.1)
            .clamp(target, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cairan Mingguan',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: weeklyData.map((day) {
            final ratio = day.intake / maxValue;
            final isToday =
                day.date.year == DateTime.now().year &&
                day.date.month == DateTime.now().month &&
                day.date.day == DateTime.now().day;
            final color = day.intake > target
                ? AppColors.warning
                : day.intake >= target * 0.8
                ? AppColors.primary
                : AppColors.textHint;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  children: [
                    // Bar with rounded top
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.divider.withValues(alpha: 0.3),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: (ratio * 80).clamp(0, 80),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${day.intake.toInt()}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isToday
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day.day,
                      style: TextStyle(
                        fontSize: 10,
                        color: isToday ? AppColors.primary : AppColors.textHint,
                        fontWeight: isToday
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    if (isToday)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Legend
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'Target',
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'Berlebih',
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DAY FLUID DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _DayFluidData {
  final String day;
  final double intake;
  final DateTime date;

  _DayFluidData({required this.day, required this.intake, required this.date});
}

class _NutrientData {
  final String label;
  final double intake;
  final double target;
  final String unit;
  final IconData icon;

  const _NutrientData(
    this.label,
    this.intake,
    this.target,
    this.unit,
    this.icon,
  );

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
            Text(
              data.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (data.exceeded)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Melebihi!',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(
              '${_fmt(data.intake)} / ${_fmt(data.target)} ${data.unit}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
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
// KIDNEY FLUID INTAKE GAUGE (Circular Progress for Cairan)
// ─────────────────────────────────────────────────────────────────────────────

class _KidneyFluidGauge extends StatelessWidget {
  final double intake;
  final double target;

  const _KidneyFluidGauge({required this.intake, required this.target});

  double get _ratio => target > 0 ? intake / target : 0;
  bool get _exceeded => intake > target;
  double get _remaining => (target - intake).clamp(0, target);

  Color get _gaugeColor {
    if (_exceeded) return AppColors.error;
    if (_ratio >= 0.8) return AppColors.warning;
    if (_ratio >= 0.5) return AppColors.primary;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.kidneyColor.withValues(alpha: 0.15),
            AppColors.kidneyColor.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.kidneyColor.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          // Title
          Row(
            children: [
              Icon(
                Icons.opacity_outlined,
                color: AppColors.kidneyColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Target Cairan Harian',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Circular gauge with progress
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.divider.withValues(alpha: 0.3),
                    ),
                  ),
                  // Progress arc (using CustomPaint for curved progress)
                  CustomPaint(
                    painter: _CircleProgressPainter(
                      progress: _ratio.clamp(0.0, 1.0),
                      color: _gaugeColor,
                      backgroundColor: AppColors.divider.withValues(alpha: 0.2),
                      strokeWidth: 12,
                    ),
                    size: const Size(200, 200),
                  ),
                  // Center content
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${intake.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: _gaugeColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'dari ${target.toStringAsFixed(0)} ml',
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
          const SizedBox(height: 20),

          // Status bars
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  icon: Icons.check_circle_outline,
                  label: 'Terserap',
                  value: '${intake.toStringAsFixed(0)} ml',
                  color: AppColors.success,
                ),
                Container(width: 1, height: 40, color: AppColors.divider),
                _StatItem(
                  icon: _exceeded
                      ? Icons.warning_outlined
                      : Icons.hourglass_bottom_outlined,
                  label: _exceeded ? 'Berlebih' : 'Sisa',
                  value: '${_remaining.toStringAsFixed(0)} ml',
                  color: _exceeded ? AppColors.error : AppColors.warning,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for circular progress indicator
class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _CircleProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    this.strokeWidth = 8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final angle = (progress * 360 * pi / 180);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Start from top
      angle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
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
          Icon(Icons.info_outline_rounded, color: AppColors.textHint, size: 36),
          const SizedBox(height: 10),
          const Text(
            'Formula nutrisi untuk penyakit Anda\nsedang dikembangkan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
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

  const _FoodListSection({
    required this.entries,
    required this.onDelete,
    required this.onEdit,
  });

  // Helper: Group entries by meal type
  Map<MealType, List<FoodLogEntry>> _groupByMealType() {
    final grouped = <MealType, List<FoodLogEntry>>{};
    for (final meal in MealType.values) {
      grouped[meal] = entries.where((e) => e.mealType == meal).toList();
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByMealType();
    final hasFood = entries.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Makanan Hari Ini',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${entries.length} item',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!hasFood)
          const _EmptyFoodState()
        else
          ...MealType.values.map((meal) {
            final mealEntries = grouped[meal]!;
            if (mealEntries.isEmpty) return const SizedBox.shrink();
            return _MealSection(
              mealType: meal,
              entries: mealEntries,
              onDelete: onDelete,
              onEdit: onEdit,
            );
          }),
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
          Icon(
            Icons.restaurant_menu_outlined,
            size: 48,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 12),
          const Text(
            'Belum ada makanan dicatat',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap tombol + untuk menambahkan',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

// New widget: Section for each meal type with all entries and subtotals
class _MealSection extends StatelessWidget {
  final MealType mealType;
  final List<FoodLogEntry> entries;
  final Future<void> Function(FoodLogEntry) onDelete;
  final Future<void> Function(FoodLogEntry) onEdit;

  const _MealSection({
    required this.mealType,
    required this.entries,
    required this.onDelete,
    required this.onEdit,
  });

  // Calculate subtotals for this meal
  Map<String, double> _calculateSubtotals() {
    return {
      'energi': entries.fold(0.0, (sum, e) => sum + e.energi),
      'protein': entries.fold(0.0, (sum, e) => sum + e.protein),
      'natrium': entries.fold(0.0, (sum, e) => sum + e.natrium),
      'kalium': entries.fold(0.0, (sum, e) => sum + e.kalium),
      'fosfor': entries.fold(0.0, (sum, e) => sum + e.fosfor),
      'air': entries.fold(0.0, (sum, e) => sum + e.air),
    };
  }

  @override
  Widget build(BuildContext context) {
    final subtotals = _calculateSubtotals();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Meal header with emoji and time range
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(mealType.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mealType.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      mealType.timeRange,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${entries.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Food entries
        ...entries.map(
          (e) => _FoodEntryCard(
            entry: e,
            onDelete: () => onDelete(e),
            onEdit: () => onEdit(e),
          ),
        ),
        // Meal subtotals
        Container(
          margin: const EdgeInsets.fromLTRB(0, 4, 0, 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal Kalori: ${subtotals['energi']!.toStringAsFixed(0)} kkal',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Na: ${subtotals['natrium']!.toStringAsFixed(0)} mg  ·  P: ${subtotals['protein']!.toStringAsFixed(1)} g',
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FoodEntryCard extends StatelessWidget {
  final FoodLogEntry entry;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _FoodEntryCard({
    required this.entry,
    required this.onDelete,
    required this.onEdit,
  });

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
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: onEdit,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.restaurant_outlined,
            color: Colors.orange,
            size: 22,
          ),
        ),
        title: Text(
          entry.foodName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${entry.grams.toInt()} g  ·  ${entry.energi.toStringAsFixed(0)} kkal',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'P: ${entry.protein.toStringAsFixed(1)} g',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'Na: ${entry.natrium.toStringAsFixed(1)} mg',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                size: 20,
                color: AppColors.textSecondary,
              ),
              onSelected: (val) {
                if (val == 'edit') onEdit();
                if (val == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 10),
                      Text('Edit Gram'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AppColors.error,
                      ),
                      SizedBox(width: 10),
                      Text('Hapus', style: TextStyle(color: AppColors.error)),
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
  final MealType mealType; // ← NEW
  final Future<void> Function(FoodItem food, double grams) onAdd;
  const _AddFoodSheet({
    required this.mealType, // ← NEW
    required this.onAdd,
  });

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
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() => _isSearching = true);
    final results = await FoodDatabaseService.search(q);
    if (mounted)
      setState(() {
        _results = results;
        _isSearching = false;
      });
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.nama,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  food.kategori,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.normal,
                  ),
                ),
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
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Berat (gram)',
                      suffixText: 'g',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
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
                        _previewRow(
                          'Cairan (Air)',
                          n['air']!,
                          'ml',
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: grams > 0
                    ? () async {
                        Navigator.pop(ctx); // tutup dialog
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

  Widget _previewRow(
    String label,
    double value,
    String unit, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            '${value.toStringAsFixed(1)} $unit',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Tambah Makanan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                        child: Text(
                          'Tidak ditemukan',
                          style: TextStyle(color: AppColors.textHint),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final food = _results[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 4,
                            ),
                            title: Text(
                              food.nama,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '${food.energi.toInt()} kkal  ·  P: ${food.protein}g  ·  Na: ${food.natrium.toInt()}mg',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.add_circle_outline,
                              color: AppColors.primary,
                            ),
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

  const _EditGramDialog({
    required this.entry,
    required this.food,
    required this.onSave,
  });

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
    _gramCtrl = TextEditingController(
      text: widget.entry.grams.toInt().toString(),
    );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gram harus lebih dari 0')));
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
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final g = double.tryParse(_gramCtrl.text) ?? 0;
    return AlertDialog(
      title: Text(
        'Edit ${widget.food.nama}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Jumlah (gram)',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _gramCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                suffixText: 'g',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (_) => _recalc(),
            ),
            if (g > 0) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 4),
              const Text(
                'Perkiraan Gizi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _row(
                'Energi',
                '${(_preview['energi'] ?? 0).toStringAsFixed(1)} kkal',
              ),
              _row(
                'Protein',
                '${(_preview['protein'] ?? 0).toStringAsFixed(1)} g',
              ),
              _row('Lemak', '${(_preview['lemak'] ?? 0).toStringAsFixed(1)} g'),
              _row(
                'Karbohidrat',
                '${(_preview['karbohidrat'] ?? 0).toStringAsFixed(1)} g',
              ),
              _row(
                'Natrium',
                '${(_preview['natrium'] ?? 0).toStringAsFixed(1)} mg',
              ),
              _row(
                'Kalium',
                '${(_preview['kalium'] ?? 0).toStringAsFixed(1)} mg',
              ),
              _row(
                'Fosfor',
                '${(_preview['fosfor'] ?? 0).toStringAsFixed(1)} mg',
              ),
              _row('Air', '${(_preview['air'] ?? 0).toStringAsFixed(1)} ml'),
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
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
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

  const _TakaranSajiContent({
    required this.food,
    required this.onSave,
    required this.onCancel,
  });

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
    'Tidak\nmakan',
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
      color: AppColors.textPrimary,
    ),
  );

  Widget _previewRow(String label, double value, String unit) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        Text(
          '${value.toStringAsFixed(1)} $unit',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
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
          Text(
            widget.food.nama,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Text(
            'Berapa yang kamu makan?',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
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
                      right: i < takaran.length - 1 ? 8 : 0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? AppColors.primary : Colors.grey.shade200,
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.food.emoji,
                          style: TextStyle(fontSize: emojiSize),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: sel
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${t.gram.toInt()} g',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: sel
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
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
                color: _count > 1 ? AppColors.primary : Colors.grey.shade300,
                onPressed: _count > 1 ? () => setState(() => _count--) : null,
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '$_count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
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
                          color: sel ? AppColors.primary : Colors.grey.shade300,
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
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.2,
                        color: sel
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
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
                  Text(
                    '${gram.toStringAsFixed(0)} g dimakan',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _previewRow('Energi', preview['energi']!, 'kkal'),
                  _previewRow('Protein', preview['protein']!, 'g'),
                  _previewRow('Lemak', preview['lemak']!, 'g'),
                  _previewRow('Karbohidrat', preview['karbohidrat']!, 'g'),
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
                child: Text(
                  'Makanan tidak dicatat (sisa 100%)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
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
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
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
    canvas.drawCircle(center, radius, Paint()..color = Colors.grey.shade100);

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

// ─────────────────────────────────────────────────────────────────────────────
// DM DAILY MEAL TABLE - Hierarchical table with per-meal breakdown
// ─────────────────────────────────────────────────────────────────────────────

class _DMDailyMealTable extends StatelessWidget {
  final Map<MealType, List<FoodLogEntry>> entriesByMeal;
  final NutritionNeeds needs;

  const _DMDailyMealTable({required this.entriesByMeal, required this.needs});

  // DM meal distribution (20% + 15% + 30% + 10% + 25% = 100%)
  static const List<MealType> _dmMealOrder = [
    MealType.sarapan,
    MealType.selinganPagi,
    MealType.makanSiang,
    MealType.selinganSiang,
    MealType.makanMalam,
  ];

  Map<String, double> _calculateMealTotals(List<FoodLogEntry> entries) {
    return {
      'energi': entries.fold(0.0, (sum, e) => sum + e.energi),
      'protein': entries.fold(0.0, (sum, e) => sum + e.protein),
      'lemak': entries.fold(0.0, (sum, e) => sum + e.lemak),
      'serat': entries.fold(0.0, (sum, e) => sum + e.serat),
    };
  }

  Map<String, double> _calculateDailyTotals() {
    double totalEnergi = 0, totalProtein = 0, totalLemak = 0, totalSerat = 0;
    for (final meal in entriesByMeal.values) {
      final totals = _calculateMealTotals(meal);
      totalEnergi += totals['energi']!;
      totalProtein += totals['protein']!;
      totalLemak += totals['lemak']!;
      totalSerat += totals['serat']!;
    }
    return {
      'energi': totalEnergi,
      'protein': totalProtein,
      'lemak': totalLemak,
      'serat': totalSerat,
    };
  }

  Color _getStatusColor(double percentage) {
    if (percentage >= 0.9 && percentage <= 1.1) {
      return const Color(0xFF4CAF50); // Green - ideal
    } else if (percentage >= 0.8 && percentage <= 1.2) {
      return const Color(0xFFFFC107); // Amber - acceptable
    } else {
      return const Color(0xFFF44336); // Red - warning
    }
  }

  String _formatPercentage(double percentage) {
    return '${(percentage * 100).toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Daily Summary Section (at top) ──
        _DailyInterpretationTable(
          entriesByMeal: entriesByMeal,
          totalNeeds: needs,
          calculateDailyTotals: _calculateDailyTotals,
          getStatusColor: _getStatusColor,
          formatPercentage: _formatPercentage,
        ),

        const SizedBox(height: 20),

        // ── Per-Meal Sections ──
        for (final mealType in _dmMealOrder)
          _MealTableSection(
            mealType: mealType,
            entries: entriesByMeal[mealType] ?? [],
            totalNeeds: needs,
            getStatusColor: _getStatusColor,
            formatPercentage: _formatPercentage,
            calculateMealTotals: _calculateMealTotals,
          ),
      ],
    );
  }
}

class _MealTableSection extends StatelessWidget {
  final MealType mealType;
  final List<FoodLogEntry> entries;
  final NutritionNeeds totalNeeds;
  final Color Function(double) getStatusColor;
  final String Function(double) formatPercentage;
  final Map<String, double> Function(List<FoodLogEntry>) calculateMealTotals;

  const _MealTableSection({
    required this.mealType,
    required this.entries,
    required this.totalNeeds,
    required this.getStatusColor,
    required this.formatPercentage,
    required this.calculateMealTotals,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = mealType.dmCaloriePercentage;
    if (percentage == 0.0)
      return const SizedBox.shrink(); // Skip selingan malam

    final targetEnergi = totalNeeds.energi * percentage;
    final targetProtein = totalNeeds.protein * percentage;
    final targetLemak = totalNeeds.lemak * percentage;
    final targetSerat = totalNeeds.serat * percentage;

    final totals = calculateMealTotals(entries);
    final actualEnergi = totals['energi']!;
    final actualProtein = totals['protein']!;
    final actualLemak = totals['lemak']!;
    final actualSerat = totals['serat']!;

    final energiRatio = targetEnergi > 0 ? actualEnergi / targetEnergi : 0.0;
    final statusColor = getStatusColor(energiRatio);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(mealType.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mealType.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${(percentage * 100).toStringAsFixed(0)}% dari kebutuhan',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    formatPercentage(energiRatio),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Food items table header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1),
                5: FlexColumnWidth(1),
                6: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  children: [
                    _tableHeaderCell('Menu'),
                    _tableHeaderCell('Energi'),
                    _tableHeaderCell('Protein'),
                    _tableHeaderCell('Lemak'),
                    _tableHeaderCell('Karbo'),
                    _tableHeaderCell('Serat'),
                    _tableHeaderCell('Berat(g)'),
                  ],
                ),
              ],
            ),
          ),

          // Food items rows
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Belum ada makanan',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                  4: FlexColumnWidth(1),
                  5: FlexColumnWidth(1),
                  6: FlexColumnWidth(1),
                },
                children: [
                  for (final entry in entries)
                    TableRow(
                      children: [
                        _tableDataCell(entry.foodName, isBold: false),
                        _tableDataCell(entry.energi.toStringAsFixed(0)),
                        _tableDataCell(entry.protein.toStringAsFixed(1)),
                        _tableDataCell(entry.lemak.toStringAsFixed(1)),
                        _tableDataCell(entry.karbohidrat.toStringAsFixed(1)),
                        _tableDataCell(entry.serat.toStringAsFixed(1)),
                        _tableDataCell(entry.grams.toStringAsFixed(0)),
                      ],
                    ),
                ],
              ),
            ),

          const Divider(height: 1),

          // Total asupan row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1),
                5: FlexColumnWidth(1),
                6: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade50),
                  children: [
                    _tableDataCell('Total Asupan', isBold: true),
                    _tableDataCell(
                      actualEnergi.toStringAsFixed(0),
                      isBold: true,
                    ),
                    _tableDataCell(
                      actualProtein.toStringAsFixed(1),
                      isBold: true,
                    ),
                    _tableDataCell(
                      actualLemak.toStringAsFixed(1),
                      isBold: true,
                    ),
                    _tableDataCell(
                      (totals['karbohidrat'] ?? 0).toStringAsFixed(1),
                      isBold: true,
                    ),
                    _tableDataCell(
                      actualSerat.toStringAsFixed(1),
                      isBold: true,
                    ),
                    _tableDataCell('', isBold: true),
                  ],
                ),
                TableRow(
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.05),
                  ),
                  children: [
                    _tableDataCell(
                      'Total ${(percentage * 100).toStringAsFixed(0)}% Kebutuhan',
                      isBold: true,
                      color: statusColor,
                    ),
                    _tableDataCell(
                      targetEnergi.toStringAsFixed(0),
                      isBold: true,
                      color: statusColor,
                    ),
                    _tableDataCell(
                      targetProtein.toStringAsFixed(1),
                      isBold: true,
                      color: statusColor,
                    ),
                    _tableDataCell(
                      targetLemak.toStringAsFixed(1),
                      isBold: true,
                      color: statusColor,
                    ),
                    _tableDataCell(
                      (targetEnergi *
                              (totalNeeds.karbohidrat / totalNeeds.energi))
                          .toStringAsFixed(1),
                      isBold: true,
                      color: statusColor,
                    ),
                    _tableDataCell(
                      targetSerat.toStringAsFixed(1),
                      isBold: true,
                      color: statusColor,
                    ),
                    _tableDataCell('', isBold: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: Colors.grey,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _tableDataCell(String text, {bool isBold = true, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          fontSize: 11,
          color: color ?? Colors.black87,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _DailyInterpretationTable extends StatelessWidget {
  final Map<MealType, List<FoodLogEntry>> entriesByMeal;
  final NutritionNeeds totalNeeds;
  final Map<String, double> Function() calculateDailyTotals;
  final Color Function(double) getStatusColor;
  final String Function(double) formatPercentage;

  const _DailyInterpretationTable({
    required this.entriesByMeal,
    required this.totalNeeds,
    required this.calculateDailyTotals,
    required this.getStatusColor,
    required this.formatPercentage,
  });

  @override
  Widget build(BuildContext context) {
    const mealOrder = [
      MealType.sarapan,
      MealType.selinganPagi,
      MealType.makanSiang,
      MealType.selinganSiang,
      MealType.makanMalam,
    ];

    final dailyTotals = calculateDailyTotals();
    final dailyEnergiRatio = totalNeeds.energi > 0
        ? dailyTotals['energi']! / totalNeeds.energi
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Text(
              'Interpretasi Hasil (%)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),

          // Daily summary table
          Padding(
            padding: const EdgeInsets.all(12),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(1),
                5: FlexColumnWidth(1),
              },
              children: [
                // Header row
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  children: [
                    _interpHeaderCell('Energi'),
                    _interpHeaderCell('Protein'),
                    _interpHeaderCell('Lemak'),
                    _interpHeaderCell('Karbo'),
                    _interpHeaderCell('Serat'),
                    _interpHeaderCell('%'),
                  ],
                ),

                // Daily total row
                _buildDailySummaryRow(dailyEnergiRatio),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Meals interpretation header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Ringkasan Per Waktu Makan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),

          // Meals interpretation rows
          Padding(
            padding: const EdgeInsets.all(12),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
              },
              children: [
                // Header row
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  children: [
                    _interpHeaderCell('Waktu Makan'),
                    _interpHeaderCell('Target'),
                    _interpHeaderCell('Aktual'),
                    _interpHeaderCell('%'),
                  ],
                ),

                // Meal rows
                for (final meal in mealOrder)
                  if (meal.dmCaloriePercentage > 0)
                    _buildMealInterpretationRow(
                      meal,
                      entriesByMeal[meal] ?? [],
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildMealInterpretationRow(
    MealType meal,
    List<FoodLogEntry> entries,
  ) {
    final percentage = meal.dmCaloriePercentage;
    final targetEnergi = totalNeeds.energi * percentage;
    final actualEnergi = entries.fold(0.0, (sum, e) => sum + e.energi);
    final ratio = targetEnergi > 0 ? actualEnergi / targetEnergi : 0.0;
    final statusColor = getStatusColor(ratio);

    return TableRow(
      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.05)),
      children: [
        _interpDataCell('${meal.emoji} ${meal.label}'),
        _interpDataCell(targetEnergi.toStringAsFixed(0)),
        _interpDataCell(actualEnergi.toStringAsFixed(0)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              formatPercentage(ratio),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildDailySummaryRow(double dailyRatio) {
    final statusColor = getStatusColor(dailyRatio);
    final dailyTotals = calculateDailyTotals();

    return TableRow(
      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1)),
      children: [
        _interpDataCell(
          dailyTotals['energi']!.toStringAsFixed(0),
          isBold: true,
          color: statusColor,
        ),
        _interpDataCell(
          dailyTotals['protein']!.toStringAsFixed(1),
          isBold: true,
          color: statusColor,
        ),
        _interpDataCell(
          dailyTotals['lemak']!.toStringAsFixed(1),
          isBold: true,
          color: statusColor,
        ),
        _interpDataCell(
          (dailyTotals['energi']! *
                  (totalNeeds.karbohidrat / totalNeeds.energi))
              .toStringAsFixed(1),
          isBold: true,
          color: statusColor,
        ),
        _interpDataCell(
          dailyTotals['serat']!.toStringAsFixed(1),
          isBold: true,
          color: statusColor,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              formatPercentage(dailyRatio),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _interpHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: Colors.grey,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _interpDataCell(String text, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          fontSize: 11,
          color: color ?? Colors.black87,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
