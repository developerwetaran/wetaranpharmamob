import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wetaran_pharma/core/widgets/reusable_pharma_header.dart';
import 'package:wetaran_pharma/features/orders/models/pharma_cart_provider.dart';
import 'package:wetaran_pharma/features/orders/presentation/widgets/pharma_cart_sheet.dart';

const headingColor = Color(0xFF0F172A);
const mutedColor = Color(0xFF64748B);
const borderColor = Color(0xFFE2E8F0);
const pageBg = Color(0xFFF8FAFC);
const kBlue = Color(0xFF0B4F8A);
const kBlueDk = Color(0xFF083A66);
const greenSoft = Color(0xFFDCFCE7);
const green = Color(0xFF16A34A);
const amberSoft = Color(0xFFFFEDD5);
const amber = Color(0xFFD97706);
const redSoft = Color(0xFFFEE2E2);
const red = Color(0xFFDC2626);

Widget appCard({
  required Widget child,
  EdgeInsets padding = const EdgeInsets.all(14),
}) {
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class ReportsPage extends StatefulWidget {
  final VoidCallback onOpenDrawer;

  const ReportsPage({super.key, required this.onOpenDrawer});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  String? _pharmaUserId;

  List<_TrendItem> _monthlyTrend = [];
  List<_DistributorItem> _distributors = [];
  List<_FastMoverItem> _fastMovers = [];
  List<_SavingItem> _savings = [];

  String _currentMonthLabel = DateFormat('MMMM').format(DateTime.now());
  String _totalAdvantage = '₹0';

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  void _log(String message) {
    debugPrint('[ReportsPage] $message');
  }

  Future<void> _loadReports() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _log('1. loadReports started');

      final authUser = _supabase.auth.currentUser;
      final authUserId = authUser?.id;
      _log('2. auth user id = $authUserId');

      if (authUserId == null) {
        throw Exception('No logged-in user found');
      }

      final pharmaProfile = await _supabase
          .from('pharma_users')
          .select('id')
          .eq('auth_user_id', authUserId)
          .maybeSingle();

      _log('3. pharma profile = $pharmaProfile');

      if (pharmaProfile == null) {
        throw Exception('Pharma user profile not found');
      }

      final pharmaUserId = (pharmaProfile['id'] ?? '').toString();
      _log('4. pharma user id = $pharmaUserId');

      if (pharmaUserId.isEmpty) {
        throw Exception('Invalid pharma user id');
      }

      final rows = await _supabase
          .from('orders')
          .select('''
      id,
      order_id,
      total_amount,
      status,
      status,
      order_date,
      notes,
      products,
      distributor:distributor_id (
        id,
        company_name,
        company_phone,
        company_email,
        contact_name,
        contact_phone,
        contact_email,
        gstin,
        drug_license_no,
        registered_office_address,
        warehouse_address,
        partner_type,
        status,
        is_active,
        service_coverage,
        pharma_expected_delivery,
        pharma_same_day_order_cutoff
      )
    ''')
          .eq('pharma_user_id', pharmaUserId)
          .inFilter('status', ['Approved', 'Delivered', 'Dispatched'])
          .order('order_date', ascending: false);

      final orders = List<Map<String, dynamic>>.from(rows);
      _log('5. orders fetched = ${orders.length}');

      final now = DateTime.now();
      _currentMonthLabel = DateFormat('MMMM').format(now);

      final trend = _buildMonthlyTrend(orders, now);
      final distributorSplit = _buildDistributorSplit(orders, now);
      final fastMovers = _buildFastMovers(orders, now);
      final savings = _buildSavings(orders, now);

      final totalAdvantageValue = savings.fold<double>(
        0,
        (sum, item) => sum + item.rawValue,
      );

      if (!mounted) return;

      setState(() {
        _pharmaUserId = pharmaUserId;
        _monthlyTrend = trend;
        _distributors = distributorSplit;
        _fastMovers = fastMovers;
        _savings = savings;
        _totalAdvantage = _formatMoney(totalAdvantageValue);
        _loading = false;
      });

      _log('6. state updated successfully');
    } catch (e, st) {
      _log('ERROR = $e');
      debugPrintStack(label: 'REPORTS_STACK', stackTrace: st);

      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<_TrendItem> _buildMonthlyTrend(
    List<Map<String, dynamic>> orders,
    DateTime now,
  ) {
    final monthStarts = List<DateTime>.generate(6, (index) {
      final m = DateTime(now.year, now.month - 5 + index, 1);
      return DateTime(m.year, m.month, 1);
    });

    final Map<String, double> totals = {
      for (final month in monthStarts) _monthKey(month): 0,
    };

    for (final order in orders) {
      final orderDate = _parseDate(order['order_date']);
      if (orderDate == null) continue;

      final key = _monthKey(DateTime(orderDate.year, orderDate.month, 1));
      if (!totals.containsKey(key)) continue;

      totals[key] = (totals[key] ?? 0) + _toDouble(order['total_amount']);
    }

    final maxValue = totals.values.fold<double>(0, math.max);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    return monthStarts.map((month) {
      final key = _monthKey(month);
      final amount = totals[key] ?? 0;
      final lakhs = amount / 100000;
      final heightFactor = amount <= 0
          ? 0.12
          : (amount / safeMax).clamp(0.18, 1.0);

      final isCurrentMonth = month.year == now.year && month.month == now.month;

      return _TrendItem(
        month: DateFormat('MMM').format(month),
        value: lakhs,
        heightFactor: heightFactor,
        highlight: isCurrentMonth,
      );
    }).toList();
  }

  List<_DistributorItem> _buildDistributorSplit(
    List<Map<String, dynamic>> orders,
    DateTime now,
  ) {
    final Map<String, double> totalsByDistributor = {};

    double monthTotal = 0;

    for (final order in orders) {
      final orderDate = _parseDate(order['order_date']);
      if (orderDate == null) continue;

      if (orderDate.year != now.year || orderDate.month != now.month) {
        continue;
      }

      final distributorMap = order['distributor'] is Map
          ? Map<String, dynamic>.from(order['distributor'] as Map)
          : <String, dynamic>{};

      final distributorName = (distributorMap['company_name'] ?? 'Distributor')
          .toString();

      final totalAmount = _toDouble(order['total_amount']);

      totalsByDistributor[distributorName] =
          (totalsByDistributor[distributorName] ?? 0) + totalAmount;

      monthTotal += totalAmount;
    }

    if (totalsByDistributor.isEmpty || monthTotal <= 0) {
      return [];
    }

    final sorted = totalsByDistributor.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    const colors = [
      Color(0xFF0FA3A3),
      kBlue,
      amber,
      Color(0xFF7FB2D9),
      green,
      red,
    ];

    return sorted.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final percent = ((item.value / monthTotal) * 100).round();

      return _DistributorItem(
        name: item.key,
        value: _formatCompactLakh(item.value),
        percent: percent,
        color: colors[index % colors.length],
      );
    }).toList();
  }

  List<_FastMoverItem> _buildFastMovers(
    List<Map<String, dynamic>> orders,
    DateTime now,
  ) {
    final Map<String, int> qtyByMedicine = {};
    final Map<String, double> spendByMedicine = {};

    for (final order in orders) {
      final orderDate = _parseDate(order['order_date']);
      if (orderDate == null) continue;

      if (orderDate.year != now.year || orderDate.month != now.month) {
        continue;
      }

      final products = order['products'] as List? ?? [];

      for (final raw in products) {
        if (raw is! Map) continue;
        final p = Map<String, dynamic>.from(raw);

        final name = _productName(p);
        final qty = _productQty(p);
        final total = _productTotal(p);

        qtyByMedicine[name] = (qtyByMedicine[name] ?? 0) + qty;
        spendByMedicine[name] = (spendByMedicine[name] ?? 0) + total;
      }
    }

    final medicines = qtyByMedicine.keys.toList()
      ..sort(
        (a, b) => (qtyByMedicine[b] ?? 0).compareTo(qtyByMedicine[a] ?? 0),
      );

    return medicines.take(6).map((name) {
      final qty = qtyByMedicine[name] ?? 0;
      final spend = spendByMedicine[name] ?? 0.0;

      return _FastMoverItem(
        name: name,
        qty: '$qty units',
        spend: _formatMoney(spend),
      );
    }).toList();
  }

  List<_SavingItem> _buildSavings(
    List<Map<String, dynamic>> orders,
    DateTime now,
  ) {
    double monthSpend = 0;
    double comparisonSavings = 0;
    double schemeSavings = 0;
    double cashback = 0;

    for (final order in orders) {
      final orderDate = _parseDate(order['order_date']);
      if (orderDate == null) continue;

      if (orderDate.year != now.year || orderDate.month != now.month) {
        continue;
      }

      final orderTotal = _toDouble(order['total_amount']);
      monthSpend += orderTotal;
      cashback += orderTotal * 0.01;

      final products = order['products'] as List? ?? [];
      for (final raw in products) {
        if (raw is! Map) continue;
        final p = Map<String, dynamic>.from(raw);

        final qty = _productQty(p);
        final ptr = _toDouble(p['ptr']);
        final sell = _toDouble(
          p['sell_price_to_retailer'] ?? p['price_per_unit'],
        );

        if (sell > ptr && qty > 0) {
          comparisonSavings += (sell - ptr) * qty;
        }

        final lineTotal = _productTotal(p);
        schemeSavings += lineTotal * 0.03;
      }
    }

    final safeBase = monthSpend <= 0 ? 1.0 : monthSpend;

    return [
      _SavingItem(
        title: 'Saved via distributor comparison',
        value: _formatMoney(comparisonSavings),
        rawValue: comparisonSavings,
        progress: (comparisonSavings / safeBase).clamp(0.0, 1.0),
        color: const Color(0xFF0FA3A3),
      ),
      _SavingItem(
        title: 'Scheme benefits captured',
        value: _formatMoney(schemeSavings),
        rawValue: schemeSavings,
        progress: (schemeSavings / safeBase).clamp(0.0, 1.0),
        color: kBlue,
      ),
      _SavingItem(
        title: 'Cashback earned',
        value: _formatMoney(cashback),
        rawValue: cashback,
        progress: (cashback / safeBase).clamp(0.0, 1.0),
        color: amber,
      ),
    ];
  }

  String _monthKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  int _productQty(Map<String, dynamic> p) {
    final dynamic qty = p['quantity'] ?? p['qty'] ?? 0;
    if (qty is int) return qty;
    if (qty is double) return qty.toInt();
    return int.tryParse(qty.toString()) ?? 0;
  }

  double _productTotal(Map<String, dynamic> p) {
    final dynamic total =
        p['line_total'] ?? p['order_price'] ?? p['total_price'] ?? 0;
    if (total is num) return total.toDouble();
    return double.tryParse(total.toString()) ?? 0;
  }

  String _productName(Map<String, dynamic> p) {
    return (p['product_name'] ?? p['name'] ?? p['medicine_name'] ?? '-')
        .toString();
  }

  String _formatMoney(num value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(value);
  }

  String _formatCompactLakh(double value) {
    if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)}L';
    }
    if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(0)}K';
    }
    return _formatMoney(value);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<PharmaCartProvider>();

    return Container(
      color: pageBg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PharmaPageHeader(
              title: 'Reports',
              showMenu: true,
              showNotification: false,
              showCart: true,
              cartCount: cart.itemCount,
              onMenu: widget.onOpenDrawer,
              onCart: () => showPharmaCartSheet(context),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _buildErrorState()
                  : RefreshIndicator(
                      onRefresh: _loadReports,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                        children: [
                          const Text(
                            'Reports',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: headingColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Your pharmacy's buying, decoded. Data from platform orders only.",
                            style: TextStyle(
                              fontSize: 13,
                              color: mutedColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 14),
                          appCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Monthly purchase trend (₹ in lakh)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: headingColor,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 180,
                                  child: _monthlyTrend.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'No monthly trend data found.',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: mutedColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )
                                      : Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: _monthlyTrend
                                              .map(
                                                (item) => Expanded(
                                                  child: _buildBar(item),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          appCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Purchase by distributor - $_currentMonthLabel',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: headingColor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_distributors.isEmpty)
                                  const Text(
                                    'No distributor purchase data found for this month.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: mutedColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                else
                                  ..._distributors.map(_buildDistributorRow),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          appCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 42,
                                        child: Text(
                                          'Fast movers - $_currentMonthLabel',
                                          style: _tableHeadStyle,
                                        ),
                                      ),
                                      const Expanded(
                                        flex: 28,
                                        child: Text(
                                          'Qty',
                                          style: _tableHeadStyle,
                                        ),
                                      ),
                                      const Expanded(
                                        flex: 30,
                                        child: Text(
                                          'Spend',
                                          style: _tableHeadStyle,
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1, color: borderColor),
                                if (_fastMovers.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    child: Text(
                                      'No fast mover data found for this month.',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: mutedColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                else
                                  ..._fastMovers.map(_buildFastMoverRow),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          appCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Savings snapshot - $_currentMonthLabel',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: headingColor,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ..._savings.map(_buildSavingsRow),
                                //const SizedBox(height: 10),
                                /*
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: mutedColor,
                                      height: 1.45,
                                    ),
                                    children: [
                                      const TextSpan(
                                        text: 'Total monthly advantage: ',
                                      ),
                                      TextSpan(
                                        text: _totalAdvantage,
                                        style: const TextStyle(
                                          color: green,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const TextSpan(
                                        text:
                                            ' versus buying without comparison.',
                                      ),
                                    ],
                                  ),
                                ),
                                */
                              ],
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

  Widget _buildErrorState() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        appCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unable to load reports',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: headingColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Unknown error',
                style: const TextStyle(
                  fontSize: 13,
                  color: mutedColor,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _loadReports,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBar(_TrendItem item) {
    final Color fillColor = item.highlight ? amber : kBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            item.value.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 10.5,
              color: item.highlight ? amber : kBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: item.heightFactor,
                child: Container(
                  width: 28,
                  decoration: BoxDecoration(
                    gradient: item.highlight
                        ? null
                        : const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [kBlue, Color(0xFF0FA3A3)],
                          ),
                    color: item.highlight ? amber : null,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                      bottom: Radius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.month,
            style: const TextStyle(
              fontSize: 10.5,
              color: mutedColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributorRow(_DistributorItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 12.2,
                    fontWeight: FontWeight.w600,
                    color: headingColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${item.value} · ${item.percent}%',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: mutedColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: item.percent / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(item.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFastMoverRow(_FastMoverItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 42,
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: headingColor,
                  ),
                ),
              ),
              Expanded(
                flex: 28,
                child: Text(
                  item.qty,
                  style: const TextStyle(
                    fontSize: 12,
                    color: mutedColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 30,
                child: Text(
                  item.spend,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: headingColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, color: borderColor),
        ],
      ),
    );
  }

  Widget _buildSavingsRow(_SavingItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 12.2,
                    fontWeight: FontWeight.w600,
                    color: headingColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                item.value,
                style: const TextStyle(
                  fontSize: 11.8,
                  color: mutedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: item.progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(item.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendItem {
  final String month;
  final double value;
  final double heightFactor;
  final bool highlight;

  const _TrendItem({
    required this.month,
    required this.value,
    required this.heightFactor,
    this.highlight = false,
  });
}

class _DistributorItem {
  final String name;
  final String value;
  final int percent;
  final Color color;

  const _DistributorItem({
    required this.name,
    required this.value,
    required this.percent,
    required this.color,
  });
}

class _FastMoverItem {
  final String name;
  final String qty;
  final String spend;

  const _FastMoverItem({
    required this.name,
    required this.qty,
    required this.spend,
  });
}

class _SavingItem {
  final String title;
  final String value;
  final double progress;
  final Color color;
  final double rawValue;

  const _SavingItem({
    required this.title,
    required this.value,
    required this.progress,
    required this.color,
    required this.rawValue,
  });
}

const _tableHeadStyle = TextStyle(
  fontSize: 10.5,
  fontWeight: FontWeight.w800,
  color: mutedColor,
  letterSpacing: 0.6,
);
