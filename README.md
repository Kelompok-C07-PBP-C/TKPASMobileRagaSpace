# RagaSpace
[![Build Status](https://app.bitrise.io/app/8494dc3d-c505-42f0-8cc8-5f317362e2dd/status.svg?token=8l3C6fh7DiaWRYezq6kBIw&branch=main&workflow=deploy&v=20251220)](https://app.bitrise.io/app/8494dc3d-c505-42f0-8cc8-5f317362e2dd)


## Download
Download our latest version of RagaSpace! [Download _RagaSpace_ APK](https://app.bitrise.io/app/8494dc3d-c505-42f0-8cc8-5f317362e2dd/installable-artifacts/af1304a58e0452a4/public-install-page/d05d7eb2b7daccc63c885ebdf9f8b049)

# Aplikasi Penyewaan Lapangan Olahraga

## Anggota Kelompok :

1. Tirta Rendy Siahaan (2406355621)
2. Rindu Aurellia Zahra (2406439002)
3. Shafa Aurelia Permata Basuki (2406432236)
4. Bilqis Nisrina Dzahabiyah Mulyadi (2406432141)
5. Raden Pandji Mohammad Dimaz Bagus Hayyii Dausti Surya (2406439343)
6. Haekal Alexander Dinova (2406352424)

---

## Deskripsi Aplikasi

Aplikasi mobile ini merupakan platform penyewaan lapangan olahraga yang menghubungkan penyewa (user) dengan pemilik tempat (admin).
Melalui aplikasi mobile ini, pengguna dapat dengan mudah mencari, membandingkan, dan menyewa berbagai jenis lapangan olahraga di kota-kota besar di Indonesia.

Fitur utama aplikasi mobile ini mencakup pencarian **berdasarkan kategori olahraga, filter harga, like dan review, serta integrasi dengan pembayaran digital**.
Bagi pemilik lapangan, aplikasi ini memudahkan pengelolaan data venue, fasilitas, jadwal ketersediaan, serta aturan yang berlaku.

## Kebermanfaatan:

* Mempermudah masyarakat untuk menemukan dan menyewa lapangan olahraga.
* Membantu pemilik lapangan dalam memasarkan fasilitas olahraga mereka secara online.
* Meningkatkan aksesibilitas olahraga di kota besar maupun daerah.

---

## Daftar Modul yang Akan Diimplementasikan

1. Modul Admin by Alexander Haekal Dinova

   * Tambah dan hapus data lapangan
   * Tambah fasilitas, deskripsi, aturan venue, lokasi
   * Tambah jadwal ketersediaan
   * Menyimpan list venue, kategori, kota, dan daftar jadwal
   * Membuat Home Screen

2. Modul Autentifikasi by Tirta Rendy Siahaan

   * Login, Register (Gmail)
   * Validasi email unik
   * State loading/error
   * Simpan token/session

3. Modul Katalog Lapangan (User) by Shafa Aurelia

   * Lihat daftar lapangan berdasarkan kota dan kategori
   * Filter berdasarkan harga
   * Sortir berdasarkan harga

4. Modul Booking dan Product Detail (User) by RPM Dimaz

   * Pemesanan lapangan
   * Pembayaran

5. Modul Wishlist (User) by Rindu Aurellia Zahra

   * Like lapangan
   * Page wishlist user
     
6. Modul Account Setting by Bilqis Nisrina Dzahabiyah Mulyadi
   * Edit username, email, phone number, dan password
   * Page Setting
   * Integrasi dengan autentifikasi

---

## Sumber Initial Dataset
https://docs.google.com/spreadsheets/d/1V5WDI6bk9W4e-xLFGekK7lzSh3USWyDNecmrQcqFUrw/edit?gid=0#gid=0 

Dataset awal berisi sekitar 100 entri lapangan olahraga di *10 kota besar di Indonesia*.
Kategori utama produk (lapangan) mencakup:

* Padel
* Tennis
* Badminton
* Basket
* Sepak Bola
* Mini Soccer
* Futsal
* Billiard
* Tenis Meja
* Volly Ball

Setiap data mencakup:

* Nama lapangan
* Kota/lokasi
* Kategori olahraga
* Rentang harga
* Fasilitas tambahan

---

## Role atau Peran Pengguna

1. User (Penyewa / Menyewa)

   * Melihat daftar lapangan berdasarkan kategori & lokasi
   * Menyewa lapangan
   * Melakukan pembayaran
   * Memberikan like & review
   * Menyewa alat olahraga tambahan

2. Pemilik Tempat (Admin)

   * Menambahkan atau menghapus data lapangan
   * Mengatur deskripsi, fasilitas, aturan venue, lokasi
   * Menentukan jadwal ketersediaan lapangan
   * Mengelola informasi harga

---

## Desain

*Link Design (Figma/Prototype)*: https://www.figma.com/design/jXh9W3tagXfWVRxPSbpGmP/DESIGN-MOBILE?m=auto&t=bbgBl0vK2AYZvu3Z-1 (view only)

---






Langkah-langkah Integrasi Aplikasi dengan Website :

Membangun Wrapper Class untuk HTTP Request
Membuat sebuah wrapper class yang memanfaatkan library HTTP dan MAP guna mendukung mekanisme cookie-based authentication pada aplikasi.

Mengimplementasikan REST API di Django
Mengembangkan endpoint API pada Django melalui views.py dengan menggunakan JsonResponse atau Django JSON Serializer untuk memastikan data dikirim dalam format JSON yang konsisten.

Mengembangkan Desain Front-End
Mengimplementasikan tampilan antarmuka aplikasi berdasarkan desain website yang telah ada, sehingga memastikan keselarasan UI/UX.

Integrasi Front-End dan Back-End secara Asinkron
Menghubungkan front-end dengan API back-end menggunakan konsep asynchronous HTTP request agar komunikasi data lebih efisien dan responsif.
