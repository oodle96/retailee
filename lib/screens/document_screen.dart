import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/app_ui.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/brand.dart';
import 'business_home_screen.dart';
import 'operations_screen.dart' show MaterialPicker;
import 'stock_screen.dart';

/// Hosts one source document through processing → review → result.
class DocumentScreen extends StatefulWidget {
  final String docId;
  const DocumentScreen({super.key, required this.docId});
  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {
  PostResult? _result;
  Map<String, double> _before = {};
  bool _photoRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_photoRequested) return;
    _photoRequested = true;
    scheduleMicrotask(() {
      if (mounted) StoreScope.read(context).loadPhoto(widget.docId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final doc = store.documentById(widget.docId);
    if (doc == null) {
      return const AppFrame(
        title: 'Jurnal',
        body: Center(child: LocalText('Dokumen tidak ditemukan')),
      );
    }

    final Widget body;
    if (_result != null || doc.status == DocStatus.posted) {
      body = _ResultView(doc: doc, result: _result, before: _before);
    } else {
      body = switch (doc.status) {
        DocStatus.processing => _ProcessingView(doc: doc),
        DocStatus.failed => _FailedView(doc: doc),
        DocStatus.cancelled => _CancelledView(doc: doc),
        _ => _ReviewView(
          key: ValueKey(
            '${doc.id}_${doc.rawRows.length}_${doc.rawRows.hashCode}',
          ),
          doc: doc,
          keyboardVisible: MediaQuery.viewInsetsOf(context).bottom > 0,
          onPosted: (r, before) => setState(() {
            _result = r;
            _before = before;
          }),
        ),
      };
    }
    return AppFrame(
      title: docKindLabels[doc.kind]!,
      leading: IconButton(
        tooltip: appTr(context, 'Tutup dokumen'),
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          ScanProgress(
            step: doc.status == DocStatus.posted || _result != null
                ? 4
                : doc.status == DocStatus.processing
                ? 1
                : 2,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- processing
class _ProcessingView extends StatefulWidget {
  final SourceDocument doc;
  const _ProcessingView({required this.doc});
  @override
  State<_ProcessingView> createState() => _ProcessingViewState();
}

class _ProcessingViewState extends State<_ProcessingView> {
  int _step = 0;
  Timer? _t;
  static const _steps = [
    'Mengunggah foto',
    'Membaca tulisan tangan',
    'Mencocokkan produk',
    'Menyiapkan draf',
  ];
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (_step < _steps.length - 1) setState(() => _step++);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SourcePreview(
          doc: widget.doc,
          image: store.imageFor(widget.doc.id),
          height: 180,
          scanning: true,
        ),
        const SizedBox(height: 16),
        Row(children: [Flexible(child: Pill.ai('AI sedang membaca'))]),
        const SizedBox(height: 14),
        for (var i = 0; i < _steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: i < _step
                      ? const Icon(Icons.check_circle, color: AppColors.primary)
                      : i == _step
                      ? const Padding(
                          padding: EdgeInsets.all(3),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.ai,
                          ),
                        )
                      : const Icon(
                          Icons.circle_outlined,
                          color: AppColors.line,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LocalText(
                    _steps[i],
                    style: TextStyle(
                      fontWeight: i == _step
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: i > _step ? appSecondary : AppColors.ink,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        const LocalText(
          'Biasanya selesai dalam 15 detik. Kamu bisa menutup layar ini — draf tersimpan otomatis.',
          style: TextStyle(color: AppColors.muted, fontSize: 16),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- failure
class _FailedView extends StatelessWidget {
  final SourceDocument doc;
  const _FailedView({required this.doc});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        const Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.danger),
        const SizedBox(height: 16),
        const LocalText(
          'Catatan belum bisa dibaca',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        LocalText(
          doc.error ?? 'Terjadi kesalahan.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        const LocalText(
          'Tenang, stok dan laporanmu tidak berubah.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: () => store.extract(doc.id),
          icon: const Icon(Icons.refresh),
          label: const LocalText('Proses ulang'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => store.startManualDraft(doc.id),
          icon: const Icon(Icons.edit_note),
          label: const LocalText('Isi manual'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () async {
            await store.cancelDocument(doc.id);
            if (context.mounted) Navigator.pop(context);
          },
          child: const LocalText(
            'Batalkan draf',
            style: TextStyle(color: AppColors.danger),
          ),
        ),
      ],
    );
  }
}

class _CancelledView extends StatelessWidget {
  final SourceDocument doc;
  const _CancelledView({required this.doc});
  @override
  Widget build(BuildContext context) => const SingleChildScrollView(
    child: EmptyState(
      icon: Icons.block,
      title: 'Draf dibatalkan',
      body: 'Draf ini tidak memengaruhi stok maupun laporan.',
    ),
  );
}

// ----------------------------------------------------------------- review
class _ReviewView extends StatefulWidget {
  final SourceDocument doc;
  final bool keyboardVisible;
  final void Function(PostResult, Map<String, double> before) onPosted;
  const _ReviewView({
    super.key,
    required this.doc,
    this.keyboardVisible = false,
    required this.onPosted,
  });
  @override
  State<_ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends State<_ReviewView> {
  bool _ack = false;
  bool _posting = false;
  bool _showPhoto = true;
  Set<DraftRow>? _focusedRows;
  final _rowsAnchor = GlobalKey();

  SourceDocument get doc => widget.doc;

  void _changed() {
    setState(() {});
    StoreScope.read(context).saveDraft(doc);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final v = store.validate(doc, overlapAcknowledged: _ack);
    final unclear = doc.rows.where((r) => r.include && r.unclear).length;
    final attention = <DraftRow>{
      for (var i = 0; i < doc.rows.length; i++)
        if (doc.rows[i].include &&
            (doc.rows[i].unclear || v.rowErrors.containsKey(i)))
          doc.rows[i],
    };

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _banner(unclear),
                if (store.serviceFirst &&
                    (doc.kind == DocKind.openingStock ||
                        doc.kind == DocKind.dailySales))
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: const LocalText('Ini catatan layanan, bukan stok'),
                    onPressed: () {
                      doc.kind = DocKind.serviceIncome;
                      doc.saleMode = SaleMode.individual;
                      doc.servicesCompleted = false;
                      for (final row in doc.rows) {
                        row.productId = null;
                        row.candidates = [];
                        row.unitCost = null;
                      }
                      _changed();
                    },
                  ),
                if (v.errors.isNotEmpty)
                  ExpansionTile(
                    initiallyExpanded: true,
                    title: LocalText(
                      '${v.errors.length} hal menghalangi konfirmasi',
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    children: [
                      for (final e in v.errors)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: LocalText(
                            e,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ),
                    ],
                  ),
                if (attention.isNotEmpty && doc.kind != DocKind.expenseReceipt)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.find_in_page_outlined),
                    label: LocalText(
                      'Periksa ${attention.length} baris bertanda',
                    ),
                    onPressed: () {
                      setState(() => _focusedRows = attention);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _rowsAnchor.currentContext != null) {
                          Scrollable.ensureVisible(
                            _rowsAnchor.currentContext!,
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 200),
                          );
                        }
                      });
                    },
                  ),
                const SizedBox(height: 12),
                if (doc.manualEntry &&
                    doc.imagePath == null &&
                    !doc.photoStored &&
                    store.imageFor(doc.id) == null)
                  const Row(
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        size: 20,
                        color: appSecondary,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: LocalText(
                          'Catatan manual',
                          style: TextStyle(fontSize: 13, color: appSecondary),
                        ),
                      ),
                      InfoButton(
                        title: 'Catatan manual',
                        message: 'Data diisi langsung, tanpa foto sumber.',
                      ),
                    ],
                  )
                else
                  _photoToggle(store),
                const SizedBox(height: 12),
                AppSection(children: [_dateAndMode(store)]),
                if (doc.kind == DocKind.serviceIncome)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: doc.servicesCompleted,
                    title: const LocalText('Layanan ini sudah selesai'),
                    subtitle: const LocalText(
                      'Bukan penawaran, uang muka, atau pekerjaan yang masih berjalan.',
                    ),
                    onChanged: (v) {
                      doc.servicesCompleted = v == true;
                      _changed();
                    },
                  ),
                if (doc.kind == DocKind.expenseReceipt)
                  AppSection(
                    title: 'Detail pengeluaran',
                    children: [_ExpenseEditor(doc: doc, onChanged: _changed)],
                  )
                else ...[
                  Padding(
                    key: _rowsAnchor,
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LocalText(
                          _focusedRows == null
                              ? 'Periksa semua ${doc.rows.length} baris'
                              : 'Fokus pada baris bertanda',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_focusedRows != null) ...[
                          const LocalText(
                            'Baris lain tetap ikut dalam total. Periksa semuanya sebelum konfirmasi.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _focusedRows = null),
                            child: LocalText(
                              'Tampilkan semua ${doc.rows.length} baris',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  for (var i = 0; i < doc.rows.length; i++)
                    if (_focusedRows == null ||
                        _focusedRows!.contains(doc.rows[i]))
                      _RowEditor(
                        key: ObjectKey(doc.rows[i]),
                        doc: doc,
                        index: i,
                        error: v.rowErrors[i],
                        onChanged: _changed,
                        onRemove: () {
                          doc.rows.removeAt(i);
                          _changed();
                        },
                      ),
                  OutlinedButton.icon(
                    onPressed: () {
                      doc.rows.add(
                        DraftRow(
                          rawText: '(ditambah manual)',
                          name: '',
                          qty: 1,
                        ),
                      );
                      _focusedRows = null;
                      _changed();
                    },
                    icon: const Icon(Icons.add),
                    label: const LocalText('Tambah baris'),
                  ),
                ],
                if (v.warnings.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  for (final w in v.warnings.toSet())
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _note(
                        Icons.info_outline,
                        w,
                        AppColors.warn,
                        AppColors.warnSoft,
                      ),
                    ),
                ],
                if (store.needsOverlapAck(doc)) ...[
                  const SizedBox(height: 8),
                  Card(
                    color: AppColors.warnSoft,
                    child: CheckboxListTile(
                      value: _ack,
                      onChanged: (x) => setState(() => _ack = x ?? false),
                      title: const LocalText(
                        'Ringkasan ini tidak mencakup transaksi satuan yang sudah dicatat hari itu',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
                for (final e in v.errors)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _note(
                      Icons.block,
                      e,
                      AppColors.danger,
                      AppColors.dangerSoft,
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (!doc.manualEntry ||
                        doc.imagePath != null ||
                        doc.photoStored)
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => store.extract(doc.id),
                          icon: const Icon(Icons.refresh),
                          label: const LocalText('Proses ulang foto'),
                        ),
                      ),
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                        onPressed: () async {
                          await store.cancelDocument(doc.id);
                          if (context.mounted) {
                            Navigator.pop(context);
                            showMessage(
                              context,
                              'Draf dibatalkan. Tidak ada data yang berubah.',
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const LocalText('Batalkan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!widget.keyboardVisible) _bottomBar(store, v),
      ],
    );
  }

  Widget _banner(int unclear) {
    if (doc.manualEntry) {
      return _note(
        Icons.edit_note_rounded,
        'Periksa data yang kamu isi, lalu konfirmasi untuk mencatatnya.',
        AppColors.primaryDark,
        AppColors.primarySoft,
      );
    }
    if (unclear > 0) {
      return _note(
        Icons.visibility_outlined,
        '$unclear baris kurang jelas ditandai kuning. Cek dan perbaiki sebelum konfirmasi.',
        AppColors.warn,
        AppColors.warnSoft,
      );
    }
    return _note(
      Icons.fact_check_outlined,
      'Cek hasil bacaan AI. Ubah jika ada yang salah, lalu konfirmasi.',
      AppColors.ai,
      AppColors.aiSoft,
    );
  }

  Widget _photoToggle(AppStore store) => Card(
    child: Column(
      children: [
        ListTile(
          leading: const Icon(Icons.image_outlined),
          title: LocalText(
            _showPhoto ? 'Sembunyikan foto asli' : 'Lihat foto asli',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: Icon(_showPhoto ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() => _showPhoto = !_showPhoto),
        ),
        if (_showPhoto)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: store.photoLoading(doc.id)
                ? const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : store.photoErrors[doc.id] != null &&
                      store.imageFor(doc.id) == null
                ? Column(
                    children: [
                      LocalText(
                        store.photoErrors[doc.id]!,
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => store.loadPhoto(doc.id),
                        child: const LocalText('Muat ulang foto'),
                      ),
                    ],
                  )
                : SourcePreview(
                    doc: doc,
                    image: store.imageFor(doc.id),
                    height: 180,
                  ),
          ),
      ],
    ),
  );

  Widget _dateAndMode(AppStore store) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const LocalText(
                'Tanggal catatan',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w700,
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.calendar_today, size: 16),
                label: Text(
                  fmtDate(doc.date),
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: doc.date,
                    firstDate: DateTime(store.now.year - 1),
                    lastDate: store.now,
                  );
                  if (d != null) {
                    doc.date = DateTime(d.year, d.month, d.day, 12);
                    _changed();
                  }
                },
              ),
            ],
          ),
          if (doc.kind == DocKind.dailySales ||
              doc.kind == DocKind.serviceIncome) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in SaleMode.values)
                  ChoiceChip(
                    label: LocalText(
                      mode == SaleMode.dailySummary
                          ? 'Ringkasan harian'
                          : 'Transaksi satuan',
                    ),
                    selected: doc.saleMode == mode,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.line),
                    labelStyle: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      color: doc.saleMode == mode
                          ? Colors.white
                          : AppColors.primaryDark,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    onSelected: (_) {
                      doc.saleMode = mode;
                      _changed();
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _bottomBar(AppStore store, ValidationReport v) {
    String summary;
    if (doc.kind == DocKind.dailySales || doc.kind == DocKind.serviceIncome) {
      final total = doc.rows
          .where((r) => r.include)
          .fold<double>(0, (s, r) => s + r.qty * (r.unitPrice ?? 0));
      summary =
          '${appTr(context, doc.kind == DocKind.serviceIncome ? 'Pendapatan layanan' : 'Total penjualan')} ${rp(total)}';
    } else if (doc.kind == DocKind.openingStock) {
      final n = doc.rows.where((r) => r.include).length;
      final quantities = <String, double>{};
      for (final row in doc.rows.where((r) => r.include)) {
        final unit = store.rowUnit(row);
        quantities[unit] = (quantities[unit] ?? 0) + row.qty;
      }
      summary =
          '$n ${appTr(context, 'Produk')} · ${quantities.entries.map((e) => '${fmtQty(e.value)} ${e.key}').join(' · ')}';
    } else {
      summary = 'Nominal ${rp(doc.expense?.amount ?? 0)}';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalText(
                  summary,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                LocalText(
                  v.ok ? 'Siap dikonfirmasi' : 'Perbaiki tanda merah dulu',
                  style: TextStyle(
                    fontSize: 14,
                    color: v.ok ? AppColors.primary : AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: (!v.ok || _posting) ? null : () => _confirm(store),
              icon: _posting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle),
              label: const LocalText('Konfirmasi'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(AppStore store) async {
    final lines = <String>[];
    if (doc.kind == DocKind.serviceIncome) {
      lines.add(
        'Pendapatan hanya untuk layanan selesai. Pembayaran tidak dicatat otomatis.',
      );
      for (final r in doc.rows.where((r) => r.include)) {
        lines.add('${r.name}: ${rp(r.qty * r.unitPrice!)}');
        for (final m in r.materials) {
          final p = store.productById(m.productId)!;
          lines.add('${p.name}: −${fmtQty(m.qty)} ${p.unit}');
        }
      }
      lines.add(
        'Hanya bahan yang dipilih akan dipotong. Biaya bahan ditambahkan sekali ke biaya langsung.',
      );
    } else if (doc.kind == DocKind.dailySales) {
      for (final r in doc.rows.where((r) => r.include)) {
        final p = store.productById(r.productId)!;
        lines.add(
          '${p.name}: −${fmtQty(r.qty)} ${p.unit} (stok ${fmtQty(p.qty)} → ${fmtQty(p.qty - r.qty)})',
        );
      }
    } else if (doc.kind == DocKind.openingStock) {
      for (final r in doc.rows.where((r) => r.include)) {
        final p = store.productById(r.productId);
        lines.add(
          p == null
              ? '${r.name}: produk baru, stok ${fmtQty(r.qty)} ${store.rowUnit(r)}'
              : '${p.name}: +${fmtQty(r.qty)} ${p.unit} (stok ${fmtQty(p.qty)} → ${fmtQty(p.qty + r.qty)})',
        );
      }
    } else {
      final e = doc.expense!;
      lines.add('${e.description} · ${rp(e.amount)}');
      lines.add('Jenis: ${expenseTypeLabels[e.type]}');
      lines.add(switch (e.type) {
        ExpenseType.businessExpense => 'Mengurangi estimasi laba bersih.',
        ExpenseType.personalWithdrawal => 'Tidak mengurangi laba usaha.',
        ExpenseType.inventoryPurchase => 'Menambah stok & nilai persediaan.',
      });
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const LocalText('Catat ke pembukuan?'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScanProgress(step: 3),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LocalText('•  '),
                    Expanded(child: LocalText(l)),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            LocalText(
              doc.kind == DocKind.serviceIncome
                  ? 'Jurnal dan laporan layanan akan diperbarui.'
                  : 'Setelah dikonfirmasi, stok & laporan akan diperbarui.',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const LocalText('Cek lagi'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(d, true),
            child: const LocalText('Ya, catat'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _posting = true);
    HapticFeedback.mediumImpact();
    final before = {for (final p in store.products) p.id: p.qty};
    final r = await store.confirmDocument(doc.id, overlapAcknowledged: _ack);
    if (!mounted) return;
    setState(() => _posting = false);
    if (r.ok) {
      widget.onPosted(r, before);
    } else {
      showMessage(context, r.message, error: true);
    }
  }
}

Widget _note(IconData icon, String text, Color color, Color bg) => Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: LocalText(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    ],
  ),
);

/// One editable extracted row.
class _RowEditor extends StatelessWidget {
  final SourceDocument doc;
  final int index;
  final String? error;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  const _RowEditor({
    super.key,
    required this.doc,
    required this.index,
    required this.error,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final r = doc.rows[index];
    final isSales = doc.kind == DocKind.dailySales;
    final isService = doc.kind == DocKind.serviceIncome;
    final borderColor = !r.include
        ? AppColors.line
        : error != null
        ? AppColors.danger
        : r.unclear
        ? AppColors.accent
        : AppColors.line;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedOpacity(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        opacity: r.include ? 1 : .5,
        child: Container(
          decoration: BoxDecoration(
            color: r.unclear && r.include
                ? const Color(0xFFFFFBF0)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: borderColor == AppColors.line ? 1 : 2,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LocalText(
                          r.rawText == '(input manual)'
                              ? 'Dimasukkan manual'
                              : 'Tertulis: "${r.rawText}"',
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: AppColors.muted,
                            fontSize: 14,
                          ),
                        ),
                        if (r.learned)
                          Pill.ai('Dikenali dari koreksimu')
                        else if (r.unclear)
                          Pill.warn(
                            'Kurang jelas ${(r.confidence * 100).round()}%',
                          ),
                      ],
                    ),
                  ),
                  Checkbox(
                    value: r.include,
                    onChanged: (v) {
                      r.include = v ?? true;
                      onChanged();
                    },
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: isSales
                    ? _productPicker(context, store, r)
                    : _openingName(store, r),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...[
                      AppTextField(
                        key: ValueKey('row-unit-$index-${r.productId}'),
                        initialValue: isService ? r.unit : store.rowUnit(r),
                        maxLength: 32,
                        decoration: InputDecoration(
                          labelText: isService
                              ? 'Satuan layanan'
                              : 'Satuan produk',
                          counterText: '',
                        ),
                        onChanged: (v) {
                          r.unit = v;
                          onChanged();
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    AppFieldPair(
                      first: _num(
                        '${appTr(context, isService ? 'Jumlah layanan' : 'Jumlah barang')} (${store.rowUnit(r)})',
                        r.qty,
                        (v) => r.qty = v ?? 0,
                      ),
                      second: _num(
                        '${appTr(context, isService
                            ? 'Tarif per layanan'
                            : isSales
                            ? 'Harga per barang'
                            : 'Harga jual')} (${store.rowUnit(r)})',
                        r.unitPrice,
                        (v) => r.unitPrice = v,
                        money: true,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isSales) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _num(
                    '${appTr(context, isService ? 'Biaya lain per layanan' : 'Modal per barang')} (${store.rowUnit(r)})',
                    r.unitCost,
                    (v) => r.unitCost = v,
                    money: true,
                  ),
                ),
                const LocalText(
                  'Boleh kosong jika belum tahu.',
                  style: TextStyle(fontSize: 14, color: AppColors.muted),
                ),
              ],
              if (isService) ...[
                const SizedBox(height: 12),
                const LocalText(
                  'Biaya lain tidak termasuk bahan yang dipilih di bawah. Isi 0 hanya jika memang tidak ada; kosong berarti belum diketahui.',
                ),
                const SizedBox(height: 12),
                const LocalText(
                  'Bahan yang dipakai untuk seluruh baris ini',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                MaterialPicker(
                  initial: r.materials,
                  onChanged: (v) {
                    r.materials = v;
                    onChanged();
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.inventory_2_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StockScreen()),
                  ),
                  label: const LocalText('Kelola stok bahan'),
                ),
              ],
              if (isSales && r.include && r.productId != null) ...[
                const SizedBox(height: 8),
                LocalText(
                  'Subtotal ${rp(r.qty * (r.unitPrice ?? 0))}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
              if (error != null && r.include) ...[
                const SizedBox(height: 8),
                LocalText(
                  error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
              if (r.rawText.contains('manual'))
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onRemove,
                    child: const LocalText('Hapus baris'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _openingName(AppStore store, DraftRow r) {
    final existing = doc.kind == DocKind.serviceIncome
        ? null
        : store.productById(r.productId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          initialValue: r.name,
          decoration: InputDecoration(
            labelText: doc.kind == DocKind.serviceIncome
                ? 'Nama layanan'
                : 'Nama produk',
            isDense: true,
          ),
          style: const TextStyle(fontWeight: FontWeight.w800),
          onChanged: (v) {
            r.name = v;
            onChanged();
          },
        ),
        if (existing != null) ...[
          const SizedBox(height: 6),
          Pill.ok(
            'Cocok dengan produk "${existing.name}" — stok akan ditambah',
            icon: Icons.link,
          ),
        ],
      ],
    );
  }

  Widget _productPicker(BuildContext context, AppStore store, DraftRow r) {
    final candidates = r.candidates
        .map(store.productById)
        .whereType<Product>()
        .toList();
    final others = store.activeProducts
        .where((p) => !r.candidates.contains(p.id))
        .toList();
    final selected = store.productById(r.productId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDropdown<String>(
          initialValue: selected?.id,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Produk',
            isDense: true,
            errorText: r.productId == null && r.include ? 'Pilih produk' : null,
          ),
          items: [
            for (final p in candidates)
              DropdownMenuItem(
                value: p.id,
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: AppColors.ai,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                    LocalText(
                      ' stok ${fmtQty(p.qty)} ${p.unit}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            for (final p in others)
              DropdownMenuItem(
                value: p.id,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                    LocalText(
                      ' stok ${fmtQty(p.qty)} ${p.unit}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (v) {
            r.productId = v;
            final p = store.productById(v);
            if (p != null && (r.unit.trim().isEmpty || r.unit == 'unit')) {
              r.unit = p.unit;
            }
            if (p != null && (r.unitPrice == null || r.unitPrice == 0)) {
              r.unitPrice = p.sellPrice;
            }
            if (r.unclear) r.confidence = 1; // user verified the match
            onChanged();
          },
        ),
        if (selected != null &&
            r.unitPrice != null &&
            r.unitPrice != selected.sellPrice)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: LocalText(
              'Harga di catatan berbeda dari harga jual tersimpan (${rp(selected.sellPrice)}).',
              style: const TextStyle(fontSize: 14, color: AppColors.warn),
            ),
          ),
      ],
    );
  }

  Widget _num(
    String label,
    double? value,
    void Function(double?) set, {
    bool money = false,
  }) {
    return AppTextField(
      initialValue: value == null
          ? ''
          : (money ? fmtNum(value) : fmtQty(value)),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        prefixText: money ? 'Rp ' : null,
      ),
      style: const TextStyle(fontWeight: FontWeight.w700),
      onChanged: (v) {
        set(parseAmount(v));
        onChanged();
      },
    );
  }
}

class _ExpenseEditor extends StatelessWidget {
  final SourceDocument doc;
  final VoidCallback onChanged;
  const _ExpenseEditor({required this.doc, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final e = doc.expense!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in e.flags)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _note(
              Icons.flag_outlined,
              f,
              AppColors.warn,
              AppColors.warnSoft,
            ),
          ),
        if (e.confidence < .75)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _note(
              Icons.visibility_outlined,
              'Bacaan kurang jelas — cek nominal.',
              AppColors.warn,
              AppColors.warnSoft,
            ),
          ),
        const LocalText(
          'Jenis pengeluaran',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const LocalText(
          'Saran AI — pastikan sudah benar.',
          style: TextStyle(color: AppColors.muted, fontSize: 14),
        ),
        const SizedBox(height: 8),
        for (final t in ExpenseType.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _typeOption(t, e),
          ),
        if (e.type == ExpenseType.inventoryPurchase)
          _inventoryFields(context, store),
        const SizedBox(height: 8),
        AppTextField(
          initialValue: e.description,
          decoration: const InputDecoration(labelText: 'Keterangan'),
          onChanged: (v) {
            e.description = v;
            onChanged();
          },
        ),
        const SizedBox(height: 10),
        AppTextField(
          initialValue: e.amount == 0 ? '' : fmtNum(e.amount),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Nominal',
            prefixText: 'Rp ',
          ),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          onChanged: (v) {
            e.amount = parseAmount(v) ?? 0;
            onChanged();
          },
        ),
        const SizedBox(height: 10),
        if (e.type == ExpenseType.businessExpense)
          AppDropdown<String>(
            initialValue: expenseCategories.contains(e.category)
                ? e.category
                : 'Lainnya',
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: [
              for (final c in expenseCategories)
                DropdownMenuItem(value: c, child: LocalText(c)),
            ],
            onChanged: (v) {
              e.category = v ?? 'Lainnya';
              onChanged();
            },
          ),
        const SizedBox(height: 10),
        AppTextField(
          initialValue: e.vendor ?? '',
          decoration: const InputDecoration(
            labelText: 'Toko / penerima (opsional)',
          ),
          onChanged: (v) {
            e.vendor = v.isEmpty ? null : v;
            onChanged();
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _typeOption(ExpenseType t, DraftExpense e) {
    final sel = e.type == t;
    final desc = switch (t) {
      ExpenseType.businessExpense =>
        'Listrik, sewa, transport — mengurangi laba',
      ExpenseType.personalWithdrawal =>
        'Uang warung dipakai pribadi — bukan biaya usaha',
      ExpenseType.inventoryPurchase =>
        'Belanja barang dagangan — menambah stok',
    };
    return Material(
      color: sel ? AppColors.primarySoft : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          e.type = t;
          if (t == ExpenseType.inventoryPurchase && doc.rows.isEmpty) {
            doc.rows = [DraftRow(rawText: 'pembelian stok', name: '', qty: 1)];
          }
          onChanged();
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel ? AppColors.primary : AppColors.line,
              width: sel ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                sel ? Icons.radio_button_checked : Icons.radio_button_off,
                color: sel ? AppColors.primary : AppColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocalText(
                      expenseTypeLabels[t]!,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    LocalText(
                      desc,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inventoryFields(BuildContext context, AppStore store) {
    if (doc.rows.isEmpty) {
      doc.rows = [DraftRow(rawText: 'pembelian stok', name: '', qty: 1)];
    }
    final r = doc.rows.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            AppDropdown<String>(
              initialValue: r.productId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Produk yang dibeli',
                isDense: true,
              ),
              items: [
                for (final p in store.activeProducts)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) {
                r.productId = v;
                r.unit = store.productById(v)?.unit ?? 'unit';
                onChanged();
              },
            ),
            const SizedBox(height: 10),
            AppTextField(
              initialValue: fmtQty(r.qty),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText:
                    '${appTr(context, 'Jumlah unit')} (${store.rowUnit(r)})',
                isDense: true,
              ),
              onChanged: (v) {
                r.qty = parseAmount(v) ?? 0;
                onChanged();
              },
            ),
            if (r.qty > 0 && (doc.expense?.amount ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LocalText(
                  'Modal per unit: ${rp(doc.expense!.amount / r.qty)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- result
class _ResultView extends StatelessWidget {
  final SourceDocument doc;
  final PostResult? result;
  final Map<String, double> before;
  const _ResultView({
    required this.doc,
    required this.result,
    required this.before,
  });

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final xp = result?.xpGained ?? 0;
    final sale =
        doc.kind == DocKind.dailySales || doc.kind == DocKind.serviceIncome
        ? store.sales.where((s) => s.idempotencyKey == doc.id).firstOrNull
        : null;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(
            begin: MediaQuery.disableAnimationsOf(context) ? 1.0 : .5,
            end: 1,
          ),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (_, s, child) => Transform.scale(scale: s, child: child),
          child: Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 52,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        LocalText(
          result?.duplicate == true
              ? 'Sudah tercatat sebelumnya'
              : 'Berhasil dicatat!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        LocalText(
          '${docKindLabels[doc.kind]} · ${fmtDate(doc.date)}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
        if (xp > 0) ...[
          const SizedBox(height: 14),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(99),
              ),
              child: LocalText(
                '+$xp XP terverifikasi',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6B4A00),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (sale != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _kv('Omzet', rp(sale.revenue), bold: true),
                  _kv(
                    doc.kind == DocKind.serviceIncome
                        ? 'Biaya layanan & bahan'
                        : 'HPP (modal terjual)',
                    sale.cogsComplete
                        ? rp(sale.knownCogs)
                        : '≥ ${rp(sale.knownCogs)} (belum lengkap)',
                  ),
                  _kv(
                    'Laba kotor',
                    sale.cogsComplete
                        ? rp(sale.revenue - sale.knownCogs)
                        : 'Belum lengkap',
                    bold: true,
                    color: AppColors.primary,
                  ),
                  if (sale.cogsComplete && sale.revenue > 0)
                    _kv(
                      'Margin',
                      '${((sale.revenue - sale.knownCogs) / sale.revenue * 100).toStringAsFixed(2)}%',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (doc.kind == DocKind.openingStock || doc.kind == DocKind.dailySales)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalText(
                    result == null ? 'Stok saat ini' : 'Perubahan stok',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (result == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: LocalText(
                        'Saldo terbaru, termasuk catatan setelah transaksi ini.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  const SizedBox(height: 8),
                  for (final pid
                      in doc.kind == DocKind.dailySales
                          ? (sale?.items.map((i) => i.productId).toList() ??
                                <String>[])
                          : doc.postedRefs)
                    if (store.productById(pid) case final p?)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              result == null
                                  ? ''
                                  : before.containsKey(pid)
                                  ? '${fmtQty(before[pid]!)} → '
                                  : 'baru → ',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                            LocalText(
                              '${fmtQty(p.qty)} ${p.unit}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
        if (doc.kind == DocKind.expenseReceipt)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _kv('Keterangan', doc.expense?.description ?? ''),
                  _kv('Nominal', rp(doc.expense?.amount ?? 0), bold: true),
                  _kv('Jenis', expenseTypeLabels[doc.expense?.type] ?? ''),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const LocalText('Selesai'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.lightbulb_outline),
          label: const LocalText('Saran dari jurnal ini'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AppFrame(
                title: 'Saran untuk usahamu',
                body: const SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: BusinessAdvicePanel(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _kv(String k, String v, {bool bold = false, Color? color}) =>
      AppKeyValue(label: k, value: v, bold: bold, color: color);
}

/// Shows the captured photo, or a rendered notebook page for demo samples.
class SourcePreview extends StatelessWidget {
  final SourceDocument doc;
  final dynamic image; // Uint8List?
  final double height;
  final bool scanning;
  const SourcePreview({
    super.key,
    required this.doc,
    required this.image,
    this.height = 200,
    this.scanning = false,
  });

  static const _sample = {
    DocKind.serviceIncome: ['Foto catatan layanan selesai'],
    DocKind.openingStock: [
      'STOK AWAL — Okt',
      'Indomie goreng 30 bks  modal 2600  jual 3500',
      'Aqua 600   24 btl   modal 3rb   jual 4rb',
      'Teh pucuk  20   modal 3500   jual 5rb',
      'Gula 1kg   8   jual 16rb  (modal ?)',
    ],
    DocKind.dailySales: [
      'Jual hari ini',
      'indomie   10 x 3500',
      'aqua   5 @4rb',
      'teh pcuk   4 x 5000',
      '                 total 75rb',
    ],
    DocKind.expenseReceipt: [
      'PLN PREPAID',
      'Token listrik',
      'Nominal   Rp 50.000',
      'Lunas — terima kasih',
    ],
  };

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (image != null) {
      content = Image.memory(
        image,
        fit: BoxFit.cover,
        width: double.infinity,
        height: height,
        errorBuilder: (_, _, _) => SizedBox(
          height: height,
          child: const Center(
            child: LocalText('Pratinjau format foto tidak tersedia.'),
          ),
        ),
      );
    } else if (doc.imagePath != null) {
      content = SizedBox(
        height: height,
        width: double.infinity,
        child: const Center(
          child: LocalText(
            'Foto asli sedang dimuat atau belum tersedia.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      final lines = _sample[doc.kind]!;
      content = Container(
        height: height,
        width: double.infinity,
        color: const Color(0xFFFFFDF4),
        child: CustomPaint(
          painter: _PaperPainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(46, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lines.length; i++)
                  SizedBox(
                    height: (height - 28) / lines.length,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          lines[i],
                          maxLines: 1,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: i == 0 ? 17 : 16,
                            fontWeight: i == 0
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: const Color(0xFF1E3A8A),
                            letterSpacing: .3,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          content,
          if (scanning) Positioned.fill(child: _ScanLine(height: height)),
          if (image == null && doc.imagePath == null)
            Positioned(
              right: 10,
              top: 10,
              child: Pill(
                'Contoh demo',
                color: AppColors.muted,
                bg: Colors.white.withValues(alpha: .9),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFFBFD7F2)
      ..strokeWidth = 1;
    for (double y = 46; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    canvas.drawLine(
      const Offset(36, 0),
      Offset(36, size.height),
      Paint()
        ..color = const Color(0xFFF2A6A6)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanLine extends StatefulWidget {
  final double height;
  const _ScanLine({required this.height});
  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: AppColors.ai.withValues(alpha: .06)),
          ),
          Positioned(
            top: _c.value * (widget.height - 4),
            left: 0,
            right: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.ai,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ai.withValues(alpha: .6),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
