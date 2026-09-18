// Framework-free business logic. No DOM, no storage — pure functions only,
// so this module can be reused as-is if the UI is ever rewritten.

export function calcTotalCFT(round, cftPerVehicle) {
  return round * cftPerVehicle;
}

export function calcAmount(totalCFT, ratePerCft) {
  return totalCFT * ratePerCft;
}

// Convenience: derive totalCFT + amount together from raw entry fields + brand rate.
export function calcEntryTotals(round, cftPerVehicle, ratePerCft) {
  const totalCFT = calcTotalCFT(round, cftPerVehicle);
  const amount = calcAmount(totalCFT, ratePerCft);
  return { totalCFT, amount };
}

export function calcProfit(totalSaleAmount, totalPurchaseAmount) {
  return totalSaleAmount - totalPurchaseAmount;
}
