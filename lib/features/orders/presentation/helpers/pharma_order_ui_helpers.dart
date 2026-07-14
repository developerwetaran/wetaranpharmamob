import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wetaran_pharma/models/sku_model.dart';

String pharmaImageUrl(String path) {
  if (path.startsWith('http')) return path;
  return Supabase.instance.client.storage.from('products').getPublicUrl(path);
}

String normalizeText(String? value) {
  return (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String normalizeLoose(String? value) {
  return (value ?? '').trim().toLowerCase();
}

String cleanPackSuffix(String input) {
  var s = normalizeLoose(input);

  const stripTokens = [
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

  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String mergedProductKey(SkuProduct product) {
  final info = product.info ?? <String, dynamic>{};

  final repoId = normalizeLoose(info['medicine_repository_id']?.toString());
  if (repoId.isNotEmpty) return 'repo:$repoId';

  final medCode = normalizeLoose(info['medicine_code']?.toString());
  if (medCode.isNotEmpty) return 'med:$medCode';

  final generic = cleanPackSuffix(info['generic_name']?.toString() ?? '');
  final dosage = normalizeLoose(info['dosage_form']?.toString());
  final name = cleanPackSuffix(product.name);
  final sku = normalizeLoose(product.skuCode);

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

bool matchesSearch(SkuProduct product, String query) {
  if (query.isEmpty) return true;

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

  return fields.any((f) => f.contains(query));
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
