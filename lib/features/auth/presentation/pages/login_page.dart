import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wetaran_pharma/features/auth/presentation/pages/signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  SupabaseClient get _supabase => Supabase.instance.client;

  static const Color bg = Color(0xFFEFF3FA);
  static const Color ink = Color(0xFF10233F);
  static const Color inkSoft = Color(0xFF5B6B85);
  static const Color inkFaint = Color(0xFF8C9AB1);

  static const Color teal600 = Color(0xFF0D9488);
  static const Color teal500 = Color(0xFF14B8A6);

  static const Color line = Color(0xFFE3E9F3);
  static const Color fieldBg = Colors.white;

  static const Color successText = Color(0xFF15803D);
  static const Color successBg = Color(0xFFEAF7EF);
  static const Color successBorder = Color(0xFFC6E6D1);

  bool get _canSubmit {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final emailValid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

    return emailValid && password.length >= 6 && !_isLoading;
  }

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onFieldsChanged);
    _passwordController.addListener(_onFieldsChanged);
  }

  void _onFieldsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _emailController.removeListener(_onFieldsChanged);
    _passwordController.removeListener(_onFieldsChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isLoading) return;

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final result = await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      debugPrint('LOGIN SUCCESS');
      debugPrint('auth user id: ${result.user?.id}');
      debugPrint('auth email: ${result.user?.email}');
      debugPrint('session exists: ${result.session != null}');

      final authUserId = result.user?.id;
      if (authUserId != null) {
        try {
          final profile = await _supabase
              .from('pharma_users')
              .select()
              .eq('auth_user_id', authUserId)
              .maybeSingle();
          debugPrint('pharma_users profile: $profile');
        } catch (e, st) {
          debugPrint('pharma_users fetch failed after login: $e');
          debugPrintStack(stackTrace: st);
        }
      }

      if (!mounted) return;
    } on AuthException catch (error, st) {
      debugPrint('LOGIN AuthException: ${error.message}');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      _showSnack(error.message);
    } catch (e, st) {
      debugPrint('LOGIN unknown error: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      _showSnack('Something went wrong. Please try again.');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade600,
      ),
    );
  }

  void _openSignup() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SignupPage()));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const _LoginHero(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 70),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Sign in to your pharmacy',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: ink,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Enter your email and password to continue.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: inkSoft,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 26),

                          const _FieldLabel('EMAIL ADDRESS'),
                          const SizedBox(height: 8),
                          _buildInputShell(
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [
                                AutofillHints.username,
                                AutofillHints.email,
                              ],
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: ink,
                              ),
                              decoration: _inputDecoration(
                                hint: 'you@pharmacy.com',
                                prefixIcon: Icons.mail_outline_rounded,
                              ),
                              validator: (v) {
                                final t = (v ?? '').trim();
                                if (t.isEmpty) {
                                  return 'Please enter your email address';
                                }
                                if (!RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(t)) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                            ),
                          ),

                          const SizedBox(height: 20),

                          Row(
                            children: [
                              const Expanded(child: _FieldLabel('PASSWORD')),
                              /*
                              TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: teal600,
                                ),
                                child: const Text(
                                  'Forgot?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              */
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildInputShell(
                            child: TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) {
                                if (_canSubmit) _signIn();
                              },
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: ink,
                              ),
                              decoration: _inputDecoration(
                                hint: 'Enter your password',
                                prefixIcon: Icons.lock_outline_rounded,
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: inkFaint,
                                  ),
                                ),
                              ),
                              validator: (v) {
                                final t = (v ?? '').trim();
                                if (t.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (t.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                          ),

                          const SizedBox(height: 20),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: successBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: successBorder),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  color: successText,
                                  size: 18,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Only GST + Drug License verified pharmacies can order',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.35,
                                      fontWeight: FontWeight.w700,
                                      color: successText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 34),

                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: LinearGradient(
                                colors: _canSubmit
                                    ? const [
                                        Color.fromARGB(255, 3, 208, 191),
                                        Color.fromARGB(255, 6, 190, 203),
                                      ]
                                    : const [
                                        Color(0xFFB8D9D5),
                                        Color(0xFFAFC9CD),
                                      ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              boxShadow: _canSubmit
                                  ? [
                                      BoxShadow(
                                        color: teal500.withOpacity(0.20),
                                        blurRadius: 18,
                                        offset: const Offset(0, 8),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: FilledButton(
                              onPressed: _canSubmit ? _signIn : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                disabledForegroundColor: Colors.white70,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Sign in',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: _canSubmit
                                                ? Colors.white
                                                : Colors.white70,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 22,
                                          color: _canSubmit
                                              ? Colors.white
                                              : Colors.white70,
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'New to Wetaran? ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: inkSoft,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextButton(
                                onPressed: _isLoading ? null : _openSignup,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: teal600,
                                ),
                                child: const Text(
                                  'Create pharmacy account',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          RichText(
                            textAlign: TextAlign.center,
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 12.5,
                                color: inkFaint,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                              children: [
                                TextSpan(
                                  text:
                                      'By continuing you agree to Wetaran\'s ',
                                ),
                                TextSpan(
                                  text: 'Terms of Use',
                                  style: TextStyle(
                                    color: inkSoft,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(text: ' & '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: TextStyle(
                                    color: inkSoft,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputShell({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line, width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140A2451),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      border: InputBorder.none,
      prefixIcon: Icon(prefixIcon, color: inkFaint, size: 22),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      hintStyle: const TextStyle(
        color: inkFaint,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      errorStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Color(0xFF6B7A90),
        letterSpacing: 0.6,
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  static const Color blue900 = Color(0xFF082454);
  static const Color blue800 = Color(0xFF0D3D85);
  static const Color blue700 = Color(0xFF174EA6);
  static const Color teal500 = Color(0xFF19C3B3);
  static const Color teal600 = Color(0xFF12AFA1);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(48),
        bottomRight: Radius.circular(48),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 235,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [blue900, blue800, blue700],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.82, -0.55),
                    radius: 0.60,
                    colors: [
                      teal500.withOpacity(0.22),
                      teal500.withOpacity(0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.82, -0.58),
                    radius: 0.24,
                    colors: [teal500.withOpacity(0.18), Colors.transparent],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.all(0),
                            child: Image.asset(
                              'assets/images/WRxLogo_RX.webp',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  height: 1.05,
                                  color: Colors.white,
                                ),
                                children: [
                                  TextSpan(text: 'Wetaran '),
                                  TextSpan(
                                    text: 'Pharma',
                                    style: TextStyle(color: Color(0xFF19C3B3)),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'MARKETPLACE FOR PHARMACIES',
                              style: TextStyle(
                                color: Color(0xC7D7E1EF),
                                fontSize: 10.8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Order from your ',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextSpan(
                          text: 'nearest distributors',
                          style: TextStyle(color: Color(0xFF19C3B3)),
                        ),
                        TextSpan(
                          text: ' — in one place.',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Live prices, schemes, delivery times and cashback for verified chemists.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xC7E2E8F0),
                      fontWeight: FontWeight.w500,
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
