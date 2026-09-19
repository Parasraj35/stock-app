// PDF report builders — the only file that touches the `pdf` package
// directly. Pure data in, PDF bytes out; screens hand the bytes to
// `printing`'s share/print sheet.
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/format.dart';
import '../core/models.dart';
import '../core/reports.dart';
import '../core/statement.dart';

// MultiPage stops at 20 pages by default and throws past that, which would
// make a long date range impossible to print — so lift the cap.
const _maxPages = 100000;
const _pageMargin = pw.EdgeInsets.all(30);

pw.Widget _header(String? businessName, String title, {String? filters}) {
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
      if (filters != null) ...[
        pw.SizedBox(height: 2),
        pw.Text(filters, style: const pw.TextStyle(fontSize: 10)),
      ],
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

/// One table column: header, width, and how to read its cell from a row.
class _Col<T> {
  _Col(this.header, this.width, this.cell, {this.numeric = false});
  final String header;
  final pw.TableColumnWidth width;
  final String Function(T) cell;
  final bool numeric;
}

/// The full voucher columns for an entry row. [typeOf] adds a Purchase/Sale
/// column (for tables that mix both); [showParty] drops the party column
/// where the whole table is already about one party.
List<_Col<T>> _entryCols<T>(
  Entry Function(T) entryOf, {
  String Function(T)? typeOf,
  bool showParty = true,
  bool showVehicle = true,
}) {
  String vehicle(T r) {
    final v = entryOf(r).vehicleNo;
    return (v == null || v.isEmpty) ? '-' : v;
  }

  return [
    _Col('Date', pw.FixedColumnWidth(54), (r) => entryOf(r).date),
    if (typeOf != null) _Col('Type', pw.FixedColumnWidth(40), typeOf),
    if (showParty)
      _Col('Party', pw.FlexColumnWidth(1.5), (r) => entryOf(r).party),
    _Col('Brand', pw.FlexColumnWidth(1.3), (r) => entryOf(r).brandName),
    if (showVehicle) _Col('Vehicle', pw.FlexColumnWidth(1), vehicle),
    _Col(
      'Round x CFT',
      pw.FixedColumnWidth(54),
      (r) =>
          '${formatDecimal(entryOf(r).round)} x ${formatDecimal(entryOf(r).cftPerVehicle)}',
      numeric: true,
    ),
    _Col(
      'CFT',
      pw.FixedColumnWidth(40),
      (r) => formatGroupedNumber(entryOf(r).totalCFT),
      numeric: true,
    ),
    _Col(
      'Rate',
      pw.FixedColumnWidth(34),
      (r) => formatDecimal(entryOf(r).ratePerCft),
      numeric: true,
    ),
    _Col(
      'Amount (Rs)',
      pw.FixedColumnWidth(60),
      (r) => formatGroupedNumber(entryOf(r).amount),
      numeric: true,
    ),
  ];
}

pw.Widget _table<T>(List<_Col<T>> cols, List<T> rows) {
  final align = {
    for (var i = 0; i < cols.length; i++)
      if (cols[i].numeric) i: pw.Alignment.centerRight,
  };
  return pw.TableHelper.fromTextArray(
    headers: [for (final c in cols) c.header],
    data: [
      for (final r in rows) [for (final c in cols) c.cell(r)],
    ],
    columnWidths: {for (var i = 0; i < cols.length; i++) i: cols[i].width},
    cellAlignments: align,
    headerAlignments: align,
    headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
    cellStyle: const pw.TextStyle(fontSize: 8),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
  );
}

pw.Widget _monthHeading(String title, String detail) {
  return pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(top: 12, bottom: 4),
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    color: PdfColors.grey200,
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(detail, style: const pw.TextStyle(fontSize: 9)),
      ],
    ),
  );
}

String _purchaseOrSale(PartyLedgerEntry l) =>
    l.isPurchase ? 'Purchase' : 'Sale';

/// Purchase or Sale report — every entry, grouped month by month with each
/// month's subtotal, and a grand total at the end.
Future<Uint8List> buildEntryReportPdf({
  required String title,
  required String? businessName,
  required List<Entry> entries,
}) async {
  final groups = groupEntriesByMonth(entries);
  final totalCft = entries.fold<double>(0, (sum, e) => sum + e.totalCFT);
  final totalAmount = entries.fold<double>(0, (sum, e) => sum + e.amount);
  final cols = _entryCols<Entry>((e) => e);
  final summary =
      '${entries.length} entries | ${formatGroupedNumber(totalCft)} cft | ${formatPkrCurrency(totalAmount)}';

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      maxPages: _maxPages,
      margin: _pageMargin,
      build: (context) => [
        _header(businessName, title),
        pw.SizedBox(height: 4),
        pw.Text(
          summary,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
        ),
        for (final g in groups) ...[
          _monthHeading(
            formatMonthLabel(g.total.monthKey),
            '${g.total.count} entries | ${formatGroupedNumber(g.total.totalCft)} cft | ${formatPkrCurrency(g.total.totalAmount)}',
          ),
          _table(cols, g.entries),
        ],
        pw.SizedBox(height: 10),
        pw.Divider(),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Grand total: $summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );
  return doc.save();
}

/// One row of the party statement table, already turned into text. Goods
/// (sale, purchase) fill every column; money (debit, credit) only the amount.
class _StatementRow {
  const _StatementRow({
    required this.date,
    required this.type,
    required this.balance,
    this.brand = '-',
    this.vehicle = '-',
    this.roundCft = '-',
    this.cft = '-',
    this.rate = '-',
    this.amount = '',
  });
  final String date;
  final String type;
  final String brand;
  final String vehicle;
  final String roundCft;
  final String cft;
  final String rate;
  final String amount;
  final String balance;
}

/// A party's statement: every sale, purchase, debit and credit in date order
/// with a running balance, then the totals and the closing balance in words.
/// With a From date the first row is the balance brought forward.
Future<Uint8List> buildPartyStatementPdf({
  required String partyName,
  required String? businessName,
  required PartyStatement statement,
  String? filters,
}) async {
  String balanceText(double b) => formatBalance(b, withCurrency: false);
  String vehicleOf(Entry e) {
    final v = e.vehicleNo;
    return (v == null || v.isEmpty) ? '-' : v;
  }

  final rows = <_StatementRow>[
    if (statement.showsOpening)
      _StatementRow(
        date: '',
        type: 'Opening',
        brand: 'Balance brought forward',
        balance: balanceText(statement.opening),
      ),
    for (final l in statement.lines)
      if (l.trade != null)
        _StatementRow(
          date: l.date,
          type: l.kind.label,
          brand: l.trade!.brandName,
          vehicle: vehicleOf(l.trade!),
          roundCft:
              '${formatDecimal(l.trade!.round)} x ${formatDecimal(l.trade!.cftPerVehicle)}',
          cft: formatGroupedNumber(l.trade!.totalCFT),
          rate: formatDecimal(l.trade!.ratePerCft),
          amount: formatGroupedNumber(l.amount),
          balance: balanceText(l.balance),
        )
      else
        _StatementRow(
          date: l.date,
          type: l.kind.label,
          amount: formatGroupedNumber(l.amount),
          balance: balanceText(l.balance),
        ),
  ];
  final cols = <_Col<_StatementRow>>[
    _Col('Date', pw.FixedColumnWidth(54), (r) => r.date),
    _Col('Type', pw.FixedColumnWidth(44), (r) => r.type),
    _Col('Brand', pw.FlexColumnWidth(1.3), (r) => r.brand),
    _Col('Vehicle', pw.FlexColumnWidth(1), (r) => r.vehicle),
    _Col(
      'Round x CFT',
      pw.FixedColumnWidth(54),
      (r) => r.roundCft,
      numeric: true,
    ),
    _Col('CFT', pw.FixedColumnWidth(40), (r) => r.cft, numeric: true),
    _Col('Rate', pw.FixedColumnWidth(34), (r) => r.rate, numeric: true),
    _Col(
      'Amount (Rs)',
      pw.FixedColumnWidth(58),
      (r) => r.amount,
      numeric: true,
    ),
    _Col(
      'Balance (Rs)',
      pw.FixedColumnWidth(84),
      (r) => r.balance,
      numeric: true,
    ),
  ];

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      maxPages: _maxPages,
      margin: _pageMargin,
      build: (context) => [
        _header(businessName, 'Party Statement - $partyName', filters: filters),
        pw.SizedBox(height: 8),
        _table(cols, rows),
        pw.SizedBox(height: 12),
        pw.Divider(),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Total sold: ${formatPkrCurrency(statement.sold)}'),
              pw.Text(
                'Total purchased: ${formatPkrCurrency(statement.purchased)}',
              ),
              pw.Text(
                'Total debit (money given): ${formatPkrCurrency(statement.debit)}',
              ),
              pw.Text(
                'Total credit (money received): ${formatPkrCurrency(statement.credit)}',
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Closing balance: ${formatBalanceWith(partyName, statement.closing)}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Sale and Debit raise what the party owes you; Purchase and Credit lower it.',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
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
      maxPages: _maxPages,
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

/// Purchase and Sale together — every entry, grouped month by month with
/// that month's purchase, sale and net.
Future<Uint8List> buildMergedReportPdf({
  required String? businessName,
  required List<Entry> purchases,
  required List<Entry> sales,
}) async {
  final groups = groupLedgerByMonth(purchases, sales);
  final totalPurchase = purchases.fold<double>(0, (sum, e) => sum + e.amount);
  final totalSale = sales.fold<double>(0, (sum, e) => sum + e.amount);
  final cols = _entryCols<PartyLedgerEntry>(
    (l) => l.entry,
    typeOf: _purchaseOrSale,
  );

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      maxPages: _maxPages,
      margin: _pageMargin,
      build: (context) => [
        _header(businessName, 'Purchase & Sale Report'),
        pw.SizedBox(height: 4),
        for (final g in groups) ...[
          _monthHeading(
            formatMonthLabel(g.monthKey),
            'Buy ${formatPkrCurrency(g.purchaseAmount)} | Sell ${formatPkrCurrency(g.saleAmount)} | Net ${formatPkrCurrency(g.profit)}',
          ),
          _table(cols, g.lines),
        ],
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

/// Vehicles — one section per vehicle with every purchase/sale (trip) on it
/// and its totals, then its Debit and Credit entries with their balance, then
/// a grand total. [showType] adds a Purchase/Sale column when both are
/// included.
Future<Uint8List> buildVehicleReportPdf({
  required String? businessName,
  required String title,
  required String filters,
  required List<VehicleGroup> groups,
  required bool showType,
}) async {
  final cols = _entryCols<PartyLedgerEntry>(
    (l) => l.entry,
    typeOf: showType ? _purchaseOrSale : null,
    showVehicle: false,
  );
  final moneyCols = <_Col<MoneyEntry>>[
    _Col('Date', pw.FixedColumnWidth(64), (e) => e.date),
    _Col('Type', pw.FixedColumnWidth(54), (e) => e.type.label),
    _Col(
      'Rupees',
      pw.FlexColumnWidth(1),
      (e) => formatGroupedNumber(e.amount),
      numeric: true,
    ),
  ];
  final entries = groups.fold<int>(0, (sum, g) => sum + g.lines.length);
  final rounds = groups.fold<double>(0, (sum, g) => sum + g.rounds);
  final totalCft = groups.fold<double>(0, (sum, g) => sum + g.totalCft);
  final purchased = groups.fold<double>(0, (sum, g) => sum + g.purchaseAmount);
  final sold = groups.fold<double>(0, (sum, g) => sum + g.saleAmount);
  final debit = groups.fold<double>(0, (sum, g) => sum + g.debit);
  final credit = groups.fold<double>(0, (sum, g) => sum + g.credit);
  final hasMoney = groups.any((g) => g.money.isNotEmpty);

  String amounts(double purchase, double sale) => showType
      ? 'Buy ${formatPkrCurrency(purchase)} | Sell ${formatPkrCurrency(sale)}'
      : formatPkrCurrency(purchase + sale);

  String moneyTotals(double debit, double credit) =>
      'Debit ${formatPkrCurrency(debit)} | Credit ${formatPkrCurrency(credit)} | Balance: ${formatBalance(debit - credit)}';

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      maxPages: _maxPages,
      margin: _pageMargin,
      build: (context) => [
        _header(businessName, title, filters: filters),
        pw.SizedBox(height: 4),
        for (final g in groups) ...[
          _monthHeading(
            g.vehicleNo ?? 'No vehicle',
            g.lines.isEmpty
                ? 'No trips'
                : '${g.lines.length} entries | ${formatDecimal(g.rounds)} rounds | ${formatGroupedNumber(g.totalCft)} cft | ${amounts(g.purchaseAmount, g.saleAmount)}',
          ),
          if (g.lines.isNotEmpty) _table(cols, g.lines),
          if (g.money.isNotEmpty) ...[
            _monthHeading('Debit & Credit', moneyTotals(g.debit, g.credit)),
            _table(moneyCols, g.money),
          ],
        ],
        pw.SizedBox(height: 12),
        pw.Divider(),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (entries > 0)
                pw.Text(
                  'Grand total: $entries entries | ${formatDecimal(rounds)} rounds | ${formatGroupedNumber(totalCft)} cft | ${amounts(purchased, sold)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              if (hasMoney) ...[
                pw.Text(
                  'Debit & Credit total: ${moneyTotals(debit, credit)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Balance = Debit - Credit. "Owes you" means you gave more than you got back.',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
  return doc.save();
}

/// Debit & Credit — every entry, month by month with each month's debit and
/// credit, then a grand total. [showType] adds a Debit/Credit column when
/// both are included; [showParty] / [showVehicle] pick the Party and Vehicle
/// columns (an entry is for one or the other, the other shows "-").
Future<Uint8List> buildMoneyReportPdf({
  required String? businessName,
  required String title,
  required String filters,
  required List<MoneyMonthGroup> groups,
  required bool showType,
  bool showParty = true,
  bool showVehicle = true,
}) async {
  final cols = <_Col<MoneyEntry>>[
    _Col('Date', pw.FixedColumnWidth(64), (e) => e.date),
    if (showType) _Col('Type', pw.FixedColumnWidth(54), (e) => e.type.label),
    if (showParty) _Col('Party', pw.FlexColumnWidth(1), (e) => e.party ?? '-'),
    if (showVehicle)
      _Col('Vehicle', pw.FlexColumnWidth(1), (e) => e.vehicleNo ?? '-'),
    _Col(
      'Rupees',
      pw.FixedColumnWidth(96),
      (e) => formatGroupedNumber(e.amount),
      numeric: true,
    ),
  ];
  final all = [for (final g in groups) ...g.entries];

  String totals(List<MoneyEntry> entries) =>
      'Debit ${formatPkrCurrency(entries.debit)} | Credit ${formatPkrCurrency(entries.credit)}';

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      maxPages: _maxPages,
      margin: _pageMargin,
      build: (context) => [
        _header(businessName, title, filters: filters),
        pw.SizedBox(height: 4),
        for (final g in groups) ...[
          _monthHeading(
            formatMonthLabel(g.monthKey),
            '${g.entries.length} entries | ${totals(g.entries)}',
          ),
          _table(cols, g.entries),
        ],
        pw.SizedBox(height: 12),
        pw.Divider(),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Grand total: ${all.length} entries | ${totals(all)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );
  return doc.save();
}

/// Diesel — a "litres by vehicle" summary (when more than one vehicle is in
/// the report), then every entry month by month (date, vehicle, litres,
/// price, total), and at the very end the total litres and total amount.
Future<Uint8List> buildDieselReportPdf({
  required String? businessName,
  required String title,
  required String filters,
  required List<DieselMonthGroup> groups,
  required List<DieselVehicleTotal> byVehicle,
}) async {
  final cols = <_Col<DieselEntry>>[
    _Col('Date', pw.FixedColumnWidth(64), (e) => e.date),
    _Col('Vehicle', pw.FlexColumnWidth(1), (e) => e.vehicleNo),
    _Col(
      'Litres',
      pw.FixedColumnWidth(64),
      (e) => formatLitres(e.litres),
      numeric: true,
    ),
    _Col(
      'Price (Rs/L)',
      pw.FixedColumnWidth(70),
      (e) => formatDecimal(e.price),
      numeric: true,
    ),
    _Col(
      'Total (Rs)',
      pw.FixedColumnWidth(80),
      (e) => formatGroupedNumber(e.total),
      numeric: true,
    ),
  ];
  final vehicleCols = <_Col<DieselVehicleTotal>>[
    _Col('Vehicle', pw.FlexColumnWidth(1), (v) => v.vehicleNo),
    _Col(
      'Fill-ups',
      pw.FixedColumnWidth(54),
      (v) => v.fills.toString(),
      numeric: true,
    ),
    _Col(
      'Litres',
      pw.FixedColumnWidth(80),
      (v) => formatLitres(v.litres),
      numeric: true,
    ),
    _Col(
      'Total (Rs)',
      pw.FixedColumnWidth(90),
      (v) => formatGroupedNumber(v.amount),
      numeric: true,
    ),
  ];
  final all = [for (final g in groups) ...g.entries];

  String totals(List<DieselEntry> entries) =>
      '${formatLitres(entries.litres)} L | ${formatPkrCurrency(entries.amount)}';

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      maxPages: _maxPages,
      margin: _pageMargin,
      build: (context) => [
        _header(businessName, title, filters: filters),
        pw.SizedBox(height: 4),
        if (byVehicle.length > 1) ...[
          _monthHeading('Litres by vehicle', '${byVehicle.length} vehicles'),
          _table(vehicleCols, byVehicle),
        ],
        for (final g in groups) ...[
          _monthHeading(
            formatMonthLabel(g.monthKey),
            '${g.entries.length} ${g.entries.length == 1 ? 'entry' : 'entries'} | ${totals(g.entries)}',
          ),
          _table(cols, g.entries),
        ],
        pw.SizedBox(height: 12),
        pw.Divider(),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Total of ${all.length} ${all.length == 1 ? 'entry' : 'entries'}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Total litres: ${formatLitres(all.litres)} L',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Total amount: ${formatPkrCurrency(all.amount)}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  return doc.save();
}
