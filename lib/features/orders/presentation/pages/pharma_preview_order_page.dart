// lib/features/orders/presentation/pages/pharma_preview_order_page.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wetaran_pharma/features/distributors/presentation/pages/distributors_page.dart';
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

const ink = Color(0xFF10233F);
const inkSoft = Color(0xFF5B6B85);
const teal50 = Color(0xFFE9FBF8);
const teal600 = Color(0xFF0D9488);
const Color teal500 = Color(0xFF14B8A6);

class PharmaPreviewOrderPage extends StatefulWidget {
  final PharmaCartProvider cart;

  const PharmaPreviewOrderPage({super.key, required this.cart});

  @override
  State<PharmaPreviewOrderPage> createState() => _PharmaPreviewOrderPageState();
}

class _PharmaPreviewOrderPageState extends State<PharmaPreviewOrderPage> {
  final _db = Supabase.instance.client;
  final _notesCtrl = TextEditingController();

  bool _isPlacingOrder = false;
  bool _isSavingDraft = false;
  String? _errorMsg;

  String _previewOrderId = '';
  String? _pharmaUserId;

  String? _customerName;
  String? _billingAddress;
  String? _phoneNumber;
  String? _userName;
  String? _businessState;
  String? _businessCity;
  String? _businessPincode;
  String? _placedDistributorId;
  String? _placedDistributorName;
  String? _placedOrderId;

  double distributorMinimumOrderValue = 0;

  String distributorExpectedDelivery = '';
  String distributorSameDayCutoff = '';
  bool distributorMetaLoading = false;

  String get normalizedExpectedDelivery =>
      distributorExpectedDelivery.trim().toLowerCase();

  bool get isSameDayDelivery => normalizedExpectedDelivery == 'same_day';

  bool get isNextDayDelivery => normalizedExpectedDelivery == 'next_day';

  Timer? deliveryTimer;

  @override
  void initState() {
    super.initState();
    _loadPreviewId();
    _loadPharmaUserProfile();
    _loadDistributorMeta();
    deliveryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && showDeliveryTimerCard) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    deliveryTimer?.cancel();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDistributorMeta() async {
    final distributorId = widget.cart.lockedDistributorId;
    if (distributorId == null || distributorId.isEmpty) return;

    if (mounted) {
      setState(() => distributorMetaLoading = true);
    }

    try {
      final row = await _db
          .from('distributor')
          .select(
            'pharma_minimum_order_value, pharma_expected_delivery, pharma_same_day_order_cutoff',
          )
          .eq('id', distributorId)
          .maybeSingle();

      if (!mounted || row == null) return;

      final expected = (row['pharma_expected_delivery'] ?? '')
          .toString()
          .trim();
      final cutoff = (row['pharma_same_day_order_cutoff'] ?? '')
          .toString()
          .trim();
      final minValue =
          (row['pharma_minimum_order_value'] as num?)?.toDouble() ?? 0.0;

      setState(() {
        distributorMinimumOrderValue = minValue;
        distributorExpectedDelivery = expected;
        distributorSameDayCutoff = cutoff;
        distributorMetaLoading = false;
      });

      debugPrint('row expected => $expected');
      debugPrint('row cutoff => $cutoff');
    } catch (e) {
      if (!mounted) return;
      setState(() => distributorMetaLoading = false);
      debugPrint('loadDistributorMeta error => $e');
    }
  }

  Future<void> _loadPreviewId() async {
    final distributorId = widget.cart.lockedDistributorId;

    if (distributorId == null || distributorId.isEmpty) {
      if (!mounted) return;
      setState(() => _previewOrderId = '0001');
      return;
    }

    await PharmaOrderIdService.setActiveDistributor(distributorId);

    if (!mounted) return;
    setState(() {
      _previewOrderId = PharmaOrderIdService.previewNextOrderId;
    });
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

  /*
  Future<void> _saveDraft() async {
    if (_isSavingDraft || _isPlacingOrder) return;

    setState(() {
      _isSavingDraft = true;
      _errorMsg = null;
    });

    try {
      final distributorId = widget.cart.lockedDistributorId;
      if (distributorId == null) throw Exception('No distributor selected');

      final products = widget.cart.items
          .map((i) => i.toOrderProduct())
          .toList();
      final totalAmount = widget.cart.subtotal;

      await _db.from('orders').insert({
        'distributor_id': distributorId,
        'retailer_id': _pharmaUserId,
        'total_amount': totalAmount,
        'order_price': products
            .map((p) => '${p['name']}: ${p['quantity']} × ₹${p['sell_price']}')
            .join(', '),
        'products': products,
        'notes': _notesCtrl.text.trim(),
        'status': 'draft',
        'status_updated_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved successfully'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = 'Failed to save draft: $e');
    } finally {
      if (mounted) setState(() => _isSavingDraft = false);
    }
  }
  */

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
    if (match == null) {
      debugPrint('parseCutoff FAILED for input: "$input"');
      return null;
    }

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2) ?? '0');
    final period = match.group(3)!;

    if (hour < 1 || hour > 12 || minute < 0 || minute > 59) return null;

    if (hour == 12) hour = 0;
    if (period == 'PM') hour += 12;

    return TimeOfDay(hour: hour, minute: minute);
  }

  int get nowIstMinutes {
    final nowUtc = DateTime.now().toUtc();
    final nowIst = nowUtc.add(const Duration(hours: 5, minutes: 30));
    return nowIst.hour * 60 + nowIst.minute;
  }

  bool get isBeforeSameDayCutoff {
    if (!isSameDayDelivery) return false;

    final cutoff = parseCutoff(distributorSameDayCutoff);
    if (cutoff == null) return false;

    final cutoffMinutes = cutoff.hour * 60 + cutoff.minute;
    return nowIstMinutes <= cutoffMinutes;
  }

  String get deliveryHeadline {
    if (isSameDayDelivery) {
      return isBeforeSameDayCutoff ? 'Same day delivery' : 'Tomorrow delivery';
    }

    if (isNextDayDelivery) {
      return 'Tomorrow delivery';
    }

    return '';
  }

  String get deliverySubtext {
    if (!isSameDayDelivery) return '';
    if (distributorSameDayCutoff.trim().isEmpty) return '';

    return isBeforeSameDayCutoff
        ? 'Order before $distributorSameDayCutoff'
        : 'Today cutoff was $distributorSameDayCutoff. New orders will be delivered tomorrow.';
  }

  Duration? get timeLeftToCutoff {
    if (!isSameDayDelivery) return null;

    final cutoff = parseCutoff(distributorSameDayCutoff);
    if (cutoff == null) return null;

    final cutoffMinutes = cutoff.hour * 60 + cutoff.minute;
    final diffMinutes = cutoffMinutes - nowIstMinutes;

    if (diffMinutes <= 0) return Duration.zero;

    final nowUtc = DateTime.now().toUtc();
    final nowIst = nowUtc.add(const Duration(hours: 5, minutes: 30));
    final secondsIntoCurrentMinute = nowIst.second;

    final totalSeconds = (diffMinutes * 60) - secondsIntoCurrentMinute;
    return Duration(seconds: totalSeconds < 0 ? 0 : totalSeconds);
  }

  bool get showDeliveryTimerCard =>
      isSameDayDelivery && distributorSameDayCutoff.trim().isNotEmpty;

  bool get meetsMinimumOrderValue {
    return widget.cart.subtotal >= distributorMinimumOrderValue;
  }

  double get minimumOrderShortfall {
    final diff = distributorMinimumOrderValue - widget.cart.subtotal;
    return diff > 0 ? diff : 0;
  }

  Future<void> _placeOrder() async {
    if (!meetsMinimumOrderValue) {
      throw Exception(
        'Minimum order value for this distributor is ₹${distributorMinimumOrderValue.toStringAsFixed(2)}. '
        'Add ₹${minimumOrderShortfall.toStringAsFixed(2)} more to place the order.',
      );
    }
    if (_isPlacingOrder || _isSavingDraft) return;

    setState(() {
      _isPlacingOrder = true;
      _errorMsg = null;
    });

    try {
      final distributorId = widget.cart.lockedDistributorId;
      final distributorName = widget.cart.lockedDistributorName;

      if (distributorId == null) throw Exception('No distributor selected');
      if (_pharmaUserId == null) throw Exception('User profile not loaded');

      await PharmaOrderIdService.setActiveDistributor(distributorId);
      final orderId = await PharmaOrderIdService.reserveNextOrderId();

      final products = widget.cart.items
          .map((i) => i.toOrderProduct())
          .toList();
      final totalAmount = widget.cart.subtotal;

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

      if (!mounted) return;

      setState(() {
        _placedDistributorId = distributorId;
        _placedDistributorName = distributorName;
        _placedOrderId = savedOrderId;
        _previewOrderId = savedOrderId;
      });

      widget.cart.clear();
      _notesCtrl.clear();

      _showSuccessDialog(savedOrderId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = 'Failed to place order: $e');
    } finally {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
      }
    }
  }

  void _showSuccessDialog(String orderId) {
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
                'Order Placed!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your order $orderId has been placed successfully.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: _inkSoft,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: _teal50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFC7EFE9)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      size: 17,
                      color: _teal600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Order ID: $orderId',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _teal600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [_teal500, _teal600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _teal500.withOpacity(0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
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
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget buildDeliveryTimerCard() {
    final beforeCutoff = isBeforeSameDayCutoff;
    final left = timeLeftToCutoff;
    debugPrint(
      'beforeCutoff=$beforeCutoff left=$left cutoff="$distributorSameDayCutoff" '
      'nowIstMinutes=$nowIstMinutes',
    );
    return _surfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _leadingIconBox(
            icon: beforeCutoff
                ? Icons.timer_outlined
                : Icons.local_shipping_outlined,
            bg: teal50,
            fg: teal600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  beforeCutoff
                      ? 'Same day delivery available'
                      : 'Tomorrow delivery',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  beforeCutoff && left != null
                      ? 'Order within ${formatDuration(left)} to get same day delivery.'
                      : 'Today’s cutoff was $distributorSameDayCutoff. New orders will be delivered tomorrow.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: inkSoft,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;

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
                  _buildOrderIdCard(),
                  const SizedBox(height: 14),
                  _buildDistributorCard(cart),
                  if (showDeliveryTimerCard) ...[
                    const SizedBox(height: 12),
                    buildDeliveryTimerCard(),
                  ],
                  const SizedBox(height: 14),
                  _buildItemsCard(cart),
                  const SizedBox(height: 14),
                  _buildNotesCard(),
                  const SizedBox(height: 14),
                  _buildSummaryCard(cart),
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
      bottomNavigationBar: _buildBottomBar(cart),
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

  Widget _buildOrderIdCard() => _surfaceCard(
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
                'ORDER ID',
                style: TextStyle(
                  fontSize: 11,
                  color: _inkSoft,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                (_placedOrderId ?? _previewOrderId).isNotEmpty
                    ? (_placedOrderId ?? _previewOrderId)
                    : 'Loading...',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
        /*
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _teal50,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'Preview',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _teal600,
            ),
          ),
        ),
        */
      ],
    ),
  );
  Widget _buildDistributorCard(PharmaCartProvider cart) => _surfaceCard(
    padding: const EdgeInsets.all(16),
    child: Row(
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
              const Text(
                'DISTRIBUTOR',
                style: TextStyle(
                  fontSize: 11,
                  color: inkSoft,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _placedDistributorName ??
                    cart.lockedDistributorName ??
                    'Unknown distributor',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  metaInfoChip(
                    icon: Icons.currency_rupee_rounded,
                    text: distributorMinimumOrderValue > 0
                        ? 'Min order ₹${distributorMinimumOrderValue.toStringAsFixed(0)}'
                        : 'No minimum order',
                    bg: meetsMinimumOrderValue ? teal50 : redSoft,
                    fg: meetsMinimumOrderValue ? teal600 : red,
                  ),
                ],
              ),
              if (!meetsMinimumOrderValue &&
                  distributorMinimumOrderValue > 0) ...[
                const SizedBox(height: 10),
                Text(
                  'Add ₹${minimumOrderShortfall.toStringAsFixed(2)} more to place this order.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildItemsCard(PharmaCartProvider cart) => _surfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              const Text(
                'Order Items',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _teal50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _teal600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: _line),
        ...cart.items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return _buildItemRow(item, isLast: idx == cart.items.length - 1);
        }),
      ],
    ),
  );

  Widget _buildItemRow(PharmaCartItem item, {bool isLast = false}) {
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
                if (item.genericName != null &&
                    item.genericName!.isNotEmpty) ...[
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
                  '${item.quantity} × ₹${item.pricePerUnit.toStringAsFixed(2)} / ${item.unit}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
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
                hintText: 'Add special instructions or notes for this order…',
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

  Widget _buildSummaryCard(PharmaCartProvider cart) => _surfaceCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        _summaryRow(
          'Subtotal (${cart.itemCount} items)',
          '₹${cart.subtotal.toStringAsFixed(2)}',
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
              '₹${cart.subtotal.toStringAsFixed(2)}',
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

  Widget _buildBottomBar(PharmaCartProvider cart) {
    final disablePlaceOrder =
        _isPlacingOrder || _isSavingDraft || !meetsMinimumOrderValue;
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
          /*
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isSavingDraft || _isPlacingOrder ? null : _saveDraft,
              icon: _isSavingDraft
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _teal600,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 17, color: _teal600),
              label: const Text(
                'Draft',
                style: TextStyle(
                  color: _teal600,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                side: const BorderSide(color: _teal500, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          */
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: disablePlaceOrder
                      ? [inkSoft.withOpacity(0.55), inkSoft.withOpacity(0.40)]
                      : [teal500, teal600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: disablePlaceOrder
                    ? []
                    : [
                        BoxShadow(
                          color: teal500.withOpacity(0.22),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
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
                    : Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: disablePlaceOrder
                            ? Colors.white.withOpacity(0.92)
                            : Colors.white,
                      ),
                label: Text(
                  !meetsMinimumOrderValue && distributorMinimumOrderValue > 0
                      ? 'Min order value not met'
                      : 'Place Order',
                  style: TextStyle(
                    color: disablePlaceOrder
                        ? Colors.white.withOpacity(0.92)
                        : Colors.white,
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
