// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wetaran_pharma/core/widgets/app_drawer.dart';
import 'package:wetaran_pharma/features/orders/models/pharma_cart_provider.dart';
import 'package:wetaran_pharma/features/orders/presentation/pages/pharma_preview_order_page.dart';
import 'package:wetaran_pharma/features/orders/presentation/widgets/comparison_sheet.dart';
import 'package:wetaran_pharma/features/orders/presentation/widgets/product_preview_card.dart';
import 'package:wetaran_pharma/features/orders/services/pharma_distributor_service.dart';
import 'package:wetaran_pharma/models/sku_model.dart';

const primaryBlue = Color(0xFF0B4F8A);
const primaryBlueDeep = Color(0xFF06304F);
const primaryBlueSoft = Color(0xFFE4EDF7);
const teal = Color(0xFF0FA3A3);
const tealSoft = Color(0xFFE2F4F4);
const headingColor = Color(0xFF13242F);
const mutedColor = Color(0xFF63788A);
const borderColor = Color(0xFFE3EBF1);
const green = Color(0xFF0E8A4C);
const greenSoft = Color(0xFFE4F5EC);
const amber = Color(0xFFB36A00);
const amberSoft = Color(0xFFFFF4E0);
const red = Color(0xFFC43D3D);
const redSoft = Color(0xFFFBEAEA);
const pageBg = Color(0xFFF3F7FA);
const kBlue = Color(0xFF0B4F8A);
const kBlueDk = Color(0xFF083A66);

enum PharmaOrderViewMode { bySku, byDistributor }

class AddOrderScreen extends StatefulWidget {
  const AddOrderScreen({super.key});

  @override
  State<AddOrderScreen> createState() => AddOrderScreenState();
}

class AddOrderScreenState extends State<AddOrderScreen> {
  String? pincode;
  String? city;
  String? state;

  List<PharmaDistributor> distributors = [];

  bool loadingDistributors = true;
  String? loadError;
  String? selectedDistributorId;

  List<SkuProduct> allProducts = [];
  List<SkuProduct> filteredProducts = [];
  List<SkuProduct> searchSuggestions = [];

  bool showSuggestions = false;
  PharmaOrderViewMode viewMode = PharmaOrderViewMode.bySku;

  final TextEditingController searchCtrl = TextEditingController();
  String selectedCategory = 'All';
  List<String> categories = ['All'];

  List<MapEntry<String, List<MapEntry<dynamic, SkuProduct>>>> mergedFiltered =
      [];

  Timer? debounce;

  @override
  void initState() {
    super.initState();
    searchCtrl.addListener(onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => init());
  }

  @override
  void dispose() {
    searchCtrl.removeListener(onSearchChanged);
    searchCtrl.dispose();
    debounce?.cancel();
    super.dispose();
  }

  void onSearchChanged() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 220), applyFilter);
  }

  Future<void> init() async {
    setState(() {
      loadingDistributors = true;
      loadError = null;
    });

    try {
      final location = await PharmaDistributorService.loadPharmaUserLocation();

      pincode = location['pincode'];
      city = location['city'];
      state = location['state'];

      final loadedDistributors =
          await PharmaDistributorService.loadDistributorsWithProducts(
            pincode: pincode,
            city: city,
            state: state,
          );

      if (!mounted) return;

      setState(() {
        distributors = loadedDistributors;
        loadingDistributors = false;
      });

      if (distributors.isNotEmpty) {
        final cart = context.read<PharmaCartProvider>();
        final lockedId = cart.lockedDistributorId;

        final hasLocked =
            lockedId != null &&
            lockedId.isNotEmpty &&
            distributors.any((d) => d.id == lockedId);

        selectDistributor(hasLocked ? lockedId : distributors.first.id);
      } else {
        buildMergedMap();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loadError = e.toString();
        loadingDistributors = false;
      });
    }
  }

  void onDistributorChipTap(String id, PharmaCartProvider cart) {
    if (cart.isNotEmpty &&
        cart.lockedDistributorId != null &&
        cart.lockedDistributorId != id) {
      showDistributorSwitchDialog(
        cart: cart,
        newDistId: id,
        newDistName: distributors.firstWhere((d) => d.id == id).companyName,
      );
      return;
    }

    selectDistributor(id);
  }

  void selectDistributor(String id) {
    if (distributors.isEmpty) return;

    final dist = distributors.firstWhere(
      (d) => d.id == id,
      orElse: () => distributors.first,
    );

    final List<SkuProduct> products = List<SkuProduct>.from(
      // ignore: dead_code
      dist.products ?? [],
    );

    final builtCategories =
        <String>{
          'All',
          ...products.map(
            (p) => (p.category == null || p.category!.trim().isEmpty)
                ? 'Uncategorised'
                : p.category!.trim(),
          ),
        }.toList()..sort((a, b) {
          if (a == 'All') return -1;
          if (b == 'All') return 1;
          return a.compareTo(b);
        });

    setState(() {
      selectedDistributorId = id;
      allProducts = products;
      filteredProducts = products;
      categories = builtCategories;
      selectedCategory = 'All';
      showSuggestions = false;
      searchSuggestions = [];
      searchCtrl.clear();
    });

    buildMergedMap();
  }

  PharmaDistributor? get selectedDist {
    if (distributors.isEmpty) return null;
    return distributors.firstWhere(
      (d) => d.id == selectedDistributorId,
      orElse: () => distributors.first,
    );
  }

  String getImageUrl(String path) {
    if (path.startsWith('http')) return path;
    return Supabase.instance.client.storage.from('products').getPublicUrl(path);
  }

  List<SkuVariant> _sortedVariants(SkuProduct product) {
    final variants = product.variants.isNotEmpty
        ? List<SkuVariant>.from(product.variants)
        : <SkuVariant>[_fallbackVariantFor(product)];

    variants.sort((a, b) {
      final byPrice = a.sellPriceToRetailer.compareTo(b.sellPriceToRetailer);
      if (byPrice != 0) return byPrice;
      final aIn = a.availableStock > 0 ? 1 : 0;
      final bIn = b.availableStock > 0 ? 1 : 0;
      if (aIn != bIn) return bIn.compareTo(aIn);
      return b.availableStock.compareTo(a.availableStock);
    });

    return variants;
  }

  SkuVariant _fallbackVariantFor(SkuProduct product) {
    return SkuVariant(
      id: product.id,
      variantName: 'Standard',
      variantSkuCode: product.skuCode ?? '',
      primaryUnit: product.primaryUnit,
      availableStock: product.currentStock,
      sellPriceToRetailer: product.sellPriceToRetailer,
      maxRetailPrice: product.maxRetailPrice ?? 0,
      allowSellingInAlternativeUnit: product.allowSellingInAlternativeUnit,
      allowOrderBeyondStock: false,
      alternativeUnits: product.alternativeUnits,
    );
  }

  int selectedQtyFor(PharmaCartProvider cart, String variantId, String unit) {
    return cart.qtyForVariant(variantId, unit);
  }

  void handleProductTap({
    required SkuProduct product,
    required String distributorId,
    required String distributorName,
    required PharmaCartProvider cart,
  }) {
    final variants = _sortedVariants(product);

    if (variants.length <= 1) {
      addToCart(
        product: product,
        variant: variants.first,
        distributorId: distributorId,
        distributorName: distributorName,
        cart: cart,
      );
      return;
    }

    showVariantPicker(
      product: product,
      distributorId: distributorId,
      distributorName: distributorName,
      cart: cart,
    );
  }

  void showVariantPicker({
    required SkuProduct product,
    required String distributorId,
    required String distributorName,
    required PharmaCartProvider cart,
  }) {
    final variants = _sortedVariants(product);

    showGeneralDialog(
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
                                                    variant
                                                        .sellPriceToRetailer) /
                                                variant.maxRetailPrice) *
                                            100
                                      : 0.0;

                                  final qty = selectedQtyFor(
                                    cart,
                                    variant.id,
                                    variant.primaryUnit,
                                  );

                                  final inCart = cart.isVariantInCart(
                                    variant.id,
                                    variant.primaryUnit,
                                  );

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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Color.fromRGBO(
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
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                                  decoration: TextDecoration
                                                      .lineThrough,
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
                                                      Color.fromRGBO(
                                                        0,
                                                        60,
                                                        190,
                                                        1,
                                                      ),
                                                  disabledBackgroundColor:
                                                      borderColor,
                                                  elevation: 0,
                                                  minimumSize: const Size(
                                                    0,
                                                    36,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
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

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<PharmaCartProvider>();
    _syncSelectedDistributorWithCart(cart);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: buildAppBar(cart),
      body: loadingDistributors
          ? buildLoading()
          : loadError != null
          ? buildError()
          : distributors.isEmpty
          ? buildNoDistributors()
          : Column(
              children: [
                buildTopSection(cart),
                Expanded(
                  child: viewMode == PharmaOrderViewMode.byDistributor
                      ? buildByDistributorView(cart)
                      : buildBySkuView(cart),
                ),
              ],
            ),
      bottomNavigationBar: cart.isNotEmpty ? buildCartBar(cart) : null,
    );
  }

  PreferredSizeWidget buildAppBar(PharmaCartProvider cart) {
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
            colors: [kBlue, kBlueDk, Color(0xFF06304F)],
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
        'Place Order',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      actions: [
        if (cart.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => showCartSheet(cart),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.13),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(.10)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shopping_cart_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${cart.itemCount}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white.withOpacity(.10)),
      ),
    );
  }

  Widget buildTopSection(PharmaCartProvider cart) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildViewToggle(),
          const SizedBox(height: 12),
          if (viewMode == PharmaOrderViewMode.byDistributor)
            buildDistributorChips(cart),
          buildSearchBar(),
          const SizedBox(height: 10),
          if (showSuggestions) buildSuggestions(),
          const SizedBox(height: 10),
          Container(height: 1, color: borderColor),
        ],
      ),
    );
  }

  Widget buildViewToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE3FF)),
      ),
      child: Row(
        children: [
          modeChip('By SKU', PharmaOrderViewMode.bySku),
          modeChip('By Distributor', PharmaOrderViewMode.byDistributor),
        ],
      ),
    );
  }

  Widget modeChip(String label, PharmaOrderViewMode mode) {
    final selected = viewMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (viewMode == mode) return;

          setState(() {
            viewMode = mode;
            selectedCategory = 'All';
            showSuggestions = false;
            searchSuggestions = [];
            searchCtrl.clear();
          });

          if (viewMode == PharmaOrderViewMode.byDistributor &&
              selectedDistributorId != null) {
            selectDistributor(selectedDistributorId!);
          } else {
            buildMergedMap();
            applyFilter();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [kBlue, kBlueDk, Color(0xFF06304F)],
                  )
                : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : kBlue,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: pageBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: searchCtrl,
        style: const TextStyle(fontSize: 14, color: headingColor),
        decoration: InputDecoration(
          hintText: 'Search by name, SKU code, category...',
          hintStyle: const TextStyle(fontSize: 14, color: mutedColor),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: primaryBlue,
            size: 20,
          ),
          suffixIcon: searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: mutedColor,
                    size: 18,
                  ),
                  onPressed: () {
                    searchCtrl.clear();
                    applyFilter();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget buildSuggestions() {
    if (searchSuggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: searchSuggestions.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: borderColor),
        itemBuilder: (_, i) {
          final sku = searchSuggestions[i];
          return ListTile(
            dense: true,
            leading: const Icon(
              Icons.search_rounded,
              size: 18,
              color: primaryBlue,
            ),
            title: Text(
              sku.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              sku.skuCode ?? '-',
              style: const TextStyle(fontSize: 11, color: mutedColor),
            ),
            onTap: () {
              FocusScope.of(context).unfocus();
              searchCtrl.text = sku.name;
              setState(() => showSuggestions = false);
              applyFilter();
            },
          );
        },
      ),
    );
  }

  Widget buildDistributorChips(PharmaCartProvider cart) {
    final lockedId = cart.lockedDistributorId;
    final isLocked = cart.isNotEmpty && lockedId != null && lockedId.isNotEmpty;

    // ignore: unnecessary_question_mark
    final selectedDistributor = distributors.cast<dynamic?>().firstWhere(
      (d) => d?.id == selectedDistributorId,
      orElse: () => null,
    );

    // ignore: unnecessary_question_mark
    final lockedDistributor = distributors.cast<dynamic?>().firstWhere(
      (d) => d?.id == lockedId,
      orElse: () => null,
    );

    const kBlue = Color(0xFF0B4F8A);
    const kBlueSoft = Color(0xFFE4EDF7);
    const kTeal = Color(0xFF0FA3A3);
    const kTealSoft = Color(0xFFE2F4F4);
    const kBg = Color(0xFFF3F7FA);
    const kLine = Color(0xFFE3EBF1);
    const kInk = Color(0xFF13242F);
    const kMuted = Color(0xFF63788A);
    const kAmber = Color(0xFFB36A00);
    const kAmberSoft = Color(0xFFFFF4E0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isLocked ? const Color(0xFFF5DFB8) : kLine),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120B4F8A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isLocked ? kAmberSoft : kBlueSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isLocked ? Icons.lock_outline_rounded : Icons.business_outlined,
              color: isLocked ? kAmber : kBlue,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Distributor',
                  style: const TextStyle(
                    fontSize: 11,
                    color: kMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                if (isLocked)
                  Text(
                    lockedDistributor?.companyName ??
                        cart.lockedDistributorName ??
                        lockedId,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kInk,
                    ),
                  )
                else
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedDistributorId,
                      isExpanded: true,
                      isDense: true,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kInk,
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: kBlue,
                        size: 20,
                      ),
                      items: distributors.map<DropdownMenuItem<String>>((dist) {
                        return DropdownMenuItem<String>(
                          // ignore: unnecessary_cast
                          value: dist.id as String,
                          child: Text(
                            // ignore: dead_code
                            dist.companyName ?? dist.id,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: kInk,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (id) {
                        if (id == null) return;

                        final lockedElsewhere =
                            cart.isNotEmpty &&
                            cart.lockedDistributorId != null &&
                            cart.lockedDistributorId != id;

                        if (lockedElsewhere) {
                          showDistributorLockInfo(
                            cart.lockedDistributorName ?? 'another distributor',
                          );
                          return;
                        }

                        selectDistributor(id);
                      },
                    ),
                  ),
                if (!isLocked &&
                    selectedDistributor != null &&
                    (selectedDistributor.companyName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  const Text(
                    'Choose distributor for this order',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: kMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isLocked) ...[
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: kAmberSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Cart Locked',
                    style: TextStyle(
                      fontSize: 10,
                      color: kAmber,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        title: const Text(
                          'Clear cart to change distributor',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: kInk,
                          ),
                        ),
                        content: const Text(
                          'Your cart is locked to another distributor. Clear the cart to change distributor.',
                          style: TextStyle(
                            fontSize: 13,
                            color: kMuted,
                            height: 1.45,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: kMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              cart.clear();
                              Navigator.pop(dialogCtx);

                              final fallbackDistributor =
                                  distributors.isNotEmpty
                                  ? distributors.first
                                  : null;
                              if (fallbackDistributor == null) return;

                              selectDistributor(
                                // ignore: unnecessary_cast
                                fallbackDistributor.id as String,
                              );
                            },
                            child: const Text(
                              'Clear & Change',
                              style: TextStyle(
                                color: kTeal,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: kTealSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: kTeal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kLine),
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                size: 15,
                color: kBlue,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildCategoryChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final selected = selectedCategory == cat;

          return GestureDetector(
            onTap: () {
              setState(() => selectedCategory = cat);
              applyFilter();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? primaryBlueSoft : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? primaryBlue : borderColor),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? primaryBlue : mutedColor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildByDistributorView(PharmaCartProvider cart) {
    if (filteredProducts.isEmpty) return buildEmptyState();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: filteredProducts.length,
      itemBuilder: (_, i) => buildSkuCard(filteredProducts[i], cart),
    );
  }

  Widget buildBySkuView(PharmaCartProvider cart) {
    if (mergedFiltered.isEmpty) return buildEmptyState();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: mergedFiltered.length,
      itemBuilder: (_, i) {
        final entry = mergedFiltered[i];
        final sample = entry.value.first.value;
        return buildMergedSkuCard(sample, entry.value, cart);
      },
    );
  }

  String formatDeliveryLabel({
    required String expectedDelivery,
    String? sameDayCutoff,
  }) {
    final type = expectedDelivery.trim().toLowerCase();

    if (type == 'same_day') {
      final cutoff = (sameDayCutoff ?? '').trim();
      if (cutoff.isNotEmpty) {
        return 'Same day · order before $cutoff';
      }
      return 'Same day delivery';
    }

    if (type == 'next_day') {
      return 'Next day delivery';
    }

    return 'Delivery info unavailable';
  }

  List<ProductDistributorOffer> buildComparisonOffers(SkuProduct target) {
    final offers = <ProductDistributorOffer>[];
    final seen = <String>{};

    for (final dist in distributors) {
      final products = List<SkuProduct>.from(dist.products ?? []);

      for (final product in products) {
        if (!isSameMedicine(product, target)) continue;

        final variants = _sortedVariants(product);
        final variant = variants.isNotEmpty
            ? variants.first
            : _fallbackVariantFor(product);

        final ptr = variant.sellPriceToRetailer;
        final mrp = variant.maxRetailPrice;
        final stock = variant.availableStock;
        final allowBeyond = variant.allowOrderBeyondStock;
        final discountPct = (mrp > 0 && mrp > ptr)
            ? ((mrp - ptr) / mrp) * 100
            : 0.0;

        final key = '${dist.id}_${variant.id}';
        if (seen.contains(key)) continue;
        seen.add(key);

        offers.add(
          ProductDistributorOffer(
            distributorId: dist.id.toString(),
            distributorName: dist.companyName,
            product: product,
            variant: variant,
            ptr: ptr,
            mrp: mrp,
            stock: stock,
            allowBeyond: allowBeyond,
            discountPct: discountPct,
            deliveryLabel: formatDeliveryLabel(
              expectedDelivery: dist.pharmaExpectedDelivery,
              sameDayCutoff: dist.pharmaSameDayOrderCutoff,
            ),
            minimumOrderValue: dist.pharmaMinimumOrderValue,
          ),
        );
      }
    }

    offers.sort((a, b) {
      final aUsable = a.stock > 0 || a.allowBeyond;
      final bUsable = b.stock > 0 || b.allowBeyond;
      if (aUsable != bUsable) return aUsable ? -1 : 1;

      final byPrice = a.ptr.compareTo(b.ptr);
      if (byPrice != 0) return byPrice;

      return a.distributorName.compareTo(b.distributorName);
    });

    return offers;
  }

  void showProductInfoPopup(
    SkuProduct product, {
    required String distributorId,
    required String distributorName,
  }) {
    final normalized = <String, dynamic>{
      'id': product.id,
      'name': product.name,
      'image_path': product.imagePath != null && product.imagePath!.isNotEmpty
          ? getImageUrl(product.imagePath!)
          : '',
      'sku_code': product.skuCode,
      'category': product.category ?? '',
      'primary_unit': product.primaryUnit,
      'hsn_code': product.hsnCode ?? '',
      'tax_slab': product.taxSlab,
      'sub_brand_name': product.subBrandName ?? '',
      'sub_brand_logo_url': product.subBrandLogoUrl ?? '',
      'allow_selling_in_alternative_unit':
          product.allowSellingInAlternativeUnit,
      'current_stock': product.currentStock,
      'base_price': product.sellPriceToRetailer,
      'alternative_units': product.alternativeUnits
          .map((u) => u.toJson())
          .toList(),
      'variants': product.variants,
      'info': product.info,
    };

    final cart = context.read<PharmaCartProvider>();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Product preview',
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) {
        return ProductPreviewCard(
          product: normalized,
          cart: cart,
          distributorId: distributorId,
          distributorName: distributorName,
          onClose: () => Navigator.of(context).pop(),
          onAddToCart: (variant, unit, qtyDelta) {
            final currentQty = cart.qtyForVariant(variant.id, unit);

            if (currentQty == 0 && qtyDelta > 0) {
              addToCart(
                product: product,
                variant: variant,
                distributorId: distributorId,
                distributorName: distributorName,
                cart: cart,
              );
            } else {
              cart.updateQuantity(variant.id, unit, currentQty + qtyDelta);
            }
          },
          onCompareDistributors: () {
            Navigator.of(context).pop();
            Future.microtask(() {
              showDistributorComparisonDialog(
                context: context,
                title: product.name,
                offers: buildComparisonOffers(product),
                onAddOffer: (offer) {
                  addToCart(
                    product: offer.product,
                    variant: offer.variant,
                    distributorId: offer.distributorId,
                    distributorName: offer.distributorName,
                    cart: context.read<PharmaCartProvider>(),
                  );
                },
                onSwitchDistributor: (offer) {
                  final cart = context.read<PharmaCartProvider>();

                  showDistributorSwitchDialog(
                    cart: cart,
                    newDistId: offer.distributorId,
                    newDistName: offer.distributorName,
                    onSwitched: () {
                      addToCart(
                        product: offer.product,
                        variant: offer.variant,
                        distributorId: offer.distributorId,
                        distributorName: offer.distributorName,
                        cart: cart,
                      );
                    },
                  );
                },
              );
            });
          },
        );
      },
      transitionBuilder: (_, anim, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  List<ProductDistributorOffer> buildComparisonOffersFromMerged(
    SkuProduct sample,
    List<MapEntry<dynamic, SkuProduct>> offers,
  ) {
    final result = <ProductDistributorOffer>[];
    final seen = <String>{};

    for (final entry in offers) {
      final dist = entry.key;
      final product = entry.value;

      final variants = _sortedVariants(product);
      final variant = variants.isNotEmpty
          ? variants.first
          : _fallbackVariantFor(product);

      final ptr = variant.sellPriceToRetailer;
      final mrp = variant.maxRetailPrice;
      final stock = variant.availableStock;
      final allowBeyond = variant.allowOrderBeyondStock;
      final discountPct = (mrp > 0 && mrp > ptr)
          ? ((mrp - ptr) / mrp) * 100
          : 0.0;

      final key = '${dist.id}_${variant.id}';
      if (seen.contains(key)) continue;
      seen.add(key);

      result.add(
        ProductDistributorOffer(
          distributorId: dist.id as String,
          distributorName: dist.companyName as String,
          product: product,
          variant: variant,
          ptr: ptr,
          mrp: mrp,
          stock: stock,
          allowBeyond: allowBeyond,
          discountPct: discountPct,
          deliveryLabel: formatDeliveryLabel(
            expectedDelivery: dist.pharmaExpectedDelivery ?? 'same_day',
            sameDayCutoff: dist.pharmaSameDayOrderCutoff,
          ),
          minimumOrderValue:
              (dist.pharmaMinimumOrderValue as num?)?.toDouble() ?? 0,
        ),
      );
    }

    result.sort((a, b) {
      final aUsable = a.stock > 0 || a.allowBeyond;
      final bUsable = b.stock > 0 || b.allowBeyond;
      if (aUsable != bUsable) return aUsable ? -1 : 1;

      final byPrice = a.ptr.compareTo(b.ptr);
      if (byPrice != 0) return byPrice;

      return a.distributorName.compareTo(b.distributorName);
    });

    return result;
  }

  List<ProductDistributorOffer> buildComparisonOffersForProduct(
    SkuProduct target,
  ) {
    final result = <ProductDistributorOffer>[];
    final seen = <String>{};

    for (final dist in distributors) {
      final products = List<SkuProduct>.from(dist.products ?? []);

      for (final product in products) {
        final sameProduct = product.id == target.id;
        final sameSku =
            (product.skuCode ?? '').trim().toLowerCase() ==
            (target.skuCode ?? '').trim().toLowerCase();

        if (!sameProduct && !sameSku) continue;

        final variants = _sortedVariants(product);
        final variant = variants.isNotEmpty
            ? variants.first
            : _fallbackVariantFor(product);

        final key = '${dist.id}_${variant.id}';
        if (seen.contains(key)) continue;
        seen.add(key);

        final ptr = variant.sellPriceToRetailer;
        final mrp = variant.maxRetailPrice;
        final stock = variant.availableStock;
        final allowBeyond = variant.allowOrderBeyondStock;
        final discountPct = (mrp > 0 && mrp > ptr)
            ? ((mrp - ptr) / mrp) * 100
            : 0.0;

        result.add(
          ProductDistributorOffer(
            // ignore: unnecessary_cast
            distributorId: dist.id as String,
            // ignore: unnecessary_cast
            distributorName: dist.companyName as String,
            product: product,
            variant: variant,
            ptr: ptr,
            mrp: mrp,
            stock: stock,
            allowBeyond: allowBeyond,
            discountPct: discountPct,
            deliveryLabel: formatDeliveryLabel(
              expectedDelivery: dist.pharmaExpectedDelivery ?? 'same_day',
              sameDayCutoff: dist.pharmaSameDayOrderCutoff,
            ),
            minimumOrderValue:
                (dist.pharmaMinimumOrderValue as num?)?.toDouble() ?? 0,
          ),
        );
      }
    }

    result.sort((a, b) {
      final aUsable = a.stock > 0 || a.allowBeyond;
      final bUsable = b.stock > 0 || b.allowBeyond;
      if (aUsable != bUsable) return aUsable ? -1 : 1;

      final byPrice = a.ptr.compareTo(b.ptr);
      if (byPrice != 0) return byPrice;

      return a.distributorName.compareTo(b.distributorName);
    });

    return result;
  }

  Widget buildSkuCard(SkuProduct product, PharmaCartProvider cart) {
    final variants = _sortedVariants(product);
    final displayVariant = variants.first;
    final hasMultipleVariants = product.variants.length > 1;

    final sellPrice = displayVariant.sellPriceToRetailer;
    final mrp = displayVariant.maxRetailPrice.toDouble();
    final stock = displayVariant.availableStock;
    final allowBeyond = displayVariant.allowOrderBeyondStock;
    final outOfStock = stock <= 0;
    final variantId = displayVariant.id;
    final primaryUnit = displayVariant.primaryUnit;
    final qtyInCart = cart.qtyForVariant(variantId, primaryUnit);
    final isInCart = cart.isVariantInCart(variantId, primaryUnit);
    final distributorId = selectedDistributorId ?? '';
    final distributor = selectedDist;
    final lockedElsewhere =
        cart.isNotEmpty &&
        cart.lockedDistributorId != null &&
        cart.lockedDistributorId != distributorId;
    final hasDiscount = mrp > 0 && mrp > sellPrice;
    final discountPct = hasDiscount ? ((mrp - sellPrice) / mrp) * 100 : 0.0;

    const kGreen = Color(0xFF0E8A4C);
    const kGreenSoft = Color(0xFFE4F5EC);
    const kAmber = Color(0xFFB36A00);
    const kAmberSoft = Color(0xFFFFF4E0);
    const kRed = Color(0xFFB3261E);
    const kRedSoft = Color(0xFFFCE8E6);
    const kBlueChip = Color(0xFFE4EDF7);
    const kTeal = Color(0xFF0FA3A3);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isInCart ? const Color(0xFFBBF7D0) : borderColor,
          width: isInCart ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0B4F8A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: headingColor,
                      height: 1.3,
                    ),
                  ),
                ),
                if (product.category != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: kBlueChip,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      product.category!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: primaryBlue,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              product.skuCode ?? '-',
              style: const TextStyle(fontSize: 11, color: mutedColor),
            ),
            if (hasMultipleVariants) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kAmberSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${product.variants.length} variants available',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kAmber,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  sellPrice.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: primaryBlue,
                  ),
                ),
                if (hasDiscount) ...[
                  const SizedBox(width: 6),
                  Text(
                    mrp.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 11,
                      color: mutedColor,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: kGreenSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${discountPct.toStringAsFixed(0)}% Off',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: kGreen,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: outOfStock
                        ? (allowBeyond ? kAmberSoft : kRedSoft)
                        : kGreenSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    outOfStock
                        ? (allowBeyond ? 'On Order' : 'Out of Stock')
                        : '${stock.toInt()} $primaryUnit',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: outOfStock
                          ? (allowBeyond ? kAmber : kRed)
                          : kGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => showProductInfoPopup(
                      product,
                      distributorId: distributorId,
                      distributorName: distributor?.companyName ?? '',
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: primaryBlue, width: 1.4),
                      backgroundColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: primaryBlue,
                        ),
                        SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'View Profile',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final offers = buildComparisonOffersForProduct(product);
                      if (offers.isEmpty) return;

                      showDistributorComparisonDialog(
                        context: context,
                        title: product.name,
                        offers: offers,
                        onAddOffer: (offer) {
                          addToCart(
                            product: offer.product,
                            variant: offer.variant,
                            distributorId: offer.distributorId,
                            distributorName: offer.distributorName,
                            cart: context.read<PharmaCartProvider>(),
                          );
                        },
                        onSwitchDistributor: (offer) {
                          final cart = context.read<PharmaCartProvider>();

                          showDistributorSwitchDialog(
                            cart: cart,
                            newDistId: offer.distributorId,
                            newDistName: offer.distributorName,
                            onSwitched: () {
                              addToCart(
                                product: offer.product,
                                variant: offer.variant,
                                distributorId: offer.distributorId,
                                distributorName: offer.distributorName,
                                cart: cart,
                              );
                            },
                          );
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTeal,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.compare_arrows_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Compare',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (lockedElsewhere)
              buildLockedBanner(cart)
            else if (isInCart && !hasMultipleVariants)
              buildQtyStepper(
                variantId: variantId,
                unit: primaryUnit,
                qty: qtyInCart,
                max: stock.toInt(),
                allowBeyond: allowBeyond,
                cart: cart,
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: outOfStock && !allowBeyond && !hasMultipleVariants
                      ? null
                      : () => handleProductTap(
                          product: product,
                          distributorId: distributorId,
                          distributorName: distributor?.companyName ?? '',
                          cart: cart,
                        ),
                  icon: Icon(
                    hasMultipleVariants
                        ? Icons.tune_rounded
                        : Icons.add_shopping_cart_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    hasMultipleVariants ? 'Choose Variant' : 'Add to Cart',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    disabledBackgroundColor: borderColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _syncSelectedDistributorWithCart(PharmaCartProvider cart) {
    final lockedId = cart.lockedDistributorId;
    if (viewMode != PharmaOrderViewMode.byDistributor) return;
    if (lockedId == null || lockedId.isEmpty) return;
    if (selectedDistributorId == lockedId) return;

    final exists = distributors.any((d) => d.id == lockedId);
    if (!exists) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (selectedDistributorId == lockedId) return;
      selectDistributor(lockedId);
    });
  }

  Widget buildQtyStepper({
    required String variantId,
    required String unit,
    required int qty,
    required int max,
    required bool allowBeyond,
    required PharmaCartProvider cart,
    bool compact = false,
  }) {
    final btnSize = compact ? 28.0 : 32.0;
    final fontSize = compact ? 13.0 : 14.0;

    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        GestureDetector(
          onTap: () {
            if (qty <= 1) {
              cart.removeItem(variantId, unit);
            } else {
              cart.updateQuantity(variantId, unit, qty - 1);
            }
          },
          child: Container(
            width: btnSize,
            height: btnSize,
            decoration: BoxDecoration(
              color: qty <= 1 ? redSoft : pageBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: qty <= 1 ? red : borderColor),
            ),
            child: Icon(
              qty <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
              size: 16,
              color: qty <= 1 ? red : headingColor,
            ),
          ),
        ),
        SizedBox(
          width: compact ? 36 : 44,
          child: Center(
            child: Text(
              '$qty',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: headingColor,
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            if (!allowBeyond && max > 0 && qty >= max) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Maximum stock reached'),
                  backgroundColor: amber,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                ),
              );
              return;
            }
            cart.updateQuantity(variantId, unit, qty + 1);
          },
          child: Container(
            width: btnSize,
            height: btnSize,
            decoration: BoxDecoration(
              color: primaryBlueSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_rounded, size: 16, color: primaryBlue),
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 8),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 12,
              color: mutedColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget buildCartBar(PharmaCartProvider cart) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: primaryBlue,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => showCartSheet(cart),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${cart.itemCount}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'View Cart',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  cart.subtotal.toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void addToCart({
    required SkuProduct product,
    required SkuVariant? variant,
    required String distributorId,
    required String distributorName,
    required PharmaCartProvider cart,
  }) {
    final resolvedVariant = variant ?? _fallbackVariantFor(product);
    final info = product.info ?? <String, dynamic>{};

    final item = PharmaCartItem(
      skuId: product.id,
      skuName: product.name,
      skuCode: product.skuCode ?? '-',
      imagePath: product.imagePath,
      category: product.category,
      distributorId: distributorId,
      distributorName: distributorName,

      mrp: resolvedVariant.maxRetailPrice,
      ptr: resolvedVariant.sellPriceToRetailer,
      minSellPrice: (info['min_sell_price'] as num?)?.toDouble(),
      pricePerUnit: resolvedVariant.sellPriceToRetailer,

      variantId: resolvedVariant.id,
      variantName: resolvedVariant.variantName,
      variantSkuCode: resolvedVariant.variantSkuCode,

      unit: resolvedVariant.primaryUnit,
      primaryUnit: resolvedVariant.primaryUnit,
      availableStock: resolvedVariant.availableStock,

      allowOrderBeyondStock: resolvedVariant.allowOrderBeyondStock,
      allowSellingInAlternativeUnit:
          resolvedVariant.allowSellingInAlternativeUnit,
      alternativeUnits: resolvedVariant.alternativeUnits
          .map((u) => u.toJson())
          .toList(),

      genericName: info['generic_name']?.toString(),
      dosageForm: info['dosage_form']?.toString(),
      packLabel: info['pack_label']?.toString(),
      batchNumber: info['batch_number']?.toString(),
      expiryDate: info['expiry_date']?.toString(),
      manufacturerName: info['manufacturer_name']?.toString(),
      marketerName: info['marketer_name']?.toString(),
      productCategory: info['product_category']?.toString(),
      medicineCode: info['medicine_code']?.toString(),
      brandName: info['brand_name']?.toString(),
      extraInfo: info,

      quantity: 1,
    );

    final added = cart.addItem(item);
    if (!added) {
      showDistributorSwitchDialog(
        cart: cart,
        newDistId: distributorId,
        newDistName: distributorName,
        onSwitched: () {
          cart.addItem(item);
        },
      );
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${product.name} (${resolvedVariant.variantName}) added from $distributorName',
          ),
          backgroundColor: primaryBlue,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
  }

  void showDistributorSwitchDialog({
    required PharmaCartProvider cart,
    required String newDistId,
    required String newDistName,
    VoidCallback? onSwitched,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: amberSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: amber,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Switch Distributor?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: headingColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your cart has items from ${cart.lockedDistributorName}. Switching to $newDistName will clear your current cart.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: mutedColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: headingColor,
                        minimumSize: const Size.fromHeight(46),
                        side: const BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        cart.clear();
                        selectDistributor(newDistId);
                        onSwitched?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: amber,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Switch & Add',
                        style: TextStyle(fontWeight: FontWeight.w700),
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

  void showCartSheet(PharmaCartProvider cart) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PharmaCartSheet(cart: cart),
    );
  }

  void showDistributorLockInfo(String lockedName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cart is locked to $lockedName'),
        backgroundColor: amber,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: primaryBlue),
          const SizedBox(height: 16),
          Text(
            pincode != null
                ? 'Finding distributors for $pincode...'
                : 'Loading ...',
            style: const TextStyle(fontSize: 14, color: mutedColor),
          ),
        ],
      ),
    );
  }

  Widget buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 54, color: borderColor),
            const SizedBox(height: 16),
            const Text(
              'Could not load distributors',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: headingColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loadError ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: mutedColor),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: init,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryBlue,
                side: const BorderSide(color: primaryBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildNoDistributors() {
    final scope = [
      if (pincode != null && pincode!.isNotEmpty) 'PIN $pincode',
      if (city != null && city!.isNotEmpty) city,
      if (state != null && state!.isNotEmpty) state,
    ].join(', ');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: primaryBlueSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.store_mall_directory_outlined,
                size: 36,
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Distributors Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: headingColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              scope.isNotEmpty
                  ? 'We could not find any distributors serving $scope.'
                  : 'We could not find any distributors serving your location.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: mutedColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: init,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryBlue,
                side: const BorderSide(color: primaryBlue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: pageBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 30,
                color: mutedColor,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No products found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: headingColor,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try adjusting your search or category filter.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: mutedColor, height: 1.5),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () {
                searchCtrl.clear();
                setState(() {
                  selectedCategory = 'All';
                  if (viewMode == PharmaOrderViewMode.byDistributor) {
                    filteredProducts = List<SkuProduct>.from(allProducts);
                  } else {
                    buildMergedMap();
                  }
                });
                applyFilter();
              },
              icon: const Icon(Icons.clear_rounded, size: 16),
              label: const Text(
                'Clear filters',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(foregroundColor: primaryBlue),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildLockedBanner(PharmaCartProvider cart) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: amberSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Text(
        'Cart locked to ${cart.lockedDistributorName}. Clear cart to order from another distributor.',
        style: const TextStyle(
          fontSize: 11,
          color: amber,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }

  Widget placeholderImage() {
    return Container(
      color: pageBg,
      child: const Center(
        child: Icon(Icons.medication_outlined, size: 28, color: borderColor),
      ),
    );
  }

  String _norm(String? value) {
    return (value ?? '').trim().toLowerCase();
  }

  String _cleanPackSuffix(String input) {
    var s = _norm(input);

    final stripTokens = [
      ' tabs',
      ' tab',
      ' tablets',
      ' tablet',
      ' caps',
      ' cap',
      ' capsules',
      ' capsule',
      ' softgel',
      ' softgels',
      ' syrup',
      ' suspension',
      ' injection',
      ' inj',
      ' vial',
      ' ampoule',
      ' bottle',
      ' pack',
      ' strips',
      ' strip',
    ];

    for (final token in stripTokens) {
      s = s.replaceAll(token, '');
    }

    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  String mergedProductKey(SkuProduct product) {
    final info = product.info ?? <String, dynamic>{};

    final repoId = _norm(info['medicine_repository_id']?.toString());
    if (repoId.isNotEmpty) return 'repo:$repoId';

    final medCode = _norm(info['medicine_code']?.toString());
    if (medCode.isNotEmpty) return 'med:$medCode';

    final generic = _cleanPackSuffix(info['generic_name']?.toString() ?? '');
    final dosage = _norm(info['dosage_form']?.toString());
    final name = _cleanPackSuffix(product.name);
    final sku = _norm(product.skuCode);

    if (generic.isNotEmpty && dosage.isNotEmpty) {
      return 'generic:$generic|dosage:$dosage';
    }

    if (name.isNotEmpty && dosage.isNotEmpty) {
      return 'name:$name|dosage:$dosage';
    }

    if (name.isNotEmpty) return 'name:$name';
    if (sku.isNotEmpty) return 'sku:$sku';

    return 'fallback:${product.id}';
  }

  List<MapEntry<String, List<MapEntry<dynamic, SkuProduct>>>>
  _buildMergedEntries() {
    final Map<String, List<MapEntry<dynamic, SkuProduct>>> grouped = {};

    for (final dist in distributors) {
      final products = List<SkuProduct>.from(dist.products);

      for (final product in products) {
        final key = mergedProductKey(product);
        grouped.putIfAbsent(key, () => []);
        grouped[key]!.add(MapEntry(dist, product));
      }
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final an = a.value.first.value.name.toLowerCase();
        final bn = b.value.first.value.name.toLowerCase();
        return an.compareTo(bn);
      });

    return entries;
  }

  void buildMergedMap() {
    mergedFiltered = _buildMergedEntries();
  }

  bool _matchesSearch(SkuProduct product, String q) {
    if (q.isEmpty) return true;

    final info = product.info ?? <String, dynamic>{};

    final fields = <String>[
      product.name,
      product.skuCode ?? '',
      product.category ?? '',
      info['generic_name']?.toString() ?? '',
      info['medicine_code']?.toString() ?? '',
      info['dosage_form']?.toString() ?? '',
      info['manufacturer_name']?.toString() ?? '',
      info['marketer_name']?.toString() ?? '',
    ].map((e) => e.toLowerCase()).toList();

    return fields.any((f) => f.contains(q));
  }

  SkuProduct _pickDisplayProduct(List<MapEntry<dynamic, SkuProduct>> offers) {
    final sorted = List<MapEntry<dynamic, SkuProduct>>.from(offers)
      ..sort((a, b) {
        final av = _sortedVariants(a.value).first.sellPriceToRetailer;
        final bv = _sortedVariants(b.value).first.sellPriceToRetailer;
        return av.compareTo(bv);
      });

    return sorted.first.value;
  }

  void applyFilter() {
    final q = searchCtrl.text.toLowerCase().trim();

    if (viewMode == PharmaOrderViewMode.byDistributor) {
      final result = allProducts.where((p) {
        final matchSearch = _matchesSearch(p, q);

        final cat = (p.category == null || p.category!.trim().isEmpty)
            ? 'Uncategorised'
            : p.category!.trim();

        final matchCategory =
            selectedCategory == 'All' || cat == selectedCategory;

        return matchSearch && matchCategory;
      }).toList();

      final seen = <String>{};
      final suggestions = q.isEmpty
          ? <SkuProduct>[]
          : result
                .where((p) {
                  final key = mergedProductKey(p);
                  if (seen.contains(key)) return false;
                  seen.add(key);
                  return true;
                })
                .take(6)
                .toList();

      setState(() {
        filteredProducts = result;
        searchSuggestions = suggestions;
        showSuggestions = q.isNotEmpty && suggestions.isNotEmpty;
      });
      return;
    }

    final baseEntries = _buildMergedEntries();
    final List<MapEntry<String, List<MapEntry<dynamic, SkuProduct>>>> merged =
        [];

    for (final entry in baseEntries) {
      final allOffers = entry.value;

      final visibleOffers = allOffers.where((offer) {
        final product = offer.value;
        final matchSearch = _matchesSearch(product, q);

        final cat =
            (product.category == null || product.category!.trim().isEmpty)
            ? 'Uncategorised'
            : product.category!.trim();

        final matchCategory =
            selectedCategory == 'All' || cat == selectedCategory;

        return matchSearch && matchCategory;
      }).toList();

      if (visibleOffers.isNotEmpty) {
        merged.add(MapEntry(entry.key, allOffers));
      }
    }

    final seenSuggestionKeys = <String>{};
    final suggestions = q.isEmpty
        ? <SkuProduct>[]
        : merged
              .map((e) => _pickDisplayProduct(e.value))
              .where((p) {
                final key = mergedProductKey(p);
                if (seenSuggestionKeys.contains(key)) return false;
                seenSuggestionKeys.add(key);
                return true;
              })
              .take(6)
              .toList();

    setState(() {
      mergedFiltered = merged;
      searchSuggestions = suggestions;
      showSuggestions = q.isNotEmpty && suggestions.isNotEmpty;
    });
  }

  Widget buildMergedSkuCard(
    SkuProduct sample,
    List<MapEntry<dynamic, SkuProduct>> offers,
    PharmaCartProvider cart,
  ) {
    final Map<String, SkuVariant> uniqueVariants = {};
    final distributorIds = <String>{};
    double? minPrice;
    // ignore: unused_local_variable
    final firstDist = offers.isNotEmpty
        ? offers.first.key as PharmaDistributor
        : null;

    for (final offer in offers) {
      final dist = offer.key as PharmaDistributor;
      distributorIds.add(dist.id);

      final product = offer.value;
      final variants = _sortedVariants(product);

      for (final variant in variants) {
        final variantKey =
            '${variant.variantName}|${variant.primaryUnit}|${variant.variantSkuCode}'
                .toLowerCase();

        uniqueVariants.putIfAbsent(variantKey, () => variant);

        if (minPrice == null || variant.sellPriceToRetailer < minPrice) {
          minPrice = variant.sellPriceToRetailer;
        }
      }
    }

    final variantCount = uniqueVariants.length;
    final distributorCount = distributorIds.length;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () =>
          showMergedVariantPicker(sample: sample, offers: offers, cart: cart),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A0B4F8A),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: sample.name,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: headingColor,
                            ),
                          ),
                          TextSpan(
                            text: sample.skuCode?.trim().isNotEmpty == true
                                ? ' ( ${sample.skuCode} )'
                                : '',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  /*
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: firstDist == null
                        ? null
                        : () {
                            showProductInfoPopup(
                              sample,
                              distributorId: firstDist.id,
                              distributorName: firstDist.companyName,
                            );
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: primaryBlueSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 13,
                            color: primaryBlue,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'View Profile',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ), */
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: mutedColor,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if ((sample.category ?? '').trim().isNotEmpty)
                    _tinyChip(
                      sample.category!.trim(),
                      primaryBlueSoft,
                      primaryBlue,
                    ),
                  _tinyChip(
                    '$distributorCount distributor${distributorCount > 1 ? 's' : ''}',
                    tealSoft,
                    teal,
                  ),
                  if (variantCount > 1)
                    _tinyChip('$variantCount variants', amberSoft, amber),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    minPrice == null
                        ? '-'
                        : 'From ₹${minPrice!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: primaryBlue,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Tap to view distributors',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: mutedColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        final first = offers.first;
                        showProductInfoPopup(
                          sample,
                          distributorId: first.key.id as String,
                          distributorName: first.key.companyName as String,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: primaryBlue, width: 1.4),
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: primaryBlue,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'View Profile',
                            style: TextStyle(
                              color: primaryBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        showDistributorComparisonDialog(
                          context: context,
                          title: sample.name,
                          offers: buildComparisonOffersFromMerged(
                            sample,
                            offers,
                          ),
                          onAddOffer: (offer) {
                            addToCart(
                              product: offer.product,
                              variant: offer.variant,
                              distributorId: offer.distributorId,
                              distributorName: offer.distributorName,
                              cart: context.read<PharmaCartProvider>(),
                            );
                          },
                          onSwitchDistributor: (offer) {
                            final cart = context.read<PharmaCartProvider>();

                            showDistributorSwitchDialog(
                              cart: cart,
                              newDistId: offer.distributorId,
                              newDistName: offer.distributorName,
                              onSwitched: () {
                                addToCart(
                                  product: offer.product,
                                  variant: offer.variant,
                                  distributorId: offer.distributorId,
                                  distributorName: offer.distributorName,
                                  cart: cart,
                                );
                              },
                            );
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kTeal,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.compare_arrows_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Compare',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
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

  List<MapEntry<String, List<MapEntry<dynamic, SkuProduct>>>>
  buildMergedEntries() {
    final Map<String, List<MapEntry<dynamic, SkuProduct>>> grouped = {};

    for (final dist in distributors) {
      final products = List<SkuProduct>.from(dist.products);
      for (final product in products) {
        final key = mergedProductKey(product);
        grouped.putIfAbsent(key, () => []);
        grouped[key]!.add(MapEntry(dist, product));
      }
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final an = a.value.first.value.name.toLowerCase();
        final bn = b.value.first.value.name.toLowerCase();
        return an.compareTo(bn);
      });

    return entries;
  }

  Widget _tinyChip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

  String normalizeText(String? value) {
    return (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool isSameMedicine(SkuProduct a, SkuProduct b) {
    if (a.id.isNotEmpty && b.id.isNotEmpty && a.id == b.id) return true;

    final aSku = normalizeText(a.skuCode);
    final bSku = normalizeText(b.skuCode);
    if (aSku.isNotEmpty && bSku.isNotEmpty && aSku == bSku) return true;

    final aName = normalizeText(a.name);
    final bName = normalizeText(b.name);
    final aUnit = normalizeText(a.primaryUnit);
    final bUnit = normalizeText(b.primaryUnit);

    return aName == bName && aUnit == bUnit;
  }

  void showMergedVariantPicker({
    required SkuProduct sample,
    required List<MapEntry<dynamic, SkuProduct>> offers,
    required PharmaCartProvider cart,
  }) {
    final Map<String, List<_VariantOfferBundle>> grouped = {};

    for (final offer in offers) {
      final dist = offer.key as PharmaDistributor;
      final product = offer.value;
      final variants = _sortedVariants(product);

      for (final variant in variants) {
        final groupKey =
            '${variant.variantName}|${variant.primaryUnit}|${variant.variantSkuCode}';
        grouped.putIfAbsent(groupKey, () => []);
        grouped[groupKey]!.add(
          _VariantOfferBundle(
            distributor: dist,
            product: product,
            variant: variant,
          ),
        );
      }
    }

    final variantGroups = grouped.values.toList()
      ..sort((a, b) {
        final av = a.first.variant.sellPriceToRetailer;
        final bv = b.first.variant.sellPriceToRetailer;
        return av.compareTo(bv);
      });

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Distributor offers',
      barrierColor: Colors.black.withOpacity(0.50),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return ChangeNotifierProvider.value(
          value: cart,
          child: Consumer<PharmaCartProvider>(
            builder: (ctx2, liveCart, _) {
              return Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: MediaQuery.of(ctx2).size.width * 0.92,
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx2).size.height * 0.84,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FBFF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(18),
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
                                      sample.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: headingColor,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${offers.length} offers • ${variantGroups.length} variant group${variantGroups.length > 1 ? 's' : ''}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: mutedColor,
                                        fontWeight: FontWeight.w600,
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
                          child: variantGroups.isEmpty
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
                                      Text(
                                        'No distributor offers available for this medicine',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w600,
                                        ),
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
                                  itemCount: variantGroups.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (_, i) {
                                    final bundles = variantGroups[i];
                                    final variant = bundles.first.variant;

                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFEEEEF5),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.03,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: primaryBlue,
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
                                              Text(
                                                variant.variantSkuCode,
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  color: mutedColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          ...bundles.map((bundle) {
                                            final dist =
                                                bundle.distributor
                                                    as PharmaDistributor;
                                            final product = bundle.product;
                                            final v = bundle.variant;

                                            final variantExistsInCart = liveCart
                                                .isVariantInCart(
                                                  v.id,
                                                  v.primaryUnit,
                                                );

                                            final qtyInCart = selectedQtyFor(
                                              liveCart,
                                              v.id,
                                              v.primaryUnit,
                                            );

                                            final isThisDistributorSelected =
                                                variantExistsInCart &&
                                                liveCart.lockedDistributorId ==
                                                    dist.id;

                                            final isLockedElsewhere =
                                                liveCart.isNotEmpty &&
                                                liveCart.lockedDistributorId !=
                                                    null &&
                                                liveCart.lockedDistributorId !=
                                                    dist.id;

                                            final outOfStock =
                                                v.availableStock <= 0;

                                            final hasDiscount =
                                                v.maxRetailPrice > 0 &&
                                                v.maxRetailPrice >
                                                    v.sellPriceToRetailer;

                                            final discountPercent = hasDiscount
                                                ? ((v.maxRetailPrice -
                                                              v.sellPriceToRetailer) /
                                                          v.maxRetailPrice) *
                                                      100
                                                : 0.0;

                                            final tileBg =
                                                isThisDistributorSelected
                                                ? const Color(0xFFF0FFF4)
                                                : isLockedElsewhere
                                                ? const Color(0xFFFFFBF5)
                                                : const Color(0xFFF8FBFF);

                                            final tileBorder =
                                                isThisDistributorSelected
                                                ? const Color(0xFFB7E4C7)
                                                : isLockedElsewhere
                                                ? const Color(0xFFF3D19C)
                                                : const Color(0xFFDDE3FF);

                                            final buttonColor =
                                                isThisDistributorSelected
                                                ? const Color(0xFF2E7D32)
                                                : isLockedElsewhere
                                                ? const Color(0xFFEF8F21)
                                                : primaryBlue;

                                            return Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: tileBg,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: tileBorder,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              dist.companyName,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: const TextStyle(
                                                                fontSize: 13.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                color:
                                                                    headingColor,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 4,
                                                            ),
                                                            Text(
                                                              formatDeliveryLabel(
                                                                expectedDelivery:
                                                                    dist.pharmaExpectedDelivery,
                                                                sameDayCutoff: dist
                                                                    .pharmaSameDayOrderCutoff,
                                                              ),
                                                              style: const TextStyle(
                                                                fontSize: 11,
                                                                color:
                                                                    mutedColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                            if (dist.pharmaMinimumOrderValue >
                                                                0) ...[
                                                              const SizedBox(
                                                                height: 4,
                                                              ),
                                                              Text(
                                                                'Minimum order ₹${dist.pharmaMinimumOrderValue.toStringAsFixed(0)}',
                                                                style: const TextStyle(
                                                                  fontSize: 11,
                                                                  color:
                                                                      mutedColor,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ],
                                                            const SizedBox(
                                                              height: 4,
                                                            ),
                                                            if (isThisDistributorSelected)
                                                              Row(
                                                                children: [
                                                                  const Icon(
                                                                    Icons
                                                                        .check_circle,
                                                                    size: 13,
                                                                    color: Color(
                                                                      0xFF2E7D32,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 4,
                                                                  ),
                                                                  Expanded(
                                                                    child: Text(
                                                                      qtyInCart >
                                                                              0
                                                                          ? 'Added ${qtyInCart.toString()} ${v.primaryUnit}'
                                                                          : 'Added from this distributor',
                                                                      style: const TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        color: Color(
                                                                          0xFF2E7D32,
                                                                        ),
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              )
                                                            else if (isLockedElsewhere)
                                                              const Text(
                                                                'Select this distributor to replace current cart',
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  color: Color(
                                                                    0xFFB26A00,
                                                                  ),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              )
                                                            else
                                                              const Text(
                                                                'Tap to add from this distributor',
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  color:
                                                                      mutedColor,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: outOfStock
                                                              ? v.allowOrderBeyondStock
                                                                    ? amberSoft
                                                                    : redSoft
                                                              : greenSoft,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                7,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          outOfStock
                                                              ? (v.allowOrderBeyondStock
                                                                    ? 'On Order'
                                                                    : 'Out of Stock')
                                                              : 'In stock ${v.availableStock.toInt()}',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: outOfStock
                                                                ? (v.allowOrderBeyondStock
                                                                      ? amber
                                                                      : red)
                                                                : green,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 6,
                                                    crossAxisAlignment:
                                                        WrapCrossAlignment
                                                            .center,
                                                    children: [
                                                      if (v.maxRetailPrice > 0)
                                                        Text(
                                                          'MRP ₹${v.maxRetailPrice.toStringAsFixed(2)}',
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            color: mutedColor,
                                                            decoration:
                                                                TextDecoration
                                                                    .lineThrough,
                                                          ),
                                                        ),
                                                      Text(
                                                        '₹${v.sellPriceToRetailer.toStringAsFixed(2)}',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: primaryBlue,
                                                        ),
                                                      ),
                                                      if (discountPercent > 0)
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: greenSoft,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  6,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            '${discountPercent.toStringAsFixed(0)}% OFF',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: green,
                                                                ),
                                                          ),
                                                        ),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: pageBg,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                          border: Border.all(
                                                            color: borderColor,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          v.primaryUnit,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color:
                                                                    mutedColor,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (isLockedElsewhere) ...[
                                                    const SizedBox(height: 10),
                                                    Container(
                                                      width: double.infinity,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: amberSoft,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        border: Border.all(
                                                          color: const Color(
                                                            0xFFF3D19C,
                                                          ),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        'Current cart is locked to ${liveCart.lockedDistributorName ?? 'another distributor'}. Switch to ${dist.companyName}.',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          height: 1.35,
                                                          color: Color(
                                                            0xFF9A5A00,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  const SizedBox(height: 10),
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child:
                                                        isThisDistributorSelected
                                                        ? buildQtyStepper(
                                                            variantId: v.id,
                                                            unit: v.primaryUnit,
                                                            qty: qtyInCart,
                                                            max: v
                                                                .availableStock
                                                                .toInt(),
                                                            allowBeyond: v
                                                                .allowOrderBeyondStock,
                                                            cart: liveCart,
                                                            compact: false,
                                                          )
                                                        : ElevatedButton.icon(
                                                            onPressed:
                                                                outOfStock &&
                                                                    !v.allowOrderBeyondStock
                                                                ? null
                                                                : () {
                                                                    if (isLockedElsewhere) {
                                                                      showDistributorSwitchDialog(
                                                                        cart:
                                                                            liveCart,
                                                                        newDistId:
                                                                            dist.id,
                                                                        newDistName:
                                                                            dist.companyName,
                                                                        onSwitched: () {
                                                                          Navigator.pop(
                                                                            ctx2,
                                                                          );
                                                                          addToCart(
                                                                            product:
                                                                                product,
                                                                            variant:
                                                                                v,
                                                                            distributorId:
                                                                                dist.id,
                                                                            distributorName:
                                                                                dist.companyName,
                                                                            cart:
                                                                                liveCart,
                                                                          );
                                                                        },
                                                                      );
                                                                      return;
                                                                    }

                                                                    addToCart(
                                                                      product:
                                                                          product,
                                                                      variant:
                                                                          v,
                                                                      distributorId:
                                                                          dist.id,
                                                                      distributorName:
                                                                          dist.companyName,
                                                                      cart:
                                                                          liveCart,
                                                                    );
                                                                  },
                                                            icon: Icon(
                                                              isLockedElsewhere
                                                                  ? Icons
                                                                        .swap_horiz_rounded
                                                                  : Icons
                                                                        .add_shopping_cart_rounded,
                                                              size: 18,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                            label: Text(
                                                              isLockedElsewhere
                                                                  ? 'Select from this distributor'
                                                                  : 'Add to cart',
                                                              style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                            ),
                                                            style: ElevatedButton.styleFrom(
                                                              elevation: 0,
                                                              backgroundColor:
                                                                  buttonColor,
                                                              disabledBackgroundColor:
                                                                  const Color(
                                                                    0xFFCBD5E1,
                                                                  ),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      10,
                                                                    ),
                                                              ),
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        12,
                                                                  ),
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
                                  },
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx2),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text(
                                'Close',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
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
            },
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class PharmaCartSheet extends StatelessWidget {
  final PharmaCartProvider cart;

  const PharmaCartSheet({super.key, required this.cart});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: cart,
      child: Consumer<PharmaCartProvider>(
        builder: (context, cart, _) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Your Cart',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: headingColor,
                          ),
                        ),
                      ),
                      if (cart.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => showClearCartDialog(context, cart),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: red,
                          ),
                          label: const Text(
                            'Clear',
                            style: TextStyle(
                              color: red,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                        ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: mutedColor,
                          size: 20,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: pageBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (cart.lockedDistributorName != null) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.store_outlined,
                          size: 14,
                          color: primaryBlue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'From ${cart.lockedDistributorName}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1, color: borderColor),
                if (cart.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 48,
                          color: borderColor,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Your cart is empty',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: mutedColor,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      shrinkWrap: true,
                      itemCount: cart.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final item = cart.items[i];
                        return CartItemRow(item: item, cart: cart);
                      },
                    ),
                  ),
                if (cart.isNotEmpty) ...[
                  const Divider(height: 1, color: borderColor),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Column(
                      children: [
                        SummaryRow(
                          label: 'Subtotal',
                          value: cart.subtotal.toStringAsFixed(2),
                        ),
                        const SizedBox(height: 8),
                        const Divider(color: borderColor),
                        const SizedBox(height: 6),
                        SummaryRow(
                          label: 'Total',
                          value: cart.subtotal.toStringAsFixed(2),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      14,
                      16,
                      MediaQuery.of(context).padding.bottom + 16,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PharmaPreviewOrderPage(cart: cart),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Proceed to Preview',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
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
              ],
            ),
          );
        },
      ),
    );
  }

  void showClearCartDialog(BuildContext context, PharmaCartProvider cart) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: redSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: red,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Clear Cart?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: headingColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'All items will be removed from your cart. This cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: mutedColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: headingColor,
                        minimumSize: const Size.fromHeight(46),
                        side: const BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        cart.clear();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Clear Cart',
                        style: TextStyle(fontWeight: FontWeight.w700),
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

class CartItemRow extends StatelessWidget {
  final PharmaCartItem item;
  final PharmaCartProvider cart;

  const CartItemRow({super.key, required this.item, required this.cart});

  @override
  Widget build(BuildContext context) {
    final lineTotal = item.totalPrice;
    final max = item.availableStock.toInt();
    final beyond = item.allowOrderBeyondStock;
    final isNearDelete = item.quantity <= 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: primaryBlueSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.medication_liquid_rounded,
                  size: 18,
                  color: primaryBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.skuName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: headingColor,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _metaChip(item.skuCode.isEmpty ? '-' : item.skuCode),
                        _metaChip(item.variantName),
                        _metaChip(item.unit),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: mutedColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lineTotal.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: headingColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: pageBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: item.pricePerUnit.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: primaryBlue,
                          ),
                        ),
                        const TextSpan(
                          text: ' / unit',
                          style: TextStyle(fontSize: 11, color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (item.quantity <= 1) {
                            cart.removeItem(item.variantId, item.unit);
                          } else {
                            cart.updateQuantity(
                              item.variantId,
                              item.unit,
                              item.quantity - 1,
                            );
                          }
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: isNearDelete ? redSoft : pageBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isNearDelete ? red : borderColor,
                            ),
                          ),
                          child: Icon(
                            isNearDelete
                                ? Icons.delete_outline_rounded
                                : Icons.remove_rounded,
                            size: 15,
                            color: isNearDelete ? red : headingColor,
                          ),
                        ),
                      ),
                      Container(
                        constraints: const BoxConstraints(minWidth: 32),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: headingColor,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (!beyond && max > 0 && item.quantity >= max) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Maximum stock reached'),
                                backgroundColor: amber,
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 1),
                              ),
                            );
                            return;
                          }

                          cart.updateQuantity(
                            item.variantId,
                            item.unit,
                            item.quantity + 1,
                          );
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: primaryBlueSoft,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 15,
                            color: primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!beyond && max > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Available stock: $max ${item.unit}',
              style: const TextStyle(
                fontSize: 10.5,
                color: mutedColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (beyond) ...[
            const SizedBox(height: 8),
            const Text(
              'Ordering beyond stock is allowed',
              style: TextStyle(
                fontSize: 10.5,
                color: amber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _metaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: pageBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: mutedColor,
        ),
      ),
    );
  }
}

class SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool muted;
  final bool bold;

  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.muted = false,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = muted ? mutedColor : headingColor;
    final weight = bold ? FontWeight.w800 : FontWeight.w600;
    final size = bold ? 15.0 : 13.0;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: size, fontWeight: weight, color: color),
          ),
        ),
        Text(
          value,
          style: TextStyle(fontSize: size, fontWeight: weight, color: color),
        ),
      ],
    );
  }
}

class _VariantOfferBundle {
  final dynamic distributor;
  final SkuProduct product;
  final SkuVariant variant;

  _VariantOfferBundle({
    required this.distributor,
    required this.product,
    required this.variant,
  });
}
