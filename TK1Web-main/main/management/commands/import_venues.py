from django.core.management.base import BaseCommand
from main.models import Venue
import pandas as pd
import os
import glob

class Command(BaseCommand):
    help = "Import semua dataset olahraga ke database"

    def handle(self, *args, **options):
        base_dir = os.path.join(os.path.dirname(__file__), '../../data')
        base_dir = os.path.abspath(base_dir)
        csv_files = glob.glob(os.path.join(base_dir, '*.csv'))

        for file_path in csv_files:
            kategori = os.path.basename(file_path).split('-')[1].split('(')[0].strip()
            self.stdout.write(f"📂 Mengimpor kategori: {kategori}")

            try:
                df = pd.read_csv(file_path, skiprows=2)  # skip 2 baris pertama, baru header asli

                df = df.rename(columns=lambda x: x.strip())
            except Exception as e:
                self.stdout.write(self.style.ERROR(f"Gagal baca {file_path}: {e}"))
                continue

            if 'Nama Lapangan' not in df.columns:
                self.stdout.write(self.style.WARNING(f"⚠️  File {file_path} tidak memiliki kolom 'Nama Lapangan', dilewati."))
                continue

            for _, row in df.iterrows():
                if pd.isna(row['Nama Lapangan']):
                    continue

                Venue.objects.create(
                    kategori=kategori,
                    nama_lapangan=row.get('Nama Lapangan', ''),
                    kota=row.get('Kota', ''),
                    lokasi=row.get('Lokasi ', '') or row.get('Lokasi', ''),
                    rentang_harga=row.get('Rentang Harga', ''),
                    fasilitas=row.get('Fasilitas', ''),
                    image_address=row.get('Image Address', ''),
                )

        self.stdout.write(self.style.SUCCESS('✅ Semua data CSV berhasil diimport ke database!'))
