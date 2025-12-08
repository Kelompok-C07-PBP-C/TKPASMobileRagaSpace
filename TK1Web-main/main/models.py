from django.db import models

class Venue(models.Model):
    kategori = models.CharField(max_length=100)  # contoh: "Padel", "Futsal", dll
    nama_lapangan = models.CharField(max_length=200)
    kota = models.CharField(max_length=100)
    lokasi = models.TextField(blank=True, null=True)
    rentang_harga = models.CharField(max_length=100, blank=True, null=True)
    fasilitas = models.TextField(blank=True, null=True)
    image_address = models.TextField(blank=True, null=True)

    def __str__(self):
        return f"{self.nama_lapangan} ({self.kategori})"
    
    
