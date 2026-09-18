// PDF report builders — the only file that touches the `pdf` package
// directly. Pure data in, PDF bytes out; screens hand the bytes to
// `printing`'s share/print sheet.
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/format.dart';
import '../core/models.dart';
import '../core/reports.dart';

pw.Widget _header(String? businessName, String title) {
  final name = (businessName != null && businessName.isNotEmpty)
      ? businessName
      : 'Stock';
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        name,
        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        title,
        style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        'Generated ${DateTime.now().toString().split('.').first}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
      ),
      pw.SizedBox(height: 8),
      pw.Divider(),
    ],
  );
}

/// Purchase or Sale report — every entry plus a monthly breakdown table.
Future<Uint8List> buildEntryReportPdf({
  required String title,
  required String? businessName,
  required List<Entry> entries,
}) async {
  final monthly = monthlyTotals(entries);
  final totalCount = entries.length;
  final totalCft = entries.fold<double>(0, (sum, e) => sum + e.totalCFT);
  final totalAmount = entries.fold<double>(0, (sum, e) => sum + e.amount);

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      build: (context) => [
        _header(businessName, title),
        pw.SizedBox(height: 12),
        pw.Text(
          'Monthly breakdown',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Month', 'Entries', 'Total CFT', 'Amount'],
          data: [
            for (final m in monthly)
              [
                formatMonthLabel(m.monthKey),
                '${m.count}',
                formatGroupedNumber(m.totalCft),
                formatPkrCurrency(m.totalAmount),
              ],
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'All entries',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: [
            'Date',
            'Party',
            'Brand',
            'Round×CFT',
            'Total CFT',
            'Amount',
          ],
          data: [
            for (final e in entries)
              [
                e.date,
                e.party,
                e.brandName,
                '${e.round.toStringAsFixed(0)}×${e.cftPerVehicle.toStringAsFixed(0)}',
                formatGroupedNumber(e.totalCFT),
                formatPkrCurrency(e.amount),
              ],
          ],
        ),
        pw.Divider(),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Grand total: $totalCount entries • ${formatGroupedNumber(totalCft)} cft • ${formatPkrCurrency(totalAmount)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );
  return doc.save();
}

/// A single party's full purchase+sale history with running totals.
Future<Uint8List> buildPartyStatementPdf({
  required String partyName,
  required String? businessName,
  required List<Entry> purchases,
  required List<Entry> sales,
}) async {
  final history = partyHistory(partyName, purchases, sales);
  final totalPurchaseAmount = purchases
      .where((e) => e.party == partyName)
      .fold<double>(0, (sum, e) => sum + e.amount);
  final totalSaleAmount = sales
      .where((e) => e.party == partyName)
      .fold<double>(0, (sum, e) => sum + e.amount);

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      build: (context) => [
        _header(businessName, 'Party Statement — $partyName'),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Type', 'Brand', 'Total CFT', 'Amount'],
          data: [
            for (final line in history)
              [
                line.entry.date,
                line.isPurchase ? 'Purchase' : 'Sale',
                line.entry.brandName,
                formatGroupedNumber(line.entry.totalCFT),
                formatPkrCurrency(line.entry.amount),
              ],
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Divider(),
        pw.Text('Total purchased: ${formatPkrCurrency(totalPurchaseAmount)}'),
        pw.Text('Total sold: ${formatPkrCurrency(totalSaleAmount)}'),
        pw.Text(
          'Net: ${formatPkrCurrency(totalSaleAmount - totalPurchaseAmount)}',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );
  return doc.save();
}

class StockReportRow {
  final String brandName;
  final double purchaseRate;
  final double saleRate;
  final double stockCft;
  const StockReportRow({
    required this.brandName,
    required this.purchaseRate,
    required this.saleRate,
    required this.stockCft,
  });
}

/// Current stock on hand per brand.
Future<Uint8List> buildStockReportPdf({
  required String? businessName,
  required List<StockReportRow> rows,
}) async {
  final totalStock = rows.fold<double>(0, (sum, r) => sum + r.stockCft);
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      build: (context) => [
        _header(businessName, 'Stock Report'),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: ['Brand', 'Buy Rate', 'Sell Rate', 'Stock (cft)'],
          data: [
            for (final r in rows)
              [
                r.brandName,
                formatPkrCurrency(r.purchaseRate),
                formatPkrCurrency(r.saleRate),
                formatGroupedNumber(r.stockCft),
              ],
          ],
        ),
        pw.Divider(),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Total stock: ${formatGroupedNumber(totalStock)} cft across ${rows.length} brands',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );
  return doc.save();
}

/// Purchase and Sale side by side per month, with net profit — the
/// combined report.
Future<Uint8List> buildMergedReportPdf({
  required String? businessName,
  required List<Entry> purchases,
  required List<Entry> sales,
}) async {
  final merged = mergedMonthlyTotals(purchases, sales);
  final totalPurchase = purchases.fold<double>(0, (sum, e) => sum + e.amount);
  final totalSale = sales.fold<double>(0, (sum, e) => sum + e.amount);
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      build: (context) => [
        _header(businessName, 'Purchase & Sale Report'),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: ['Month', 'Purchase', 'Sale', 'Profit'],
          data: [
            for (final m in merged)
              [
                formatMonthLabel(m.monthKey),
                formatPkrCurrency(m.purchaseAmount),
                formatPkrCurrency(m.saleAmount),
                formatPkrCurrency(m.profit),
              ],
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Divider(),
        pw.Text('Total purchased: ${formatPkrCurrency(totalPurchase)}'),
        pw.Text('Total sold: ${formatPkrCurrency(totalSale)}'),
        pw.Text(
          'Net profit: ${formatPkrCurrency(totalSale - totalPurchase)}',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
        ),
      ],
    ),
  );
  return doc.save();
}
