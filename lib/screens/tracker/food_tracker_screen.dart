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
import '../../models/food_modifier.dart';
import '../../services/food_modifier_service.dart';

class _NumberStepper extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String suffixText;
  final VoidCallback onChanged;

  const _NumberStepper({
    required this.controller,
    required this.labelText,
    required this.suffixText,
    required this.onChanged,
  });

  void _step(double delta) {
    final current = double.tryParse(controller.text) ?? 0.0;
    var next = current + delta;
    if (next < 0) next = 0;
    // Format to remove trailing .0
    controller.text = next.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _step(-0.5),
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
            child: Container(
              width: 32,
              alignment: Alignment.center,
              child: const Icon(Icons.remove, size: 16, color: AppColors.textSecondary),
            ),
          ),
          Container(width: 1, color: AppColors.border),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                hintText: '0',
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          if (suffixText.isNotEmpty) ...[
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                suffixText,
                style: TextStyle(fontSize: 11, color: theme.hintColor),
              ),
            ),
          ],
          Container(width: 1, color: AppColors.border),
          InkWell(
            onTap: () => _step(0.5),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
            child: Container(
              width: 32,
              alignment: Alignment.center,
              child: const Icon(Icons.add, size: 16, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

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
        serat = 0,
        kalsium = 0,
        magnesium = 0;
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
      kalsium += entry.kalsium;
      magnesium += entry.magnesium;
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
      kalsium: kalsium,
      magnesium: magnesium,
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

  Future<void> _loadEntriesInternal({
    required bool showFullScreenLoading,
  }) async {
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      locale: const Locale('id', 'ID'),
    );
    if (!mounted || picked == null) return;
    setState(
      () => _selectedDate = DateTime(picked.year, picked.month, picked.day),
    );
    _loadEntriesInternal(showFullScreenLoading: false);
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

  Future<void> _editEntryTime(FoodLogEntry entry) async {
    final uid =
        context.read<AuthProvider>().currentUser?.uid ??
        context.read<AuthProvider>().firebaseUser?.uid ??
        '';
    if (uid.isEmpty) return;

    final initialTime = TimeOfDay(
      hour: entry.loggedAt.hour,
      minute: entry.loggedAt.minute,
    );

    if (!mounted) return;
    final picked = await showDialog<TimeOfDay>(
      context: context,
      builder: (ctx) =>
          _EatTimeDialog(mealType: entry.mealType, initialTime: initialTime),
    );
    if (picked == null || !mounted) return;

    final oldDate = entry.loggedAt;
    final newLoggedAt = DateTime(
      oldDate.year,
      oldDate.month,
      oldDate.day,
      picked.hour,
      picked.minute,
    );
    final updated = FoodLogEntry(
      id: entry.id,
      foodId: entry.foodId,
      foodName: entry.foodName,
      grams: entry.grams,
      loggedAt: newLoggedAt,
      mealType: entry.mealType,
      energi: entry.energi,
      protein: entry.protein,
      lemak: entry.lemak,
      karbohidrat: entry.karbohidrat,
      natrium: entry.natrium,
      kalium: entry.kalium,
      fosfor: entry.fosfor,
      air: entry.air,
      serat: entry.serat,
      indeksGlikemik: entry.indeksGlikemik,
    );
    await FoodLogService.updateEntry(uid, _selectedDate, updated);
    if (mounted) _loadEntries();
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
            ),
            ...MealType.values.map(
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
                      Text(meal.emoji, style: const TextStyle(fontSize: 28)),
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
                      Icon(Icons.chevron_right, color: theme.primaryColor),
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
        onAddAll: (cartItems, eatTime) async {
          if (cartItems.isEmpty) return;
          final mealType = _selectedMealType!;
          final base = _selectedDate;
          final loggedAt = DateTime(
            base.year,
            base.month,
            base.day,
            eatTime.hour,
            eatTime.minute,
          );
          final entries = cartItems
              .map(
                (item) => FoodLogEntry.create(
                  food: item.food,
                  grams: item.grams,
                  mealType: mealType,
                  loggedAt: loggedAt,
                  cookingMethod: item.cookingMethod,
                  selectedAdditives: item.additives,
                ),
              )
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
        // Karbohidrat Chart
        _buildHFNutritionChart(
          title: 'Karbohidrat',
          unit: 'g',
          weeklyData: weeklyData,
          lineColor: Colors.green.shade600,
          getActual: (data) => data.karbohidrat,
          getTarget: (data) => data.targetKarbohidrat,
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
            onPickDate: _pickDate,
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
                                DiseaseType.chronicKidneyDisease) ...[
                              _WeeklyFluidChart(
                                target: needs.cairan,
                                uid: _uid,
                                needs: needs,
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
                                key: ValueKey(
                                  'gl_chart_${_selectedDate.millisecondsSinceEpoch}_${_entries.length}',
                                ),
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
                            // 4. Hypertension: Show dedicated natrium-highlight summary
                            else if (auth.currentUser?.diseaseType ==
                                DiseaseType.hypertension) ...[
                              _HypertensionSummaryCard(
                                needs: needs,
                                intake: intake,
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
                              onEditTime: _editEntryTime,
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
  final VoidCallback onPickDate;

  const _DateHeader({
    required this.date,
    required this.isToday,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = isToday
        ? 'Hari Ini · ${DateFormat('d MMMM y', 'id_ID').format(date)}'
        : DateFormat('EEEE, d MMMM y', 'id_ID').format(date);

    return Container(
      color: theme.cardTheme.color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _navCircleButton(
            context: context,
            onTap: onPrev,
            icon: Icons.chevron_left,
            fillColor: const Color(0xFF64B5F6).withValues(alpha: 0.52),
          ),
          Expanded(
            child: InkWell(
              onTap: onPickDate,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: theme.hintColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
          _navCircleButton(
            context: context,
            onTap: canGoNext ? onNext : null,
            icon: Icons.chevron_right,
            fillColor: canGoNext
                ? const Color(0xFF64B5F6).withValues(alpha: 0.52)
                : const Color(0xFFE5EAF1),
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
        child: Icon(icon, color: iconColor ?? Colors.white, size: 18),
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
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: theme.primaryColor,
            ),
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
    final themeColor = _isDM
        ? (ext?.diabetesColor ?? Colors.orange)
        : (ext?.kidneyColor ?? Colors.red);

    // Nutrisi dasar (semua penyakit)
    final nutrients = [
      if (!_isHF)
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
      if (!_isHF)
        _NutrientData(
          'Lemak',
          intake.lemak,
          needs.lemak,
          'g',
          Icons.water_drop_outlined,
        ),
      if (!_isHF)
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
        if (!_isHF)
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
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05,
            ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// WEEKLY FLUID CHART (Bar diagram for past 7 days)
// ─────────────────────────────────────────────────────────────────────────────

class _WeeklyFluidChart extends StatefulWidget {
  final double target;
  final String uid;
  final NutritionNeeds needs;

  const _WeeklyFluidChart({
    required this.target,
    required this.uid,
    required this.needs,
  });

  @override
  State<_WeeklyFluidChart> createState() => _WeeklyFluidChartState();
}

class _WeeklyFluidChartState extends State<_WeeklyFluidChart> {
  // 0 = minggu ini, -1 = minggu lalu, dst.
  int _weekOffset = 0;
  List<DailyNutrition>? _data;
  bool _loading = false;

  // ── Tanggal akhir dari minggu yang sedang ditampilkan ──
  DateTime get _endDate {
    final today = DateTime.now();
    return DateTime(
      today.year,
      today.month,
      today.day,
    ).add(Duration(days: _weekOffset * 7));
  }

  DateTime get _startDate => _endDate.subtract(const Duration(days: 6));

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await NutritionHistoryService.getWeeklyNutrition(
        uid: widget.uid,
        endDate: _endDate,
        targets: widget.needs,
      );
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted) setState(() => _data = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigate(int delta) {
    // Tidak boleh ke depan melebihi minggu ini
    if (_weekOffset + delta > 0) return;
    setState(() {
      _weekOffset += delta;
      _data = null;
    });
    _fetchData();
  }

  String _formatDate(DateTime d) {
    const bulan = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${d.day} ${bulan[d.month]} ${d.year}';
  }

  String get _periodLabel {
    final start = _formatDate(_startDate);
    final end = _formatDate(_endDate);
    if (_weekOffset == 0) return 'Minggu ini  ·  $start – $end';
    if (_weekOffset == -1) return 'Minggu lalu  ·  $start – $end';
    return 'Periode  $start – $end';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weeklyData = _data;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header: judul + navigasi ──
        Row(
          children: [
            Expanded(
              child: Column(
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
                  const SizedBox(height: 2),
                  Text(
                    _periodLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.hintColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            // Tombol navigasi ←  →
            Row(
              children: [
                _NavButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => _navigate(-1),
                  enabled: true,
                ),
                const SizedBox(width: 4),
                _NavButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: () => _navigate(1),
                  enabled: _weekOffset < 0,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Grafik / Loading ──
        if (_loading || weeklyData == null)
          SizedBox(
            height: 130,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.primaryColor,
              ),
            ),
          )
        else if (weeklyData.isEmpty)
          SizedBox(
            height: 100,
            child: Center(
              child: Text(
                'Tidak ada data',
                style: TextStyle(color: theme.hintColor, fontSize: 12),
              ),
            ),
          )
        else
          _buildBars(context, weeklyData),

        const SizedBox(height: 8),
        // ── Legend ──
        Row(
          children: [
            _LegendDot(color: AppColors.success, label: 'Normal (90–110%)'),
            const SizedBox(width: 10),
            _LegendDot(color: AppColors.warning, label: 'Kurang'),
            const SizedBox(width: 10),
            _LegendDot(color: AppColors.error, label: 'Berlebih'),
          ],
        ),
      ],
    );
  }

  Widget _buildBars(BuildContext context, List<DailyNutrition> data) {
    final theme = Theme.of(context);
    final target = widget.target;
    final maxValue =
        data
            .map((d) => d.cairan)
            .fold(target, (prev, v) => v > prev ? v : prev) *
        1.1;

    const dayLabels = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
    const bulan = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final today = DateTime.now();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((day) {
        final ratio = maxValue > 0 ? day.cairan / maxValue : 0.0;
        final isToday =
            day.date.year == today.year &&
            day.date.month == today.month &&
            day.date.day == today.day;
        final targetRatio = target > 0 ? day.cairan / target : 0.0;
        final color = targetRatio >= 1.1
            ? AppColors.error
            : targetRatio >= 0.9
            ? AppColors.success
            : AppColors.warning;

        final dayLabel = dayLabels[day.date.weekday % 7];
        final dateLabel = '${day.date.day} ${bulan[day.date.month]}';

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              children: [
                // Bar
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
                    height: ((ratio * 80).clamp(0, 80)).toDouble(),
                    decoration: BoxDecoration(
                      color: day.cairan == 0
                          ? theme.dividerColor.withValues(alpha: 0.2)
                          : color,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // ml label
                Text(
                  day.cairan == 0 ? '–' : '${day.cairan.toInt()}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isToday
                        ? theme.primaryColor
                        : theme.textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 1),
                // Nama hari
                Text(
                  dayLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                    color: isToday ? theme.primaryColor : theme.hintColor,
                  ),
                ),
                // Tanggal
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 9,
                    color: isToday
                        ? theme.primaryColor.withValues(alpha: 0.85)
                        : theme.hintColor.withValues(alpha: 0.65),
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
    );
  }
}

/// Tombol navigasi panah (dipakai di header chart)
class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _NavButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled
              ? theme.primaryColor.withValues(alpha: isDark ? 0.28 : 0.12)
              : theme.dividerColor.withValues(alpha: isDark ? 0.16 : 0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled
                ? theme.primaryColor.withValues(alpha: isDark ? 0.7 : 0.4)
                : theme.dividerColor.withValues(alpha: isDark ? 0.35 : 0.2),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          // Dark mode: putih agar kontras, light mode: ikut primaryColor/hintColor
          color: enabled
              ? (isDark ? Colors.white : theme.primaryColor)
              : theme.hintColor.withValues(alpha: isDark ? 0.5 : 0.4),
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: Theme.of(context).hintColor),
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
    final valueText = diseaseType == DiseaseType.chronicKidneyDisease
        ? '${(data.ratio * 100).round()}%'
        : '${_fmt(data.intake)} / ${_fmt(data.target)} ${data.unit}';
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
              valueText,
              style: TextStyle(fontSize: 11, color: theme.hintColor),
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
              Icon(Icons.opacity_outlined, color: kidneyColor, size: 20),
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
                      backgroundColor: theme.dividerColor.withValues(
                        alpha: 0.05,
                      ),
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
                        style: TextStyle(fontSize: 12, color: theme.hintColor),
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
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.2),
              ),
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
                Container(
                  width: 1,
                  height: 40,
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
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
        Text(label, style: TextStyle(fontSize: 11, color: theme.hintColor)),
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
            style: TextStyle(color: theme.hintColor, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HYPERTENSION SUMMARY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _HypertensionSummaryCard extends StatelessWidget {
  final NutritionNeeds needs;
  final NutritionIntake intake;

  const _HypertensionSummaryCard({
    required this.needs,
    required this.intake,
  });

  static const Color _htColor = Color(0xFF00897B); // teal-700

  /// Traffic light for hypertension nutrients.
  /// wideRange (Kalium, Serat, Kalsium, Magnesium, Protein): 80-110% hijau
  /// others (Energi, Lemak, Karbohidrat, Natrium): 80-110% hijau, 60-79% kuning
  Color _getHtStatusColor(String nutrient, double percentage) {
    const wideRange = {'kalium', 'serat', 'kalsium', 'magnesium', 'protein'};
    if (wideRange.contains(nutrient)) {
      if (percentage >= 0.80 && percentage <= 1.10) return AppColors.success;
      if (percentage > 1.10 && percentage <= 1.20) return AppColors.warning;
      return AppColors.error;
    } else {
      if (percentage >= 0.80 && percentage <= 1.10) return AppColors.success;
      if (percentage >= 0.60 && percentage < 0.80) return AppColors.warning;
      return AppColors.error;
    }
  }

  double _pct(double actual, double target) =>
      target > 0 ? actual / target : 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Natrium highlight values
    final naActual = intake.natrium;
    final naTarget = needs.natrium;
    final naPct = _pct(naActual, naTarget);
    final naColor = _getHtStatusColor('natrium', naPct);

    // Nutrient rows data: [key, label, actual, target, unit]
    final rows = [
      ('energi', 'Energi', intake.energi, needs.energi, 'kkal'),
      ('protein', 'Protein', intake.protein, needs.protein, 'g'),
      ('lemak', 'Lemak', intake.lemak, needs.lemak, 'g'),
      ('karbohidrat', 'Karbohidrat', intake.karbohidrat, needs.karbohidrat, 'g'),
      ('natrium', 'Natrium', intake.natrium, needs.natrium, 'mg'),
      ('kalium', 'Kalium', intake.kalium, needs.kalium, 'mg'),
      ('serat', 'Serat', intake.serat, needs.serat, 'g'),
      ('kalsium', 'Kalsium', intake.kalsium, needs.kalsium, 'mg'),
      ('magnesium', 'Magnesium', intake.magnesium, needs.magnesium, 'mg'),
    ];

    String fmtVal(double v) {
      if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
      if (v == v.roundToDouble()) return v.toInt().toString();
      return v.toStringAsFixed(1);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Natrium highlight card ──
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _htColor.withValues(alpha: 0.15),
                _htColor.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _htColor.withValues(alpha: 0.25)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _htColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.water_drop_outlined,
                      color: _htColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Batas Natrium Harian',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: naColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(naPct * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: naColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    fmtVal(naActual),
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: naColor,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 16),
                    child: Text(
                      'mg',
                      style: TextStyle(
                          fontSize: 14, color: theme.hintColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'dari ${fmtVal(naTarget)} mg target',
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: naPct.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor:
                      theme.dividerColor.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(naColor),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatItem(
                    icon: Icons.check_circle_outline,
                    label: 'Dikonsumsi',
                    value: '${fmtVal(naActual)} mg',
                    color: AppColors.success,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: theme.dividerColor.withValues(alpha: 0.3),
                  ),
                  _StatItem(
                    icon: naActual > naTarget
                        ? Icons.warning_outlined
                        : Icons.hourglass_bottom_outlined,
                    label: naActual > naTarget ? 'Berlebih' : 'Sisa',
                    value: naActual > naTarget
                        ? '${fmtVal(naActual - naTarget)} mg'
                        : '${fmtVal(naTarget - naActual)} mg',
                    color: naActual > naTarget
                        ? AppColors.error
                        : AppColors.warning,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ── Nutrient rows card ──
        Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: theme.brightness == Brightness.dark
                ? Border.all(color: theme.dividerColor)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05,
                ),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _htColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        color: _htColor,
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
                  ],
                ),
              ),
              Divider(height: 1, color: theme.dividerColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: rows.map((r) {
                    final key = r.$1;
                    final label = r.$2;
                    final actual = r.$3;
                    final target = r.$4;
                    final unit = r.$5;
                    final pct = _pct(actual, target);
                    final color = _getHtStatusColor(key, pct);
                    final exceeded = key == 'kalium' ||
                            key == 'serat' ||
                            key == 'kalsium' ||
                            key == 'magnesium' ||
                            key == 'protein'
                        ? pct > 1.20
                        : pct > 1.10;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              const Spacer(),
                              if (exceeded)
                                Container(
                                  margin:
                                      const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.error
                                        .withValues(alpha: 0.12),
                                    borderRadius:
                                        BorderRadius.circular(6),
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
                                '${fmtVal(actual)} / ${fmtVal(target)} $unit',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: theme.hintColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct.clamp(0.0, 1.0),
                              minHeight: 7,
                              backgroundColor: theme.dividerColor
                                  .withValues(alpha: 0.1),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
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
  final Future<void> Function(FoodLogEntry) onEditTime;

  const _FoodListSection({
    required this.entries,
    required this.onDelete,
    required this.onEdit,
    required this.onEditTime,
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
            return _MealSection(
              mealType: meal,
              entries: mealEntries,
              onDelete: onDelete,
              onEdit: onEdit,
              onEditTime: onEditTime,
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
            style: TextStyle(
              fontSize: 12,
              color: theme.hintColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// Section for each meal type — accordion (collapsed by default), matching DM style
class _MealSection extends StatelessWidget {
  final MealType mealType;
  final List<FoodLogEntry> entries;
  final Future<void> Function(FoodLogEntry) onDelete;
  final Future<void> Function(FoodLogEntry) onEdit;
  final Future<void> Function(FoodLogEntry) onEditTime;

  const _MealSection({
    required this.mealType,
    required this.entries,
    required this.onDelete,
    required this.onEdit,
    required this.onEditTime,
  });

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
    final kkal = subtotals['energi']!;

    // Status color: merah jika tidak ada makanan, hijau jika ada
    // (konsisten dgn DM — karena non-DM tidak punya target per-meal)
    final Color statusColor = entries.isEmpty
        ? theme.hintColor.withValues(alpha: 0.5)
        : AppColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.5),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.15 : 0.04,
            ),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Theme(
        // Hilangkan garis divider bawaan ExpansionTile
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          // Background header sesuai status (mirip DM)
          collapsedBackgroundColor: entries.isEmpty
              ? Colors.transparent
              : statusColor.withValues(alpha: 0.07),
          backgroundColor: entries.isEmpty
              ? Colors.transparent
              : statusColor.withValues(alpha: 0.07),
          // ── Custom trailing: badge jumlah + ikon expand ──
          trailing: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge jumlah item
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '${entries.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: entries.isEmpty ? theme.hintColor : statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Ikon dropdown
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: entries.isEmpty ? theme.hintColor : statusColor,
                  ),
                ),
              ],
            ),
          ),
          // ── Header (title) ──
          title: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
            child: Row(
              children: [
                Text(mealType.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mealType.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      Text(
                        entries.isEmpty
                            ? mealType.timeRange
                            : '${mealType.timeRange}  ·  ${kkal.toStringAsFixed(0)} kkal',
                        style: TextStyle(fontSize: 11, color: theme.hintColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Expanded content ──
          children: [
            Divider(height: 1, color: theme.dividerColor),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
                child: Text(
                  'Belum ada makanan untuk ${mealType.label}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.hintColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Column(
                  children: entries
                      .map(
                        (e) => _FoodEntryCard(
                          entry: e,
                          onDelete: () => onDelete(e),
                          onEdit: () => onEdit(e),
                          onEditTime: () => onEditTime(e),
                        ),
                      )
                      .toList(),
                ),
              ),
              // Subtotal row
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Subtotal: ${kkal.toStringAsFixed(0)} kkal',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.hintColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Na: ${subtotals['natrium']!.toStringAsFixed(0)}  P: ${subtotals['protein']!.toStringAsFixed(1)} g',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.hintColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FoodEntryCard extends StatelessWidget {
  final FoodLogEntry entry;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onEditTime;

  const _FoodEntryCard({
    required this.entry,
    required this.onDelete,
    required this.onEdit,
    required this.onEditTime,
  });

  String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: theme.brightness == Brightness.dark
            ? Border.all(color: theme.dividerColor)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.2 : 0.04,
            ),
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
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${entry.grams.toInt()} g  ·  ${entry.energi.toStringAsFixed(0)} kkal',
              style: TextStyle(fontSize: 12, color: theme.hintColor),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule_rounded, size: 11, color: theme.hintColor),
                const SizedBox(width: 3),
                Text(
                  _fmtTime(entry.loggedAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.hintColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 20, color: theme.hintColor),
          onSelected: (val) {
            if (val == 'edit') onEdit();
            if (val == 'edit_time') onEditTime();
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
              value: 'edit_time',
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 18,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(width: 10),
                  const Text('Edit Jam'),
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
                  Text(
                    'Hapus',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ),
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
  final CookingMethod? cookingMethod;
  final List<SelectedAdditive> additives;
  _CartItem({
    required this.food,
    required this.grams,
    this.cookingMethod,
    this.additives = const [],
  });
}

class _AddFoodSheet extends StatefulWidget {
  final MealType mealType;
  final bool isGuest;
  final Future<void> Function(List<_CartItem> cartItems, TimeOfDay eatTime)
  onAddAll;
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

  void _addToCart(FoodItem food, double grams, {CookingMethod? cookingMethod, List<SelectedAdditive> additives = const []}) {
    setState(() => _cart.add(_CartItem(
      food: food,
      grams: grams,
      cookingMethod: cookingMethod,
      additives: additives,
    )));
    _showCartSuccessOverlay(food.nama, food.emoji);
  }

  /// Tampilkan overlay animasi "Berhasil ditambahkan ke keranjang"
  /// menggunakan OverlayEntry + AnimationController agar modal muncul
  /// tepat di atas konten sheet dan auto-dismiss tanpa interaksi user.
  void _showCartSuccessOverlay(String foodName, String emoji) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    late AnimationController ctrl;

    ctrl = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 280),
    );

    entry = OverlayEntry(
      builder: (_) => _CartSuccessOverlay(
        foodName: foodName,
        emoji: emoji,
        controller: ctrl,
      ),
    );

    overlay.insert(entry);
    ctrl.forward();

    Future.delayed(const Duration(milliseconds: 1400), () async {
      await ctrl.reverse();
      entry.remove();
      ctrl.dispose();
    });
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
    showDialog(
      context: context,
      builder: (ctx) => _FoodModifierDialog(
        food: food,
        isGuest: widget.isGuest,
        onSave: (grams, cookingMethod, additives) {
          Navigator.pop(ctx); // tutup dialog
          if (widget.isGuest) {
            _showGuestLoginDialog();
            return;
          }
          _addToCart(food, grams, cookingMethod: cookingMethod, additives: additives);
        },
      ),
    );
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
        return Material(
          color: theme.cardTheme.color ?? theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
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
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            // Dark mode: fill lebih solid agar badge terlihat
                            color: theme.brightness == Brightness.dark
                                ? theme.primaryColor.withValues(alpha: 0.28)
                                : theme.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.brightness == Brightness.dark
                                  ? theme.primaryColor.withValues(alpha: 0.7)
                                  : theme.primaryColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isCartExpanded
                                    ? Icons.shopping_cart
                                    : Icons.shopping_cart_outlined,
                                size: 16,
                                // Dark mode: putih agar kontras di atas fill gelap
                                color: theme.brightness == Brightness.dark
                                    ? Colors.white
                                    : theme.primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$cartCount item',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.white
                                      : theme.primaryColor,
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
                      color: theme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.shopping_cart,
                              size: 14,
                              color: theme.primaryColor,
                            ),
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
                        color: theme.primaryColor.withValues(alpha: 0.15),
                      ),
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
                                horizontal: 12,
                                vertical: 0,
                              ),
                              title: Text(
                                item.food.nama,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${item.grams.toInt()} g  ·  $kkal kkal',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.hintColor,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: theme.colorScheme.error,
                                ),
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
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? theme.primaryColor.withValues(
                                    alpha: isDark ? 0.9 : 1,
                                  )
                                : theme.dividerColor.withValues(
                                    alpha: isDark ? 0.16 : 0.1,
                                  ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? theme.primaryColor
                                  : theme.dividerColor.withValues(
                                      alpha: isDark ? 0.35 : 0.2,
                                    ),
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: theme.primaryColor.withValues(
                                        alpha: isDark ? 0.28 : 0.12,
                                      ),
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
                          color: theme.primaryColor,
                        ),
                      )
                    : _results.isEmpty
                    ? Center(
                        child: Text(
                          'Tidak ditemukan',
                          style: TextStyle(color: theme.hintColor),
                        ),
                      )
                    : _filteredResults.isEmpty
                    ? Center(
                        child: Text(
                          _selectedCategory == 'Semua'
                              ? 'Tidak ditemukan'
                              : 'Tidak ada makanan di kategori "$_selectedCategory"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.hintColor,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          4,
                          16,
                          cartCount > 0 ? 16 : 4,
                        ),
                        itemCount: _filteredResults.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: theme.dividerColor),
                        itemBuilder: (_, i) {
                          final food = _filteredResults[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 4,
                            ),
                            title: Text(
                              food.nama,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            subtitle: Text(
                              '${food.energi.toInt()} kkal  ·  P: ${food.protein}g  ·  Na: ${food.natrium.toInt()}mg',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.hintColor,
                              ),
                            ),
                            trailing: Icon(
                              Icons.add_circle_outline,
                              color: theme.primaryColor,
                            ),
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
                        color: theme.dividerColor.withValues(alpha: 0.4),
                      ),
                    ),
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
                                // Parse default jam dari timeRange mealType
                                final rangeParts = widget.mealType.timeRange
                                    .split(' - ');
                                TimeOfDay defaultTime = TimeOfDay.now();
                                if (rangeParts.isNotEmpty) {
                                  final parts = rangeParts.first.split(':');
                                  if (parts.length == 2) {
                                    final h = int.tryParse(parts[0]);
                                    final m = int.tryParse(parts[1]);
                                    if (h != null && m != null) {
                                      defaultTime = TimeOfDay(
                                        hour: h,
                                        minute: m,
                                      );
                                    }
                                  }
                                }

                                // Modal konfirmasi jam makan
                                final confirmed = await showDialog<TimeOfDay>(
                                  context: context,
                                  builder: (ctx) => _EatTimeDialog(
                                    mealType: widget.mealType,
                                    initialTime: defaultTime,
                                  ),
                                );
                                if (confirmed == null) return;

                                setState(() => _isSubmitting = true);
                                Navigator.pop(context);
                                await widget.onAddAll(
                                  List.from(_cart),
                                  confirmed,
                                );
                              },
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_alt_rounded, size: 18),
                        label: const Text('Simpan Semua'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
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

// ─── Eat Time Dialog ──────────────────────────────────────────────────────────

class _EatTimeDialog extends StatefulWidget {
  final MealType mealType;
  final TimeOfDay initialTime;

  const _EatTimeDialog({required this.mealType, required this.initialTime});

  @override
  State<_EatTimeDialog> createState() => _EatTimeDialogState();
}

class _EatTimeDialogState extends State<_EatTimeDialog> {
  late TextEditingController _hourCtrl;
  late TextEditingController _minCtrl;
  String? _error;

  (int, int)? get _rangeMins {
    final parts = widget.mealType.timeRange.split(' - ');
    if (parts.length != 2) return null;
    int? parseMin(String s) {
      final p = s.trim().split(':');
      if (p.length != 2) return null;
      final h = int.tryParse(p[0]);
      final m = int.tryParse(p[1]);
      if (h == null || m == null) return null;
      return h * 60 + m;
    }

    final s = parseMin(parts[0]);
    final e = parseMin(parts[1]);
    if (s == null || e == null) return null;
    return (s, e);
  }

  bool _isOutOfRange(int h, int m) {
    final r = _rangeMins;
    if (r == null) return false;
    final (s, e) = r;
    final v = h * 60 + m;
    final eAdj = e < s ? e + 24 * 60 : e;
    final vAdj = v < s ? v + 24 * 60 : v;
    return vAdj < s || vAdj > eAdj;
  }

  @override
  void initState() {
    super.initState();
    _hourCtrl = TextEditingController(
      text: widget.initialTime.hour.toString().padLeft(2, '0'),
    );
    _minCtrl = TextEditingController(
      text: widget.initialTime.minute.toString().padLeft(2, '0'),
    );
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final h = int.tryParse(_hourCtrl.text.trim());
    final m = int.tryParse(_minCtrl.text.trim());
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      setState(() => _error = 'Jam 00-23, menit 00-59.');
      return;
    }
    setState(() => _error = null);

    if (_isOutOfRange(h, m)) {
      String pad(int v) => v.toString().padLeft(2, '0');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Jam di luar kisaran'),
          content: Text(
            'Jam ${pad(h)}:${pad(m)} di luar kisaran '
            '${widget.mealType.label} (${widget.mealType.timeRange}).\n\nTetap simpan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ubah Jam'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
              child: const Text(
                'Tetap Simpan',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (mounted) Navigator.pop(context, TimeOfDay(hour: h, minute: m));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Text(widget.mealType.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Jam ${widget.mealType.label}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kisaran: ${widget.mealType.timeRange}',
            style: TextStyle(fontSize: 12, color: theme.hintColor),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hourCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: 'Jam',
                    hintText: '00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _minCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: 'Menit',
                    hintText: '00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: AppColors.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(fontSize: 11, color: AppColors.error),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _onSave, child: const Text('Simpan')),
      ],
    );
  }
}

// ─── Cart Success Overlay ─────────────────────────────────────────────────────

/// Overlay animasi yang muncul saat item berhasil ditambahkan ke keranjang.
/// Menggunakan scale + fade agar terasa ringan dan tidak mengganggu alur input.
class _CartSuccessOverlay extends AnimatedWidget {
  final String foodName;
  final String emoji;

  const _CartSuccessOverlay({
    required this.foodName,
    required this.emoji,
    required AnimationController controller,
  }) : super(listenable: controller);

  AnimationController get _ctrl => listenable as AnimationController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaleAnim = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeIn,
    );
    final fadeAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );

    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment: const Alignment(0, 0.1),
          child: FadeTransition(
            opacity: fadeAnim,
            child: ScaleTransition(
              scale: scaleAnim,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 300),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF1E2A2A)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.primaryColor.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ikon centang animasi
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 22)),
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: theme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Ditambahkan ke keranjang!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      foodName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
          Text(label, style: TextStyle(fontSize: 13, color: theme.hintColor)),
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
              widget.food.satuanNama == 'Gelas'
                  ? 'Jumlah (ml)'
                  : 'Jumlah (gram)',
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

  Widget _previewRow(
    BuildContext context,
    String label,
    double value,
    String unit,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: theme.hintColor)),
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
                      : theme.dividerColor.withValues(
                          alpha: isDark ? 0.18 : 0.08,
                        ),
                  border: Border.all(
                    color: _count > 1
                        ? theme.primaryColor
                        : theme.dividerColor.withValues(
                            alpha: isDark ? 0.35 : 0.2,
                          ),
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
                  border: Border.all(color: theme.primaryColor),
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
          _sectionLabel(
            context,
            widget.food.satuanNama == 'Gelas'
                ? 'Sisa di Gelas'
                : 'Sisa di Piring',
          ),
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
                  _previewRow(
                    context,
                    'Karbohidrat',
                    preview['karbohidrat']!,
                    'g',
                  ),
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
                  style: TextStyle(color: theme.hintColor, fontSize: 13),
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
                _buildMealHeader(
                  context,
                  energiRatio,
                  statusColor,
                  isEnlarged: true,
                ),
                const SizedBox(height: 32),
                Text(
                  'Daftar Makanan',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFoodTable(context, isEnlarged: true),
                const SizedBox(height: 32),
                Text(
                  'Ringkasan Gizi Harian',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTotalsTable(
                  context,
                  actualEnergi,
                  actualProtein,
                  actualLemak,
                  actualKarbo,
                  actualSerat,
                  targetEnergi,
                  targetProtein,
                  targetLemak,
                  targetKarbo,
                  targetSerat,
                  percentage,
                  statusColor,
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

  Widget _buildMealHeader(
    BuildContext context,
    double ratio,
    Color statusColor, {
    bool isEnlarged = false,
  }) {
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
                    style: TextStyle(fontSize: 14, color: theme.hintColor),
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
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
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
            child: Text(
              'Belum ada makanan',
              style: TextStyle(
                fontSize: isEnlarged ? 14 : 12,
                color: theme.hintColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          Table(
            columnWidths: colWidths,
            children: [
              for (final entry in entries)
                TableRow(
                  children: [
                    _tableDataCell(
                      context,
                      entry.foodName,
                      isBold: false,
                      isEnlarged: isEnlarged,
                    ),
                    _tableDataCell(
                      context,
                      entry.energi.toStringAsFixed(0),
                      isEnlarged: isEnlarged,
                    ),
                    _tableDataCell(
                      context,
                      entry.protein.toStringAsFixed(1),
                      isEnlarged: isEnlarged,
                    ),
                    _tableDataCell(
                      context,
                      entry.lemak.toStringAsFixed(1),
                      isEnlarged: isEnlarged,
                    ),
                    _tableDataCell(
                      context,
                      entry.karbohidrat.toStringAsFixed(1),
                      isEnlarged: isEnlarged,
                    ),
                    _tableDataCell(
                      context,
                      entry.serat.toStringAsFixed(1),
                      isEnlarged: isEnlarged,
                    ),
                    _tableDataCell(
                      context,
                      entry.grams.toStringAsFixed(0),
                      isEnlarged: isEnlarged,
                    ),
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
    double actualEnergi,
    double actualProtein,
    double actualLemak,
    double actualKarbo,
    double actualSerat,
    double targetEnergi,
    double targetProtein,
    double targetLemak,
    double targetKarbo,
    double targetSerat,
    double percentage,
    Color statusColor, {
    bool isEnlarged = false,
    double fulfillmentRatio = 0.0,
  }) {
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
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.03),
              ),
              children: [
                _tableDataCell(
                  context,
                  'Total Asupan',
                  isBold: true,
                  isEnlarged: isEnlarged,
                ),
                _tableDataCell(
                  context,
                  actualEnergi.toStringAsFixed(0),
                  isBold: true,
                  isEnlarged: isEnlarged,
                ),
                _tableDataCell(
                  context,
                  actualProtein.toStringAsFixed(1),
                  isBold: true,
                  isEnlarged: isEnlarged,
                ),
                _tableDataCell(
                  context,
                  actualLemak.toStringAsFixed(1),
                  isBold: true,
                  isEnlarged: isEnlarged,
                ),
                _tableDataCell(
                  context,
                  actualKarbo.toStringAsFixed(1),
                  isBold: true,
                  isEnlarged: isEnlarged,
                ),
                _tableDataCell(
                  context,
                  actualSerat.toStringAsFixed(1),
                  isBold: true,
                  isEnlarged: isEnlarged,
                ),
                _tableDataCell(
                  context,
                  '',
                  isBold: true,
                  isEnlarged: isEnlarged,
                ),
              ],
            ),
            TableRow(
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.05),
              ),
              children: [
                _tableDataCell(
                  context,
                  'Total Kebutuhan',
                  isBold: true,
                  color: statusColor,
                  isEnlarged: isEnlarged,
                ),
                _tableDataCell(
                  context,
                  targetEnergi.toStringAsFixed(0),
                  isBold: true,
                  color: statusColor,
                  isEnlarged: isEnlarged,
                ),
                _tableDataCell(
                  context,
                  targetProtein.toStringAsFixed(1),
                  isBold: true,
                  color: statusColor,
                  isEnlarged: isEnlarged,
                ),
                _tableDataCell(
                  context,
                  targetLemak.toStringAsFixed(1),
                  isBold: true,
                  color: statusColor,
                  isEnlarged: isEnlarged,
                ),
                _tableDataCell(
                  context,
                  targetKarbo.toStringAsFixed(1),
                  isBold: true,
                  color: statusColor,
                  isEnlarged: isEnlarged,
                ),
                _tableDataCell(
                  context,
                  targetSerat.toStringAsFixed(1),
                  isBold: true,
                  color: statusColor,
                  isEnlarged: isEnlarged,
                ),
                _tableDataCell(
                  context,
                  '',
                  isBold: true,
                  isEnlarged: isEnlarged,
                ),
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
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.5),
          width: 1,
        ),
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
                    icon: Icon(Icons.fullscreen, size: 16, color: statusColor),
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
                actualEnergi,
                actualProtein,
                actualLemak,
                actualKarbo,
                actualSerat,
                targetEnergi,
                targetProtein,
                targetLemak,
                targetKarbo,
                targetSerat,
                percentage,
                statusColor,
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
              const PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
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

  Widget _tableHeaderCell(
    BuildContext context,
    String text, {
    bool isEnlarged = false,
  }) {
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

  Widget _tableDataCell(
    BuildContext context,
    String text, {
    bool isBold = false,
    Color? color,
    bool isEnlarged = false,
  }) {
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
                Text(
                  'Ringkasan Makan Sehari',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 12),
                _buildBaseTable(context, mealOrder, isPercentage: false),
                const SizedBox(height: 32),
                Text(
                  'Persentase Ketercapaian Gizi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                ),
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

  Widget _buildBaseTable(
    BuildContext context,
    List<MealType> mealOrder, {
    required bool isPercentage,
  }) {
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
                _interpHeaderCell(
                  context,
                  isPercentage ? '% Energi' : 'Energi',
                  isEnlarged: true,
                ),
                _interpHeaderCell(
                  context,
                  isPercentage ? '% Prot' : 'Prot',
                  isEnlarged: true,
                ),
                _interpHeaderCell(
                  context,
                  isPercentage ? '% Lemak' : 'Lemak',
                  isEnlarged: true,
                ),
                _interpHeaderCell(
                  context,
                  isPercentage ? '% Karbo' : 'Karbo',
                  isEnlarged: true,
                ),
                _interpHeaderCell(
                  context,
                  isPercentage ? '% Serat' : 'Serat',
                  isEnlarged: true,
                ),
              ],
            ),
            for (final meal in mealOrder)
              isPercentage
                  ? _buildMealPercentageRow(
                      context,
                      meal,
                      entriesByMeal[meal] ?? [],
                      isEnlarged: true,
                    )
                  : _buildMealInterpretationRow(
                      context,
                      meal,
                      entriesByMeal[meal] ?? [],
                      isEnlarged: true,
                    ),
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
    final pE = totalNeeds.energi > 0
        ? dailyTotals['energi']! / totalNeeds.energi
        : 0.0;
    final pP = totalNeeds.protein > 0
        ? dailyTotals['protein']! / totalNeeds.protein
        : 0.0;
    final pL = totalNeeds.lemak > 0
        ? dailyTotals['lemak']! / totalNeeds.lemak
        : 0.0;
    final pK = totalNeeds.karbohidrat > 0
        ? dailyTotals['karbohidrat']! / totalNeeds.karbohidrat
        : 0.0;
    final pS = totalNeeds.serat > 0
        ? dailyTotals['serat']! / totalNeeds.serat
        : 0.0;

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
                  icon: Icon(
                    Icons.fullscreen,
                    size: 20,
                    color: actionIconColor,
                  ),
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
                        border: Border(
                          top: BorderSide(color: theme.dividerColor, width: 2),
                        ),
                      ),
                      children: [
                        _interpDataCell(
                          context,
                          'Total Ketercapaian (%)',
                          isBold: true,
                        ),
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
    List<FoodLogEntry> entries, {
    bool isEnlarged = false,
  }) {
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
        _interpDataCell(
          context,
          '${meal.emoji} ${meal.label}',
          isEnlarged: isEnlarged,
        ),
        _interpDataCell(
          context,
          '${actualEnergi.toInt()} / ${targetEnergi.toInt()}',
          isEnlarged: isEnlarged,
        ),
        _interpDataCell(
          context,
          '${actualProt.toStringAsFixed(1)} / ${targetProt.toStringAsFixed(1)}',
          isEnlarged: isEnlarged,
        ),
        _interpDataCell(
          context,
          '${actualLemak.toStringAsFixed(1)} / ${targetLemak.toStringAsFixed(1)}',
          isEnlarged: isEnlarged,
        ),
        _interpDataCell(
          context,
          '${actualKarbo.toStringAsFixed(1)} / ${targetKarbo.toStringAsFixed(1)}',
          isEnlarged: isEnlarged,
        ),
        _interpDataCell(
          context,
          '${actualSerat.toStringAsFixed(1)} / ${targetSerat.toStringAsFixed(1)}',
          isEnlarged: isEnlarged,
        ),
      ],
    );
  }

  TableRow _buildMealPercentageRow(
    BuildContext context,
    MealType meal,
    List<FoodLogEntry> entries, {
    bool isEnlarged = false,
  }) {
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
        _interpDataCell(
          context,
          '${meal.emoji} ${meal.label}',
          isEnlarged: isEnlarged,
        ),
        _interpPercentageCell(context, pE, isEnlarged: isEnlarged),
        _interpPercentageCell(context, pP, isEnlarged: isEnlarged),
        _interpPercentageCell(context, pL, isEnlarged: isEnlarged),
        _interpPercentageCell(context, pK, isEnlarged: isEnlarged),
        _interpPercentageCell(context, pS, isEnlarged: isEnlarged),
      ],
    );
  }

  Widget _interpPercentageCell(
    BuildContext context,
    double ratio, {
    bool isEnlarged = false,
  }) {
    final statusColor = getStatusColor(ratio);
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: isEnlarged ? 12 : 8,
        horizontal: 4,
      ),
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

  Widget _interpHeaderCell(
    BuildContext context,
    String text, {
    bool isEnlarged = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: isEnlarged ? 12 : 8,
        horizontal: 4,
      ),
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

  Widget _interpDataCell(
    BuildContext context,
    String text, {
    bool isBold = false,
    Color? color,
    bool isEnlarged = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: isEnlarged ? 12 : 8,
        horizontal: 4,
      ),
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
                if (index < 0 || index >= _dmMealOrder.length) {
                  return const SizedBox();
                }
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
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
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
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.2 : 0.05,
            ),
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
            style: TextStyle(fontSize: 11, color: theme.hintColor),
          ),
          const SizedBox(height: 20),

          // Chart
          SizedBox(height: 200, child: _buildChart(context)),

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

// ─────────────────────────────────────────────────────────────────────────────
// DIALOG MODIFIKATOR MAKANAN (PENGOLAHAN & BAHAN TAMBAHAN)
// ─────────────────────────────────────────────────────────────────────────────
class _FoodModifierDialog extends StatefulWidget {
  final FoodItem food;
  final bool isGuest;
  final void Function(double grams, CookingMethod? cookingMethod, List<SelectedAdditive> additives) onSave;

  const _FoodModifierDialog({
    required this.food,
    required this.isGuest,
    required this.onSave,
  });

  @override
  State<_FoodModifierDialog> createState() => _FoodModifierDialogState();
}

class _FoodModifierDialogState extends State<_FoodModifierDialog> {
  // Porsi state
  bool _useCustomGram = false;
  late int _takaranIdx;
  
  // Gunakan controller untuk input jumlah URT & Gram agar bebas mengetik angka desimal
  final _urtCountCtrl = TextEditingController(text: '1');
  final _gramCtrl = TextEditingController(text: '100');

  // Modifiers state
  List<CookingMethod> _cookingMethods = [];
  List<FoodAdditive> _additivesPool = [];
  bool _loadingModifiers = true;

  CookingMethod? _selectedCookingMethod;
  final List<SelectedAdditive> _selectedAdditives = [];

  @override
  void initState() {
    super.initState();
    // Jika tidak ada takaran saji terstruktur, gunakan input custom gram
    _useCustomGram = widget.food.takaranSaji.isEmpty;
    final takaranLength = widget.food.takaranSaji.length;
    _takaranIdx = takaranLength <= 1 ? 0 : 1;
    
    // Set inisial gram berdasarkan takaran saji jika ada
    if (widget.food.takaranSaji.isNotEmpty) {
      final t = widget.food.takaranSaji[_takaranIdx];
      _gramCtrl.text = t.gram.toStringAsFixed(0);
    } else {
      _gramCtrl.text = '100'; // Default fallback
    }
    
    _loadModifiers();
  }

  @override
  void dispose() {
    _urtCountCtrl.dispose();
    _gramCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadModifiers() async {
    try {
      // Force refresh agar data yang baru di-seed langsung muncul
      final methods = await FoodModifierService.getCookingMethods(forceRefresh: true);
      final additives = await FoodModifierService.getFoodAdditives(forceRefresh: true);
      if (mounted) {
        setState(() {
          _cookingMethods = [CookingMethod.mentah, ...methods];
          _additivesPool = additives;
          _selectedCookingMethod = CookingMethod.mentah;
          _loadingModifiers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingModifiers = false);
    }
  }

  double get _baseGrams {
    if (_useCustomGram) {
      return double.tryParse(_gramCtrl.text.trim()) ?? 0.0;
    } else {
      final count = double.tryParse(_urtCountCtrl.text.trim()) ?? 0.0;
      final t = widget.food.takaranSaji[_takaranIdx];
      return t.gram * count;
    }
  }

  // ── Hitung kalkulasi real-time gizi ────────────────────────────────────────
  Map<String, double> get _currentNutrition {
    final grams = _baseGrams;
    final baseNutrition = widget.food.calcFor(grams);

    double energi  = (baseNutrition['energi']      ?? 0.0).toDouble();
    double protein = (baseNutrition['protein']     ?? 0.0).toDouble();
    double lemak   = (baseNutrition['lemak']       ?? 0.0).toDouble();
    double karbo   = (baseNutrition['karbohidrat'] ?? 0.0).toDouble();
    double natrium = (baseNutrition['natrium']     ?? 0.0).toDouble();

    // Terapkan metode pengolahan
    if (_selectedCookingMethod != null) {
      final delta = _selectedCookingMethod!.deltaFor(grams);
      if (_selectedCookingMethod!.mode == CookingNutritionMode.addition) {
        energi  += delta['energi']      ?? 0;
        lemak   += delta['lemak']       ?? 0;
        karbo   += delta['karbohidrat'] ?? 0;
        protein += delta['protein']     ?? 0;
        natrium += delta['natrium']     ?? 0;
      } else {
        // Factor mode
        final fk = delta['fk'] ?? 1.0;
        final rawNutrition = widget.food.calcFor(grams * fk);
        energi  = (rawNutrition['energi']      ?? 0.0).toDouble();
        protein = (rawNutrition['protein']     ?? 0.0).toDouble();
        lemak   = (rawNutrition['lemak']       ?? 0.0).toDouble();
        karbo   = (rawNutrition['karbohidrat'] ?? 0.0).toDouble();
        natrium = (rawNutrition['natrium']     ?? 0.0).toDouble();
      }
    }

    // Tambahkan bahan tambahan
    for (final sa in _selectedAdditives) {
      final n = sa.totalNutrisi;
      energi  += n['energi']      ?? 0;
      lemak   += n['lemak']       ?? 0;
      karbo   += n['karbohidrat'] ?? 0;
      protein += n['protein']     ?? 0;
      natrium += n['natrium']     ?? 0;
    }

    return {
      'energi': energi,
      'karbohidrat': karbo,
      'lemak': lemak,
      'protein': protein,
      'natrium': natrium,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nutrition = _currentNutrition;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: _loadingModifiers
            ? const SizedBox(
                height: 220,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                      SizedBox(height: 12),
                      Text('Memuat metode & bahan...', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(widget.food.emoji, style: const TextStyle(fontSize: 22)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.food.nama,
                                      style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.food.kategori} ${widget.food.urt.isNotEmpty ? "• URT: " + widget.food.urt : ""}',
                                style: TextStyle(
                                    fontSize: 11, color: theme.hintColor),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // ── 1. Pilihan Porsi ─────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Porsi Makanan',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        if (widget.food.takaranSaji.isNotEmpty)
                          Container(
                            decoration: BoxDecoration(
                              color: theme.dividerColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() => _useCustomGram = false);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: !_useCustomGram ? AppColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'URT',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: !_useCustomGram ? FontWeight.bold : FontWeight.w500,
                                        color: !_useCustomGram ? Colors.white : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _useCustomGram = true;
                                      final t = widget.food.takaranSaji[_takaranIdx];
                                      _gramCtrl.text = t.gram.toStringAsFixed(0);
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _useCustomGram ? AppColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Gram',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: _useCustomGram ? FontWeight.bold : FontWeight.w500,
                                        color: _useCustomGram ? Colors.white : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_useCustomGram) ...[
                      TextField(
                        controller: _gramCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Berat porsi (gram)',
                          suffixText: 'g',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() {}),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<int>(
                              value: _takaranIdx,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Takaran saji',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: List.generate(
                                widget.food.takaranSaji.length,
                                (i) {
                                  final t = widget.food.takaranSaji[i];
                                  return DropdownMenuItem(
                                    value: i,
                                    child: Text('${t.ukuran} (${t.gram.toStringAsFixed(0)}g)'),
                                  );
                                },
                              ),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    _takaranIdx = v;
                                    final t = widget.food.takaranSaji[v];
                                    _gramCtrl.text = t.gram.toStringAsFixed(0);
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('Jumlah', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                const SizedBox(height: 4),
                                _NumberStepper(
                                  controller: _urtCountCtrl,
                                  labelText: '',
                                  suffixText: '', // Kosongkan agar lega
                                  onChanged: () => setState(() {}),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    widget.food.satuanNama,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),

                    // ── 2. Pilihan Pengolahan ──────────────────────────────
                    const Text(
                      'Metode Masak / Pengolahan',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<CookingMethod>(
                      value: _selectedCookingMethod,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _cookingMethods.map((m) {
                        final String tag = m.mode == CookingNutritionMode.addition && m.id != 'mentah'
                            ? ' (+ lemak)'
                            : m.id != 'mentah' ? ' (FK: ${m.defaultFk})' : '';
                        return DropdownMenuItem(
                          value: m,
                          child: Text(
                            m.name + tag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedCookingMethod = v);
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── 3. Bahan Tambahan ──────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Bahan Tambahan (Bumbu/Tepung/Garam)',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showAddAdditiveDialog,
                          icon: const Icon(Icons.add_circle_outline, size: 16),
                          label: const Text('Tambah'),
                        ),
                      ],
                    ),
                    if (_selectedAdditives.isEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '— Tanpa bahan tambahan —',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _selectedAdditives.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, idx) {
                          final sa = _selectedAdditives[idx];
                          final countController = TextEditingController(
                            text: sa.jumlahUnit.toString().replaceAll('.0', ''),
                          );
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.hoverColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sa.additive.name,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        '1 ${sa.additive.unitLabel} = ±${sa.additive.gramPerUnit.toStringAsFixed(0)}g',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: theme.hintColor),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Input jumlah URT dinamis dengan stepper
                                SizedBox(
                                  width: 110,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      _NumberStepper(
                                        controller: countController,
                                        labelText: '',
                                        suffixText: '',
                                        onChanged: () {
                                          final parsed = double.tryParse(countController.text) ?? 0.0;
                                          setState(() {
                                            _selectedAdditives[idx] = SelectedAdditive(
                                              additive: sa.additive,
                                              jumlahUnit: parsed,
                                            );
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.primaryColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          sa.additive.unitLabel,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: theme.primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: () => setState(() => _selectedAdditives.removeAt(idx)),
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppColors.error, size: 20),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    const Divider(height: 32),

                    // ── 4. Pratinjau Gizi Real-time ─────────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estimasi Nutrisi Porsi Ini',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary),
                          ),
                          const SizedBox(height: 8),
                          _nutritionRow('Energi', nutrition['energi']!, 'kkal', isPrimary: true),
                          _nutritionRow('Karbohidrat', nutrition['karbohidrat']!, 'g'),
                          _nutritionRow('Protein', nutrition['protein']!, 'g'),
                          _nutritionRow('Lemak', nutrition['lemak']!, 'g'),
                          _nutritionRow('Natrium', nutrition['natrium']!, 'mg',
                              color: nutrition['natrium']! > 400 ? AppColors.error : null),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _baseGrams <= 0
                                ? null
                                : () {
                                    widget.onSave(_baseGrams, _selectedCookingMethod, _selectedAdditives);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Tambahkan'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _showAddAdditiveDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                'Pilih Bahan Tambahan',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _additivesPool.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final a = _additivesPool[i];
                  return ListTile(
                    dense: true,
                    title: Text(a.name),
                    subtitle: Text('${a.unitLabel} • ${a.category}'),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        // Jangan duplikat
                        if (!_selectedAdditives.any((x) => x.additive.id == a.id)) {
                          _selectedAdditives.add(
                            SelectedAdditive(additive: a, jumlahUnit: 1.0),
                          );
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const Divider(),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Tutup'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nutritionRow(String label, double value, String unit, {bool isPrimary = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal)),
          Text(
            '${value.toStringAsFixed(1)} $unit',
            style: TextStyle(
                fontSize: isPrimary ? 13 : 12,
                fontWeight: FontWeight.bold,
                color: color ?? (isPrimary ? AppColors.primary : AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
