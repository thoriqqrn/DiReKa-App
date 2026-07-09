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

class AdminFoodTab extends StatefulWidget {
  final AdminService adminService;
  const AdminFoodTab({super.key, required this.adminService});

  @override
  State<AdminFoodTab> createState() => _AdminFoodTabState();
}

class _AdminFoodTabState extends State<AdminFoodTab> {
  bool _isLoading = false;
  String? _error;
  List<AdminFoodLogSummary> _foodLogs = [];
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
      final logs = await widget.adminService.getRecentFoodLogs(limit: 200);
      final users = await widget.adminService.getAllUsers();
      if (!mounted) return;
      setState(() { _foodLogs = logs; _users = users; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _exportXlsx({UserModel? targetUser}) async {
    final rows = targetUser == null ? _foodLogs : _foodLogs.where((l) => l.uid == targetUser.uid).toList();
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada data.')));
      return;
    }

    // Map uid → UserModel untuk hitung target nutrisi
    final userMap = { for (final u in _users) u.uid: u };

    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];

    // Header baris 1: grup
    sheet.getRangeByIndex(1, 1).setText('Nama');
    sheet.getRangeByIndex(1, 2).setText('Email');
    sheet.getRangeByIndex(1, 3).setText('Tgl');
    sheet.getRangeByIndex(1, 4).setText('Meal');
    sheet.getRangeByIndex(1, 5).setText('Makanan');
    sheet.getRangeByIndex(1, 6).setText('Gram');
    // Asupan per entry
    sheet.getRangeByIndex(1, 7).setText('Energi (kkal)');
    sheet.getRangeByIndex(1, 8).setText('Protein (g)');
    sheet.getRangeByIndex(1, 9).setText('Lemak (g)');
    sheet.getRangeByIndex(1, 10).setText('Karbohidrat (g)');
    // Total harian & persentase target
    sheet.getRangeByIndex(1, 11).setText('Total Energi (kkal)');
    sheet.getRangeByIndex(1, 12).setText('Target Energi (kkal)');
    sheet.getRangeByIndex(1, 13).setText('% Energi');
    sheet.getRangeByIndex(1, 14).setText('Total Protein (g)');
    sheet.getRangeByIndex(1, 15).setText('Target Protein (g)');
    sheet.getRangeByIndex(1, 16).setText('% Protein');
    sheet.getRangeByIndex(1, 17).setText('Total Lemak (g)');
    sheet.getRangeByIndex(1, 18).setText('Target Lemak (g)');
    sheet.getRangeByIndex(1, 19).setText('% Lemak');
    sheet.getRangeByIndex(1, 20).setText('Total Karbohidrat (g)');
    sheet.getRangeByIndex(1, 21).setText('Target Karbohidrat (g)');
    sheet.getRangeByIndex(1, 22).setText('% Karbohidrat');

    var rIdx = 2;
    for (final log in rows) {
      if (log.entries.isEmpty) continue;

      // Hitung total harian dari semua entry dalam log ini
      final totalEnergi = log.entries.fold(0.0, (s, e) => s + (e['energi'] ?? 0).toDouble());
      final totalProtein = log.entries.fold(0.0, (s, e) => s + (e['protein'] ?? 0).toDouble());
      final totalLemak = log.entries.fold(0.0, (s, e) => s + (e['lemak'] ?? 0).toDouble());
      final totalKarbo = log.entries.fold(0.0, (s, e) => s + (e['karbohidrat'] ?? 0).toDouble());

      // Target nutrisi dari profil user
      final needs = userMap[log.uid]?.nutritionNeeds;
      final tEnergi = needs?.energi ?? 0.0;
      final tProtein = needs?.protein ?? 0.0;
      final tLemak = needs?.lemak ?? 0.0;
      final tKarbo = needs?.karbohidrat ?? 0.0;

      // Persentase (0 jika target tidak diketahui)
      String pct(double actual, double target) =>
          target > 0 ? '${(actual / target * 100).toStringAsFixed(1)}%' : '-';

      for (var i = 0; i < log.entries.length; i++) {
        final e = log.entries[i];
        sheet.getRangeByIndex(rIdx, 1).setText(log.userName);
        sheet.getRangeByIndex(rIdx, 2).setText(log.userEmail);
        sheet.getRangeByIndex(rIdx, 3).setText(DateFormat('yyyy-MM-dd').format(log.date));
        sheet.getRangeByIndex(rIdx, 4).setText(e['mealType']?.toString() ?? '-');
        sheet.getRangeByIndex(rIdx, 5).setText(e['foodName']?.toString() ?? '-');
        sheet.getRangeByIndex(rIdx, 6).setNumber((e['grams'] ?? 0).toDouble());
        // Nutrisi per entry
        sheet.getRangeByIndex(rIdx, 7).setNumber((e['energi'] ?? 0).toDouble());
        sheet.getRangeByIndex(rIdx, 8).setNumber((e['protein'] ?? 0).toDouble());
        sheet.getRangeByIndex(rIdx, 9).setNumber((e['lemak'] ?? 0).toDouble());
        sheet.getRangeByIndex(rIdx, 10).setNumber((e['karbohidrat'] ?? 0).toDouble());
        // Total & persentase hanya di baris pertama entry setiap log (ringkasan hari)
        if (i == 0) {
          sheet.getRangeByIndex(rIdx, 11).setNumber(totalEnergi);
          if (tEnergi > 0) sheet.getRangeByIndex(rIdx, 12).setNumber(tEnergi);
          sheet.getRangeByIndex(rIdx, 13).setText(pct(totalEnergi, tEnergi));
          sheet.getRangeByIndex(rIdx, 14).setNumber(totalProtein);
          if (tProtein > 0) sheet.getRangeByIndex(rIdx, 15).setNumber(tProtein);
          sheet.getRangeByIndex(rIdx, 16).setText(pct(totalProtein, tProtein));
          sheet.getRangeByIndex(rIdx, 17).setNumber(totalLemak);
          if (tLemak > 0) sheet.getRangeByIndex(rIdx, 18).setNumber(tLemak);
          sheet.getRangeByIndex(rIdx, 19).setText(pct(totalLemak, tLemak));
          sheet.getRangeByIndex(rIdx, 20).setNumber(totalKarbo);
          if (tKarbo > 0) sheet.getRangeByIndex(rIdx, 21).setNumber(tKarbo);
          sheet.getRangeByIndex(rIdx, 22).setText(pct(totalKarbo, tKarbo));
        }
        rIdx++;
      }
    }

    final bytes = workbook.saveAsStream();
    workbook.dispose();
    final fName = 'food_log_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';

    if (kIsWeb) {
      final blob = html.Blob([Uint8List.fromList(bytes)], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)..setAttribute('download', fName)..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fName');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Export Food Log');
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
          final mSearch = u.name.toLowerCase().contains(q.toLowerCase()) || 
                          u.email.toLowerCase().contains(q.toLowerCase());
          final mDisease = dFilter == null || u.diseaseType == dFilter;
          return mSearch && mDisease;
        }).toList();

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Text('Pilih User Food Tracker', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    ChoiceChip(
                      label: const Text('Semua'),
                      selected: dFilter == null,
                      onSelected: (_) => setLocal(() => dFilter = null),
                    ),
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
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            child: Text(u.name[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(u.email, style: const TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                          onTap: () {
                            setState(() => _selectedUser = u);
                            Navigator.pop(context);
                          },
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
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.restaurant_menu_rounded, size: 48, color: AppColors.primary),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Manajer Food Tracker',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pantau dan export data asupan nutrisi harian seluruh pengguna aplikasi DiReKa.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            ElevatedButton.icon(
              onPressed: () => _exportXlsx(),
              icon: const Icon(Icons.cloud_download_rounded),
              label: const Text('Export SEMUA Data (XLSX)', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _showUserPicker,
              icon: const Icon(Icons.person_search_rounded),
              label: const Text('Pilih User Spesifik', style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    final userLogs = _foodLogs.where((l) => l.uid == _selectedUser!.uid).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card - Paling Aman (No Row Conflict)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.primary),
                      onPressed: () => setState(() => _selectedUser = null),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedUser!.name, 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(_selectedUser!.email, 
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
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
                      backgroundColor: AppColors.primary,
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
          
          const Text('Riwayat Log Makanan Rinci', 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          
          if (userLogs.isEmpty)
            const AdminEmptyView(message: 'Tidak ada riwayat makanan untuk user ini.')
          else
            ...userLogs.map((log) {
              // Hitung total harian untuk ringkasan di header tile
              double dayEnergi = 0;
              double dayProt = 0;
              double dayFat = 0;
              double dayCarb = 0;
              for (var e in log.entries) {
                dayEnergi += (e['energi'] ?? 0).toDouble();
                dayProt += (e['protein'] ?? 0).toDouble();
                dayFat += (e['lemak'] ?? 0).toDouble();
                dayCarb += (e['karbohidrat'] ?? 0).toDouble();
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                  title: Text(DateFormat('dd MMMM yyyy', 'id_ID').format(log.date), 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Total: ${dayEnergi.toInt()} kkal • ${log.entryCount} makanan', 
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    // Daily Summary Mini Table
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _miniStat('Protein', '${dayProt.toStringAsFixed(1)}g'),
                          _miniStat('Lemak', '${dayFat.toStringAsFixed(1)}g'),
                          _miniStat('Karbo', '${dayCarb.toStringAsFixed(1)}g'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Daftar Makanan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    ...log.entries.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(e['foodName'] ?? '-', 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                              Text('${e['energi']?.toInt() ?? 0} kkal', 
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Waktu: ${e['mealType'] ?? '-'} • Porsi: ${e['grams'] ?? 0}g', 
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _nutrientText('P: ${e['protein']?.toStringAsFixed(1)}g'),
                              _nutrientText('L: ${e['lemak']?.toStringAsFixed(1)}g'),
                              _nutrientText('K: ${e['karbohidrat']?.toStringAsFixed(1)}g'),
                              _nutrientText('Na: ${e['natrium']?.toStringAsFixed(0)}mg'),
                            ],
                          ),
                          if ((e['indeksGlikemik'] ?? 0) > 0) ...[
                            const SizedBox(height: 4),
                            Text('Indeks Glikemik: ${e['indeksGlikemik']}', 
                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                          ],
                        ],
                      ),
                    )),
                  ],
                ),
              );
            }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String val) => Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
    ],
  );

  Widget _nutrientText(String text) => Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500));
}
