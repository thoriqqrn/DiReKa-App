import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:universal_html/html.dart' as html;

import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../models/activity_level.dart';
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
  
  // Search & Filter state for Users
  String _userSearchQuery = '';
  DiseaseType? _userDiseaseFilter;
  int _userCurrentPage = 0;
  static const int _userPageSize = 10;

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

  void _showUserDetailDialog(UserModel user) {
    final isFamily = user.primaryUserUid != null;
    String primaryName = '-';
    if (isFamily) {
      try {
        primaryName = _users.firstWhere((u) => u.uid == user.primaryUserUid).name;
      } catch (_) { primaryName = 'Akun Utama'; }
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Detail Profil Pengguna'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Profil
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        user.name[0].toUpperCase(),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(user.email, style: const TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    if (isFamily)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'AKUN KELUARGA',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 32),

                // Data Biografi
                _buildDetailSection('Data Biografi', [
                  _detailRow('Jenis Kelamin', user.gender),
                  _detailRow('Tanggal Lahir', DateFormat('dd MMMM yyyy', 'id_ID').format(user.dateOfBirth)),
                  _detailRow('Usia', user.ageString),
                  _detailRow('Pendidikan', user.education.isEmpty ? '-' : user.education),
                  _detailRow('Pekerjaan', user.occupation.isEmpty ? '-' : user.occupation),
                ]),

                // Alamat
                _buildDetailSection('Alamat', [
                  _detailRow('Desa/Kelurahan', user.addressVillage),
                  _detailRow('Kecamatan', user.addressDistrict),
                  _detailRow('Kota/Kabupaten', user.addressCity),
                  _detailRow('Provinsi', user.addressProvince),
                ]),

                // Data Klinis Umum
                _buildDetailSection('Informasi Klinis & Gizi', [
                  _detailRow('Jenis Penyakit', DiseaseTypeExtension.getLabel(user.diseaseType)),
                  _detailRow('Berat Badan', '${user.weight} kg'),
                  _detailRow('Tinggi Badan', '${user.height} cm'),
                  _detailRow('IMT', '${user.bmi.toStringAsFixed(1)} (${user.bmiCategory})'),
                  _detailRow('Berat Badan Ideal', '${user.bbi.toStringAsFixed(1)} kg'),
                  _detailRow('Tingkat Aktivitas', user.activityLevel?.label ?? '-'),
                  _detailRow('Output Urin', '${user.urinOutput} ml/hari'),
                ]),

                // Data Penyakit Spesifik
                if (user.diseaseType == DiseaseType.type2DiabetesMellitus)
                  _buildDetailSection('Data Khusus Diabetes', [
                    _detailRow('Lama Menderita DM', '${user.diabetesDurationYears} tahun'),
                    _detailRow('Terapi Insulin', user.usesInsulinTherapy ? 'Ya' : 'Tidak'),
                    if (user.usesInsulinTherapy)
                      _detailRow('Lama Pakai Insulin', '${user.insulinDurationYears} tahun'),
                  ]),

                if (user.diseaseType == DiseaseType.heartFailure)
                  _buildDetailSection('Data Khusus Jantung', [
                    _detailRow('Lama Jantung Koroner', '${user.heartDiseaseDurationYears} tahun'),
                    _detailRow('Riwayat Bengkak', user.hasEdema ? 'Ada' : 'Tidak Ada'),
                  ]),

                // Info Akun
                _buildDetailSection('Informasi Sistem', [
                  _detailRow('Tipe Akun', isFamily ? 'Keluarga' : 'Utama'),
                  if (isFamily) _detailRow('Akun Utama', primaryName),
                  _detailRow('Terdaftar Sejak', DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(user.createdAt)),
                  _detailRow('Login Terakhir', user.lastLoginDate != null ? DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(user.lastLoginDate!) : '-'),
                  _detailRow('Current Streak', '${user.currentStreak} hari'),
                ]),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportUsersToXlsx() async {
    final filtered = _users.where((u) {
      final matchesSearch = u.name.toLowerCase().contains(_userSearchQuery.toLowerCase()) ||
          u.email.toLowerCase().contains(_userSearchQuery.toLowerCase());
      final matchesDisease = _userDiseaseFilter == null || u.diseaseType == _userDiseaseFilter;
      return matchesSearch && matchesDisease;
    }).toList();

    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data user untuk diexport.')),
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
    sheet.name = 'Daftar Pengguna';

    final headers = [
      'Nama', 'Email', 'Gender', 'Tgl Lahir', 'Usia',
      'Desa', 'Kecamatan', 'Kota/Kab', 'Provinsi',
      'Pendidikan', 'Pekerjaan', 'Penyakit',
      'BB (kg)', 'TB (cm)', 'IMT', 'Kategori IMT', 'BBI (kg)',
      'Lama DM (thn)', 'Terapi Insulin', 'Lama Insulin (thn)',
      'Lama Jantung (thn)', 'Riwayat Bengkak',
      'Urin Output (ml)', 'Aktifitas Fisik',
      'Tipe Akun', 'Tautan Dari', 'Tgl Daftar'
    ];

    for (var i = 0; i < headers.length; i++) {
      sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
    }

    var rowIndex = 2;
    for (final u in filtered) {
      final isFamily = u.primaryUserUid != null;
      String primaryName = '-';
      if (isFamily) {
        try {
          primaryName = _users.firstWhere((p) => p.uid == u.primaryUserUid).name;
        } catch (_) { primaryName = 'Akun Utama'; }
      }

      sheet.getRangeByIndex(rowIndex, 1).setText(u.name);
      sheet.getRangeByIndex(rowIndex, 2).setText(u.email);
      sheet.getRangeByIndex(rowIndex, 3).setText(u.gender);
      sheet.getRangeByIndex(rowIndex, 4).setText(DateFormat('yyyy-MM-dd').format(u.dateOfBirth));
      sheet.getRangeByIndex(rowIndex, 5).setText(u.ageString);
      sheet.getRangeByIndex(rowIndex, 6).setText(u.addressVillage);
      sheet.getRangeByIndex(rowIndex, 7).setText(u.addressDistrict);
      sheet.getRangeByIndex(rowIndex, 8).setText(u.addressCity);
      sheet.getRangeByIndex(rowIndex, 9).setText(u.addressProvince);
      sheet.getRangeByIndex(rowIndex, 10).setText(u.education);
      sheet.getRangeByIndex(rowIndex, 11).setText(u.occupation);
      sheet.getRangeByIndex(rowIndex, 12).setText(DiseaseTypeExtension.getLabel(u.diseaseType));
      sheet.getRangeByIndex(rowIndex, 13).setNumber(u.weight);
      sheet.getRangeByIndex(rowIndex, 14).setNumber(u.height);
      sheet.getRangeByIndex(rowIndex, 15).setNumber(double.parse(u.bmi.toStringAsFixed(2)));
      sheet.getRangeByIndex(rowIndex, 16).setText(u.bmiCategory);
      sheet.getRangeByIndex(rowIndex, 17).setNumber(double.parse(u.bbi.toStringAsFixed(2)));
      sheet.getRangeByIndex(rowIndex, 18).setNumber(u.diabetesDurationYears);
      sheet.getRangeByIndex(rowIndex, 19).setText(u.usesInsulinTherapy ? 'Ya' : 'Tidak');
      sheet.getRangeByIndex(rowIndex, 20).setNumber(u.insulinDurationYears);
      sheet.getRangeByIndex(rowIndex, 21).setNumber(u.heartDiseaseDurationYears);
      sheet.getRangeByIndex(rowIndex, 22).setText(u.hasEdema ? 'Ya' : 'Tidak');
      sheet.getRangeByIndex(rowIndex, 23).setNumber(u.urinOutput);
      sheet.getRangeByIndex(rowIndex, 24).setText(u.activityLevel?.label ?? '-');
      sheet.getRangeByIndex(rowIndex, 25).setText(isFamily ? 'KELUARGA' : 'UTAMA');
      sheet.getRangeByIndex(rowIndex, 26).setText(primaryName);
      sheet.getRangeByIndex(rowIndex, 27).setText(DateFormat('yyyy-MM-dd HH:mm').format(u.createdAt));
      
      rowIndex++;
    }

    for (var i = 1; i <= headers.length; i++) { sheet.autoFitColumn(i); }

    final bytes = workbook.saveAsStream();
    workbook.dispose();

    final blob = html.Blob([Uint8List.fromList(bytes)], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'data_user_direka_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx')
      ..click();
    html.Url.revokeObjectUrl(url);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export Data User berhasil.')));
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
          // Quick Actions
          const Text(
            'Aksi Cepat',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.pushNamed(
                  context,
                  AppConstants.routeAdminFoodCatalog,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.table_chart_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kelola Katalog Makanan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tambah, edit, dan hapus database makanan (Firestore)',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Metrics
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Total User',
                  value: '$_totalUsers',
                  icon: Icons.group_rounded,
                  colors: const [Color(0xFF4776E6), Color(0xFF8E54E9)],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Food Logs',
                  value: '${_foodLogs.length}',
                  icon: Icons.restaurant_rounded,
                  colors: const [Color(0xFF00B4DB), Color(0xFF0083B0)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Health Records',
                  value: '${_healthRecords.length}',
                  icon: Icons.monitor_heart_rounded,
                  colors: const [Color(0xFFFF512F), Color(0xFFDD2476)],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Edukasi',
                  value: '${_educationPosts.length}',
                  icon: Icons.school_rounded,
                  colors: const [Color(0xFF11998E), Color(0xFF38EF7D)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Distribusi Penyakit Pengguna',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 4,
                            centerSpaceRadius: 40,
                            sections: DiseaseType.values.map((disease) {
                              final count = _usersByDisease[disease] ?? 0;
                              final percentage = _totalUsers > 0 ? (count / _totalUsers * 100) : 0.0;
                              
                              Color color;
                              switch (disease) {
                                case DiseaseType.chronicKidneyDisease: color = AppColors.kidneyColor; break;
                                case DiseaseType.type2DiabetesMellitus: color = AppColors.diabetesColor; break;
                                case DiseaseType.heartFailure: color = AppColors.heartColor; break;
                              }

                              return PieChartSectionData(
                                color: color,
                                value: count.toDouble(),
                                title: count > 0 ? '${percentage.toStringAsFixed(0)}%' : '',
                                radius: 50,
                                titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: DiseaseType.values.map((disease) {
                            final count = _usersByDisease[disease] ?? 0;
                            Color color;
                            switch (disease) {
                              case DiseaseType.chronicKidneyDisease: color = AppColors.kidneyColor; break;
                              case DiseaseType.type2DiabetesMellitus: color = AppColors.diabetesColor; break;
                              case DiseaseType.heartFailure: color = AppColors.heartColor; break;
                            }
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      DiseaseTypeExtension.getLabel(disease),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '$count',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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

    // Filter logic
    final filtered = _users.where((u) {
      final matchesSearch = u.name.toLowerCase().contains(_userSearchQuery.toLowerCase()) ||
          u.email.toLowerCase().contains(_userSearchQuery.toLowerCase());
      final matchesDisease = _userDiseaseFilter == null || u.diseaseType == _userDiseaseFilter;
      return matchesSearch && matchesDisease;
    }).toList();

    // Pagination logic
    final totalFiltered = filtered.length;
    final totalPages = (totalFiltered / _userPageSize).ceil();
    final startIdx = _userCurrentPage * _userPageSize;
    final endIdx = math.min(startIdx + _userPageSize, totalFiltered);
    final pageItems = totalFiltered > 0 ? filtered.sublist(startIdx, endIdx) : [];

    return RefreshIndicator(
      onRefresh: _loadUsersTab,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatsHeader(totalUsers: _totalUsers, usersByDisease: _usersByDisease),
          const SizedBox(height: 20),
          
          // Search & Filter Header
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Manajemen Pengguna',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _exportUsersToXlsx,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Export XLSX'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Cari nama atau email...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _userSearchQuery = val;
                _userCurrentPage = 0; // Reset ke page 1
              });
            },
          ),
          const SizedBox(height: 12),
          
          // Disease Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Semua'),
                  selected: _userDiseaseFilter == null,
                  onSelected: (val) => setState(() {
                    _userDiseaseFilter = null;
                    _userCurrentPage = 0;
                  }),
                ),
                const SizedBox(width: 8),
                ...DiseaseType.values.map((d) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(DiseaseTypeExtension.getLabel(d)),
                    selected: _userDiseaseFilter == d,
                    onSelected: (val) => setState(() {
                      _userDiseaseFilter = val ? d : null;
                      _userCurrentPage = 0;
                    }),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (totalFiltered == 0)
            const _EmptyView(message: 'Tidak ada pengguna yang sesuai kriteria.')
          else ...[
            Text(
              'Menampilkan \${startIdx + 1} - \$endIdx dari \$totalFiltered user',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            ...pageItems.map((user) {
              final isFamily = user.primaryUserUid != null;
              // Cari nama akun utama jika ini akun keluarga
              String? primaryName;
              if (isFamily) {
                try {
                  primaryName = _users.firstWhere((u) => u.uid == user.primaryUserUid).name;
                } catch (_) {
                  primaryName = 'Akun Utama';
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isFamily ? const Color(0xFFFFF9C4) : AppColors.surface, // Kuning untuk keluarga
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: isFamily ? Colors.orange.withValues(alpha: 0.3) : AppColors.divider.withValues(alpha: 0.5),
                    width: isFamily ? 1.5 : 1,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showUserDetailDialog(user),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: isFamily ? Colors.orange.withValues(alpha: 0.2) : AppColors.primaryLight,
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: isFamily ? Colors.orange.shade900 : AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        if (isFamily)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'KELUARGA',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.email),
                          const SizedBox(height: 2),
                          Text(
                            DiseaseTypeExtension.getLabel(user.diseaseType),
                            style: TextStyle(
                              color: isFamily ? Colors.orange.shade800 : AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          if (isFamily) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.link, size: 12, color: Colors.orange),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Tautan keluarga dari: $primaryName',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      DateFormat('dd MMM yyyy', 'id_ID').format(user.createdAt),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
            
            // Pagination Controls
            if (totalPages > 1) ...[
              const SizedBox(height: 20),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _userCurrentPage > 0
                          ? () => setState(() => _userCurrentPage--)
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Hal ${_userCurrentPage + 1} / $totalPages',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _userCurrentPage < totalPages - 1
                          ? () => setState(() => _userCurrentPage++)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ],
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Semua Log', style: TextStyle(fontWeight: FontWeight.w600)),
                selected: _foodFilterUid == 'all',
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                checkmarkColor: AppColors.primaryDark,
                onSelected: (_) => setState(() => _foodFilterUid = 'all'),
              ),
              ...filters.map(
                (item) => ChoiceChip(
                  label: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  selected: _foodFilterUid == item.uid,
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.primaryDark,
                  onSelected: (_) => setState(() => _foodFilterUid = item.uid),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (logs.isEmpty)
            const _EmptyView(message: 'Belum ada data food tracker.')
          else
            ...logs.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
                ),
                child: ExpansionTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.restaurant_rounded, color: AppColors.primaryDark),
                  ),
                  title: Text(item.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${item.userEmail}\n${DateFormat('dd MMM yyyy', 'id_ID').format(item.date)} • ${item.entryCount} entri',
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    if (item.entries.isEmpty)
                      const Text('Tidak ada entri log makanan.', style: TextStyle(color: AppColors.textHint))
                    else
                      ...item.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.circle, size: 6, color: AppColors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${(entry['foodName'] ?? '-')} (${(entry['grams'] ?? 0)} g)',
                                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                                ),
                              ),
                            ],
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
              (record) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.heartColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.monitor_heart_rounded, color: AppColors.heartColor),
                  ),
                  title: Text('${record.userName} • ${record.source}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${record.userEmail}\n${record.type} | ${_payloadPreview(record.payload)}',
                      style: const TextStyle(height: 1.4, fontSize: 13),
                    ),
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    DateFormat('dd MMM\nHH:mm', 'id_ID').format(record.date),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
              (post) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.school_rounded, color: AppColors.primaryDark),
                  ),
                  title: Text(post.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${post.content}\nOleh: ${post.createdBy}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(height: 1.4, fontSize: 13),
                    ),
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy', 'id_ID').format(post.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 20, color: AppColors.primary),
                        tooltip: 'Edit',
                        onPressed: () => _editEducation(post),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded, size: 20, color: AppColors.error),
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
  final List<Color> colors;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Pengguna Terdaftar',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '$totalUsers akun',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: DiseaseType.values.map((disease) {
              final count = usersByDisease[disease] ?? 0;
              Color badgeColor;
              switch (disease) {
                case DiseaseType.chronicKidneyDisease: badgeColor = AppColors.kidneyColor; break;
                case DiseaseType.type2DiabetesMellitus: badgeColor = AppColors.diabetesColor; break;
                case DiseaseType.heartFailure:
                  badgeColor = AppColors.heartColor;
                  break;
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${DiseaseTypeExtension.getLabel(disease)}: $count',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: badgeColor),
                    ),
                  ],
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
