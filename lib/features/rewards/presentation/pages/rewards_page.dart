import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wetaran_pharma/core/widgets/reusable_pharma_header.dart';
import 'package:wetaran_pharma/features/distributors/models/distributor_summary.dart';
import 'package:wetaran_pharma/features/distributors/presentation/pages/distributors_profile_page.dart';
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

class CashbackEntry {
  final String orderId;
  final String distributor;
  final double orderValue;
  final double cashback;
  final String status;
  final DateTime? createdAt;

  CashbackEntry({
    required this.orderId,
    required this.distributor,
    required this.orderValue,
    required this.cashback,
    required this.status,
    required this.createdAt,
  });
}

class RewardsPage extends StatefulWidget {
  final VoidCallback onOpenDrawer;

  const RewardsPage({super.key, required this.onOpenDrawer});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  double _walletBalance = 0;
  double _monthCashback = 0;
  int _monthOrders = 0;
  double _lifetimeCashback = 0;

  List<CashbackEntry> _cashbackEntries = [];
  final SupabaseClient _supabase = Supabase.instance.client;

  String? _pharmaUserId;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  String _formatMoney(num value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(value);
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  bool _isCreditedStatus(String status) {
    final s = status.trim().toLowerCase();
    return s == 'delivered' ||
        s == 'completed' ||
        s == 'paid' ||
        s == 'success' ||
        s == 'credited';
  }

  bool _isPendingStatus(String status) {
    final s = status.trim().toLowerCase();
    return s == 'pending' ||
        s == 'confirmed' ||
        s == 'processing' ||
        s == 'shipped' ||
        s == 'out for delivery' ||
        s == 'pending delivery';
  }

  String _cashbackStatusFromOrderStatus(String status) {
    if (_isCreditedStatus(status)) return 'Credited';
    if (_isPendingStatus(status)) return 'Pending delivery';
    return 'Pending';
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      _log('1. loadOrders started');

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
          .order('order_date', ascending: false);

      final orders = List<Map<String, dynamic>>.from(rows);

      final now = DateTime.now();

      double walletBalance = 0;
      double monthCashback = 0;
      int monthOrders = 0;
      double lifetimeCashback = 0;
      final List<CashbackEntry> cashbackEntries = [];

      for (final order in orders) {
        final totalAmount = _toDouble(order['total_amount']);
        final cashback = totalAmount * 0.01;
        final status = (order['status'] ?? '').toString();
        final orderDate = _parseDate(order['order_date']);
        final cashbackStatus = _cashbackStatusFromOrderStatus(status);

        final distributorMap = order['distributor'] is Map
            ? Map<String, dynamic>.from(order['distributor'] as Map)
            : <String, dynamic>{};

        final distributorName =
            (distributorMap['company_name'] ?? 'Distributor').toString();

        lifetimeCashback += cashback;

        if (orderDate != null &&
            orderDate.year == now.year &&
            orderDate.month == now.month) {
          monthCashback += cashback;
          monthOrders += 1;
        }

        cashbackEntries.add(
          CashbackEntry(
            orderId: (order['order_id'] ?? '—').toString(),
            distributor: distributorName,
            orderValue: totalAmount,
            cashback: cashback,
            status: cashbackStatus,
            createdAt: orderDate,
          ),
        );
      }
      walletBalance = lifetimeCashback;
      _log('7. walletBalance = $walletBalance');
      _log('8. monthCashback = $monthCashback');
      _log('9. monthOrders = $monthOrders');
      _log('10. lifetimeCashback = $lifetimeCashback');
      _log('11. cashbackEntries count = ${cashbackEntries.length}');

      if (!mounted) return;
      setState(() {
        _pharmaUserId = pharmaUserId;
        _orders = orders;
        _walletBalance = walletBalance;
        _monthCashback = monthCashback;
        _monthOrders = monthOrders;
        _lifetimeCashback = lifetimeCashback;
        _cashbackEntries = cashbackEntries;
        _loading = false;
      });

      _log('12. state updated successfully');
    } catch (e, st) {
      _log('ERROR = $e');
      debugPrintStack(label: 'REWARDS_STACK', stackTrace: st);

      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _log(Object msg) {
    debugPrint('REWARDS_DEBUG: $msg');
  }

  String _formatMoneyPrecise(num? raw) {
    final value = raw?.toDouble() ?? 0;
    return '₹${value.toStringAsFixed(2)}';
  }

  int _productQty(Map<String, dynamic> p) {
    return (p['quantity'] ?? p['qty'] ?? 0) as int? ?? 0;
  }

  double _productPtr(Map<String, dynamic> p) {
    final v = p['ptr'] ?? p['sell_price_to_retailer'] ?? p['price_per_unit'];
    return (v as num?)?.toDouble() ?? 0.0;
  }

  double _productTotal(Map<String, dynamic> p) {
    final v = p['total_price'] ?? p['line_total'] ?? p['order_price'];
    return (v as num?)?.toDouble() ?? 0.0;
  }

  String _productName(Map<String, dynamic> p) {
    return (p['name'] ?? p['product_name'] ?? p['medicine_name'] ?? '-')
        .toString();
  }

  Widget _buildProductsTable(List<Map<String, dynamic>> products) {
    if (products.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: const Text(
          'No product rows found for this order.',
          style: TextStyle(
            fontSize: 12,
            color: mutedColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text('Medicine', style: _TableHeadStyle.style),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Qty', style: _TableHeadStyle.style),
                ),
                Expanded(
                  flex: 2,
                  child: Text('PTR', style: _TableHeadStyle.style),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Amount',
                    textAlign: TextAlign.right,
                    style: _TableHeadStyle.style,
                  ),
                ),
              ],
            ),
          ),
          ...products.asMap().entries.map((entry) {
            final i = entry.key;
            final product = entry.value;

            final qty = _productQty(product);
            final unit = (product['unit'] ?? product['primary_unit'] ?? '')
                .toString();
            final total = _productTotal(product);
            final ptr = _productPtr(product);
            final name = _productName(product);

            final subLineParts = [
              (product['sku_code'] ?? '').toString(),
              (product['brand_name'] ?? '').toString(),
              if (unit.trim().isNotEmpty) unit,
            ].where((e) => e.trim().isNotEmpty).toList();

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: i == products.length - 1
                    ? null
                    : const Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (name).toString(),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: headingColor,
                          ),
                        ),
                        if (subLineParts.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subLineParts.join(' · '),
                            style: const TextStyle(
                              fontSize: 11,
                              color: mutedColor,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '$qty',
                      style: const TextStyle(
                        fontSize: 12,
                        color: headingColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatMoneyPrecise(ptr),
                      style: const TextStyle(
                        fontSize: 12,
                        color: headingColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      _formatMoneyPrecise(total),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        color: headingColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '-';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return raw.toString();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
  }

  Widget _kvDistributorRow({
    required Map<String, dynamic> distributor,
    required String distributorName,
    required VoidCallback onTap,
  }) {
    final products = (distributor['products'] as List? ?? []);
    final productCount = products.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onTap,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFF6FAFF), Color(0xFFF9FCFF)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDCE8F5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF2FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              size: 18,
                              color: kBlue,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  distributorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.8,
                                    fontWeight: FontWeight.w800,
                                    color: kBlue,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  (distributor['company_phone'] ?? '-')
                                      .toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.6,
                                    color: mutedColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEAF8EE),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        distributor['partner_type']
                                                    ?.toString()
                                                    .trim()
                                                    .isNotEmpty ==
                                                true
                                            ? distributor['partner_type']
                                                  .toString()
                                            : 'Distributor',
                                        style: const TextStyle(
                                          fontSize: 10.6,
                                          color: green,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: kBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    final s = status.trim();
    if (s.isEmpty) return 'NEW';
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  Color _statusBg(String status) {
    switch (status.toLowerCase()) {
      case 'booked':
        return bookedSoft;

      case 'delivered':
        return deliveredSoft;

      case 'approved':
        return newSoft;

      case 'pending':
        return pendingSoft;

      case 'onhold':
        return processingSoft;

      case 'returned':
        return returnedSoft;

      case 'cancelled':
        return cancelledSoft;

      default:
        return const Color(0xFFE8F0FF);
    }
  }

  Color _statusFg(String status) {
    switch (status.toLowerCase()) {
      case 'booked':
        return booked;

      case 'delivered':
        return delivered;

      case 'approved':
        return newColor;

      case 'pending':
        return pending;

      case 'onhold':
        return processing;

      case 'returned':
        return returned;

      case 'cancelled':
        return cancelled;

      default:
        return ordersPrimaryBlue;
    }
  }

  Widget _kvStatusRow(String label, String status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 118,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: mutedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusBg(status),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: _statusFg(status),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kvRow(
    String label,
    String value, {
    bool valueBlue = false,
    bool valueGreen = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 118,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: mutedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: valueBlue ? 15 : 12.5,
                  color: valueBlue
                      ? kBlue
                      : valueGreen
                      ? green
                      : headingColor,
                  fontWeight: valueBlue || valueGreen
                      ? FontWeight.w800
                      : FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowDeliveryRow(Map<String, dynamic> order) {
    final status = (order['status'] ?? '').toString().trim().toLowerCase();

    switch (status) {
      case 'delivered':
      case 'cancelled':
      case 'returned':
        return false;
      default:
        return true;
    }
  }

  DateTime? _calculatedDeliveryDate(Map<String, dynamic> order) {
    final distributor = order['distributor'] as Map<String, dynamic>?;
    final deliveryType =
        (distributor?['pharma_expected_delivery'] ?? 'same_day')
            .toString()
            .trim()
            .toLowerCase();

    final cutoffRaw = distributor?['pharma_same_day_order_cutoff']?.toString();

    final orderDateRaw =
        order['order_date'] ?? order['created_at'] ?? order['ordered_at'];

    if (orderDateRaw == null) return null;

    final orderDate = DateTime.tryParse(orderDateRaw.toString())?.toLocal();
    if (orderDate == null) return null;

    if (deliveryType != 'same_day') {
      return DateTime(orderDate.year, orderDate.month, orderDate.day);
    }

    if (cutoffRaw == null || cutoffRaw.trim().isEmpty) {
      return DateTime(orderDate.year, orderDate.month, orderDate.day);
    }

    final cutoff = _parseCutoffTime(cutoffRaw);
    if (cutoff == null) {
      return DateTime(orderDate.year, orderDate.month, orderDate.day);
    }

    final cutoffDateTime = DateTime(
      orderDate.year,
      orderDate.month,
      orderDate.day,
      cutoff.hour,
      cutoff.minute,
    );

    final isSameDay =
        orderDate.isBefore(cutoffDateTime) ||
        orderDate.isAtSameMomentAs(cutoffDateTime);

    return isSameDay
        ? DateTime(orderDate.year, orderDate.month, orderDate.day)
        : DateTime(
            orderDate.year,
            orderDate.month,
            orderDate.day,
          ).add(const Duration(days: 1));
  }

  DateTime? _parseCutoffTime(String raw) {
    final value = raw.trim();

    final formats = [
      DateFormat('HH:mm'),
      DateFormat('H:mm'),
      DateFormat('hh:mm a'),
      DateFormat('h:mm a'),
    ];

    for (final format in formats) {
      try {
        return format.parse(value);
      } catch (_) {}
    }

    return null;
  }

  String _expectedDeliveryText(Map<String, dynamic> order) {
    final status = (order['status'] ?? '').toString().trim().toLowerCase();

    switch (status) {
      case 'cancelled':
        return 'Cancelled';

      case 'returned':
        return 'Returned';

      case 'delivered':
        final deliveredDate = _calculatedDeliveryDate(order);
        if (deliveredDate == null) return 'Delivered';
        return 'Delivered on ${DateFormat('dd MMM yyyy').format(deliveredDate)}';

      default:
        final deliveryDate = _calculatedDeliveryDate(order);
        if (deliveryDate == null) return 'Not available';

        final orderDateRaw =
            order['order_date'] ?? order['created_at'] ?? order['ordered_at'];

        final orderDate = DateTime.tryParse(orderDateRaw.toString())?.toLocal();
        if (orderDate == null) {
          return DateFormat('dd MMM yyyy').format(deliveryDate);
        }

        final isSameCalendarDay =
            deliveryDate.year == orderDate.year &&
            deliveryDate.month == orderDate.month &&
            deliveryDate.day == orderDate.day;

        final formattedDate = DateFormat('dd MMM yyyy').format(deliveryDate);

        return isSameCalendarDay
            ? 'Same day • $formattedDate'
            : 'Tomorrow • $formattedDate';
    }
  }

  int _totalQty(Map<String, dynamic> order) {
    final products = (order['products'] as List? ?? []);
    return products.fold<int>(0, (sum, item) {
      final p = Map<String, dynamic>.from(item as Map);
      return sum + ((p['quantity'] as num?)?.toInt() ?? 0);
    });
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final products = (order['products'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final distributor = (order['distributor'] as Map<String, dynamic>?) ?? {};

    final distributorName = (distributor['company_name'] ?? '-').toString();
    final distributorPhone = (distributor['company_phone'] ?? '-').toString();
    final distributorEmail = (distributor['company_email'] ?? '-').toString();
    final status = (order['status'] ?? 'new').toString();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Order Details',
      barrierColor: Colors.black.withOpacity(0.50),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, animation, _) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(ctx).size.width * 0.92,
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: MediaQuery.of(ctx).size.height * 0.84,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBFF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      border: Border(bottom: BorderSide(color: borderColor)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (order['order_id'] ?? 'Order').toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: headingColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(order['order_date']),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: mutedColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: redSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                      children: [
                        _kvDistributorRow(
                          distributor: distributor,
                          distributorName: distributorName,
                          onTap: () {
                            Navigator.pop(ctx);
                            _openDistributorProfile(distributor);
                          },
                        ),
                        _kvRow('Company Phone', distributorPhone),
                        _kvRow('Company Email', distributorEmail),
                        _kvStatusRow('Status', status),
                        if (_shouldShowDeliveryRow(order))
                          _kvRow(
                            'Expected delivery',
                            _expectedDeliveryText(order),
                          ),
                        const SizedBox(height: 14),
                        Text(
                          'Items - ${products.length} products · ${_totalQty(order)} units',
                          style: const TextStyle(
                            fontSize: 12,
                            color: mutedColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildProductsTable(products),
                        const SizedBox(height: 12),
                        _kvRow(
                          'Order value',
                          _formatMoney(order['total_amount']),
                          valueBlue: true,
                        ),
                        _kvRow(
                          'Cashback',
                          _formatMoney(
                            (double.tryParse(
                                      order['total_amount'].toString(),
                                    ) ??
                                    0.0) *
                                0.01,
                          ),
                          valueGreen: true,
                        ),
                        if ((order['notes'] ?? '').toString().trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Notes',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: mutedColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    (order['notes'] ?? '').toString(),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: headingColor,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
        child: ScaleTransition(
          scale: Tween(
            begin: 0.96,
            end: 1.0,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
  }

  void _openDistributorProfile(Map<String, dynamic> distributor) {
    final d = DistributorSummary(
      id: (distributor['id'] ?? '').toString(),
      companyName: (distributor['company_name'] ?? '').toString(),
      companyPhone: (distributor['company_phone'] ?? '').toString(),
      companyEmail: (distributor['company_email'] ?? '').toString(),
      contactName: (distributor['contact_name'] ?? '').toString(),
      contactPhone: (distributor['contact_phone'] ?? '').toString(),
      contactEmail: (distributor['contact_email'] ?? '').toString(),
      gstin: (distributor['gstin'] ?? '').toString(),
      drugLicenseNo: (distributor['drug_license_no'] ?? '').toString(),
      registeredOfficeAddress: (distributor['registered_office_address'] ?? '')
          .toString(),
      warehouseAddress: (distributor['warehouse_address'] ?? '').toString(),
      partnerType: (distributor['partner_type'] ?? '').toString(),
      status: (distributor['status'] ?? '').toString(),
      isActive: distributor['is_active'] == true,
      orderCount: 0,
      totalOrderedValue: 0,
      totalItems: 0,
      serviceCoverage: distributor['service_coverage'] is Map
          ? Map<String, dynamic>.from(distributor['service_coverage'] as Map)
          : <String, dynamic>{},
      pharmaExpectedDelivery: (distributor['pharma_expected_delivery'] ?? '')
          .toString(),
      pharmaSameDayOrderCutoff:
          (distributor['pharma_same_day_order_cutoff'] ?? '').toString(),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DistributorProfilePage(
          distributor: d,
          pharmaUserId: _pharmaUserId ?? '',
        ),
      ),
    );
  }

  Widget _buildCashbackCard(CashbackEntry item, Map<String, dynamic> order) {
    final bool credited = item.status == 'Credited';
    final distributor = order['distributor'] is Map
        ? Map<String, dynamic>.from(order['distributor'] as Map)
        : <String, dynamic>{};

    return appCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showOrderDetails(order),
                  child: Text(
                    item.orderId,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: kBlue,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: credited ? greenSoft : amberSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: credited ? green : amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: distributor.isEmpty
                ? null
                : () => _openDistributorProfile(distributor),
            child: Text(
              item.distributor,
              style: const TextStyle(
                fontSize: 12.5,
                color: kBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ValueBlock(
                  'Order value',
                  _formatMoney(item.orderValue),
                  mutedColor,
                ),
              ),
              Expanded(
                child: _ValueBlock(
                  'Cashback',
                  _formatMoney(item.cashback),
                  green,
                  alignRight: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ValueBlock(
    String label,
    String value,
    Color valueColor, {
    bool alignRight = false,
  }) {
    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: mutedColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
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
              title: 'Rewards',
              showMenu: true,
              showNotification: false,
              showCart: true,
              cartCount: cart.itemCount,
              onMenu: widget.onOpenDrawer,
              onCart: () => showPharmaCartSheet(context),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: kBlue))
                  : _error != null
                  ? _buildErrorState()
                  : RefreshIndicator(
                      color: kBlue,
                      onRefresh: _loadOrders,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                        children: [
                          const Text(
                            'Rewards',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: headingColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Cashback on every order - credited automatically to your wallet.',
                            style: TextStyle(
                              fontSize: 13,
                              color: mutedColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildWalletCard(),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'Cashback this month',
                                  value: _formatMoney(_monthCashback),
                                  subtitle:
                                      'Across $_monthOrders orders this month',
                                  valueColor: const Color(0xFF0FA3A3),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'Lifetime cashback',
                                  value: _formatMoney(_lifetimeCashback),
                                  subtitle: 'From all your orders',
                                  valueColor: kBlue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Recent cashback',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: mutedColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _cashbackEntries.isEmpty
                              ? appCard(
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 10),
                                    child: Text(
                                      'No cashback entries found yet.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: mutedColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                              : Column(
                                  children: _cashbackEntries
                                      .take(20)
                                      .toList()
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                        final index = entry.key;
                                        final item = entry.value;
                                        final order = _orders[index];

                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: _buildCashbackCard(
                                            item,
                                            order,
                                          ),
                                        );
                                      })
                                      .toList(),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade300,
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(color: mutedColor),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loadOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: kBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kBlue, kBlueDk, Color(0xFF06304F)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wallet balance',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatMoney(_walletBalance),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Use it against your next order at checkout.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color valueColor,
  }) {
    return appCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              color: mutedColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: mutedColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: const [
          Expanded(flex: 22, child: Text('Order', style: _tableHeadStyle)),
          Expanded(
            flex: 30,
            child: Text('Distributor', style: _tableHeadStyle),
          ),
          Expanded(
            flex: 20,
            child: Text(
              'Value',
              style: _tableHeadStyle,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 18,
            child: Text(
              'Cashback',
              style: _tableHeadStyle,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashbackRow(CashbackEntry item) {
    final bool credited = item.status == 'Credited';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 22,
                child: Text(
                  item.orderId,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: headingColor,
                  ),
                ),
              ),
              Expanded(
                flex: 30,
                child: Text(
                  item.distributor,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: headingColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 20,
                child: Text(
                  _formatMoney(item.orderValue),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    color: mutedColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 18,
                child: Text(
                  _formatMoney(item.cashback),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: kBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: credited ? greenSoft : amberSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                item.status,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: credited ? green : amber,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, color: borderColor),
        ],
      ),
    );
  }
}

const _tableHeadStyle = TextStyle(
  fontSize: 10.5,
  fontWeight: FontWeight.w800,
  color: mutedColor,
  letterSpacing: 0.6,
);

class _TableHeadStyle {
  static const style = TextStyle(
    fontSize: 10.5,
    color: mutedColor,
    fontWeight: FontWeight.w700,
  );
}
