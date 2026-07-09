class PharmaUserProfile {
  final String id;
  final String? authUserId;
  final String businessName;
  final String businessType;
  final String email;
  final String phoneNumber;
  final String? businessAddress;
  final String? businessCity;
  final String? businessState;
  final String? businessPincode;
  final String? drugLicenseNumber;
  final String? gstNumber;
  final String? contactPersonName;
  final String profileStatus;
  final bool canPlaceMedicineOrders;
  final bool emailVerified;

  const PharmaUserProfile({
    required this.id,
    this.authUserId,
    required this.businessName,
    required this.businessType,
    required this.email,
    required this.phoneNumber,
    this.businessAddress,
    this.businessCity,
    this.businessState,
    this.businessPincode,
    this.drugLicenseNumber,
    this.gstNumber,
    this.contactPersonName,
    required this.profileStatus,
    required this.canPlaceMedicineOrders,
    required this.emailVerified,
  });

  factory PharmaUserProfile.fromMap(Map<String, dynamic> map) {
    return PharmaUserProfile(
      id: map['id'] as String,
      authUserId: map['auth_user_id'] as String?,
      businessName: map['business_name'] as String? ?? '',
      businessType: map['business_type'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phoneNumber: map['phone_number'] as String? ?? '',
      businessAddress: map['business_address'] as String?,
      businessCity: map['business_city'] as String?,
      businessState: map['business_state'] as String?,
      businessPincode: map['business_pincode'] as String?,
      drugLicenseNumber: map['drug_license_number'] as String?,
      gstNumber: map['gst_number'] as String?,
      contactPersonName: map['contact_person_name'] as String?,
      profileStatus: map['profile_status'] as String? ?? 'incomplete',
      canPlaceMedicineOrders:
          map['can_place_medicine_orders'] as bool? ?? false,
      emailVerified: map['email_verified'] as bool? ?? false,
    );
  }

  String get locationLine {
    final parts = [
      if (businessCity != null && businessCity!.isNotEmpty) businessCity,
    ];
    return parts.join(', ');
  }
}
