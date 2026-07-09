import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wetaran_pharma/core/widgets/pharma_auth_shell.dart';
import 'package:wetaran_pharma/features/auth/presentation/pages/complete_profile_page.dart';

class OtpVerificationPage extends StatefulWidget {
  final String email;
  final String password;
  final String businessName;
  final String businessType;
  final String phoneNumber;
  final String? initialOtpExpiresAt;
  final String? initialResendAvailableAt;

  const OtpVerificationPage({
    super.key,
    required this.email,
    required this.password,
    required this.businessName,
    required this.businessType,
    required this.phoneNumber,
    this.initialOtpExpiresAt,
    this.initialResendAvailableAt,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  Timer? _timer;
  int _secondsLeft = 0;

  bool _isVerifying = false;
  bool _isResending = false;

  SupabaseClient get _supabase => Supabase.instance.client;

  static const Color white = Colors.white;
  static const Color ink = Color(0xFF10233F);
  static const Color inkSoft = Color(0xFF5B6B85);
  static const Color inkFaint = Color(0xFF8C9AB1);

  static const Color teal600 = Color(0xFF0D9488);
  static const Color teal500 = Color(0xFF14B8A6);
  static const Color teal50 = Color(0xFFE9FBF8);

  static const Color line = Color(0xFFE3E9F3);

  String get _otpCode => _controllers.map((c) => c.text).join();
  bool get _canVerify => RegExp(r'^\d{4}$').hasMatch(_otpCode) && !_isVerifying;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startResendCountdown() {
    _timer?.cancel();

    final resendAt = DateTime.tryParse(widget.initialResendAvailableAt ?? '');
    if (resendAt != null) {
      final diff = resendAt.difference(DateTime.now()).inSeconds;
      _secondsLeft = diff > 0 ? diff : 0;
    } else {
      _secondsLeft = 30;
    }

    if (_secondsLeft <= 0) {
      setState(() {});
      return;
    }

    setState(() {});

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
        });
      } else {
        setState(() {
          _secondsLeft--;
        });
      }
    });
  }

  void _handleOtpInput(int index, String rawValue) {
    final value = rawValue.replaceAll(RegExp(r'\D'), '');

    if (value.isEmpty) {
      _controllers[index].clear();
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
      setState(() {});
      return;
    }

    if (value.length > 1) {
      final chars = value.split('');
      for (int i = 0; i < chars.length && (index + i) < 4; i++) {
        _controllers[index + i].text = chars[i];
      }

      final nextIndex = (index + value.length) >= 4 ? 3 : index + value.length;
      _focusNodes[nextIndex].requestFocus();
      setState(() {});
      return;
    }

    _controllers[index].text = value;
    _controllers[index].selection = TextSelection.fromPosition(
      TextPosition(offset: _controllers[index].text.length),
    );

    if (index < 3) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
    }

    setState(() {});
  }

  void _handleBackspace(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey != LogicalKeyboardKey.backspace) return;

    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      setState(() {});
    }
  }

  Future<void> _verifyOtp() async {
    if (_isVerifying) return;

    if (_otpCode.length != 4 || !_otpCode.contains(RegExp(r'^\d{4}$'))) {
      _showError('Please enter the 4-digit OTP');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isVerifying = true;
    });

    try {
      final response = await _supabase.functions.invoke(
        'verify-pharma-otp',
        body: {
          'email': widget.email,
          'otp': _otpCode,
          'password': widget.password,
        },
      );

      final data = response.data;

      if (data == null || data is! Map) {
        _showError('Unexpected server response');
        return;
      }

      final success = data['success'];
      if (success != true) {
        _showError(
          (data['error'] ?? data['message'] ?? 'OTP verification failed')
              .toString(),
        );
        return;
      }

      await _supabase.auth.signInWithPassword(
        email: widget.email,
        password: widget.password,
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => CompleteProfilePage(
            email: widget.email,
            businessName: widget.businessName,
          ),
        ),
        (route) => false,
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
      setState(() {
        _isVerifying = false;
      });
    }
  }

  Future<void> _resendOtp() async {
    if (_isResending || _secondsLeft > 0) return;

    setState(() {
      _isResending = true;
    });

    try {
      final response = await _supabase.functions.invoke(
        'start-pharma-signup',
        body: {
          'business_name': widget.businessName,
          'business_type': widget.businessType,
          'email': widget.email,
          'phone_number': widget.phoneNumber,
          'password': widget.password,
        },
      );

      final data = response.data;

      if (data == null || data is! Map) {
        _showError('Unexpected server response');
        return;
      }

      final success = data['success'];
      if (success != true) {
        _showError(
          (data['error'] ?? data['message'] ?? 'Failed to resend OTP')
              .toString(),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent again successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _clearOtp();
      _startResendCountdown();
    } on FunctionException catch (error) {
      if (!mounted) return;
      _showError(
        error.details?.toString() ?? error.reasonPhrase ?? 'Function error',
      );
    } catch (_) {
      if (!mounted) return;
      _showError('Unable to resend OTP right now');
    } finally {
      if (!mounted) return;
      setState(() {
        _isResending = false;
      });
    }
  }

  void _clearOtp() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes.first.requestFocus();
    setState(() {});
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

  String _formatTimer(int seconds) {
    final s = seconds.clamp(0, 999);
    return '0:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PharmaAuthShell(
      compactHero: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SignupBackButton(
            onTap: _isVerifying ? null : () => Navigator.of(context).pop(),
            label: 'Back',
          ),
          const SizedBox(height: 8),
          const SignupProgress(step: 2),
          const SizedBox(height: 18),
          const MailIllustration(),
          const SizedBox(height: 10),

          const Text(
            'Verify your email',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ink,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),

          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'We\'ve sent a 4-digit code to\n'),
                TextSpan(
                  text: widget.email,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: inkSoft,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 22),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              4,
              (index) => Padding(
                padding: EdgeInsets.only(right: index == 3 ? 0 : 12),
                child: SizedBox(
                  width: 60,
                  height: 66,
                  child: Focus(
                    onKeyEvent: (_, event) {
                      _handleBackspace(index, event);
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textInputAction: index == 3
                          ? TextInputAction.done
                          : TextInputAction.next,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      autofocus: index == 0,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: _controllers[index].text.isNotEmpty
                            ? teal50
                            : white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: line, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: _controllers[index].text.isNotEmpty
                                ? teal500
                                : line,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: teal500,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (value) => _handleOtpInput(index, value),
                      onSubmitted: (_) {
                        if (index == 3 && _canVerify) {
                          _verifyOtp();
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Center(
            child: _secondsLeft > 0
                ? Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Didn\'t receive it? '),
                        TextSpan(
                          text: 'Resend in ${_formatTimer(_secondsLeft)}',
                          style: const TextStyle(color: inkFaint),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: inkSoft,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : TextButton(
                    onPressed: _isResending ? null : _resendOtp,
                    style: TextButton.styleFrom(
                      foregroundColor: teal600,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: _isResending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: teal600,
                            ),
                          )
                        : const Text(
                            'Didn\'t receive it? Resend code',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
          ),

          const SizedBox(height: 24),

          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: _canVerify
                    ? const [teal500, teal600]
                    : const [Color(0xFF9EDAD2), Color(0xFF8BC7C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: _canVerify
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
              onPressed: _canVerify ? _verifyOtp : null,
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
              child: _isVerifying
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
                        Text('Verify email'),
                        SizedBox(width: 8),
                        Icon(Icons.check_rounded, size: 18),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 16),

          TextButton(
            onPressed: _isVerifying ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: teal600,
            ),
            child: const Text(
              'Wrong email? Go back',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
