# 🌐 RagaSpace

# Aplikasi Penyewaan Lapangan Olahraga

[![Build Status](https://app.bitrise.io/app/8494dc3d-c505-42f0-8cc8-5f317362e2dd/status.svg?token=8l3C6fh7DiaWRYezq6kBIw&branch=main)](https://app.bitrise.io/app/8494dc3d-c505-42f0-8cc8-5f317362e2dd)

## 🔗 Download Link:
https://app.bitrise.io/app/8494dc3d-c505-42f0-8cc8-5f317362e2dd/installable-artifacts/83f6c87d02ff9f1b/public-install-page/28514b763be4390a1312a832286ec85e

## Anggota Kelompok :

1. Tirta Rendy Siahaan (2406355621)
2. Rindu Aurellia Zahra (2406439002)
3. Shafa Aurelia Permata Basuki (2406432236)
4. Bilqis Nisrina Dzahabiyah Mulyadi (2406432141)
5. Raden Pandji Mohammad Dimaz Bagus Hayyii Dausti Surya (2406439343)
6. Haekal Alexander Dinova (2406352424)

---

## Deskripsi Aplikasi

RagaSpace Mobile adalah platform penyewaan lapangan olahraga yang menghubungkan penyewa (user) dengan pemilik tempat (admin). 
Aplikasi ini memudahkan pengguna untuk mencari, membandingkan, dan menyewa berbagai jenis lapangan olahraga di kota-kota besar di Indonesia.

## Fitur Utama

* Pencarian lapangan berdasarkan kategori olahraga dan lokasi
* Filter dan sortir berdasarkan harga
* Sistem like dan wishlist
* Integrasi pembayaran digital
* Pengelolaan venue untuk admin (jadwal, fasilitas, aturan)

## Kebermanfaatan:

* Mempermudah masyarakat untuk menemukan dan menyewa lapangan olahraga.
* Membantu pemilik lapangan dalam memasarkan fasilitas olahraga mereka secara online.
* Meningkatkan aksesibilitas olahraga di kota besar maupun daerah.

## Kategori Lapangan

Aplikasi menyediakan 100+ lapangan di 10 kota besar Indonesia dengan kategori:

* Padel
* Tennis
* Futsal
* Volly Ball
* Badminton
* Basket
* Billiard
* Sepak Bola
* Mini Soccer
* Tenis Meja

---

## Role Pengguna

1. User (Penyewa)

* Melihat daftar lapangan berdasarkan kategori & lokasi
* Menyewa lapangan dan melakukan pembayaran
* Memberikan like pada lapangan favorit
* Mengelola wishlist pribadi
* Mengatur profil dan pengaturan akun


2. Admin (Pemilik Tempat)

* Menambahkan atau menghapus data lapangan
* Mengatur deskripsi, fasilitas, dan aturan venue
* Menentukan jadwal ketersediaan lapangan
* Mengelola informasi harga dan lokasi

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

## Screenshot

* Home Screen
<!-- ![Home Screen](screenshots/home.png) -->
Screenshot akan ditambahkan

* Katalog Lapangan
<!-- ![Katalog](screenshots/katalog.png) -->
Screenshot akan ditambahkan

* Detail & Booking
<!-- ![Detail](screenshots/detail.png) -->
Screenshot akan ditambahkan

* Wishlist
<!-- ![Wishlist](screenshots/wishlist.png) -->
Screenshot akan ditambahkan

* Account Setting
<!-- ![Setting](screenshots/setting.png) -->
Screenshot akan ditambahkan


## Desain

*Link Design (Figma/Prototype)*: https://www.figma.com/design/jXh9W3tagXfWVRxPSbpGmP/DESIGN-MOBILE?m=auto&t=bbgBl0vK2AYZvu3Z-1 (view only)

---

## Alur Integrasi dengan Web Service

<img width="645" height="364" alt="image" src="https://github.com/user-attachments/assets/14da48a5-527d-44a9-92ac-a36395417dd9" />


Langkah-langkah Integrasi Aplikasi dengan Website :

1. Menambahkan Dependensi HTTP
   Menambahkan package http dan pbp_django_auth pada pubspec.yaml untuk mendukung komunikasi dengan web service Django.
   
2. Membuat Wrapper Class untuk HTTP Request
   Membuat wrapper class menggunakan library pbp_django_auth yang memanfaatkan mekanisme cookie-based authentication.
   Class ini menangani session management dan menyimpan cookies secara otomatis.

3. Mengimplementasikan REST API di Django
   Mengembangkan endpoint API pada Django melalui views.py dengan menggunakan JsonResponse atau Django JSON Serializer untuk memastikan data dikirim dalam format JSON yang konsisten.
   a. Konfigurasi CORS dan Cookies di settings.py
   b. Membuat endpoint API di views.py
   c. Routing di urls.py

4. Membuat Model Dart dari JSON
   Mengkonversi response JSON dari Django menjadi object Dart menggunakan model class dengan factory constructor.

5. Mengembangkan Desain Front-End
   Mengimplementasikan tampilan antarmuka aplikasi berdasarkan desain Figma dengan memastikan keselarasan UI/UX antara versi web dan mobile.
   Komponen utama:
   * Screens: Halaman-halaman utama aplikasi (Home, Katalog, Detail, dll.)
   * Widgets: Komponen reusable (Card, Button, Form Fields, dll.)
   * Themes: Konsistensi warna, typography, dan styling

6. Integrasi Front-End dan Back-End secara Asinkron
   Menghubungkan front-end dengan API back-end menggunakan konsep asynchronous HTTP request dengan Future, async, dan await agar komunikasi data lebih efisien dan responsif.
   * Implementasi dengan FutureBuilder
   * State Management dengan Provider

## Ringkasan API

Method             Endpoint            Fungsi                  Modul
POST/              auth/login/         Login user              Autentikasi
POST/              auth/register/      Register user baru      Autentikasi
POST/              auth/logout/        Logout user             Autentikasi
GET/               json/               Ambil semua venue       Katalog
GET/               json/<id>/          Ambil detail venue      Product Detail
POST/              create-flutter/     Tambah venue baru       Admin
POST/              booking/create/     Buat booking            Booking
GET/               wishlist/json/      Ambil wishlist user     Wishlist
POST/              wishlist/add/       Tambah ke wishlist      Wishlist
POST/              account/update/     Update profil user      Account Setting
  
___

## Catatan
Username admin: dinova
Password admin: dinova132

---

## Video Promosi Platform RagaSpace
https://youtu.be/t9Z0Ka4zslo?si=mtui485qQYaGMeE9

---

## Lisensi
Proyek ini dikembangkan untuk keperluan Tugas Akhir Mata Kuliah Pemrograman Berbasis Platform (PBP) - Fakultas Ilmu Komputer, Universitas Indonesia, Semester Ganjil 2024/2025.
