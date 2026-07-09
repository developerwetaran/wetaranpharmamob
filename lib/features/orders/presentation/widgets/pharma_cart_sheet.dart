// lib/features/orders/presentation/widgets/pharma_cart_sheet.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wetaran_pharma/features/orders/models/pharma_cart_provider.dart';
import 'package:wetaran_pharma/features/orders/presentation/pages/add_order_screen.dart';
import 'package:wetaran_pharma/features/orders/presentation/pages/pharma_preview_order_page.dart';

const _blue = Color(0xFF0B4F8A);
const _blueDk = Color(0xFF083A66);
const _blueDeep = Color(0xFF06304F);
const _teal = Color(0xFF0FA3A3);
const _tealSoft = Color(0xFFE2F4F4);
const _pageBg = Color(0xFFF3F7FA);
const _card = Colors.white;
const _headingColor = Color(0xFF13242F);
const _mutedColor = Color(0xFF63788A);
const _faintColor = Color(0xFF93A6B5);
const _borderColor = Color(0xFFE3EBF1);

const _red = Color(0xFFC43D3D);
const _redSoft = Color(0xFFFBEAEA);
const _green = Color(0xFF0E8A4C);
const _greenSoft = Color(0xFFE4F5EC);

void showPharmaCartSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<PharmaCartProvider>(),
      child: const _PharmaCartSheet(),
    ),
  );
}

class _PharmaCartSheet extends StatelessWidget {
  const _PharmaCartSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<PharmaCartProvider>(
      builder: (ctx, cart, _) {
        return DraggableScrollableSheet(
          initialChildSize: 0.68,
          minChildSize: 0.42,
          maxChildSize: 0.94,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: _pageBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: _borderColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _buildHeader(ctx, cart),
                  ),

                  const Divider(height: 1, color: _borderColor),

                  if (cart.isEmpty)
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 74,
                                height: 74,
                                decoration: BoxDecoration(
                                  color: _tealSoft,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: const Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 34,
                                  color: _teal,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Your cart is empty',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: _headingColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Search medicines and compare distributors to add items for your next order.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: _mutedColor,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 18),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.pop(ctx),
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  size: 18,
                                  color: _blue,
                                ),
                                label: const Text(
                                  'Continue browsing',
                                  style: TextStyle(
                                    color: _blue,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: _borderColor),
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        children: [
                          if (cart.lockedDistributorName != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _tealSoft,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _teal.withOpacity(.15),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.storefront_outlined,
                                    size: 17,
                                    color: _teal,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Distributor locked: ${cart.lockedDistributorName!}',
                                      style: const TextStyle(
                                        fontSize: 11.8,
                                        color: _blue,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ...List.generate(cart.items.length, (i) {
                            final item = cart.items[i];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: i == cart.items.length - 1 ? 0 : 10,
                              ),
                              child: CartItemRow(item: item, cart: cart),
                            );
                          }),
                        ],
                      ),
                    ),

                  if (cart.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: _borderColor)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _pageBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SummaryRow(
                                  label: 'Items',
                                  value: '${cart.itemCount}',
                                  muted: true,
                                ),
                                const SizedBox(height: 8),
                                SummaryRow(
                                  label: 'Subtotal',
                                  value: '₹${cart.subtotal.toStringAsFixed(2)}',
                                ),
                                const SizedBox(height: 8),
                                const Divider(color: _borderColor, height: 1),
                                const SizedBox(height: 10),
                                SummaryRow(
                                  label: 'Order total',
                                  value: '₹${cart.subtotal.toStringAsFixed(2)}',
                                  bold: true,
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _greenSoft,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Ready to review',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: _green,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [_blue, _blueDk, _blueDeep],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: _blue.withOpacity(.20),
                                    blurRadius: 14,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final nav = Navigator.of(context);
                                  Navigator.pop(ctx);
                                  Future.microtask(() {
                                    nav.push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            PharmaPreviewOrderPage(cart: cart),
                                      ),
                                    );
                                  });
                                },
                                icon: const Icon(
                                  Icons.receipt_long_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Proceed to Order Preview',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  elevation: 0,
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
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext ctx, PharmaCartProvider cart) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _tealSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.shopping_cart_rounded,
            color: _teal,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your order',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _headingColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'} added',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: _mutedColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (cart.isNotEmpty)
          TextButton(
            onPressed: () => _showClearDialog(ctx, cart),
            style: TextButton.styleFrom(
              foregroundColor: _red,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            child: const Text(
              'Clear',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _borderColor),
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 18,
              color: _mutedColor,
            ),
          ),
        ),
      ],
    );
  }

  void _showClearDialog(BuildContext ctx, PharmaCartProvider cart) {
    showDialog(
      context: ctx,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: _redSoft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 27,
                  color: _red,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Clear cart?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _headingColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'All items will be removed from your order basket.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: _mutedColor,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        side: const BorderSide(color: _borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: _headingColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        cart.clear();
                        Navigator.pop(ctx);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Clear Cart',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartItemTile extends StatefulWidget {
  final PharmaCartItem item;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onRemove;

  const _CartItemTile({
    required this.item,
    required this.onQtyChanged,
    required this.onRemove,
  });

  @override
  State<_CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends State<_CartItemTile> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  bool _hasFocus = false;
  bool _internalUpdate = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.item.quantity}');
    _focus = FocusNode()
      ..addListener(() {
        if (!mounted) return;
        setState(() => _hasFocus = _focus.hasFocus);
        if (!_focus.hasFocus) _submit();
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  int get _maxQty {
    if (widget.item.allowOrderBeyondStock) return 9999;
    return widget.item.availableStock.toInt();
  }

  void _setText(String v) {
    _internalUpdate = true;
    _ctrl.value = TextEditingValue(
      text: v,
      selection: TextSelection.collapsed(offset: v.length),
    );
    _internalUpdate = false;
  }

  void _submit() {
    final parsed = int.tryParse(_ctrl.text.trim());
    if (parsed == null || parsed < 1) {
      _setText('1');
      widget.onQtyChanged(1);
      return;
    }
    final max = _maxQty;
    final clamped = max <= 0 ? parsed : parsed.clamp(1, max);
    _setText('$clamped');
    widget.onQtyChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final qty = item.quantity;
    final hasDiscount = item.discountPercent > 0;

    if (!_hasFocus) {
      final expected = '$qty';
      if (_ctrl.text != expected) _setText(expected);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12083A66),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.skuName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.2,
                    fontWeight: FontWeight.w700,
                    color: _headingColor,
                    height: 1.3,
                  ),
                ),
                if (item.genericName != null &&
                    item.genericName!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.genericName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.2, color: _mutedColor),
                  ),
                ],
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '₹${item.pricePerUnit.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _blue,
                      ),
                    ),
                    if (hasDiscount)
                      Text(
                        'MRP ₹${item.mrp.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: _mutedColor,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    if (hasDiscount)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _greenSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${item.discountPercent.toStringAsFixed(0)}% OFF',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: _green,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'Line total: ₹${item.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 11.2,
                    fontWeight: FontWeight.w600,
                    color: _mutedColor,
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
                                : () => widget.onQtyChanged(qty - 1),
                          ),
                          SizedBox(
                            width: 42,
                            height: 32,
                            child: TextField(
                              controller: _ctrl,
                              focusNode: _focus,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _headingColor,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 7,
                                ),
                              ),
                              onChanged: (_) {
                                if (_internalUpdate) return;
                              },
                              onSubmitted: (_) => _submit(),
                              onTapOutside: (_) {
                                _submit();
                                FocusScope.of(context).unfocus();
                              },
                            ),
                          ),
                          _stepBtn(
                            icon: Icons.add_rounded,
                            color: _blue,
                            onTap: () => widget.onQtyChanged(qty + 1),
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
                      onTap: widget.onRemove,
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
}
