import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wetaran_pharma/core/config/app_constants.dart';
import 'package:wetaran_pharma/core/widgets/pharma_auth_shell.dart';
import 'package:wetaran_pharma/features/auth/presentation/pages/login_page.dart';
import 'package:wetaran_pharma/features/home/presentation/pages/main_shell.dart';

class CompleteProfilePage extends StatefulWidget {
  final String email;
  final String businessName;
  final bool allowBack;

  const CompleteProfilePage({
    super.key,
    required this.email,
    required this.businessName,
    this.allowBack = true,
  });

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _businessNameController;
  late final TextEditingController _emailController;

  final _phoneNumberController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _drugLicenseNumberController = TextEditingController();
  final _contactPersonNameController = TextEditingController();
  final _gstNumberController = TextEditingController();
  final _areaController = TextEditingController();
  final _businessCityController = TextEditingController();
  final _businessStateController = TextEditingController();
  final _businessPincodeController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  String? _selectedBusinessType;
  String? _existingLicenseUrl;

  File? _licenseFile;

  File? _gstFile;
  String? _existingGstUrl;
  bool _clientAgreementAccepted = false;
  String? _clientAgreementUrl;
  DateTime? _clientAgreementAcceptedAt;
  String _clientAgreementVersion = '1.0';
  bool _isAgreementLoading = false;

  final List<_BusinessTypeOption> _businessTypes = const [
    _BusinessTypeOption(value: 'chemist_store', label: 'Chemist Store'),
    _BusinessTypeOption(value: 'hospital', label: 'Hospital'),
    _BusinessTypeOption(value: 'clinic', label: 'Clinic'),
  ];

  SupabaseClient get _supabase => Supabase.instance.client;

  static const Color bg = Color(0xFFEFF3FA);
  static const Color white = Colors.white;
  static const Color ink = Color(0xFF10233F);
  static const Color inkSoft = Color(0xFF5B6B85);
  static const Color inkFaint = Color(0xFF8C9AB1);

  static const Color teal600 = Color(0xFF0D9488);
  static const Color teal500 = Color(0xFF14B8A6);
  static const Color teal50 = Color(0xFFE9FBF8);

  static const Color green600 = Color(0xFF15803D);

  static const Color line = Color(0xFFE3E9F3);
  static const Color lockedBg = Color(0xFFF4F7FC);
  static const Color uploadBg = Color(0xFFF7FAFF);

  bool _isAddressLoading = false;
  double? _geoLatitude;
  double? _geoLongitude;
  String? _geoFormattedAddress;

  @override
  void initState() {
    super.initState();
    _businessNameController = TextEditingController(text: widget.businessName);
    _emailController = TextEditingController(text: widget.email);
    _loadProfile();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _businessAddressController.dispose();
    _drugLicenseNumberController.dispose();
    _contactPersonNameController.dispose();
    _gstNumberController.dispose();
    _businessCityController.dispose();
    _businessStateController.dispose();
    _businessPincodeController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<String?> _uploadDrugLicenseIfNeeded() async {
    if (_licenseFile == null) {
      return _existingLicenseUrl;
    }

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User session not found');

    final fileName =
        'drug_license_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final storagePath = 'pharma-documents/$userId/$fileName';

    await _supabase.storage.from('products').upload(storagePath, _licenseFile!);

    return _supabase.storage.from('products').getPublicUrl(storagePath);
  }

  Future<String?> _uploadGstIfNeeded() async {
    if (_gstFile == null) {
      return _existingGstUrl;
    }

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User session not found');

    final fileName =
        'gst_certificate_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final storagePath = 'pharma-documents/$userId/$fileName';

    await _supabase.storage.from('products').upload(storagePath, _gstFile!);

    return _supabase.storage.from('products').getPublicUrl(storagePath);
  }

  Future<void> _fetchAndFillAddress() async {
    setState(() => _isAddressLoading = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError(
          'Location permission permanently denied. Please enable it from settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final lat = position.latitude;
      final lng = position.longitude;

      final apiKey = AppConstants.googleMapsApiKey;
      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'latlng': '$lat,$lng',
        'key': apiKey,
      });

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      debugPrint('Reverse geocode response: ${response.body}');

      final status = data['status']?.toString();
      final results = (data['results'] as List?) ?? [];
      final errorMessage = data['error_message']?.toString();

      if (status == 'OK' && results.isNotEmpty) {
        final firstResult = results.first as Map<String, dynamic>;
        final formattedAddress = (firstResult['formatted_address'] ?? '')
            .toString()
            .trim();

        final components =
            (firstResult['address_components'] as List?) ?? const [];

        final area =
            _getAddressComponent(components, ['sublocality_level_1']) ??
            _getAddressComponent(components, ['sublocality']) ??
            _getAddressComponent(components, ['neighborhood']) ??
            _getAddressComponent(components, ['administrative_area_level_2']);

        final city =
            _getAddressComponent(components, ['locality']) ??
            _getAddressComponent(components, ['administrative_area_level_3']) ??
            _getAddressComponent(components, ['administrative_area_level_2']);

        final stateRaw = _getAddressComponent(components, [
          'administrative_area_level_1',
        ]);

        final normalizedState = _normalizeIndianState(stateRaw);

        final pincode = _getAddressComponent(components, ['postal_code']);

        if (formattedAddress.isEmpty) {
          throw Exception('Formatted address is empty');
        }
        final resolvedArea = (area != null && area != city) ? area : '';
        setState(() {
          _geoLatitude = lat;
          _geoLongitude = lng;
          _geoFormattedAddress = formattedAddress;
          _businessAddressController.text = formattedAddress;
          _areaController.text = resolvedArea;
          _businessCityController.text = city ?? '';
          _businessPincodeController.text = pincode ?? '';
          _businessStateController.text = normalizedState ?? '';
        });
      } else {
        throw Exception(
          'Reverse geocoding failed. status=$status error=${errorMessage ?? "none"}',
        );
      }
    } catch (e) {
      _showError('Error getting location: $e');
    } finally {
      if (mounted) {
        setState(() => _isAddressLoading = false);
      }
    }
  }

  String? _getAddressComponent(
    List<dynamic> components,
    List<String> targetTypes, {
    bool useShortName = false,
  }) {
    for (final component in components) {
      final types = List<String>.from(component['types'] ?? const []);
      final matches = targetTypes.any(types.contains);
      if (matches) {
        return (useShortName ? component['short_name'] : component['long_name'])
            ?.toString()
            .trim();
      }
    }
    return null;
  }

  String? _normalizeIndianState(String? raw) {
    if (raw == null) return null;

    final value = raw.trim().toLowerCase();

    const map = {
      'andhra pradesh': 'Andhra Pradesh',
      'arunachal pradesh': 'Arunachal Pradesh',
      'assam': 'Assam',
      'bihar': 'Bihar',
      'chhattisgarh': 'Chhattisgarh',
      'goa': 'Goa',
      'gujarat': 'Gujarat',
      'haryana': 'Haryana',
      'himachal pradesh': 'Himachal Pradesh',
      'jharkhand': 'Jharkhand',
      'karnataka': 'Karnataka',
      'kerala': 'Kerala',
      'madhya pradesh': 'Madhya Pradesh',
      'maharashtra': 'Maharashtra',
      'manipur': 'Manipur',
      'meghalaya': 'Meghalaya',
      'mizoram': 'Mizoram',
      'nagaland': 'Nagaland',
      'odisha': 'Odisha',
      'orissa': 'Odisha',
      'punjab': 'Punjab',
      'rajasthan': 'Rajasthan',
      'sikkim': 'Sikkim',
      'tamil nadu': 'Tamil Nadu',
      'telangana': 'Telangana',
      'tripura': 'Tripura',
      'uttar pradesh': 'Uttar Pradesh',
      'uttarakhand': 'Uttarakhand',
      'uttaranchal': 'Uttarakhand',
      'west bengal': 'West Bengal',
      'andaman and nicobar islands': 'Andaman & Nicobar Islands',
      'andaman & nicobar islands': 'Andaman & Nicobar Islands',
      'chandigarh': 'Chandigarh',
      'dadra and nagar haveli and daman and diu':
          'Dadra & Nagar Haveli and Daman & Diu',
      'dadra & nagar haveli and daman & diu':
          'Dadra & Nagar Haveli and Daman & Diu',
      'delhi': 'Delhi',
      'nct of delhi': 'Delhi',
      'national capital territory of delhi': 'Delhi',
      'jammu and kashmir': 'Jammu & Kashmir',
      'jammu & kashmir': 'Jammu & Kashmir',
      'ladakh': 'Ladakh',
      'lakshadweep': 'Lakshadweep',
      'puducherry': 'Puducherry',
      'pondicherry': 'Puducherry',
    };

    return map[value];
  }

  Future<void> _loadProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User session not found');
      }

      final row = await _supabase
          .from('pharma_users')
          .select()
          .eq('auth_user_id', userId)
          .maybeSingle();

      if (row != null) {
        _businessNameController.text =
            (row['business_name'] ?? widget.businessName).toString();
        _emailController.text = (row['email'] ?? widget.email).toString();
        _phoneNumberController.text = (row['phone_number'] ?? '').toString();
        _businessAddressController.text = (row['business_address'] ?? '')
            .toString();
        _drugLicenseNumberController.text = (row['drug_license_number'] ?? '')
            .toString();
        _contactPersonNameController.text = (row['contact_person_name'] ?? '')
            .toString();
        _gstNumberController.text = (row['gst_number'] ?? '').toString();
        _areaController.text = (row['area'] ?? '').toString();
        _businessCityController.text = (row['business_city'] ?? '').toString();
        _businessStateController.text = (row['business_state'] ?? '')
            .toString();
        _businessPincodeController.text = (row['business_pincode'] ?? '')
            .toString();
        _selectedBusinessType = row['business_type']?.toString();

        _existingLicenseUrl = row['drug_license_copy_url']?.toString();
        _existingGstUrl = row['gst_certificate_url']?.toString();

        _clientAgreementUrl = row['client_service_agreement_url']?.toString();
        _clientAgreementVersion =
            (row['client_service_agreement_version'] ?? '1.0').toString();

        final acceptedAtText = row['client_service_agreement_accepted_at']
            ?.toString();
        if (acceptedAtText != null && acceptedAtText.isNotEmpty) {
          _clientAgreementAcceptedAt = DateTime.tryParse(acceptedAtText);
        }

        _clientAgreementAccepted =
            (_clientAgreementUrl ?? '').isNotEmpty ||
            _clientAgreementAcceptedAt != null;

        final geoLocationText = row['geo_location']?.toString();
        if (geoLocationText != null && geoLocationText.trim().isNotEmpty) {
          final parts = geoLocationText.split(',');
          if (parts.length == 2) {
            _geoLatitude = double.tryParse(parts[0].trim());
            _geoLongitude = double.tryParse(parts[1].trim());
          }
        }
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load profile: $error'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openPdfUrl(String? url) async {
    if (url == null || url.isEmpty) {
      _showError('PDF not available');
      return;
    }

    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showError('Could not open PDF');
    }
  }

  Future<void> _pickLicenseFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;

      if (pickedFile.path == null || pickedFile.path!.isEmpty) {
        _showError('Unable to read selected PDF file');
        return;
      }

      setState(() {
        _licenseFile = File(pickedFile.path!);
      });
    } catch (error) {
      _showError('Failed to pick PDF: $error');
    }
  }

  Future<String?> _uploadLicenseIfNeeded() async {
    if (_licenseFile == null) {
      return _existingLicenseUrl;
    }

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User session not found');
    }

    final fileExt = _licenseFile!.path.split('.').last.toLowerCase();
    if (fileExt != 'pdf') {
      throw Exception('Only PDF files are allowed');
    }

    final fileName =
        'drug_license_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final storagePath = 'pharma-documents/$userId/$fileName';

    await _supabase.storage.from('products').upload(storagePath, _licenseFile!);

    return storagePath;
  }

  Future<void> _showClientServiceAgreementDialog() async {
    final agreementText = _buildClientServiceAgreementText(
      businessName: _businessNameController.text.trim(),
      entityType: _selectedBusinessType ?? '',
      contactPerson: _contactPersonNameController.text.trim(),
      gstNumber: _gstNumberController.text.trim(),
      drugLicense: _drugLicenseNumberController.text.trim(),
      address: _businessAddressController.text.trim(),
      acceptedAtText: _formatAgreementTimestamp(DateTime.now()),
    );

    bool accepted = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.88,
                  maxWidth: 900,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Client Service Agreement',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Version 1.0 · Retailer Service Agreement',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF5B6B85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          agreementText,
                          style: const TextStyle(fontSize: 13.2, height: 1.55),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: accepted,
                            onChanged: (v) =>
                                setState(() => accepted = v ?? false),
                          ),
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Text(
                                'I have reviewed and accept the terms of the Client Service Agreement.',
                                style: TextStyle(fontSize: 12.8, height: 1.35),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: accepted
                                  ? () async {
                                      Navigator.of(dialogContext).pop();
                                      await _acceptClientServiceAgreement();
                                    }
                                  : null,
                              child: const Text('Accept'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatAgreementTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour >= 12 ? 'pm' : 'am';
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$day $month $year ${hour.toString().padLeft(2, '0')}:$minute:$second $ampm';
  }

  Future<Uint8List> _generateAgreementPdf(
    String agreementText, {
    required String title,
  }) async {
    final pdf = pw.Document();
    final sections = agreementText
        .split('\n\n')
        .where((e) => e.trim().isNotEmpty)
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            ...sections.map(
              (s) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  s,
                  style: const pw.TextStyle(fontSize: 9.8, height: 1.4),
                ),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  String _buildClientServiceAgreementText({
    required String businessName,
    required String entityType,
    required String contactPerson,
    required String gstNumber,
    required String drugLicense,
    required String address,
    required String acceptedAtText,
  }) {
    return '''
RETAILER SERVICE AGREEMENT - Wetaran Tech Private Limited
Version 1.0
This Service Agreement ("Agreement") is entered into between:
Wetaran Tech Private Limited, a company incorporated under the Companies Act, 2013, having its registered office at Dynasty Business Park Level 4, A-Wing, Andheri Kurla Road, Andheri East 400059, Mumbai, Maharashtra ("Wetaran", the "Service Provider"), operator of the Wetaran Pharma platform (web and mobile applications) ("Platform"); and
$businessName, being a $entityType, having its principal place of business at $address, holding GSTIN $gstNumber and Drug Licence No(s). $drugLicense (the "Client").
Effective Date: $acceptedAtText

1. Scope of Services
1.1 Wetaran shall provide the Client the following technology services through the Platform ("Services"):
(a) Marketplace access - access to a central medicine repository through which the Client can browse products and compare verified pharmaceutical distributors ("Distributors") on price, stock availability, and delivery time;
(b) Ordering services - placement of purchase orders with one or more Distributors; each order placed with a Distributor generates its own unique order number and is fulfilled and invoiced by that Distributor separately;
(c) Order tracking - status updates from order placement to delivery;
(d) Scheme benefits - where a manufacturer or brand routes trade scheme benefits through the Platform, such benefits are passed through to the Client as trade benefits (trade discount, bonus units, or credit note) on qualifying orders;
(e) Rewards - cashback or reward programs on qualifying orders, as per Clause 6;
(f) Verified counterparties - Distributors on the Platform are onboarded subject to dual verification of GST and drug licence;
(g) Support - account and technical support during business hours.
1.2 Wetaran provides technology services only. Wetaran is an intermediary under the Information Technology Act, 2000 and is not the seller, stockist, or agent of any Distributor. Every purchase concluded through the Platform is a direct contract between the Client and the relevant Distributor; title, risk, invoicing, and payment for goods flow directly between them.

2. Service Availability
2.1 Wetaran shall use commercially reasonable efforts to keep the Platform available 24x7, excluding scheduled maintenance (notified in advance where practicable) and events beyond Wetaran's reasonable control.
2.2 The Services are provided on an "as is" basis during the current beta phase; features may be added, modified, or withdrawn with notice.

3. Fees
3.1 The Services are currently provided free of charge to the Client. No subscription, ordering, or transaction fees are presently payable.
3.2 Wetaran may introduce fees for specific Services with at least 30 days' prior written notice. Continued use after the effective date of a fee schedule constitutes acceptance; the Client may terminate under Clause 10 if it does not accept.
3.3 The price payable for goods is the Distributor's price displayed at the time of order, payable by the Client directly to the Distributor on the payment terms displayed.

4. Client Eligibility & Verification
4.1 The Client must at all times hold and maintain:
(a) a valid Drug Licence appropriate to its establishment (retail sale licence in Forms 20/21 or equivalent, or the licence/registration applicable to a hospital or clinic dispensing establishment) under the Drugs and Cosmetics Act, 1940 and Rules, 1945; and
(b) a valid GST registration.
4.2 Access to Services is subject to Wetaran's dual verification of GST and drug licence at sign-up. The Client shall promptly notify Wetaran of any suspension, cancellation, expiry, or modification of any licence; Wetaran may suspend Services immediately upon any lapse.
4.3 The account is for the Client entity's business use only. The Client is responsible for the confidentiality of its credentials and for all activity under its account.

5. Client Obligations
5.1 Licensed purchasing only. The Client shall purchase products solely for dispensing, sale, or use as permitted by its licence(s), and shall not purchase products it is not licensed to stock, dispense, or sell (including scheduled drugs outside the scope of its licence).
5.2 No unauthorised resale. Products purchased through the Platform shall not be diverted, re-exported, or resold in violation of applicable law.
5.3 Payment. The Client shall pay each Distributor in full as per the payment terms accepted at the time of order. Wetaran is not a party to, does not collect (unless expressly stated on the Platform), and does not guarantee any payment.
5.4 Receipt of goods. The Client shall inspect goods on delivery and raise any short-supply, damage, or discrepancy claim through the Platform within 48 hours of delivery.
5.5 Accurate information. All information and documents provided to Wetaran, including licence and GST details and structured address information, shall be true, complete, and kept current.
5.6 Compliance. The Client shall comply with all applicable laws, including the Drugs and Cosmetics Act, 1940 and Rules, 1945, and GST laws, in its purchase, storage, and dispensing of products.

6. Rewards & Scheme Benefits
6.1 Cashback and reward programs are promotional, funded and administered by Wetaran and/or participating brands, and may be modified, suspended, or withdrawn prospectively at any time with notice. Accrued benefits will be honoured.
6.2 All scheme benefits, cashback, and rewards are extended to the Client entity as trade benefits and shall be applied to the entity's account. No benefit under this Agreement constitutes, and none shall be claimed or used as, a personal payment, gift, or inducement to any individual medical practitioner, in line with the Uniform Code of Pharmaceutical Marketing Practices (UCPMP) and applicable law.
6.3 Rewards misuse, including fake orders, self-dealing, split orders to game thresholds, or misrepresentation entitles Wetaran to reverse benefits and suspend or terminate the account.

7. Data & Privacy
7.1 The Client grants Wetaran a non-exclusive, royalty-free licence to use transactional data generated on the Platform (orders, products, quantities, fulfilment) to provide the Services, administer schemes and rewards, and produce aggregated and anonymised analytics and market intelligence.
7.2 Each party shall comply with the Digital Personal Data Protection Act, 2023. Wetaran processes personal data of the Client's authorised users per its Privacy Policy. Analytics describe medication demand patterns at an aggregated level; the Platform does not collect or process patient-level data.

8. Returns, Disputes & Wetaran's Role
8.1 Returns of damaged, short-supplied, wrongly supplied, or recalled products are governed by the relevant Distributor's returns obligations and stated policy; the Client shall raise returns through the Platform within the applicable window.
8.2 Disputes regarding goods, quality, invoicing, or delivery are between the Client and the Distributor. Wetaran will facilitate resolution through the Platform's process but is not liable for the goods, their quality, or the Distributor's performance.
8.3 Product information in the central medicine repository is compiled from manufacturer and public sources for identification and ordering convenience; it is not medical advice, and the Client remains responsible for its own professional dispensing decisions.

9. Warranties, Indemnity & Limitation of Liability
9.1 The Client represents and warrants that it has authority to enter this Agreement, that all licences and documents furnished are valid, true, and complete, and that its use of the Services will comply with applicable law.
9.2 The Client shall indemnify and hold harmless Wetaran, its directors, and employees from any claim, penalty, loss, or expense (including legal costs) arising from:
(a) breach of this Agreement or applicable law;
(b) invalidity or misuse of any licence;
(c) misuse of rewards or the account; or
(d) the Client's dispensing, storage, or onward sale of products.
9.3 Wetaran does not warrant uninterrupted or error-free operation, the availability of any product or Distributor, or any price level. Wetaran shall not be liable for indirect, incidental, or consequential losses, loss of profit, or loss of business. Wetaran's aggregate liability under this Agreement shall not exceed INR 25,000 or the fees paid by the Client to Wetaran in the preceding 12 months, whichever is higher.

10. Term, Suspension & Termination
10.1 This Agreement is effective from the Effective Date and continues until terminated.
10.2 Either party may terminate for convenience with 30 days' written notice. Orders placed before termination remain binding between the Client and the relevant Distributor.
10.3 Wetaran may suspend or terminate the Services immediately upon:
(a) lapse or cancellation of any Client licence;
(b) purchase attempts outside licence scope;
(c) rewards misuse or fraud;
(d) repeated payment defaults reported by Distributors; or
(e) breach not cured within 15 days of notice.
10.4 On termination, access ceases and unaccrued promotional benefits lapse; Clauses 7, 9, 11, and 12 survive.

11. Confidentiality & Intellectual Property
11.1 Each party shall keep confidential the other's non-public business information and use it only for purposes of this Agreement.
11.2 The Platform, its software, medicine repository, trademarks, and all Wetaran branding remain Wetaran's exclusive property. The Client receives only a limited, non-transferable right to use the Platform during the term.

12. Governing Law & Dispute Resolution
12.1 This Agreement is governed by the laws of India.
12.2 Disputes between Wetaran and the Client shall first be attempted to be resolved amicably within 30 days, failing which they shall be referred to arbitration by a sole arbitrator under the Arbitration and Conciliation Act, 1996. Seat and venue: Mumbai. Language: English. Subject to arbitration, courts at Mumbai shall have exclusive jurisdiction.

13. General
13.1 Notices shall be in writing to the addresses/emails stated above.
13.2 Force majeure: neither party is liable for delay caused by events beyond reasonable control.
13.3 Assignment: the Client may not assign this Agreement without Wetaran's written consent.
13.4 Relationship: the parties are independent contractors; nothing creates an agency, partnership, or employment relationship.
13.5 Amendments: Wetaran may update Platform policies with notice; material amendments to this Agreement require 30 days' notice.
13.6 Entire agreement: this Agreement, together with the Platform Terms of Use and Privacy Policy, constitutes the entire agreement and supersedes prior discussions.

ACCEPTANCE
I have reviewed and accept the terms of the Client Service Agreement.
Client / Retailer Legal Name: $businessName
Entity Type: $entityType
Authorised Contact Person: $contactPerson
GSTIN: $gstNumber
Drug Licence No(s).: $drugLicense
Principal Place of Business: $address
Client acceptance timestamp (IST): $acceptedAtText
''';
  }

  Future<void> _acceptClientServiceAgreement() async {
    if (_isAgreementLoading) return;

    setState(() => _isAgreementLoading = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User session not found');

      final row = await _supabase
          .from('pharma_users')
          .select(
            'client_service_agreement_url, client_service_agreement_accepted_at, client_service_agreement_version',
          )
          .eq('auth_user_id', userId)
          .maybeSingle();

      if (row != null) {
        final existingUrl = (row['client_service_agreement_url'] ?? '')
            .toString();
        if (existingUrl.isNotEmpty) {
          _clientAgreementUrl = existingUrl;
          _clientAgreementAccepted = true;
          _clientAgreementAcceptedAt = DateTime.tryParse(
            (row['client_service_agreement_accepted_at'] ?? '').toString(),
          );
          _clientAgreementVersion =
              (row['client_service_agreement_version'] ?? '1.0').toString();

          if (mounted) setState(() {});
          return;
        }
      }

      _clientAgreementAccepted = true;
      _clientAgreementAcceptedAt = DateTime.now().toUtc();

      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      _showError('Failed to accept agreement: $error');
    } finally {
      if (!mounted) return;
      setState(() => _isAgreementLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    if (_selectedBusinessType == null) {
      _showError('Please select a business type');
      return;
    }

    if (!_clientAgreementAccepted) {
      _showError('Please review and accept the Client Service Agreement');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User session not found');
      }

      final drugLicenseUrl = await _uploadDrugLicenseIfNeeded();
      final gstUrl = await _uploadGstIfNeeded();

      final businessName = _businessNameController.text.trim();
      final phoneNumber = _phoneNumberController.text.trim();
      final businessAddress = _businessAddressController.text.trim();
      final drugLicenseNumber = _drugLicenseNumberController.text.trim();
      final gstNumber = _gstNumberController.text.trim();
      final contactPersonName = _contactPersonNameController.text.trim();
      final businessCity = _businessCityController.text.trim();
      final businessState = _businessStateController.text.trim();
      final businessPincode = _businessPincodeController.text.trim();

      final geoLocation = (_geoLatitude != null && _geoLongitude != null)
          ? '${_geoLatitude!.toStringAsFixed(6)},${_geoLongitude!.toStringAsFixed(6)}'
          : null;

      final isProfileComplete =
          businessName.isNotEmpty &&
          (_selectedBusinessType?.trim().isNotEmpty ?? false) &&
          phoneNumber.isNotEmpty &&
          businessAddress.isNotEmpty &&
          drugLicenseNumber.isNotEmpty &&
          (drugLicenseUrl?.trim().isNotEmpty ?? false) &&
          gstNumber.isNotEmpty &&
          contactPersonName.isNotEmpty &&
          businessCity.isNotEmpty &&
          businessState.isNotEmpty &&
          businessPincode.isNotEmpty;

      String? agreementUrl = _clientAgreementUrl;
      if (agreementUrl == null || agreementUrl.isEmpty) {
        final acceptedAt = _clientAgreementAcceptedAt ?? DateTime.now().toUtc();
        final acceptedAtText = _formatAgreementTimestamp(acceptedAt);

        final agreementText = _buildClientServiceAgreementText(
          businessName: businessName,
          entityType: _selectedBusinessType ?? '',
          contactPerson: contactPersonName,
          gstNumber: gstNumber,
          drugLicense: drugLicenseNumber,
          address: businessAddress,
          acceptedAtText: acceptedAtText,
        );

        final pdfBytes = await _generateAgreementPdf(
          agreementText,
          title: 'client-service-agreement-v1.0',
        );

        final fileName =
            'client-service-agreement-v1.0-${DateTime.now().millisecondsSinceEpoch}.pdf';
        final storagePath = 'pharma-documents/$userId/$fileName';

        await _supabase.storage
            .from('products')
            .uploadBinary(
              storagePath,
              pdfBytes,
              fileOptions: const FileOptions(contentType: 'application/pdf'),
            );

        agreementUrl = _supabase.storage
            .from('products')
            .getPublicUrl(storagePath);
        _clientAgreementUrl = agreementUrl;
        _clientAgreementAcceptedAt ??= acceptedAt;
      }

      await _supabase
          .from('pharma_users')
          .update({
            'business_name': businessName,
            'business_type': _selectedBusinessType,
            'phone_number': phoneNumber,
            'business_address': businessAddress,
            'drug_license_number': drugLicenseNumber,
            'gst_number': gstNumber,
            'contact_person_name': contactPersonName,
            'business_city': businessCity,
            'geo_location': geoLocation,
            'business_state': businessState,
            'business_pincode': businessPincode,
            'profile_status': isProfileComplete ? 'complete' : 'incomplete',
            'can_place_medicine_orders': isProfileComplete,
            'drug_license_copy_url': drugLicenseUrl,
            'gst_certificate_url': gstUrl,
            'client_service_agreement_url': agreementUrl,
            'client_service_agreement_accepted_at':
                _clientAgreementAcceptedAt?.toIso8601String() ??
                DateTime.now().toIso8601String(),
            'client_service_agreement_version': _clientAgreementVersion,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('auth_user_id', userId);

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      _showError('Failed to save profile: $error');
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  String _formatAcceptedOnLine(DateTime? dt, String version) {
    if (dt == null) return 'Accepted · v$version';

    final local = dt.toLocal();
    final day = local.day;
    final month = local.month;
    final year = local.year;
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'pm' : 'am';

    return 'Accepted on $day/$month/$year, $hour:$minute:$second $ampm · v$version';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _businessTypeLabel(String? value) {
    for (final type in _businessTypes) {
      if (type.value == value) return type.label;
    }
    return 'Select business type';
  }

  void _handleBlockedBack() {
    Future<void> _confirmExitDialog() async {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Complete your profile'),
          content: const Text(
            'Please finish your business details to continue. Do you want to sign out instead?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Stay'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sign out'),
            ),
          ],
        ),
      );

      if (shouldExit == true) {
        await _supabase.auth.signOut();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }

    _confirmExitDialog();
  }

  Future<void> _pickGstFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;

      if (pickedFile.path == null || pickedFile.path!.isEmpty) {
        _showError('Unable to read selected PDF file');
        return;
      }

      setState(() {
        _gstFile = File(pickedFile.path!);
      });
    } catch (error) {
      _showError('Failed to pick GST PDF: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedState =
        _indianStatesAndUts.contains(_businessStateController.text.trim())
        ? _businessStateController.text.trim()
        : null;

    return PopScope(
      canPop: widget.allowBack,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBlockedBack();
      },
      child: PharmaAuthShell(
        compactHero: true,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SignupBackButton(
                onTap: _isSaving
                    ? null
                    : (widget.allowBack
                          ? () => Navigator.of(context).pop()
                          : _handleBlockedBack),
                label: widget.allowBack ? 'Back' : 'Sign out',
              ),
              const SizedBox(height: 8),
              const _SignupProgress(step: 3),
              const SizedBox(height: 18),

              const Text(
                'Business details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ink,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Confirm your details and add your licenses for verification.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: inkSoft,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 18),

              const _FieldLabel('BUSINESS NAME'),
              const SizedBox(height: 7),
              _LockedInputShell(
                child: _LockedValueRow(
                  icon: Icons.business_outlined,
                  value: _businessNameController.text,
                ),
              ),

              const SizedBox(height: 16),

              const _FieldLabel('BUSINESS TYPE'),
              const SizedBox(height: 7),
              _LockedInputShell(
                child: _LockedValueRow(
                  icon: Icons.storefront_outlined,
                  value: _businessTypeLabel(_selectedBusinessType),
                ),
              ),

              const SizedBox(height: 16),

              const _FieldLabel('EMAIL ADDRESS'),
              const SizedBox(height: 7),
              _LockedInputShell(
                child: _LockedValueRow(
                  icon: Icons.mail_outline_rounded,
                  value: _emailController.text,
                ),
              ),

              const SizedBox(height: 16),

              const _FieldLabel('PHONE NUMBER', requiredField: true),
              const SizedBox(height: 7),
              _InputShell(
                child: Row(
                  children: [
                    Container(
                      height: 30,
                      margin: const EdgeInsets.only(left: 14),
                      padding: const EdgeInsets.only(right: 10),
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: line, width: 1.5),
                        ),
                      ),
                      child: const Row(
                        children: [
                          _IndiaFlagMini(),
                          SizedBox(width: 6),
                          Text(
                            '+91',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneNumberController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: ink,
                          letterSpacing: 0.4,
                        ),
                        decoration: _inputDecoration(
                          hintText: '9876543210',
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty) {
                            return 'Please enter phone number';
                          }
                          if (!RegExp(r'^\d{10}$').hasMatch(text)) {
                            return 'Enter a valid 10-digit phone number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const _FieldLabel('CONTACT PERSON NAME', requiredField: true),
              const SizedBox(height: 7),
              _InputShell(
                child: TextFormField(
                  controller: _contactPersonNameController,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: ink,
                  ),
                  decoration: _inputDecoration(
                    hintText: 'Enter contact person name',
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Please enter contact person name';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Business address',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),

              const SizedBox(height: 14),

              _GeoCaptureCard(
                isLoading: _isAddressLoading,
                onTap: _fetchAndFillAddress,
                address: _geoFormattedAddress,
                latitude: _geoLatitude,
                longitude: _geoLongitude,
              ),

              const SizedBox(height: 16),

              const _FieldLabel('ADDRESS LINE', requiredField: true),

              const SizedBox(height: 7),
              _InputShell(
                child: TextFormField(
                  controller: _businessAddressController,
                  keyboardType: TextInputType.multiline,
                  minLines: 2,
                  maxLines: 4,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: ink,
                  ),
                  decoration:
                      _inputDecoration(
                        hintText: 'Shop no., building, street',
                        prefixIcon: Icons.home_work_outlined,
                      ).copyWith(
                        alignLabelWithHint: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
                        ),
                      ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Please enter business address';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              const _FieldLabel('AREA', requiredField: false),
              const SizedBox(height: 7),

              _InputShell(
                child: TextFormField(
                  controller: _areaController,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: ink,
                  ),
                  decoration: _inputDecoration(
                    hintText: 'Area',
                    prefixIcon: Icons.area_chart_outlined,
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Please enter area';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 7),

              const _FieldLabel('CITY', requiredField: true),

              const SizedBox(height: 7),

              _InputShell(
                child: TextFormField(
                  controller: _businessCityController,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: ink,
                  ),
                  decoration: _inputDecoration(
                    hintText: 'City Name',
                    prefixIcon: Icons.location_city_outlined,
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Please enter city';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 16),

              const _FieldLabel('STATE / UNION TERRITORY', requiredField: true),

              const SizedBox(height: 7),
              _InputShell(
                child: DropdownButtonFormField<String>(
                  value: selectedState,
                  isExpanded: true,
                  icon: const Icon(Icons.expand_more_rounded, color: inkFaint),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: ink,
                  ),
                  decoration: _inputDecoration(
                    hintText: 'Select state / UT',
                    prefixIcon: Icons.map_outlined,
                  ),
                  items: _indianStatesAndUts.map((state) {
                    return DropdownMenuItem<String>(
                      value: state,
                      child: Text(state),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _businessStateController.text = value ?? '';
                    });
                  },
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Please select state / UT';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 16),

              const _FieldLabel('PIN CODE', requiredField: true),
              const SizedBox(height: 7),
              _InputShell(
                child: TextFormField(
                  controller: _businessPincodeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: ink,
                    letterSpacing: 0.4,
                  ),
                  decoration: _inputDecoration(
                    hintText: 'Pincode',
                    counterText: '',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return 'Please enter pincode';
                    if (!RegExp(r'^\d{6}$').hasMatch(text)) {
                      return 'Enter a valid 6-digit pincode';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 16),

              const _FieldLabel('GST NUMBER'),
              const SizedBox(height: 7),
              _InputShell(
                child: TextFormField(
                  controller: _gstNumberController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: ink,
                  ),
                  decoration: _inputDecoration(
                    hintText: '22AAAAA0000A1Z5',
                    prefixIcon: Icons.receipt_long_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const _FieldLabel('DRUG LICENSE NUMBER', requiredField: true),
              const SizedBox(height: 7),
              _InputShell(
                child: TextFormField(
                  controller: _drugLicenseNumberController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: ink,
                  ),
                  decoration: _inputDecoration(
                    hintText: 'e.g. MH-MZ1-123456',
                    prefixIcon: Icons.description_outlined,
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Please enter drug license number';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 16),

              const SizedBox(height: 16),

              const _FieldLabel('DRUG LICENSE COPY', requiredField: true),
              const SizedBox(height: 8),
              _LicenseUploadCard(
                file: _licenseFile,
                existingLicenseUrl: _existingLicenseUrl,
                onTap: _pickLicenseFile,
                onView: (_licenseFile != null && _licenseFile!.path.isNotEmpty)
                    ? () => _openPdfUrl(_licenseFile!.path)
                    : (_existingLicenseUrl == null
                          ? null
                          : () => _openPdfUrl(_existingLicenseUrl)),
              ),
              const SizedBox(height: 16),

              const _FieldLabel('GST CERTIFICATE', requiredField: true),
              const SizedBox(height: 8),
              _GstUploadCard(
                file: _gstFile,
                existingGstUrl: _existingGstUrl,
                onTap: _pickGstFile,
                onView: (_gstFile != null && _gstFile!.path.isNotEmpty)
                    ? () => _openPdfUrl(_gstFile!.path)
                    : (_existingGstUrl == null
                          ? null
                          : () => _openPdfUrl(_existingGstUrl)),
              ),
              const SizedBox(height: 15),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE3E9F3)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A0A2451),
                      blurRadius: 18,
                      offset: Offset(0, 6),
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
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F7FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.description_outlined,
                            color: Color(0xFF1D4ED8),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Client Service Agreement',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF10233F),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Review and accept the Wetaran Retailer Service Agreement to continue using medicine orders.',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.3,
                                  height: 1.35,
                                  color: Color(0xFF5B6B85),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isAgreementLoading
                                ? null
                                : _showClientServiceAgreementDialog,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(42),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _clientAgreementAccepted
                                  ? 'Accepted'
                                  : 'Review & accept',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        if (_clientAgreementAccepted &&
                            _clientAgreementUrl != null) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openPdfUrl(_clientAgreementUrl),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.download_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Download PDF',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _clientAgreementAccepted
                          ? _formatAcceptedOnLine(
                              _clientAgreementAcceptedAt,
                              _clientAgreementVersion,
                            )
                          : 'Not accepted yet - required to enable medicine orders',
                      style: TextStyle(
                        fontSize: 12.4,
                        fontWeight: FontWeight.w700,
                        color: _clientAgreementAccepted
                            ? const Color(0xFF15803D)
                            : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [teal500, teal600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: teal500.withOpacity(.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: white,
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('Submit'),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                'Your account activates once GST and Drug License are verified.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.5,
                  color: inkFaint,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? hintText,
    IconData? prefixIcon,
    String? counterText,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: inkFaint,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      counterText: counterText,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, color: inkFaint, size: 20),
      contentPadding:
          contentPadding ??
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool requiredField;

  const _FieldLabel(this.text, {this.requiredField = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: _CompleteProfilePageState.inkSoft,
          letterSpacing: 0.2,
        ),
        children: [
          TextSpan(text: text),
          if (requiredField)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800),
            ),
        ],
      ),
    );
  }
}

class _InputShell extends StatelessWidget {
  final Widget child;
  const _InputShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _CompleteProfilePageState.line, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120A2451),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LockedInputShell extends StatelessWidget {
  final Widget child;
  const _LockedInputShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _CompleteProfilePageState.lockedBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _CompleteProfilePageState.line, width: 1.5),
      ),
      child: child,
    );
  }
}

class _LockedValueRow extends StatelessWidget {
  final IconData? icon;
  final String value;

  const _LockedValueRow({this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Icon(
              icon,
              color: _CompleteProfilePageState.inkFaint,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _CompleteProfilePageState.inkSoft,
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(right: 12),
          child: Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: _CompleteProfilePageState.inkFaint,
          ),
        ),
      ],
    );
  }
}

class _LicenseUploadCard extends StatelessWidget {
  final File? file;
  final String? existingLicenseUrl;
  final VoidCallback onTap;
  final VoidCallback? onView;

  const _LicenseUploadCard({
    super.key,
    required this.file,
    required this.existingLicenseUrl,
    required this.onTap,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = file != null;
    final hasExisting =
        existingLicenseUrl != null && existingLicenseUrl!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasFile || hasExisting
              ? _CompleteProfilePageState.teal50
              : _CompleteProfilePageState.uploadBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile || hasExisting
                ? _CompleteProfilePageState.teal500
                : const Color(0xFFC3D0E4),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    hasFile || hasExisting
                        ? Icons.check_circle_outline_rounded
                        : Icons.upload_file_outlined,
                    color: hasFile || hasExisting
                        ? _CompleteProfilePageState.green600
                        : const Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasFile
                            ? file!.path.split('/').last
                            : hasExisting
                            ? 'Drug license already uploaded'
                            : 'Tap to upload Drug License PDF',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _CompleteProfilePageState.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasFile
                            ? 'Selected, tap to change'
                            : hasExisting
                            ? 'Click to replace with a new PDF'
                            : 'PDF only',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: hasFile || hasExisting
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: hasFile || hasExisting
                              ? _CompleteProfilePageState.teal600
                              : _CompleteProfilePageState.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasExisting || hasFile) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.upload_outlined, size: 18),
                    label: const Text('Replace PDF'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: onView,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('View PDF'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GeoCaptureCard extends StatelessWidget {
  final bool isLoading;
  final String? address;
  final double? latitude;
  final double? longitude;
  final VoidCallback onTap;

  const _GeoCaptureCard({
    required this.isLoading,
    required this.onTap,
    this.address,
    this.latitude,
    this.longitude,
  });

  bool get hasLocation =>
      latitude != null &&
      longitude != null &&
      address != null &&
      address!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FBF9), Color(0xFFEAF3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCDE8E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x120A2451),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.location_on_outlined,
                  size: 19,
                  color: _CompleteProfilePageState.teal600,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'At your business right now?',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _CompleteProfilePageState.ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Capture your exact shop location as a map pin for accurate deliveries.',
                      style: TextStyle(
                        fontSize: 10.5,
                        height: 1.45,
                        color: _CompleteProfilePageState.inkSoft,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isLoading ? null : onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: _CompleteProfilePageState.teal600,
              side: const BorderSide(
                color: _CompleteProfilePageState.teal500,
                width: 1.5,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            ),
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.gps_fixed_rounded, size: 16),
            label: Text(
              isLoading
                  ? 'Fetching current location...'
                  : hasLocation
                  ? 'Refresh current location'
                  : 'Use my current location',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          if (hasLocation) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD8E7E2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Color(0xFF15803D),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Location captured',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF15803D),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          address!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.45,
                            color: _CompleteProfilePageState.inkSoft,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _CompleteProfilePageState.inkFaint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SignupBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;

  const _SignupBackButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: _CompleteProfilePageState.inkSoft,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _CompleteProfilePageState.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignupProgress extends StatelessWidget {
  final int step;

  const _SignupProgress({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ProgressNode(
          number: 1,
          label: 'Account',
          state: step > 1 ? _ProgressState.done : _ProgressState.active,
        ),
        _ProgressLine(filled: step > 1),
        _ProgressNode(
          number: 2,
          label: 'Verify',
          state: step > 2
              ? _ProgressState.done
              : (step == 2 ? _ProgressState.active : _ProgressState.todo),
        ),
        _ProgressLine(filled: step > 2),
        _ProgressNode(
          number: 3,
          label: 'Business',
          state: step == 3 ? _ProgressState.active : _ProgressState.todo,
        ),
      ],
    );
  }
}

enum _ProgressState { todo, active, done }

class _ProgressNode extends StatelessWidget {
  final int number;
  final String label;
  final _ProgressState state;

  const _ProgressNode({
    required this.number,
    required this.label,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = state == _ProgressState.active;
    final isDone = state == _ProgressState.done;

    return SizedBox(
      width: 40,
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDone || isActive
                    ? _CompleteProfilePageState.teal500
                    : _CompleteProfilePageState.line,
                width: 2,
              ),
              color: isDone
                  ? _CompleteProfilePageState.teal500
                  : isActive
                  ? _CompleteProfilePageState.teal50
                  : Colors.white,
            ),
            alignment: Alignment.center,
            child: isDone
                ? const Icon(Icons.check, size: 15, color: Colors.white)
                : Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? _CompleteProfilePageState.teal600
                          : _CompleteProfilePageState.inkFaint,
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isDone || isActive
                  ? _CompleteProfilePageState.teal600
                  : _CompleteProfilePageState.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final bool filled;

  const _ProgressLine({required this.filled});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20),
        color: filled
            ? _CompleteProfilePageState.teal500
            : _CompleteProfilePageState.line,
      ),
    );
  }
}

class _IndiaFlagMini extends StatelessWidget {
  const _IndiaFlagMini();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 1)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(child: Container(color: const Color(0xFFFF9933))),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(color: Colors.white),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF0A3B8C),
                      width: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: Container(color: const Color(0xFF138808))),
        ],
      ),
    );
  }
}

class _BusinessTypeOption {
  final String value;
  final String label;

  const _BusinessTypeOption({required this.value, required this.label});
}

const List<String> _indianStatesAndUts = [
  'Andhra Pradesh',
  'Arunachal Pradesh',
  'Assam',
  'Bihar',
  'Chhattisgarh',
  'Goa',
  'Gujarat',
  'Haryana',
  'Himachal Pradesh',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Madhya Pradesh',
  'Maharashtra',
  'Manipur',
  'Meghalaya',
  'Mizoram',
  'Nagaland',
  'Odisha',
  'Punjab',
  'Rajasthan',
  'Sikkim',
  'Tamil Nadu',
  'Telangana',
  'Tripura',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal',
  'Andaman & Nicobar Islands',
  'Chandigarh',
  'Dadra & Nagar Haveli and Daman & Diu',
  'Delhi',
  'Jammu & Kashmir',
  'Ladakh',
  'Lakshadweep',
  'Puducherry',
];

class _GstUploadCard extends StatelessWidget {
  final File? file;
  final String? existingGstUrl;
  final VoidCallback onTap;
  final VoidCallback? onView;

  const _GstUploadCard({
    super.key,
    required this.file,
    required this.existingGstUrl,
    required this.onTap,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = file != null;
    final hasExisting = existingGstUrl != null && existingGstUrl!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasFile || hasExisting
              ? _CompleteProfilePageState.teal50
              : _CompleteProfilePageState.uploadBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile || hasExisting
                ? _CompleteProfilePageState.teal500
                : const Color(0xFFC3D0E4),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    hasFile || hasExisting
                        ? Icons.check_circle_outline_rounded
                        : Icons.upload_file_outlined,
                    color: hasFile || hasExisting
                        ? _CompleteProfilePageState.green600
                        : const Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasFile
                            ? file!.path.split('/').last
                            : hasExisting
                            ? 'GST certificate already uploaded'
                            : 'Tap to upload GST certificate PDF',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _CompleteProfilePageState.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasFile
                            ? 'Selected, tap to change'
                            : hasExisting
                            ? 'Click to replace with a new PDF'
                            : 'PDF only',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: hasFile || hasExisting
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: hasFile || hasExisting
                              ? _CompleteProfilePageState.teal600
                              : _CompleteProfilePageState.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasExisting || hasFile) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.upload_outlined, size: 18),
                    label: const Text('Replace PDF'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: onView,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('View PDF'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
