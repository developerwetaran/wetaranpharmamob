import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:wetaran_pharma/core/widgets/reusable_pharma_header.dart';
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
              registered_office_address,
              warehouse_address,
              partner_type,
              status,
              is_active
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

    setState(() {
      if (q.isEmpty) {
        _filtered = List<Map<String, dynamic>>.from(_orders);
        return;
      }

      _filtered = _orders.where((order) {
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
    });
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
    final value = (raw as num?)?.toDouble() ?? 0;
    return '₹${value.toStringAsFixed(0)}';
  }

  String _formatMoneyPrecise(num? raw) {
    final value = raw?.toDouble() ?? 0;
    return '₹${value.toStringAsFixed(2)}';
  }

  Color _statusBg(String status) {
    switch (status.toLowerCase()) {
      case 'booked':
      case 'delivered':
        return greenSoft;
      case 'new':
      case 'pending':
      case 'processing':
        return amberSoft;
      case 'cancelled':
        return redSoft;
      default:
        return const Color(0xFFE8F0FF);
    }
  }

  Color _statusFg(String status) {
    switch (status.toLowerCase()) {
      case 'booked':
      case 'delivered':
        return green;
      case 'new':
      case 'pending':
      case 'processing':
        return amber;
      case 'cancelled':
        return red;
      default:
        return ordersPrimaryBlue;
    }
  }

  String _statusLabel(String status) {
    final s = status.trim();
    if (s.isEmpty) return 'NEW';
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  String _expectedDeliveryText(Map<String, dynamic> order) {
    final raw =
        order['expected_delivery'] ??
        order['delivery_date'] ??
        order['expected_delivery_date'];
    if (raw == null) return 'Not available';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return raw.toString();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
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
    final orderId = (order['order_id'] ?? '—').toString();
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
          title: 'Orders Page',
          showMenu: true,
          showNotification: false,
          showCart: true,
          cartCount: cart.itemCount,
          onMenu: widget.onOpenDrawer,
          onCart: () => showPharmaCartSheet(context),
        ),
        _buildSearchBar(),
        //_buildSummaryBlock(),
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
                        _kvRow('Distributor', distributorName),
                        _kvRow('Company Phone', distributorPhone),
                        _kvRow('Company Email', distributorEmail),
                        _kvStatusRow('Status', status),
                        _kvRow(
                          'Expected delivery',
                          _expectedDeliveryText(order),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Items — ${products.length} products · ${_totalQty(order)} units',
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
                        _kvRow('Cashback', 'Not available'),
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

            final qty = ((product['quantity'] as num?)?.toInt() ?? 0);
            final unit = (product['unit'] ?? product['primary_unit'] ?? '')
                .toString();
            final total = (product['total_price'] as num?)?.toDouble() ?? 0.0;
            final ptr =
                (product['ptr'] as num?)?.toDouble() ??
                (product['sell_price'] as num?)?.toDouble() ??
                0.0;

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
                          (product['name'] ?? '-').toString(),
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
