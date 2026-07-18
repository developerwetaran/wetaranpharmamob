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
const redSoft = Color(0xFFFEE2E2);
const red = Color(0xFFDC2626);

class ExpiryPage extends StatefulWidget {
  final VoidCallback onOpenDrawer;

  const ExpiryPage({super.key, required this.onOpenDrawer});

  @override
  State<ExpiryPage> createState() => _ExpiryPageState();
}

class _ExpiryPageState extends State<ExpiryPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;

  List<_BatchItem> _batches = [];

  int _expiring30Count = 0;
  int _expiring60Count = 0;
  int _healthyCount = 0;
  String? _pharmaUserId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _log(String message) {
    debugPrint('[ExpiryPage] $message');
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;

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

      if (pharmaProfile == null || pharmaProfile['id'] == null) {
        throw Exception('No pharma user found for this account');
      }

      final pharmaUserId = pharmaProfile['id'] as String;
      _log('4. pharma user id = $pharmaUserId');

      final orderRows = await _supabase
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
      _log('5. orders fetched = ${orderRows.length}');

      final Set<String> stockIds = {};
      final List<Map<String, dynamic>> flattenedProducts = [];

      for (final row in orderRows) {
        final orderMap = Map<String, dynamic>.from(row as Map);
        final orderIdDisplay =
            (orderMap['order_id']?.toString().trim().isNotEmpty ?? false)
            ? orderMap['order_id'].toString()
            : (orderMap['id']?.toString() ?? '-');

        final productsRaw = orderMap['products'];

        if (productsRaw is! List) continue;

        for (final item in productsRaw) {
          if (item is! Map) continue;

          final product = Map<String, dynamic>.from(item);
          final stockId = product['pharma_stock_id']?.toString();

          if (stockId == null || stockId.isEmpty) continue;

          stockIds.add(stockId);

          flattenedProducts.add({
            'order': orderMap,
            'order_id': orderIdDisplay,
            'product_name':
                product['product_name']?.toString() ?? 'Unknown Product',
            'pharma_stock_id': stockId,
            'qty': _extractQty(product),
            'ptr': _toDouble(product['ptr']),
          });
        }
      }

      _log('6. unique stock ids = ${stockIds.length}');
      _log('7. flattened order products = ${flattenedProducts.length}');

      Map<String, Map<String, dynamic>> stockMap = {};

      if (stockIds.isNotEmpty) {
        final stockRows = await _supabase
            .from('inventory_pharma_stock')
            .select('''
              id,
              product_name,
              brand_name,
              batch_number,
              expiry_date
            ''')
            .inFilter('id', stockIds.toList());

        _log('8. inventory rows fetched = ${stockRows.length}');

        stockMap = {
          for (final row in stockRows)
            (row['id'].toString()): Map<String, dynamic>.from(row as Map),
        };
      }

      final List<_BatchItem> items = [];
      int expiring30 = 0;
      int expiring60 = 0;
      int healthy = 0;

      for (final product in flattenedProducts) {
        final stock = stockMap[product['pharma_stock_id']];
        if (stock == null) continue;

        final expiryDate = _parseDate(stock['expiry_date']);
        final statusMeta = _buildStatus(expiryDate);

        if (statusMeta.type == BatchStatus.danger) {
          expiring30++;
        } else if (statusMeta.type == BatchStatus.warning) {
          expiring60++;
        } else if (statusMeta.isHealthy) {
          healthy++;
        }

        items.add(
          _BatchItem(
            order: Map<String, dynamic>.from(product['order'] as Map),
            product:
                (stock['product_name']?.toString().trim().isNotEmpty ?? false)
                ? stock['product_name'].toString()
                : product['product_name'].toString(),
            company: stock['brand_name']?.toString() ?? '-',
            batchNo: stock['batch_number']?.toString() ?? '-',
            orderNo: product['order_id'].toString(),
            qtyLeft: '${product['qty']} units',
            expiry: expiryDate != null
                ? DateFormat('dd MMM yyyy').format(expiryDate)
                : '-',
            status: statusMeta.label,
            statusType: statusMeta.type,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _pharmaUserId = pharmaUserId;
        _batches = items;
        _expiring30Count = expiring30;
        _expiring60Count = expiring60;
        _healthyCount = healthy;
        _loading = false;
      });

      _log('9. final batch items = ${items.length}');
    } on PostgrestException catch (e) {
      _log('PostgrestException: ${e.message}');
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      _log('Exception: $e');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<_BatchItem> get _filteredBatches {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return _batches;

    return _batches.where((item) {
      final product = item.product.toLowerCase();
      final orderNo = item.orderNo.toLowerCase();
      final batchNo = item.batchNo.toLowerCase();

      return product.contains(query) ||
          orderNo.contains(query) ||
          batchNo.contains(query);
    }).toList();
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

  int _extractQty(Map<String, dynamic> product) {
    final dynamic qty = product['qty'] ?? product['quantity'] ?? 0;

    if (qty is int) return qty;
    if (qty is double) return qty.toInt();
    return int.tryParse(qty.toString()) ?? 0;
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

  _BatchStatusMeta _buildStatus(DateTime? expiryDate) {
    if (expiryDate == null) {
      return const _BatchStatusMeta(
        label: 'No expiry',
        type: BatchStatus.good,
        isHealthy: false,
      );
    }

    final today = DateTime.now();
    final now = DateTime(today.year, today.month, today.day);
    final exp = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final daysLeft = exp.difference(now).inDays;

    if (daysLeft < 0) {
      return const _BatchStatusMeta(
        label: 'Expired',
        type: BatchStatus.danger,
        isHealthy: false,
      );
    }

    if (daysLeft <= 30) {
      return _BatchStatusMeta(
        label: '$daysLeft days left',
        type: BatchStatus.danger,
        isHealthy: false,
      );
    }

    if (daysLeft <= 60) {
      return _BatchStatusMeta(
        label: '$daysLeft days left',
        type: BatchStatus.warning,
        isHealthy: false,
      );
    }

    if (daysLeft > 90) {
      return const _BatchStatusMeta(
        label: 'Healthy',
        type: BatchStatus.good,
        isHealthy: true,
      );
    }

    return _BatchStatusMeta(
      label: '$daysLeft days left',
      type: BatchStatus.good,
      isHealthy: false,
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
              title: 'Expiry & Batch',
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
                      onRefresh: _loadOrders,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                        children: [
                          const Text(
                            'Expiry & Batch Tracking',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: headingColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Every product bought via the platform, tracked batch by batch.',
                            style: TextStyle(
                              fontSize: 13,
                              color: mutedColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'Expiring ≤ 30 days',
                                  value: '$_expiring30Count',
                                  subtitle: 'Act now - return or push sales',
                                  accentColor: red,
                                  accentSoft: redSoft,
                                  icon: Icons.warning_amber_rounded,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'Expiring ≤ 60 days',
                                  value: '$_expiring60Count',
                                  subtitle: 'Plan returns with distributor',
                                  accentColor: amber,
                                  accentSoft: amberSoft,
                                  icon: Icons.schedule_rounded,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'Healthy batches',
                                  value: '$_healthyCount',
                                  subtitle: 'More than 90 days shelf life',
                                  accentColor: green,
                                  accentSoft: greenSoft,
                                  icon: Icons.verified_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          appCard(
                            padding: const EdgeInsets.all(12),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Search batch no, order id ...',
                                hintStyle: const TextStyle(
                                  fontSize: 13,
                                  color: mutedColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: mutedColor,
                                  size: 20,
                                ),
                                suffixIcon: _searchQuery.trim().isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchQuery = '';
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          color: mutedColor,
                                          size: 18,
                                        ),
                                      ),
                                filled: true,
                                fillColor: pageBg,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: borderColor,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: borderColor,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: kBlue,
                                    width: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'BATCH REGISTER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: mutedColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 10),

                          if (_batches.isEmpty)
                            appCard(
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'No batch-wise expiry records found for your orders.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: mutedColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                          else if (_filteredBatches.isEmpty)
                            appCard(
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'No medicine or order found for this search.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: mutedColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                          else
                            ..._filteredBatches.map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildBatchCard(item),
                              );
                            }),
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
                'Unable to load expiry records',
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
                onPressed: _loadOrders,
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

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color accentColor,
    required Color accentSoft,
    required IconData icon,
  }) {
    return appCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accentColor, size: 19),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11.2,
              color: mutedColor,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: accentColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10.5,
              color: mutedColor,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCard(_BatchItem item) {
    final statusColors = _statusColors(item.statusType);

    return appCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: headingColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.company,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: mutedColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColors.$1,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.status,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: statusColors.$2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: borderColor),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _infoBlock('Batch no.', item.batchNo)),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showOrderDetails(item.order),
                  child: _infoBlock('Order', item.orderNo, valueColor: kBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _infoBlock('Qty bought', item.qtyLeft)),
              const SizedBox(width: 12),
              Expanded(child: _infoBlock('Expiry', item.expiry)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBlock(
    String label,
    String value, {
    Color valueColor = headingColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: pageBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color: mutedColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.2,
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _statusColors(BatchStatus statusType) {
    switch (statusType) {
      case BatchStatus.danger:
        return (redSoft, red);
      case BatchStatus.warning:
        return (amberSoft, amber);
      case BatchStatus.good:
        return (greenSoft, green);
    }
  }
}

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

enum BatchStatus { danger, warning, good }

class _BatchItem {
  final Map<String, dynamic> order;
  final String product;
  final String company;
  final String batchNo;
  final String orderNo;
  final String qtyLeft;
  final String expiry;
  final String status;
  final BatchStatus statusType;

  const _BatchItem({
    required this.order,
    required this.product,
    required this.company,
    required this.batchNo,
    required this.orderNo,
    required this.qtyLeft,
    required this.expiry,
    required this.status,
    required this.statusType,
  });
}

class _BatchStatusMeta {
  final String label;
  final BatchStatus type;
  final bool isHealthy;

  const _BatchStatusMeta({
    required this.label,
    required this.type,
    required this.isHealthy,
  });
}

class _TableHeadStyle {
  static const style = TextStyle(
    fontSize: 10.5,
    color: mutedColor,
    fontWeight: FontWeight.w700,
  );
}
