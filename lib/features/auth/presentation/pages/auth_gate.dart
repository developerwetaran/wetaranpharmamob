import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wetaran_pharma/features/auth/presentation/pages/complete_profile_page.dart';
import 'package:wetaran_pharma/features/auth/presentation/pages/login_page.dart';
import 'package:wetaran_pharma/features/home/presentation/pages/main_shell.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = _supabase.auth.onAuthStateChange;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStream,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        _supabase.auth.currentSession,
      ),
      builder: (context, authSnapshot) {
        final session =
            authSnapshot.data?.session ?? _supabase.auth.currentSession;

        if (session == null) {
          return const LoginPage();
        }

        return _ProfileStatusResolver(key: ValueKey(session.user.id));
      },
    );
  }
}

class _ProfileStatusResolver extends StatefulWidget {
  const _ProfileStatusResolver({super.key});

  @override
  State<_ProfileStatusResolver> createState() => _ProfileStatusResolverState();
}

class _ProfileStatusResolverState extends State<_ProfileStatusResolver> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<_ResolvedProfileState> _future;
  bool _nativeSplashRemoved = false;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  void _removeNativeSplashOnce() {
    if (_nativeSplashRemoved) return;
    FlutterNativeSplash.remove();
    _nativeSplashRemoved = true;
  }

  Future<_ResolvedProfileState> _resolve() async {
    final user = _supabase.auth.currentUser;
    debugPrint('AUTHGATE _resolve called');
    debugPrint('AUTHGATE currentUser = ${user?.id} / ${user?.email}');

    if (user == null) {
      debugPrint('AUTHGATE -> loggedOut');
      return const _ResolvedProfileState.loggedOut();
    }

    final row = await _supabase
        .from('pharma_users')
        .select('id, business_name, email, profile_status, auth_user_id')
        .eq('auth_user_id', user.id)
        .maybeSingle();

    debugPrint('AUTHGATE pharma_users row = $row');

    if (row == null) {
      debugPrint('AUTHGATE -> incomplete because row is null');
      return _ResolvedProfileState.incomplete(
        email: user.email ?? '',
        businessName: '',
      );
    }

    final profileStatus = (row['profile_status'] ?? 'incomplete')
        .toString()
        .trim()
        .toLowerCase();

    final email = (row['email'] ?? user.email ?? '').toString();
    final businessName = (row['business_name'] ?? '').toString();

    debugPrint('AUTHGATE profileStatus = $profileStatus');
    debugPrint('AUTHGATE businessName = $businessName');
    debugPrint('AUTHGATE email = $email');

    if (profileStatus == 'complete') {
      debugPrint('AUTHGATE -> MainShell');
      return const _ResolvedProfileState.complete();
    }

    debugPrint('AUTHGATE -> CompleteProfilePage');
    return _ResolvedProfileState.incomplete(
      email: email,
      businessName: businessName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ResolvedProfileState>(
      future: _future,
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2563EB),
                strokeWidth: 2.4,
              ),
            ),
          );
        }

        _removeNativeSplashOnce();

        if (profileSnapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 46,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to resolve account status\n${profileSnapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _future = _resolve();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final result = profileSnapshot.data!;

        switch (result.type) {
          case _ResolvedProfileType.loggedOut:
            return const LoginPage();

          case _ResolvedProfileType.incomplete:
            return CompleteProfilePage(
              email: result.email,
              businessName: result.businessName,
              allowBack: false,
            );

          case _ResolvedProfileType.complete:
            return const MainShell();
        }
      },
    );
  }
}

enum _ResolvedProfileType { loggedOut, incomplete, complete }

class _ResolvedProfileState {
  final _ResolvedProfileType type;
  final String email;
  final String businessName;

  const _ResolvedProfileState._({
    required this.type,
    this.email = '',
    this.businessName = '',
  });

  const _ResolvedProfileState.loggedOut()
    : this._(type: _ResolvedProfileType.loggedOut);

  const _ResolvedProfileState.complete()
    : this._(type: _ResolvedProfileType.complete);

  const _ResolvedProfileState.incomplete({
    required String email,
    required String businessName,
  }) : this._(
         type: _ResolvedProfileType.incomplete,
         email: email,
         businessName: businessName,
       );
}
