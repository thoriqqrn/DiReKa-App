# DiReKa App 🏥

**DiReKa** (Diet & Rekam Kesehatan) adalah aplikasi mobile berbasis Flutter yang dirancang untuk membantu penderita penyakit kronis dalam memantau dan mengelola kesehatan mereka secara personal.

---

## 📱 Fitur Saat Ini

### Autentikasi
- Login & registrasi dengan Email/Password
- Login dengan Google (OAuth)
- Mode tamu — bisa menjelajahi fitur tanpa akun
- Alur lengkapi profil untuk user Google baru

### Manajemen Pengguna
- Pilihan kondisi penyakit saat mendaftar (tidak dapat diubah setelah daftar)
- Edit profil: nama, tanggal lahir, berat & tinggi badan
- Kalkulasi BMI otomatis

### Penyakit yang Didukung
| Penyakit | Emoji |
|---|---|
| Penyakit Ginjal Kronis | 🫘 |
| Diabetes Mellitus Tipe 2 | 🩸 |
| Jantung Koroner | 🫀 |

### Panel Admin
- Login admin hardcoded (`admin@direka.app`)
- Dashboard statistik: total pengguna & jumlah per jenis penyakit
- Daftar semua pengguna terdaftar (nama, email, penyakit, tanggal daftar)
- Halaman pengaturan admin (informasi app, fitur mendatang)

### Fitur Mendatang 🔜
- Pelacak makanan harian
- Pelacak kesehatan (tekanan darah, gula darah, dll.)
- Konten edukasi kesehatan
- Export data pengguna (CSV) oleh admin
- Notifikasi & broadcast dari admin

---

## 🛠️ Teknologi

| Kategori | Teknologi |
|---|---|
| Framework | Flutter |
| Backend | Firebase (Auth + Firestore) |
| State Management | Provider |
| Autentikasi Google | google_sign_in |

---

## 📁 Struktur Proyek

```
lib/
├── main.dart
├── core/           # Tema, warna, konstanta global
├── models/         # UserModel, DiseaseType
├── providers/      # AuthProvider, DiseaseProvider
├── services/       # AuthService, UserService, AdminService
├── widgets/        # Komponen UI reusable
└── screens/
    ├── admin/      # Dashboard & pengaturan admin
    ├── auth/       # Login, register, pilih penyakit
    ├── home/       # Halaman utama & navigasi
    ├── profile/    # Pengaturan & edit profil
    └── tracker/    # Pelacak makanan, kesehatan, edukasi
```

---

## 🚀 Cara Menjalankan

### Prasyarat
- Flutter SDK ≥ 3.9.2
- Android Studio / VS Code
- Akun Firebase

### Setup
1. Clone repositori:
   ```bash
   git clone https://github.com/suhenyu1904/DiReKa-App.git
   cd DiReKa-App
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Tambahkan file `google-services.json` ke `android/app/` (dari Firebase Console)

4. Jalankan aplikasi:
   ```bash
   flutter run
   ```

---

## 🔐 Akun Admin

> ⚠️ Hanya untuk keperluan pengembangan. Jangan gunakan di produksi.

| Field | Value |
|---|---|
| Email | `admin@direka.app` |
| Password | `admin123` |

---

## 📄 Lisensi

Proyek ini dibuat untuk keperluan akademik / pengembangan pribadi.
