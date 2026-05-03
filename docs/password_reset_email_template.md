# Template Email Reset Password DIREKA

Setel template ini di Firebase Console:
- `Authentication`
- `Templates`
- `Password reset`

Action URL / custom handler:
- `https://direka-app.web.app`

Continue URL yang dipakai app:
- `https://direka-app.web.app/login`

Saran subject:
- `Reset Kata Sandi Akun DIREKA`

Saran heading:
- `Atur Ulang Kata Sandi Anda`

Saran body:

```text
Kami menerima permintaan untuk mengatur ulang kata sandi akun DIREKA Anda.

Klik tombol di bawah untuk membuat kata sandi baru. Demi keamanan, tautan ini hanya berlaku dalam waktu terbatas dan tidak membagikan kata sandi Anda dalam bentuk teks biasa.

Jika Anda tidak merasa meminta reset password, Anda dapat mengabaikan email ini.
```

Saran label tombol:
- `Buat Password Baru`

Catatan:
- Tampilan HTML akhir email tetap diatur dari Firebase Console.
- Aplikasi Flutter sudah menyiapkan alur kirim email reset, validasi email, dan halaman penggantian password berbasis `oobCode`.
