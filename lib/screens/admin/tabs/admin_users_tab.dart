import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:universal_html/html.dart' as html;

import '../../../core/app_colors.dart';
import '../../../models/activity_level.dart';
import '../../../models/disease_type.dart';
import '../../../models/user_model.dart';
import '../../../services/admin_service.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminUsersTab extends StatefulWidget {
  final AdminService adminService;
  const AdminUsersTab({super.key, required this.adminService});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends State<AdminUsersTab> {
  bool _isLoading = false;
  String? _error;
  List<UserModel> _users = [];
  int _totalUsers = 0;
  Map<DiseaseType, int> _usersByDisease = {};

  // Search & Filter state
  String _searchQuery = '';
  DiseaseType? _diseaseFilter;
  int _currentPage = 0;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final total = await widget.adminService.getTotalUsers();
      final byDisease = await widget.adminService.getUsersByDisease();
      final users = await widget.adminService.getAllUsers();
      if (!mounted) return;
      setState(() {
        _totalUsers = total;
        _usersByDisease = byDisease;
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat data user: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _exportToXlsx() async {
    final filtered = _users.where((u) {
      final mSearch = u.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.email.toLowerCase().contains(_searchQuery.toLowerCase());
      final mDisease = _diseaseFilter == null || u.diseaseType == _diseaseFilter;
      return mSearch && mDisease;
    }).toList();

    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada data untuk diexport.')));
      return;
    }

    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'Daftar Pengguna';

    final headers = [
      'Nama', 'Email', 'Gender', 'Tgl Lahir', 'Usia',
      'Penyakit', 'BB (kg)', 'TB (cm)', 'IMT', 'Kategori IMT',
      'Lama Penyakit (thn)', 'Tipe Akun', 'Tgl Daftar'
    ];

    for (var i = 0; i < headers.length; i++) {
      sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
    }

    var rowIndex = 2;
    for (final u in filtered) {
      sheet.getRangeByIndex(rowIndex, 1).setText(u.name);
      sheet.getRangeByIndex(rowIndex, 2).setText(u.email);
      sheet.getRangeByIndex(rowIndex, 3).setText(u.gender);
      sheet.getRangeByIndex(rowIndex, 4).setText(DateFormat('yyyy-MM-dd').format(u.dateOfBirth));
      sheet.getRangeByIndex(rowIndex, 5).setText(u.ageString);
      sheet.getRangeByIndex(rowIndex, 6).setText(DiseaseTypeExtension.getLabel(u.diseaseType));
      sheet.getRangeByIndex(rowIndex, 7).setNumber(u.weight);
      sheet.getRangeByIndex(rowIndex, 8).setNumber(u.height);
      sheet.getRangeByIndex(rowIndex, 9).setNumber(double.parse(u.bmi.toStringAsFixed(2)));
      sheet.getRangeByIndex(rowIndex, 10).setText(u.bmiCategory);
      sheet.getRangeByIndex(rowIndex, 11).setNumber(u.diseaseType == DiseaseType.type2DiabetesMellitus ? u.diabetesDurationYears : u.heartDiseaseDurationYears);
      sheet.getRangeByIndex(rowIndex, 12).setText(u.primaryUserUid != null ? 'KELUARGA' : 'UTAMA');
      sheet.getRangeByIndex(rowIndex, 13).setText(DateFormat('yyyy-MM-dd HH:mm').format(u.createdAt));
      rowIndex++;
    }

    for (var i = 1; i <= headers.length; i++) { sheet.autoFitColumn(i); }
    final bytes = workbook.saveAsStream();
    workbook.dispose();

    if (kIsWeb) {
      final blob = html.Blob([Uint8List.fromList(bytes)], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)..setAttribute('download', 'data_user_direka.xlsx')..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/data_user_direka.xlsx');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Export Data Pengguna');
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Akun'),
        content: Text('Hapus akun "${user.name}"? Tindakan ini permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.adminService.deleteUserAccount(user.uid);
        _loadData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  void _showUserDetail(UserModel user) {
    final isFamily = user.primaryUserUid != null && user.primaryUserUid!.isNotEmpty;
    String primaryName = '-';
    if (isFamily) {
      try {
        primaryName = _users.firstWhere((u) => u.uid == user.primaryUserUid).name;
      } catch (_) {
        primaryName = 'Akun Utama';
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Profil Lengkap Pengguna'),
            backgroundColor: AppColors.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: AppColors.textPrimary),
              onPressed: () => Navigator.pop(ctx),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteUser(user);
                },
                tooltip: 'Hapus Akun',
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Profil
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: Text(
                          user.name[0].toUpperCase(),
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      Text(user.email, style: const TextStyle(color: AppColors.textSecondary)),
                      if (isFamily)
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'AKUN KELUARGA',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Data Biografi
                _buildDetailSection('Informasi Pribadi', [
                  _detailRow('Jenis Kelamin', user.gender),
                  _detailRow('Tanggal Lahir', DateFormat('dd MMMM yyyy', 'id_ID').format(user.dateOfBirth)),
                  _detailRow('Usia', user.ageString),
                  _detailRow('Pendidikan', user.education.isEmpty ? '-' : user.education),
                  _detailRow('Pekerjaan', user.occupation.isEmpty ? '-' : user.occupation),
                ]),

                // Alamat
                _buildDetailSection('Alamat Domisili', [
                  _detailRow('Desa/Kelurahan', user.addressVillage.isEmpty ? '-' : user.addressVillage),
                  _detailRow('Kecamatan', user.addressDistrict.isEmpty ? '-' : user.addressDistrict),
                  _detailRow('Kota/Kabupaten', user.addressCity.isEmpty ? '-' : user.addressCity),
                  _detailRow('Provinsi', user.addressProvince.isEmpty ? '-' : user.addressProvince),
                ]),

                // Data Klinis
                _buildDetailSection('Parameter Klinis & Gizi', [
                  _detailRow('Penyakit Utama', DiseaseTypeExtension.getLabel(user.diseaseType)),
                  _detailRow('Berat Badan', '${user.weight} kg'),
                  _detailRow('Tinggi Badan', '${user.height} cm'),
                  _detailRow('IMT', user.bmi.toStringAsFixed(2)),
                  _detailRow('Status Gizi', user.bmiCategory),
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
                    _detailRow('Riwayat Pembengkakan', user.hasEdema ? 'Ada' : 'Tidak Ada'),
                  ]),

                // Info Akun
                _buildDetailSection('Informasi Akun & Sistem', [
                  _detailRow('Tipe Akun', isFamily ? 'Keluarga' : 'Utama'),
                  if (isFamily) _detailRow('Tautan Dari', primaryName),
                  _detailRow('Terdaftar Sejak', DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(user.createdAt)),
                  _detailRow('Login Terakhir', user.lastLoginDate != null ? DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(user.lastLoginDate!) : '-'),
                  _detailRow('Streak Aktif', '${user.currentStreak} hari'),
                ]),
                const SizedBox(height: 40),
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
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            flex: 3,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return AdminErrorView(message: _error!, onRetry: _loadData);

    final filtered = _users.where((u) {
      final mSearch = u.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.email.toLowerCase().contains(_searchQuery.toLowerCase());
      final mDisease = _diseaseFilter == null || u.diseaseType == _diseaseFilter;
      return mSearch && mDisease;
    }).toList();

    final totalPages = (filtered.length / _pageSize).ceil();
    final pageItems = filtered.isEmpty ? <UserModel>[] : filtered.sublist(_currentPage * _pageSize, math.min((_currentPage + 1) * _pageSize, filtered.length));

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AdminStatsHeader(totalUsers: _totalUsers, usersByDisease: _usersByDisease),
          const SizedBox(height: 24),
          
          // Header Manajemen & Tombol Export Besar
          const Text(
            'Manajemen Pengguna',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _exportToXlsx,
              icon: const Icon(Icons.download_for_offline_outlined),
              label: const Text('Export Data User (XLSX)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Search & Filter
          TextField(
            decoration: InputDecoration(
              hintText: 'Cari nama atau email...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
            onChanged: (v) => setState(() { _searchQuery = v; _currentPage = 0; }),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Semua'),
                  selected: _diseaseFilter == null,
                  onSelected: (_) => setState(() { _diseaseFilter = null; _currentPage = 0; }),
                ),
                ...DiseaseType.values.map((d) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(DiseaseTypeExtension.getLabel(d)),
                    selected: _diseaseFilter == d,
                    onSelected: (v) => setState(() { _diseaseFilter = v ? d : null; _currentPage = 0; }),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Info Hasil Filter
          Text(
            'Menampilkan ${(_currentPage * _pageSize) + 1} - ${math.min((_currentPage + 1) * _pageSize, filtered.length)} dari ${filtered.length} user',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          ...pageItems.map((u) {
            final isFamily = u.primaryUserUid != null && u.primaryUserUid!.isNotEmpty;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isFamily ? const Color(0xFFFFF9C4) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                ],
                border: Border.all(
                  color: isFamily ? Colors.orange.withValues(alpha: 0.5) : AppColors.border,
                  width: isFamily ? 1.5 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showUserDetail(u),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: isFamily ? Colors.orange.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      u.name[0].toUpperCase(),
                      style: TextStyle(
                        color: isFamily ? Colors.orange.shade900 : AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                      if (isFamily)
                        const Text('KELUARGA', style: TextStyle(color: Colors.orange, fontSize: 8, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  subtitle: Text(
                    '${u.email}\n${DiseaseTypeExtension.getLabel(u.diseaseType)}',
                    style: const TextStyle(height: 1.4, fontSize: 13),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
                ),
              ),
            );
          }),
          if (totalPages > 1) 
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null),
                  Text('Hal ${_currentPage + 1} / $totalPages'),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
