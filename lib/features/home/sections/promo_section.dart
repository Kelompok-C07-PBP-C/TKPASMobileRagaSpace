part of 'package:tk2ragaspace/features/home/home_screen.dart';

mixin _HomePromoSection on _HomeScreenCore {
  static const List<_PromoCardData> _promoCards = [
    _PromoCardData(
      title: 'Cara Booking Kilat',
      description:
          'Cari lapangan sepak bola, futsal, basket, atau badminton favoritmu, pilih jadwal kosong, lalu konfirmasi pembayaran dalam hitungan detik.',
      bullets: [
        'Filter tipe olahraga, kota, harga, dan tipe permukaan rumput.',
        'Lihat slot realtime untuk sesi latihan, sparring, atau turnamen.',
        'Checkout aman—invoice otomatis dikirim ke tim dan pengelola.',
      ],
      gradient: [Color(0xFF4F46E5), Color(0xFF9337FF)],
      icon: Icons.flash_on_rounded,
    ),
    _PromoCardData(
      title: 'Raih Jam Latihan Terbaik',
      description:
          'Cari slot murah, atur jadwal tim, dan manfaatkan promo komunitas langsung dari aplikasi tanpa harus menghubungi admin venue.',
      bullets: [
        'Aktifkan notifikasi supaya dapat info slot kosong & promo flash.',
        'Pantau jadwal rutin tim dan langsung ajak pemain cadangan.',
        'Booking bareng komunitas lain untuk bagi biaya lapangan.',
      ],
      gradient: [Color(0xFF00C6FF), Color(0xFF0072FF)],
      icon: Icons.auto_graph_rounded,
    ),
  ];

  Widget _buildPromoSpotlight() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Mulai Lebih Pintar',
          'Panduan singkat & promo instan supaya operasionalmu makin lancar.',
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 650;
            final itemWidth = isWide
                ? (constraints.maxWidth - 20) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 20,
              runSpacing: 20,
              children: _promoCards
                  .map(
                    (data) => SizedBox(
                      width: itemWidth,
                      child: _PromoCard(data: data),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}