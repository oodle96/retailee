// Deterministic financial logic. Pure functions so they can be unit tested
// and, later, moved server-side (Cloud Run) unchanged in behaviour.

/// Moving weighted-average purchase cost (PRD §6).
///
/// Returns `null` when the resulting cost basis is unreliable: an unknown
/// historical cost must never be treated as zero or silently mixed in.
double? movingAverageCost({
  required double oldQty,
  required double? oldAvg,
  required double addQty,
  required double? addCost,
}) {
  if (addQty <= 0) return oldAvg;
  if (addCost == null) return null;
  if (oldQty <= 0) return addCost;
  if (oldAvg == null) return null;
  return (oldQty * oldAvg + addQty * addCost) / (oldQty + addQty);
}

/// COGS snapshot for a sale line; null when cost unknown.
double? cogsFor(double qty, double? avgCost) =>
    avgCost == null ? null : qty * avgCost;

class PeriodSummary {
  final double revenue;
  final double knownCogs;
  final bool cogsComplete;
  final double opex; // business expenses only
  final double personal; // personal withdrawals (excluded from profit)
  final double inventoryPurchases; // excluded from opex, goes to stock value
  final int saleCount;
  final int itemsSold;

  const PeriodSummary({
    required this.revenue,
    required this.knownCogs,
    required this.cogsComplete,
    required this.opex,
    required this.personal,
    required this.inventoryPurchases,
    required this.saleCount,
    required this.itemsSold,
  });

  bool get hasSales => saleCount > 0;

  /// Gross profit is only shown when every sold item has a known cost.
  double? get grossProfit =>
      (hasSales && cogsComplete) ? revenue - knownCogs : null;
  double? get grossMarginPct => (grossProfit == null || revenue <= 0)
      ? null
      : grossProfit! / revenue * 100;

  /// Estimated net profit = gross profit − business operating expenses.
  double? get netProfit => grossProfit == null ? null : grossProfit! - opex;
}
