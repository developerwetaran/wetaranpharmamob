import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wetaran_pharma/core/config/app_constants.dart';
import 'package:wetaran_pharma/core/widgets/pharma_auth_shell.dart';
import 'package:wetaran_pharma/features/home/presentation/pages/main_shell.dart';

class CompleteProfilePage extends StatefulWidget {
  final String email;
  final String businessName;

  const CompleteProfilePage({
    super.key,
    required this.email,
    required this.businessName,
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
  final _businessCityController = TextEditingController();
  final _businessStateController = TextEditingController();
  final _businessPincodeController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  String? _selectedBusinessType;
  String? _existingLicenseUrl;

  File? _licenseFile;

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
    super.dispose();
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
        final formattedAddress = (results.first['formatted_address'] ?? '')
            .toString()
            .trim();

        if (formattedAddress.isEmpty) {
          throw Exception('Formatted address is empty');
        }

        setState(() {
          _geoLatitude = lat;
          _geoLongitude = lng;
          _geoFormattedAddress = formattedAddress;
          _businessAddressController.text = formattedAddress;
        });
      } else if (status == 'ZERO_RESULTS') {
        setState(() {
          _geoLatitude = lat;
          _geoLongitude = lng;
          _geoFormattedAddress = null;
        });
        _showError('Location captured, but no readable address was returned');
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
        _businessCityController.text = (row['business_city'] ?? '').toString();
        _businessStateController.text = (row['business_state'] ?? '')
            .toString();
        _businessPincodeController.text = (row['business_pincode'] ?? '')
            .toString();
        _selectedBusinessType = row['business_type']?.toString();
        _existingLicenseUrl = row['drug_license_copy_url']?.toString();

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

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    if (_selectedBusinessType == null) {
      _showError('Please select a business type');
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

      final licensePath = await _uploadLicenseIfNeeded();

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
          (licensePath?.trim().isNotEmpty ?? false) &&
          gstNumber.isNotEmpty &&
          contactPersonName.isNotEmpty &&
          businessCity.isNotEmpty &&
          businessState.isNotEmpty &&
          businessPincode.isNotEmpty;

      await _supabase
          .from('pharma_users')
          .update({
            'business_name': businessName,
            'business_type': _selectedBusinessType,
            'phone_number': phoneNumber,
            'business_address': businessAddress,
            'drug_license_number': drugLicenseNumber,
            'drug_license_copy_url': licensePath,
            'gst_number': gstNumber,
            'contact_person_name': contactPersonName,
            'business_city': businessCity,
            'geo_location': geoLocation,
            'business_state': businessState,
            'business_pincode': businessPincode,
            'profile_status': isProfileComplete ? 'complete' : 'incomplete',
            'can_place_medicine_orders': isProfileComplete,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: bg,
        body: Center(
          child: CircularProgressIndicator(strokeWidth: 2.5, color: teal500),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: PharmaAuthShell(
        compactHero: true,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SignupBackButton(
                onTap: _isSaving ? null : () => Navigator.of(context).pop(),
                label: 'Back',
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
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: ink,
                  ),
                  decoration: _inputDecoration(
                    hintText: 'Shop no., building, street',
                    prefixIcon: Icons.home_work_outlined,
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
                  value: _businessStateController.text.trim().isEmpty
                      ? null
                      : _businessStateController.text.trim(),
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
                  items: _indianStatesAndUts
                      .map(
                        (state) => DropdownMenuItem<String>(
                          value: state,
                          child: Text(state),
                        ),
                      )
                      .toList(),
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
              ),

              const SizedBox(height: 24),

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
              value.isEmpty ? '—' : value,
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

  const _LicenseUploadCard({
    required this.file,
    required this.existingLicenseUrl,
    required this.onTap,
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
        child: Row(
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
                        ? 'Tap to replace uploaded PDF'
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
