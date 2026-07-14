import 'package:wetaran_pharma/features/orders/services/pharma_distributor_service.dart';
import 'package:wetaran_pharma/models/sku_model.dart';

class DistributorProductLink {
  final PharmaDistributor distributor;
  final SkuProduct product;

  const DistributorProductLink({
    required this.distributor,
    required this.product,
  });
}

class MergedSkuGroup {
  final String key;
  final SkuProduct sample;
  final List<DistributorProductLink> offers;

  const MergedSkuGroup({
    required this.key,
    required this.sample,
    required this.offers,
  });
}

class VariantOfferBundle {
  final PharmaDistributor distributor;
  final SkuProduct product;
  final SkuVariant variant;

  const VariantOfferBundle({
    required this.distributor,
    required this.product,
    required this.variant,
  });
}
