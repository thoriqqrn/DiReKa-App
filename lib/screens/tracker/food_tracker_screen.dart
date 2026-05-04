// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../models/disease_type.dart';
import '../../models/food_item.dart';
import '../../models/food_log_entry.dart';
import '../../models/meal_type.dart';
import '../../models/nutrition_needs.dart';
import '../../providers/auth_provider.dart';
import '../../services/food_database_service.dart';
import '../../services/food_log_service.dart';
import '../../services/app_notification_service.dart';
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
    await _loadEntriesInternal(showFullScreenLoading: true);
  }

  Future<void> _loadEntriesInternal({required bool showFullScreenLoading}) async {
    if (_uid.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    if (showFullScreenLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final entries = await FoodLogService.getEntries(_uid, _selectedDate);
      if (mounted) setState(() => _entries = entries);
      // Sinkronkan ulang data mingguan agar chart ikut terupdate (terutama untuk ginjal dan jantung)
      await _loadWeeklyData();
    } catch (e) {
      if (mounted) {
        setState(() => _entries = []);
      }
    } finally {
      if (showFullScreenLoading && mounted) setState(() => _isLoading = false);
    }
  }

  void _changeDate(int days) {
    final newDate = _selectedDate.add(Duration(days: days));
    if (newDate.isBefore(DateTime.now().add(const Duration(days: 1)))) {
      setState(() => _selectedDate = newDate);
      // Jangan tampilkan full-screen loading saat ganti tanggal agar posisi scroll tidak reset.
      _loadEntriesInternal(showFullScreenLoading: false);
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _deleteEntry(FoodLogEntry entry) async {
    final theme = Theme.of(context);
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
            child: Text(
              'Hapus',
              style: TextStyle(color: theme.colorScheme.error),
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
    final auth = context.read<AuthProvider>();
    final isGuest = auth.firebaseUser == null && auth.currentUser == null;
    _showMealTimeSelector(isGuest: isGuest);
  }

  void _showMealTimeSelector({bool isGuest = false}) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardTheme.color,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Pilih Waktu Makan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.titleLarge?.color),
              ),
            ),
            ...MealType.values
                .map(
                  (meal) => InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _selectedMealType = meal);
                      _proceedToFoodSearch(isGuest: isGuest);
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
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                Text(
                                  meal.timeRange,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.hintColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: theme.primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _proceedToFoodSearch({bool isGuest = false}) {
    if (_selectedMealType == null) return;
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.uid ?? auth.firebaseUser?.uid ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddFoodSheet(
        mealType: _selectedMealType!,
        isGuest: isGuest,
        onAddAll: (cartItems) async {
          if (cartItems.isEmpty) return;
          final mealType = _selectedMealType!;
          final entries = cartItems
              .map((item) => FoodLogEntry.create(
                    food: item.food,
                    grams: item.grams,
                    mealType: mealType,
                  ))
              .toList();
          await FoodLogService.addEntries(uid, _selectedDate, entries);
          if (mounted) {
            final auth = context.read<AuthProvider>();
            auth.updateActivityStreak();
            if (auth.currentUser != null) {
              AppNotificationService.refreshForUser(auth.currentUser!);
            }
            _loadEntries();
          }
        },
      ),
    );
  }

  /// Build HF weekly charts section
  Widget _hfWeeklyChartsSection({required List<DailyNutrition> weeklyData}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Grafik Nutrisi Mingguan',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: theme.textTheme.titleSmall?.color,
            ),
          ),
        ),
        // Energi Chart
        _buildHFNutritionChart(
          title: 'Energi',
          unit: 'kkal',
          weeklyData: weeklyData,
          lineColor: Colors.blue.shade600,
          getActual: (data) => data.energi,
          getTarget: (data) => data.targetEnergi,
        ),
        const SizedBox(height: 12),
        // Lemak Chart
        _buildHFNutritionChart(
          title: 'Lemak',
          unit: 'g',
          weeklyData: weeklyData,
          lineColor: Colors.orange.shade700,
          getActual: (data) => data.lemak,
          getTarget: (data) => data.targetLemak,
          showTargetLine: false,
        ),
        const SizedBox(height: 12),
        // Natrium Chart
        _buildHFNutritionChart(
          title: 'Natrium',
          unit: 'mg',
          weeklyData: weeklyData,
          lineColor: Colors.purple.shade600,
          getActual: (data) => data.natrium,
          getTarget: (data) => data.targetNatrium,
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
    bool showTargetLine = true,
  }) {
    final actualMax = weeklyData.fold<double>(
      0,
      (max, data) => getActual(data) > max ? getActual(data) : max,
    );
    final targetMax = weeklyData.fold<double>(
      0,
      (max, data) => getTarget(data) > max ? getTarget(data) : max,
    );
    final peakValue = actualMax > targetMax ? actualMax : targetMax;
    final safeMaxY = peakValue <= 0 ? 10.0 : (peakValue * 1.15);

    return NutritionLineChart(
      title: title,
      unit: unit,
      weeklyData: weeklyData,
      lineColor: lineColor,
      getActual: getActual,
      getTarget: getTarget,
      showTargetLine: showTargetLine,
      minY: 0,
      maxY: safeMaxY,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final needs = auth.currentUser?.nutritionNeeds;
    // True jika user sudah login Firebase tapi userModel belum selesai load
    final isUserModelLoading =
        auth.firebaseUser != null && auth.currentUser == null;
    final intake = _totalIntake;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isUserModelLoading ||
                              auth.status == AuthStatus.loading)
                            const _NutritionLoadingCard()
                          else if (needs != null) ...[
                            // 1. Weekly fluid chart for kidney patients
                            if (auth.currentUser?.diseaseType ==
                                    DiseaseType.chronicKidneyDisease &&
                                _weeklyData != null &&
                                _weeklyData!.isNotEmpty) ...[
                              _WeeklyFluidChart(
                                target: needs.cairan,
                                weeklyData: _weeklyData!,
                              ),
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
                              _hfWeeklyChartsSection(weeklyData: _weeklyData!),
                              const SizedBox(height: 16),
                            ],
                            // 3. DM Patients: Show Glycemic Load chart and hierarchical meal table
                            if (auth.currentUser?.diseaseType ==
                                DiseaseType.type2DiabetesMellitus) ...[
                              _GlycemicLoadChart(
                                key: ValueKey('gl_chart_${_selectedDate.millisecondsSinceEpoch}_${_entries.length}'),
                                entries: _entries,
                              ),
                              const SizedBox(height: 20),
                              _DMDailyMealTable(
                                entriesByMeal: _groupEntriesByMeal(_entries),
                                needs: needs,
                                onEditEntry: _editEntry,
                                onDeleteEntry: _deleteEntry,
                              ),
                            ]
                            // 3. Other patients: Show nutrition summary
                            else ...[
                              _NutritionSummaryCard(
                                needs: needs,
                                intake: intake,
                                diseaseType: auth.currentUser?.diseaseType,
                              ),
                            ],
                          ] else
                            const _NoFormulaCard(),
                          const SizedBox(height: 16),
                          if (auth.currentUser?.diseaseType !=
                              DiseaseType.type2DiabetesMellitus)
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF62E7D9).withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.25),
                blurRadius: theme.brightness == Brightness.dark ? 22 : 14,
                spreadRadius: theme.brightness == Brightness.dark ? 1 : 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: _showAddFoodSheet,
            backgroundColor: theme.primaryColor,
            elevation: theme.brightness == Brightness.dark ? 2 : 4,
            highlightElevation: theme.brightness == Brightness.dark ? 4 : 6,
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            label: const Text(
              'Tambah Makanan',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
    final theme = Theme.of(context);
    final label = isToday
        ? 'Hari Ini · ${DateFormat('d MMM y').format(date)}'
        : DateFormat('EEE, d MMM y').format(date);

    return Container(
      color: theme.cardTheme.color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _navCircleButton(
            context: context,
            onTap: onPrev,
            icon: Icons.chevron_left,
            fillColor: const Color(0xFF64B5F6).withValues(alpha: 0.52), // light blue transparent
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ),
          _navCircleButton(
            context: context,
            onTap: canGoNext ? onNext : null,
            icon: Icons.chevron_right,
            fillColor: canGoNext
                ? const Color(0xFF64B5F6).withValues(alpha: 0.52) // light blue transparent
                : const Color(0xFFE5EAF1), // light gray when disabled
            iconColor: canGoNext ? Colors.white : const Color(0xFF9AA4B2),
          ),
        ],
      ),
    );
  }

  Widget _navCircleButton({
    required BuildContext context,
    required VoidCallback? onTap,
    required IconData icon,
    required Color fillColor,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: fillColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: iconColor ?? Colors.white,
          size: 18,
        ),
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
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.primaryColor),
          ),
          const SizedBox(width: 12),
          Text(
            'Memuat data nutrisi...',
            style: TextStyle(color: theme.hintColor, fontSize: 13),
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
  bool get _isHF => diseaseType == DiseaseType.heartFailure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();
    final themeColor = _isDM ? (ext?.diabetesColor ?? Colors.orange) : (ext?.kidneyColor ?? Colors.red);
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
        // Kalium & Fosfor: tidak relevan untuk Jantung Koroner (HF),
        // hanya ditampilkan untuk CKD dan penyakit lainnya.
        if (!_isHF) ...[
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
        ],
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
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: theme.brightness == Brightness.dark 
            ? Border.all(color: theme.dividerColor)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05),
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
                    color: themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.bar_chart_rounded,
                    color: themeColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ringkasan Nutrisi Harian',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: theme.textTheme.titleMedium?.color,
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
                    Text(
                      'energi',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),

          // ── Nutrient rows ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: nutrients
                  .map(
                    (n) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _NutrientRow(data: n, diseaseType: diseaseType),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Color _progressColor(double ratio) {
    if (diseaseType == DiseaseType.chronicKidneyDisease) {
      if (ratio >= 1.1) return AppColors.error; // Merah >= 110%
      if (ratio >= 0.9) return AppColors.success; // Hijau 90% - 110%
      return AppColors.warning; // Kuning < 90%
    }
    // Default/DM logic
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
  final List<DailyNutrition> weeklyData;

  const _WeeklyFluidChart({required this.target, required this.weeklyData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue =
        (weeklyData.map((d) => d.cairan).reduce((a, b) => a > b ? a : b) * 1.1)
            .clamp(target, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cairan Mingguan',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.hintColor,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: weeklyData.map((day) {
            final ratio = day.cairan / maxValue;
            final isToday =
                day.date.year == DateTime.now().year &&
                day.date.month == DateTime.now().month &&
                day.date.day == DateTime.now().day;
            final targetRatio = day.cairan / (target > 0 ? target : 1.0);
            final color = targetRatio >= 1.1
                ? AppColors.error // Merah >= 110%
                : targetRatio >= 0.9
                ? AppColors.success // Hijau 90% - 110%
                : AppColors.warning; // Kuning < 90%
            
            final dayOfWeek = [
              'Min',
              'Sen',
              'Sel',
              'Rab',
              'Kam',
              'Jum',
              'Sab',
            ][day.date.weekday % 7];

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  children: [
                    // Bar with rounded top
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withValues(alpha: 0.1),
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
                      '${day.cairan.toInt()} ml',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isToday
                            ? theme.primaryColor
                            : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dayOfWeek,
                      style: TextStyle(
                        fontSize: 10,
                        color: isToday ? theme.primaryColor : theme.hintColor,
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
                          color: theme.primaryColor,
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
                color: theme.primaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Target',
              style: TextStyle(fontSize: 10, color: theme.hintColor),
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
            Text(
              'Berlebih',
              style: TextStyle(fontSize: 10, color: theme.hintColor),
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
  final DiseaseType? diseaseType;
  const _NutrientRow({required this.data, this.diseaseType});

  Color get _barColor {
    if (diseaseType == DiseaseType.chronicKidneyDisease) {
      if (data.ratio >= 1.1) return AppColors.error;
      if (data.ratio >= 0.9) return AppColors.success;
      return AppColors.warning;
    }
    if (data.exceeded) return AppColors.error; // Merah jika > 100%
    if (data.ratio >= 0.8) return AppColors.success; // Hijau jika >= 80%
    return AppColors.warning; // Kuning jika < 80%
  }

  bool get _isExceeded {
    if (diseaseType == DiseaseType.chronicKidneyDisease) {
      return data.ratio >= 1.1;
    }
    return data.exceeded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(data.icon, size: 13, color: theme.hintColor),
            const SizedBox(width: 6),
            Text(
              data.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const Spacer(),
            if (_isExceeded)
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
              style: TextStyle(
                fontSize: 11,
                color: theme.hintColor,
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
            backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
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
  double get _excess => (intake - target).clamp(0, double.infinity);

  Color get _gaugeColor {
    if (_ratio >= 1.1) return AppColors.error; // Merah >= 110%
    if (_ratio >= 0.9) return AppColors.success; // Hijau 90% - 110%
    return AppColors.warning; // Kuning < 90%
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();
    final kidneyColor = ext?.kidneyColor ?? AppColors.kidneyColor;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kidneyColor.withValues(alpha: 0.15),
            kidneyColor.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kidneyColor.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          // Title
          Row(
            children: [
              Icon(
                Icons.opacity_outlined,
                color: kidneyColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Target Cairan Harian',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: theme.textTheme.bodyLarge?.color,
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
                      color: theme.dividerColor.withValues(alpha: 0.1),
                    ),
                  ),
                  // Progress arc (using CustomPaint for curved progress)
                  CustomPaint(
                    painter: _CircleProgressPainter(
                      progress: _ratio.clamp(0.0, 1.0),
                      color: _gaugeColor,
                      backgroundColor: theme.dividerColor.withValues(alpha: 0.05),
                      strokeWidth: 12,
                    ),
                    size: const Size(200, 200),
                  ),
                  // Center content
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        intake.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: _gaugeColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'dari ${target.toStringAsFixed(0)} ml',
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
          const SizedBox(height: 20),

          // Status bars
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.dividerColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
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
                Container(width: 1, height: 40, color: theme.dividerColor.withValues(alpha: 0.3)),
                _StatItem(
                  icon: _exceeded
                      ? Icons.warning_outlined
                      : Icons.hourglass_bottom_outlined,
                  label: _exceeded ? 'Berlebih' : 'Sisa',
                  value: _exceeded
                      ? '${_excess.toStringAsFixed(0)} ml'
                      : '${_remaining.toStringAsFixed(0)} ml',
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
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: theme.hintColor),
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
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline_rounded, color: theme.hintColor, size: 36),
          const SizedBox(height: 10),
          Text(
            'Formula nutrisi untuk penyakit Anda\nsedang dikembangkan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.hintColor,
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
    final theme = Theme.of(context);
    final grouped = _groupByMealType();
    final hasFood = entries.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Makanan Hari Ini',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: theme.textTheme.titleMedium?.color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${entries.length} item',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.primaryColor,
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
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.restaurant_menu_outlined,
            size: 48,
            color: theme.hintColor,
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada makanan dicatat',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap tombol + untuk menambahkan',
            style: TextStyle(fontSize: 12, color: theme.hintColor.withValues(alpha: 0.7)),
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
    final theme = Theme.of(context);
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    Text(
                      mealType.timeRange,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${entries.length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.primaryColor,
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
            color: theme.dividerColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal Kalori: ${subtotals['energi']!.toStringAsFixed(0)} kkal',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.hintColor,
                ),
              ),
              Text(
                'Na: ${subtotals['natrium']!.toStringAsFixed(0)} mg  ·  P: ${subtotals['protein']!.toStringAsFixed(1)} g',
                style: TextStyle(fontSize: 11, color: theme.hintColor.withValues(alpha: 0.8)),
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
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: theme.brightness == Brightness.dark ? Border.all(color: theme.dividerColor) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.04),
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
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: Text(
          '${entry.grams.toInt()} g  ·  ${entry.energi.toStringAsFixed(0)} kkal',
          style: TextStyle(fontSize: 12, color: theme.hintColor),
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
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.hintColor,
                  ),
                ),
                Text(
                  'Na: ${entry.natrium.toStringAsFixed(1)} mg',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: theme.hintColor,
              ),
              onSelected: (val) {
                if (val == 'edit') onEdit();
                if (val == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: theme.primaryColor,
                      ),
                      const SizedBox(width: 10),
                      const Text('Edit Gram'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 10),
                      Text('Hapus', style: TextStyle(color: theme.colorScheme.error)),
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

/// A single item sitting in the temporary cart before batch-submit.
class _CartItem {
  final FoodItem food;
  final double grams;
  _CartItem({required this.food, required this.grams});
}

class _AddFoodSheet extends StatefulWidget {
  final MealType mealType;
  final bool isGuest;
  final Future<void> Function(List<_CartItem> cartItems) onAddAll;
  const _AddFoodSheet({
    required this.mealType,
    required this.onAddAll,
    this.isGuest = false,
  });

  @override
  State<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<_AddFoodSheet> {
  final _searchCtrl = TextEditingController();
  List<FoodItem> _results = [];
  List<String> _categories = [];
  String _selectedCategory = 'Semua';
  bool _isSearching = false;
  Timer? _debounce;

  // ── Cart state ──────────────────────────────────────────────────────────────
  final List<_CartItem> _cart = [];

  void _addToCart(FoodItem food, double grams) {
    setState(() => _cart.add(_CartItem(food: food, grams: grams)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${food.nama} ditambahkan ke keranjang'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      ),
    );
  }

  void _removeFromCart(int index) {
    setState(() => _cart.removeAt(index));
  }
  // ────────────────────────────────────────────────────────────────────────────

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
    if (mounted) {
      // Build category list from full results (only on first/empty load)
      final cats = <String>{};
      for (final f in results) {
        if (f.kategori.isNotEmpty) cats.add(f.kategori);
      }
      final sortedCats = cats.toList()..sort();
      setState(() {
        _results = results;
        _isSearching = false;
        if (q.isEmpty) _categories = ['Semua', ...sortedCats];
      });
    }
  }

  /// Results after applying category filter
  List<FoodItem> get _filteredResults {
    if (_selectedCategory == 'Semua') return _results;
    return _results.where((f) => f.kategori == _selectedCategory).toList();
  }

  void _selectFood(FoodItem food) {
    if (food.takaranSaji.isNotEmpty) {
      _showTakaranDialog(food);
    } else {
      _showGramDialog(food);
    }
  }

  /// Shows a dialog prompting the guest to login before they can save.
  void _showGuestLoginDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: theme.primaryColor),
            const SizedBox(width: 10),
            const Text('Login Diperlukan'),
          ],
        ),
        content: const Text(
          'Kamu perlu login terlebih dahulu untuk menyimpan catatan makanan. '
          'Yuk, buat akun atau masuk sekarang!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nanti Saja'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx); // tutup dialog
              Navigator.pop(context); // tutup sheet
              Navigator.pushNamed(context, AppConstants.routeLogin);
            },
            child: const Text('Login Sekarang'),
          ),
        ],
      ),
    );
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
            Navigator.pop(ctx); // tutup dialog takaran saja
            if (widget.isGuest) {
              _showGuestLoginDialog();
              return;
            }
            _addToCart(food, grams); // masuk ke keranjang, sheet tetap terbuka
          },
          onCancel: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _showGramDialog(FoodItem food) {
    final gramCtrl = TextEditingController(text: '100');
    final theme = Theme.of(context);

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
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.hintColor,
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
                      color: theme.dividerColor.withValues(alpha: 0.05),
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
                    ? () {
                        Navigator.pop(ctx); // tutup dialog gram saja
                        if (widget.isGuest) {
                          _showGuestLoginDialog();
                          return;
                        }
                        _addToCart(food, grams); // masuk ke keranjang
                      }
                    : null,
                child: const Text('Tambah ke Keranjang'),
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
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.hintColor,
            ),
          ),
          Text(
            '${value.toStringAsFixed(1)} $unit',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  bool _isCartExpanded = false;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cartCount = _cart.length;
    final cartTotalKkal = _cart.fold(
      0.0,
      (sum, item) => sum + item.food.calcFor(item.grams)['energi']!,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Handle ──
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              // ── Title row with meal label ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      widget.mealType.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tambah • ${widget.mealType.label}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.titleMedium?.color,
                        ),
                      ),
                    ),
                    if (cartCount > 0)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _isCartExpanded = !_isCartExpanded),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: theme.primaryColor
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: theme.primaryColor
                                    .withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isCartExpanded
                                    ? Icons.shopping_cart
                                    : Icons.shopping_cart_outlined,
                                size: 16,
                                color: theme.primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$cartCount item',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Keranjang expandable panel ──
              if (_isCartExpanded && cartCount > 0) ...[
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.shopping_cart,
                                size: 14, color: theme.primaryColor),
                            const SizedBox(width: 6),
                            Text(
                              'Keranjang ($cartCount item)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: theme.primaryColor,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${cartTotalKkal.toStringAsFixed(0)} kkal',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                          height: 1,
                          color: theme.primaryColor.withValues(alpha: 0.15)),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _cart.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: theme.dividerColor),
                          itemBuilder: (_, i) {
                            final item = _cart[i];
                            final kkal = item.food
                                .calcFor(item.grams)['energi']!
                                .toStringAsFixed(0);
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 0),
                              title: Text(
                                item.food.nama,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${item.grams.toInt()} g  ·  $kkal kkal',
                                style: TextStyle(
                                    fontSize: 11, color: theme.hintColor),
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.close,
                                    size: 16,
                                    color: theme.colorScheme.error),
                                onPressed: () => _removeFromCart(i),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // ── Search field ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Cari bahan makanan...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: theme.dividerColor.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),

              // ── Category chips ──
              if (_categories.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final cat = _categories[i];
                      final selected = cat == _selectedCategory;
                      final isDark = theme.brightness == Brightness.dark;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? theme.primaryColor.withValues(
                                    alpha: isDark ? 0.9 : 1)
                                : theme.dividerColor.withValues(
                                    alpha: isDark ? 0.16 : 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? theme.primaryColor
                                  : theme.dividerColor.withValues(
                                      alpha: isDark ? 0.35 : 0.2),
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: theme.primaryColor.withValues(
                                          alpha: isDark ? 0.28 : 0.12),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: selected ? Colors.white : theme.hintColor,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 8),

              // ── Results list ──
              Expanded(
                child: _isSearching
                    ? Center(
                        child: CircularProgressIndicator(
                            color: theme.primaryColor))
                    : _results.isEmpty
                        ? Center(
                            child: Text('Tidak ditemukan',
                                style: TextStyle(color: theme.hintColor)))
                        : _filteredResults.isEmpty
                            ? Center(
                                child: Text(
                                  _selectedCategory == 'Semua'
                                      ? 'Tidak ditemukan'
                                      : 'Tidak ada makanan di kategori "$_selectedCategory"',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: theme.hintColor, fontSize: 13),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollCtrl,
                                padding: EdgeInsets.fromLTRB(
                                    16, 4, 16, cartCount > 0 ? 16 : 4),
                                itemCount: _filteredResults.length,
                                separatorBuilder: (_, __) => Divider(
                                    height: 1, color: theme.dividerColor),
                                itemBuilder: (_, i) {
                                  final food = _filteredResults[i];
                                  return ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            vertical: 4),
                                    title: Text(
                                      food.nama,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color:
                                            theme.textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${food.energi.toInt()} kkal  ·  P: ${food.protein}g  ·  Na: ${food.natrium.toInt()}mg',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: theme.hintColor),
                                    ),
                                    trailing: Icon(Icons.add_circle_outline,
                                        color: theme.primaryColor),
                                    onTap: () => _selectFood(food),
                                  );
                                },
                              ),
              ),

              // ── Cart submit bar (fixed bottom) ──
              if (cartCount > 0)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    border: Border(
                        top: BorderSide(
                            color: theme.dividerColor.withValues(alpha: 0.4))),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$cartCount makanan dipilih',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.hintColor,
                              ),
                            ),
                            Text(
                              '${cartTotalKkal.toStringAsFixed(0)} kkal total',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                setState(() => _isSubmitting = true);
                                Navigator.pop(context);
                                await widget.onAddAll(List.from(_cart));
                              },
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_alt_rounded, size: 18),
                        label: const Text('Simpan Semua'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
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

  Widget _row(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: theme.hintColor),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = double.tryParse(_gramCtrl.text) ?? 0;
    return AlertDialog(
      backgroundColor: theme.cardTheme.color,
      title: Text(
        'Edit ${widget.food.nama}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.food.satuanNama == 'Gelas' ? 'Jumlah (ml)' : 'Jumlah (gram)',
              style: TextStyle(fontSize: 13, color: theme.hintColor),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _gramCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                suffixText: widget.food.satuanNama == 'Gelas' ? 'ml' : 'g',
                filled: true,
                fillColor: theme.dividerColor.withValues(alpha: 0.05),
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
              Text(
                'Perkiraan Gizi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleSmall?.color,
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
  late int _takaranIdx;
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

  @override
  void initState() {
    super.initState();
    final takaranLength = widget.food.takaranSaji.length;
    _takaranIdx = takaranLength <= 1 ? 0 : 1;
  }

  double get _gramDimakan {
    final t = widget.food.takaranSaji[_takaranIdx];
    return t.gram * _count * (1 - _sisaPercent / 100);
  }

  Map<String, double> get _preview => widget.food.calcFor(_gramDimakan);

  Widget _sectionLabel(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: theme.textTheme.titleSmall?.color,
      ),
    );
  }

  Widget _previewRow(BuildContext context, String label, double value, String unit) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: theme.hintColor),
          ),
          Text(
            '${value.toStringAsFixed(1)} $unit',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final takaran = widget.food.takaranSaji;
    final gram = _gramDimakan;
    final preview = _preview;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Text(
            widget.food.nama,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          Text(
            'Berapa yang kamu makan?',
            style: TextStyle(fontSize: 13, color: theme.hintColor),
          ),
          const SizedBox(height: 18),

          // ── Pilih ukuran takaran ──
          _sectionLabel(context, 'Ukuran ${widget.food.satuanNama}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(takaran.length, (i) {
              final t = takaran[i];
              final sel = _takaranIdx == i;
              final emojiSize = 20.0 + (i.clamp(0, 4) * 3.0);
              return SizedBox(
                width: 96,
                child: GestureDetector(
                  onTap: () => setState(() => _takaranIdx = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: sel
                          ? theme.primaryColor.withValues(
                              alpha: isDark ? 0.28 : 0.12,
                            )
                          : theme.dividerColor.withValues(
                              alpha: isDark ? 0.14 : 0.05,
                            ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel
                            ? theme.primaryColor
                            : theme.dividerColor.withValues(
                                alpha: isDark ? 0.45 : 0.2,
                              ),
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
                                ? (isDark ? Colors.white : theme.primaryColor)
                                : theme.hintColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          widget.food.satuanNama == 'Gelas'
                              ? '${t.gram.toInt()} ml'
                              : '${t.gram.toInt()} g',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: sel
                                ? (isDark ? Colors.white : theme.primaryColor)
                                : theme.textTheme.bodyLarge?.color,
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

          // ── Jumlah takaran ──
          _sectionLabel(context, 'Jumlah ${widget.food.satuanNama}'),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _count > 1
                      ? theme.primaryColor
                      : theme.dividerColor.withValues(alpha: isDark ? 0.18 : 0.08),
                  border: Border.all(
                    color: _count > 1
                        ? theme.primaryColor
                        : theme.dividerColor.withValues(alpha: isDark ? 0.35 : 0.2),
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.remove, size: 24),
                  color: _count > 1
                      ? Colors.white
                      : theme.hintColor.withValues(alpha: isDark ? 0.7 : 0.45),
                  onPressed: _count > 1 ? () => setState(() => _count--) : null,
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '$_count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.primaryColor,
                  border: Border.all(
                    color: theme.primaryColor,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.add, size: 24),
                  color: Colors.white,
                  onPressed: () => setState(() => _count++),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Sisa di piring ──
          _sectionLabel(context, widget.food.satuanNama == 'Gelas' ? 'Sisa di Gelas' : 'Sisa di Piring'),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_sisaPercentages.length, (i) {
              final sisa = _sisaPercentages[i];
              final label = _sisaLabels[i];
              final sel = _sisaPercent == sisa;
              return GestureDetector(
                onTap: () => setState(() => _sisaPercent = sisa),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sel
                            ? theme.primaryColor.withValues(
                                alpha: isDark ? 0.28 : 0.12,
                              )
                            : theme.cardColor.withValues(
                                alpha: isDark ? 0.78 : 1,
                              ),
                        border: Border.all(
                          color: sel
                              ? theme.primaryColor
                              : theme.dividerColor.withValues(
                                  alpha: isDark ? 0.5 : 0.3,
                                ),
                          width: sel ? 2.5 : 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: CustomPaint(
                          painter: _PiePainter(
                            eatFraction: 1 - sisa / 100,
                            color: theme.primaryColor,
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.12),
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
                            ? (isDark ? Colors.white : theme.primaryColor)
                            : theme.hintColor,
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 18),

          // ── Ringkasan gizi ──
          if (gram > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.food.satuanNama == 'Gelas'
                        ? '${gram.toStringAsFixed(0)} ml diminum'
                        : '${gram.toStringAsFixed(0)} g dimakan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _previewRow(context, 'Energi', preview['energi']!, 'kkal'),
                  _previewRow(context, 'Protein', preview['protein']!, 'g'),
                  _previewRow(context, 'Lemak', preview['lemak']!, 'g'),
                  _previewRow(context, 'Karbohidrat', preview['karbohidrat']!, 'g'),
                  _previewRow(context, 'Natrium', preview['natrium']!, 'mg'),
                  _previewRow(context, 'Kalium', preview['kalium']!, 'mg'),
                  _previewRow(context, 'Fosfor', preview['fosfor']!, 'mg'),
                  _previewRow(context, 'Cairan', preview['air']!, 'ml'),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Makanan tidak dicatat (sisa 100%)',
                  style: TextStyle(
                    color: theme.hintColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),

          // ── Tombol ──
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
                      : const Text('Tambah ke Keranjang'),
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
  final Color backgroundColor;

  const _PiePainter({
    required this.eatFraction,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Latar: bagian yang tidak dimakan (abu-abu)
    canvas.drawCircle(center, radius, Paint()..color = backgroundColor);

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
  bool shouldRepaint(_PiePainter old) =>
      old.eatFraction != eatFraction ||
      old.color != color ||
      old.backgroundColor != backgroundColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// DM DAILY MEAL TABLE - Hierarchical table with per-meal breakdown
// ─────────────────────────────────────────────────────────────────────────────

class _DMDailyMealTable extends StatelessWidget {
  final Map<MealType, List<FoodLogEntry>> entriesByMeal;
  final NutritionNeeds needs;
  final Future<void> Function(FoodLogEntry) onEditEntry;
  final Future<void> Function(FoodLogEntry) onDeleteEntry;

  const _DMDailyMealTable({
    required this.entriesByMeal,
    required this.needs,
    required this.onEditEntry,
    required this.onDeleteEntry,
  });

  // DM meal distribution
  static const List<MealType> _dmMealOrder = [
    MealType.sarapan,
    MealType.selinganPagi,
    MealType.makanSiang,
    MealType.selinganSiang,
    MealType.makanMalam,
    MealType.selinganMalam,
  ];

  Map<String, double> _calculateMealTotals(List<FoodLogEntry> entries) {
    return {
      'energi': entries.fold(0.0, (sum, e) => sum + e.energi),
      'protein': entries.fold(0.0, (sum, e) => sum + e.protein),
      'lemak': entries.fold(0.0, (sum, e) => sum + e.lemak),
      'karbohidrat': entries.fold(0.0, (sum, e) => sum + e.karbohidrat),
      'serat': entries.fold(0.0, (sum, e) => sum + e.serat),
      'gl': entries.fold(0.0, (sum, e) => sum + e.glycemicLoad),
    };
  }

  Map<String, double> _calculateDailyTotals() {
    double totalEnergi = 0,
        totalProtein = 0,
        totalLemak = 0,
        totalCarb = 0,
        totalSerat = 0,
        totalGL = 0;
    for (final meal in entriesByMeal.values) {
      final totals = _calculateMealTotals(meal);
      totalEnergi += totals['energi']!;
      totalProtein += totals['protein']!;
      totalLemak += totals['lemak']!;
      totalCarb += totals['karbohidrat']!;
      totalSerat += totals['serat']!;
      totalGL += totals['gl']!;
    }
    return {
      'energi': totalEnergi,
      'protein': totalProtein,
      'lemak': totalLemak,
      'karbohidrat': totalCarb,
      'serat': totalSerat,
      'gl': totalGL,
    };
  }

  Color _getStatusColor(double percentage) {
    if (percentage <= 0) return Colors.blue; // Biru jika belum ada data
    if (percentage > 1.0) return AppColors.error; // Merah jika berlebih (>100%)
    if (percentage >= 0.8) return AppColors.success; // Hijau jika sudah >= 80%
    return AppColors.warning; // Kuning jika masih kurang (<80%)
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
            onEditEntry: onEditEntry,
            onDeleteEntry: onDeleteEntry,
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
  final Future<void> Function(FoodLogEntry) onEditEntry;
  final Future<void> Function(FoodLogEntry) onDeleteEntry;
  final Color Function(double) getStatusColor;
  final String Function(double) formatPercentage;
  final Map<String, double> Function(List<FoodLogEntry>) calculateMealTotals;

  const _MealTableSection({
    required this.mealType,
    required this.entries,
    required this.totalNeeds,
    required this.onEditEntry,
    required this.onDeleteEntry,
    required this.getStatusColor,
    required this.formatPercentage,
    required this.calculateMealTotals,
  });

  void _showEnlargedMealTable(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = mealType.dmCaloriePercentage;
    final targetEnergi = totalNeeds.energi * percentage;
    final targetProtein = totalNeeds.protein * percentage;
    final targetLemak = totalNeeds.lemak * percentage;
    final targetKarbo = totalNeeds.karbohidrat * percentage;
    final targetSerat = totalNeeds.serat * percentage;

    final totals = calculateMealTotals(entries);
    final actualEnergi = totals['energi']!;
    final actualProtein = totals['protein']!;
    final actualLemak = totals['lemak']!;
    final actualKarbo = totals['karbohidrat']!;
    final actualSerat = totals['serat']!;

    final energiRatio = targetEnergi > 0 ? actualEnergi / targetEnergi : 0.0;
    final statusColor = getStatusColor(energiRatio);

    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text('Rincian ${mealType.label}'),
            backgroundColor: theme.appBarTheme.backgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close, color: theme.appBarTheme.foregroundColor),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMealHeader(context, energiRatio, statusColor, isEnlarged: true),
                const SizedBox(height: 32),
                Text('Daftar Makanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.textTheme.titleLarge?.color)),
                const SizedBox(height: 12),
                _buildFoodTable(context, isEnlarged: true),
                const SizedBox(height: 32),
                Text('Ringkasan Gizi Harian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.textTheme.titleLarge?.color)),
                const SizedBox(height: 12),
                _buildTotalsTable(
                  context,
                  actualEnergi, actualProtein, actualLemak, actualKarbo, actualSerat,
                  targetEnergi, targetProtein, targetLemak, targetKarbo, targetSerat,
                  percentage, statusColor,
                  isEnlarged: true,
                  fulfillmentRatio: energiRatio,
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMealHeader(BuildContext context, double ratio, Color statusColor, {bool isEnlarged = false}) {
    final theme = Theme.of(context);
    if (isEnlarged) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(mealType.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mealType.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: theme.textTheme.titleMedium?.color,
                    ),
                  ),
                  Text(
                    '${(mealType.dmCaloriePercentage * 100).toStringAsFixed(0)}% dari kebutuhan harian',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
                Text(
                  '${(mealType.dmCaloriePercentage * 100).toStringAsFixed(0)}% dari kebutuhan harian',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodTable(BuildContext context, {bool isEnlarged = false}) {
    final theme = Theme.of(context);
    final colWidths = {
      0: FlexColumnWidth(isEnlarged ? 2.5 : 2),
      1: const FlexColumnWidth(1),
      2: const FlexColumnWidth(1),
      3: const FlexColumnWidth(1),
      4: const FlexColumnWidth(1),
      5: const FlexColumnWidth(1),
      6: const FlexColumnWidth(1),
      7: const FlexColumnWidth(0.9),
    };

    return Column(
      children: [
        Table(
          columnWidths: colWidths,
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              children: [
                _tableHeaderCell(context, 'Menu', isEnlarged: isEnlarged),
                _tableHeaderCell(context, 'Energi', isEnlarged: isEnlarged),
                _tableHeaderCell(context, 'Prot', isEnlarged: isEnlarged),
                _tableHeaderCell(context, 'Lemak', isEnlarged: isEnlarged),
                _tableHeaderCell(context, 'Karbo', isEnlarged: isEnlarged),
                _tableHeaderCell(context, 'Serat', isEnlarged: isEnlarged),
                _tableHeaderCell(context, 'Berat', isEnlarged: isEnlarged),
                _tableHeaderCell(context, 'Aksi', isEnlarged: isEnlarged),
              ],
            ),
          ],
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Belum ada makanan', style: TextStyle(fontSize: isEnlarged ? 14 : 12, color: theme.hintColor, fontStyle: FontStyle.italic)),
          )
        else
          Table(
            columnWidths: colWidths,
            children: [
              for (final entry in entries)
                TableRow(
                  children: [
                    _tableDataCell(context, entry.foodName, isBold: false, isEnlarged: isEnlarged),
                    _tableDataCell(context, entry.energi.toStringAsFixed(0), isEnlarged: isEnlarged),
                    _tableDataCell(context, entry.protein.toStringAsFixed(1), isEnlarged: isEnlarged),
                    _tableDataCell(context, entry.lemak.toStringAsFixed(1), isEnlarged: isEnlarged),
                    _tableDataCell(context, entry.karbohidrat.toStringAsFixed(1), isEnlarged: isEnlarged),
                    _tableDataCell(context, entry.serat.toStringAsFixed(1), isEnlarged: isEnlarged),
                    _tableDataCell(context, entry.grams.toStringAsFixed(0), isEnlarged: isEnlarged),
                    _tableActionCell(context, entry, isEnlarged: isEnlarged),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildTotalsTable(
    BuildContext context,
    double actualEnergi, double actualProtein, double actualLemak, double actualKarbo, double actualSerat,
    double targetEnergi, double targetProtein, double targetLemak, double targetKarbo, double targetSerat,
    double percentage, Color statusColor,
    {bool isEnlarged = false, double fulfillmentRatio = 0.0}
  ) {
    final theme = Theme.of(context);
    final pE = targetEnergi > 0 ? actualEnergi / targetEnergi : 0.0;
    final pP = targetProtein > 0 ? actualProtein / targetProtein : 0.0;
    final pL = targetLemak > 0 ? actualLemak / targetLemak : 0.0;
    final pK = targetKarbo > 0 ? actualKarbo / targetKarbo : 0.0;
    final pS = targetSerat > 0 ? actualSerat / targetSerat : 0.0;

    return Column(
      children: [
        Table(
          columnWidths: {
            0: FlexColumnWidth(isEnlarged ? 2.5 : 2),
            1: const FlexColumnWidth(1),
            2: const FlexColumnWidth(1),
            3: const FlexColumnWidth(1),
            4: const FlexColumnWidth(1),
            5: const FlexColumnWidth(1),
            6: const FlexColumnWidth(1),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: theme.dividerColor.withValues(alpha: 0.03)),
              children: [
                _tableDataCell(context, 'Total Asupan', isBold: true, isEnlarged: isEnlarged),
                _tableDataCell(context, actualEnergi.toStringAsFixed(0), isBold: true, isEnlarged: isEnlarged),
                _tableDataCell(context, actualProtein.toStringAsFixed(1), isBold: true, isEnlarged: isEnlarged),
                _tableDataCell(context, actualLemak.toStringAsFixed(1), isBold: true, isEnlarged: isEnlarged),
                _tableDataCell(context, actualKarbo.toStringAsFixed(1), isBold: true, isEnlarged: isEnlarged),
                _tableDataCell(context, actualSerat.toStringAsFixed(1), isBold: true, isEnlarged: isEnlarged),
                _tableDataCell(context, '', isBold: true, isEnlarged: isEnlarged),
              ],
            ),
            TableRow(
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.05)),
              children: [
                _tableDataCell(context, 'Total Kebutuhan', isBold: true, color: statusColor, isEnlarged: isEnlarged),
                _tableDataCell(context, targetEnergi.toStringAsFixed(0), isBold: true, color: statusColor, isEnlarged: isEnlarged),
                _tableDataCell(context, targetProtein.toStringAsFixed(1), isBold: true, color: statusColor, isEnlarged: isEnlarged),
                _tableDataCell(context, targetLemak.toStringAsFixed(1), isBold: true, color: statusColor, isEnlarged: isEnlarged),
                _tableDataCell(context, targetKarbo.toStringAsFixed(1), isBold: true, color: statusColor, isEnlarged: isEnlarged),
                _tableDataCell(context, targetSerat.toStringAsFixed(1), isBold: true, color: statusColor, isEnlarged: isEnlarged),
                _tableDataCell(context, '', isBold: true, isEnlarged: isEnlarged),
              ],
            ),
            TableRow(
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.05),
              ),
              children: [
                _tableDataCell(
                  context,
                  'Ketercapaian (%)',
                  isBold: true,
                  isEnlarged: isEnlarged,
                ),
                _tablePercentageCell(context, pE, isEnlarged: isEnlarged),
                _tablePercentageCell(context, pP, isEnlarged: isEnlarged),
                _tablePercentageCell(context, pL, isEnlarged: isEnlarged),
                _tablePercentageCell(context, pK, isEnlarged: isEnlarged),
                _tablePercentageCell(context, pS, isEnlarged: isEnlarged),
                _tableDataCell(context, '', isEnlarged: isEnlarged),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = mealType.dmCaloriePercentage;
    final targetEnergi = totalNeeds.energi * percentage;
    final targetProtein = totalNeeds.protein * percentage;
    final targetLemak = totalNeeds.lemak * percentage;
    final targetKarbo = totalNeeds.karbohidrat * percentage;
    final targetSerat = totalNeeds.serat * percentage;

    final totals = calculateMealTotals(entries);
    final actualEnergi = totals['energi']!;
    final actualProtein = totals['protein']!;
    final actualLemak = totals['lemak']!;
    final actualKarbo = totals['karbohidrat']!;
    final actualSerat = totals['serat']!;

    // Hitung rasio rata-rata ketercapaian gizi utama (E, P, L, K)
    final rE = targetEnergi > 0 ? actualEnergi / targetEnergi : 0.0;
    final rP = targetProtein > 0 ? actualProtein / targetProtein : 0.0;
    final rL = targetLemak > 0 ? actualLemak / targetLemak : 0.0;
    final rK = targetKarbo > 0 ? actualKarbo / targetKarbo : 0.0;
    
    // Rata-rata ketercapaian untuk status total waktu makan
    final totalFulfillmentRatio = (rE + rP + rL + rK) / 4.0;
    final statusColor = getStatusColor(totalFulfillmentRatio);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5), width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          childrenPadding: EdgeInsets.zero,
          collapsedBackgroundColor: statusColor.withValues(alpha: 0.1),
          backgroundColor: statusColor.withValues(alpha: 0.1),
          trailing: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.30),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    splashRadius: 16,
                    tooltip: 'Perbesar',
                    icon: Icon(
                      Icons.fullscreen,
                      size: 16,
                      color: statusColor,
                    ),
                    onPressed: () => _showEnlargedMealTable(context),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          title: _buildMealHeader(context, totalFulfillmentRatio, statusColor),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: _buildFoodTable(context),
            ),
            Divider(height: 1, color: theme.dividerColor),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: _buildTotalsTable(
                context,
                actualEnergi, actualProtein, actualLemak, actualKarbo, actualSerat,
                targetEnergi, targetProtein, targetLemak, targetKarbo, targetSerat,
                percentage, statusColor,
                fulfillmentRatio: totalFulfillmentRatio,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableActionCell(
    BuildContext context,
    FoodLogEntry entry, {
    bool isEnlarged = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Center(
        child: SizedBox(
          width: isEnlarged ? 24 : 20,
          height: isEnlarged ? 24 : 20,
          child: PopupMenuButton<String>(
          tooltip: 'Aksi',
          icon: Icon(
            Icons.more_vert,
            size: isEnlarged ? 16 : 14,
            color: theme.hintColor,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 140),
          onSelected: (value) {
            if (value == 'edit') onEditEntry(entry);
            if (value == 'delete') onDeleteEntry(entry);
          },
          itemBuilder: (context) => [
            const PopupMenuItem<String>(
              value: 'edit',
              child: Text('Edit'),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              child: Text(
                'Hapus',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _tableHeaderCell(BuildContext context, String text, {bool isEnlarged = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: isEnlarged ? 12 : 9,
          color: theme.hintColor,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _tableDataCell(BuildContext context, String text, {bool isBold = false, Color? color, bool isEnlarged = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isEnlarged ? 13 : 10,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color ?? theme.textTheme.bodyLarge?.color,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _tablePercentageCell(
    BuildContext context,
    double ratio, {
    bool isEnlarged = false,
  }) {
    final statusColor = getStatusColor(ratio);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isEnlarged ? 8 : 6,
            vertical: isEnlarged ? 6 : 4,
          ),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            formatPercentage(ratio),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isEnlarged ? 12 : 10,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DAILY INTERPRETATION TABLE
// ─────────────────────────────────────────────────────────────────────────────

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

  void _showEnlargedInterpretationTable(BuildContext context) {
    const mealOrder = [
      MealType.sarapan,
      MealType.selinganPagi,
      MealType.makanSiang,
      MealType.selinganSiang,
      MealType.makanMalam,
      MealType.selinganMalam,
    ];

    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Rincian Ketercapaian Harian'),
            backgroundColor: theme.appBarTheme.backgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close, color: theme.appBarTheme.foregroundColor),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ringkasan Makan Sehari', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.textTheme.titleLarge?.color)),
                const SizedBox(height: 12),
                _buildBaseTable(context, mealOrder, isPercentage: false),
                const SizedBox(height: 32),
                Text('Persentase Ketercapaian Gizi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.textTheme.titleLarge?.color)),
                const SizedBox(height: 12),
                _buildBaseTable(context, mealOrder, isPercentage: true),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBaseTable(BuildContext context, List<MealType> mealOrder, {required bool isPercentage}) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 600),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1.2),
            2: FlexColumnWidth(1.2),
            3: FlexColumnWidth(1.2),
            4: FlexColumnWidth(1.2),
            5: FlexColumnWidth(1.2),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              children: [
                _interpHeaderCell(context, 'Waktu Makan', isEnlarged: true),
                _interpHeaderCell(context, isPercentage ? '% Energi' : 'Energi', isEnlarged: true),
                _interpHeaderCell(context, isPercentage ? '% Prot' : 'Prot', isEnlarged: true),
                _interpHeaderCell(context, isPercentage ? '% Lemak' : 'Lemak', isEnlarged: true),
                _interpHeaderCell(context, isPercentage ? '% Karbo' : 'Karbo', isEnlarged: true),
                _interpHeaderCell(context, isPercentage ? '% Serat' : 'Serat', isEnlarged: true),
              ],
            ),
            for (final meal in mealOrder)
              isPercentage 
                ? _buildMealPercentageRow(context, meal, entriesByMeal[meal] ?? [], isEnlarged: true)
                : _buildMealInterpretationRow(context, meal, entriesByMeal[meal] ?? [], isEnlarged: true),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const mealOrder = [
      MealType.sarapan,
      MealType.selinganPagi,
      MealType.makanSiang,
      MealType.selinganSiang,
      MealType.makanMalam,
      MealType.selinganMalam,
    ];

    final theme = Theme.of(context);
    final actionIconColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.onSurface
        : theme.primaryColor;

    final dailyTotals = calculateDailyTotals();
    final pE = totalNeeds.energi > 0 ? dailyTotals['energi']! / totalNeeds.energi : 0.0;
    final pP = totalNeeds.protein > 0 ? dailyTotals['protein']! / totalNeeds.protein : 0.0;
    final pL = totalNeeds.lemak > 0 ? dailyTotals['lemak']! / totalNeeds.lemak : 0.0;
    final pK = totalNeeds.karbohidrat > 0 ? dailyTotals['karbohidrat']! / totalNeeds.karbohidrat : 0.0;
    final pS = totalNeeds.serat > 0 ? dailyTotals['serat']! / totalNeeds.serat : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        border: Border.all(color: theme.dividerColor, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meals interpretation header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ringkasan Makan Sehari',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 14,
                    color: theme.textTheme.titleSmall?.color,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.fullscreen, size: 20, color: actionIconColor),
                  onPressed: () => _showEnlargedInterpretationTable(context),
                ),
              ],
            ),
          ),

          // Meals interpretation rows
          Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 500),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2), // Waktu Makan
                    1: FlexColumnWidth(1.2), // Energi
                    2: FlexColumnWidth(1.2), // Protein
                    3: FlexColumnWidth(1.2), // Lemak
                    4: FlexColumnWidth(1.2), // Karbo
                    5: FlexColumnWidth(1.2), // Serat
                  },
                  children: [
                    // Header row
                    TableRow(
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      children: [
                        _interpHeaderCell(context, 'Waktu Makan'),
                        _interpHeaderCell(context, 'Energi'),
                        _interpHeaderCell(context, 'Prot'),
                        _interpHeaderCell(context, 'Lemak'),
                        _interpHeaderCell(context, 'Karbo'),
                        _interpHeaderCell(context, 'Serat'),
                      ],
                    ),

                    // Meal rows
                    for (final meal in mealOrder)
                      _buildMealInterpretationRow(
                        context,
                        meal,
                        entriesByMeal[meal] ?? [],
                      ),

                    // Summary row (Daily percentage)
                    TableRow(
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        border: Border(top: BorderSide(color: theme.dividerColor, width: 2)),
                      ),
                      children: [
                        _interpDataCell(context, 'Total Ketercapaian (%)', isBold: true),
                        _interpPercentageCell(context, pE),
                        _interpPercentageCell(context, pP),
                        _interpPercentageCell(context, pL),
                        _interpPercentageCell(context, pK),
                        _interpPercentageCell(context, pS),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildMealInterpretationRow(
    BuildContext context,
    MealType meal,
    List<FoodLogEntry> entries,
    {bool isEnlarged = false}
  ) {
    final percentage = meal.dmCaloriePercentage;
    final targetEnergi = totalNeeds.energi * percentage;
    final targetProt = totalNeeds.protein * percentage;
    final targetLemak = totalNeeds.lemak * percentage;
    final targetKarbo = totalNeeds.karbohidrat * percentage;
    final targetSerat = totalNeeds.serat * percentage;

    final actualEnergi = entries.fold(0.0, (sum, e) => sum + e.energi);
    final actualProt = entries.fold(0.0, (sum, e) => sum + e.protein);
    final actualLemak = entries.fold(0.0, (sum, e) => sum + e.lemak);
    final actualKarbo = entries.fold(0.0, (sum, e) => sum + e.karbohidrat);
    final actualSerat = entries.fold(0.0, (sum, e) => sum + e.serat);

    // Hitung rasio rata-rata ketercapaian gizi utama (E, P, L, K)
    final rE = targetEnergi > 0 ? actualEnergi / targetEnergi : 0.0;
    final rP = targetProt > 0 ? actualProt / targetProt : 0.0;
    final rL = targetLemak > 0 ? actualLemak / targetLemak : 0.0;
    final rK = targetKarbo > 0 ? actualKarbo / targetKarbo : 0.0;
    
    final totalRatio = (rE + rP + rL + rK) / 4.0;
    final statusColor = getStatusColor(totalRatio);

    return TableRow(
      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.05)),
      children: [
        _interpDataCell(context, '${meal.emoji} ${meal.label}', isEnlarged: isEnlarged),
        _interpDataCell(context, '${actualEnergi.toInt()} / ${targetEnergi.toInt()}', isEnlarged: isEnlarged),
        _interpDataCell(context, '${actualProt.toStringAsFixed(1)} / ${targetProt.toStringAsFixed(1)}', isEnlarged: isEnlarged),
        _interpDataCell(context, '${actualLemak.toStringAsFixed(1)} / ${targetLemak.toStringAsFixed(1)}', isEnlarged: isEnlarged),
        _interpDataCell(context, '${actualKarbo.toStringAsFixed(1)} / ${targetKarbo.toStringAsFixed(1)}', isEnlarged: isEnlarged),
        _interpDataCell(context, '${actualSerat.toStringAsFixed(1)} / ${targetSerat.toStringAsFixed(1)}', isEnlarged: isEnlarged),
      ],
    );
  }

  TableRow _buildMealPercentageRow(
    BuildContext context,
    MealType meal,
    List<FoodLogEntry> entries,
    {bool isEnlarged = false}
  ) {
    final percentage = meal.dmCaloriePercentage;
    final targetEnergi = totalNeeds.energi * percentage;
    final targetProt = totalNeeds.protein * percentage;
    final targetLemak = totalNeeds.lemak * percentage;
    final targetKarbo = totalNeeds.karbohidrat * percentage;
    final targetSerat = totalNeeds.serat * percentage;

    final actualEnergi = entries.fold(0.0, (sum, e) => sum + e.energi);
    final actualProt = entries.fold(0.0, (sum, e) => sum + e.protein);
    final actualLemak = entries.fold(0.0, (sum, e) => sum + e.lemak);
    final actualKarbo = entries.fold(0.0, (sum, e) => sum + e.karbohidrat);
    final actualSerat = entries.fold(0.0, (sum, e) => sum + e.serat);

    final pE = targetEnergi > 0 ? actualEnergi / targetEnergi : 0.0;
    final pP = targetProt > 0 ? actualProt / targetProt : 0.0;
    final pL = targetLemak > 0 ? actualLemak / targetLemak : 0.0;
    final pK = targetKarbo > 0 ? actualKarbo / targetKarbo : 0.0;
    final pS = targetSerat > 0 ? actualSerat / targetSerat : 0.0;

    final totalRatio = (pE + pP + pL + pK) / 4.0;
    final statusColor = getStatusColor(totalRatio);

    return TableRow(
      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.05)),
      children: [
        _interpDataCell(context, '${meal.emoji} ${meal.label}', isEnlarged: isEnlarged),
        _interpPercentageCell(context, pE, isEnlarged: isEnlarged),
        _interpPercentageCell(context, pP, isEnlarged: isEnlarged),
        _interpPercentageCell(context, pL, isEnlarged: isEnlarged),
        _interpPercentageCell(context, pK, isEnlarged: isEnlarged),
        _interpPercentageCell(context, pS, isEnlarged: isEnlarged),
      ],
    );
  }

  Widget _interpPercentageCell(BuildContext context, double ratio, {bool isEnlarged = false}) {
    final statusColor = getStatusColor(ratio);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isEnlarged ? 12 : 8, horizontal: 4),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          formatPercentage(ratio),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _interpHeaderCell(BuildContext context, String text, {bool isEnlarged = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isEnlarged ? 12 : 8, horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: isEnlarged ? 13 : 11,
          color: theme.hintColor,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _interpDataCell(BuildContext context, String text, {bool isBold = false, Color? color, bool isEnlarged = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isEnlarged ? 12 : 8, horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          fontSize: isEnlarged ? 13 : 11,
          color: color ?? theme.textTheme.bodyLarge?.color,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GLYCEMIC LOAD CHART WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _GlycemicLoadChart extends StatelessWidget {
  final List<FoodLogEntry> entries;

  const _GlycemicLoadChart({super.key, required this.entries});

  static const List<MealType> _dmMealOrder = [
    MealType.sarapan,
    MealType.selinganPagi,
    MealType.makanSiang,
    MealType.selinganSiang,
    MealType.makanMalam,
    MealType.selinganMalam,
  ];

  Map<MealType, double> _calculateMealGL() {
    final mealGL = <MealType, double>{};
    for (final meal in _dmMealOrder) {
      final mealEntries = entries.where((e) => e.mealType == meal);
      mealGL[meal] = mealEntries.fold(0.0, (sum, e) => sum + e.glycemicLoad);
    }
    return mealGL;
  }

  Color _getGLColor(double gl) {
    if (gl < 11) return const Color(0xFF4CAF50); // Rendah: < 11 (mencakup < 10)
    if (gl < 20) return const Color(0xFFFFC107); // Sedang: 11 - 19
    return const Color(0xFFF44336); // Tinggi: >= 20
  }

  String _getGLStatus(double gl) {
    if (gl < 11) return 'Rendah';
    if (gl < 20) return 'Sedang';
    return 'Tinggi';
  }

  void _showEnlargedChart(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Grafik Glycemic Load'),
            backgroundColor: theme.appBarTheme.backgroundColor,
            leading: IconButton(
              icon: Icon(Icons.close, color: theme.appBarTheme.foregroundColor),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                SizedBox(
                  height: 500, // Ukuran jauh lebih besar untuk lansia
                  child: _buildChart(context, isEnlarged: true),
                ),
                const SizedBox(height: 40),
                _buildLegend(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LegendItem(label: 'Rendah (<10)', color: Color(0xFF4CAF50)),
          SizedBox(width: 8),
          _LegendItem(label: 'Sedang (11-19)', color: Color(0xFFFFC107)),
          SizedBox(width: 8),
          _LegendItem(label: 'Tinggi (>20)', color: Color(0xFFF44336)),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, {bool isEnlarged = false}) {
    final theme = Theme.of(context);
    final mealGL = _calculateMealGL();
    double maxGL = -1;
    for (final meal in mealGL.keys) {
      if (mealGL[meal]! > maxGL) {
        maxGL = mealGL[meal]!;
      }
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxGL < 25) ? 25 : (maxGL * 1.2),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final gl = rod.toY;
              final percentage = (gl / 20.0 * 100).toStringAsFixed(0);
              return BarTooltipItem(
                '${_dmMealOrder[group.x].label}\n',
                TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isEnlarged ? 16 : 14,
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: '${gl.toStringAsFixed(1)} ($percentage%)',
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _dmMealOrder.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _dmMealOrder[index].label.replaceAll(' ', '\n'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isEnlarged ? 11 : 9,
                      color: theme.hintColor,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontSize: isEnlarged ? 11 : 9,
                    color: theme.hintColor,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.dividerColor.withValues(alpha: 0.1),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(_dmMealOrder.length, (i) {
          final gl = mealGL[_dmMealOrder[i]] ?? 0;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: gl,
                color: _getGLColor(gl),
                width: isEnlarged ? 30 : 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: (maxGL < 25) ? 25 : (maxGL * 1.2),
                  color: theme.dividerColor.withValues(alpha: 0.05),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionIconColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.onSurface
        : theme.primaryColor;
    final mealGL = _calculateMealGL();
    final totalGL = mealGL.values.fold(0.0, (sum, gl) => sum + gl);
    final totalPercentage = (totalGL / 120.0 * 100).toStringAsFixed(0);

    // Find peak GL
    MealType? peakMeal;
    double maxGL = -1;
    for (final meal in mealGL.keys) {
      if (mealGL[meal]! > maxGL) {
        maxGL = mealGL[meal]!;
        peakMeal = meal;
      }
    }

    final peakInfo = (peakMeal != null && maxGL > 0)
        ? 'Puncak: ${peakMeal.label} (${maxGL.toStringAsFixed(1)} - ${_getGLStatus(maxGL)})'
        : 'Puncak: -';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: theme.brightness == Brightness.dark 
            ? Border.all(color: theme.dividerColor)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.show_chart,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Grafik Glycemic Load (Estimasi)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.fullscreen, color: actionIconColor),
                onPressed: () => _showEnlargedChart(context),
                tooltip: 'Perbesar Grafik',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Total GL hari ini: ${totalGL.toStringAsFixed(1)} ($totalPercentage%) • $peakInfo',
            style: TextStyle(
              fontSize: 11,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 20),
          
          // Chart
          SizedBox(
            height: 200,
            child: _buildChart(context),
          ),
          
          const SizedBox(height: 20),
          
          // Legend
          _buildLegend(),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendItem({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
