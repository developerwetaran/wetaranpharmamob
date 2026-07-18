import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wetaran_pharma/core/widgets/reusable_pharma_header.dart';
import 'package:wetaran_pharma/features/distributors/presentation/pages/distributors_profile_page.dart';
import 'package:wetaran_pharma/features/distributors/models/distributor_summary.dart';

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

class PharmaPurchaseHistoryPage extends StatefulWidget {
  const PharmaPurchaseHistoryPage({super.key});

  @override
  State<PharmaPurchaseHistoryPage> createState() =>
      _PharmaPurchaseHistoryPageState();
}

class _PharmaPurchaseHistoryPageState extends State<PharmaPurchaseHistoryPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  String? _pharmaUserId;

  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _filtered = [];

  DateTime? fromDate;
  DateTime? toDate;
  DateTime? selectedMonth;
  String _statusFilter = 'All';

  static const Color kBlue = Color(0xFF0B4F8A);
  static const Color kBlueDark = Color(0xFF083A66);
  static const Color kTeal = Color(0xFF0FA3A3);
  static const Color kBg = Color(0xFFF3F7FA);
  static const Color kLine = Color(0xFFE3EBF1);
  static const Color kInk = Color(0xFF13242F);
  static const Color kMuted = Color(0xFF63788A);
  static const Color kGreen = Color(0xFF15803D);
  static const Color kGreenSoft = Color(0xFFEAF8EE);
  static const Color kAmber = Color(0xFFB36A00);
  static const Color kAmberSoft = Color(0xFFFFF4E0);
  static const Color kRed = Color(0xFFC2410C);
  static const Color kRedSoft = Color(0xFFFFEFEA);

  @override
  void initState() {
    super.initState();
    selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _searchCtrl.addListener(_applyFilter);
    _loadOrders();
  }

  @override
  void dispose() {
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

      _applyFilter();
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

    if (selectedMonth != null) {
      result = result.where((o) {
        final dt = DateTime.tryParse((o['order_date'] ?? '').toString());
        if (dt == null) return false;
        return dt.year == selectedMonth!.year &&
            dt.month == selectedMonth!.month;
      }).toList();
    }

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

    if (_statusFilter != 'All') {
      result = result.where((o) {
        final status = (o['status'] ?? '').toString().trim().toLowerCase();

        if (_statusFilter == 'Cancelled') {
          return status == 'cancelled' || status == 'canceled';
        }

        if (_statusFilter == 'On Hold') {
          return status == 'on hold' || status == 'hold';
        }

        if (_statusFilter == 'Returned') {
          return status == 'returned' || status == 'returned';
        }

        return true;
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

  void _resetFilter() {
    setState(() {
      fromDate = null;
      toDate = null;
      selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
      _searchCtrl.clear();
    });
    _applyFilter();
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
      setState(() {
        fromDate = picked;
        selectedMonth = null;
      });
      _applyFilter();
    }
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: toDate ?? fromDate ?? now,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(now.year + 1),
    );

    if (picked != null) {
      setState(() {
        toDate = picked;
        selectedMonth = null;
      });
      _applyFilter();
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showMonthPicker(
      context: context,
      initialDate: selectedMonth ?? DateTime.now(),
      firstDate: DateTime(2024, 1),
      lastDate: DateTime(DateTime.now().year + 1, 12),
    );

    if (picked != null) {
      setState(() {
        selectedMonth = DateTime(picked.year, picked.month, 1);
        fromDate = null;
        toDate = null;
      });

      _applyFilter();
    }
  }

  String _formatMoney(dynamic raw) {
    final value = double.tryParse(raw.toString()) ?? 0.0;
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }

  String _formatCompact(dynamic raw) {
    final value = double.tryParse(raw.toString()) ?? 0.0;
    return NumberFormat.decimalPattern('en_IN').format(value.round());
  }

  DateTime? _orderDate(Map<String, dynamic> order) {
    return DateTime.tryParse((order['order_date'] ?? '').toString());
  }

  double _orderAmount(Map<String, dynamic> order) {
    final candidates = [
      order['total_amount'],
      order['grand_total'],
      order['net_amount'],
      order['amount'],
    ];

    for (final c in candidates) {
      final v = double.tryParse(c.toString());
      if (v != null) return v;
    }
    return 0.0;
  }

  bool _isDelivered(Map<String, dynamic> order) {
    final status = (order['status'] ?? '').toString().trim().toLowerCase();
    return status == 'delivered';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return kGreen;
      case 'cancelled':
      case 'canceled':
        return kRed;
      case 'pending':
        return kAmber;
      default:
        return kBlue;
    }
  }

  Color _statusBg(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return kGreenSoft;
      case 'cancelled':
      case 'canceled':
        return kRedSoft;
      case 'pending':
        return kAmberSoft;
      default:
        return const Color(0xFFEAF2FF);
    }
  }

  int get _deliveredCount => _filtered.where((o) => _isDelivered(o)).length;

  double get _deliveredAmount => _filtered
      .where((o) => _isDelivered(o))
      .fold(0.0, (sum, o) => sum + _orderAmount(o));

  double get _overallAmount =>
      _filtered.fold(0.0, (sum, o) => sum + _orderAmount(o));

  double get _cashbackEarned => _overallAmount * 0.01;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            const PharmaPageHeader(
              title: 'Purchase History',
              showBack: true,
              showMenu: false,
              showNotification: false,
              showCart: false,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _buildError()
                  : RefreshIndicator(
                      color: kBlue,
                      onRefresh: _loadOrders,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          const SizedBox(height: 10),
                          _buildHistoryIntro(),
                          const SizedBox(height: 14),
                          _buildFilterCard(),
                          const SizedBox(height: 14),
                          _buildSummaryCards(),
                          const SizedBox(height: 14),
                          _buildSearchBar(),
                          const SizedBox(height: 10),
                          _buildStatusFilters(),
                          const SizedBox(height: 14),
                          _buildListHeader(),
                          const SizedBox(height: 14),
                          if (_filtered.isEmpty) _buildEmptyState(),
                          ..._filtered.map(_buildOrderCard),
                        ],
                      ),
                    ),
            ),
          ],
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

  Widget _buildHistoryIntro() {
    String periodText;

    if (selectedMonth != null) {
      periodText = DateFormat('MMMM yyyy').format(selectedMonth!);
    } else if (fromDate != null && toDate != null) {
      periodText =
          '${DateFormat('dd MMM yyyy').format(fromDate!)} - ${DateFormat('dd MMM yyyy').format(toDate!)}';
    } else if (fromDate != null) {
      periodText = 'From ${DateFormat('dd MMM yyyy').format(fromDate!)}';
    } else if (toDate != null) {
      periodText = 'Up to ${DateFormat('dd MMM yyyy').format(toDate!)}';
    } else {
      periodText = DateFormat(
        'MMMM yyyy',
      ).format(DateTime(DateTime.now().year, DateTime.now().month, 1));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Purchase History',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: kInk,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Delivered purchases · showing $periodText · records available for the last 18 months',
          style: const TextStyle(
            fontSize: 12.5,
            color: kMuted,
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kLine),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 34, color: kAmber),
              const SizedBox(height: 10),
              Text(
                _error ?? 'Something went wrong',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadOrders,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTeal,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Purchases in Period',
                value: _formatCompact(_deliveredAmount),
                sub: '$_deliveredCount delivered orders',
                valueColor: kAmber,
                subColor: kMuted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _KpiCard(
                label: 'Total Value',
                value: _formatCompact(_overallAmount),
                sub: 'Sum of all purchases',
                valueColor: kBlue,
                subColor: kMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Cashback Earned',
                value: _formatMoney(_cashbackEarned),
                sub: '1% on every order',
                valueColor: kGreen,
                subColor: kMuted,
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLine),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (_) => _applyFilter(),
        style: const TextStyle(
          fontSize: 13.5,
          color: kInk,
          fontWeight: FontWeight.w600,
        ),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search_rounded, color: kMuted),
          hintText: 'Search by order id, product, status, phone',
          hintStyle: TextStyle(
            color: kMuted,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLine),
      ),
      child: Column(
        children: [
          _dateButton(
            label: 'Month',
            value: selectedMonth == null
                ? 'Select month'
                : DateFormat('MMM yyyy').format(selectedMonth!),
            onTap: _pickMonth,
            icon: Icons.calendar_view_month_rounded,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _dateButton(
                  label: 'From date',
                  value: fromDate == null
                      ? 'Select'
                      : DateFormat('dd MMM yyyy').format(fromDate!),
                  onTap: _pickFromDate,
                  icon: Icons.event_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dateButton(
                  label: 'To date',
                  value: toDate == null
                      ? 'Select'
                      : DateFormat('dd MMM yyyy').format(toDate!),
                  onTap: _pickToDate,
                  icon: Icons.date_range_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _applyFilter,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: kTeal,
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
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: kBlue,
                    side: const BorderSide(color: kLine),
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
        ],
      ),
    );
  }

  Widget _dateButton({
    required String label,
    required String value,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kLine),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: kBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10.8,
                      color: kMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.6,
                      color: kInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListHeader() {
    return Row(
      children: [
        const Text(
          'Purchases',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: kInk,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${_filtered.length} orders',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: kBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLine),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 34, color: kMuted),
          SizedBox(height: 10),
          Text(
            'No purchases found for the selected filters',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: kInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = (order['status'] ?? 'Unknown').toString();
    final orderId = (order['order_id'] ?? '-').toString();
    final dt = _orderDate(order);
    final dateText = dt == null
        ? '-'
        : DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    final amount = _orderAmount(order);

    final distributor = Map<String, dynamic>.from(
      (order['distributor'] as Map?) ?? <String, dynamic>{},
    );

    final distributorName = (distributor['company_name'] ?? 'Distributor')
        .toString();
    final address = (order['billing_address'] ?? '').toString();
    final phone = (order['phone_number'] ?? '').toString();

    final products = (order['products'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final productCount = products.length;
    final firstProduct = productCount > 0
        ? (products.first['name'] ?? 'Product').toString()
        : 'No product details';

    final cashback = amount * 0.01;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showOrderDetails(order),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kLine),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x080B4F8A),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '#$orderId',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.4,
                            fontWeight: FontWeight.w800,
                            color: kBlue,
                            letterSpacing: .1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _statusBg(status),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          status.isNotEmpty
                              ? '${status[0].toUpperCase()}${status.substring(1)}'
                              : '',
                          style: TextStyle(
                            fontSize: 10.8,
                            fontWeight: FontWeight.w800,
                            color: _statusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: kMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          dateText,
                          style: const TextStyle(
                            fontSize: 11.4,
                            color: kMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatMoney(amount),
                            style: const TextStyle(
                              fontSize: 15.2,
                              color: kBlue,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Cashback ${_formatMoney(cashback)}',
                            style: const TextStyle(
                              fontSize: 10.8,
                              color: kTeal,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openDistributorProfile(distributor),
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
                                  firstProduct,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.6,
                                    color: kMuted,
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
                                        '$productCount item${productCount == 1 ? '' : 's'}',
                                        style: const TextStyle(
                                          fontSize: 10.6,
                                          color: green,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Tap to open distributor',
                                      style: TextStyle(
                                        fontSize: 10.8,
                                        color: kMuted,
                                        fontWeight: FontWeight.w600,
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
                  if (phone.isNotEmpty || address.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFCFE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF0F4F8)),
                      ),
                      child: Column(
                        children: [
                          if (phone.isNotEmpty)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.call_outlined,
                                  size: 14,
                                  color: kMuted,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    phone,
                                    style: const TextStyle(
                                      fontSize: 11.2,
                                      color: kMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (phone.isNotEmpty && address.isNotEmpty)
                            const SizedBox(height: 6),
                          if (address.isNotEmpty)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: kMuted,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    address,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.2,
                                      color: kMuted,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
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

  String _statusLabel(String status) {
    final s = status.trim();
    if (s.isEmpty) return 'NEW';
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
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

  String _formatMoneyPrecise(num? raw) {
    final value = raw?.toDouble() ?? 0;
    return '₹${value.toStringAsFixed(2)}';
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

  String _formatDate(dynamic value) {
    final dt = DateTime.tryParse((value ?? '').toString());
    if (dt == null) return '-';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  int _totalQty(Map<String, dynamic> order) {
    final products = (order['products'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return products.fold<int>(0, (sum, p) {
      final qty =
          int.tryParse((p['quantity'] ?? p['qty'] ?? 0).toString()) ?? 0;
      return sum + qty;
    });
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color valueColor;
  final Color subColor;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.valueColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EBF1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0B4F8A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.4,
              color: Color(0xFF63788A),
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value.startsWith('₹') ? value : '₹$value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15.5,
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            sub,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.2,
              color: subColor,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
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
