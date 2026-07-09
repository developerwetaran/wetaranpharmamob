import 'package:flutter/material.dart';
import 'package:wetaran_pharma/features/splash/presentation/pages/splash_page.dart';

class WetaranPharmaApp extends StatelessWidget {
  const WetaranPharmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wetaran Pharma',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0066CC),
        fontFamily: 'IBMPlexSans',
      ),
      home: const SplashPage(),
    );
  }
}
