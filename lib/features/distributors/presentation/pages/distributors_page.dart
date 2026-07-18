import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

class DistributorsPage extends StatefulWidget {
  const DistributorsPage({super.key});

  @override
  State<DistributorsPage> createState() => _DistributorsPageState();
}

class _DistributorsPageState extends State<DistributorsPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool loading = true;
  String? error;
  String? pharmaUserId;
  List<DistributorSummary> distributors = [];
  List<DistributorSummary> filtered = [];
  final TextEditingController searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    searchCtrl.addListener(_applyFilter);
    _loadDistributors();
  }

  @override
  void dispose() {
    searchCtrl.removeListener(_applyFilter);
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDistributors() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final authUserId = supabase.auth.currentUser?.id;
      if (authUserId == null) {
        throw Exception('No logged-in user found');
      }

      final pharmaProfile = await supabase
          .from('pharma_users')
          .select('id, business_pincode')
          .eq('auth_user_id', authUserId)
          .maybeSingle();

      if (pharmaProfile == null) {
        throw Exception('Pharma user profile not found');
      }

      final currentPharmaUserId = (pharmaProfile['id'] ?? '').toString();
      final pincode = (pharmaProfile['business_pincode'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      if (currentPharmaUserId.isEmpty) {
        throw Exception('Invalid pharma user id');
      }

      if (pincode.isEmpty) {
        throw Exception('Business pincode not found');
      }

      final distributorRows = await supabase
          .from('distributor')
          .select('''
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
        ''')
          .eq('is_active', true)
          .eq('is_available_on_pharma_marketplace', true);

      bool matchesPincode(Map<String, dynamic> coverage) {
        final regions = (coverage['regions'] as List?) ?? [];

        for (final regionItem in regions) {
          final region = Map<String, dynamic>.from(regionItem as Map);
          final cities = (region['cities'] as List?) ?? [];

          for (final cityItem in cities) {
            final cityMap = Map<String, dynamic>.from(cityItem as Map);
            final pincodes = (cityMap['pincodes'] as List? ?? [])
                .map((e) => e.toString().trim().toLowerCase())
                .toList();

            if (pincodes.contains(pincode)) {
              return true;
            }
          }
        }

        return false;
      }

      final Map<String, DistributorSummaryBuilder> grouped = {};

      for (final raw in distributorRows as List) {
        final distributorMap = Map<String, dynamic>.from(raw as Map);

        final distributorId = (distributorMap['id'] ?? '').toString();
        if (distributorId.isEmpty) continue;

        final coverage = distributorMap['service_coverage'] is Map
            ? Map<String, dynamic>.from(
                distributorMap['service_coverage'] as Map,
              )
            : <String, dynamic>{};

        if (!matchesPincode(coverage)) continue;

        grouped[distributorId] = DistributorSummaryBuilder(
          id: distributorId,
          companyName: (distributorMap['company_name'] ?? '-').toString(),
          companyPhone: (distributorMap['company_phone'] ?? '').toString(),
          companyEmail: (distributorMap['company_email'] ?? '').toString(),
          contactName: (distributorMap['contact_name'] ?? '').toString(),
          contactPhone: (distributorMap['contact_phone'] ?? '').toString(),
          contactEmail: (distributorMap['contact_email'] ?? '').toString(),
          gstin: (distributorMap['gstin'] ?? '').toString(),
          drugLicenseNo: (distributorMap['drug_license_no'] ?? '').toString(),
          registeredOfficeAddress:
              (distributorMap['registered_office_address'] ?? '').toString(),
          warehouseAddress: (distributorMap['warehouse_address'] ?? '')
              .toString(),
          partnerType: (distributorMap['partner_type'] ?? '').toString(),
          status: (distributorMap['status'] ?? '').toString(),
          isActive: (distributorMap['is_active'] as bool?) ?? false,
          serviceCoverage: coverage,
          pharmaExpectedDelivery:
              (distributorMap['pharma_expected_delivery'] ?? '').toString(),
          pharmaSameDayOrderCutoff:
              (distributorMap['pharma_same_day_order_cutoff'] ?? '').toString(),
        );
      }

      if (grouped.isNotEmpty) {
        final orderRows = await supabase
            .from('orders')
            .select('distributor_id, total_amount, products')
            .eq('pharma_user_id', currentPharmaUserId)
            .inFilter('distributor_id', grouped.keys.toList());

        for (final raw in orderRows as List) {
          final order = Map<String, dynamic>.from(raw as Map);
          final distributorId = (order['distributor_id'] ?? '').toString();

          final builder = grouped[distributorId];
          if (builder == null) continue;

          final totalAmount = ((order['total_amount'] as num?) ?? 0).toDouble();
          final products = (order['products'] as List?) ?? [];
          final itemCount = products.length;

          builder
            ..orderCount += 1
            ..totalOrderedValue += totalAmount
            ..totalItems += itemCount;
        }
      }

      final built = grouped.values.map((e) => e.build()).toList()
        ..sort((a, b) {
          final scoreCompare = b.orderCount.compareTo(a.orderCount);
          if (scoreCompare != 0) return scoreCompare;
          return a.companyName.toLowerCase().compareTo(
            b.companyName.toLowerCase(),
          );
        });

      if (!mounted) return;
      setState(() {
        pharmaUserId = currentPharmaUserId;
        distributors = built;
        filtered = List<DistributorSummary>.from(built);
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

  void _applyFilter() {
    final q = searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        filtered = List<DistributorSummary>.from(distributors);
        return;
      }

      filtered = distributors.where((d) {
        return d.companyName.toLowerCase().contains(q) ||
            d.companyPhone.toLowerCase().contains(q) ||
            d.companyEmail.toLowerCase().contains(q) ||
            d.contactName.toLowerCase().contains(q) ||
            d.registeredOfficeAddress.toLowerCase().contains(q) ||
            d.warehouseAddress.toLowerCase().contains(q);
      }).toList();
    });
  }

  String _formatMoney(num value) {
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(value);
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Distributors',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'See distributors available for your location.',
                  style: TextStyle(
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: TextField(
        controller: searchCtrl,
        decoration: InputDecoration(
          hintText: 'Search distributor, phone, email or address...',
          prefixIcon: const Icon(Icons.search_rounded, color: mutedColor),
          suffixIcon: searchCtrl.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    searchCtrl.clear();
                    _applyFilter();
                  },
                  icon: const Icon(Icons.close_rounded, color: mutedColor),
                )
              : null,
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

  Widget _buildSummaryStrip() {
    final totalOrders = filtered.fold<int>(0, (sum, e) => sum + e.orderCount);
    final totalValue = filtered.fold<double>(
      0,
      (sum, e) => sum + e.totalOrderedValue,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _miniSummaryCard(
              icon: Icons.local_shipping_outlined,
              title: 'Distributors',
              value: '${filtered.length}',
              subtitle: 'Available in this list',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _miniSummaryCard(
              icon: Icons.receipt_long_outlined,
              title: 'Orders',
              value: '$totalOrders',
              subtitle: _formatMoney(totalValue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: kBlue, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: mutedColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    color: headingColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: mutedColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributorCard(DistributorSummary d) {
    final location = _compactLocation(
      d.registeredOfficeAddress,
      d.warehouseAddress,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DistributorProfilePage(
              distributor: d,
              pharmaUserId: pharmaUserId ?? '',
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              d.companyName,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: headingColor,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              location.isEmpty ? 'Address not available' : location,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: mutedColor,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${d.orderCount} orders with you · ${_formatMoney(d.totalOrderedValue)} total',
              style: const TextStyle(
                fontSize: 12,
                color: headingColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            /*
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (d.gstin.trim().isNotEmpty)
                  _badge('GST verified', greenSoft, green),
                if (d.drugLicenseNo.trim().isNotEmpty)
                  _badge(
                    'Drug licence on file',
                    const Color(0xFFE8F0FF),
                    kBlue,
                  ),
                _badge(
                  d.isActive ? 'Active' : 'Inactive',
                  d.isActive ? const Color(0xFFE8F6EE) : redSoft,
                  d.isActive ? green : red,
                ),
              ],
            ),
            */
            //const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DistributorProfilePage(
                      distributor: d,
                      pharmaUserId: pharmaUserId ?? '',
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: kBlue,
                side: const BorderSide(color: kBlue, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
              ),
              child: const Text(
                'View profile',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _compactLocation(String office, String warehouse) {
    final source = office.trim().isNotEmpty ? office : warehouse;
    if (source.trim().isEmpty) return '';
    final cleaned = source
        .replaceAll('\n', ', ')
        .replaceAll(RegExp(r'\s+'), ' ');
    return cleaned;
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: ordersPrimaryBlue),
    );
  }

  Widget _buildError() {
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
              error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(color: mutedColor),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loadDistributors,
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

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, size: 42, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'No distributors found',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: headingColor,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Distributors from your past orders will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (loading) return _buildLoading();
    if (error != null) return _buildError();
    if (filtered.isEmpty) return _buildEmpty();

    return RefreshIndicator(
      color: ordersPrimaryBlue,
      onRefresh: _loadDistributors,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        children: [
          ...filtered.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildDistributorCard(d),
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
            _buildSearchBar(),
            _buildSummaryStrip(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
}
