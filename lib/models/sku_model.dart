class AlternativeUnit {
  final String unit;
  final double factor;

  const AlternativeUnit({required this.unit, required this.factor});

  factory AlternativeUnit.fromJson(Map<String, dynamic> json) {
    return AlternativeUnit(
      unit: (json['unit'] ?? '').toString(),
      factor: ((json['factor'] ?? json['conversion_factor'] ?? 1) as num)
          .toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'unit': unit, 'factor': factor};
}

class SkuVariant {
  final String id;
  final String variantName;
  final String variantSkuCode;
  final String primaryUnit;
  final double availableStock;
  final double sellPriceToRetailer;
  final double maxRetailPrice;
  final bool allowOrderBeyondStock;
  final bool allowSellingInAlternativeUnit;
  final List<AlternativeUnit> alternativeUnits;

  const SkuVariant({
    required this.id,
    required this.variantName,
    required this.variantSkuCode,
    required this.primaryUnit,
    required this.availableStock,
    required this.sellPriceToRetailer,
    required this.maxRetailPrice,
    required this.allowOrderBeyondStock,
    required this.allowSellingInAlternativeUnit,
    required this.alternativeUnits,
  });

  factory SkuVariant.fromJson(Map<String, dynamic> json) {
    final rawAltUnits = (json['alternative_units'] as List?) ?? const [];

    return SkuVariant(
      id: (json['id'] ?? '').toString(),
      variantName: (json['variant_name'] ?? json['name'] ?? '').toString(),
      variantSkuCode: (json['variant_sku_code'] ?? json['sku_code'] ?? '')
          .toString(),
      primaryUnit: (json['primary_unit'] ?? 'pcs').toString(),
      availableStock: _toDouble(
        json['available_stock'] ?? json['current_stock'] ?? json['stock'],
      ),
      sellPriceToRetailer: _toDouble(
        json['sell_price_to_retailer'] ?? json['sell_price'] ?? json['ptr'],
      ),
      maxRetailPrice: _toDouble(json['max_retail_price'] ?? json['mrp']),
      allowOrderBeyondStock: _toBool(
        json['allow_order_beyond_stock'],
        fallback: false,
      ),
      allowSellingInAlternativeUnit: _toBool(
        json['allow_selling_in_alternative_unit'],
        fallback: true,
      ),
      alternativeUnits: rawAltUnits
          .whereType<Map>()
          .map((e) => AlternativeUnit.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  double pricePerUnit(String unit) {
    if (unit.toLowerCase() == primaryUnit.toLowerCase()) {
      return sellPriceToRetailer;
    }

    final alt = alternativeUnits
        .where((u) {
          return u.unit.toLowerCase() == unit.toLowerCase();
        })
        .cast<AlternativeUnit?>()
        .firstWhere((u) => u != null, orElse: () => null);

    if (alt == null || alt.factor <= 0) return sellPriceToRetailer;
    return sellPriceToRetailer / alt.factor;
  }

  double stockInUnit(String unit) {
    if (unit.toLowerCase() == primaryUnit.toLowerCase()) {
      return availableStock;
    }

    final alt = alternativeUnits
        .where((u) {
          return u.unit.toLowerCase() == unit.toLowerCase();
        })
        .cast<AlternativeUnit?>()
        .firstWhere((u) => u != null, orElse: () => null);

    if (alt == null || alt.factor <= 0) return availableStock;
    return availableStock * alt.factor;
  }

  static double _toDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  static bool _toBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    final s = value.toString().toLowerCase().trim();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return fallback;
  }
}

class SkuProduct {
  final String id;
  final String name;
  final String? skuCode;
  final String? category;
  final String primaryUnit;
  final String? hsnCode;
  final double taxSlab;
  final double currentStock;
  final double sellPriceToRetailer;
  final double? maxRetailPrice;
  final bool allowSellingInAlternativeUnit;
  final String? imagePath;
  final String? subBrandName;
  final String? subBrandLogoUrl;
  final List<AlternativeUnit> alternativeUnits;
  final List<SkuVariant> variants;
  final Map<String, dynamic>? info;

  const SkuProduct({
    required this.id,
    required this.name,
    required this.primaryUnit,
    required this.taxSlab,
    required this.currentStock,
    required this.sellPriceToRetailer,
    required this.allowSellingInAlternativeUnit,
    required this.alternativeUnits,
    required this.variants,
    this.skuCode,
    this.category,
    this.hsnCode,
    this.maxRetailPrice,
    this.imagePath,
    this.subBrandName,
    this.subBrandLogoUrl,
    this.info,
  });

  factory SkuProduct.fromJson(Map<String, dynamic> json) {
    final stockRow = _asMap(json['inventory_pharma_stock']);
    final repoRow = _asMap(json['medicine_repository']);
    final nestedRepoRow = _asMap(stockRow?['medicine_repository']);

    final medicine = repoRow ?? nestedRepoRow;
    final normalizedInfo = _buildNormalizedInfo(
      root: json,
      stock: stockRow,
      medicine: medicine,
    );

    final rawAltUnits =
        (json['alternative_units'] as List?) ??
        (stockRow?['alternative_units'] as List?) ??
        const [];

    final rawVariants = (json['variants'] as List?) ?? const [];

    return SkuProduct(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['product_name'] ?? '').toString(),
      skuCode: _stringOrNull(json['sku_code']),
      category: _stringOrNull(json['category_name'] ?? json['category']),
      primaryUnit:
          (json['primary_unit'] ??
                  stockRow?['primary_unit'] ??
                  medicine?['primary_unit'] ??
                  'pcs')
              .toString(),
      hsnCode: _stringOrNull(
        json['hsn_code'] ?? stockRow?['hsn_code'] ?? medicine?['hsn_code'],
      ),
      taxSlab: _toDouble(
        json['tax_slab'] ?? stockRow?['tax_slab'] ?? medicine?['tax_slab'],
      ),
      currentStock: _toDouble(
        json['current_stock'] ??
            json['available_stock'] ??
            stockRow?['current_stock'] ??
            stockRow?['available_stock'],
      ),
      sellPriceToRetailer: _toDouble(
        json['sell_price_to_retailer'] ??
            json['sell_price'] ??
            stockRow?['sell_price_to_retailer'] ??
            stockRow?['sell_price'] ??
            stockRow?['ptr'],
      ),
      maxRetailPrice: _toNullableDouble(
        json['max_retail_price'] ??
            json['mrp'] ??
            stockRow?['max_retail_price'] ??
            stockRow?['mrp'],
      ),
      allowSellingInAlternativeUnit: _toBool(
        json['allow_selling_in_alternative_unit'] ??
            stockRow?['allow_selling_in_alternative_unit'],
        fallback: true,
      ),
      imagePath: _stringOrNull(
        json['image_path'] ??
            json['product_image'] ??
            medicine?['image_path'] ??
            medicine?['image_url'],
      ),
      subBrandName: _stringOrNull(
        json['sub_brand_name'] ?? medicine?['sub_brand_name'],
      ),
      subBrandLogoUrl: _stringOrNull(
        json['sub_brand_logo_url'] ?? medicine?['sub_brand_logo_url'],
      ),
      alternativeUnits: rawAltUnits
          .whereType<Map>()
          .map((e) => AlternativeUnit.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      variants: rawVariants
          .whereType<Map>()
          .map((e) => SkuVariant.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      info: json['info'] is Map
          ? Map<String, dynamic>.from(json['info'] as Map)
          : normalizedInfo,
    );
  }

  static Map<String, dynamic>? _buildNormalizedInfo({
    required Map<String, dynamic> root,
    Map<String, dynamic>? stock,
    Map<String, dynamic>? medicine,
  }) {
    final info = <String, dynamic>{
      'medicine_repository_id':
          medicine?['id'] ?? stock?['medicine_repository_id'],
      'generic_name': medicine?['generic_name'] ?? stock?['generic_name'],
      'dosage_form': medicine?['dosage_form'] ?? stock?['dosage_form'],
      'pack_label': medicine?['pack_label'] ?? stock?['pack_label'],
      'manufacturer_name':
          medicine?['manufacturer_name'] ?? stock?['manufacturer_name'],
      'marketer_name': medicine?['marketer_name'] ?? stock?['marketer_name'],
      'composition': medicine?['composition'] ?? stock?['composition'],
      'product_category':
          medicine?['product_category'] ?? stock?['product_category'],
      'medicine_code': medicine?['medicine_code'] ?? stock?['medicine_code'],
      'batch_number': stock?['batch_number'] ?? root['batch_number'],
      'expiry_date': stock?['expiry_date'] ?? root['expiry_date'],
      'ptr':
          stock?['ptr'] ??
          stock?['sell_price_to_retailer'] ??
          root['sell_price_to_retailer'],
      'mrp': stock?['mrp'] ?? stock?['max_retail_price'] ?? root['mrp'],
      'min_sell_price': stock?['min_sell_price'] ?? root['min_sell_price'],
      'tax_slab':
          root['tax_slab'] ?? stock?['tax_slab'] ?? medicine?['tax_slab'],
      'hsn_code':
          root['hsn_code'] ?? stock?['hsn_code'] ?? medicine?['hsn_code'],
    };

    info.removeWhere((key, value) {
      if (value == null) return true;
      if (value is String && value.trim().isEmpty) return true;
      return false;
    });

    return info.isEmpty ? null : info;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static double _toDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  static double? _toNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static bool _toBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    final s = value.toString().toLowerCase().trim();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return fallback;
  }
}
