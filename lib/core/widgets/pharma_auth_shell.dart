import 'package:flutter/material.dart';

class PharmaAuthShell extends StatelessWidget {
  final Widget child;
  final bool compactHero;

  const PharmaAuthShell({
    super.key,
    required this.child,
    this.compactHero = false,
  });

  static const Color bg = Color(0xFFEFF3FA);

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          SizedBox(height: topInset),
          _SignupHero(compact: compactHero),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 18, 24, 24 + bottomInset),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignupHero extends StatelessWidget {
  final bool compact;
  const _SignupHero({required this.compact});

  static const Color white = Colors.white;
  static const Color blue900 = Color(0xFF0A2451);
  static const Color blue800 = Color(0xFF0E3A7A);
  static const Color blue700 = Color(0xFF12489A);
  static const Color teal600 = Color(0xFF0D9488);
  static const Color teal500 = Color(0xFF14B8A6);

  @override
  Widget build(BuildContext context) {
    final double heroHeight = compact ? 90 : 188;
    final double topPadding = compact ? 18 : 34;
    final double bottomPadding = compact ? 18 : 28;

    return SizedBox(
      width: double.infinity,
      height: heroHeight,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              padding: EdgeInsets.fromLTRB(26, topPadding, 26, bottomPadding),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [blue900, blue800, blue700],
                  stops: [0.0, 0.60, 1.0],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [teal500, teal600],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: teal500.withOpacity(.24),
                              blurRadius: 18,
                              spreadRadius: 0.5,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'W',
                          style: TextStyle(
                            color: white,
                            fontWeight: FontWeight.w800,
                            fontSize: 23,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Wetaran ',
                                    style: TextStyle(color: white),
                                  ),
                                  TextSpan(
                                    text: 'Pharma',
                                    style: TextStyle(color: teal500),
                                  ),
                                ],
                              ),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'MARKETPLACE FOR PHARMACIES',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0x99FFFFFF),
                                fontWeight: FontWeight.w600,
                                letterSpacing: .7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 18),
                    const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Order from your ',
                            style: TextStyle(color: white),
                          ),
                          TextSpan(
                            text: 'nearest distributors',
                            style: TextStyle(color: teal500),
                          ),
                          TextSpan(
                            text: ' — in one place.',
                            style: TextStyle(color: white),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Live prices, schemes, delivery times and cashback for verified chemists.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xB3FFFFFF),
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Positioned(
              right: -70,
              top: -72,
              child: IgnorePointer(
                child: Container(
                  width: compact ? 170 : 250,
                  height: compact ? 170 : 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        teal500.withOpacity(compact ? .14 : .22),
                        teal500.withOpacity(compact ? .05 : .09),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.42, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              left: -46,
              bottom: -82,
              child: IgnorePointer(
                child: Container(
                  width: compact ? 120 : 200,
                  height: compact ? 120 : 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(
                          0xFF12489A,
                        ).withOpacity(compact ? .18 : .28),
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

class SignupProgress extends StatelessWidget {
  final int step;
  const SignupProgress({super.key, required this.step});

  static const Color teal500 = Color(0xFF14B8A6);
  static const Color teal50 = Color(0xFFE9FBF8);
  static const Color line = Color(0xFFE3E9F3);
  static const Color inkFaint = Color(0xFF8C9AB1);
  static const Color inkSoft = Color(0xFF5B6B85);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _node(label: 'Account', index: 1, state: _stateFor(1)),
        _line(filled: step >= 2),
        _node(label: 'Verify', index: 2, state: _stateFor(2)),
        _line(filled: step >= 3),
        _node(label: 'Business', index: 3, state: _stateFor(3)),
      ],
    );
  }

  _ProgressState _stateFor(int index) {
    if (index < step) return _ProgressState.done;
    if (index == step) return _ProgressState.active;
    return _ProgressState.upcoming;
  }

  Widget _line({required bool filled}) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20),
        color: filled ? teal500 : line,
      ),
    );
  }

  Widget _node({
    required String label,
    required int index,
    required _ProgressState state,
  }) {
    final isActive = state == _ProgressState.active;
    final isDone = state == _ProgressState.done;

    return SizedBox(
      width: 38,
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive || isDone ? teal500 : line,
                width: 2,
              ),
              color: isDone
                  ? teal500
                  : isActive
                  ? teal50
                  : Colors.white,
            ),
            alignment: Alignment.center,
            child: isDone
                ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                : Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isActive ? teal500 : inkFaint,
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: isActive || isDone ? teal500 : inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ProgressState { done, active, upcoming }

class SignupBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;

  const SignupBackButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: const Color(0xFF5B6B85),
        ),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class MailIllustration extends StatelessWidget {
  const MailIllustration();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          color: const Color(0xFFE9FBF8),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFC7EFE9)),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.mail_outline_rounded,
          size: 38,
          color: Color(0xFF0D9488),
        ),
      ),
    );
  }
}
