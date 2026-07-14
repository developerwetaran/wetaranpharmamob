import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wetaran_pharma/features/orders/models/pharma_cart_provider.dart';
import 'package:wetaran_pharma/models/sku_model.dart';

const _blue = Color(0xFF0B4F8A);
const _blueSoft = Color(0xFFE4EDF7);
const _heading = Color(0xFF13242F);
const _muted = Color(0xFF63788A);
const _border = Color(0xFFE3EBF1);
const _pageBg = Color(0xFFF3F7FA);
const _green = Color(0xFF0E8A4C);
const _greenSoft = Color(0xFFE4F5EC);
const _amber = Color(0xFFB36A00);
const _amberSoft = Color(0xFFFFF4E0);
const _red = Color(0xFFC43D3D);
const _redSoft = Color(0xFFFBEAEA);
const _teal = Color(0xFF0FA3A3);
const _tealSoft = Color(0xFFE2F4F4);

class ProductDistributorOffer {
  final String distributorId;
  final String distributorName;
  final SkuProduct product;
  final SkuVariant variant;
  final double ptr;
  final double mrp;
  final double stock;
  final bool allowBeyond;
  final double discountPct;
  final String deliveryLabel;
  final double minimumOrderValue;

  const ProductDistributorOffer({
    required this.distributorId,
    required this.distributorName,
    required this.product,
    required this.variant,
    required this.ptr,
    required this.mrp,
    required this.stock,
    required this.allowBeyond,
    required this.discountPct,
    required this.deliveryLabel,
    required this.minimumOrderValue,
  });
}

String? _cartDistributorId(PharmaCartProvider cart) {
  if (cart.items.isEmpty) return null;
  return cart.items.first.distributorId;
}

Future<void> showDistributorComparisonDialog({
  required BuildContext context,
  required String title,
  required List<ProductDistributorOffer> offers,
  required void Function(ProductDistributorOffer offer) onAddOffer,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Distributor comparison',
    barrierColor: Colors.black.withOpacity(0.48),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) {
      return _DistributorComparisonDialog(
        title: title,
        offers: offers,
        onAddOffer: onAddOffer,
      );
    },
    transitionBuilder: (_, anim, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.96,
            end: 1,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    },
  );
}

class _DistributorComparisonDialog extends StatelessWidget {
  final String title;
  final List<ProductDistributorOffer> offers;
  final void Function(ProductDistributorOffer offer) onAddOffer;

  const _DistributorComparisonDialog({
    required this.title,
    required this.offers,
    required this.onAddOffer,
  });

  @override
  Widget build(BuildContext context) {
    final sortedOffers = [...offers]
      ..sort((a, b) {
        final aUsable = a.stock > 0 || a.allowBeyond;
        final bUsable = b.stock > 0 || b.allowBeyond;
        if (aUsable != bUsable) return aUsable ? -1 : 1;
        final byPrice = a.ptr.compareTo(b.ptr);
        if (byPrice != 0) return byPrice;
        return a.distributorName.compareTo(b.distributorName);
      });

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.94,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.84,
            ),
            color: _pageBg,
            child: Consumer<PharmaCartProvider>(
              builder: (context, cart, _) {
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        border: Border(bottom: BorderSide(color: _border)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _blueSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.compare_arrows_rounded,
                              size: 19,
                              color: _blue,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Compare distributors',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: _heading,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _muted,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _border),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: _heading,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: sortedOffers.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'No distributor offers available for this medicine.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _muted,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                12,
                                12,
                                16,
                              ),
                              itemCount: sortedOffers.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final offer = sortedOffers[i];
                                return _DistributorOfferTile(
                                  offer: offer,
                                  isCheapest: i == 0,
                                  cart: cart,
                                  onAddOffer: onAddOffer,
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DistributorOfferTile extends StatelessWidget {
  final ProductDistributorOffer offer;
  final bool isCheapest;
  final PharmaCartProvider cart;
  final void Function(ProductDistributorOffer offer) onAddOffer;

  const _DistributorOfferTile({
    required this.offer,
    required this.isCheapest,
    required this.cart,
    required this.onAddOffer,
  });

  @override
  Widget build(BuildContext context) {
    final qty = cart.qtyForVariant(offer.variant.id, offer.variant.primaryUnit);
    final inCart = cart.isVariantInCart(
      offer.variant.id,
      offer.variant.primaryUnit,
    );
    final activeDistributorId = _cartDistributorId(cart);
    final selectedHere = activeDistributorId == offer.distributorId && inCart;
    final outOfStock = offer.stock <= 0;

    final tileBg = selectedHere ? const Color(0xFFF0FFF8) : Colors.white;
    final tileBorder = selectedHere ? const Color(0xFFBBF7D0) : _border;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tileBorder, width: selectedHere ? 1.4 : 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120B4F8A),
            blurRadius: 10,
            offset: Offset(0, 2),
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
                  offer.distributorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _heading,
                  ),
                ),
              ),
              if (isCheapest) _pill('Best price', _greenSoft, _green),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _iconPill(
                Icons.local_shipping_outlined,
                offer.deliveryLabel,
                _tealSoft,
                _teal,
              ),
              _iconPill(
                Icons.currency_rupee_rounded,
                offer.minimumOrderValue > 0
                    ? 'Min order ₹${offer.minimumOrderValue.toStringAsFixed(0)}'
                    : 'No min order',
                _blueSoft,
                _blue,
              ),
              _iconPill(
                Icons.inventory_2_outlined,
                outOfStock
                    ? (offer.allowBeyond
                          ? 'No stock · order allowed'
                          : 'Out of stock')
                    : 'Stock ${offer.stock.toInt()} ${offer.variant.primaryUnit}',
                outOfStock
                    ? (offer.allowBeyond ? _amberSoft : _redSoft)
                    : _greenSoft,
                outOfStock ? (offer.allowBeyond ? _amber : _red) : _green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _pageBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _metric(
                    'PTR',
                    '₹${offer.ptr.toStringAsFixed(2)}',
                    valueColor: _blue,
                  ),
                ),
                Expanded(
                  child: _metric(
                    'MRP',
                    offer.mrp > 0 ? '₹${offer.mrp.toStringAsFixed(2)}' : '-',
                    strike: offer.mrp > 0,
                  ),
                ),
                Expanded(
                  child: _metric(
                    'Save',
                    offer.discountPct > 0
                        ? '${offer.discountPct.toStringAsFixed(0)}%'
                        : '-',
                    valueColor: offer.discountPct > 0 ? _green : _heading,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            offer.variant.variantName.isEmpty
                ? offer.variant.primaryUnit
                : '${offer.variant.variantName} · ${offer.variant.primaryUnit}',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _muted,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: selectedHere
                ? _LiveQtyState(qty: qty, unit: offer.variant.primaryUnit)
                : OutlinedButton.icon(
                    onPressed: (outOfStock && !offer.allowBeyond)
                        ? null
                        : () => onAddOffer(offer),
                    icon: const Icon(
                      Icons.add_shopping_cart_rounded,
                      size: 16,
                      color: _blue,
                    ),
                    label: const Text(
                      'Add to Cart',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _blue,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _blue, width: 1.4),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  static Widget _iconPill(IconData icon, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _metric(
    String label,
    String value, {
    Color valueColor = _heading,
    bool strike = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            color: _muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: valueColor,
            decoration: strike ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }
}

class _LiveQtyState extends StatelessWidget {
  final int qty;
  final String unit;

  const _LiveQtyState({required this.qty, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: _greenSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB7E4C7)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, size: 16, color: _green),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Added · $qty $unit',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
