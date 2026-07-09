import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wetaran_pharma/features/auth/presentation/pages/complete_profile_page.dart';

class PharmaProfilePage extends StatefulWidget {
  const PharmaProfilePage({super.key});

  @override
  State<PharmaProfilePage> createState() => _PharmaProfilePageState();
}

class _PharmaProfilePageState extends State<PharmaProfilePage> {
  static const Color bg = Color(0xFFEFF3FA);
  static const Color white = Colors.white;
  static const Color ink = Color(0xFF10233F);
  static const Color inkSoft = Color(0xFF5B6B85);
  static const Color inkFaint = Color(0xFF8C9AB1);

  static const Color blue900 = Color(0xFF0A2451);
  static const Color blue800 = Color(0xFF0E3A7A);
  static const Color blue700 = Color(0xFF12489A);

  static const Color teal600 = Color(0xFF0D9488);
  static const Color teal500 = Color(0xFF14B8A6);
  static const Color teal50 = Color(0xFFE9FBF8);

  static const Color line = Color(0xFFE3E9F3);

  static const Color green = Color(0xFF15803D);
  static const Color greenSoft = Color(0xFFEAF7EF);

  static const Color amber = Color(0xFFB45309);
  static const Color amberSoft = Color(0xFFFFEDD5);

  static const Color red = Color(0xFFDC2626);
  static const Color redSoft = Color(0xFFFEE2E2);

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authUser = _supabase.auth.currentUser;
      final authUserId = authUser?.id;

      if (authUserId == null) {
        throw Exception('No logged-in user found');
      }

      final profile = await _supabase
          .from('pharma_users')
          .select()
          .eq('auth_user_id', authUserId)
          .maybeSingle();

      if (profile == null) {
        throw Exception('Pharma profile not found');
      }

      if (!mounted) return;
      setState(() {
        _profile = Map<String, dynamic>.from(profile);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openEditPage() async {
    final businessName = (_profile?['business_name'] ?? '').toString();
    final userEmail = (_profile?['email'] ?? '').toString();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CompleteProfilePage(email: userEmail, businessName: businessName),
      ),
    );

    if (!mounted) return;
    _loadProfile();
  }

  String _display(String? value, {String fallback = 'Not available'}) {
    final text = (value ?? '').trim();
    return text.isEmpty ? fallback : text;
  }

  String _businessTypeLabel(String? value) {
    switch ((value ?? '').trim()) {
      case 'chemist_store':
        return 'Chemist Store';
      case 'hospital':
        return 'Hospital';
      case 'clinic':
        return 'Clinic';
      default:
        return _display(value);
    }
  }

  String _statusLabel(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Unknown';

    return raw
        .split('_')
        .map((part) {
          if (part.isEmpty) return part;
          return part[0].toUpperCase() + part.substring(1).toLowerCase();
        })
        .join(' ');
  }

  Color _statusBg(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
      case 'complete':
        return greenSoft;
      case 'pending verification':
      case 'incomplete':
        return amberSoft;
      case 'rejected':
      case 'blocked':
        return redSoft;
      default:
        return teal50;
    }
  }

  Color _statusFg(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
      case 'complete':
        return green;
      case 'pending verification':
      case 'incomplete':
        return amber;
      case 'rejected':
      case 'blocked':
        return red;
      default:
        return teal600;
    }
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120A2451),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: teal50,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 17, color: teal600),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(
    String label,
    String? value, {
    String fallback = 'Not available',
  }) {
    final text = _display(value, fallback: fallback);
    final isFallback = text == fallback;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: inkSoft,
              letterSpacing: 0.25,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: isFallback ? inkFaint : ink,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _flagTile({
    required IconData icon,
    required String title,
    required bool value,
  }) {
    final fg = value ? green : red;
    final bgColor = value ? greenSoft : redSoft;
    final border = value ? const Color(0xFFC5E9D2) : const Color(0xFFF8CACA);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
          Text(
            value ? 'Yes' : 'No',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    final businessName = _display(profile?['business_name']?.toString());
    final businessType = _businessTypeLabel(
      profile?['business_type']?.toString(),
    );
    final email = _display(profile?['email']?.toString());
    final phone = _display(profile?['phone_number']?.toString());
    final contactPerson = _display(profile?['contact_person_name']?.toString());
    final address = _display(profile?['business_address']?.toString());
    final city = _display(profile?['business_city']?.toString());
    final state = _display(profile?['business_state']?.toString());
    final pincode = _display(profile?['business_pincode']?.toString());
    final gstNumber = _display(profile?['gst_number']?.toString());
    final drugLicense = _display(profile?['drug_license_number']?.toString());
    final status = _statusLabel(profile?['profile_status']?.toString());
    final emailVerified = (profile?['email_verified'] as bool?) ?? false;
    final canPlaceOrders =
        (profile?['can_place_medicine_orders'] as bool?) ?? false;

    final initials = businessName == 'Not available'
        ? 'P'
        : businessName
              .split(' ')
              .where((e) => e.trim().isNotEmpty)
              .take(2)
              .map((e) => e[0].toUpperCase())
              .join();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: teal500,
                  strokeWidth: 2.5,
                ),
              )
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: line),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: Colors.red.shade300,
                          size: 42,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: inkSoft,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _loadProfile,
                            style: FilledButton.styleFrom(
                              backgroundColor: teal600,
                              foregroundColor: white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: const Text(
                              'Retry',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Column(
                children: [
                  _PharmaGradientHeader(
                    height: 240,
                    borderRadius: BorderRadius.zero,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            _TopIconButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              onTap: () => Navigator.maybePop(context),
                            ),
                            const Spacer(),
                            _TopIconButton(
                              icon: Icons.refresh_rounded,
                              onTap: _loadProfile,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: white.withOpacity(.14),
                                border: Border.all(
                                  color: white.withOpacity(.22),
                                  width: 2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    businessName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: white,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    businessType,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xCCFFFFFF),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _statusBg(status),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: _statusFg(status),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: const LinearGradient(
                                colors: [teal500, teal600],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: teal500.withOpacity(.25),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: FilledButton.icon(
                              onPressed: _openEditPage,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: white,
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              label: const Text(
                                'Edit Profile',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        children: [
                          _buildInfoCard(
                            title: 'Business Information',
                            icon: Icons.business_rounded,
                            children: [
                              _infoRow('Business Name', businessName),
                              _infoRow('Business Type', businessType),
                              _infoRow('Contact Person', contactPerson),
                              _infoRow('Phone Number', phone),
                              _infoRow('Email Address', email),
                            ],
                          ),
                          _buildInfoCard(
                            title: 'Address Details',
                            icon: Icons.location_on_outlined,
                            children: [
                              _infoRow('Business Address', address),
                              _infoRow('City', city),
                              _infoRow('State', state),
                              _infoRow('Pincode', pincode),
                            ],
                          ),
                          _buildInfoCard(
                            title: 'Compliance',
                            icon: Icons.verified_user_outlined,
                            children: [
                              _infoRow('GST Number', gstNumber),
                              _infoRow('Drug License Number', drugLicense),
                            ],
                          ),
                          _buildInfoCard(
                            title: 'Account Status',
                            icon: Icons.shield_outlined,
                            children: [
                              _infoRow('Profile Status', status),
                              const SizedBox(height: 8),
                              _flagTile(
                                icon: Icons.verified_outlined,
                                title: 'Email Verified',
                                value: emailVerified,
                              ),
                              const SizedBox(height: 10),
                              _flagTile(
                                icon: Icons.medication_outlined,
                                title: 'Can Place Medicine Orders',
                                value: canPlaceOrders,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PharmaGradientHeader extends StatelessWidget {
  final Widget child;
  final double height;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const _PharmaGradientHeader({
    required this.child,
    this.height = 150,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 22),
    this.borderRadius = const BorderRadius.only(
      bottomLeft: Radius.circular(30),
      bottomRight: Radius.circular(30),
    ),
  });

  static const Color blue900 = Color(0xFF0A2451);
  static const Color blue800 = Color(0xFF0E3A7A);
  static const Color blue700 = Color(0xFF12489A);
  static const Color teal500 = Color(0xFF14B8A6);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              padding: padding,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [blue900, blue800, blue700],
                  stops: [0.0, 0.58, 1.0],
                ),
              ),
              child: child,
            ),
            Positioned(
              right: -55,
              top: -50,
              child: IgnorePointer(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        teal500.withOpacity(0.20),
                        teal500.withOpacity(0.07),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.42, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -45,
              bottom: -70,
              child: IgnorePointer(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF2B6CCF).withOpacity(0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withOpacity(0.07),
                        Colors.transparent,
                        Colors.black.withOpacity(0.03),
                      ],
                      stops: const [0.0, 0.58, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
