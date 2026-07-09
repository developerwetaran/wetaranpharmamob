// lib/features/orders/services/pharma_distributor_service.dart
// ignore_for_file: avoid_print

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wetaran_pharma/models/sku_model.dart';

class PharmaDistributor {
  final String id;
  final String companyName;
  final String? companyPhone;
  final String? logoCompactUrl;
  final bool allowOrderBeyondAvailableSkus;
  final String pharmaExpectedDelivery;
  final String? pharmaSameDayOrderCutoff;
  final double pharmaMinimumOrderValue;
  final List<SkuProduct> products;

  const PharmaDistributor({
    required this.id,
    required this.companyName,
    this.companyPhone,
    this.logoCompactUrl,
    required this.allowOrderBeyondAvailableSkus,
    required this.pharmaExpectedDelivery,
    this.pharmaSameDayOrderCutoff,
    required this.pharmaMinimumOrderValue,
    required this.products,
  });
}

class PharmaDistributorService {
  static final _supabase = Supabase.instance.client;

  static Future<Map<String, String?>> loadPharmaUserLocation() async {
    final authId = _supabase.auth.currentUser?.id;
    if (authId == null) return {};

    final row = await _supabase
        .from('pharma_users')
        .select('business_pincode, business_city, business_state')
        .eq('auth_user_id', authId)
        .maybeSingle();

    if (row == null) return {};
    return {
      'pincode': (row['business_pincode'] as String?)?.trim().toLowerCase(),
      'city': (row['business_city'] as String?)?.trim().toLowerCase(),
      'state': (row['business_state'] as String?)?.trim().toLowerCase(),
    };
  }

  static Future<List<Map<String, dynamic>>> findDistributors({
    required String? pincode,
    required String? city,
    required String? state,
  }) async {
    final rows =
        await _supabase
                .from('distributor')
                .select(
                  'id, company_name, company_phone, logo_compact_url, '
                  'allow_order_beyond_available_skus, service_coverage, '
                  'pharma_expected_delivery, pharma_same_day_order_cutoff, pharma_minimum_order_value',
                )
                .eq('is_active', true)
            as List;

    final matched = <Map<String, dynamic>>[];

    for (final raw in rows) {
      final row = raw as Map<String, dynamic>;
      final coverage = row['service_coverage'] as Map<String, dynamic>?;
      if (coverage == null) continue;

      final regions = coverage['regions'] as List? ?? [];
      int matchScore = 0;

      for (final item in regions) {
        final region = item as Map<String, dynamic>;

        final regionPincode = (region['pincode']?.toString() ?? '')
            .trim()
            .toLowerCase();
        if (pincode != null && pincode.isNotEmpty && regionPincode == pincode) {
          matchScore = 3;
          break;
        }

        final regionState = (region['state'] as String? ?? '')
            .trim()
            .toLowerCase();
        final cities = region['cities'] as List? ?? [];

        if (state != null && state.isNotEmpty && regionState == state) {
          matchScore = matchScore < 1 ? 1 : matchScore;

          for (final c in cities) {
            final cityObj = c as Map<String, dynamic>;
            final cityName = (cityObj['city'] as String? ?? '')
                .trim()
                .toLowerCase();
            final pincodes = (cityObj['pincodes'] as List? ?? [])
                .map((e) => e.toString().trim().toLowerCase())
                .toList();

            if (city != null && city.isNotEmpty && cityName == city) {
              matchScore = matchScore < 2 ? 2 : matchScore;
            }

            if (pincode != null &&
                pincode.isNotEmpty &&
                pincodes.contains(pincode)) {
              matchScore = 3;
              break;
            }
          }
        }

        if (matchScore == 3) break;
      }

      if (matchScore > 0) {
        matched.add({...row, '_score': matchScore});
      }
    }

    matched.sort((a, b) => (b['_score'] as int).compareTo(a['_score'] as int));
    return matched;
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final s = value.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static bool _asBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    final s = value.toString().toLowerCase().trim();
    if (s == 'true') return true;
    if (s == 'false') return false;
    return fallback;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<dynamic> _buildAlternativeUnits({
    required String primaryUnit,
    required Map<String, dynamic> medicineRepo,
  }) {
    final packUom = _asMap(medicineRepo['pack_uom']);
    final conversionFactor = _asMap(packUom['conversionFactor']);

    final fromUom = _asString(conversionFactor['fromUom']);
    final toUom = _asString(conversionFactor['toUom']);
    final fromQty = _asDouble(conversionFactor['fromQty'], fallback: 1);
    final toQty = _asDouble(conversionFactor['toQty'], fallback: 0);

    if (fromUom.isEmpty || toUom.isEmpty || toQty <= 0) {
      return const [];
    }

    if (primaryUnit.toLowerCase() == fromUom.toLowerCase()) {
      return [
        {
          'unit': toUom,
          'conversion_factor': toQty / (fromQty <= 0 ? 1 : fromQty),
        },
      ];
    }

    if (primaryUnit.toLowerCase() == toUom.toLowerCase()) {
      return [
        {
          'unit': fromUom,
          'conversion_factor': (fromQty <= 0 ? 1 : fromQty) / toQty,
        },
      ];
    }

    return [
      {'unit': fromUom, 'conversion_factor': fromQty <= 0 ? 1 : fromQty},
      {'unit': toUom, 'conversion_factor': toQty},
    ];
  }

  static SkuVariant _buildSingleVariantFromInventoryRow(
    Map<String, dynamic> row,
    Map<String, dynamic> medicineRepo,
  ) {
    final pricingTax = _asMap(medicineRepo['pricing_tax']);
    final packUom = _asMap(medicineRepo['pack_uom']);
    final productIdentity = _asMap(medicineRepo['product_identity']);

    final primaryUnit = _asString(
      row['pricing_unit'],
      fallback: _asString(
        packUom['salesUom'],
        fallback: _asString(packUom['inventoryUom'], fallback: 'Unit'),
      ),
    );

    final variantName = _asString(
      row['product_name'],
      fallback: _asString(
        row['sku_name'],
        fallback: _asString(
          medicineRepo['product_name'],
          fallback: _asString(
            productIdentity['productName'],
            fallback: 'Product',
          ),
        ),
      ),
    );

    final variantSkuCode = _asString(
      row['variant_sku_code'],
      fallback: _asString(
        row['sku_code'],
        fallback: _asString(
          row['medicine_code'],
          fallback: _asString(medicineRepo['medicine_code']),
        ),
      ),
    );

    final sellPrice = _asDouble(
      row['sell_price_to_retailer'],
      fallback: _asDouble(row['ptr'], fallback: _asDouble(pricingTax['ptr'])),
    );

    final mrp = _asDouble(
      row['max_retail_price'],
      fallback: _asDouble(
        row['mrp'],
        fallback: _asDouble(medicineRepo['current_mrp']),
      ),
    );

    final currentStock = _asDouble(row['current_stock']);
    final reservedStock = _asDouble(row['reserved_stock']);

    return SkuVariant.fromJson({
      'id': row['id'],
      'sku_id': row['id'],
      'variant_name': variantName,
      'variant_sku_code': variantSkuCode,
      'primary_unit': primaryUnit,
      'alternative_units': _buildAlternativeUnits(
        primaryUnit: primaryUnit,
        medicineRepo: medicineRepo,
      ),
      'current_stock': currentStock,
      'reserved_stock': reservedStock,
      'sell_price_to_retailer': sellPrice,
      'max_retail_price': mrp,
      'allow_selling_in_alternative_unit': true,
      'allow_collecting_order_beyond_stock_availability': false,
      'sub_brand_id': null,
      'status': 'Active',
    });
  }

  static SkuProduct _buildProductFromInventoryRow(Map<String, dynamic> row) {
    final medicineRepo = _asMap(row['medicine_repository']);
    final productIdentity = _asMap(medicineRepo?['product_identity']);
    final dosageMedicineType = _asMap(medicineRepo?['dosage_medicine_type']);
    final regulatoryDetails = _asMap(medicineRepo?['regulatory_details']);
    final batchExpirySettings = _asMap(medicineRepo?['batch_expiry_settings']);
    final compositionStrength = _asMap(medicineRepo?['composition_strength']);
    final pricingTax = _asMap(medicineRepo?['pricing_tax']);

    final primaryUnit = _asString(row['pricing_unit'], fallback: 'Unit');

    final productName = _asString(
      row['product_name'],
      fallback: _asString(
        row['sku_name'],
        fallback: _asString(
          medicineRepo?['product_name'],
          fallback: _asString(
            productIdentity?['productName'],
            fallback: 'Unnamed Product',
          ),
        ),
      ),
    );

    final skuCode = _asString(
      row['sku_code'],
      fallback: _asString(
        row['medicine_code'],
        fallback: _asString(medicineRepo?['medicine_code']),
      ),
    );

    final currentStock = _asDouble(row['current_stock']);
    final reservedStock = _asDouble(row['reserved_stock']);
    final sellPrice = _asDouble(
      row['sell_price_to_retailer'],
      fallback: _asDouble(row['ptr']),
    );
    final mrp = _asDouble(
      row['max_retail_price'],
      fallback: _asDouble(
        row['mrp'],
        fallback: _asDouble(medicineRepo?['current_mrp']),
      ),
    );

    final ingredients =
        (compositionStrength?['ingredients'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        <Map<String, dynamic>>[];

    final productDescription = _asString(
      productIdentity?['productDescription'],
    );

    final compositionDisplay = _asString(
      medicineRepo?['composition_display'],
      fallback: _asString(compositionStrength?['compositionDisplay']),
    );

    final ingredientSummary = ingredients
        .map((e) {
          final name = _asString(e['ingredientName']);
          final value = e['strengthValue']?.toString() ?? '';
          final unit = _asString(e['strengthUnit']);
          if (name.isEmpty) return '';
          final strength = [value, unit].where((s) => s.isNotEmpty).join(' ');
          return strength.isEmpty ? name : '$name $strength';
        })
        .where((e) => e.isNotEmpty)
        .join(', ');

    final variant = _buildSingleVariantFromInventoryRow(
      row,
      medicineRepo ?? <String, dynamic>{},
    );

    final info = <String, dynamic>{
      'inventory_stock_id': row['id'],
      'medicine_repository_id': row['medicine_repository_id'],
      'brand_name': _asString(
        row['brand_name'],
        fallback: _asString(medicineRepo?['brand_company']),
      ),
      'barcode_gtin': _asString(productIdentity?['barcodeGtin']),
      'generic_name': _asString(
        row['generic_name'],
        fallback: _asString(
          medicineRepo?['generic_name'],
          fallback: _asString(productIdentity?['genericName']),
        ),
      ),
      'medicine_code': _asString(
        row['medicine_code'],
        fallback: _asString(
          medicineRepo?['medicine_code'],
          fallback: _asString(productIdentity?['medicineCode']),
        ),
      ),
      'product_name': productName,
      'sku_name': _asString(row['sku_name']),
      'pricing_unit': primaryUnit,
      'purchase_price_from_brand': _asDouble(row['purchase_price_from_brand']),
      'purchase_rate': _asDouble(row['purchase_rate']),
      'ptr': _asDouble(row['ptr'], fallback: sellPrice),
      'sell_price_to_retailer': sellPrice,
      'min_sell_price': _asDouble(row['min_sell_price']),
      'max_retail_price': mrp,
      'mrp': _asDouble(row['mrp'], fallback: mrp),
      'batch_number': _asString(row['batch_number']),
      'expiry_date': row['expiry_date'],
      'reorder_level': _asInt(row['reorder_level']),
      'last_movement_at': row['last_movement_at'],
      'last_movement_type': _asString(row['last_movement_type']),
      'brand_company': _asString(
        medicineRepo?['brand_company'],
        fallback: _asString(productIdentity?['brandCompany']),
      ),
      'manufacturer_name': _asString(
        medicineRepo?['manufacturer_name'],
        fallback: _asString(regulatoryDetails?['manufacturerName']),
      ),
      'marketer_name': _asString(
        medicineRepo?['marketer_name'],
        fallback: _asString(regulatoryDetails?['marketerName']),
      ),
      'composition_display': compositionDisplay,
      'ingredient_summary': ingredientSummary,
      'ingredients': ingredients,
      'dosage_form': _asString(
        medicineRepo?['dosage_form'],
        fallback: _asString(dosageMedicineType?['dosageForm']),
      ),
      'product_status': _asString(productIdentity?['productStatus']),
      'product_category': _asString(
        medicineRepo?['product_category'],
        fallback: _asString(productIdentity?['productCategory']),
      ),
      'product_description': productDescription,
      'therapeutic_class': _asString(productIdentity?['therapeuticClass']),
      'prescription_required': _asBool(
        dosageMedicineType?['prescriptionRequired'],
      ),
      'drug_license_required_to_sell': _asBool(
        regulatoryDetails?['drugLicenseRequiredToSell'],
      ),
      'batch_tracking_required': _asBool(
        batchExpirySettings?['batchTrackingRequired'],
      ),
      'expiry_tracking_required': _asBool(
        batchExpirySettings?['expiryTrackingRequired'],
      ),
      'fefo_required': _asBool(batchExpirySettings?['fefoRequired']),
      'raw_product_identity': productIdentity,
      'raw_composition_strength': compositionStrength,
      'raw_medicine_repository': medicineRepo,
    };

    return SkuProduct.fromJson({
      'id': row['id'],
      'name': productName,
      'sku_code': skuCode,
      'category': _asString(
        medicineRepo?['product_category'],
        fallback: _asString(productIdentity?['productCategory']),
      ),
      'variant': null,
      'hsn_code': _asString(pricingTax?['hsnCode']),
      'primary_unit': primaryUnit,
      'alternative_units': _buildAlternativeUnits(
        primaryUnit: primaryUnit,
        medicineRepo: medicineRepo ?? <String, dynamic>{},
      ),
      'image_path': null,
      'info': info,
      'status': 'Active',
      'brand_id': row['brand_id'],
      'tax_slab': _asString(pricingTax?['gstPercent']),
      'sub_brand_id': null,
      'variants': [variant],
      'current_stock': currentStock,
      'reserved_stock': reservedStock,
      'sell_price_to_retailer': sellPrice,
      'max_retail_price': mrp,
      'allow_selling_in_alternative_unit': true,
      'allow_order_beyond_stock': false,
      'medicine_repository': medicineRepo,
    });
  }

  static Future<List<SkuProduct>> loadProductsForDistributor(
    String distributorId,
  ) async {
    try {
      final rows =
          await _supabase
                  .from('inventory_pharma_stock')
                  .select('''
                id,
                distributor_id,
                brand_id,
                medicine_repository_id,
                brand_name,
                sku_code,
                sku_name,
                current_stock,
                reserved_stock,
                reorder_level,
                pricing_unit,
                purchase_price_from_brand,
                sell_price_to_retailer,
                min_sell_price,
                max_retail_price,
                last_movement_at,
                last_movement_type,
                created_at,
                updated_at,
                medicine_code,
                product_name,
                generic_name,
                variant_sku_code,
                batch_number,
                expiry_date,
                purchase_rate,
                ptr,
                mrp,
                medicine_repository:medicine_repository_id (
                  id,
                  medicine_code,
                  slug,
                  product_identity,
                  composition_strength,
                  dosage_medicine_type,
                  pack_uom,
                  pricing_tax,
                  storage_handling,
                  batch_expiry_settings,
                  regulatory_details,
                  documents_notes,
                  current_mrp,
                  current_mrp_effective_from,
                  current_mrp_updated_at,
                  brand_company,
                  generic_name,
                  product_name,
                  manufacturer_name,
                  marketer_name,
                  composition_display,
                  dosage_form,
                  product_category,
                  status,
                  verification_status
                )
              ''')
                  .eq('distributor_id', distributorId)
                  .order('product_name', ascending: true)
              as List;

      if (rows.isEmpty) return [];

      final products = rows
          .map(
            (e) => _buildProductFromInventoryRow(Map<String, dynamic>.from(e)),
          )
          .toList();

      products.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      return products;
    } catch (e) {
      print('PharmaDistributorService.loadProducts error: $e');
      return [];
    }
  }

  static Future<List<PharmaDistributor>> loadDistributorsWithProducts({
    required String? pincode,
    required String? city,
    required String? state,
  }) async {
    final distRows = await findDistributors(
      pincode: pincode,
      city: city,
      state: state,
    );

    if (distRows.isEmpty) return [];

    final futures = distRows.map((row) async {
      final id = row['id'] as String;
      final products = await loadProductsForDistributor(id);

      return PharmaDistributor(
        id: id,
        companyName: row['company_name'] as String,
        companyPhone: row['company_phone'] as String?,
        logoCompactUrl: row['logo_compact_url'] as String?,
        allowOrderBeyondAvailableSkus:
            row['allow_order_beyond_available_skus'] as bool? ?? false,
        pharmaExpectedDelivery:
            (row['pharma_expected_delivery'] as String?) ?? 'same_day',
        pharmaSameDayOrderCutoff:
            row['pharma_same_day_order_cutoff'] as String?,
        pharmaMinimumOrderValue:
            ((row['pharma_minimum_order_value'] as num?) ?? 0).toDouble(),
        products: products,
      );
    });

    return await Future.wait(futures);
  }
}
