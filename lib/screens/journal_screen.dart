import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/retail_art.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'document_screen.dart';
import 'home_shell.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  bool _draftsOnly = false;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final documents =
        store.documents
            .where(
              (d) =>
                  d.status != DocStatus.cancelled &&
                  (!_draftsOnly || d.status != DocStatus.posted),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final linked = store.documents.expand((d) => d.postedRefs).toSet();
    final entries = <(DateTime, Widget)>[
      for (final doc in documents)
        (doc.date, _JournalRecordTile(document: doc)),
      if (!_draftsOnly) ...[
        for (final sale in store.sales.where(
          (s) => s.documentId == null && !linked.contains(s.id),
        ))
          (
            sale.date,
            Card(
              child: ExpansionTile(
                key: PageStorageKey('journal-sale-${sale.id}'),
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(
                  '${appTr(context, 'Pendapatan')} · ${rp(sale.revenue)}',
                ),
                subtitle: Text(fmtDate(sale.date)),
                children: [
                  for (final item in sale.items)
                    ListTile(
                      title: Text(item.productName),
                      subtitle: Text(
                        '${fmtQty(item.qty)} ${item.unit} × ${rp(item.unitPrice)}',
                      ),
                      trailing: Text(rp(item.total)),
                    ),
                ],
              ),
            ),
          ),
        for (final expense in store.expenses.where(
          (e) => e.documentId == null && !linked.contains(e.id),
        ))
          (
            expense.date,
            Card(
              child: ExpansionTile(
                key: PageStorageKey('journal-expense-${expense.id}'),
                leading: const Icon(Icons.payments_outlined),
                title: Text(expense.description),
                subtitle: Text(
                  '${fmtDate(expense.date)} · ${rp(expense.amount)}',
                ),
                children: [
                  ListTile(
                    title: LocalText(expenseTypeLabels[expense.type]!),
                    subtitle: LocalText(expense.category),
                  ),
                ],
              ),
            ),
          ),
      ],
    ]..sort((a, b) => b.$1.compareTo(a.$1));
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
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      child: Material(
        color: const Color(0xFFF7F8FC),
        child: SafeArea(
          child: ListView(
            key: const PageStorageKey('journal-records'),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              Semantics(
                header: true,
                child: LocalText(
                  'Jurnal usahamu',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEAFE),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2DDF7)),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFFE0DCF0), offset: Offset(0, 4)),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const copy = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LocalText(
                          'Catatanmu,\nrapi di sini.',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        SizedBox(height: 8),
                        LocalText(
                          'Periksa draf, buka foto asal, dan lihat catatan yang sudah dikonfirmasi.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: Color(0xFF5D5875),
                          ),
                        ),
                      ],
                    );
                    const art = RetailArt(
                      scene: RetailScene.notebook,
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
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const LocalText('Semua catatan'),
                    avatar: Icon(
                      Icons.menu_book_outlined,
                      size: 18,
                      color: !_draftsOnly
                          ? Colors.white
                          : AppColors.primaryDark,
                    ),
                    selected: !_draftsOnly,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: !_draftsOnly
                          ? Colors.white
                          : AppColors.primaryDark,
                    ),
                    side: const BorderSide(color: Color(0xFFE4DFF4)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 9,
                    ),
                    onSelected: (_) => setState(() => _draftsOnly = false),
                  ),
                  ChoiceChip(
                    label: const LocalText('Perlu diperiksa'),
                    avatar: Icon(
                      Icons.fact_check_outlined,
                      size: 18,
                      color: _draftsOnly ? Colors.white : AppColors.primaryDark,
                    ),
                    selected: _draftsOnly,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _draftsOnly ? Colors.white : AppColors.primaryDark,
                    ),
                    side: const BorderSide(color: Color(0xFFE4DFF4)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 9,
                    ),
                    onSelected: (_) => setState(() => _draftsOnly = true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (entries.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          _draftsOnly
                              ? Icons.task_alt_rounded
                              : Icons.menu_book_outlined,
                          color: _draftsOnly
                              ? AppColors.positive
                              : AppColors.primary,
                          size: 36,
                        ),
                        const SizedBox(height: 14),
                        LocalText(
                          _draftsOnly
                              ? 'Tidak ada draf yang perlu diperiksa.'
                              : 'Jurnal dimulai dari foto catatan pertamamu.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () => HomeShell.goTo(context, 2),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const LocalText('Foto catatan'),
                        ),
                      ],
                    ),
                  ),
                ),
              for (var i = 0; i < entries.length; i++) ...[
                if (i == 0 ||
                    !DateUtils.isSameDay(entries[i].$1, entries[i - 1].$1))
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 10),
                    child: Semantics(
                      header: true,
                      child: Text(
                        fmtDate(entries[i].$1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF65687B),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: entries[i].$2,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _JournalRecordTile extends StatelessWidget {
  final SourceDocument document;
  const _JournalRecordTile({required this.document});
  @override
  Widget build(BuildContext context) {
    final (status, icon, color, background) = switch (document.status) {
      DocStatus.posted => (
        'Tercatat',
        Icons.check_circle_outline,
        AppColors.positive,
        const Color(0xFFE9F6F0),
      ),
      DocStatus.draft => (
        'Perlu diperiksa',
        Icons.fact_check_outlined,
        AppColors.warn,
        AppColors.warnSoft,
      ),
      DocStatus.processing => (
        'Diproses',
        Icons.hourglass_top_rounded,
        AppColors.info,
        AppColors.infoSoft,
      ),
      DocStatus.failed => (
        'Gagal dibaca',
        Icons.error_outline,
        AppColors.danger,
        AppColors.dangerSoft,
      ),
      DocStatus.cancelled => (
        'Dibatalkan',
        Icons.cancel_outlined,
        const Color(0xFF65687B),
        const Color(0xFFF1F1F6),
      ),
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DocumentScreen(docId: document.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EEFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  document.manualEntry ? Icons.edit_note : Icons.photo_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocalText(
                      docKindLabels[document.kind]!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, color: color, size: 16),
                          const SizedBox(width: 5),
                          Flexible(
                            child: LocalText(
                              status,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFF65687B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JournalDocumentTile extends StatelessWidget {
  final SourceDocument document;
  const JournalDocumentTile({super.key, required this.document});
  @override
  Widget build(BuildContext context) {
    final status = switch (document.status) {
      DocStatus.posted => 'Tercatat',
      DocStatus.draft => 'Perlu diperiksa',
      DocStatus.processing => 'Diproses',
      DocStatus.failed => 'Gagal dibaca',
      DocStatus.cancelled => 'Dibatalkan',
    };
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(
          document.manualEntry ? Icons.edit_note : Icons.photo_outlined,
        ),
        title: LocalText(
          docKindLabels[document.kind]!,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('${fmtDate(document.date)} · ${appTr(context, status)}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DocumentScreen(docId: document.id)),
        ),
      ),
    );
  }
}
