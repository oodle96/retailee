import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../services/store.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import '../widgets/retail_art.dart';
import 'document_screen.dart';

const _kindIcons = {
  DocKind.serviceIncome: Icons.cleaning_services_outlined,
  DocKind.openingStock: Icons.inventory_2_rounded,
  DocKind.dailySales: Icons.receipt_long_rounded,
  DocKind.expenseReceipt: Icons.request_quote_rounded,
};
const _kindDesc = {
  DocKind.serviceIncome: 'Catatan pekerjaan selesai dan tarif layanan',
  DocKind.openingStock: 'Catatan stok & harga modal di buku',
  DocKind.dailySales: 'Catatan penjualan harian tulisan tangan',
  DocKind.expenseReceipt: 'Nota listrik, transport, belanja, dll.',
};
const _kindColors = {
  DocKind.serviceIncome: AppColors.primary,
  DocKind.openingStock: AppColors.ai,
  DocKind.dailySales: AppColors.primary,
  DocKind.expenseReceipt: AppColors.info,
};

/// Scan → choose document type → capture/upload → processing → review.
Future<void> startScan(BuildContext context, DocKind kind) async {
  final store = StoreScope.read(context);
  if (store.serviceFirst &&
      !store.mixedBusiness &&
      kind == DocKind.dailySales) {
    kind = DocKind.serviceIncome;
  }
  if (kind == DocKind.dailySales && store.products.isEmpty) {
    showMessage(
      context,
      'Catat stok awal dulu supaya penjualan bisa dicocokkan ke produk.',
      error: true,
    );
    return;
  }
  final source = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFFF7F8FC),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * .85,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: LocalText(
                        docKindLabels[kind]!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: appTr(ctx, 'Batalkan'),
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const LocalText(
                  'Pastikan tulisan terlihat jelas & cahaya cukup.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF65687B),
                  ),
                ),
                const SizedBox(height: 16),
                _sourceTile(
                  ctx,
                  'camera',
                  Icons.photo_camera_rounded,
                  'Ambil foto',
                  'Gunakan kamera HP',
                ),
                _sourceTile(
                  ctx,
                  'gallery',
                  Icons.photo_library_rounded,
                  'Pilih dari galeri',
                  'Foto yang sudah ada',
                ),
                if (!store.googleEnabled)
                  _sourceTile(
                    ctx,
                    'sample',
                    Icons.auto_stories_rounded,
                    'Pakai contoh catatan',
                    'Data demo untuk presentasi',
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  if (source == null || !context.mounted) return;

  XFile? file;
  if (source != 'sample') {
    try {
      file = await ImagePicker().pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1800,
        imageQuality: 80,
      );
    } catch (e) {
      if (context.mounted) {
        showMessage(context, 'Kamera/galeri tidak tersedia: $e', error: true);
      }
      return;
    }
    if (file == null) return;
  }
  try {
    final bytes = file == null ? null : await file.readAsBytes();
    if (!context.mounted) return;
    final doc = await store.createDocument(
      kind,
      image: bytes,
      imagePath: file?.name,
    );
    store.extract(doc.id); // async; DocumentScreen shows progress
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => DocumentScreen(docId: doc.id)));
  } catch (e) {
    if (context.mounted) {
      showMessage(context, 'Foto belum dapat disimpan. $e', error: true);
    }
  }
}

Widget _sourceTile(
  BuildContext ctx,
  String value,
  IconData icon,
  String title,
  String sub,
) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Material(
    color: AppColors.bg,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.pop(ctx, value),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalText(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  LocalText(
                    sub,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    ),
  ),
);

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final drafts = store.openDrafts;
    final history =
        store.documents.where((d) => d.status == DocStatus.posted).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final primaryKind = store.serviceFirst
        ? DocKind.serviceIncome
        : store.products.isEmpty
        ? DocKind.openingStock
        : DocKind.dailySales;
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE9EAF2)),
          ),
        ),
        textTheme: base.textTheme.copyWith(
          bodyMedium: const TextStyle(
            fontSize: 15,
            height: 1.45,
            color: AppColors.ink,
          ),
          bodySmall: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: Color(0xFF65687B),
          ),
        ),
      ),
      child: Material(
        color: const Color(0xFFF7F8FC),
        child: SafeArea(
          child: ListView(
            key: const PageStorageKey('photo-capture'),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: const LocalText(
                        'Foto catatan',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                  const InfoButton(
                    title: 'Tips foto',
                    message:
                        'Pastikan tulisan terlihat jelas & cahaya cukup.\n\nFoto seluruh catatan tanpa menutupi tepinya. Kamu dapat memakai kamera atau memilih foto dari galeri.',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE0F4FF), Color(0xFFEBE5FF)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFFD6E7F6)),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFFD2DFF0), offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LocalText(
                      '1 / 5 · Ambil foto',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const copy = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LocalText(
                              'Dari foto,\njadi catatan.',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            SizedBox(height: 8),
                            LocalText(
                              'Pilih catatan yang ingin difoto.',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: Color(0xFF535471),
                              ),
                            ),
                          ],
                        );
                        const art = RetailArt(
                          scene: RetailScene.capture,
                          width: 92,
                        );
                        return MediaQuery.textScalerOf(context).scale(14) > 20
                            ? const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [art, SizedBox(height: 12), copy],
                              )
                            : const Row(
                                children: [
                                  Expanded(child: copy),
                                  SizedBox(width: 8),
                                  art,
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: 16),
                    _kindCard(context, primaryKind, primary: true),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.verified_user_outlined,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LocalText(
                      'Hasil AI jadi draf. Periksa dan konfirmasi sebelum masuk jurnal.',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF65687B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  key: const PageStorageKey('photo-other-kinds'),
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: AppColors.primary,
                  ),
                  title: const LocalText(
                    'Catatan lainnya',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    if (store.mixedBusiness) ...[
                      _kindCard(
                        context,
                        store.serviceFirst
                            ? DocKind.dailySales
                            : DocKind.serviceIncome,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (store.products.isNotEmpty && !store.serviceFirst) ...[
                      _kindCard(context, DocKind.openingStock),
                      const SizedBox(height: 8),
                    ],
                    _kindCard(context, DocKind.expenseReceipt),
                  ],
                ),
              ),
              if (drafts.isNotEmpty) ...[
                const SizedBox(height: 24),
                _heading('Lanjutkan yang belum selesai'),
                const SizedBox(height: 12),
                for (final d in drafts) _docTile(context, d),
              ],
              if (history.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    key: const PageStorageKey('photo-history'),
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    leading: const Icon(
                      Icons.history_rounded,
                      color: AppColors.primary,
                    ),
                    title: const LocalText(
                      'Riwayat tercatat',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    children: [
                      for (final d in history.take(8)) _docTile(context, d),
                      TextButton.icon(
                        onPressed: () => HomeShell.goTo(context, 1),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const LocalText('Buka jurnal'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String label) => Semantics(
    header: true,
    child: LocalText(
      label,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    ),
  );

  Widget _kindCard(BuildContext context, DocKind kind, {bool primary = false}) {
    final color = primary ? AppColors.primaryDark : _kindColors[kind]!;
    return Material(
      color: primary ? color : const Color(0xFFF5F3FC),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => startScan(context, kind),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                _kindIcons[kind],
                color: primary ? Colors.white : color,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocalText(
                      docKindLabels[kind]!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primary ? Colors.white : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    LocalText(
                      _kindDesc[kind]!,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: primary ? Colors.white : const Color(0xFF65687B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                primary
                    ? Icons.photo_camera_outlined
                    : Icons.chevron_right_rounded,
                size: 22,
                color: primary ? Colors.white : color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _docTile(BuildContext context, SourceDocument d) {
    final (label, color) = switch (d.status) {
      DocStatus.draft => ('Menunggu konfirmasi', AppColors.warn),
      DocStatus.failed => ('Gagal dibaca', AppColors.danger),
      DocStatus.posted => ('Tercatat', AppColors.positive),
      DocStatus.processing => ('Diproses', AppColors.info),
      DocStatus.cancelled => ('Dibatalkan', const Color(0xFF65687B)),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DocumentScreen(docId: d.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(_kindIcons[d.kind], color: _kindColors[d.kind], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LocalText(
                        docKindLabels[d.kind]!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${fmtDate(d.date)} · ${fmtTime(d.createdAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Color(0xFF65687B),
                        ),
                      ),
                      const SizedBox(height: 5),
                      LocalText(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
