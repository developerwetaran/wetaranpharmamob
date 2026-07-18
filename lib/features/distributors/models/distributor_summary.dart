class DistributorSummary {
  final String id;
  final String companyName;
  final String companyPhone;
  final String companyEmail;
  final String contactName;
  final String contactPhone;
  final String contactEmail;
  final String gstin;
  final String drugLicenseNo;
  final String registeredOfficeAddress;
  final String warehouseAddress;
  final String partnerType;
  final String status;
  final bool isActive;
  final int orderCount;
  final double totalOrderedValue;
  final int totalItems;
  final Map<String, dynamic> serviceCoverage;
  final String pharmaExpectedDelivery;
  final String pharmaSameDayOrderCutoff;

  DistributorSummary({
    required this.id,
    required this.companyName,
    required this.companyPhone,
    required this.companyEmail,
    required this.contactName,
    required this.contactPhone,
    required this.contactEmail,
    required this.gstin,
    required this.drugLicenseNo,
    required this.registeredOfficeAddress,
    required this.warehouseAddress,
    required this.partnerType,
    required this.status,
    required this.isActive,
    required this.orderCount,
    required this.totalOrderedValue,
    required this.totalItems,
    required this.serviceCoverage,
    required this.pharmaExpectedDelivery,
    required this.pharmaSameDayOrderCutoff,
  });
}

class DistributorSummaryBuilder {
  final String id;
  final String companyName;
  final String companyPhone;
  final String companyEmail;
  final String contactName;
  final String contactPhone;
  final String contactEmail;
  final String gstin;
  final String drugLicenseNo;
  final String registeredOfficeAddress;
  final String warehouseAddress;
  final String partnerType;
  final String status;
  final bool isActive;
  final Map<String, dynamic> serviceCoverage;
  final String pharmaExpectedDelivery;
  final String pharmaSameDayOrderCutoff;

  int orderCount = 0;
  double totalOrderedValue = 0;
  int totalItems = 0;

  DistributorSummaryBuilder({
    required this.id,
    required this.companyName,
    required this.companyPhone,
    required this.companyEmail,
    required this.contactName,
    required this.contactPhone,
    required this.contactEmail,
    required this.gstin,
    required this.drugLicenseNo,
    required this.registeredOfficeAddress,
    required this.warehouseAddress,
    required this.partnerType,
    required this.status,
    required this.isActive,
    required this.serviceCoverage,
    required this.pharmaExpectedDelivery,
    required this.pharmaSameDayOrderCutoff,
  });

  DistributorSummary build() {
    return DistributorSummary(
      id: id,
      companyName: companyName,
      companyPhone: companyPhone,
      companyEmail: companyEmail,
      contactName: contactName,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      gstin: gstin,
      drugLicenseNo: drugLicenseNo,
      registeredOfficeAddress: registeredOfficeAddress,
      warehouseAddress: warehouseAddress,
      partnerType: partnerType,
      status: status,
      isActive: isActive,
      orderCount: orderCount,
      totalOrderedValue: totalOrderedValue,
      totalItems: totalItems,
      serviceCoverage: serviceCoverage,
      pharmaExpectedDelivery: pharmaExpectedDelivery,
      pharmaSameDayOrderCutoff: pharmaSameDayOrderCutoff,
    );
  }
}
