import 'package:flutter/material.dart';
import '../models.dart';
import '../services/ledger.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../l10n/app_language.dart';

class MoneyBreakdown extends StatelessWidget {
  final PeriodSummary summary;
  const MoneyBreakdown({super.key, required this.summary});
  @override
  Widget build(BuildContext context) {
    final s = summary;
    final complete = s.hasSales && s.cogsComplete;
    final net = s.netProfit;
    final parts = [
      ('Biaya langsung', s.knownCogs, AppColors.primary),
      ('Biaya usaha', s.opex, AppColors.warn),
      ('Sisa untung', net ?? 0, AppColors.positive),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Expanded(
                  child: LocalText(
                    'Ke mana pendapatan usahamu?',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.primaryDark,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const LocalText(
              'Ambil pribadi dan belanja stok tidak masuk biaya usaha di bawah.',
              style: TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 12),
            const LocalText(
              'Total pendapatan',
              style: TextStyle(color: AppColors.muted),
            ),
            Text(
              rp(s.revenue),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            if (complete && net! >= 0 && s.revenue > 0) ...[
              Semantics(
                label: parts
                    .map((p) => '${appTr(context, p.$1)} ${rp(p.$2)}')
                    .join(', '),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        for (final p in parts)
                          if (p.$2 > 0)
                            Expanded(
                              flex: (p.$2 / s.revenue * 10000).round().clamp(
                                1,
                                10000,
                              ),
                              child: ColoredBox(
                                color: p.$3,
                                child: const SizedBox.expand(),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final p in parts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 6, right: 12),
                        color: p.$3,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LocalText(
                              p.$1,
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text(
                              rp(p.$2),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ] else ...[
              LocalText(
                !s.hasSales
                    ? 'Belum ada pendapatan tercatat.'
                    : !s.cogsComplete
                    ? 'Biaya langsung belum lengkap. Laba belum bisa dipastikan.'
                    : 'Biaya melebihi pendapatan.',
                style: const TextStyle(
                  color: AppColors.warn,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (complete) ...[
                RankedAmount(
                  label: 'Biaya langsung',
                  amount: s.knownCogs,
                  maximum: s.knownCogs + s.opex,
                  color: AppColors.primary,
                ),
                RankedAmount(
                  label: 'Biaya usaha',
                  amount: s.opex,
                  maximum: s.knownCogs + s.opex,
                  color: AppColors.warn,
                ),
                LocalText(
                  'Rugi ${rp(-net!)}',
                  style: const TextStyle(
                    fontSize: 24,
                    color: AppColors.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class RankedAmount extends StatelessWidget {
  final String label;
  final String? detail;
  final double amount;
  final double maximum;
  final Color color;
  const RankedAmount({
    super.key,
    required this.label,
    this.detail,
    required this.amount,
    required this.maximum,
    this.color = AppColors.primary,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LocalText(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        Text(
          rp(amount),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        if (detail != null)
          LocalText(
            detail!,
            style: const TextStyle(fontSize: 16, color: AppColors.muted),
          ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: maximum <= 0 ? 0 : (amount / maximum).clamp(0, 1),
          minHeight: 14,
          color: color,
          backgroundColor: AppColors.line,
        ),
      ],
    ),
  );
}

class SalesTrend extends StatefulWidget {
  final List<MapEntry<DateTime, double>> data;
  final Set<String> recordedDays;
  final bool compact;
  const SalesTrend({
    super.key,
    required this.data,
    required this.recordedDays,
    this.compact = false,
  });
  @override
  State<SalesTrend> createState() => _SalesTrendState();
}

class _SalesTrendState extends State<SalesTrend> {
  int? _selected;
  @override
  void didUpdateWidget(covariant SalesTrend oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.length != widget.data.length) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data.isEmpty) return const SizedBox();
    final selected = (_selected ?? data.length - 1).clamp(0, data.length - 1);
    final max = data.fold<double>(0, (v, e) => e.value > v ? e.value : v);
    final current = data[selected];
    final recorded = widget.recordedDays.contains(dayKey(current.key));
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    fmtDateLong(current.key),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.primaryDark,
                ),
              ],
            ),
            LocalText(
              recorded ? rp(current.value) : 'Belum dicatat',
              style: TextStyle(
                fontSize: widget.compact ? 24 : 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            LocalText(
              'Ketuk batang untuk melihat jumlah. Geser untuk hari lainnya. Batang pucat berarti belum ada catatan.',
              style: TextStyle(fontSize: widget.compact ? 13 : 16, height: 1.4),
            ),
            const SizedBox(height: 20),
            SingleChildScrollView(
              key: PageStorageKey('sales-trend-${data.length}'),
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: SizedBox(
                height: 150 + 48 * scale,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < data.length; i++)
                      Semantics(
                        selected: i == selected,
                        button: true,
                        label:
                            '${fmtDate(data[i].key)}: ${widget.recordedDays.contains(dayKey(data[i].key)) ? rp(data[i].value) : appTr(context, 'belum dicatat')}',
                        child: InkWell(
                          onTap: () => setState(() => _selected = i),
                          child: SizedBox(
                            width: (widget.compact ? 64 : 52) * scale,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  width: 30 * scale,
                                  height:
                                      4 +
                                      (max <= 0
                                          ? 0
                                          : data[i].value / max * 126),
                                  decoration: BoxDecoration(
                                    color:
                                        widget.recordedDays.contains(
                                          dayKey(data[i].key),
                                        )
                                        ? (selected == i
                                              ? AppColors.primary
                                              : AppColors.info)
                                        : AppColors.line,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                LocalText(
                                  '${data[i].key.day}/${data[i].key.month}',
                                  style: TextStyle(
                                    fontSize: widget.compact ? 12 : 18,
                                    fontWeight: selected == i
                                        ? FontWeight.w900
                                        : FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
