// lib/features/orders/presentation/pages/pharma_preview_order_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wetaran_pharma/features/orders/models/pharma_cart_provider.dart';
import 'package:wetaran_pharma/features/orders/services/pharma_order_id_service.dart';

const _bg = Color(0xFFEFF3FA);
const _card = Colors.white;
const _ink = Color(0xFF10233F);
const _inkSoft = Color(0xFF5B6B85);
const _inkFaint = Color(0xFF8C9AB1);
const _line = Color(0xFFE3E9F3);

const _blue900 = Color(0xFF0A2451);
const _blue800 = Color(0xFF0E3A7A);

const _teal600 = Color(0xFF0D9488);
const _teal500 = Color(0xFF14B8A6);
const _teal50 = Color(0xFFE9FBF8);

const _green = Color(0xFF15803D);
const _greenSoft = Color(0xFFEAF7EF);

const _red = Color(0xFFDC2626);
const _redSoft = Color(0xFFFEE2E2);

const _amber = Color(0xFFB45309);
const _amberSoft = Color(0xFFFFF7ED);
const _headingColor = Color(0xFF13242F);
const _mutedColor = Color(0xFF63788A);
const _faintColor = Color(0xFF93A6B5);
const _borderColor = Color(0xFFE3EBF1);
const _pageBg = Color(0xFFF3F7FA);

const _blue = Color(0xFF0B4F8A);

class DistributorOrderGroup {
  final String distributorId;
  final String distributorName;
  final List<PharmaCartItem> items;
  final String orderId;
  final double subtotal;
  final double minimumOrderValue;
  final String expectedDelivery;
  final String sameDayCutoff;

  DistributorOrderGroup({
    required this.distributorId,
    required this.distributorName,
    required this.items,
    required this.orderId,
    required this.subtotal,
    required this.minimumOrderValue,
    required this.expectedDelivery,
    required this.sameDayCutoff,
  });

  bool get meetsMOV => subtotal >= minimumOrderValue;

  double get shortfall => meetsMOV ? 0 : (minimumOrderValue - subtotal);
}

class PharmaPreviewOrderPage extends StatefulWidget {
  final PharmaCartProvider cart;

  const PharmaPreviewOrderPage({super.key, required this.cart});

  @override
  State createState() => _PharmaPreviewOrderPageState();
}

class _PharmaPreviewOrderPageState extends State<PharmaPreviewOrderPage> {
  final _db = Supabase.instance.client;
  final _notesCtrl = TextEditingController();

  bool _isPlacingOrder = false;
  bool _isSavingDraft = false;
  String? _errorMsg;

  String? _pharmaUserId;
  String? _customerName;
  String? _billingAddress;
  String? _phoneNumber;
  String? _userName;
  String? _businessState;
  String? _businessCity;
  String? _businessPincode;

  final Map<String, double> _minOrderMap = {};
  final Map<String, String> _deliveryMap = {};
  final Map<String, String> _cutoffMap = {};
  final Map<String, String> _orderIdMap = {};
  bool _loadingGroupMeta = true;

  Timer? deliveryTimer;

  @override
  void initState() {
    super.initState();
    _loadPharmaUserProfile();
    _initOrderGroups();
    deliveryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    deliveryTimer?.cancel();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPharmaUserProfile() async {
    final authId = _db.auth.currentUser?.id;
    if (authId == null) return;

    try {
      final row = await _db
          .from('pharma_users')
          .select(
            'id, business_name, phone_number, business_address, business_city, business_state, business_pincode',
          )
          .eq('auth_user_id', authId)
          .maybeSingle();

      final addressParts = [
        (row?['business_address'] as String?)?.trim(),
        (row?['business_city'] as String?)?.trim(),
        (row?['business_state'] as String?)?.trim(),
        (row?['business_pincode'] as String?)?.trim(),
      ].where((e) => e != null && e.isNotEmpty).cast<String>().toList();

      if (!mounted) return;

      setState(() {
        _pharmaUserId = row?['id'] as String?;
        _customerName = (row?['business_name'] as String?)?.trim();
        _phoneNumber = (row?['phone_number'] as String?)?.trim();
        _businessCity = (row?['business_city'] as String?)?.trim();
        _businessState = (row?['business_state'] as String?)?.trim();
        _businessPincode = (row?['business_pincode'] as String?)?.trim();
        _billingAddress = addressParts.join(', ');
        _userName = _customerName;
      });
    } catch (_) {}
  }

  Future<void> _initOrderGroups() async {
    final groups = _buildGroups(widget.cart.items);
    if (groups.isEmpty) {
      if (!mounted) return;
      setState(() => _loadingGroupMeta = false);
      return;
    }

    final distributorIds = groups.map((e) => e.distributorId).toList();
    await PharmaOrderIdService.initForDistributors(distributorIds);

    final futures = groups.map((g) async {
      final row = await _db
          .from('distributor')
          .select(
            'pharma_minimum_order_value, pharma_expected_delivery, pharma_same_day_order_cutoff',
          )
          .eq('id', g.distributorId)
          .maybeSingle();

      final minValue =
          (row?['pharma_minimum_order_value'] as num?)?.toDouble() ?? 0.0;
      final delivery = (row?['pharma_expected_delivery'] ?? '')
          .toString()
          .trim();
      final cutoff = (row?['pharma_same_day_order_cutoff'] ?? '')
          .toString()
          .trim();

      return {
        'id': g.distributorId,
        'min': minValue,
        'delivery': delivery,
        'cutoff': cutoff,
      };
    }).toList();

    final results = await Future.wait(futures);

    for (final r in results) {
      final id = r['id'] as String;
      _minOrderMap[id] = r['min'] as double;
      _deliveryMap[id] = r['delivery'] as String;
      _cutoffMap[id] = r['cutoff'] as String;
    }

    final idsToReserve = groups.map((e) => e.distributorId).toList();
    final reserved = <String, String>{};

    for (final distId in idsToReserve) {
      await PharmaOrderIdService.setActiveDistributor(distId);
      final nextId = PharmaOrderIdService.previewNextOrderId;
      reserved[distId] = nextId;
    }

    if (!mounted) return;
    setState(() {
      _orderIdMap.addAll(reserved);
      _loadingGroupMeta = false;
    });
  }

  List<DistributorOrderGroup> _buildGroups(List<PharmaCartItem> items) {
    final map = <String, List<PharmaCartItem>>{};
    for (final item in items) {
      map.putIfAbsent(item.distributorId, () => []);
      map[item.distributorId]!.add(item);
    }

    final groups = map.entries.map((entry) {
      final distributorId = entry.key;
      final groupItems = entry.value;
      final distributorName = groupItems.isNotEmpty
          ? groupItems.first.distributorName
          : 'Unknown distributor';
      final subtotal = groupItems.fold<double>(
        0,
        (sum, i) => sum + i.totalPrice,
      );

      return DistributorOrderGroup(
        distributorId: distributorId,
        distributorName: distributorName,
        items: groupItems,
        orderId: _orderIdMap[distributorId] ?? 'Loading...',
        subtotal: subtotal,
        minimumOrderValue: _minOrderMap[distributorId] ?? 0.0,
        expectedDelivery: _deliveryMap[distributorId] ?? '',
        sameDayCutoff: _cutoffMap[distributorId] ?? '',
      );
    }).toList();

    groups.sort((a, b) => a.distributorName.compareTo(b.distributorName));
    return groups;
  }

  DateTime getIndianTime() {
    final nowUtc = DateTime.now().toUtc();
    return nowUtc.add(const Duration(hours: 5, minutes: 30));
  }

  TimeOfDay? parseCutoff(String value) {
    final input = value
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toUpperCase();
    if (input.isEmpty) return null;

    final match = RegExp(
      r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)$',
    ).firstMatch(input);
    if (match == null) return null;

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2) ?? '0');
    final period = match.group(3)!;

    if (hour == 12) hour = 0;
    if (period == 'PM') hour += 12;

    return TimeOfDay(hour: hour, minute: minute);
  }

  int get nowIstMinutes {
    final nowUtc = DateTime.now().toUtc();
    final nowIst = nowUtc.add(const Duration(hours: 5, minutes: 30));
    return nowIst.hour * 60 + nowIst.minute;
  }

  bool _isBeforeCutoff(String cutoff) {
    final t = parseCutoff(cutoff);
    if (t == null) return false;
    return nowIstMinutes <= (t.hour * 60 + t.minute);
  }

  Duration? _timeLeftToCutoff(String cutoff) {
    final t = parseCutoff(cutoff);
    if (t == null) return null;

    final cutoffMinutes = t.hour * 60 + t.minute;
    final diffMinutes = cutoffMinutes - nowIstMinutes;
    if (diffMinutes <= 0) return Duration.zero;

    final nowUtc = DateTime.now().toUtc();
    final nowIst = nowUtc.add(const Duration(hours: 5, minutes: 30));
    final secondsIntoCurrentMinute = nowIst.second;
    final totalSeconds = (diffMinutes * 60) - secondsIntoCurrentMinute;
    return Duration(seconds: totalSeconds < 0 ? 0 : totalSeconds);
  }

  bool get _allMeetMOV {
    final groups = _buildGroups(widget.cart.items);
    return groups.every(
      (g) => (g.subtotal) >= (_minOrderMap[g.distributorId] ?? 0.0),
    );
  }

  Future<void> _placeOrder() async {
    if (_isPlacingOrder || _isSavingDraft) return;
    if (_pharmaUserId == null) throw Exception('User profile not loaded');

    final groups = _buildGroups(widget.cart.items);
    final blocked = groups.where((g) => !g.meetsMOV).toList();
    if (blocked.isNotEmpty) {
      final msg = blocked
          .map(
            (g) =>
                '${g.distributorName}: short by ₹${g.shortfall.toStringAsFixed(2)}',
          )
          .join('\n');
      throw Exception('Minimum order value not met for:\n$msg');
    }

    setState(() {
      _isPlacingOrder = true;
      _errorMsg = null;
    });

    try {
      final inserts = await Future.wait(
        groups.map((g) async {
          final distributorId = g.distributorId;
          await PharmaOrderIdService.setActiveDistributor(distributorId);
          final orderId = await PharmaOrderIdService.reserveNextOrderId();

          final products = g.items.map((i) => i.toOrderProduct()).toList();
          final totalAmount = g.subtotal;

          final inserted = await _db
              .from('orders')
              .insert({
                'order_id': orderId,
                'distributor_id': distributorId,
                'pharma_user_id': _pharmaUserId,
                'customer_name': _customerName,
                'billing_address': _billingAddress,
                'phone_number': _phoneNumber,
                'user_name': _userName ?? _customerName,
                'total_amount': totalAmount,
                'products': products,
                'notes': _notesCtrl.text.trim(),
                'status': 'booked',
                'business_state': _businessState,
                'business_city': _businessCity,
                'business_pincode': _businessPincode,
                'status_updated_at': DateTime.now().toIso8601String(),
                'order_date': getIndianTime().toIso8601String(),
              })
              .select('id, order_id')
              .single();

          final savedOrderId = inserted['order_id'] as String? ?? orderId;
          await PharmaOrderIdService.onOrderSaved(savedOrderId);

          return {
            'distributorId': distributorId,
            'distributorName': g.distributorName,
            'orderId': savedOrderId,
          };
        }),
      );

      if (!mounted) return;
      widget.cart.clear();

      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.45),
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x220A2451),
                  blurRadius: 28,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _greenSoft,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: _green,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Orders Placed!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your orders have been placed successfully.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _inkSoft,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ...inserts.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${e['distributorName']}: ${e['orderId']}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _teal600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _teal600,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Back to Home',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = 'Failed to place order: $e');
    } finally {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
      }
    }
  }

  String formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    String two(int v) => v.toString().padLeft(2, '0');

    if (hours > 0) {
      return '${two(hours)}h ${two(minutes)}m ${two(seconds)}s';
    }
    return '${two(minutes)}m ${two(seconds)}s';
  }

  @override
  Widget build(BuildContext context) {
    final groups = _buildGroups(widget.cart.items);

    return Scaffold(
      appBar: buildHeroAppBar(),
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  _buildOverviewCard(groups),
                  const SizedBox(height: 14),
                  ...groups.expand(
                    (group) => [
                      _buildDistributorGroupCard(group),
                      const SizedBox(height: 12),
                    ],
                  ),
                  _buildNotesCard(),
                  const SizedBox(height: 14),
                  _buildSummaryCard(groups),
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 12),
                    _buildErrorCard(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(groups),
    );
  }

  PreferredSizeWidget buildHeroAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_blue900, _blue800, Color(0xFF06304F)],
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: Colors.white,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Order Preview',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white.withOpacity(.10)),
      ),
    );
  }

  Widget _buildOverviewCard(List<DistributorOrderGroup> groups) {
    final allMeet = groups.every((g) => g.meetsMOV);

    return _surfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _leadingIconBox(
            icon: Icons.receipt_long_rounded,
            bg: _teal50,
            fg: _teal600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ORDER SUMMARY',
                  style: TextStyle(
                    fontSize: 11,
                    color: _inkSoft,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${groups.length} distributor order${groups.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  allMeet
                      ? 'All distributor orders meet MOV.'
                      : 'Some distributor orders are below MOV.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: allMeet ? _green : _red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributorGroupCard(DistributorOrderGroup group) {
    final beforeCutoff = _isBeforeCutoff(group.sameDayCutoff);
    final left = _timeLeftToCutoff(group.sameDayCutoff);

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _leadingIconBox(
                  icon: Icons.storefront_outlined,
                  bg: _greenSoft,
                  fg: _green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order ${_buildGroups(widget.cart.items).indexWhere((g) => g.distributorId == group.distributorId) + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _inkSoft,
                          letterSpacing: 0.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        group.distributorName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          metaInfoChip(
                            icon: Icons.receipt_long_rounded,
                            text: group.orderId,
                            bg: _teal50,
                            fg: _teal600,
                          ),
                          metaInfoChip(
                            icon: Icons.currency_rupee_rounded,
                            text: group.minimumOrderValue > 0
                                ? 'MOV ₹${group.minimumOrderValue.toStringAsFixed(0)}'
                                : 'No MOV',
                            bg: group.meetsMOV ? _teal50 : _redSoft,
                            fg: group.meetsMOV ? _teal600 : _red,
                          ),
                          metaInfoChip(
                            icon: beforeCutoff
                                ? Icons.timer_outlined
                                : Icons.local_shipping_outlined,
                            text: group.expectedDelivery.trim().isEmpty
                                ? 'Delivery info unavailable'
                                : (beforeCutoff ? 'Same day' : 'Tomorrow'),
                            bg: _amberSoft,
                            fg: _amber,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (group.sameDayCutoff.trim().isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                beforeCutoff && left != null
                    ? 'Order within ${formatDuration(left)} for same day delivery.'
                    : 'Today’s cutoff was ${group.sameDayCutoff}. New orders will be delivered tomorrow.',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: _inkSoft,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...group.items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return _buildItemRow(item, isLast: idx == group.items.length - 1);
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Distributor subtotal',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: group.meetsMOV ? _green : _red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '₹${group.subtotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: group.meetsMOV ? _teal600 : _red,
                  ),
                ),
              ],
            ),
          ),
          if (!group.meetsMOV && group.minimumOrderValue > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _redSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Add ₹${group.shortfall.toStringAsFixed(2)} more to place this order.',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: _red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemRow(PharmaCartItem item, {bool isLast = false}) {
    final qty = item.quantity;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: _line, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.medication_outlined,
              size: 18,
              color: _inkSoft,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.skuName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    height: 1.3,
                  ),
                ),
                if ((item.genericName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.genericName!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: _inkSoft,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${item.pricePerUnit.toStringAsFixed(2)} / ${item.unit}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: _pageBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _stepBtn(
                            icon: Icons.remove_rounded,
                            onTap: qty <= 1
                                ? null
                                : () {
                                    widget.cart.updateQuantity(
                                      item.variantId,
                                      item.unit,
                                      qty - 1,
                                    );
                                    setState(() {});
                                  },
                          ),
                          SizedBox(
                            width: 42,
                            height: 32,
                            child: Center(
                              child: Text(
                                '$qty',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _headingColor,
                                ),
                              ),
                            ),
                          ),
                          _stepBtn(
                            icon: Icons.add_rounded,
                            color: _blue,
                            onTap: () {
                              widget.cart.updateQuantity(
                                item.variantId,
                                item.unit,
                                qty + 1,
                              );
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '× ₹${item.pricePerUnit.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 10.8,
                        color: _mutedColor,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        widget.cart.removeItem(item.variantId, item.unit);
                        setState(() {});
                      },
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _redSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 17,
                          color: _red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '₹${item.totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _teal600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBtn({
    required IconData icon,
    Color color = _mutedColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 32,
        alignment: Alignment.center,
        child: Icon(icon, size: 17, color: onTap == null ? _faintColor : color),
      ),
    );
  }

  Widget _buildNotesCard() => _surfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 15, 16, 8),
          child: Text(
            'Notes (optional)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
          child: Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line, width: 1.4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120A2451),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _notesCtrl,
              maxLines: 3,
              style: const TextStyle(
                fontSize: 14,
                color: _ink,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                hintText: 'Add special instructions or notes for these orders…',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  color: _inkFaint,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildSummaryCard(List<DistributorOrderGroup> groups) => _surfaceCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        _summaryRow(
          'Orders (${groups.length})',
          '₹${widget.cart.subtotal.toStringAsFixed(2)}',
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1, color: _line),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Amount',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            Text(
              '₹${widget.cart.subtotal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _teal600,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: _inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _redSoft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFF7B3B3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: _red, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _errorMsg!,
            style: const TextStyle(
              fontSize: 12.5,
              color: _red,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildBottomBar(List<DistributorOrderGroup> groups) {
    final disablePlaceOrder =
        _isPlacingOrder || _isSavingDraft || !_allMeetMOV || _loadingGroupMeta;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
      decoration: const BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _line, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x140A2451),
            blurRadius: 18,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: disablePlaceOrder
                      ? [_inkSoft.withOpacity(0.55), _inkSoft.withOpacity(0.40)]
                      : [_teal500, _teal600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: FilledButton.icon(
                onPressed: disablePlaceOrder ? null : _placeOrder,
                icon: _isPlacingOrder
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                label: Text(
                  !_allMeetMOV ? 'MOV not met' : 'Place Orders',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _surfaceCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120A2451),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _leadingIconBox({
    required IconData icon,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: fg, size: 20),
    );
  }
}

Widget metaInfoChip({
  required IconData icon,
  required String text,
  required Color bg,
  required Color fg,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ],
    ),
  );
}
