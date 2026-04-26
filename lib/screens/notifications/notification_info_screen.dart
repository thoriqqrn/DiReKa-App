import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/disease_type.dart';

class NotificationInfoScreen extends StatelessWidget {
  const NotificationInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Informasi Notifikasi'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDiseaseSection(
              title: 'Penyakit Ginjal Kronis (CKD)',
              color: AppColors.kidneyColor,
              notifications: [
                _NotifDetail(
                  'Asupan Cairan Tinggi',
                  'Memberitahu jika asupan cairan sudah mencapai zona kuning (50% dari target).',
                ),
                _NotifDetail(
                  'Batas Zat Gizi',
                  'Peringatan jika asupan Protein, Natrium, Kalium, atau Fosfor mendekati/melebihi batas harian.',
                ),
                _NotifDetail(
                  'Belum Ada Input',
                  'Pengingat harian jika Anda belum mencatat makanan atau data kesehatan.',
                ),
                _NotifDetail(
                  'Jadwal Hemodialisis',
                  'Pengingat H-1 sebelum jadwal cuci darah Anda.',
                ),
                _NotifDetail(
                  'Pantauan Keluarga',
                  'Notifikasi khusus ke akun keluarga jika kondisi kesehatan terpantau menurun.',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDiseaseSection(
              title: 'Diabetes Mellitus Tipe 2',
              color: AppColors.diabetesColor,
              notifications: [
                _NotifDetail(
                  'Beban Glikemik (GL) Tinggi',
                  'Peringatan jika menu makanan yang dicatat memiliki GL > 20.',
                ),
                _NotifDetail(
                  'Analisis Insulin',
                  'Pengingat bagi pengguna terapi insulin yang belum mencatat dosis hari ini.',
                ),
                _NotifDetail(
                  'Hasil Pemeriksaan',
                  'Peringatan jika hasil gula darah atau pemeriksaan lain di luar batas normal.',
                ),
                _NotifDetail(
                  'Belum Ada Input',
                  'Pengingat harian untuk mencatat aktivitas makan dan kesehatan.',
                ),
                _NotifDetail(
                  'Pantauan Keluarga',
                  'Mengirim sinyal waspada ke keluarga jika pola makan dan pemeriksaan tidak sinkron.',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDiseaseSection(
              title: 'Gagal Jantung (HF)',
              color: AppColors.heartColor,
              notifications: [
                _NotifDetail(
                  'Asupan Natrium',
                  'Peringatan jika konsumsi garam/natrium sudah mencapai 75% dari batas aman.',
                ),
                _NotifDetail(
                  'Tren Tekanan Darah',
                  'Memberitahu jika terdeteksi kenaikan tekanan darah dalam beberapa hari terakhir.',
                ),
                _NotifDetail(
                  'Gejala & Obat',
                  'Pengingat jika Anda belum mencatat keluhan gejala atau konsumsi obat harian.',
                ),
                _NotifDetail(
                  'Pemeriksaan Fisik',
                  'Peringatan jika hasil pemeriksaan fisik (seperti bengkak/sesak) memerlukan perhatian.',
                ),
                _NotifDetail(
                  'Pantauan Keluarga',
                  'Pesan otomatis ke keluarga jika tren kesehatan jantung menunjukkan penurunan.',
                ),
              ],
            ),
            const SizedBox(height: 40),
            const Center(
              child: Text(
                'Notifikasi dikirim secara otomatis oleh sistem\nberdasarkan data yang Anda masukkan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiseaseSection({
    required String title,
    required Color color,
    required List<_NotifDetail> notifications,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...notifications.map((n) => _buildNotifItem(n)),
      ],
    );
  }

  Widget _buildNotifItem(_NotifDetail n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 6, color: AppColors.textHint),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  n.message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
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

class _NotifDetail {
  final String title;
  final String message;
  const _NotifDetail(this.title, this.message);
}
