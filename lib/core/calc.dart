// Framework-free business logic: no Flutter, no DB imports.
// Kept isolated so it can be reused unchanged if the UI or storage layer is
// ever replaced (e.g. ported to native mobile or wired to a backend).
import 'models.dart';

double calcTotalCFT(double round, double cftPerVehicle) {
  return round * cftPerVehicle;
}

double calcAmount(double totalCFT, double ratePerCft) {
  return totalCFT * ratePerCft;
}

class EntryTotals {
  final double totalCFT;
  final double amount;
  const EntryTotals(this.totalCFT, this.amount);
}

/// Derives totalCFT + amount together from raw entry fields + the selected brand's rate.
EntryTotals calcEntryTotals(
  double round,
  double cftPerVehicle,
  double ratePerCft,
) {
  final totalCFT = calcTotalCFT(round, cftPerVehicle);
  final amount = calcAmount(totalCFT, ratePerCft);
  return EntryTotals(totalCFT, amount);
}

/// What each brand's stock actually cost per cft: the average price paid
/// across all of that brand's purchases (so per-entry price changes are
/// respected), falling back to the brand's default purchase rate while
/// nothing has been bought yet.
Map<int, double> costRateByBrand(List<Entry> purchases, List<Brand> brands) {
  final cft = <int, double>{};
  final amount = <int, double>{};
  for (final p in purchases) {
    cft[p.brandId] = (cft[p.brandId] ?? 0) + p.totalCFT;
    amount[p.brandId] = (amount[p.brandId] ?? 0) + p.amount;
  }
  final rates = <int, double>{
    for (final b in brands)
      if (b.id != null) b.id!: b.purchaseRate,
  };
  for (final id in cft.keys) {
    final total = cft[id]!;
    if (total > 0) rates[id] = amount[id]! / total;
  }
  return rates;
}

/// Realized profit — margin actually earned on stock that's been sold, using
/// the average price actually paid for each brand as its cost basis. Buying
/// inventory that hasn't sold yet doesn't count as a loss here — it's still
/// an asset, not money lost. Only selling below cost does.
double calcRealizedProfit(
  List<Entry> sales,
  List<Entry> purchases,
  List<Brand> brands,
) {
  final costRates = costRateByBrand(purchases, brands);
  return sales.fold<double>(0, (sum, e) {
    final costRate = costRates[e.brandId] ?? 0;
    return sum + (e.amount - costRate * e.totalCFT);
  });
}

/// Stock on hand for a brand = everything purchased minus everything sold.
/// Can go negative if more was sold than was ever purchased (oversold).
double calcStock(double totalCFTPurchased, double totalCFTSold) {
  return totalCFTPurchased - totalCFTSold;
}
