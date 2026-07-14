import 'package:flutter/material.dart';
import 'package:wetaran_pharma/features/orders/models/pharma_cart_provider.dart';
import 'package:wetaran_pharma/models/sku_model.dart';

const primaryBlue = Color(0xFF0B4F8A);
const mutedColor = Color(0xFF63788A);
const borderColor = Color(0xFFE3EBF1);
const green = Color(0xFF0E8A4C);
const greenSoft = Color(0xFFE4F5EC);
const amber = Color(0xFFB36A00);
const amberSoft = Color(0xFFFFF4E0);
const red = Color(0xFFC43D3D);
const redSoft = Color(0xFFFBEAEA);

typedef QtyBuilder =
    Widget Function({
      required String variantId,
      required String unit,
      required int qty,
      required int max,
      required bool allowBeyond,
      required PharmaCartProvider cart,
      bool compact,
    });

typedef AddToCartCallback =
    void Function({
      required SkuProduct product,
      required SkuVariant? variant,
      required String distributorId,
      required String distributorName,
      required PharmaCartProvider cart,
    });

typedef IsVariantInCartCallback =
    bool Function(PharmaCartProvider cart, SkuVariant variant);

Future<void> showVariantPickerDialog({
  required BuildContext context,
  required SkuProduct product,
  required List<SkuVariant> variants,
  required String distributorId,
  required String distributorName,
  required PharmaCartProvider cart,
  required int Function(PharmaCartProvider cart, String variantId, String unit)
  selectedQtyFor,
  required IsVariantInCartCallback isVariantInCart,
  required QtyBuilder buildQtyStepper,
  required AddToCartCallback addToCart,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Variants',
    barrierColor: Colors.black.withOpacity(0.50),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, animation, _) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(ctx).size.width * 0.92,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.80,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBFF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: StatefulBuilder(
              builder: (ctx2, setModal) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFF0F0F0)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${variants.length} variant(s) • Select a variant',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx2),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.red.shade400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: variants.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 36,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'No variants available for this product',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                12,
                                12,
                                16,
                              ),
                              itemCount: variants.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final variant = variants[i];
                                final stock = variant.availableStock;
                                final outOfStock = stock <= 0;
                                final allowBeyond =
                                    variant.allowOrderBeyondStock;
                                final hasDiscount =
                                    variant.maxRetailPrice > 0 &&
                                    variant.maxRetailPrice >
                                        variant.sellPriceToRetailer;
                                final discountPct = hasDiscount
                                    ? ((variant.maxRetailPrice -
                                                  variant.sellPriceToRetailer) /
                                              variant.maxRetailPrice) *
                                          100
                                    : 0.0;

                                final qty = selectedQtyFor(
                                  cart,
                                  variant.id,
                                  variant.primaryUnit,
                                );

                                final inCart = isVariantInCart(cart, variant);

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: inCart
                                        ? const Color(0xFFF0FFF8)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: inCart
                                          ? const Color(0xFFBBF7D0)
                                          : const Color(0xFFEEEEF5),
                                      width: inCart ? 1.4 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color.fromRGBO(
                                                0,
                                                60,
                                                190,
                                                1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(7),
                                            ),
                                            child: Text(
                                              variant.variantName,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              variant.variantSkuCode,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: outOfStock
                                                  ? (allowBeyond
                                                        ? amberSoft
                                                        : redSoft)
                                                  : greenSoft,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              outOfStock
                                                  ? (allowBeyond
                                                        ? 'On Order'
                                                        : 'Out of Stock')
                                                  : '${stock.toInt()} ${variant.primaryUnit}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: outOfStock
                                                    ? (allowBeyond
                                                          ? amber
                                                          : red)
                                                    : green,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Text(
                                            variant.sellPriceToRetailer
                                                .toStringAsFixed(2),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: primaryBlue,
                                            ),
                                          ),
                                          if (hasDiscount) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              variant.maxRetailPrice
                                                  .toStringAsFixed(2),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: mutedColor,
                                                decoration:
                                                    TextDecoration.lineThrough,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: greenSoft,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${discountPct.toStringAsFixed(0)}% OFF',
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: green,
                                                ),
                                              ),
                                            ),
                                          ],
                                          const Spacer(),
                                          if (inCart)
                                            buildQtyStepper(
                                              variantId: variant.id,
                                              unit: variant.primaryUnit,
                                              qty: qty,
                                              max: stock.toInt(),
                                              allowBeyond: allowBeyond,
                                              cart: cart,
                                              compact: true,
                                            )
                                          else
                                            ElevatedButton(
                                              onPressed:
                                                  outOfStock && !allowBeyond
                                                  ? null
                                                  : () {
                                                      addToCart(
                                                        product: product,
                                                        variant: variant,
                                                        distributorId:
                                                            distributorId,
                                                        distributorName:
                                                            distributorName,
                                                        cart: cart,
                                                      );
                                                      setModal(() {});
                                                    },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color.fromRGBO(
                                                      0,
                                                      60,
                                                      190,
                                                      1,
                                                    ),
                                                disabledBackgroundColor:
                                                    borderColor,
                                                elevation: 0,
                                                minimumSize: const Size(0, 36),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: const Text(
                                                'Add',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
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
