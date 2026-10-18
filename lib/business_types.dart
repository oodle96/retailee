enum BusinessType {
  retail,
  food,
  laundry,
  shoeCleaning,
  beauty,
  repair,
  services,
  production,
  other,
}

const businessActivityLabels = {
  'resale': 'Jual barang',
  'services': 'Jual jasa',
};
const businessActivityDescriptions = {
  'resale': 'Jual produk dengan satuan masing-masing, seperti pcs atau pack.',
  'services': 'Kerjakan layanan untuk pelanggan, dengan bahan jika diperlukan.',
};

class BusinessTemplate {
  final String name, examples, unit, firstAction;
  final bool stockFirst, producesGoods;
  final List<String> stages, services, goals;
  const BusinessTemplate(
    this.name,
    this.examples,
    this.unit,
    this.firstAction, {
    this.stockFirst = false,
    this.producesGoods = false,
    this.stages = const ['Diterima', 'Diproses', 'Selesai'],
    this.services = const [],
    this.goals = const [
      'Untung lebih besar',
      'Catatan rapi & lengkap',
      'Pesanan selesai tepat waktu',
      'Pembayaran cepat lunas',
    ],
  });
}

const businessTemplates = <BusinessType, BusinessTemplate>{
  BusinessType.retail: BusinessTemplate(
    'Toko & Jual Barang',
    'Warung, toko online, pakaian, kosmetik',
    'pcs',
    'Catat stok barang',
    stockFirst: true,
    goals: [
      'Stok selalu tersedia',
      'Untung lebih besar',
      'Catatan rapi & lengkap',
    ],
  ),
  BusinessType.food: BusinessTemplate(
    'Makanan & Minuman',
    'Warung makan, kedai, minuman, katering',
    'porsi',
    'Siapkan menu & bahan',
    stockFirst: true,
    producesGoods: true,
    stages: ['Diterima', 'Disiapkan', 'Siap', 'Diserahkan'],
    services: ['Pesanan makanan', 'Katering'],
    goals: [
      'Untung lebih besar',
      'Kurangi bahan terbuang',
      'Pesanan selesai tepat waktu',
      'Catatan rapi & lengkap',
    ],
  ),
  BusinessType.laundry: BusinessTemplate(
    'Laundry',
    'Kiloan, satuan, setrika',
    'kg',
    'Buat layanan laundry',
    stages: [
      'Diterima',
      'Dicuci',
      'Dikeringkan / disetrika',
      'Siap diambil',
      'Diambil',
    ],
    services: ['Cuci & setrika', 'Cuci saja', 'Setrika saja'],
  ),
  BusinessType.shoeCleaning: BusinessTemplate(
    'Cuci Sepatu & Tas',
    'Sepatu, tas, perawatan barang',
    'pasang',
    'Buat layanan perawatan',
    stages: ['Diterima', 'Diperiksa', 'Dibersihkan', 'Siap diambil', 'Diambil'],
    services: ['Cuci sepatu', 'Deep cleaning', 'Cuci tas'],
  ),
  BusinessType.beauty: BusinessTemplate(
    'Salon & Barbershop',
    'Potong rambut, salon, kecantikan',
    'layanan',
    'Buat daftar layanan',
    stages: ['Dijadwalkan', 'Dilayani', 'Selesai'],
    services: ['Potong rambut', 'Perawatan rambut', 'Perawatan kecantikan'],
  ),
  BusinessType.repair: BusinessTemplate(
    'Bengkel & Servis',
    'Motor, ponsel, elektronik, peralatan',
    'pekerjaan',
    'Buat layanan servis',
    stages: [
      'Diterima',
      'Diagnosis',
      'Menunggu persetujuan',
      'Dikerjakan',
      'Siap diambil',
      'Diambil',
    ],
    services: ['Pemeriksaan', 'Jasa servis', 'Penggantian komponen'],
  ),
  BusinessType.services: BusinessTemplate(
    'Jasa Lainnya',
    'Cleaning, jahit, cetak, pekerjaan lepas',
    'pekerjaan',
    'Buat daftar jasa',
    stages: ['Diterima', 'Disepakati', 'Dikerjakan', 'Selesai'],
    services: ['Jasa utama'],
  ),
  BusinessType.production: BusinessTemplate(
    'Produksi Rumahan',
    'Camilan, kerajinan, pakaian',
    'pcs',
    'Catat bahan & resep produksi',
    stockFirst: true,
    producesGoods: true,
    stages: ['Diterima', 'Diproduksi', 'Siap', 'Diserahkan'],
    services: ['Pesanan khusus'],
    goals: [
      'Untung lebih besar',
      'Kurangi bahan terbuang',
      'Pesanan selesai tepat waktu',
      'Catatan rapi & lengkap',
    ],
  ),
  BusinessType.other: BusinessTemplate(
    'Lainnya',
    'Jelaskan usahamu agar arahan lebih sesuai',
    'unit',
    'Catat transaksi pertama',
    services: ['Produk atau jasa utama'],
  ),
};

BusinessType? parseBusinessType(Object? value) =>
    BusinessType.values.where((t) => t.name == value).firstOrNull;
