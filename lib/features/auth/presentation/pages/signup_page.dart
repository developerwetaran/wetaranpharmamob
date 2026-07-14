import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wetaran_pharma/core/widgets/pharma_auth_shell.dart';
import 'package:wetaran_pharma/features/auth/presentation/pages/complete_profile_page.dart';
import 'package:wetaran_pharma/features/auth/presentation/pages/otp_verification_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  final _businessNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _selectedBusinessType;

  final List<_BusinessTypeOption> _businessTypes = const [
    _BusinessTypeOption(value: 'chemist_store', label: 'Chemist Shop'),
    _BusinessTypeOption(value: 'hospital', label: 'Hospital'),
    _BusinessTypeOption(value: 'clinic', label: 'Doctor Clinic'),
  ];

  SupabaseClient get _supabase => Supabase.instance.client;

  static const Color white = Colors.white;
  static const Color ink = Color(0xFF10233F);
  static const Color inkSoft = Color(0xFF5B6B85);
  static const Color inkFaint = Color(0xFF8C9AB1);

  static const Color teal600 = Color(0xFF0D9488);
  static const Color teal500 = Color(0xFF14B8A6);

  static const Color line = Color(0xFFE3E9F3);

  bool get _canContinue {
    final businessName = _businessNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    final okEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    final okPhone = RegExp(r'^\d{10}$').hasMatch(phone);

    return businessName.length >= 2 &&
        _selectedBusinessType != null &&
        okEmail &&
        okPhone &&
        password.length >= 6 &&
        !_isLoading;
  }

  @override
  void initState() {
    super.initState();
    _businessNameController.addListener(_onFormChanged);
    _emailController.addListener(_onFormChanged);
    _phoneController.addListener(_onFormChanged);
    _passwordController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _businessNameController.removeListener(_onFormChanged);
    _emailController.removeListener(_onFormChanged);
    _phoneController.removeListener(_onFormChanged);
    _passwordController.removeListener(_onFormChanged);

    _businessNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _continueSignup() async {
    if (_isLoading) return;
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    if (_selectedBusinessType == null) {
      _showError('Please select a business type');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final response = await _supabase.functions.invoke(
        'start-pharma-signup',
        body: {
          'business_name': _businessNameController.text.trim(),
          'business_type': _selectedBusinessType,
          'email': _emailController.text.trim().toLowerCase(),
          'phone_number': _phoneController.text.trim(),
          'password': _passwordController.text.trim(),
        },
      );

      final data = response.data;
      if (!mounted) return;
      if (data == null || data is! Map) {
        _showError('Unexpected server response');
        return;
      }

      final success = data['success'];
      final errorCode = data['error_code']?.toString();

      if (success != true) {
        switch (errorCode) {
          case 'email_and_phone_exists':
            _showError(
              'This email and phone number are both already registered. Try signing in instead.',
            );
            break;
          case 'email_exists':
            _showError(
              'This email is already registered. Try signing in or use a different email.',
            );
            break;
          case 'phone_exists':
            _showError(
              'This phone number is already registered. Try signing in or use a different number.',
            );
            break;
          case 'account_exists':
            _showError('Account already exists. Please sign in instead.');
            break;
          default:
            _showError(
              (data['error'] ?? data['message'] ?? 'Unable to continue signup')
                  .toString(),
            );
        }
        return;
      }

      if (errorCode == 'profile_incomplete') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => CompleteProfilePage(
              email: _emailController.text.trim().toLowerCase(),
              businessName: _businessNameController.text.trim(),
            ),
          ),
          (route) => false,
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationPage(
            email: _emailController.text.trim().toLowerCase(),
            password: _passwordController.text.trim(),
            businessName: _businessNameController.text.trim(),
            businessType: _selectedBusinessType!,
            phoneNumber: _phoneController.text.trim(),
            initialOtpExpiresAt: data['otp_expires_at']?.toString(),
            initialResendAvailableAt: data['resend_available_at']?.toString(),
          ),
        ),
      );
    } on FunctionException catch (error) {
      if (!mounted) return;
      _showError(
        error.details?.toString() ?? error.reasonPhrase ?? 'Function error',
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      _showError('Something went wrong. Please try again.');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return PharmaAuthShell(
      compactHero: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SignupBackButton(
              onTap: _isLoading ? null : () => Navigator.of(context).pop(),
              label: 'Back to sign in',
            ),
            const SizedBox(height: 8),
            const SignupProgress(step: 1),
            const SizedBox(height: 18),

            const Text(
              'Create your account',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ink,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tell us the basics to get started.',
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
            _InputShell(
              child: TextFormField(
                controller: _businessNameController,
                textInputAction: TextInputAction.next,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: ink,
                ),
                decoration: _inputDecoration(
                  hintText: 'e.g. Shree Medico & General Stores',
                  prefixIcon: Icons.business_outlined,
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return 'Please enter your business name';
                  if (text.length < 2) return 'Business name is too short';
                  return null;
                },
              ),
            ),

            const SizedBox(height: 16),
            const _FieldLabel('BUSINESS TYPE'),
            const SizedBox(height: 7),
            _InputShell(
              child: DropdownButtonFormField<String>(
                value: _selectedBusinessType,
                isExpanded: true,
                icon: const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: inkFaint,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: ink,
                ),
                dropdownColor: white,
                decoration: _inputDecoration(
                  hintText: 'Select business type',
                  prefixIcon: Icons.storefront_outlined,
                ),
                items: _businessTypes
                    .map(
                      (type) => DropdownMenuItem<String>(
                        value: type.value,
                        child: Text(type.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBusinessType = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a business type';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(height: 16),
            const _FieldLabel('EMAIL ADDRESS'),
            const SizedBox(height: 7),
            _InputShell(
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: ink,
                ),
                decoration: _inputDecoration(
                  hintText: 'you@pharmacy.com',
                  prefixIcon: Icons.mail_outline_rounded,
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return 'Please enter your email address';
                  final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                  if (!emailRegex.hasMatch(text)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(height: 16),
            const _FieldLabel('PHONE NUMBER'),
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
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      maxLength: 10,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: ink,
                        letterSpacing: 0.4,
                      ),
                      decoration: _inputDecoration(
                        hintText: '98765 43210',
                        prefixIcon: null,
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty)
                          return 'Please enter your phone number';
                        if (!RegExp(r'^\d{10}$').hasMatch(text)) {
                          return 'Please enter a valid 10-digit phone number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const _FieldLabel('PASSWORD'),
            const SizedBox(height: 7),
            _InputShell(
              child: TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (_canContinue) _continueSignup();
                },
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: ink,
                ),
                decoration: _inputDecoration(
                  hintText: 'Minimum 8 characters',
                  prefixIcon: Icons.lock_outline_rounded,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: inkFaint,
                    ),
                  ),
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return 'Please enter your password';
                  if (text.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
            ),

            const SizedBox(height: 20),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: _canContinue
                      ? const [teal500, teal600]
                      : const [Color(0xFF9EDAD2), Color(0xFF8BC7C0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: _canContinue
                    ? [
                        BoxShadow(
                          color: teal500.withOpacity(.40),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [],
              ),
              child: FilledButton(
                onPressed: _canContinue ? _continueSignup : null,
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
                child: _isLoading
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
                          Text('Continue'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Already registered? ',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: inkSoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: teal600,
                  ),
                  child: const Text(
                    'Sign in',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
    String? counterText,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return InputDecoration(
      hintText: hintText,
      counterText: counterText,
      border: InputBorder.none,
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, color: inkFaint, size: 20),
      suffixIcon: suffixIcon,
      contentPadding:
          contentPadding ??
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(
        color: inkFaint,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      errorStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
        border: Border.all(color: const Color(0xFFE3E9F3), width: 1.5),
        borderRadius: BorderRadius.circular(14),
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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF5B6B85),
        letterSpacing: .2,
      ),
    );
  }
}

class _BusinessTypeOption {
  final String value;
  final String label;

  const _BusinessTypeOption({required this.value, required this.label});
}
