import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:wetaran_pharma/core/widgets/reusable_pharma_header.dart';
import 'package:wetaran_pharma/features/distributors/models/distributor_summary.dart';
import 'package:wetaran_pharma/features/distributors/presentation/pages/distributors_profile_page.dart';
import 'package:wetaran_pharma/features/orders/models/pharma_cart_provider.dart';
import 'package:wetaran_pharma/features/orders/presentation/pages/add_order_screen.dart';
import 'package:wetaran_pharma/features/orders/presentation/widgets/pharma_cart_sheet.dart';

const ordersPrimaryBlue = Color.fromRGBO(0, 60, 190, 1);
const headingColor = Color(0xFF0F172A);
const mutedColor = Color(0xFF64748B);
const borderColor = Color(0xFFE2E8F0);
const pageBg = Color(0xFFF8FAFC);
const greenSoft = Color(0xFFDCFCE7);
const green = Color(0xFF16A34A);
const amberSoft = Color(0xFFFFEDD5);
const amber = Color(0xFFD97706);
const redSoft = Color(0xFFFEE2E2);
const red = Color(0xFFDC2626);
const kBlue = Color(0xFF0B4F8A);
const kBlueDk = Color(0xFF083A66);
const Color kLine = Color(0xFFE3EBF1);
const Color kInk = Color(0xFF13242F);
const tealSoft = Color(0xFFCCFBF1);
const teal = Color(0xFF0F766E);
const blueSoft = Color(0xFFDBEAFE);
const blue = Color(0xFF2563EB);
const purpleSoft = Color(0xFFF3E8FF);
const purple = Color(0xFF7C3AED);
const graySoft = Color(0xFFF1F5F9);
const gray = Color(0xFF64748B);
const bookedSoft = Color(0xFFE0F2FE);
const booked = Color(0xFF0284C7);

const deliveredSoft = Color(0xFFDCFCE7);
const delivered = Color(0xFF16A34A);

const newSoft = Color(0xFFF3E8FF);
const newColor = Color(0xFF7C3AED);

const pendingSoft = Color(0xFFFFF7CC);
const pending = Color(0xFFCA8A04);

const processingSoft = Color(0xFFFFEDD5);
const processing = Color(0xFFEA580C);

const cancelledSoft = Color(0xFFFEE2E2);
const cancelled = Color(0xFFDC2626);
const returnedSoft = Color(0xFFE0E7FF);
const returned = Color(0xFF4F46E5);

class PharmaOrdersPage extends StatefulWidget {
  final VoidCallback onOpenDrawer;

  const PharmaOrdersPage({super.key, required this.onOpenDrawer});

  @override
  State<PharmaOrdersPage> createState() => _PharmaOrdersPageState();
}

class _PharmaOrdersPageState extends State<PharmaOrdersPage>
    with AutomaticKeepAliveClientMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchCtrl = TextEditingController();
  String _statusFilter = 'All';
  bool _loading = true;
  String? _error;
  // ignore: unused_field
  String? _pharmaUserId;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _filtered = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    _loadOrders();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applyFilter);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authUser = _supabase.auth.currentUser;
      final authUserId = authUser?.id;

      if (authUserId == null) {
        throw Exception('No logged-in user found');
      }

      final pharmaProfile = await _supabase
          .from('pharma_users')
          .select('id')
          .eq('auth_user_id', authUserId)
          .maybeSingle();

      if (pharmaProfile == null) {
        throw Exception('Pharma user profile not found');
      }

      final pharmaUserId = (pharmaProfile['id'] ?? '').toString();
      if (pharmaUserId.isEmpty) {
        throw Exception('Invalid pharma user id');
      }

      final rows = await _supabase
          .from('orders')
          .select('''
      *,
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

      if (!mounted) return;
      setState(() {
        _pharmaUserId = pharmaUserId;
        _orders = orders;
        _filtered = orders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();

    List<Map<String, dynamic>> result = List<Map<String, dynamic>>.from(
      _orders,
    );

    if (_statusFilter == 'Cancelled') {
      result = result.where((order) {
        final status = (order['status'] ?? '').toString().trim().toLowerCase();
        return status == 'cancelled' || status == 'canceled';
      }).toList();
    } else if (_statusFilter == 'On Hold') {
      result = result.where((order) {
        final status = (order['status'] ?? '').toString().trim().toLowerCase();
        return status == 'on hold' || status == 'hold';
      }).toList();
    } else if (_statusFilter == 'Returned') {
      result = result.where((order) {
        final status = (order['status'] ?? '').toString().trim().toLowerCase();
        return status == 'returned' || status == 'return';
      }).toList();
    }

    if (q.isNotEmpty) {
      result = result.where((order) {
        final orderId = (order['order_id'] ?? '').toString().toLowerCase();
        final phone = (order['phone_number'] ?? '').toString().toLowerCase();
        final status = (order['status'] ?? '').toString().toLowerCase();
        final address = (order['billing_address'] ?? '')
            .toString()
            .toLowerCase();

        final products = (order['products'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        final hasProductMatch = products.any((p) {
          final name = (p['name'] ?? '').toString().toLowerCase();
          final sku = (p['sku_code'] ?? '').toString().toLowerCase();
          final brand = (p['brand_name'] ?? '').toString().toLowerCase();
          return name.contains(q) || sku.contains(q) || brand.contains(q);
        });

        return orderId.contains(q) ||
            phone.contains(q) ||
            status.contains(q) ||
            address.contains(q) ||
            hasProductMatch;
      }).toList();
    }

    setState(() {
      _filtered = result;
    });
  }

  String _productName(Map<String, dynamic> p) {
    return (p['name'] ?? p['product_name'] ?? p['medicine_name'] ?? '-')
        .toString();
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

  int _productCount(Map<String, dynamic> order) {
    return (order['products'] as List? ?? []).length;
  }

  int _totalQty(Map<String, dynamic> order) {
    final products = (order['products'] as List? ?? []);
    return products.fold<int>(0, (sum, item) {
      final p = Map<String, dynamic>.from(item as Map);
      return sum + ((p['quantity'] as num?)?.toInt() ?? 0);
    });
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '-';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return raw.toString();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
  }

  String _formatMoney(dynamic raw) {
    final value = double.tryParse(raw.toString()) ?? 0.0;
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }

  String _formatMoneyPrecise(num? raw) {
    final value = raw?.toDouble() ?? 0;
    return '₹${value.toStringAsFixed(2)}';
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

  String _statusLabel(String status) {
    final s = status.trim();
    if (s.isEmpty) return 'NEW';
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  String _deliveryLabel(Map<String, dynamic> order) {
    final status = (order['status'] ?? '').toString().trim().toLowerCase();

    switch (status) {
      case 'delivered':
        return 'Delivered';

      case 'cancelled':
        return 'Status';

      case 'returned':
        return 'Status';

      default:
        return 'Expected delivery';
    }
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Search by order id, phone, product or status...',
          prefixIcon: const Icon(Icons.search_rounded, color: mutedColor),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          hintStyle: const TextStyle(
            color: mutedColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: ordersPrimaryBlue, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilters() {
    final filters = ['All', 'Cancelled', 'On Hold', 'Returned'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters.map((filter) {
        final isSelected = _statusFilter == filter;

        return ChoiceChip(
          showCheckmark: false,
          label: Text(filter),
          selected: isSelected,
          onSelected: (_) {
            setState(() {
              _statusFilter = filter;
            });
            _applyFilter();
          },
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : kInk,
          ),
          selectedColor: kBlue,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: isSelected ? kBlue : kLine),
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        );
      }).toList(),
    );
  }

  Widget _buildPlaceOrderFab() {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddOrderScreen()));
      },
      backgroundColor: kBlue,
      elevation: 6,
      icon: const Icon(
        Icons.shopping_cart_outlined,
        color: Colors.white,
        size: 20,
      ),
      label: const Text(
        'Place Order',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildErrorView() {
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
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: mutedColor),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loadOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: ordersPrimaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 42,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 10),
            const Text(
              'No orders found',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: headingColor,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Placed orders for this pharma user will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniMeta(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: pageBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontFamily: 'Roboto'),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontSize: 10,
                color: mutedColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 10.5,
                color: headingColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = (order['status'] ?? 'new').toString();
    final orderId = (order['order_id'] ?? '-').toString();
    final distributor = (order['distributor'] as Map<String, dynamic>?) ?? {};

    final distributorName =
        (distributor['company_name'] ?? 'Unknown Distributor').toString();
    final distributorPhone = (distributor['company_phone'] ?? '').toString();
    final contactName = (distributor['contact_name'] ?? '').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showOrderDetails(order),
      child: Container(
        padding: const EdgeInsets.all(14),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        orderId,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: headingColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        distributorName,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: headingColor,
                        ),
                      ),
                      if (distributorPhone.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          distributorPhone,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: mutedColor,
                          ),
                        ),
                      ],
                      if (contactName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Contact: $contactName',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: mutedColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusBg(status),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _statusFg(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _miniMeta('Date', _formatDate(order['order_date'])),
                _miniMeta('Amount', _formatMoney(order['total_amount'])),
                _miniMeta('Products', '${_productCount(order)}'),
                _miniMeta('Qty', '${_totalQty(order)}'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    (order['billing_address'] ?? '-').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: mutedColor,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: mutedColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableBody() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 140),
        children: const [
          Center(child: CircularProgressIndicator(color: ordersPrimaryBlue)),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: 420, child: _buildErrorView())],
      );
    }

    if (_filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: 420, child: _buildEmptyView())],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) => _buildOrderCard(_filtered[index]),
    );
  }

  Widget _buildContent(PharmaCartProvider cart) {
    return Column(
      children: [
        PharmaPageHeader(
          title: 'Ongoing Orders',
          showMenu: true,
          showNotification: false,
          showCart: true,
          cartCount: cart.itemCount,
          onMenu: widget.onOpenDrawer,
          onCart: () => showPharmaCartSheet(context),
        ),
        _buildSearchBar(),
        _buildStatusFilters(),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            color: pageBg,
            child: RefreshIndicator(
              color: ordersPrimaryBlue,
              onRefresh: _loadOrders,
              child: _buildScrollableBody(),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final cart = context.watch<PharmaCartProvider>();

    return Scaffold(
      backgroundColor: pageBg,
      floatingActionButton: _buildPlaceOrderFab(),
      body: SafeArea(bottom: false, child: _buildContent(cart)),
    );
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
}

class _TableHeadStyle {
  static const style = TextStyle(
    fontSize: 10.5,
    color: mutedColor,
    fontWeight: FontWeight.w700,
  );
}
