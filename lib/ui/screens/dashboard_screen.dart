import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/calc.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/trends.dart'
    show TrendPoint, dailyRealizedProfitSeries, monthOverMonthChangePercent;
import '../../data/data_bus.dart';
import '../../data/repos.dart';
import '../theme/tokens.dart';
import '../widgets/metric_cards.dart';
import '../widgets/profile_header_button.dart';
import '../widgets/trend_chart.dart';
import 'brands_screen.dart';
import 'entry_form_screen.dart';
import 'parties_screen.dart';
import 'stock_screen.dart';

class _Totals {
  final int totalBrands;
  final int totalParties;
  final double totalPurchaseAmount;
  final double totalSaleAmount;
  final double totalCFTPurchased;
  final double totalCFTSold;
  final double profit;
  final List<TrendPoint> profitTrend;
  final double? purchaseChangePercent;
  final double? saleChangePercent;
  final List<Brand> brands;
  final List<Party> parties;

  const _Totals({
    required this.totalBrands,
    required this.totalParties,
    required this.totalPurchaseAmount,
    required this.totalSaleAmount,
    required this.totalCFTPurchased,
    required this.totalCFTSold,
    required this.profit,
    required this.profitTrend,
    required this.purchaseChangePercent,
    required this.saleChangePercent,
    required this.brands,
    required this.parties,
  });

  double get stockCft => calcStock(totalCFTPurchased, totalCFTSold);
}

/// All figures are derived live from brands/purchases/sales — nothing here
/// is stored redundantly.
Future<_Totals> _loadTotals({int trendDays = 7}) async {
  final results = await Future.wait([
    Repos.instance.brands.list(),
    Repos.instance.purchases.list(),
    Repos.instance.sales.list(),
    Repos.instance.parties.list(),
  ]);
  final brands = results[0] as List<Brand>;
  final purchases = results[1] as List<Entry>;
  final sales = results[2] as List<Entry>;
  final parties = results[3] as List<Party>;

  final totalPurchaseAmount = purchases.fold<double>(
    0,
    (sum, e) => sum + e.amount,
  );
  final totalSaleAmount = sales.fold<double>(0, (sum, e) => sum + e.amount);
  final totalCFTPurchased = purchases.fold<double>(
    0,
    (sum, e) => sum + e.totalCFT,
  );
  final totalCFTSold = sales.fold<double>(0, (sum, e) => sum + e.totalCFT);

  return _Totals(
    totalBrands: brands.length,
    totalParties: parties.length,
    totalPurchaseAmount: totalPurchaseAmount,
    totalSaleAmount: totalSaleAmount,
    totalCFTPurchased: totalCFTPurchased,
    totalCFTSold: totalCFTSold,
    profit: calcRealizedProfit(sales, purchases, brands),
    profitTrend: dailyRealizedProfitSeries(
      sales,
      purchases,
      brands,
      days: trendDays,
    ),
    purchaseChangePercent: monthOverMonthChangePercent(purchases),
    saleChangePercent: monthOverMonthChangePercent(sales),
    brands: brands,
    parties: parties,
  );
}

/// Dashboard — the one screen this enhancement pass touches. If this look
/// (shadowed cards, count-up numbers, profit/loss tag + sparkline, pull to
/// refresh) is approved, the same treatment gets rolled out everywhere else.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_Totals> _future;
  ChartStyle _chartStyle = ChartStyle.line;
  int _trendDays = 7;

  @override
  void initState() {
    super.initState();
    _future = _loadTotals(trendDays: _trendDays);
    DataBus.instance.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    DataBus.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (!mounted) return;
    setState(() => _future = _loadTotals(trendDays: _trendDays));
  }

  Future<void> _refresh() async {
    final next = _loadTotals(trendDays: _trendDays);
    setState(() => _future = next);
    await next;
  }

  void _setChartStyle(ChartStyle style) => setState(() => _chartStyle = style);

  void _setTrendDays(int days) {
    setState(() {
      _trendDays = days;
      _future = _loadTotals(trendDays: days);
    });
  }

  static String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String get _today {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        heroTag: 'dashboardFab',
        onPressed: () => _quickAdd(context),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _today,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.headerSubtitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const ProfileHeaderButton(),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<_Totals>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final t = snapshot.data!;
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    color: AppColors.primary,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenPadding,
                        AppSpacing.screenPadding,
                        AppSpacing.screenPadding,
                        32,
                      ),
                      children: [
                        _GlowingHero(profit: t.profit),
                        const SizedBox(height: AppSpacing.sectionGap),
                        _ProfitTrendSection(
                          points: t.profitTrend,
                          style: _chartStyle,
                          trendDays: _trendDays,
                          onStyleChanged: _setChartStyle,
                          onTrendDaysChanged: _setTrendDays,
                        ),
                        const SizedBox(height: AppSpacing.sectionGap),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: HalfMetricCard(
                                  label: 'Purchase',
                                  amount: t.totalPurchaseAmount,
                                  cft: t.totalCFTPurchased,
                                  palette: MetricPalette.purchase,
                                  changePercent: t.purchaseChangePercent,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.cardGap),
                              Expanded(
                                child: HalfMetricCard(
                                  label: 'Sale',
                                  amount: t.totalSaleAmount,
                                  cft: t.totalCFTSold,
                                  palette: MetricPalette.sale,
                                  changePercent: t.saleChangePercent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sectionGap),
                        Row(
                          children: [
                            Expanded(
                              child: CountCard(
                                label: 'Parties',
                                count: t.totalParties,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PartiesScreen(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.cardGap),
                            Expanded(
                              child: CountCard(
                                label: 'Brands',
                                count: t.totalBrands,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BrandsScreen(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sectionGap),
                        Card(
                          elevation: 1.5,
                          shadowColor: Colors.black.withValues(alpha: 0.08),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadii.card),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StockScreen(),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.inventory_2_outlined,
                                      color: AppColors.accent,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Stock Overview',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${formatGroupedNumber(t.stockCft)} cft across ${t.totalBrands} brands',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: AppColors.inactiveIcon,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _quickAdd(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.card),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.south_west, color: AppColors.purchaseColor),
              title: const Text('Add purchase'),
              onTap: () => Navigator.pop(context, 'purchase'),
            ),
            ListTile(
              leading: Icon(Icons.north_east, color: AppColors.saleColor),
              title: const Text('Add sale'),
              onTap: () => Navigator.pop(context, 'sale'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    final isPurchase = choice == 'purchase';
    await openEntryForm(
      context,
      title: isPurchase ? 'Purchase' : 'Sale',
      repository: isPurchase ? Repos.instance.purchases : Repos.instance.sales,
    );
  }
}

/// Soft blurred color glow behind the hero profit card — mint when
/// profitable, rose when at a loss — echoing the Auth screen's blob header
/// without obscuring the readable card content on top.
class _GlowingHero extends StatelessWidget {
  const _GlowingHero({required this.profit});
  final double profit;

  @override
  Widget build(BuildContext context) {
    final glowColor = profit >= 0 ? AppColors.accent : AppColors.negative;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 14,
          left: 20,
          right: 20,
          bottom: -10,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: glowColor.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
            ),
          ),
        ),
        HeroProfitCard(profit: profit),
      ],
    );
  }
}

/// Profit trend section — user-selectable chart type (line/bar) and time
/// window (7/30 days), backed by the same daily net-profit series.
class _ProfitTrendSection extends StatelessWidget {
  const _ProfitTrendSection({
    required this.points,
    required this.style,
    required this.trendDays,
    required this.onStyleChanged,
    required this.onTrendDaysChanged,
  });

  final List<TrendPoint> points;
  final ChartStyle style;
  final int trendDays;
  final ValueChanged<ChartStyle> onStyleChanged;
  final ValueChanged<int> onTrendDaysChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Profit Trend',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                _PeriodToggle(days: trendDays, onChanged: onTrendDaysChanged),
                const SizedBox(width: 8),
                _StyleToggle(style: style, onChanged: onStyleChanged),
              ],
            ),
            const SizedBox(height: 12),
            TrendChart(
              points: points,
              style: style,
              positiveColor: AppColors.accent,
              negativeColor: AppColors.negative,
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.days, required this.onChanged});
  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final d in [7, 30])
            GestureDetector(
              onTap: () => onChanged(d),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: days == d ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '${d}D',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: days == d ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StyleToggle extends StatelessWidget {
  const _StyleToggle({required this.style, required this.onChanged});
  final ChartStyle style;
  final ValueChanged<ChartStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in ChartStyle.values)
            GestureDetector(
              onTap: () => onChanged(s),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: style == s ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  s == ChartStyle.line ? Icons.show_chart : Icons.bar_chart,
                  size: 15,
                  color: style == s ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
