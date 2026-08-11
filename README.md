# BudgetAI — Aplikasi Manajemen Keuangan Pribadi

Aplikasi Flutter untuk perencanaan alokasi budget (berbasis persentase) dan
pencatatan transaksi (pemasukan/pengeluaran), dengan sinkronisasi ke Google Drive.

> ⚠️ **Status: versi pengembangan (WIP)**. Beberapa fitur sudah rilis, sebagian
> lain masih dalam perbaikan — lihat bagian [Yang Perlu Diperbaiki](#yang-perlu-diperbaiki).

---

## Fitur yang Sudah Rilis

### UI & Desain
- **Tampilan ala Duolingo** di seluruh layar (Beranda, Riwayat, Ringkasan, Pengaturan)
  — font Nunito, hijau `#58CC02`, tombol 3D, kartu rounded.
- **Layar login** dengan hero gradient hijau→putih dan kartu sign-in.
- **Navigasi bawah** (NavigationBar) dengan 4 tab utama.

### Alokasi & Kategori
- Alokasi budget berbasis **persentase** per kategori (default: Tabungan 50%,
  Investasi 30%, Bebas 20%).
- **Validasi total ≤ 100%**: tidak bisa menyimpan kategori jika total melebihi
  100%; ada hint real-time sisa persentase saat mengetik.
- **Edit & hapus kategori** dari layar Pengaturan (termasuk edit persentase).
- **Reset kategori** ke default, dan **Reset semua data** (kategori + riwayat).

### Transaksi
- Pencatatan **pemasukan** dan **pengeluaran**.
- **Opsi pembebanan pos**: bisa dibebankan ke "Semua Pos" (default, bagi rata
  sesuai persentase) atau ke satu kategori tertentu — berlaku untuk pemasukan
  dan pengeluaran.
- **Edit & hapus transaksi** di layar Riwayat (bottom-sheet dengan opsi edit/hapus
  + ubah pembebanan pos).

### Autentikasi
- **Masuk dengan Google** (Google Sign-In). SHA-1 untuk debug & release sudah
  terdaftar di Firebase Console.
- **Mode offline**: bisa pakai aplikasi tanpa login (data tersimpan lokal via
  SharedPreferences).

### Stabilitas
- Perbaikan **layar hitam permanen** saat startup: inisialisasi Firebase dibuat
  idempoten (tangani error `duplicate-app`) dan semua error inisialisasi/
  build widget ditangkap menjadi **layar merah berisi pesan error** (bukan layar
  hitam). Crash log juga ditulis ke `/sdcard/Download/hyperbudget_crash.log`.

---

## Yang Perlu Diperbaiki

Berikut daftar masalah yang diketahui berdasarkan pengujian terakhir (belum beres):

1. **Sinkronisasi Google Drive tidak berjalan** walau sudah login dengan Google.
   - Gejala: login sukses, tapi data tidak tersinkron antar device/install ulang.
   - Kemungkinan penyebab: token akses Drive (`drive.file` scope) sering gagal
     diambil secara diam-diam, sehingga `authenticatedClient` bernilai `null` dan
     semua panggilan sync membatal diri tanpa error yang terlihat.
   - Tindakan: periksa scope OAuth, pastikan silent sign-in mengembalikan token,
     dan tambahkan indikator status sync yang jelas di UI.

2. **Tidak ada opsi login email/password** di layar login.
   - UI hanya menyediakan "Masuk dengan Google" dan "Lewati (offline)".
   - Method `signInWithEmail`/`registerWithEmail` ada di `auth_service.dart`
     tetapi belum dihubungkan ke antarmuka.

3. **Reset data tidak menghapus file di Google Drive.**
   - `resetAllData()` membersihkan lokal, tetapi file `data.json` di Drive tetap
     ada, sehingga sinkronisasi berikutnya bisa menimpa kembali data lokal.

4. **Indikator status sinkronisasi belum informatif.**
   - `hasUnsyncedChanges` / `lastSyncTime` ada, tapi UI belum menampilkan
     status "tersinkron / belum tersinkron / error" secara jelas.

5. **Build warning minor**: Flutter mengingatkan Kotlin version (2.1.0) akan
   segera tidak didukung — sebaiknya di-upgrade ke ≥ 2.2.20.

---

## Cara Build & Jalankan

```bash
flutter pub get
flutter build apk --release
# APK hasil: build/app/outputs/flutter-apk/app-release.apk
```

Prasyarat:
- Flutter SDK (cek `flutter doctor`).
- `android/app/google-services.json` dan `lib/firebase_options.dart` sudah
  disiapkan untuk project Firebase masing-masing (tidak disertakan di repo
  publik jika berisi konfigurasi khusus).

---

## Struktur Singkat

```
lib/
  main.dart                 # entry point + inisialisasi Firebase + error screen
  services/
    auth_service.dart       # Google Sign-In + email (belum di-UI)
    drive_service.dart      # sinkronisasi Google Drive
  repositories/
    budget_repository.dart  # state kategori & riwayat (+ trigger sync)
  screens/                  # login, home, history, summary, settings, auth_wrapper
  widgets/                  # duolingo_button, duolingo_card, edit_category_dialog
  utils/app_colors.dart     # palet warna
```

---

## Catatan Pengembangan

- Lihat `README-sync-issue.md` (jika ada) untuk catatan debug terkait sinkronisasi.
- Setiap error fatal saat startup akan ditulis ke
  `/sdcard/Download/hyperbudget_crash.log` di device — berguna untuk pelaporan bug.
