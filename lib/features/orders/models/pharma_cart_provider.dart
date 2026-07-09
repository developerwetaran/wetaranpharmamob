// lib/features/orders/models/pharma_cart_provider.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PharmaCartItem {
  final String skuId;
  final String skuName;
  final String skuCode;
  final String? imagePath;
  final String? category;
  final String distributorId;
  final String distributorName;

  final double mrp;
  final double ptr;
  final double? minSellPrice;
  final double pricePerUnit;

  final String variantId;
  final String variantName;
  final String variantSkuCode;

  final String unit;
  final String primaryUnit;
  final double availableStock;

  final bool allowOrderBeyondStock;
  final bool allowSellingInAlternativeUnit;
  final List<Map<String, dynamic>> alternativeUnits;

  final String? genericName;
  final String? dosageForm;
  final String? packLabel;
  final String? batchNumber;
  final String? expiryDate;
  final String? manufacturerName;
  final String? marketerName;
  final String? productCategory;
  final String? medicineCode;
  final String? brandName;

  final Map<String, dynamic>? extraInfo;
  final int quantity;

  PharmaCartItem({
    required this.skuId,
    required this.skuName,
    required this.skuCode,
    this.imagePath,
    this.category,
    required this.distributorId,
    required this.distributorName,
    required this.mrp,
    required this.ptr,
    this.minSellPrice,
    required this.pricePerUnit,
    required this.variantId,
    required this.variantName,
    required this.variantSkuCode,
    required this.unit,
    required this.primaryUnit,
    required this.availableStock,
    required this.allowOrderBeyondStock,
    required this.allowSellingInAlternativeUnit,
    required this.alternativeUnits,
    this.genericName,
    this.dosageForm,
    this.packLabel,
    this.batchNumber,
    this.expiryDate,
    this.manufacturerName,
    this.marketerName,
    this.productCategory,
    this.medicineCode,
    this.brandName,
    this.extraInfo,
    this.quantity = 1,
  });

  double get totalPrice => pricePerUnit * quantity;

  double get discountPercent {
    if (mrp <= 0 || mrp <= pricePerUnit) return 0;
    return ((mrp - pricePerUnit) / mrp) * 100;
  }

  PharmaCartItem copyWith({int? quantity}) => PharmaCartItem(
    skuId: skuId,
    skuName: skuName,
    skuCode: skuCode,
    imagePath: imagePath,
    category: category,
    distributorId: distributorId,
    distributorName: distributorName,
    mrp: mrp,
    ptr: ptr,
    minSellPrice: minSellPrice,
    pricePerUnit: pricePerUnit,
    variantId: variantId,
    variantName: variantName,
    variantSkuCode: variantSkuCode,
    unit: unit,
    primaryUnit: primaryUnit,
    availableStock: availableStock,
    allowOrderBeyondStock: allowOrderBeyondStock,
    allowSellingInAlternativeUnit: allowSellingInAlternativeUnit,
    alternativeUnits: alternativeUnits,
    genericName: genericName,
    dosageForm: dosageForm,
    packLabel: packLabel,
    batchNumber: batchNumber,
    expiryDate: expiryDate,
    manufacturerName: manufacturerName,
    marketerName: marketerName,
    productCategory: productCategory,
    medicineCode: medicineCode,
    brandName: brandName,
    extraInfo: extraInfo,
    quantity: quantity ?? this.quantity,
  );

  Map<String, dynamic> toJson() => {
    'skuId': skuId,
    'skuName': skuName,
    'skuCode': skuCode,
    'imagePath': imagePath,
    'category': category,
    'distributorId': distributorId,
    'distributorName': distributorName,
    'mrp': mrp,
    'ptr': ptr,
    'minSellPrice': minSellPrice,
    'pricePerUnit': pricePerUnit,
    'variantId': variantId,
    'variantName': variantName,
    'variantSkuCode': variantSkuCode,
    'unit': unit,
    'primaryUnit': primaryUnit,
    'availableStock': availableStock,
    'allowOrderBeyondStock': allowOrderBeyondStock,
    'allowSellingInAlternativeUnit': allowSellingInAlternativeUnit,
    'alternativeUnits': alternativeUnits,
    'genericName': genericName,
    'dosageForm': dosageForm,
    'packLabel': packLabel,
    'batchNumber': batchNumber,
    'expiryDate': expiryDate,
    'manufacturerName': manufacturerName,
    'marketerName': marketerName,
    'productCategory': productCategory,
    'medicineCode': medicineCode,
    'brandName': brandName,
    'extraInfo': extraInfo,
    'quantity': quantity,
  };

  factory PharmaCartItem.fromJson(Map<String, dynamic> j) => PharmaCartItem(
    skuId: j['skuId'] as String? ?? '',
    skuName: j['skuName'] as String? ?? '',
    skuCode: j['skuCode'] as String? ?? '',
    imagePath: j['imagePath'] as String?,
    category: j['category'] as String?,
    distributorId: j['distributorId'] as String? ?? '',
    distributorName: j['distributorName'] as String? ?? '',
    mrp: (j['mrp'] as num?)?.toDouble() ?? 0,
    ptr: (j['ptr'] as num?)?.toDouble() ?? 0,
    minSellPrice: (j['minSellPrice'] as num?)?.toDouble(),
    pricePerUnit:
        (j['pricePerUnit'] as num?)?.toDouble() ??
        (j['sellPrice'] as num?)?.toDouble() ??
        0,
    variantId: j['variantId'] as String? ?? '',
    variantName: j['variantName'] as String? ?? '',
    variantSkuCode: j['variantSkuCode'] as String? ?? '',
    unit: j['unit'] as String? ?? j['primaryUnit'] as String? ?? '',
    primaryUnit: j['primaryUnit'] as String? ?? '',
    availableStock: (j['availableStock'] as num?)?.toDouble() ?? 0,
    allowOrderBeyondStock: j['allowOrderBeyondStock'] as bool? ?? false,
    allowSellingInAlternativeUnit:
        j['allowSellingInAlternativeUnit'] as bool? ?? true,
    alternativeUnits: (j['alternativeUnits'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
    genericName: j['genericName'] as String?,
    dosageForm: j['dosageForm'] as String?,
    packLabel: j['packLabel'] as String?,
    batchNumber: j['batchNumber'] as String?,
    expiryDate: j['expiryDate'] as String?,
    manufacturerName: j['manufacturerName'] as String?,
    marketerName: j['marketerName'] as String?,
    productCategory: j['productCategory'] as String?,
    medicineCode: j['medicineCode'] as String?,
    brandName: j['brandName'] as String?,
    extraInfo: j['extraInfo'] is Map
        ? Map<String, dynamic>.from(j['extraInfo'] as Map)
        : null,
    quantity: j['quantity'] as int? ?? 1,
  );

  Map<String, dynamic> toOrderProduct() => {
    'sku_id': skuId,
    'name': skuName,
    'sku_code': skuCode,
    'category': category ?? productCategory ?? 'Uncategorised',
    'image_path': imagePath ?? '',
    'distributor_id': distributorId,
    'distributor_name': distributorName,
    'variant_id': variantId,
    'variant_name': variantName,
    'variant_sku_code': variantSkuCode,
    'primary_unit': primaryUnit,
    'unit': unit,
    'sell_price': pricePerUnit,
    'ptr': ptr,
    'mrp': mrp,
    'min_sell_price': minSellPrice,
    'discount_percent': discountPercent,
    'quantity': quantity,
    'total_price': totalPrice,
    'available_stock': availableStock,
    'generic_name': genericName ?? '',
    'dosage_form': dosageForm ?? '',
    'pack_label': packLabel ?? '',
    'batch_number': batchNumber ?? '',
    'expiry_date': expiryDate ?? '',
    'manufacturer_name': manufacturerName ?? '',
    'marketer_name': marketerName ?? '',
    'medicine_code': medicineCode ?? '',
    'brand_name': brandName ?? '',
    'extra_info': extraInfo ?? const {},
  };
}

class PharmaCartProvider extends ChangeNotifier {
  static const _prefKey = 'wetaran_pharma_cart_v3';

  List<PharmaCartItem> _items = [];
  String? _lockedDistributorId;
  String? _lockedDistributorName;

  List<PharmaCartItem> get items => List.unmodifiable(_items);
  String? get lockedDistributorId => _lockedDistributorId;
  String? get lockedDistributorName => _lockedDistributorName;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  int get itemCount => _items.length;
  double get subtotal => _items.fold(0, (sum, item) => sum + item.totalPrice);

  bool canAddFromDistributor(String distributorId) =>
      _items.isEmpty || _lockedDistributorId == distributorId;

  bool isVariantInCart(String variantId, String unit) =>
      _items.any((i) => i.variantId == variantId && i.unit == unit);

  PharmaCartItem? itemForVariant(String variantId, String unit) {
    try {
      return _items.firstWhere(
        (i) => i.variantId == variantId && i.unit == unit,
      );
    } catch (_) {
      return null;
    }
  }

  int qtyForVariant(String variantId, String unit) {
    return itemForVariant(variantId, unit)?.quantity ?? 0;
  }

  bool addItem(PharmaCartItem item) {
    if (!canAddFromDistributor(item.distributorId)) return false;

    if (_items.isEmpty) {
      _lockedDistributorId = item.distributorId;
      _lockedDistributorName = item.distributorName;
    }

    final idx = _items.indexWhere(
      (i) => i.variantId == item.variantId && i.unit == item.unit,
    );

    if (idx >= 0) {
      final existing = _items[idx];
      final maxQty = _resolveMax(existing);
      final newQty = existing.quantity + item.quantity;

      _items[idx] = existing.copyWith(
        quantity: maxQty == 0 ? newQty : (newQty > maxQty ? maxQty : newQty),
      );
    } else {
      final maxQty = _resolveMax(item);
      final desiredQty = item.quantity < 1 ? 1 : item.quantity;
      final initialQty = maxQty == 0
          ? desiredQty
          : (desiredQty > maxQty ? maxQty : desiredQty);

      if (initialQty > 0) {
        _items.add(item.copyWith(quantity: initialQty));
      }
    }

    _persist();
    notifyListeners();
    return true;
  }

  void updateQuantity(String variantId, String unit, int qty) {
    final idx = _items.indexWhere(
      (i) => i.variantId == variantId && i.unit == unit,
    );
    if (idx == -1) return;

    final item = _items[idx];
    final maxQty = _resolveMax(item);

    if (qty <= 0) {
      removeItem(variantId, unit);
      return;
    }

    final nextQty = maxQty == 0 ? qty : (qty > maxQty ? maxQty : qty);

    if (nextQty <= 0) {
      removeItem(variantId, unit);
      return;
    }

    _items[idx] = item.copyWith(quantity: nextQty);
    _persist();
    notifyListeners();
  }

  void removeItem(String variantId, String unit) {
    _items.removeWhere((i) => i.variantId == variantId && i.unit == unit);
    if (_items.isEmpty) {
      _resetLock();
    }
    _persist();
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _resetLock();
    _persist();
    notifyListeners();
  }

  void lockDistributor(String id, String name) {
    if (_items.isNotEmpty && _lockedDistributorId != id) return;
    _lockedDistributorId = id;
    _lockedDistributorName = name;
    _persist();
    notifyListeners();
  }

  void clearDistributorLockIfEmpty() {
    if (_items.isEmpty && _lockedDistributorId != null) {
      _resetLock();
      _persist();
      notifyListeners();
    }
  }

  int _resolveMax(PharmaCartItem item) {
    if (item.allowOrderBeyondStock) return 0;

    if (item.unit.toLowerCase() == item.primaryUnit.toLowerCase()) {
      final stock = item.availableStock.floor();
      return stock > 0 ? stock : 0;
    }

    final alt = item.alternativeUnits.cast<Map<String, dynamic>?>().firstWhere(
      (u) =>
          (u?['unit']?.toString().toLowerCase() ?? '') ==
          item.unit.toLowerCase(),
      orElse: () => null,
    );

    final altStock = (alt?['stock'] as num?)?.floor();
    if (altStock != null && altStock > 0) return altStock;

    final factor =
        (alt?['factor'] as num?)?.toDouble() ??
        (alt?['conversion_factor'] as num?)?.toDouble() ??
        0;

    if (factor > 0) {
      final converted = (item.availableStock * factor).floor();
      return converted > 0 ? converted : 0;
    }

    final fallbackStock = item.availableStock.floor();
    return fallbackStock > 0 ? fallbackStock : 0;
  }

  void _resetLock() {
    _lockedDistributorId = null;
    _lockedDistributorName = null;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null) return;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      _lockedDistributorId = map['lockedDistributorId'] as String?;
      _lockedDistributorName = map['lockedDistributorName'] as String?;
      _items = (map['items'] as List? ?? [])
          .map(
            (e) => PharmaCartItem.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();

      notifyListeners();
    } catch (e) {
      print('PharmaCartProvider.load error: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefKey,
        jsonEncode({
          'lockedDistributorId': _lockedDistributorId,
          'lockedDistributorName': _lockedDistributorName,
          'items': _items.map((i) => i.toJson()).toList(),
        }),
      );
    } catch (e) {
      print('PharmaCartProvider._persist error: $e');
    }
  }
}
