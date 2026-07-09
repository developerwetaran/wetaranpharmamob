import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wetaran_pharma/core/widgets/app_drawer.dart';
import 'package:wetaran_pharma/features/distributors/presentation/pages/distributors_page.dart';
import 'package:wetaran_pharma/features/expiry/presentation/pages/expiry_date.dart';
import 'package:wetaran_pharma/features/orders/models/pharma_kpi_data.dart';
import 'package:wetaran_pharma/features/orders/presentation/pages/add_order_screen.dart';
import 'package:wetaran_pharma/features/orders/presentation/pages/pharma_orders_page.dart';
import 'package:wetaran_pharma/features/orders/services/pharma_distributor_service.dart';
import 'package:wetaran_pharma/features/orders/services/pharma_kpi_service.dart';
import 'package:wetaran_pharma/features/profile/models/pharma_user_profile.dart';
import 'package:wetaran_pharma/features/profile/presentation/pages/pharma_profile_page.dart';
import 'package:wetaran_pharma/features/profile/services/pharm_profile_service.dart';
import 'package:wetaran_pharma/features/reports/presentation/pages/reports_page.dart';
import 'package:wetaran_pharma/features/rewards/presentation/pages/rewards_page.dart';
import 'package:wetaran_pharma/features/schemes/presentation/pages/schemes_page.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:wetaran_pharma/features/orders/models/pharma_cart_provider.dart';
import 'package:wetaran_pharma/features/orders/presentation/widgets/pharma_cart_sheet.dart';
import 'package:wetaran_pharma/models/sku_model.dart';

const kBlue = Color(0xFF0B4F8A);
const kBlueDk = Color(0xFF083A66);
const kTeal = Color(0xFF0FA3A3);
const kTealSoft = Color(0xFFE2F4F4);
const kBg = Color(0xFFF3F7FA);
const kCard = Colors.white;
const kInk = Color(0xFF13242F);
const kMuted = Color(0xFF63788A);
const kLine = Color(0xFFE3EBF1);
const kAmber = Color(0xFFB36A00);
const kAmberBg = Color(0xFFFFF4E0);
const kGreen = Color(0xFF0E8A4C);
const kGreenBg = Color(0xFFE4F5EC);
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

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;

  late final List<Widget> _pages = [
    _HomePage(onNavigateToPage: _selectPage),
    PharmaOrdersPage(
      onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
    ),
    SchemesPage(onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer()),
    RewardsPage(onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer()),
    ExpiryPage(onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer()),
    ReportsPage(onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer()),
  ];

  void _selectPage(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kBg,
      drawer: AppDrawer(
        currentIndex: _currentIndex,
        onSelectPage: (index) {
          Navigator.pop(context);
          _selectPage(index);
        },
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: kCard,
          border: Border(top: BorderSide(color: kLine, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A083A66),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BottomNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  index: 0,
                  currentIndex: _currentIndex,
                  onTap: () => _selectPage(0),
                ),
                _BottomNavItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  label: 'Orders',
                  index: 1,
                  currentIndex: _currentIndex,
                  onTap: () => _selectPage(1),
                ),
                _BottomNavItem(
                  icon: Icons.local_offer_outlined,
                  activeIcon: Icons.local_offer,
                  label: 'Schemes',
                  index: 2,
                  currentIndex: _currentIndex,
                  onTap: () => _selectPage(2),
                ),
                _BottomNavItem(
                  icon: Icons.star_border_rounded,
                  activeIcon: Icons.star_rounded,
                  label: 'Rewards',
                  index: 3,
                  currentIndex: _currentIndex,
                  onTap: () => _selectPage(3),
                ),
                _BottomNavItem(
                  icon: Icons.schedule_outlined,
                  activeIcon: Icons.schedule_rounded,
                  label: 'Expiry',
                  index: 4,
                  currentIndex: _currentIndex,
                  onTap: () => _selectPage(4),
                ),
                _BottomNavItem(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart_rounded,
                  label: 'Reports',
                  index: 5,
                  currentIndex: _currentIndex,
                  onTap: () => _selectPage(5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//  Bottom nav item
class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              decoration: isActive
                  ? BoxDecoration(
                      color: kTealSoft,
                      borderRadius: BorderRadius.circular(14),
                    )
                  : null,
              child: Icon(
                isActive ? activeIcon : icon,
                size: 20,
                color: isActive ? kTeal : const Color(0xFF8CA0B0),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? kBlue : const Color(0xFF8CA0B0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//  Medicine model / mock repo
class _Med {
  final String name;
  final String salt;
  final String mfr;
  const _Med(this.name, this.salt, this.mfr);
}

//  Home Page
class _HomePage extends StatefulWidget {
  final ValueChanged<int> onNavigateToPage;

  // ignore: unused_element_parameter
  const _HomePage({super.key, required this.onNavigateToPage});

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<_Med> _hits = [];
  _Med? _selected;
  final Set<int> _addedIndex = {};

  PharmaUserProfile? _profile;
  bool _loadingProfile = true;

  PharmaKpiData? _kpiData;
  bool _loadingKpis = true;
  Timer? _searchDebounce;

  bool _searching = false;
  bool _loadingCompare = false;

  List<SkuProduct> _searchResults = [];
  SkuProduct? _selectedProduct;

  List<_CompareOffer> _compareOffers = [];
  Timer? _debounce;

  bool _loadingMedicinePool = true;
  String? _medicineLoadError;

  String? _pincode;
  String? _city;
  String? _state;

  List<PharmaDistributor> _distributors = [];
  List<SkuProduct> _allDistributorProducts = [];

  List<MapEntry<PharmaDistributor, SkuProduct>> _selectedOffers = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _initMedicinePool();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initMedicinePool() async {
    setState(() {
      _loadingMedicinePool = true;
      _medicineLoadError = null;
    });

    try {
      final location = await PharmaDistributorService.loadPharmaUserLocation();

      _pincode = location['pincode'];
      _city = location['city'];
      _state = location['state'];

      final loaded =
          await PharmaDistributorService.loadDistributorsWithProducts(
            pincode: _pincode,
            city: _city,
            state: _state,
          );

      final all = <SkuProduct>[];
      for (final dist in loaded) {
        all.addAll(dist.products);
      }

      if (!mounted) return;
      setState(() {
        _distributors = loaded;
        _allDistributorProducts = all;
        _loadingMedicinePool = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _medicineLoadError = e.toString();
        _loadingMedicinePool = false;
      });
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _loadingProfile = true);

    try {
      final profile = await PharmaProfileService.instance.fetchCurrentProfile();
      if (!mounted) return;

      setState(() {
        _profile = profile;
        _loadingProfile = false;
      });

      if (profile != null) {
        debugPrint('Profile id for KPI: ${profile.id}');
        await _loadKpis(profile.id);
      }
    } catch (e) {
      debugPrint('loadProfile error: $e');
      if (!mounted) return;
      setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadKpis(String pharmaUserId) async {
    setState(() => _loadingKpis = true);

    try {
      debugPrint('Loading KPIs for pharmaUserId: $pharmaUserId');

      final data = await PharmaKpiService.instance.fetchMonthlyKpis(
        pharmaUserId,
      );

      debugPrint(
        'KPI result => pendingCount: ${data.pendingCount}, '
        'pendingAmount: ${data.pendingAmount}, '
        'totalPurchaseThisMonth: ${data.totalPurchaseThisMonth}, '
        'totalPurchaseLastMonth: ${data.totalPurchaseLastMonth}',
      );

      if (!mounted) return;
      setState(() {
        _kpiData = data;
        _loadingKpis = false;
      });
    } catch (e) {
      debugPrint('loadKpis error: $e');
      if (!mounted) return;
      setState(() => _loadingKpis = false);
    }
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();

    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 180), () {
      final grouped = <String, SkuProduct>{};

      for (final p in _allDistributorProducts) {
        final key = _productGroupKey(p);
        grouped.putIfAbsent(key, () => p);
      }

      final matches = grouped.values.where((p) {
        final info = p.info ?? <String, dynamic>{};

        final name = p.name.toLowerCase();
        final sku = (p.skuCode ?? '').toLowerCase();
        final generic = (info['generic_name']?.toString() ?? '').toLowerCase();
        final manufacturer = (info['manufacturer_name']?.toString() ?? '')
            .toLowerCase();

        return name.contains(query) ||
            sku.contains(query) ||
            generic.contains(query) ||
            manufacturer.contains(query);
      }).toList();

      matches.sort((a, b) {
        final ai = a.info ?? <String, dynamic>{};
        final bi = b.info ?? <String, dynamic>{};

        final aName = a.name.toLowerCase();
        final bName = b.name.toLowerCase();
        final aSku = (a.skuCode ?? '').toLowerCase();
        final bSku = (b.skuCode ?? '').toLowerCase();
        final aGeneric = (ai['generic_name']?.toString() ?? '').toLowerCase();
        final bGeneric = (bi['generic_name']?.toString() ?? '').toLowerCase();

        int score(SkuProduct p, String name, String sku, String generic) {
          if (name.startsWith(query)) return 0;
          if (name.contains(query)) return 1;
          if (sku.startsWith(query)) return 2;
          if (sku.contains(query)) return 3;
          if (generic.startsWith(query)) return 4;
          if (generic.contains(query)) return 5;
          return 6;
        }

        final sa = score(a, aName, aSku, aGeneric);
        final sb = score(b, bName, bSku, bGeneric);

        if (sa != sb) return sa.compareTo(sb);
        return aName.compareTo(bName);
      });

      if (!mounted) return;
      setState(() {
        _searchResults = matches;
      });
    });
  }

  void _selectProduct(SkuProduct product) {
    final selectedKey = _productGroupKey(product);
    final offers = <MapEntry<PharmaDistributor, SkuProduct>>[];

    for (final dist in _distributors) {
      for (final p in dist.products) {
        if (_productGroupKey(p) == selectedKey) {
          offers.add(MapEntry(dist, p));
        }
      }
    }

    offers.sort((a, b) {
      final av = _sortedVariants(a.value).first.sellPriceToRetailer;
      final bv = _sortedVariants(b.value).first.sellPriceToRetailer;
      return av.compareTo(bv);
    });

    setState(() {
      _selectedProduct = product;
      _selectedOffers = offers;
      _searchResults = [];
      _searchCtrl.text = product.name;
    });
  }

  List<SkuVariant> _sortedVariants(SkuProduct product) {
    final variants = product.variants.isNotEmpty
        ? List<SkuVariant>.from(product.variants)
        : [_fallbackVariantFor(product)];

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

  void _addToCart({
    required SkuProduct product,
    SkuVariant? variant,
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
      _showDistributorSwitchDialog(
        cart: cart,
        newDistId: distributorId,
        newDistName: distributorName,
      );
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${product.name} · ${resolvedVariant.variantName} added from $distributorName',
          ),
          backgroundColor: kBlue,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
  }

  void _handleProductTap({
    required SkuProduct product,
    required String distributorId,
    required String distributorName,
    required PharmaCartProvider cart,
  }) {
    final variants = _sortedVariants(product);

    if (variants.length == 1) {
      _addToCart(
        product: product,
        variant: variants.first,
        distributorId: distributorId,
        distributorName: distributorName,
        cart: cart,
      );
      return;
    }

    _showVariantPicker(
      product: product,
      distributorId: distributorId,
      distributorName: distributorName,
      cart: cart,
    );
  }

  void _showDistributorSwitchDialog({
    required PharmaCartProvider cart,
    required String newDistId,
    required String newDistName,
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
                  color: kAmberBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: kAmber,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Switch Distributor?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your cart has items from ${cart.lockedDistributorName}. Switching to $newDistName will clear your current cart.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: kMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
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
                        backgroundColor: kAmber,
                        elevation: 0,
                      ),
                      child: const Text(
                        'Clear Cart',
                        style: TextStyle(color: Colors.white),
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

  void _showVariantPicker({
    required SkuProduct product,
    required String distributorId,
    required String distributorName,
    required PharmaCartProvider cart,
  }) {
    final variants = _sortedVariants(product);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${variants.length} variants available',
                  style: const TextStyle(fontSize: 11, color: kMuted),
                ),
                const SizedBox(height: 14),
                ...variants.map((variant) {
                  final outOfStock = variant.availableStock <= 0;
                  final allowBeyond = variant.allowOrderBeyondStock;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kLine),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                variant.variantName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: kInk,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${variant.sellPriceToRetailer.toStringAsFixed(2)} · ${variant.availableStock.toInt()} ${variant.primaryUnit}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: kMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: outOfStock && !allowBeyond
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  _addToCart(
                                    product: product,
                                    variant: variant,
                                    distributorId: distributorId,
                                    distributorName: distributorName,
                                    cart: cart,
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kTeal,
                            elevation: 0,
                          ),
                          child: const Text(
                            'Add',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _closeCompare() {
    setState(() {
      _selectedProduct = null;
      _compareOffers = [];
      _searchCtrl.clear();
      _searchResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final userEmail = user?.email ?? '';

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: kTeal,
        onRefresh: _loadProfile,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildHero(context, userEmail),
            _buildSearch(),
            if (_selectedProduct != null) _buildComparePanel(),
            const SizedBox(height: 6),
            _buildKpis(),
            _buildFeatureGrid(context),
            _buildSchemes(),
            _buildExpiryAlert(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, String userEmail) {
    final businessName = _profile?.businessName;
    final pincode = _profile?.businessPincode;
    final contactPerson = _profile?.contactPersonName;
    final initial = (businessName?.isNotEmpty ?? false)
        ? businessName![0].toUpperCase()
        : (userEmail.isNotEmpty ? userEmail[0].toUpperCase() : 'W');

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 44),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kBlue, kBlueDk, Color(0xFF06304F)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Builder(
                builder: (ctx) => GestureDetector(
                  // onTap: () => Scaffold.of(ctx).openDrawer(),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PharmaProfilePage()),
                    );
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: kTeal,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 19,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wetaran Pharma',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      contactPerson != null && contactPerson.isNotEmpty
                          ? 'Welcome, $contactPerson'
                          : 'Order smarter. Stock sharper.',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xCCFFFFFF),
                      ),
                    ),
                  ],
                ),
              ),
              Builder(
                builder: (ctx) => GestureDetector(
                  onTap: () => Scaffold.of(ctx).openDrawer(),
                  child: Container(
                    width: 38,
                    height: 38,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.13),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.menu_rounded,
                      size: 19,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Consumer<PharmaCartProvider>(
                builder: (context, cart, _) {
                  if (cart.isNotEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: GestureDetector(
                        onTap: () => showPharmaCartSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.13),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(.10),
                            ),
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
                    );
                  }

                  return GestureDetector(
                    onTap: () => showPharmaCartSheet(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.13),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shopping_cart_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _loadingProfile
                    ? const _HeroSkeletonLine()
                    : Text(
                        businessName?.isNotEmpty == true
                            ? businessName!
                            : 'Complete your business profile',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
              if (!_loadingProfile && pincode != null && pincode.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    pincode,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  //  Search box live results
  Widget _buildSearch() {
    return Transform.translate(
      offset: const Offset(0, -30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2A083A66),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18, color: kTeal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search by medicine name, SKU, generic…',
                        hintStyle: TextStyle(
                          fontSize: 14.5,
                          color: Color(0xFF93A6B5),
                        ),
                      ),
                      style: const TextStyle(fontSize: 14.5, color: kInk),
                    ),
                  ),
                ],
              ),
            ),
            if (_searching)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x30083A66),
                      blurRadius: 26,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Searching medicines...'),
                  ],
                ),
              )
            else if (_searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x30083A66),
                      blurRadius: 26,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 4 * 68),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: kLine),
                    itemBuilder: (_, index) {
                      final p = _searchResults[index];
                      final info = p.info ?? <String, dynamic>{};
                      final generic = info['generic_name']?.toString() ?? '';
                      final manufacturer =
                          info['manufacturer_name']?.toString() ?? '';
                      final subtitle = [
                        generic,
                        manufacturer,
                      ].where((e) => e.trim().isNotEmpty).join(' · ');
                      final code =
                          (p.skuCode ?? info['medicine_code']?.toString() ?? '')
                              .trim();

                      return InkWell(
                        onTap: () => _selectProduct(p),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.medication_outlined,
                                  size: 16,
                                  color: kTeal,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: kInk,
                                      ),
                                    ),
                                    if (subtitle.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: kMuted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (code.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                Text(
                                  code,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: kTeal,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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

  //  Distributor comparison panel
  Widget _buildComparePanel() {
    final selected = _selectedProduct;
    if (selected == null) return const SizedBox.shrink();

    final cart = context.watch<PharmaCartProvider>();
    final generic = selected.info?['generic_name']?.toString() ?? '';
    final manufacturer = selected.info?['manufacturer_name']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Transform.translate(
        offset: const Offset(0, -20),
        child: Container(
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14083A66),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: kInk,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              generic,
                              manufacturer,
                            ].where((e) => e.isNotEmpty).join(' · '),
                            style: const TextStyle(fontSize: 11, color: kMuted),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _closeCompare,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: kBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 14, color: kMuted),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: kLine),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_selectedOffers.length} DISTRIBUTORS NEAR ${_pincode ?? ''}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: kMuted,
                      letterSpacing: .8,
                    ),
                  ),
                ),
              ),
              ...List.generate(_selectedOffers.length, (i) {
                final entry = _selectedOffers[i];
                final dist = entry.key;
                final product = entry.value;
                final variants = _sortedVariants(product);
                final displayVariant = variants.first;
                final lowStock =
                    displayVariant.availableStock > 0 &&
                    displayVariant.availableStock <= 30;
                final isLast = i == _selectedOffers.length - 1;
                final hasMultipleVariants = variants.length > 1;
                final variantId = displayVariant.id;
                final primaryUnit = displayVariant.primaryUnit;
                final qtyInCart = cart.qtyForVariant(variantId, primaryUnit);
                final isInCart = cart.isVariantInCart(variantId, primaryUnit);
                final isLockedElsewhere =
                    cart.isNotEmpty &&
                    cart.lockedDistributorId != null &&
                    cart.lockedDistributorId != dist.id;
                final isThisDistSelected =
                    isInCart && cart.lockedDistributorId == dist.id;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : const Border(bottom: BorderSide(color: kLine)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dist.companyName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: kInk,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: lowStock ? kAmberBg : kGreenBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                lowStock
                                    ? 'Low stock ${displayVariant.availableStock.toInt()} ${displayVariant.primaryUnit}'
                                    : 'In stock ${displayVariant.availableStock.toInt()} ${displayVariant.primaryUnit}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: lowStock ? kAmber : kGreen,
                                ),
                              ),
                            ),
                            if (hasMultipleVariants) ...[
                              const SizedBox(height: 5),
                              Text(
                                '${variants.length} variants available',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: kTeal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text:
                                      '₹${displayVariant.sellPriceToRetailer.toStringAsFixed(2)} ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: kBlue,
                                  ),
                                ),
                                const TextSpan(
                                  text: 'PTR',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: kMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 5),
                          if (isLockedElsewhere)
                            GestureDetector(
                              onTap: () => _showDistributorSwitchDialog(
                                cart: cart,
                                newDistId: dist.id,
                                newDistName: dist.companyName,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF4E0),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFF3D19C),
                                  ),
                                ),
                                child: const Text(
                                  'Switch',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFB36A00),
                                  ),
                                ),
                              ),
                            )
                          else if (isThisDistSelected && !hasMultipleVariants)
                            buildQtyStepper(
                              variantId: variantId,
                              unit: primaryUnit,
                              qty: qtyInCart,
                              max: displayVariant.availableStock.toInt(),
                              allowBeyond: displayVariant.allowOrderBeyondStock,
                              cart: cart,
                              compact: true,
                            )
                          else
                            GestureDetector(
                              onTap: () => _handleProductTap(
                                product: product,
                                distributorId: dist.id,
                                distributorName: dist.companyName,
                                cart: cart,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isThisDistSelected
                                      ? const Color(0xFF2E7D32)
                                      : kTeal,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  hasMultipleVariants
                                      ? 'Choose variant'
                                      : isThisDistSelected
                                      ? 'Added'
                                      : 'Add to cart',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFullAmount(num value) {
    return NumberFormat('#,##,##0', 'en_IN').format(value);
  }

  //  KPI section
  Widget _buildKpis() {
    final monthLabel = _monthYearLabel(DateTime.now());
    final data = _kpiData;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This month — $monthLabel',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: kInk,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: 'Pending orders',
                  value: _loadingKpis ? '—' : '${data?.pendingCount ?? 0}',
                  sub: _loadingKpis
                      ? 'Loading…'
                      : 'Worth ₹${_formatAmount(data?.pendingAmount ?? 0)}',
                  valueColor: kAmber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KpiCard(
                  label: 'Total purchase',
                  value: _loadingKpis
                      ? '—'
                      : '₹${_formatFullAmount(data?.totalPurchaseThisMonth ?? 0)}',
                  sub: _loadingKpis
                      ? 'Loading…'
                      : (data?.growthPercent == null
                            ? 'No data for last month'
                            : '${data!.isGrowthPositive ? '▲' : '▼'} ${data.growthPercent!.abs().toStringAsFixed(0)}% vs last month'),
                  valueColor: kBlue,
                  subColor: (data?.growthPercent ?? 0) >= 0 ? kGreen : kAmber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _monthYearLabel(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatAmount(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(2)}L';
    return value.toStringAsFixed(0);
  }

  //  Feature grid
  Widget _buildFeatureGrid(BuildContext context) {
    final tiles = [
      _TileData(
        'Place Order',
        Icons.shopping_cart_outlined,
        iconBg: const Color(0xFFE4EDF7),
        iconColor: kBlue,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddOrderScreen())),
      ),
      _TileData(
        'Schemes',
        Icons.card_giftcard_outlined,
        badge: '3 NEW',
        onTap: () => widget.onNavigateToPage(2),
      ),
      _TileData(
        'Rewards',
        Icons.star_border_rounded,
        badge: '₹240',
        badgeTeal: true,
        onTap: () => widget.onNavigateToPage(3),
      ),
      _TileData(
        'Expiry & Batch',
        Icons.schedule_outlined,
        badge: '4',
        onTap: () => widget.onNavigateToPage(4),
      ),
      _TileData(
        'Distributors',
        Icons.local_shipping_outlined,
        iconBg: const Color(0xFFE4EDF7),
        iconColor: kBlue,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const DistributorsPage())),
      ),
      /*
      _TileData(
        'Rx Subscription',
        Icons.description_outlined,
        onTap: () {
          // later
        },
      ),
      */
      _TileData(
        'Reports',
        Icons.bar_chart_outlined,
        onTap: () => widget.onNavigateToPage(5),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Everything you need',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: kInk,
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.95,
            children: tiles.map((t) => _FeatureTile(data: t)).toList(),
          ),
        ],
      ),
    );
  }

  //  Schemes strip
  Widget _buildSchemes() {
    final schemes = [
      _SchemeData(
        'Micro Labs · Manufacturer',
        'Dolo 650 — Buy 10 strips, get 1 free',
        'Valid till 15 Jul · Min. order 10 strips',
        kTeal,
      ),
      _SchemeData(
        'Mahavir Pharma · Distributor',
        '2% extra margin on Alkem range above ₹10,000',
        'Valid till 31 Jul · Pincode 400058',
        kBlue,
      ),
      _SchemeData(
        'GSK · Manufacturer',
        'Augmentin 625 Duo — 5 + 1 scheme',
        'Valid till 20 Jul · All distributors',
        kAmber,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Schemes in your area',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: kInk,
                  ),
                ),
                Text(
                  'View all',
                  style: TextStyle(
                    fontSize: 11,
                    color: kTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: schemes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final s = schemes[i];
                return Container(
                  width: 218,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border(top: BorderSide(color: s.color, width: 3)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12083A66),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.src.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: s.color,
                          letterSpacing: .8,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        s.offer,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: kInk,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.till,
                        style: const TextStyle(fontSize: 10.5, color: kMuted),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  //  Expiry alert
  Widget _buildExpiryAlert() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kAmberBg,
          border: Border.all(color: const Color(0xFFF5DFB8)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE7C2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                size: 17,
                color: kAmber,
              ),
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '4 batches expiring within 60 days',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B4A00),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Telma 40 · Pan 40 · Shelcal 500 · Ecosprin 75',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8A6620)),
                  ),
                ],
              ),
            ),
            const Text(
              'Review →',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kAmber,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSkeletonLine extends StatelessWidget {
  const _HeroSkeletonLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 13,
      width: 160,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.18),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

//  KPI card
class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color valueColor;
  final Color? subColor;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.valueColor,
    this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12083A66),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: kMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10.5,
              color: subColor ?? kMuted,
              fontWeight: subColor != null ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

//  Feature tile
class _TileData {
  final String title;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String? badge;
  final bool badgeTeal;
  final VoidCallback? onTap;

  _TileData(
    this.title,
    this.icon, {
    this.iconBg = kTealSoft,
    this.iconColor = kTeal,
    this.badge,
    this.badgeTeal = false,
    this.onTap,
  });
}

class _FeatureTile extends StatelessWidget {
  final _TileData data;
  const _FeatureTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: data.onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 13, 8, 11),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12083A66),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (data.badge != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: data.badgeTeal ? kTeal : const Color(0xFFFFB13D),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    data.badge!,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: data.badgeTeal
                          ? Colors.white
                          : const Color(0xFF5A3A00),
                    ),
                  ),
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: data.iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(data.icon, size: 19, color: data.iconColor),
                ),
                const SizedBox(height: 7),
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kInk,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

//  Scheme data
class _SchemeData {
  final String src;
  final String offer;
  final String till;
  final Color color;
  _SchemeData(this.src, this.offer, this.till, this.color);
}

//  Placeholder pages

class _CompareOffer {
  final String distributorId;
  final String distributorName;
  final String? distributorMeta;
  final SkuProduct product;
  final List<SkuVariant> variants;

  const _CompareOffer({
    required this.distributorId,
    required this.distributorName,
    required this.product,
    required this.variants,
    // ignore: unused_element_parameter
    this.distributorMeta,
  });

  bool get hasVariants => variants.isNotEmpty;

  SkuVariant? get defaultVariant => hasVariants ? variants.first : null;

  double get displayPrice => hasVariants
      ? variants.first.sellPriceToRetailer
      : product.sellPriceToRetailer;

  double get displayMrp => hasVariants
      ? variants.first.maxRetailPrice
      : (product.maxRetailPrice ?? 0);

  double get displayStock =>
      hasVariants ? variants.first.availableStock : product.currentStock;
}

String _productGroupKey(SkuProduct p) {
  final info = p.info ?? <String, dynamic>{};

  final medicineRepoId = info['medicine_repository_id']?.toString();
  if (medicineRepoId != null && medicineRepoId.isNotEmpty) {
    return 'repo:$medicineRepoId';
  }

  final medicineCode = (info['medicine_code']?.toString() ?? '')
      .trim()
      .toLowerCase();
  if (medicineCode.isNotEmpty) {
    return 'code:$medicineCode';
  }

  final name = p.name.trim().toLowerCase();
  final generic = (info['generic_name']?.toString() ?? '').trim().toLowerCase();
  final dosage = (info['dosage_form']?.toString() ?? '').trim().toLowerCase();

  return 'name:$name|generic:$generic|dosage:$dosage';
}
