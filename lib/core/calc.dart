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

double calcProfit(double totalSaleAmount, double totalPurchaseAmount) {
  return totalSaleAmount - totalPurchaseAmount;
}

/// Realized profit — margin actually earned on stock that's been sold,
/// using each brand's current purchase rate as its cost basis. Unlike
/// [calcProfit] (raw revenue minus all spend), buying inventory that
/// hasn't sold yet doesn't count as a loss here — it's still an asset,
/// not money lost. Only selling below cost does.
double calcRealizedProfit(List<Entry> sales, List<Brand> brands) {
  final costRateByBrand = {for (final b in brands) b.id: b.purchaseRate};
  return sales.fold<double>(0, (sum, e) {
    final costRate = costRateByBrand[e.brandId] ?? 0;
    return sum + (e.amount - costRate * e.totalCFT);
  });
}

/// Stock on hand for a brand = everything purchased minus everything sold.
/// Can go negative if more was sold than was ever purchased (oversold).
double calcStock(double totalCFTPurchased, double totalCFTSold) {
  return totalCFTPurchased - totalCFTSold;
}
