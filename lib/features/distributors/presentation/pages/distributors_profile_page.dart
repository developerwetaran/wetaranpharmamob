import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'distributors_page.dart';

class DistributorProfilePage extends StatefulWidget {
  final DistributorSummary distributor;
  final String pharmaUserId;

  const DistributorProfilePage({
    super.key,
    required this.distributor,
    required this.pharmaUserId,
  });

  @override
  State<DistributorProfilePage> createState() => _DistributorProfilePageState();
}

class _DistributorProfilePageState extends State<DistributorProfilePage> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool loading = true;
  String? error;
  List<Map<String, dynamic>> allOrders = [];
  List<Map<String, dynamic>> filteredOrders = [];

  DateTime? fromDate;
  DateTime? toDate;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      if (widget.pharmaUserId.trim().isEmpty) {
        throw Exception('Invalid pharma user id');
      }

      final rows = await supabase
          .from('orders')
          .select('''
          id,
          order_id,
          order_date,
          status,
          total_amount,
          products,
          billing_address,          
          notes
        ''')
          .eq('pharma_user_id', widget.pharmaUserId)
          .eq('distributor_id', widget.distributor.id)
          .order('order_date', ascending: false);

      final list = List<Map<String, dynamic>>.from(
        (rows as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );

      if (!mounted) return;
      setState(() {
        allOrders = list;
        filteredOrders = list.take(10).toList();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  void _applyDateFilter() {
    List<Map<String, dynamic>> result = List<Map<String, dynamic>>.from(
      allOrders,
    );

    if (fromDate != null) {
      result = result.where((o) {
        final dt = DateTime.tryParse((o['order_date'] ?? '').toString());
        if (dt == null) return false;
        return !dt.isBefore(
          DateTime(fromDate!.year, fromDate!.month, fromDate!.day),
        );
      }).toList();
    }

    if (toDate != null) {
      final end = DateTime(
        toDate!.year,
        toDate!.month,
        toDate!.day,
        23,
        59,
        59,
      );
      result = result.where((o) {
        final dt = DateTime.tryParse((o['order_date'] ?? '').toString());
        if (dt == null) return false;
        return !dt.isAfter(end);
      }).toList();
    }

    setState(() {
      filteredOrders = result;
    });
  }

  void _resetFilter() {
    setState(() {
      fromDate = null;
      toDate = null;
      filteredOrders = allOrders.take(10).toList();
    });
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: fromDate ?? now,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() => fromDate = picked);
    }
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: toDate ?? now,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() => toDate = picked);
    }
  }

  String _formatMoney(num? value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format((value ?? 0).toDouble());
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '-';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return raw.toString();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
  }

  int _productCount(Map<String, dynamic> order) {
    final products = order['products'] as List? ?? [];
    return products.length;
  }

  int _totalQty(Map<String, dynamic> order) {
    final products = order['products'] as List? ?? [];
    return products.fold<int>(0, (sum, item) {
      final p = Map<String, dynamic>.from(item as Map);
      return sum + (((p['quantity'] as num?) ?? 0).toInt());
    });
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kBlue, kBlueDk, Color(0xFF06304F)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.13),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.distributor.companyName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.distributor.companyPhone.isEmpty
                      ? 'Distributor profile'
                      : widget.distributor.companyPhone,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, {bool blue = false}) {
    return Container(
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
            width: 112,
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
              value.trim().isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: blue ? 15 : 12.5,
                color: blue ? kBlue : headingColor,
                fontWeight: blue ? FontWeight.w800 : FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, String sub) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: mutedColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              color: headingColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 11,
              color: mutedColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateButton({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: headingColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = (order['status'] ?? 'new').toString();
    final orderId = (order['order_id'] ?? order['id'] ?? '-').toString();

    return Container(
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
            children: [
              Expanded(
                child: Text(
                  orderId,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: headingColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusBg(status),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: _statusFg(status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatDate(order['order_date']),
            style: const TextStyle(
              fontSize: 11.5,
              color: mutedColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniMeta('Items', '${_productCount(order)}'),
              _miniMeta('Qty', '${_totalQty(order)}'),
              _miniMeta(
                'Value',
                _formatMoney((order['total_amount'] as num?) ?? 0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniMeta(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: pageBg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: borderColor),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                fontSize: 10.5,
                color: mutedColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 10.8,
                color: headingColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _servicePincodes() {
    final coverage = widget.distributor.serviceCoverage;
    final regions = (coverage['regions'] as List?) ?? [];

    final pins = <String>{};

    for (final regionRaw in regions) {
      final region = Map<String, dynamic>.from(regionRaw as Map);
      final cities = (region['cities'] as List?) ?? [];

      for (final cityRaw in cities) {
        final city = Map<String, dynamic>.from(cityRaw as Map);
        final pincodes = (city['pincodes'] as List?) ?? [];

        for (final pin in pincodes) {
          final value = pin.toString().trim();
          if (value.isNotEmpty) {
            pins.add(value);
          }
        }
      }
    }

    final list = pins.toList()..sort();
    return list;
  }

  Widget _buildServiceAreaCard() {
    final pincodes = _servicePincodes();

    if (pincodes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: const Text(
          'Service area not available',
          style: TextStyle(
            fontSize: 12.5,
            color: mutedColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Serviced Area — Postal Codes',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: headingColor,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: pincodes.map((pin) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F3F3),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  pin,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF238B8B),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String prettifyDeliveryMode(String value) {
    final cleaned = value.trim().replaceAll('_', ' ');
    if (cleaned.isEmpty) return '-';
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  String buildDeliveryInfoText({
    required String expectedDelivery,
    required String cutoff,
  }) {
    final mode = prettifyDeliveryMode(expectedDelivery);
    final cutoffText = cutoff.trim();

    if (cutoffText.isEmpty) return mode;
    return '$mode · order before $cutoffText';
  }

  Widget _deliveryChip() {
    final text = buildDeliveryInfoText(
      expectedDelivery: widget.distributor.pharmaExpectedDelivery,
      cutoff: widget.distributor.pharmaSameDayOrderCutoff,
    );

    if (text.trim().isEmpty || text == '-') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_shipping_outlined,
            size: 16,
            color: Color(0xFF1D4ED8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E3A8A),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: ordersPrimaryBlue),
      );
    }

    if (error != null) {
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
                error!,
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

    final orderCount = filteredOrders.length;
    final totalValue = filteredOrders.fold<double>(
      0,
      (sum, o) => sum + (((o['total_amount'] as num?) ?? 0).toDouble()),
    );

    return RefreshIndicator(
      color: ordersPrimaryBlue,
      onRefresh: _loadOrders,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        children: [
          _infoTile('Company name', widget.distributor.companyName),
          const SizedBox(height: 10),
          _infoTile('Company phone', widget.distributor.companyPhone),
          const SizedBox(height: 10),
          _infoTile('Company email', widget.distributor.companyEmail),
          const SizedBox(height: 10),
          _infoTile('Contact name', widget.distributor.contactName),
          const SizedBox(height: 10),
          _infoTile('Contact phone', widget.distributor.contactPhone),
          const SizedBox(height: 10),
          _infoTile('GSTIN', widget.distributor.gstin),
          const SizedBox(height: 10),
          _infoTile('Drug licence', widget.distributor.drugLicenseNo),
          const SizedBox(height: 10),
          _infoTile('Office', widget.distributor.registeredOfficeAddress),
          const SizedBox(height: 10),
          _infoTile('Warehouse', widget.distributor.warehouseAddress),
          const SizedBox(height: 16),
          _deliveryChip(),

          const SizedBox(height: 16),

          _infoTile(
            'Order before',
            widget.distributor.pharmaSameDayOrderCutoff,
          ),
          const SizedBox(height: 16),
          _buildServiceAreaCard(),
          const SizedBox(height: 16),
          const Text(
            'Order & Coverage',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: headingColor,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _dateButton(
                      label: 'From date',
                      value: fromDate == null
                          ? 'Select'
                          : DateFormat('dd MMM yyyy').format(fromDate!),
                      onTap: _pickFromDate,
                    ),
                    const SizedBox(width: 10),
                    _dateButton(
                      label: 'To date',
                      value: toDate == null
                          ? 'Select'
                          : DateFormat('dd MMM yyyy').format(toDate!),
                      onTap: _pickToDate,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _applyDateFilter,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0FA3A3),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Apply dates',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _resetFilter,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kBlue,
                          side: const BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Reset',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Default shows the last 10 orders. Apply a date range to browse full history.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: mutedColor,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  'Orders',
                  '$orderCount',
                  'Shown in current filter',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kpiCard(
                  'Order value',
                  _formatMoney(totalValue),
                  'Total for shown orders',
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          if (filteredOrders.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 36,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No orders found for this filter',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: headingColor,
                    ),
                  ),
                ],
              ),
            )
          else
            ...filteredOrders.map(
              (order) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildOrderCard(order),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
}
