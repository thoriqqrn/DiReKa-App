import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:universal_html/html.dart' as html;

import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../models/disease_type.dart';
import '../../models/user_model.dart';
import '../../services/admin_service.dart';

enum _AdminTab { home, users, food, health, education }

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final AdminService _adminService = AdminService();

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _contentCtrl = TextEditingController();
  final TextEditingController _sourceUrlCtrl = TextEditingController();

  int _selectedTabIndex = 0;

  bool _isUsersLoading = false;
  String? _usersError;
  int _totalUsers = 0;
  Map<DiseaseType, int> _usersByDisease = {};
  List<UserModel> _users = [];

  bool _isFoodLoading = false;
  String? _foodError;
  List<AdminFoodLogSummary> _foodLogs = [];
  String _foodFilterUid = 'all';

  bool _isHealthLoading = false;
  String? _healthError;
  List<AdminHealthRecordSummary> _healthRecords = [];

  bool _isEducationLoading = false;
  bool _isUploadingEducation = false;
  String? _educationError;
  List<EducationPost> _educationPosts = [];

  @override
  void initState() {
    super.initState();
    _loadHomeTab();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _sourceUrlCtrl.dispose();
    super.dispose();
  }

  _AdminTab get _selectedTab {
    if (_selectedTabIndex < 0 || _selectedTabIndex >= _AdminTab.values.length) {
      return _AdminTab.home;
    }
    return _AdminTab.values[_selectedTabIndex];
  }

  Future<void> _loadHomeTab() async {
    await Future.wait([
      _loadUsersTab(),
      _loadFoodTab(),
      _loadHealthTab(),
      _loadEducationTab(),
    ]);
  }

  Future<void> _refreshCurrentTab() async {
    switch (_selectedTab) {
      case _AdminTab.home:
        await _loadHomeTab();
        break;
      case _AdminTab.users:
        await _loadUsersTab();
        break;
      case _AdminTab.food:
        await _loadFoodTab();
        break;
      case _AdminTab.health:
        await _loadHealthTab();
        break;
      case _AdminTab.education:
        await _loadEducationTab();
        break;
    }
  }

  Future<void> _loadUsersTab() async {
    setState(() {
      _isUsersLoading = true;
      _usersError = null;
    });

    try {
      final total = await _adminService.getTotalUsers();
      final byDisease = await _adminService.getUsersByDisease();
      final users = await _adminService.getAllUsers();
      if (!mounted) return;
      setState(() {
        _totalUsers = total;
        _usersByDisease = byDisease;
        _users = users;
        _isUsersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usersError = 'Gagal memuat data user: $e';
        _isUsersLoading = false;
      });
    }
  }

  Future<void> _loadFoodTab() async {
    setState(() {
      _isFoodLoading = true;
      _foodError = null;
    });

    try {
      final logs = await _adminService.getRecentFoodLogs(limit: 100);
      if (!mounted) return;
      setState(() {
        _foodLogs = logs;
        if (_foodFilterUid != 'all' &&
            !_foodLogs.any((item) => item.uid == _foodFilterUid)) {
          _foodFilterUid = 'all';
        }
        _isFoodLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _foodError = 'Gagal memuat data food tracker: $e';
        _isFoodLoading = false;
      });
    }
  }

  Future<void> _loadHealthTab() async {
    setState(() {
      _isHealthLoading = true;
      _healthError = null;
    });

    try {
      final records = await _adminService.getRecentHealthRecords();
      if (!mounted) return;
      setState(() {
        _healthRecords = records;
        _isHealthLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _healthError = 'Gagal memuat data health tracker: $e';
        _isHealthLoading = false;
      });
    }
  }

  Future<void> _loadEducationTab() async {
    setState(() {
      _isEducationLoading = true;
      _educationError = null;
    });

    try {
      final posts = await _adminService.getEducationPosts();
      if (!mounted) return;
      setState(() {
        _educationPosts = posts;
        _isEducationLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _educationError = 'Gagal memuat konten edukasi: $e';
        _isEducationLoading = false;
      });
    }
  }

  Future<void> _uploadEducation() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    final sourceUrl = _sourceUrlCtrl.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan isi edukasi wajib diisi.')),
      );
      return;
    }

    setState(() {
      _isUploadingEducation = true;
      _educationError = null;
    });

    try {
      await _adminService.uploadEducationPost(
        title: title,
        content: content,
        sourceUrl: sourceUrl.isEmpty ? null : sourceUrl,
      );

      _titleCtrl.clear();
      _contentCtrl.clear();
      _sourceUrlCtrl.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konten edukasi berhasil diupload.')),
      );
      await _loadEducationTab();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _educationError = 'Upload edukasi gagal: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingEducation = false;
        });
      }
    }
  }

  Future<void> _deleteEducation(EducationPost post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Edukasi'),
        content: Text('Hapus "${post.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _adminService.deleteEducationPost(post.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konten edukasi dihapus.')),
      );
      await _loadEducationTab();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus: $e')),
      );
    }
  }

  Future<void> _editEducation(EducationPost post) async {
    final titleCtrl = TextEditingController(text: post.title);
    final contentCtrl = TextEditingController(text: post.content);
    final urlCtrl = TextEditingController(text: post.sourceUrl ?? '');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Edukasi'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Judul',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contentCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Isi Edukasi',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Link Sumber (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    // Baca nilai sebelum dispose
    final newTitle = titleCtrl.text.trim();
    final newContent = contentCtrl.text.trim();
    final newUrl = urlCtrl.text.trim();

    titleCtrl.dispose();
    contentCtrl.dispose();
    urlCtrl.dispose();

    if (confirm != true) return;
    try {
      await _adminService.updateEducationPost(
        postId: post.id,
        title: newTitle,
        content: newContent,
        sourceUrl: newUrl.isEmpty ? null : newUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konten edukasi diperbarui.')),
      );
      await _loadEducationTab();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui: $e')),
      );
    }
  }

  void _onSelectTab(int index) {
    final safeIndex = index.clamp(0, _AdminTab.values.length - 1);
    final tab = _AdminTab.values[safeIndex];
    setState(() => _selectedTabIndex = safeIndex);

    if (tab == _AdminTab.users && _users.isEmpty && !_isUsersLoading) {
      _loadUsersTab();
    }
    if (tab == _AdminTab.food && _foodLogs.isEmpty && !_isFoodLoading) {
      _loadFoodTab();
    }
    if (tab == _AdminTab.health && _healthRecords.isEmpty && !_isHealthLoading) {
      _loadHealthTab();
    }
    if (tab == _AdminTab.education &&
        _educationPosts.isEmpty &&
        !_isEducationLoading) {
      _loadEducationTab();
    }
  }

  Future<void> _exportFoodToXlsx() async {
    final rows = _filteredFoodLogs();
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diexport.')),
      );
      return;
    }

    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export XLSX saat ini tersedia untuk Web.')),
      );
      return;
    }

    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'Food Tracker';

    final headers = [
      'Nama User',
      'Email',
      'UID',
      'Tanggal',
      'Jumlah Entri',
      'Daftar Makanan',
    ];

    for (var i = 0; i < headers.length; i++) {
      sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
    }

    var rowIndex = 2;
    for (final item in rows) {
      final foods = item.entries
          .map((e) => '${(e['foodName'] ?? '-')} (${(e['grams'] ?? 0)} g)')
          .join('; ');

      sheet.getRangeByIndex(rowIndex, 1).setText(item.userName);
      sheet.getRangeByIndex(rowIndex, 2).setText(item.userEmail);
      sheet.getRangeByIndex(rowIndex, 3).setText(item.uid);
      sheet
          .getRangeByIndex(rowIndex, 4)
          .setText(DateFormat('yyyy-MM-dd').format(item.date));
      sheet.getRangeByIndex(rowIndex, 5).setNumber(item.entryCount.toDouble());
      sheet.getRangeByIndex(rowIndex, 6).setText(foods);
      rowIndex++;
    }

    sheet.autoFitColumn(1);
    sheet.autoFitColumn(2);
    sheet.autoFitColumn(3);
    sheet.autoFitColumn(4);
    sheet.autoFitColumn(5);
    sheet.autoFitColumn(6);

    final bytes = workbook.saveAsStream();
    workbook.dispose();

    final blob = html.Blob(
      [Uint8List.fromList(bytes)],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute(
        'download',
        'food_tracker_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx',
      )
      ..click();

    html.Url.revokeObjectUrl(url);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export XLSX berhasil.')),
    );
  }

  List<AdminFoodLogSummary> _filteredFoodLogs() {
    if (_foodFilterUid == 'all') return _foodLogs;
    return _foodLogs.where((item) => item.uid == _foodFilterUid).toList();
  }

  List<_FoodUserFilter> _foodUserOptions() {
    final map = <String, _FoodUserFilter>{};
    for (final item in _foodLogs) {
      map[item.uid] = _FoodUserFilter(
        uid: item.uid,
        name: item.userName,
        email: item.userEmail,
      );
    }
    final list = map.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_titleForTab(_selectedTab)),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshCurrentTab,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Pengaturan Admin',
            onPressed: () => Navigator.pushNamed(
              context,
              AppConstants.routeAdminSettings,
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _buildBody(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTabIndex.clamp(0, _AdminTab.values.length - 1),
        onTap: _onSelectTab,
        selectedItemColor: AppColors.navSelected,
        unselectedItemColor: AppColors.navUnselected,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.group_outlined), label: 'User'),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu_outlined),
            label: 'Food',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart_outlined),
            label: 'Health',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined),
            label: 'Edukasi',
          ),
        ],
      ),
    );
  }

  String _titleForTab(_AdminTab tab) {
    switch (tab) {
      case _AdminTab.home:
        return 'Admin - Home Dashboard';
      case _AdminTab.users:
        return 'Admin - Data User';
      case _AdminTab.food:
        return 'Admin - Food Tracker';
      case _AdminTab.health:
        return 'Admin - Health Tracker';
      case _AdminTab.education:
        return 'Admin - Upload Edukasi';
    }
  }

  Widget _buildBody() {
    switch (_selectedTab) {
      case _AdminTab.home:
        return _buildHomeTab();
      case _AdminTab.users:
        return _buildUsersTab();
      case _AdminTab.food:
        return _buildFoodTab();
      case _AdminTab.health:
        return _buildHealthTab();
      case _AdminTab.education:
        return _buildEducationTab();
    }
  }

  Widget _buildHomeTab() {
    final isLoading = _isUsersLoading || _isFoodLoading || _isHealthLoading;
    final error = _usersError ?? _foodError ?? _healthError;

    if (isLoading && _users.isEmpty && _foodLogs.isEmpty && _healthRecords.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && _users.isEmpty) {
      return _ErrorView(message: error, onRetry: _loadHomeTab);
    }

    final diseaseCounts = DiseaseType.values
        .map((d) => (_usersByDisease[d] ?? 0).toDouble())
        .toList();
    final maxValue = math.max(1.0, diseaseCounts.fold(0.0, math.max));

    return RefreshIndicator(
      onRefresh: _loadHomeTab,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Total User',
                  value: '$_totalUsers',
                  icon: Icons.group,
                  color: const Color(0xFF0F5CC0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'Food Logs',
                  value: '${_foodLogs.length}',
                  icon: Icons.restaurant,
                  color: const Color(0xFF0AA37A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Health Records',
                  value: '${_healthRecords.length}',
                  icon: Icons.monitor_heart,
                  color: const Color(0xFFE06C2B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  title: 'Edukasi',
                  value: '${_educationPosts.length}',
                  icon: Icons.school,
                  color: const Color(0xFF7A4AC7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Distribusi Penyakit Pengguna',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      maxY: maxValue + (maxValue * 0.2),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      alignment: BarChartAlignment.spaceAround,
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, _) {
                              final labels = ['Ginjal', 'Diabetes', 'Jantung'];
                              final idx = value.toInt();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  idx >= 0 && idx < labels.length
                                      ? labels[idx]
                                      : '-',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < diseaseCounts.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: diseaseCounts[i],
                                width: 24,
                                color: const [
                                  AppColors.kidneyColor,
                                  AppColors.diabetesColor,
                                  AppColors.heartColor,
                                ][i],
                                borderRadius: BorderRadius.circular(6),
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
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    if (_isUsersLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_usersError != null) {
      return _ErrorView(message: _usersError!, onRetry: _loadUsersTab);
    }

    return RefreshIndicator(
      onRefresh: _loadUsersTab,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatsHeader(totalUsers: _totalUsers, usersByDisease: _usersByDisease),
          const SizedBox(height: 16),
          const Text(
            'Daftar User',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (_users.isEmpty)
            const _EmptyView(message: 'Belum ada user terdaftar.')
          else
            ..._users.map(
              (user) => Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.primaryDark),
                    ),
                  ),
                  title: Text(user.name),
                  subtitle: Text('${user.email}\n${user.diseaseType.shortLabel}'),
                  isThreeLine: true,
                  trailing: Text(
                    DateFormat('dd MMM yyyy', 'id_ID').format(user.createdAt),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFoodTab() {
    if (_isFoodLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_foodError != null) {
      return _ErrorView(message: _foodError!, onRetry: _loadFoodTab);
    }

    final filters = _foodUserOptions();
    final logs = _filteredFoodLogs();

    return RefreshIndicator(
      onRefresh: _loadFoodTab,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Food Tracker Log',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _exportFoodToXlsx,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Export XLSX'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Tombol Kelola Katalog Makanan ──────────────────────────────
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(
              context,
              AppConstants.routeAdminFoodCatalog,
            ),
            icon: const Icon(Icons.table_chart_outlined, size: 18),
            label: const Text('Kelola Katalog Makanan'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              backgroundColor: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _foodFilterUid == 'all',
                onSelected: (_) => setState(() => _foodFilterUid = 'all'),
              ),
              ...filters.map(
                (item) => ChoiceChip(
                  label: Text(item.name),
                  selected: _foodFilterUid == item.uid,
                  onSelected: (_) => setState(() => _foodFilterUid = item.uid),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (logs.isEmpty)
            const _EmptyView(message: 'Belum ada data food tracker.')
          else
            ...logs.map(
              (item) => Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  leading: const Icon(Icons.restaurant_outlined),
                  title: Text(item.userName),
                  subtitle: Text(
                    '${item.userEmail}\n${DateFormat('dd MMM yyyy', 'id_ID').format(item.date)} • ${item.entryCount} entri',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [
                    if (item.entries.isEmpty)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Tidak ada entri.'),
                      )
                    else
                      ...item.entries.map(
                        (entry) => Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '• ${(entry['foodName'] ?? '-')} (${(entry['grams'] ?? 0)} g)',
                            ),
                          ),
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

  Widget _buildHealthTab() {
    if (_isHealthLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_healthError != null) {
      return _ErrorView(message: _healthError!, onRetry: _loadHealthTab);
    }

    return RefreshIndicator(
      onRefresh: _loadHealthTab,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Data Health Tracker Terbaru',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (_healthRecords.isEmpty)
            const _EmptyView(message: 'Belum ada data health tracker.')
          else
            ..._healthRecords.map(
              (record) => Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.monitor_heart_outlined),
                  title: Text('${record.userName} • ${record.source}'),
                  subtitle: Text(
                    '${record.userEmail}\n${record.type} | ${_payloadPreview(record.payload)}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    DateFormat('dd MMM\nHH:mm', 'id_ID').format(record.date),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEducationTab() {
    if (_isEducationLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_educationError != null && _educationPosts.isEmpty) {
      return _ErrorView(message: _educationError!, onRetry: _loadEducationTab);
    }

    return RefreshIndicator(
      onRefresh: _loadEducationTab,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upload Konten Edukasi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Judul',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _contentCtrl,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Isi Edukasi',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _sourceUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Link Sumber (opsional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isUploadingEducation ? null : _uploadEducation,
                    icon: _isUploadingEducation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: Text(
                      _isUploadingEducation ? 'Mengupload...' : 'Upload Edukasi',
                    ),
                  ),
                ),
                if (_educationError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _educationError!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Konten Terupload',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (_educationPosts.isEmpty)
            const _EmptyView(message: 'Belum ada konten edukasi.')
          else
            ..._educationPosts.map(
              (post) => Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(post.title),
                  subtitle: Text(
                    '${post.content}\nOleh: ${post.createdBy}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy', 'id_ID')
                            .format(post.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            size: 18, color: AppColors.primary),
                        tooltip: 'Edit',
                        onPressed: () => _editEducation(post),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppColors.error),
                        tooltip: 'Hapus',
                        onPressed: () => _deleteEducation(post),
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

  String _payloadPreview(Map<String, dynamic> payload) {
    if (payload.isEmpty) return '-';
    final keys = payload.keys.take(2).toList();
    return keys.map((k) => '$k: ${payload[k]}').join(' | ');
  }
}

class _FoodUserFilter {
  final String uid;
  final String name;
  final String email;

  const _FoodUserFilter({
    required this.uid,
    required this.name,
    required this.email,
  });
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  final int totalUsers;
  final Map<DiseaseType, int> usersByDisease;

  const _StatsHeader({required this.totalUsers, required this.usersByDisease});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Pengguna',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            '$totalUsers akun',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DiseaseType.values.map((disease) {
              final count = usersByDisease[disease] ?? 0;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${disease.shortLabel}: $count',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 50),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String message;

  const _EmptyView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
