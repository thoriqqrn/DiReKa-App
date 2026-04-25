import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:universal_html/html.dart' as html;

import '../../../core/app_colors.dart';
import '../../../models/disease_type.dart';
import '../../../models/user_model.dart';
import '../../../services/admin_service.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminHealthTab extends StatefulWidget {
  final AdminService adminService;
  const AdminHealthTab({super.key, required this.adminService});

  @override
  State<AdminHealthTab> createState() => _AdminHealthTabState();
}

class _AdminHealthTabState extends State<AdminHealthTab> {
  bool _isLoading = false;
  String? _error;
  List<AdminHealthRecordSummary> _allRecords = [];
  List<UserModel> _users = [];
  UserModel? _selectedUser;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final records = await widget.adminService.getRecentHealthRecords(maxUsers: 150);
      final users = await widget.adminService.getAllUsers();
      if (!mounted) return;
      setState(() {
        _allRecords = records;
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _exportXlsx({UserModel? targetUser}) async {
    final rows = targetUser == null 
        ? _allRecords 
        : _allRecords.where((r) => r.uid == targetUser.uid).toList();

    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada data health tracker.')));
      return;
    }

    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'Health Tracker';

    final headers = ['Nama User', 'Email', 'Tanggal', 'Jam', 'Kategori', 'Detail Data', 'Sumber'];
    for (var i = 0; i < headers.length; i++) {
      sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
    }

    var rIdx = 2;
    for (final r in rows) {
      sheet.getRangeByIndex(rIdx, 1).setText(r.userName);
      sheet.getRangeByIndex(rIdx, 2).setText(r.userEmail);
      sheet.getRangeByIndex(rIdx, 3).setText(DateFormat('yyyy-MM-dd').format(r.date));
      sheet.getRangeByIndex(rIdx, 4).setText(DateFormat('HH:mm').format(r.date));
      sheet.getRangeByIndex(rIdx, 5).setText(r.type);
      
      // Flatten payload to string
      final details = r.payload.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      sheet.getRangeByIndex(rIdx, 6).setText(details);
      sheet.getRangeByIndex(rIdx, 7).setText(r.source);
      rIdx++;
    }

    for (var i = 1; i <= headers.length; i++) { sheet.autoFitColumn(i); }
    final bytes = workbook.saveAsStream();
    workbook.dispose();

    final fName = targetUser == null 
        ? 'semua_health_tracker_direka_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx'
        : 'health_tracker_${targetUser.name.replaceAll(' ', '_')}.xlsx';

    if (kIsWeb) {
      final blob = html.Blob([Uint8List.fromList(bytes)], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)..setAttribute('download', fName)..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fName');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Export Health Tracker DiReKa');
    }
  }

  void _showUserPicker() {
    String q = '';
    DiseaseType? dFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        final filtered = _users.where((u) {
          final mSearch = u.name.toLowerCase().contains(q.toLowerCase()) || u.email.toLowerCase().contains(q.toLowerCase());
          final mDisease = dFilter == null || u.diseaseType == dFilter;
          return mSearch && mDisease;
        }).toList();

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Text('Pilih User Health Tracker', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Cari nama atau email...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onChanged: (v) => setLocal(() => q = v),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(label: const Text('Semua'), selected: dFilter == null, onSelected: (_) => setLocal(() => dFilter = null)),
                    ...DiseaseType.values.map((d) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(DiseaseTypeExtension.getLabel(d)),
                        selected: dFilter == d,
                        onSelected: (v) => setLocal(() => dFilter = v ? d : null),
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filtered.isEmpty 
                  ? const Center(child: Text('User tidak ditemukan'))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final u = filtered[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            child: Text(u.name[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(u.email),
                          onTap: () { setState(() => _selectedUser = u); Navigator.pop(context); },
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return AdminErrorView(message: _error!, onRetry: _loadData);

    if (_selectedUser == null) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.monitor_heart_rounded, size: 48, color: Colors.red),
                  ),
                  const SizedBox(height: 24),
                  const Text('Health Tracker Manager', 
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text(
                    'Pantau seluruh riwayat kesehatan harian pengguna termasuk berat badan, gejala, obat, dan hasil pemeriksaan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _exportXlsx(),
                  icon: const Icon(Icons.cloud_download_rounded, size: 20),
                  label: const Text('Export SEMUA Data Health Tracker (XLSX)', 
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showUserPicker,
                  icon: const Icon(Icons.person_search_rounded, size: 20),
                  label: const Text('Pilih User Spesifik', 
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final userRecords = _allRecords.where((r) => r.uid == _selectedUser!.uid).toList();
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.red), onPressed: () => setState(() => _selectedUser = null)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedUser!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(_selectedUser!.email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _exportXlsx(targetUser: _selectedUser),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Export Data User Ini (XLSX)', 
                      style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Riwayat Kesehatan Rinci', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          if (userRecords.isEmpty)
            const AdminEmptyView(message: 'Tidak ada riwayat health tracker untuk user ini.')
          else
            ...userRecords.map((r) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16), 
                side: const BorderSide(color: AppColors.border),
              ),
              child: ExpansionTile(
                leading: _getIconForType(r.type),
                title: Text(r.type.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                subtitle: Text(DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(r.date), style: const TextStyle(fontSize: 11)),
                childrenPadding: const EdgeInsets.all(16),
                children: [
                  const Divider(),
                  ...r.payload.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${e.key}: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary)),
                        Expanded(child: Text('${e.value}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  )),
                ],
              ),
            )),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _getIconForType(String type) {
    IconData icon; Color color;
    switch (type.toLowerCase()) {
      case 'berat_badan': icon = Icons.monitor_weight_rounded; color = Colors.blue; break;
      case 'gejala': icon = Icons.warning_amber_rounded; color = Colors.orange; break;
      case 'obat': icon = Icons.medication_rounded; color = Colors.purple; break;
      case 'pemeriksaan': icon = Icons.analytics_rounded; color = Colors.teal; break;
      case 'aktivitas': icon = Icons.directions_run_rounded; color = Colors.green; break;
      case 'insulin': icon = Icons.colorize_rounded; color = Colors.pink; break;
      default: icon = Icons.health_and_safety_rounded; color = Colors.red;
    }
    return Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20));
  }
}
