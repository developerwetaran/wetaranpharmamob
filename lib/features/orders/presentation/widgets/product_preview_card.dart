// ignore_for_file: use_super_parameters, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wetaran_pharma/models/sku_model.dart';
import 'package:wetaran_pharma/features/orders/models/pharma_cart_provider.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _faint = Color(0xFF94A3B8);
const _blue = Color(0xFF003CBE);
const _blueSoft = Color(0xFFE4EDF7);
const _teal = Color(0xFF0FA3A3);
const _tealSoft = Color(0xFFE1F5F5);
const _amber = Color(0xFFB36A00);
const _amberSoft = Color(0xFFFFF4E0);
const _red = Color(0xFFB3261E);
const _redSoft = Color(0xFFFCE8E6);
const _border = Color(0xFFE2E8F0);
const _cardBg = Color(0xFFF8FAFC);

const TextStyle _base = TextStyle(
  decoration: TextDecoration.none,
  decorationColor: Colors.transparent,
  decorationThickness: 0,
  fontFamily: null,
);

TextStyle _t({
  double fontSize = 12,
  FontWeight fontWeight = FontWeight.normal,
  Color color = _ink,
  double height = 1.4,
  double? letterSpacing,
}) {
  return _base.copyWith(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

class ProductPreviewCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback onClose;
  final PharmaCartProvider cart;
  final String distributorId;
  final String distributorName;
  final void Function(SkuVariant variant, String unit, int qtyDelta)
  onAddToCart;
  final VoidCallback? onCompareDistributors;

  const ProductPreviewCard({
    super.key,
    required this.product,
    required this.onClose,
    required this.cart,
    required this.distributorId,
    required this.distributorName,
    required this.onAddToCart,
    this.onCompareDistributors,
  });

  @override
  State<ProductPreviewCard> createState() => _ProductPreviewCardState();
}

class _ProductPreviewCardState extends State<ProductPreviewCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  String? _selectedUnit;
  SkuVariant? _selectedVariant;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scaleAnim = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);

    final variants = widget.product['variants'] as List<SkuVariant>? ?? [];
    _selectedVariant = variants.isNotEmpty ? variants.first : null;
    _selectedUnit = widget.product['primary_unit'] as String? ?? 'pcs';
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _animCtrl.reverse();
    widget.onClose();
  }

  bool get _altUnitsAllowed {
    if (_selectedVariant != null)
      return _selectedVariant!.allowSellingInAlternativeUnit;
    return widget.product['allow_selling_in_alternative_unit'] as bool? ?? true;
  }

  double _resolveFactor(Map<String, dynamic> alt) {
    return ((alt['factor'] ?? alt['conversion_factor'] ?? 1) as num).toDouble();
  }

  double get _currentStock {
    if (_selectedVariant != null) {
      return _selectedVariant!.stockInUnit(
        _selectedUnit ?? _selectedVariant!.primaryUnit,
      );
    }
    final rawStock = (widget.product['current_stock'] as num? ?? 0).toDouble();
    final primaryUnit = widget.product['primary_unit'] as String? ?? 'pcs';
    if (_selectedUnit == null || _selectedUnit == primaryUnit) return rawStock;

    final altUnits =
        widget.product['alternative_units'] as List<dynamic>? ?? [];
    final alt = altUnits
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .firstWhere(
          (u) =>
              (u['unit']?.toString().toLowerCase() ?? '') ==
              (_selectedUnit ?? '').toLowerCase(),
          orElse: () => {'factor': 1},
        );

    final explicitStock = (alt['stock'] as num?)?.toDouble();
    if (explicitStock != null) return explicitStock;

    final factor = _resolveFactor(alt);
    return factor > 0 ? rawStock * factor : rawStock;
  }

  double get _currentPrice {
    if (_selectedVariant != null) {
      return _selectedVariant!.pricePerUnit(
        _selectedUnit ?? _selectedVariant!.primaryUnit,
      );
    }
    final basePrice = (widget.product['base_price'] as num? ?? 0).toDouble();
    final primaryUnit = widget.product['primary_unit'] as String? ?? 'pcs';
    if (_selectedUnit == null || _selectedUnit == primaryUnit) return basePrice;

    final altUnits =
        widget.product['alternative_units'] as List<dynamic>? ?? [];
    final alt = altUnits
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .firstWhere(
          (u) =>
              (u['unit']?.toString().toLowerCase() ?? '') ==
              (_selectedUnit ?? '').toLowerCase(),
          orElse: () => {'factor': 1},
        );

    final factor = _resolveFactor(alt);
    return factor > 0 ? basePrice / factor : basePrice;
  }

  void _onUnitChanged(String? val) {
    if (val == null) return;
    setState(() => _selectedUnit = val);
  }

  void _onVariantTap(SkuVariant v) {
    setState(() {
      _selectedVariant = v;
      final unitValid =
          _selectedUnit == v.primaryUnit ||
          v.alternativeUnits.any((u) => u.unit == _selectedUnit);
      if (!unitValid) _selectedUnit = v.primaryUnit;
    });
  }

  int get _qtyInCartForSelection {
    if (_selectedVariant == null) return 0;
    return widget.cart.qtyForVariant(
      _selectedVariant!.id,
      _selectedUnit ?? _selectedVariant!.primaryUnit,
    );
  }

  bool get _isInCartForSelection {
    if (_selectedVariant == null) return false;
    return widget.cart.isVariantInCart(
      _selectedVariant!.id,
      _selectedUnit ?? _selectedVariant!.primaryUnit,
    );
  }

  bool get _isLockedElsewhere {
    final cart = widget.cart;
    if (cart.isEmpty) return false;
    final activeDistributorId = cart.items.first.distributorId;
    return activeDistributorId.isNotEmpty &&
        activeDistributorId != widget.distributorId;
  }

  String _s(
    Map<String, dynamic>? info,
    String key, [
    String fallback = 'Not available',
  ]) {
    if (info == null) return fallback;
    final v = info[key];
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  bool? _b(Map<String, dynamic>? info, String key) {
    if (info == null) return null;
    final v = info[key];
    if (v == null) return null;
    if (v is bool) return v;
    final s = v.toString().toLowerCase();
    if (s == 'true' || s == 'yes') return true;
    if (s == 'false' || s == 'no') return false;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final name = p['name'] as String? ?? 'Unnamed Product';
    final imageUrl = p['image_path'] as String? ?? '';
    final skuCode = p['sku_code'] as String? ?? '';
    final category = p['category'] as String? ?? '';
    final primaryUnit = p['primary_unit'] as String? ?? 'pcs';
    final hsnCode = p['hsn_code'] as String? ?? '';
    final double taxSlab = (p['tax_slab'] as num?)?.toDouble() ?? 0.0;
    final List<SkuVariant> variants = p['variants'] as List<SkuVariant>? ?? [];
    final altUnits = p['alternative_units'] as List<dynamic>? ?? [];
    final Map<String, dynamic>? info = p['info'] is Map
        ? Map<String, dynamic>.from(p['info'] as Map)
        : null;

    final List<String> units = [
      primaryUnit,
      if (_altUnitsAllowed)
        ...altUnits
            .map((u) => Map<String, dynamic>.from(u as Map))
            .map((u) => (u['unit'] ?? '').toString())
            .where(
              (u) =>
                  u.isNotEmpty && u.toLowerCase() != primaryUnit.toLowerCase(),
            ),
    ];

    final double priceNoTax = taxSlab > 0
        ? _currentPrice / (1 + taxSlab / 100)
        : _currentPrice;
    final double priceWithTax = _currentPrice;
    final double mrp = (widget.product['base_price'] as num? ?? 0) > 0
        ? (_selectedVariant?.maxRetailPrice ??
              (p['base_price'] as num? ?? 0).toDouble())
        : 0;
    final double stock = _currentStock;
    final outOfStock = stock <= 0;
    final allowBeyond = _selectedVariant?.allowOrderBeyondStock ?? false;

    final margin = mrp > 0 ? ((mrp - priceWithTax) / mrp * 100) : 0.0;

    final rxRequired = _b(info, 'prescription_required');
    final antibiotic = _b(info, 'antibiotic');
    final controlled = _b(info, 'controlled_drug');
    final narcotic = _b(info, 'narcotic_restricted');

    return GestureDetector(
      onTap: _close,
      child: Container(
        color: Colors.black.withOpacity(0.45),
        child: SafeArea(
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: 560,
                      maxHeight: MediaQuery.of(context).size.height * 0.92,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 32,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCloseBar(),
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildHeaderCard(
                                    name,
                                    skuCode,
                                    category,
                                    units,
                                    priceWithTax,
                                    priceNoTax,
                                    mrp,
                                    margin,
                                    info,
                                    rxRequired,
                                    antibiotic,
                                    controlled,
                                    narcotic,
                                    outOfStock,
                                    allowBeyond,
                                    hsnCode,
                                    taxSlab,
                                    stock,
                                    primaryUnit,
                                  ),
                                  const SizedBox(height: 14),
                                  if (variants.isNotEmpty) ...[
                                    _sectionHeader('Available Variants'),
                                    const SizedBox(height: 8),
                                    _buildVariantsTable(variants),
                                    const SizedBox(height: 14),
                                  ],
                                  _buildGrid2(
                                    _overviewCard(info),
                                    _compositionCard(info, p),
                                  ),
                                  const SizedBox(height: 14),
                                  _buildGrid2(
                                    _regulatoryCard(
                                      rxRequired,
                                      antibiotic,
                                      controlled,
                                      narcotic,
                                      info,
                                    ),
                                    _pricingCard(
                                      mrp,
                                      priceWithTax,
                                      margin,
                                      info,
                                      hsnCode,
                                      taxSlab,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _buildGrid2(
                                    _packagingCard(info, p, primaryUnit),
                                    _manufacturerCard(info),
                                  ),
                                  const SizedBox(height: 14),
                                  _safetyCard(info),
                                  if (altUnits.isNotEmpty &&
                                      _altUnitsAllowed) ...[
                                    const SizedBox(height: 14),
                                    _sectionHeader('Unit Price Breakdown'),
                                    const SizedBox(height: 8),
                                    _buildBreakdown(primaryUnit, altUnits),
                                  ],
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          ),
                          _buildActionFooter(outOfStock, allowBeyond),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Product Profile',
              style: _t(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _muted,
                letterSpacing: 0.4,
              ),
            ),
          ),
          GestureDetector(
            onTap: _close,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _cardBg,
                shape: BoxShape.circle,
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.close, color: _muted, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Text(
      text.toUpperCase(),
      style: _t(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: _faint,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildGrid2(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        if (isNarrow) {
          return Column(children: [a, const SizedBox(height: 14), b]);
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: a),
              const SizedBox(width: 14),
              Expanded(child: b),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionCard({
    required String title,
    required List<Widget> children,
    Color? accentColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
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
          Text(
            title,
            style: _t(fontSize: 13, fontWeight: FontWeight.w800, color: _ink),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _kv(String label, String value, {Widget? valueWidget}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _t(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child:
                valueWidget ??
                Text(value, style: _t(fontSize: 12, color: _ink, height: 1.35)),
          ),
        ],
      ),
    );
  }

  Widget _pchip(String text, {Color bg = _cardBg, Color fg = _ink}) {
    return Container(
      margin: const EdgeInsets.only(right: 6, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: _t(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _ynChip(bool? value, {bool redIfYes = false}) {
    if (value == null)
      return Text('Not available', style: _t(fontSize: 12, color: _faint));
    final isYes = value;
    final color = isYes && redIfYes
        ? _red
        : (isYes ? _amber : Colors.green.shade700);
    final bg = isYes && redIfYes
        ? _redSoft
        : (isYes ? _amberSoft : const Color(0xFFE4F5EC));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isYes ? 'Yes' : 'No',
        style: _t(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _flagChip(String? value) {
    if (value == null || value.trim().isEmpty) {
      return Text('Not available', style: _t(fontSize: 12, color: _faint));
    }
    final v = value.toLowerCase();
    Color fg = _muted;
    Color bg = _cardBg;
    if (v.contains('unsafe') || v.contains('avoid')) {
      fg = _red;
      bg = _redSoft;
    } else if (v.contains('caution') || v.contains('consult')) {
      fg = _amber;
      bg = _amberSoft;
    } else if (v.contains('safe')) {
      fg = Colors.green.shade700;
      bg = const Color(0xFFE4F5EC);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        value,
        style: _t(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _buildHeaderCard(
    String name,
    String skuCode,
    String category,
    List<String> units,
    double priceWithTax,
    double priceNoTax,
    double mrp,
    double margin,
    Map<String, dynamic>? info,
    bool? rx,
    bool? antibiotic,
    bool? controlled,
    bool? narcotic,
    bool outOfStock,
    bool allowBeyond,
    String hsnCode,
    double taxSlab,
    double stock,
    String primaryUnit,
  ) {
    final marketer = _s(info, 'marketer_name');
    final composition = _s(info, 'composition');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: _t(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: _ink,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            composition == 'Not available'
                ? (skuCode.isEmpty ? 'Not available' : skuCode)
                : composition,
            style: _t(fontSize: 12.5, color: _muted),
          ),
          if (marketer != 'Not available') ...[
            const SizedBox(height: 2),
            Text(
              marketer,
              style: _t(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _teal,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            children: [
              if (category.isNotEmpty)
                _pchip(category, bg: _blueSoft, fg: _blue),
              _pchip(_s(info, 'dosage_form'), bg: _cardBg, fg: _muted),
              _pchip(
                _s(info, 'route_of_administration'),
                bg: _cardBg,
                fg: _muted,
              ),
              _pchip(_s(info, 'medicine_type'), bg: _cardBg, fg: _muted),
              rx == true
                  ? _pchip(
                      'Rx - Prescription required',
                      bg: _amberSoft,
                      fg: _amber,
                    )
                  : _pchip('OTC - No prescription', bg: _tealSoft, fg: _teal),
              if (antibiotic == true)
                _pchip('Antibiotic', bg: _amberSoft, fg: _amber),
              if (controlled == true)
                _pchip('Controlled drug', bg: _redSoft, fg: _red),
              if (narcotic == true)
                _pchip('Narcotic - restricted', bg: _redSoft, fg: _red),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: _border),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELLING PRICE',
                      style: _t(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _faint,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '₹${priceWithTax.toStringAsFixed(2)}',
                      style: _t(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _blue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${priceNoTax.toStringAsFixed(2)} excl. tax',
                      style: _t(fontSize: 11, color: _muted),
                    ),
                    if (mrp > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'MRP ₹${mrp.toStringAsFixed(2)} · margin ${margin.toStringAsFixed(1)}%',
                        style: _t(fontSize: 11, color: _muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (units.length > 1)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'UNIT',
                      style: _t(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _faint,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF003CBE), Color(0xFF2E5FF6)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedUnit,
                          isDense: true,
                          dropdownColor: const Color(0xFF003CBE),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          style: _t(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          items: units
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(
                                    u.toUpperCase(),
                                    style: _t(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _onUnitChanged,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statChip(
                label: 'STOCK',
                value: '${stock.toInt()} ${_selectedUnit ?? primaryUnit}',
                color: stock > 0 ? Colors.green.shade700 : _red,
              ),
              if (hsnCode.isNotEmpty)
                _statChip(label: 'HSN', value: hsnCode, color: _muted),
              _statChip(
                label: 'TAX',
                value: '${taxSlab.toStringAsFixed(0)}%',
                color: _muted,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: _t(
              fontSize: 8,
              color: _muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            value,
            style: _t(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color == _muted ? _ink : color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewCard(Map<String, dynamic>? info) {
    return _sectionCard(
      title: 'Overview',
      children: [
        Text(
          _s(info, 'product_description'),
          style: _t(fontSize: 12.5, color: _muted, height: 1.6),
        ),
        const SizedBox(height: 10),
        _kv('Therapeutic class', _s(info, 'therapeutic_class')),
        _kv('Clinical intent', _s(info, 'therapeutic_use_indication')),
      ],
    );
  }

  Widget _compositionCard(Map<String, dynamic>? info, Map<String, dynamic> p) {
    final ingredients = info?['ingredients'] as List<dynamic>? ?? [];
    return _sectionCard(
      title: 'Composition & Administration',
      children: [
        if (ingredients.isNotEmpty)
          ...ingredients.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            final ingName = (m['ingredientName'] ?? '').toString();
            final val = (m['strengthValue'] ?? '').toString();
            final unit = (m['strengthUnit'] ?? '').toString();
            return _kv(
              ingName.isEmpty ? 'Ingredient' : ingName,
              '$val $unit'.trim(),
            );
          })
        else
          _kv('Composition', _s(info, 'composition_display')),
        _kv('Dosage form', _s(info, 'dosage_form')),
        _kv('Route of administration', _s(info, 'route_of_administration')),
      ],
    );
  }

  Widget _regulatoryCard(
    bool? rx,
    bool? antibiotic,
    bool? controlled,
    bool? narcotic,
    Map<String, dynamic>? info,
  ) {
    return _sectionCard(
      title: 'Regulatory Status',
      children: [
        _kv('Medicine type', _s(info, 'medicine_type')),
        _kv('Prescription required', '', valueWidget: _ynChip(rx)),
        _kv(
          'Controlled drug',
          '',
          valueWidget: _ynChip(controlled, redIfYes: true),
        ),
        _kv('Antibiotic', '', valueWidget: _ynChip(antibiotic)),
        _kv(
          'Narcotic / restricted',
          '',
          valueWidget: _ynChip(narcotic, redIfYes: true),
        ),
      ],
    );
  }

  Widget _pricingCard(
    double mrp,
    double sellPrice,
    double margin,
    Map<String, dynamic>? info,
    String hsnCode,
    double taxSlab,
  ) {
    final discount = mrp > 0 && mrp > sellPrice
        ? '${((mrp - sellPrice) / mrp * 100).toStringAsFixed(0)}% off'
        : 'No discount';
    return _sectionCard(
      title: 'Pricing',
      children: [
        _kv('MRP', mrp > 0 ? '₹${mrp.toStringAsFixed(2)}' : 'Not available'),
        _kv(
          'Selling price',
          '',
          valueWidget: Row(
            children: [
              Text(
                '₹${sellPrice.toStringAsFixed(2)}',
                style: _t(fontSize: 12, color: _ink),
              ),
              const SizedBox(width: 6),
              _pchip(discount, bg: _tealSoft, fg: _teal),
            ],
          ),
        ),
        _kv(
          'Price per unit',
          _s(info, 'price_per_unit', '₹${sellPrice.toStringAsFixed(2)}'),
        ),
        _kv(
          'PTR - price to retailer',
          _s(
            info,
            'ptr',
            mrp > 0 ? '₹${sellPrice.toStringAsFixed(2)}' : 'Not available',
          ),
        ),
        _kv('PTS - price to stockist (est.)', _s(info, 'pts')),
        _kv(
          'Your margin at MRP',
          mrp > 0 ? '${margin.toStringAsFixed(1)}%' : 'Not available',
        ),
        _kv(
          'GST',
          taxSlab > 0 ? '${taxSlab.toStringAsFixed(0)}%' : _s(info, 'gst'),
        ),
      ],
    );
  }

  Widget _packagingCard(
    Map<String, dynamic>? info,
    Map<String, dynamic> p,
    String primaryUnit,
  ) {
    return _sectionCard(
      title: 'Packaging & Logistics',
      children: [
        _kv('Standard pack', _s(info, 'pack_label')),
        _kv('Pack type', _s(info, 'pack_type')),
        _kv('Units per pack', _s(info, 'units_per_pack')),
        _kv('Unit name', _s(info, 'unit_name', primaryUnit)),
        _kv('Minimum order qty', _s(info, 'minimum_order_qty')),
        _kv(
          'Storage condition',
          _s(info, 'storage_condition', 'Store as per label'),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            style: _t(fontSize: 12, color: _muted, height: 1.6),
            children: [
              TextSpan(
                text: 'Special handling: ',
                style: _t(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              TextSpan(text: _s(info, 'special_handling_instructions')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _manufacturerCard(Map<String, dynamic>? info) {
    final leaflet = _s(info, 'product_leaflet_url', '');
    final regDoc = _s(info, 'regulatory_document_url', '');
    final notes = _s(info, 'additional_notes', '');

    return _sectionCard(
      title: 'Manufacturer & Marketer',
      children: [
        _kv('Manufacturer', _s(info, 'manufacturer_name')),
        _kv('Address', _s(info, 'manufacturer_address')),
        _kv('Marketed by', _s(info, 'marketer_name')),
        _kv('Country of origin', _s(info, 'country_of_origin')),
        const SizedBox(height: 8),
        Text(
          'COMPLIANCE & LITERATURE',
          style: _t(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: _faint,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        _litLink(leaflet, 'Product leaflet'),
        _litLink(regDoc, 'Regulatory document'),
        if (notes.isNotEmpty && notes != 'Not available') ...[
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: _t(fontSize: 12, color: _muted, height: 1.6),
              children: [
                TextSpan(
                  text: 'Additional notes: ',
                  style: _t(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                TextSpan(text: notes),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _litLink(String url, String label) {
    final hasUrl = url.isNotEmpty && url != 'Not available';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: hasUrl
            ? () => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              )
            : null,
        child: Row(
          children: [
            Icon(
              Icons.description_outlined,
              size: 14,
              color: hasUrl ? _blue : _faint,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: _t(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: hasUrl ? _blue : _faint,
              ),
            ),
            if (!hasUrl) ...[
              const SizedBox(width: 6),
              Text('(Not available)', style: _t(fontSize: 11, color: _faint)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _safetyCard(Map<String, dynamic>? info) {
    final sideEffectsRaw = _s(info, 'common_side_effects', '');
    final sfxList = sideEffectsRaw == 'Not available'
        ? <String>[]
        : sideEffectsRaw
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
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
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: _amber,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Safety & Warning Advisory',
                style: _t(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'COMMON SIDE EFFECTS',
            style: _t(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: _faint,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          sfxList.isEmpty
              ? Text('Not available', style: _t(fontSize: 12, color: _faint))
              : Wrap(
                  children: sfxList
                      .map((s) => _pchip(s, bg: _cardBg, fg: _muted))
                      .toList(),
                ),
          const SizedBox(height: 14),
          Text(
            'SAFETY ADVISORIES',
            style: _t(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: _faint,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          _buildGrid2(
            Column(
              children: [
                _kv(
                  'Alcohol',
                  '',
                  valueWidget: _flagChip(_s(info, 'alcohol_safety', '')),
                ),
                _kv(
                  'Pregnancy',
                  '',
                  valueWidget: _flagChip(_s(info, 'pregnancy_safety', '')),
                ),
                _kv(
                  'Breastfeeding',
                  '',
                  valueWidget: _flagChip(_s(info, 'breastfeeding_safety', '')),
                ),
              ],
            ),
            Column(
              children: [
                _kv(
                  'Driving',
                  '',
                  valueWidget: _flagChip(_s(info, 'driving_safety', '')),
                ),
                _kv(
                  'Kidney',
                  '',
                  valueWidget: _flagChip(_s(info, 'kidney_safety', '')),
                ),
                _kv(
                  'Liver',
                  '',
                  valueWidget: _flagChip(_s(info, 'liver_safety', '')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'For pharmacist reference only. Always follow the prescriber\u2019s directions and the package insert.',
            style: _t(fontSize: 10.5, color: _faint),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantsTable(List<SkuVariant> variants) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Variant',
                    style: _t(
                      fontSize: 10,
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Price/${(_selectedUnit ?? '').toUpperCase()}',
                    textAlign: TextAlign.center,
                    style: _t(
                      fontSize: 10,
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Stock',
                    textAlign: TextAlign.right,
                    style: _t(
                      fontSize: 10,
                      color: _muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: _border),
          ...variants.map((v) {
            final isActive = _selectedVariant?.id == v.id;
            final unit = _selectedUnit ?? v.primaryUnit;
            final price = v.pricePerUnit(unit);
            final stock = v.stockInUnit(unit);

            return GestureDetector(
              onTap: () => _onVariantTap(v),
              child: Container(
                margin: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                padding: const EdgeInsets.fromLTRB(8, 9, 8, 9),
                decoration: BoxDecoration(
                  color: isActive ? _blueSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isActive
                      ? Border.all(color: _blue.withOpacity(0.4))
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isActive ? _blue : Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              v.variantName,
                              style: _t(
                                fontSize: 12,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color: isActive ? _blue : _ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '₹${price.toStringAsFixed(0)}',
                        textAlign: TextAlign.center,
                        style: _t(
                          fontSize: 12,
                          fontWeight: isActive
                              ? FontWeight.w800
                              : FontWeight.normal,
                          color: _blue,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${stock.toInt()} $unit',
                        textAlign: TextAlign.right,
                        style: _t(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: stock > 0 ? Colors.green.shade700 : _red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildBreakdown(String primaryUnit, List<dynamic> altUnits) {
    final basePrice =
        _selectedVariant?.sellPriceToRetailer ??
        (widget.product['base_price'] as num? ?? 0).toDouble();
    final rawStock =
        _selectedVariant?.availableStock ??
        (widget.product['current_stock'] as num? ?? 0).toDouble();

    final chips = <_ChipData>[
      _ChipData(
        unit: primaryUnit,
        price: basePrice,
        stock: rawStock.toInt(),
        isPrimary: _selectedUnit == primaryUnit,
      ),
      ...altUnits.map((u) {
        final map = Map<String, dynamic>.from(u as Map);
        final unitName = (map['unit'] ?? '').toString();
        final factor = _resolveFactor(map);
        final explicitStock = (map['stock'] as num?)?.toInt();
        return _ChipData(
          unit: unitName,
          subtitle: '1 $primaryUnit = ${factor.toInt()} $unitName',
          price: factor > 0 ? basePrice / factor : basePrice,
          stock:
              explicitStock ?? (factor > 0 ? (rawStock * factor).toInt() : 0),
          isPrimary: _selectedUnit == unitName,
        );
      }),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips
          .map((d) => SizedBox(width: 140, child: _buildChip(d)))
          .toList(),
    );
  }

  Widget _buildChip(_ChipData d) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: d.isPrimary ? _blueSoft : _cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: d.isPrimary ? _blue.withOpacity(0.3) : _border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            d.unit.toUpperCase(),
            style: _t(
              fontSize: 9,
              color: d.isPrimary ? _blue : _muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          if (d.subtitle != null) ...[
            const SizedBox(height: 1),
            Text(
              d.subtitle!,
              style: _t(fontSize: 9, fontWeight: FontWeight.w600, color: _ink),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '₹${d.price.toStringAsFixed(2)}',
            style: _t(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: d.isPrimary ? _blue : _ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Stock: ${d.stock}',
            style: _t(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: d.stock > 0 ? Colors.green.shade700 : _red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionFooter(bool outOfStock, bool allowBeyond) {
    final lockedElsewhere = _isLockedElsewhere;
    final inCart = _isInCartForSelection;
    final qty = _qtyInCartForSelection;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /*
          if (lockedElsewhere)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _amberSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF3D19C)),
              ),
              child: Text(
                'Cart is locked to ${widget.cart.items.isNotEmpty ? widget.cart.items.first.distributorName : 'another distributor'}. Clear cart to order from ${widget.distributorName}.',
                style: _t(
                  fontSize: 11,
                  color: const Color(0xFF9A5A00),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            */
          /*
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCompareDistributors,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _blue, width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.compare_arrows_rounded,
                        size: 15,
                        color: _blue,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Compare',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: _t(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              /*
              Expanded(
                flex: inCart ? 2 : 1,
                child: inCart
                    ? _qtyStepper(qty, outOfStock, allowBeyond)
                    : ElevatedButton(
                        onPressed:
                            (outOfStock && !allowBeyond) || lockedElsewhere
                            ? null
                            : () {
                                if (_selectedVariant == null) return;
                                widget.onAddToCart(
                                  _selectedVariant!,
                                  _selectedUnit ??
                                      _selectedVariant!.primaryUnit,
                                  1,
                                );
                                setState(() {});
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          disabledBackgroundColor: _border,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.add_shopping_cart_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Add to Cart',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: _t(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              */
            ],
          ),
          */
        ],
      ),
    );
  }
}

class _ChipData {
  final String unit;
  final String? subtitle;
  final double price;
  final int stock;
  final bool isPrimary;

  const _ChipData({
    required this.unit,
    this.subtitle,
    required this.price,
    required this.stock,
    required this.isPrimary,
  });
}
