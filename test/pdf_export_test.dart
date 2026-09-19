import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock/core/models.dart';
import 'package:stock/core/reports.dart';
import 'package:stock/core/statement.dart';
import 'package:stock/data/pdf_export.dart';

Entry _entry(int i, {String party = 'Some Long Party Name Pvt Ltd'}) {
  final month = (i % 12) + 1;
  final day = (i % 27) + 1;
  return Entry(
    id: i,
    date:
        '2026-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
    party: party,
    brandId: 1,
    brandName: 'Retti (Silica) Fine Grade',
    cftPerVehicle: 100.5,
    round: 3,
    vehicleNo: i.isEven ? 'LEA-${1000 + i}' : null,
    totalCFT: 301.5,
    amount: 301.5 * 32.5,
  );
}

bool _isPdf(List<int> bytes) =>
    bytes.length > 1000 && latin1.decode(bytes.take(5).toList()) == '%PDF-';

void main() {
  test('a report far past 20 pages still builds (no page cap)', () async {
    // ~50 rows fit a page, so 1500 entries is around 30+ pages — this used
    // to throw "too many pages" with the library's default limit of 20.
    final entries = [for (var i = 0; i < 1500; i++) _entry(i)];
    final bytes = await buildEntryReportPdf(
      title: 'Purchase Report',
      businessName: 'Test Traders',
      entries: entries,
    );
    expect(_isPdf(bytes), isTrue);
  });

  test('merged report lists purchases and sales together', () async {
    final purchases = [for (var i = 0; i < 300; i++) _entry(i)];
    final sales = [for (var i = 300; i < 600; i++) _entry(i)];
    final bytes = await buildMergedReportPdf(
      businessName: null,
      purchases: purchases,
      sales: sales,
    );
    expect(_isPdf(bytes), isTrue);
  });

  test('party statement builds with full rows', () async {
    final statement = buildPartyStatement(
      partyName: 'Some Long Party Name Pvt Ltd',
      purchases: [for (var i = 0; i < 40; i++) _entry(i)],
      sales: [for (var i = 40; i < 80; i++) _entry(i)],
      money: [
        for (var i = 0; i < 30; i++)
          MoneyEntry(
            id: i,
            date: '2026-05-${(i % 27 + 1).toString().padLeft(2, '0')}',
            party: 'some long party name pvt ltd',
            amount: 1000.0 + i,
            type: i.isEven ? MoneyType.debit : MoneyType.credit,
          ),
      ],
    );
    expect(statement.lines, hasLength(110));
    final bytes = await buildPartyStatementPdf(
      partyName: 'Some Long Party Name Pvt Ltd',
      businessName: 'Test Traders',
      statement: statement,
      filters: 'All dates',
    );
    expect(_isPdf(bytes), isTrue);
  });

  test(
    'party statement builds with a balance brought forward, and empty',
    () async {
      final statement = buildPartyStatement(
        partyName: 'Some Long Party Name Pvt Ltd',
        purchases: [for (var i = 0; i < 40; i++) _entry(i)],
        sales: [for (var i = 40; i < 80; i++) _entry(i)],
        money: const [],
        range: DateRange(from: DateTime(2026, 6, 1)),
      );
      expect(statement.showsOpening, isTrue);
      expect(
        _isPdf(
          await buildPartyStatementPdf(
            partyName: 'Some Long Party Name Pvt Ltd',
            businessName: null,
            statement: statement,
            filters: '2026-06-01 to today',
          ),
        ),
        isTrue,
      );
      final empty = buildPartyStatement(
        partyName: 'Nobody',
        purchases: const [],
        sales: const [],
        money: const [],
      );
      expect(
        _isPdf(
          await buildPartyStatementPdf(
            partyName: 'Nobody',
            businessName: null,
            statement: empty,
          ),
        ),
        isTrue,
      );
    },
  );

  test('vehicle report builds for all vehicles and for one', () async {
    Entry withVehicle(int i, String? vehicleNo) => Entry(
      id: i,
      date: '2026-03-${(i % 27 + 1).toString().padLeft(2, '0')}',
      party: 'Some Long Party Name Pvt Ltd',
      brandId: 1,
      brandName: 'Retti (Silica) Fine Grade',
      cftPerVehicle: 980,
      round: 2,
      vehicleNo: vehicleNo,
      totalCFT: 1960,
      amount: 1960 * 32.5,
    );

    final purchases = [
      for (var i = 0; i < 200; i++)
        withVehicle(i, i.isEven ? 'TLM-954' : 'TAB-107'),
    ];
    final sales = [
      for (var i = 200; i < 400; i++)
        withVehicle(i, i % 3 == 0 ? null : 'TLM-954'),
    ];
    final groups = groupLedgerByVehicle(purchases, sales);
    expect(groups.map((g) => g.vehicleNo), ['TAB-107', 'TLM-954', null]);

    for (final showType in [true, false]) {
      final bytes = await buildVehicleReportPdf(
        businessName: 'Test Traders',
        title: 'Vehicle Report - All vehicles',
        filters: 'Purchase and Sale | All dates',
        groups: groups,
        showType: showType,
      );
      expect(_isPdf(bytes), isTrue);
    }
    final one = await buildVehicleReportPdf(
      businessName: null,
      title: 'Vehicle Statement - TLM-954',
      filters: 'Purchase only | 2026-01-01 to 2026-12-31',
      groups: [groups[1]],
      showType: false,
    );
    expect(_isPdf(one), isTrue);
  });

  test(
    'vehicle report builds with Debit and Credit, and money-only vehicles',
    () async {
      final trips = [
        for (var i = 0; i < 60; i++)
          Entry(
            id: i,
            date: '2026-03-${(i % 27 + 1).toString().padLeft(2, '0')}',
            party: 'Some Long Party Name Pvt Ltd',
            brandId: 1,
            brandName: 'Retti (Silica) Fine Grade',
            cftPerVehicle: 980,
            round: 2,
            vehicleNo: 'TLM-954',
            totalCFT: 1960,
            amount: 1960 * 32.5,
          ),
      ];
      final money = [
        for (var i = 0; i < 40; i++)
          MoneyEntry(
            id: i,
            date: '2026-03-${(i % 27 + 1).toString().padLeft(2, '0')}',
            vehicleNo: i % 4 == 0
                ? 'TKE-994'
                : 'TLM-954', // TKE-994 has no trips
            amount: 1000.0 + i,
            type: i.isEven ? MoneyType.debit : MoneyType.credit,
          ),
      ];
      final groups = groupLedgerByVehicle(trips, const [], money);
      expect(groups.map((g) => g.vehicleNo), ['TKE-994', 'TLM-954']);
      for (final showType in [true, false]) {
        expect(
          _isPdf(
            await buildVehicleReportPdf(
              businessName: 'Test Traders',
              title: 'Vehicle Report - All vehicles',
              filters: 'Purchase, Sale, Debit, Credit | All dates',
              groups: groups,
              showType: showType,
            ),
          ),
          isTrue,
        );
      }
      // Only money, no trips at all.
      expect(
        _isPdf(
          await buildVehicleReportPdf(
            businessName: null,
            title: 'Vehicle Statement - TKE-994',
            filters: 'Debit, Credit | All dates',
            groups: [groups.first],
            showType: false,
          ),
        ),
        isTrue,
      );
    },
  );

  test('reports with no entries still build', () async {
    expect(
      _isPdf(
        await buildEntryReportPdf(
          title: 'Sale Report',
          businessName: null,
          entries: const [],
        ),
      ),
      isTrue,
    );
    expect(
      _isPdf(
        await buildStockReportPdf(
          businessName: null,
          rows: const [
            StockReportRow(
              brandName: 'Crush 16mm',
              purchaseRate: 35,
              saleRate: 52,
              stockCft: 120,
            ),
          ],
        ),
      ),
      isTrue,
    );
  });
}
