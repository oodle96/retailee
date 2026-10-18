import 'package:flutter/material.dart';
import 'additional_english.dart';

String appTr(BuildContext context, String text) {
  if (Localizations.localeOf(context).languageCode != 'en') return text;
  final exact = _english[text];
  if (exact != null) return exact;
  for (final separator in ['\n', ' · ']) {
    if (text.contains(separator)) {
      return text
          .split(separator)
          .map((part) => appTr(context, part))
          .join(separator);
    }
  }
  if (text.startsWith('Bad state: ')) return appTr(context, text.substring(11));
  for (final entry in _patterns) {
    final match = entry.$1.firstMatch(text);
    if (match != null) return entry.$2(match);
  }
  final colon = text.indexOf(': ');
  if (colon > 0) {
    final label = text.substring(0, colon);
    final value = text.substring(colon + 2);
    final translatedLabel = appTr(context, label);
    if (translatedLabel != label) {
      return '$translatedLabel: ${appTr(context, value)}';
    }
  }
  return text;
}

class LocalText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool? softWrap;
  const LocalText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.softWrap,
  });
  @override
  Widget build(BuildContext context) => Text(
    appTr(context, data),
    style: style,
    textAlign: textAlign,
    overflow: overflow,
    maxLines: maxLines,
    softWrap: softWrap,
  );
}

final _patterns = <(RegExp, String Function(RegExpMatch))>[
  (RegExp(r'^Tahap (\d+) dari (\d+)$'), (m) => 'Stage ${m[1]} of ${m[2]}'),
  (RegExp(r'^(\d+) pesanan aktif$'), (m) => '${m[1]} active orders'),
  (RegExp(r'^(\d+) lewat tenggat$'), (m) => '${m[1]} overdue'),
  (RegExp(r'^Penjualan (.+) tercatat$'), (m) => 'Sales recorded for ${m[1]}'),
  (
    RegExp(r'^Harga modal (.+) dilengkapi$'),
    (m) => 'Purchase cost completed for ${m[1]}',
  ),
  (
    RegExp(r'^(.+): produk baru, stok (.+)$'),
    (m) => '${m[1]}: new product, stock ${m[2]}',
  ),
  (
    RegExp(r'^(.+) \(stok (.+) → (.+)\)$'),
    (m) => '${m[1]} (stock ${m[2]} → ${m[3]})',
  ),
  (RegExp(r'^Bad state: (.+)$'), (m) => _english[m[1]] ?? m[1]!),
  (RegExp(r'^Total penjualan (.+)$'), (m) => 'Total sales ${m[1]}'),
  (RegExp(r'^Nominal (Rp.*)$'), (m) => 'Amount ${m[1]}'),
  (RegExp(r'^(\d+) produk$'), (m) => '${m[1]} products'),
  (
    RegExp(r'^(\d+) hal menghalangi konfirmasi$'),
    (m) => '${m[1]} issues prevent confirmation',
  ),
  (RegExp(r'^Tampilkan semua (\d+) baris$'), (m) => 'Show all ${m[1]} rows'),
  (
    RegExp(
      r'^(\d+) baris kurang jelas ditandai kuning\. Cek dan perbaiki sebelum konfirmasi\.$',
    ),
    (m) =>
        '${m[1]} unclear rows are highlighted in yellow. Review and correct them before confirming.',
  ),
  (RegExp(r'^Kurang jelas (.+)%$'), (m) => 'Unclear ${m[1]}%'),
  (RegExp(r'^Tertulis: (.+)$'), (m) => 'Written: ${m[1]}'),
  (RegExp(r'^\s+stok (.+)$'), (m) => ' stock ${m[1]}'),
  (
    RegExp(r'^Cocok dengan produk "(.+)" — stok akan ditambah$'),
    (m) => 'Matches product "${m[1]}"; stock will be added',
  ),
  (
    RegExp(r'^Harga di catatan berbeda dari harga jual tersimpan \((.+)\)\.$'),
    (m) => 'The recorded price differs from the saved selling price (${m[1]}).',
  ),
  (RegExp(r'^\+(.+) XP terverifikasi$'), (m) => '+${m[1]} verified XP'),
  (RegExp(r'^≥ (.+) \(belum lengkap\)$'), (m) => '≥ ${m[1]} (incomplete)'),
  (RegExp(r'^Jual (Rp.*)$'), (m) => 'Sell ${m[1]}'),
  (RegExp(r'^[Mm]odal (Rp.*|\?)$'), (m) => 'Cost ${m[1]}'),
  (RegExp(r'^terjual (.+) dlm 7 hari$'), (m) => '${m[1]} sold in 7 days'),
  (
    RegExp(r'^Harga modal (.+) tersimpan$'),
    (m) => 'Purchase cost saved for ${m[1]}',
  ),
  (RegExp(r'^Harga modal (.+)$'), (m) => 'Purchase cost: ${m[1]}'),
  (RegExp(r'^Stok (.+) \+(.+)$'), (m) => 'Stock ${m[1]} +${m[2]}'),
  (RegExp(r'^Dibayar (.+)$'), (m) => 'Paid ${m[1]}'),
  (RegExp(r'^Sisa (.+)$'), (m) => 'Outstanding ${m[1]}'),
  (RegExp(r'^Rugi (.+)$'), (m) => 'Loss ${m[1]}'),
  (RegExp(r'^Hasil (.+)$'), (m) => 'Output ${m[1]}'),
  (RegExp(r'^biaya (.+)$'), (m) => 'cost ${_english[m[1]] ?? m[1]}'),
  (RegExp(r'^Catat (.+) terbuang$'), (m) => 'Record waste: ${m[1]}'),
  (RegExp(r'^Tahap (\d+) dari 3$'), (m) => 'Stage ${m[1]} of 3'),
  (
    RegExp(r'^Masukan untuk saran \((\d+)\)$'),
    (m) => 'Advice feedback (${m[1]})',
  ),
  (RegExp(r'^Terakhir diperbarui (.+)$'), (m) => 'Last updated ${m[1]}'),
  (
    RegExp(
      r'^Pendapatan (.+) akan dicatat sekali\. Bahan yang dipilih dipotong dari stok; pembayaran tetap dicatat terpisah\.$',
    ),
    (m) =>
        'Revenue of ${m[1]} will be recorded once. Selected materials will be deducted from stock; payments remain separate.',
  ),
  (RegExp(r'^Semua \((\d+)\)$'), (m) => 'All (${m[1]})'),
  (RegExp(r'^Menipis \((\d+)\)$'), (m) => 'Low stock (${m[1]})'),
  (RegExp(r'^Modal kosong \((\d+)\)$'), (m) => 'Missing cost (${m[1]})'),
  (
    RegExp(r'^(\d+)% dari target terverifikasi$'),
    (m) => '${m[1]}% of verified target',
  ),
  (RegExp(r'^Level (\d+) · Pemula$'), (m) => 'Level ${m[1]} · Beginner'),
  (
    RegExp(r'^(\d+) XP lagi ke level (\d+)$'),
    (m) => '${m[1]} XP to level ${m[2]}',
  ),
  (RegExp(r'^(\d+) hari streak$'), (m) => '${m[1]} day streak'),
  (RegExp(r'^(\d+) hari tercatat$'), (m) => '${m[1]} days recorded'),
  (
    RegExp(r'^Penjualan (\d+) hari terakhir$'),
    (m) => 'Sales over the last ${m[1]} days',
  ),
  (RegExp(r'^(\d+) produk · nilai $'), (m) => '${m[1]} products · value '),
  (RegExp(r'^Periode: (.+)$'), (m) => 'Period: ${m[1]}'),
  (
    RegExp(r'^(\d+) layanan tersedia$'),
    (m) => m[1] == '1' ? '1 service available' : '${m[1]} services available',
  ),
  (RegExp(r'^Jumlah \((.+)\)$'), (m) => 'Quantity (${m[1]})'),
  (RegExp(r'^Stok sebenarnya \((.+)\)$'), (m) => 'Actual stock (${m[1]})'),
  (
    RegExp(r'^(\d+) penjualan / pekerjaan selesai$'),
    (m) => '${m[1]} sales / completed jobs',
  ),
  (
    RegExp(r'^Setelah biaya usaha (.+)$'),
    (m) => 'After operating expenses of ${m[1]}',
  ),
  (
    RegExp(r'^(\d+) melewati jadwal / tenggat$'),
    (m) => '${m[1]} past their scheduled time / deadline',
  ),
  (
    RegExp(r'^Periksa (\d+) baris bertanda$'),
    (m) => 'Review ${m[1]} flagged rows',
  ),
  (RegExp(r'^Periksa semua (\d+) baris$'), (m) => 'Review all ${m[1]} rows'),
  (RegExp(r'^Tujuan: (.+)$'), (m) => 'Goal: ${_english[m[1]] ?? m[1]}'),
  (RegExp(r'^Sisa tagihan (.+)$'), (m) => 'Outstanding balance ${m[1]}'),
  (RegExp(r'^Hari ini · (.+)$'), (m) => 'Today · ${m[1]}'),
  (RegExp(r'^Misalnya (.+)$'), (m) => 'For example: ${_english[m[1]] ?? m[1]}'),
  (RegExp(r'^Langkah (\d+) dari (\d+)$'), (m) => 'Step ${m[1]} of ${m[2]}'),
  (RegExp(r'^(\d+) draf belum selesai$'), (m) => '${m[1]} unfinished drafts'),
  (RegExp(r'^Lanjut: (.+)$'), (m) => 'Next: ${_english[m[1]] ?? m[1]}'),
  (
    RegExp(r'^Jumlah \((.+)\); desimal pakai koma$'),
    (m) => 'Quantity (${m[1]}); use a comma for decimals',
  ),
];

const _english = <String, String>{
  'Ringkas': 'Show less',
  'Baca selengkapnya': 'Read more',
  'Memuat...': 'Loading...',
  'Foto → Periksa → Jurnal → Saran': 'Photo → Review → Journal → Advice',
  'Belum ada barang terbuang tercatat.': 'No waste recorded yet.',
  'Belum ada produksi tercatat.': 'No production recorded yet.',
  'Biaya tambahan': 'Additional cost',
  'Buat resep': 'Create recipe',
  'Detail pengeluaran': 'Expense details',
  'Tanggal & jenis catatan': 'Date & entry type',
  'Stok awal & pengingat': 'Opening stock & reminders',
  'Harga & modal': 'Price & cost',
  'Detail produk / bahan': 'Product / material details',
  'Gunakan tombol Tambah layanan untuk menambah nama, satuan dan harga. Kamu yang menentukan layanan yang dijual.':
      'Use Add service to enter a name, unit and price. You choose which services to sell.',
  'Lihat semua layanan': 'View all services',
  'Coba nama lain atau hapus pencarian untuk melihat semua layanan.':
      'Try another name or clear the search to see all services.',
  'Layanan tidak ditemukan': 'No services found',
  'Cari layanan': 'Search services',
  'Contoh: 1,5': 'Example: 1.5',
  'Biaya & bahan': 'Costs & materials',
  'Tenggat pekerjaan': 'Job deadline',
  'Jadwal & staf': 'Schedule & staff',
  'Pelanggan & layanan': 'Customer & service',
  'Isi detail utama, lalu tambahkan kebutuhan pekerjaan.':
      'Start with the essentials, then add job details.',
  'Siapkan pesananmu': 'Set up your order',
  'Staf': 'Staff',
  'Total pesanan': 'Order total',
  'Sudah dibayar': 'Paid so far',
  'Sisa pembayaran': 'Outstanding payment',
  'Rincian pekerjaan': 'Job details',
  'Foto barang': 'Item photo',
  'Bahan yang digunakan': 'Materials used',
  'Tindakan lainnya': 'Other actions',
  'Sisa tagihan': 'Outstanding balance',
  'Tentang pesanan': 'About orders',
  'Sisa tagihan mencakup pesanan yang belum lunas, termasuk yang telah selesai. Pesanan dibatalkan tidak dihitung.':
      'Outstanding balances include unpaid orders, including completed work. Cancelled orders are excluded.',
  'Tidak ada pesanan aktif': 'No active orders',
  'Pesanan selesai atau dibatalkan bisa dilihat di riwayat.':
      'Completed and cancelled orders are available in history.',
  'Tenggat lewat': 'Overdue',
  'Lunas': 'Paid',
  'Hapus pencarian': 'Clear search',
  'Tentang stok': 'About stock',
  'Nilai stok memakai harga modal yang diketahui. Produk tanpa harga modal belum dihitung.':
      'Stock value uses known costs. Products without a cost are not included yet.',
  'Ubah tujuan usaha': 'Change business goal',
  'Masukan untuk saran': 'Advice feedback',
  'Langsung ke inti saran.': 'Get straight to the advice.',
  'Lebih banyak penjelasan.': 'More explanation and detail.',
  'Kegiatan': 'Activities',
  'Profil': 'Profile',
  'Tujuan': 'Goal',
  'Tentang profil usaha': 'About your business profile',
  'Pilih kegiatan yang kamu jalankan.': 'Choose the activities you run.',
  'Isi informasi yang dikenal pelangganmu.':
      'Add the details your customers know.',
  'Pilih satu tujuan dan gaya penjelasan.':
      'Choose one goal and an explanation style.',
  'Pemilik & lokasi (opsional)': 'Owner & location (optional)',
  'Usahamu': 'Your business',
  'Kegiatan usaha': 'Business activities',
  'Preferensi': 'Preferences',
  'Data & akun': 'Data & account',
  'Data lokal akan diganti dengan cadangan cloud.':
      'Local data will be replaced with the cloud backup.',
  ...additionalEnglish,
  'Catat manual': 'Manual entry',
  'Catatan stok & harga modal di buku':
      'Stock quantities and purchase costs in your notebook',
  'Catatan penjualan harian tulisan tangan': 'Handwritten daily sales records',
  'Nota listrik, transport, belanja, dll.':
      'Receipts for electricity, transport, supplies, and other expenses',
  'Pendapatan': 'Revenue',
  'Tercatat': 'Recorded',
  'Saran dari jurnal ini': 'Advice from your journal',
  'Jurnal': 'Journal',
  'Foto': 'Photo',
  'Jurnal usahamu': 'Your business journal',
  'Periksa draf, buka foto asal, dan lihat catatan yang sudah dikonfirmasi.':
      'Review drafts, open original photos, and see confirmed records.',
  'Semua catatan': 'All records',
  'Tidak ada draf yang perlu diperiksa.': 'No drafts need review.',
  'Jurnal dimulai dari foto catatan pertamamu.':
      'Your journal starts with a photo of your first record.',
  'Catatanmu jadi arahan usaha': 'Turn your records into business advice',
  'Foto catatan atau struk. Periksa hasilnya, simpan ke jurnal, lalu dapatkan saran untuk usahamu.':
      'Photograph notes or a receipt. Review the results, save them to your journal, and get advice for your business.',
  'Periksa sebelum masuk jurnal': 'Review before saving to your journal',
  'draf belum selesai': 'unfinished drafts',
  'Saran untuk usahamu': 'Advice for your business',
  'Lihat arahan': 'View advice',
  'Catatan kecil.\nLangkah besar.': 'Small records.\nBig steps.',
  'Sapa Retailee': 'Say hello to Retailee',
  'Kenali alurnya': 'Explore the steps',
  'Arahan': 'Advice',
  'Foto catatan atau struk yang ingin kamu simpan.':
      'Photograph the notes or receipt you want to keep.',
  'Periksa hasil bacaan AI. Kamu yang mengonfirmasi catatan.':
      'Review what AI reads. You confirm each record.',
  'Saran Gemini memakai catatan terkonfirmasi dan profil usahamu.':
      'Gemini advice uses confirmed records and your business profile.',
  'Aku bantu membaca. Kamu tetap yang memutuskan.':
      'I help read your notes. You stay in control.',
  'Langkah usahamu': 'Your progress',
  'Progres level': 'Level progress',
  'Tutup': 'Close',
  'Jurnal terbaru': 'Recent journal entries',
  'Catatanmu,\nrapi di sini.': 'Your records,\nall in one place.',
  'Buka jurnal': 'Open journal',
  'Ringkasan hari ini': 'Today’s summary',
  'Stok & alat usaha': 'Stock & business tools',
  'Belanja barang dagangan? Gunakan Restock di tab Stok atau Foto struk.':
      'Buying inventory? Use Restock in Inventory or photograph the receipt.',
  'Catat pengeluaran': 'Record expense',
  'Draf dibatalkan': 'Draft cancelled',
  'Draf ini tidak memengaruhi stok maupun laporan.':
      'This draft does not affect stock or reports.',
  'Foto yang jelas membantu. Kamu tetap memeriksa setiap hasilnya.':
      'A clear photo helps. You still review every result.',
  'Jumlah unit': 'Number of units',
  'Nominal': 'Amount',
  'Produk yang dibeli': 'Purchased product',
  'Toko / penerima (opsional)': 'Store / recipient (optional)',
  'Lanjutkan draf atau mulai dari catatan baru.\n\nHasil bacaan AI selalu jadi draf dulu. Tidak ada yang tercatat ke stok atau laporan sebelum kamu konfirmasi.':
      'Continue a draft or start a new record.\n\nAI results always start as drafts. Stock and reports change only after you confirm.',
  'Modal rata-rata dihitung ulang otomatis (rata-rata tertimbang).':
      'Average purchase cost is recalculated automatically using a weighted average.',
  'Laundry kiloan': 'Laundry by weight',
  'Laundry satuan': 'Laundry by item',
  'Setrika': 'Ironing',
  'Cuci sepatu': 'Shoe cleaning',
  'Cuci tas': 'Bag cleaning',
  'Potong rambut': 'Haircut',
  'Perawatan rambut': 'Hair treatment',
  'Perawatan kecantikan': 'Beauty treatment',
  'Pemeriksaan': 'Inspection',
  'Jasa servis': 'Repair service',
  'Penggantian komponen': 'Parts replacement',
  'Jasa utama': 'Main service',
  'Pesanan khusus': 'Custom orders',
  'Produk atau jasa utama': 'Main product or service',
  'Pesanan makanan': 'Food orders',
  'Katering': 'Catering',
  'Retailee, pendamping warungmu': 'Retailee, your business companion',
  'laundry kiloan': 'laundry by weight',
  'Pilih jenis usaha.': 'Choose a business type.',
  'Isi nama usaha dan satuan harga.':
      'Enter the business name and pricing unit.',
  'Pilih tujuan utama.': 'Choose your main goal.',
  'Wajib': 'Required',
  'Isi angka ≥ 0': 'Enter a number of 0 or more',
  'Periksa modal': 'Check the purchase cost',
  'Catat biaya umum. Biaya bahan/persediaan dan biaya langsung yang sudah masuk pesanan atau produksi jangan dihitung dua kali.':
      'Record overheads here. Do not count materials, inventory or direct costs already included in orders or production twice.',
  'Biaya langsung di luar bahan yang dipilih pada pesanan dan biaya umum yang dicatat terpisah. Kosong = belum diketahui; isi 0 hanya jika memang tidak ada.':
      'Direct cost excludes order materials and overheads recorded separately. Blank means unknown; enter 0 only if there is no cost.',
  'Saran hanya memakai data warung yang sudah kamu konfirmasi, pilihanmu, dan masukanmu. Tidak ada pelatihan model khusus, tidak menebak hal pribadi, dan tidak dibagikan ke usaha lain.':
      'Guidance uses confirmed business records, your preferences and feedback. It does not train a custom model, infer personal details or share your records with other businesses.',
  'Tujuan, gaya penjelasan, ejaan & masukan':
      'Goals, explanation style, spellings & feedback',
  'Jangan sampai barang laku kehabisan.': 'Keep popular products in stock.',
  'Tahu laba sebenarnya & jaga margin.':
      'Understand real profit and protect margins.',
  'Rutin mencatat supaya angka bisa dipercaya.':
      'Record regularly so your numbers are reliable.',
  'Camilan, kerajinan, pakaian': 'Snacks, crafts, clothing',
  'Jelaskan usahamu agar arahan lebih sesuai':
      'Describe your business for more relevant guidance',
  'Buat layanan perawatan': 'Set up cleaning services',
  'Buat daftar layanan': 'Create your service catalog',
  'Buat layanan servis': 'Set up repair services',
  'Buat daftar jasa': 'Create your service catalog',
  'Catat bahan & resep produksi': 'Add materials & production recipes',
  'Catat transaksi pertama': 'Record your first transaction',
  'Mulai dari produk dan bahan yang memang ada. Harga modal yang belum diketahui boleh dikosongkan.':
      'Start with the products and materials you have. Leave unknown purchase costs blank.',
  'Masukkan layanan, satuan harga dan biaya langsung jika sudah diketahui.':
      'Add your services, pricing units and direct costs if known.',
  'Catat 3 produk stok awal': 'Record 3 opening-stock products',
  'Foto catatan stok atau tambah manual.':
      'Photograph stock records or add them manually.',
  'Konfirmasi penjualan pertama': 'Confirm your first sale',
  'Catat manual atau foto, cek lalu konfirmasi.':
      'Enter manually or photograph, review and confirm.',
  'Catat penjualan hari ini': 'Record today’s sales',
  'Satu catatan penjualan terkonfirmasi untuk hari ini.':
      'One confirmed sales record for today.',
  'Lengkapi semua harga modal': 'Complete all purchase costs',
  'Agar laba bisa dihitung akurat.': 'So profit can be calculated accurately.',
  'Catat 1 biaya usaha hari ini': 'Record 1 business expense today',
  'Listrik, transport, plastik, dll.':
      'Electricity, transport, packaging and more.',
  'Buka pesanan': 'Open orders',
  'Catat pesanan': 'Record an order',
  'Buka produksi': 'Open production',
  'Buka produk': 'Open products',
  'Kerjakan misi': 'Start mission',
  'misi selesai': 'missions completed',
  'hari tercatat': 'days recorded',
  'hari streak': 'day streak',
  'Diperiksa': 'Inspected',
  'Dibersihkan': 'Cleaned',
  'Siap diambil': 'Ready for collection',
  'Diambil': 'Collected',
  'Dilayani': 'Being served',
  'Menunggu persetujuan': 'Awaiting approval',
  'Dikerjakan': 'Work in progress',
  'Disepakati': 'Agreed',
  'Diproduksi': 'In production',
  'Siap': 'Ready',
  'Diserahkan': 'Delivered',
  'Ada produk terjual tanpa harga modal. Lengkapi di tab Stok agar laba bisa dihitung pasti.':
      'Some sold products have no purchase cost. Complete them in Inventory to calculate profit accurately.',
  'Bagaimana laba dihitung?': 'How is profit calculated?',
  'Baris lain tetap ikut dalam total. Periksa semuanya sebelum konfirmasi.':
      'Other rows are still included in the total. Review everything before confirming.',
  'Batalkan draf': 'Cancel draft',
  'Belum ada pengeluaran di periode ini.': 'No expenses in this period yet.',
  'Belum ada penjualan di periode ini.': 'No sales in this period yet.',
  'Biasanya selesai dalam 15 detik. Kamu bisa menutup layar ini — draf tersimpan otomatis.':
      'This usually takes about fifteen seconds. You can close this screen; your draft is saved automatically.',
  'Boleh kosong jika belum tahu.': 'Leave blank if unknown.',
  'Catat pengeluaran manual': 'Enter an expense manually',
  'Catat pengembalian uang muka': 'Record a deposit refund',
  'Cek lagi': 'Review again',
  'Di luar bahan dan biaya umum. Kosong = belum diketahui; isi 0 jika memang tidak ada.':
      'Excludes materials and overheads. Blank means unknown; enter 0 only if there is no cost.',
  'Dokumen tidak ditemukan': 'Document not found',
  'Ejaan yang dikenali, masukan saran, dan misi yang dilewati akan dihapus. Tujuan, gaya penjelasan, dan data usahamu tetap.':
      'Recognized spellings, suggestion feedback and skipped missions will be cleared. Your goal, explanation style and business records are kept.',
  'Format pratinjau belum didukung.': 'This preview format is not supported.',
  'Foto asli sedang dimuat atau belum tersedia.':
      'The original photo is loading or is unavailable.',
  'Foto belum tersedia. Coba lagi': 'Photo unavailable. Try again',
  'Foto catatan stok': 'Photograph stock records',
  'Harga pelanggan di atas harus sudah mencakup tagihan bahan. Stok bahan dipotong saat pesanan selesai.':
      'The customer price above must include materials. Material stock is deducted when the order is completed.',
  'Jadikan misi': 'Make this a mission',
  'Jenis pengeluaran': 'Expense type',
  'Kosong = biaya belum diketahui. Biaya bahan dipilih terpisah; biaya umum dicatat sebagai pengeluaran.':
      'Blank means the cost is unknown. Select materials separately; record overheads as expenses.',
  'Laba kotor = omzet − modal barang yang terjual. Margin = laba kotor ÷ omzet. Estimasi laba bersih = laba kotor − biaya usaha. Harga modal yang belum diisi membuat laba belum lengkap, bukan nol.':
      'Gross profit = revenue minus cost of goods sold. Margin = gross profit divided by revenue. Estimated net profit = gross profit minus operating expenses. Missing purchase costs make profit incomplete, not zero.',
  'Laba rugi sederhana': 'Simple profit & loss',
  'Lihat hitungan lengkap': 'View full calculation',
  'Mengapa saran ini?': 'Why this suggestion?',
  'Muat ulang foto': 'Reload photo',
  'Pastikan tulisan terlihat jelas & cahaya cukup.':
      'Make sure the writing is clear and well lit.',
  'Periksa sebelum mengonfirmasi ke pembukuan.':
      'Review before posting to the books.',
  'Pesanan belum menjadi pendapatan sampai kamu mengonfirmasi tahap terakhir. Uang muka dicatat melalui detail pesanan.':
      'An order becomes revenue only after you confirm the final stage. Record deposits in Order details.',
  'Pesanan tidak ditemukan.': 'Order not found.',
  'Pratinjau format foto tidak tersedia.':
      'No preview is available for this photo format.',
  'Pratinjau tidak tersedia.': 'Preview unavailable.',
  'Pribadi': 'Personal',
  'Produk tidak ditemukan': 'Product not found',
  'Profil belum ada': 'No profile yet',
  'Pulihkan cadangan cloud': 'Restore cloud backup',
  'Reset': 'Reset',
  'Ringkasan ini tidak mencakup transaksi satuan yang sudah dicatat hari itu':
      'This summary excludes individual transactions already recorded that day',
  'Saran AI — pastikan sudah benar.': 'AI suggestion — please verify it.',
  'Semua arahan disembunyikan berdasarkan masukanmu. Perbarui untuk arahan baru.':
      'All guidance is hidden based on your feedback. Refresh to get new guidance.',
  'Setelah dikonfirmasi, stok & laporan akan diperbarui.':
      'Stock and reports update after confirmation.',
  'Supaya laba bisa dihitung · +20 XP': 'Enable profit calculations · +20 XP',
  'Tagihan dan uang muka mencakup semua tanggal. Pendapatan di atas mengikuti periode penyelesaian pekerjaan, bukan waktu pembayaran.':
      'Balances and deposits cover all dates. Revenue above follows job completion dates, not payment dates.',
  'Tambahkan bahan di Stok & bahan jika diperlukan.':
      'Add materials in Stock & materials if needed.',
  'Belum ada produk': 'No products yet',
  'Foto catatan stok awal atau tambah produk satu per satu.':
      'Photograph opening stock records or add products individually.',
  'Coba nama lain atau pilih filter Semua.':
      'Try another name or choose the All filter.',
  'Catat stok barang': 'Record product stock',
  'Siapkan menu & bahan': 'Set up menus & ingredients',
  'Buat layanan laundry': 'Set up laundry services',
  'Catat produk & bahan': 'Add products & materials',
  'Buat layanan': 'Create a service',
  'Perlu diperiksa': 'Needs review',
  'Perbaiki tanda merah dulu': 'Fix the red fields first',
  'Stok menipis': 'Low stock',
  'Modal belum ada': 'Purchase cost missing',
  'Belum diketahui': 'Unknown',
  'belum diketahui': 'unknown',
  'Bahasa': 'Language',
  'Pilih bahasa': 'Choose your language',
  'Lanjut': 'Continue',
  'Kembali': 'Back',
  'Simpan': 'Save',
  'Batal': 'Cancel',
  'Menyimpan...': 'Saving...',
  'Simpan profil usaha': 'Save business profile',
  'Beranda': 'Home',
  'Usaha': 'Business',
  'Catat': 'Record',
  'Laporan': 'Reports',
  'Dari catatan yang sudah kamu konfirmasi.\n\nRingkasan mengikuti pilihan periode. Grafik menunjukkan pendapatan 7 atau 30 hari terakhir.':
      'From records you have confirmed.\n\nThe summary follows your selected period. The chart shows revenue over the last 7 or 30 days.',
  'Misi': 'Missions',
  'Tentang misi': 'About missions',
  'Aktif': 'Active',
  'Siap diklaim': 'Ready to claim',
  'Belum ada misi yang siap diklaim.': 'No missions are ready to claim yet.',
  'Belum ada misi yang sudah diklaim.': 'No missions have been claimed yet.',
  'Tidak ada misi aktif saat ini.': 'There are no active missions right now.',
  'Naik level!': 'Level up!',
  'Progres ini berasal dari catatan yang sudah terverifikasi.':
      'This progress comes from verified records.',
  'Lanjutkan': 'Continue',
  'Pengaturan usaha': 'Business settings',
  'Profil usaha': 'Business profile',
  'Profil & jenis usaha': 'Business profile & type',
  'Personalisasi & masukan': 'Personalization & feedback',
  'Jenis, satuan, tujuan, cara kerja': 'Type, units, goals and workflow',
  'Apa jenis usahamu?': 'What kind of business do you run?',
  'Kenalan dengan usahamu': 'Tell us about your business',
  'Apa yang ingin kamu rapikan?': 'What would you like to improve?',
  'Pilihanmu menyesuaikan alur pesanan, stok, laporan dan arahan Gemini.':
      'Your choice adapts orders, inventory, reports and Gemini guidance.',
  'Gunakan satuan yang biasa dipakai pelangganmu.':
      'Use the pricing units your customers know.',
  'Saran memakai tujuan, catatan terkonfirmasi dan masukanmu.':
      'Guidance uses your goals, confirmed records and feedback.',
  'Data usaha yang sudah ada tetap tersimpan.':
      'Your existing business records are kept.',
  'Tentang usahamu': 'About your business',
  'Cara kerja usaha': 'How your business works',
  'Nama usaha': 'Business name',
  'Nama pemilik': 'Owner name',
  'Kota': 'City',
  'Nama yang dikenal pelanggan': 'The name your customers know',
  'Kota tempat usahamu': 'Where your business is based',
  'Jenis usaha lebih spesifik': 'Business specialty',
  'Satuan harga': 'Pricing unit',
  'Kebutuhan usaha (opsional)': 'Business needs (optional)',
  'Ceritakan cara kerja atau yang ingin dibantu':
      'Describe your workflow or what you need help with',
  'Fokus utama': 'Your main focus',
  'Arahan Gemini': 'Gemini guidance',
  'Gaya penjelasan': 'Explanation style',
  'Singkat': 'Concise',
  'Detail': 'Detailed',
  'Gemini memberi saran, bukan mengubah pembukuan. Informasi bisa diperbarui melalui Profil usaha.':
      'Gemini provides guidance; it does not change your books. You can update these details in Business profile.',
  'Toko & Jual Barang': 'Retail & Reselling',
  'Makanan & Minuman': 'Food & Drinks',
  'Cuci Sepatu & Tas': 'Shoe & Bag Cleaning',
  'Salon & Barbershop': 'Salon & Barbershop',
  'Bengkel & Servis': 'Workshop & Repairs',
  'Jasa Lainnya': 'Other Services',
  'Produksi Rumahan': 'Home Production',
  'Lainnya': 'Other',
  'Warung, toko online, pakaian, kosmetik':
      'Small shops, online stores, clothing, cosmetics',
  'Warung makan, kedai, minuman, katering':
      'Food stalls, cafes, drinks, catering',
  'Kiloan, satuan, setrika': 'By weight, individual items, ironing',
  'Sepatu, tas, perawatan barang': 'Shoes, bags, item care',
  'Potong rambut, salon, kecantikan': 'Haircuts, salons, beauty services',
  'Motor, ponsel, elektronik, peralatan':
      'Motorcycles, phones, electronics, appliances',
  'Cleaning, jahit, cetak, pekerjaan lepas':
      'Cleaning, tailoring, printing, freelance work',
  'Stok selalu tersedia': 'Keep stock available',
  'Untung lebih besar': 'Improve profitability',
  'Catatan rapi & lengkap': 'Keep complete, clear records',
  'Pesanan selesai tepat waktu': 'Finish orders on time',
  'Pembayaran cepat lunas': 'Collect payments sooner',
  'Kurangi bahan terbuang': 'Reduce material waste',
  'Pendapatan bulan ini': 'Revenue this month',
  'Perkiraan untung bersih': 'Estimated net profit',
  'Belum lengkap': 'Incomplete',
  'Lengkapi biaya langsung, bahan atau harga modal':
      'Add direct costs, materials or purchase costs',
  'Mau catat apa?': 'What would you like to record?',
  'Penjualan': 'Sales',
  'Pesanan baru': 'New order',
  'Biaya usaha': 'Business expenses',
  'Stok & bahan': 'Stock & materials',
  'Daftar layanan': 'Service catalog',
  'Yang perlu dipantau': 'Keep an eye on',
  'Pesanan berjalan': 'Active orders',
  'Sisa tagihan pesanan': 'Outstanding order balances',
  'Uang muka dan pelunasan terpisah dari status kerja':
      'Deposits and payments are tracked separately from job status',
  'Produk / bahan menipis': 'Low-stock products / materials',
  'Periksa stok dan kebutuhan produksi': 'Check stock and production needs',
  'Arahan untuk usahamu': 'Guidance for your business',
  'Kebiasaan usaha': 'Business habits',
  'Lihat misi sesuai usahamu': 'View missions for your business',
  'Gemini memakai jenis usaha, tujuan, ringkasan catatan terkonfirmasi dan masukanmu. Nama serta foto pelanggan tidak dikirim untuk saran ini.':
      'Gemini uses your business type, goals, confirmed summaries and feedback. Customer names and photos are not sent for this guidance.',
  'Kamu sedang memakai demo lokal. Arahan Gemini tersedia pada aplikasi yang terhubung dengan Google. Catatan usaha tetap bisa dipakai di demo ini.':
      'You are using the local demo. Gemini guidance is available in the Google-connected app. You can still record business activity here.',
  'Belum ada arahan Gemini. Minta arahan awal atau mulai mencatat terlebih dahulu.':
      'No Gemini guidance yet. Request initial guidance or start recording first.',
  'Catatan / pilihanmu berubah. Perbarui arahan agar memakai konteks terbaru.':
      'Your records or preferences changed. Refresh guidance to use the latest context.',
  'Minta arahan Gemini': 'Ask Gemini for guidance',
  'Perbarui arahan Gemini': 'Refresh Gemini guidance',
  'Meminta arahan...': 'Requesting guidance...',
  'Buka catatan terkait': 'Open related records',
  'Berguna': 'Helpful',
  'Tidak sesuai': 'Not relevant',
  'Lihat & atur personalisasi': 'View & adjust personalization',
  'Kelola usaha': 'Manage your business',
  'Pesanan': 'Orders',
  'Layanan': 'Services',
  'Tampilkan riwayat': 'Show history',
  'Inspirasi layanan': 'Service ideas',
  'Buat daftar layananmu': 'Build your service catalog',
  'Gunakan tombol Layanan untuk menambah nama, satuan dan harga. Kamu yang menentukan layanan yang dijual.':
      'Use Services to add a name, pricing unit and price. You decide which services to offer.',
  'Pesanan pertama dimulai di sini': 'Your first order starts here',
  'Tambahkan layanan, lalu gunakan tombol Pesanan untuk mencatat pelanggan dan tenggatnya.':
      'Add a service, then use Orders to record the customer and deadline.',
  'Catat kegiatan usaha': 'Record business activity',
  'Penjualan barang / menu': 'Product / menu sales',
  'Isi manual, periksa lalu konfirmasi': 'Enter, review and confirm',
  'Foto catatan penjualan': 'Photograph sales records',
  'Foto stok barang / bahan': 'Photograph stock records',
  'Pesanan / layanan pelanggan': 'Customer orders / services',
  'Jadwal, pekerjaan, bahan dan pembayaran':
      'Schedules, jobs, materials and payments',
  'Foto struk biaya': 'Photograph an expense receipt',
  'Draf belum selesai': 'Unfinished drafts',
  'Catat biaya usaha': 'Record a business expense',
  'Keterangan': 'Description',
  'Nominal (Rp)': 'Amount (Rp)',
  'Kategori': 'Category',
  'Wajib diisi': 'Required',
  'Nama layanan': 'Service name',
  'Tambah layanan': 'Add service',
  'Ubah layanan': 'Edit service',
  'Harga per satuan (Rp)': 'Price per unit (Rp)',
  'Biaya langsung per satuan (opsional)': 'Direct cost per unit (optional)',
  'Nama / kode pelanggan': 'Customer name / reference',
  'Biaya langsung/unit di luar bahan (opsional)':
      'Direct cost per unit, excluding materials (optional)',
  'Barang / lingkup pekerjaan': 'Customer item / job scope',
  'Kondisi awal / diagnosis': 'Initial condition / diagnosis',
  'Treatment / pekerjaan yang disepakati': 'Agreed treatment / work',
  'Petugas (opsional)': 'Assigned staff (optional)',
  'Staf yang melayani': 'Assigned staff',
  'Durasi layanan (menit)': 'Service duration (minutes)',
  'Pilih jadwal layanan': 'Choose appointment time',
  'Pilih tenggat selesai': 'Choose a deadline',
  'Bahan / suku cadang yang akan digunakan': 'Materials / parts to use',
  'Pilih bahan (opsional)': 'Choose a material (optional)',
  'Jumlah bahan; contoh 0,25': 'Material quantity; e.g. 0,25',
  'Tambahkan bahan': 'Add material',
  'Detail pesanan': 'Order details',
  'Barang / lingkup': 'Customer item / scope',
  'Kondisi / diagnosis': 'Condition / diagnosis',
  'Pekerjaan disepakati': 'Agreed work',
  'Ubah detail / biaya / jadwal': 'Edit details / costs / schedule',
  'Persetujuan pelanggan sudah diterima': 'Customer approval received',
  'Catat pembayaran / uang muka': 'Record payment / deposit',
  'Catat pembayaran': 'Record payment',
  'Metode': 'Method',
  'Tunai': 'Cash',
  'Batalkan pesanan': 'Cancel order',
  'Riwayat pembayaran': 'Payment history',
  'Belum ada pembayaran tercatat.': 'No payments recorded yet.',
  'Diterima': 'Received',
  'Diproses': 'In progress',
  'Selesai': 'Completed',
  'Dijadwalkan': 'Scheduled',
  'Stok': 'Inventory',
  'Foto stok': 'Photograph stock',
  'Cari produk…': 'Search products…',
  'Produk / bahan': 'Product / material',
  'Tambah produk / bahan': 'Add product / material',
  'Nama produk': 'Product name',
  'Harga jual': 'Selling price',
  'Modal (opsional)': 'Purchase cost (optional)',
  'Stok awal': 'Opening stock',
  'Batas minimum': 'Minimum stock',
  'Satuan': 'Unit',
  'Bahan baku / habis pakai': 'Raw material / consumable',
  'Dipakai untuk pesanan atau produksi, tidak dijual langsung.':
      'Used in orders or production; not sold directly.',
  'Simpan produk / bahan': 'Save product / material',
  'Ubah produk': 'Edit product',
  'Nama': 'Name',
  'Restock': 'Restock',
  'Sesuaikan': 'Adjust',
  'Sesuaikan stok': 'Adjust stock',
  'Masukkan jumlah hasil hitung fisik di rak.':
      'Enter the quantity counted on the shelf.',
  'Modal per unit': 'Purchase cost per unit',
  'Stok saat ini': 'Current stock',
  'Riwayat pergerakan stok': 'Stock movement history',
  'Belum ada pergerakan.': 'No stock movements yet.',
  'Produksi': 'Production',
  'Produksi & bahan': 'Production & materials',
  'Produksi & barang terbuang': 'Production & waste',
  'Buat resep / daftar bahan': 'Create recipe / bill of materials',
  'Catat bahan / barang terbuang': 'Record material / product waste',
  'Resep / daftar bahan': 'Recipe / bill of materials',
  'Nama resep / produk': 'Recipe / product name',
  'Produk hasil': 'Output product',
  'Jumlah hasil per batch': 'Output quantity per batch',
  'Biaya langsung tambahan per batch (opsional)':
      'Additional direct cost per batch (optional)',
  'Bahan per batch': 'Materials per batch',
  'Simpan resep': 'Save recipe',
  'Riwayat produksi': 'Production history',
  'Barang terbuang': 'Waste',
  'Pilih barang terbuang': 'Choose a waste item',
  'Alasan': 'Reason',
  'Catat batch produksi': 'Record production batch',
  'Siapkan resep pertamamu': 'Create your first recipe',
  'Pilih produk hasil dan bahan yang dipakai. Catat batch setelah produksi selesai.':
      'Choose the output product and materials. Record each batch after production is complete.',
  'Catat produk hasil dan bahan baku di Stok & bahan. Buat resep, lalu konfirmasikan batch yang benar-benar diproduksi.':
      'Add output products and raw materials in Stock & materials. Create a recipe, then confirm the batches you actually produce.',
  'Dari catatan yang sudah kamu konfirmasi.':
      'Based on records you have confirmed.',
  'Ke mana hasil jualanmu?': 'Where does your revenue go?',
  'Total penjualan': 'Total sales',
  'Ambil pribadi dan belanja stok tidak masuk biaya usaha di bawah.':
      'Owner withdrawals and stock purchases are excluded from operating expenses below.',
  'Belum ada penjualan tercatat.': 'No sales recorded yet.',
  'Belum dicatat': 'Not recorded',
  'Belum ada penjualan di periode ini': 'No sales in this period yet',
  'Catat penjualan atau selesaikan pekerjaan. Pendapatan muncul setelah dikonfirmasi.':
      'Record a sale or finish a job. Revenue appears after confirmation.',
  'Produk / layanan penyumbang pendapatan':
      'Products / services contributing revenue',
  'Modal barang': 'Cost of goods',
  'Sisa untung': 'Remaining profit',
  'Biaya melebihi hasil penjualan.': 'Costs exceed revenue.',
  'Ketuk batang untuk melihat jumlah. Geser untuk hari lainnya. Batang pucat berarti belum ada catatan.':
      'Tap a bar to see its amount. Swipe to other days. Pale bars mean no record is available.',
  'Kebiasaan kecil untuk usaha yang lebih rapi. XP diberikan setelah misi terbukti dari catatan usahamu.':
      'Small habits for a better-organized business. XP is awarded when your records verify a mission.',
  'Sudah terbukti · klaim hadiahmu': 'Verified · claim your reward',
  'Misi harian': 'Daily missions',
  'Terverifikasi · Klaim XP': 'Verified · Claim XP',
  'Lewati hari ini': 'Skip today',
  'Sesuai tujuanmu': 'Matches your goal',
  'Foto penjualan': 'Photograph sales',
  'Lengkapi harga modal': 'Complete purchase costs',
  'XP sudah diklaim': 'XP already claimed',
  'Yang dipelajari AI': 'What AI has learned',
  'Arahan yang mengenal usahamu': 'Guidance tailored to your business',
  'Saran memakai catatan terkonfirmasi, pilihan dan masukanmu. Data tidak dibagikan ke usaha lain.':
      'Guidance uses confirmed records, your preferences and feedback. Your data is not shared with other businesses.',
  'Tujuan usaha': 'Business goal',
  'Ejaan tulisan tangan yang dikenali': 'Recognized handwriting spellings',
  'Belum ada. Saat kamu membetulkan nama produk di hasil scan, ejaannya akan diingat di sini.':
      'No spellings yet. When you correct a product name after a scan, the spelling is remembered here.',
  'Belum ada. Tandai saran di Beranda sebagai Berguna / Tidak berguna.':
      'No feedback yet. Mark Home suggestions as Helpful or Not relevant.',
  'Reset yang dipelajari': 'Reset learned preferences',
  'Reset yang dipelajari?': 'Reset learned preferences?',
  'Scan catatan': 'Scan records',
  'Dari buku ke pembukuan': 'From notebook to bookkeeping',
  'Foto catatan': 'Photograph records',
  'Catatan lainnya': 'Other records',
  'Riwayat tercatat': 'Recorded history',
  'Tips foto': 'Photo tips',
  'Dari foto,\njadi catatan.': 'From photo,\nto record.',
  'Pilih catatan yang ingin difoto.':
      'Choose the record you want to photograph.',
  'Hasil AI jadi draf. Periksa dan konfirmasi sebelum masuk jurnal.':
      'AI results are drafts. Review and confirm before they enter your journal.',
  'Pastikan tulisan terlihat jelas & cahaya cukup.\n\nFoto seluruh catatan tanpa menutupi tepinya. Kamu dapat memakai kamera atau memilih foto dari galeri.':
      'Make sure the writing is clear and well lit.\n\nInclude the whole record without covering its edges. Use the camera or choose a photo from your gallery.',
  'Penjualan harian': 'Daily sales',
  'Stok awal & harga modal': 'Opening stock & purchase costs',
  'Struk biaya usaha': 'Business expense receipt',
  'Ambil foto': 'Take a photo',
  'AI membaca': 'AI reads',
  'Periksa': 'Review',
  'Konfirmasi': 'Confirm',
  'Tanggal catatan': 'Record date',
  'Ringkasan harian': 'Daily summary',
  'Transaksi satuan': 'Individual transaction',
  'Catatan manual': 'Manual record',
  'Data diisi langsung, tanpa foto sumber.':
      'Entered directly, without a source photo.',
  'Periksa data yang kamu isi, lalu konfirmasi untuk mencatatnya.':
      'Review your entries, then confirm to record them.',
  'Produk': 'Product',
  'Jumlah barang': 'Quantity',
  'Harga per barang': 'Price per item',
  'Pilih produk': 'Choose a product',
  'Pilih produk yang cocok': 'Choose the matching product',
  'Hapus baris': 'Remove row',
  'Tambah baris': 'Add row',
  'Batalkan': 'Cancel',
  'Proses ulang foto': 'Reprocess photo',
  'Proses ulang': 'Try again',
  'Berhasil dicatat!': 'Successfully recorded!',
  'Omzet': 'Revenue',
  'HPP (modal terjual)': 'Cost of goods sold',
  'Laba kotor': 'Gross profit',
  'Perubahan stok': 'Stock changes',
  'Saldo terbaru, termasuk catatan setelah transaksi ini.':
      'Latest balance, including records after this transaction.',
  'Mengerti': 'Got it',
  'Ya, catat': 'Yes, record it',
  'Catat ke pembukuan?': 'Post to the books?',
  'Isi manual': 'Enter manually',
  'Catatan belum bisa dibaca': 'The record could not be read',
  'Tenang, stok dan laporanmu tidak berubah.':
      'Your stock and reports have not changed.',
  'Keluar': 'Sign out',
  'Coba demo lokal': 'Try local demo',
  'Masuk dengan Google': 'Sign in with Google',
  'Catatan tetap di buku.\nUsaha makin terbaca.':
      'Keep your notebook.\nUnderstand your business.',
  'Foto catatan tulisan tangan': 'Photograph handwritten records',
  'Periksa & konfirmasi, kamu yang memutuskan': 'Review & confirm — you decide',
  'Stok, omzet & laba otomatis': 'Automatic stock, revenue & profit tracking',
  'Misi & XP untuk usaha yang lebih rapi':
      'Missions & XP for better business habits',
};
