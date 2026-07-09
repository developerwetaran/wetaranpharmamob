import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wetaran_pharma/app/app.dart';
import 'package:wetaran_pharma/core/config/supabase_initializer.dart';
import 'package:wetaran_pharma/features/orders/models/pharma_cart_provider.dart';

Future<void> bootstrap() async {
  await SupabaseInitializer.initalize();

  final pharmaCartProvider = PharmaCartProvider();
  await pharmaCartProvider.load();

  runApp(
    ChangeNotifierProvider<PharmaCartProvider>.value(
      value: pharmaCartProvider,
      child: const WetaranPharmaApp(),
    ),
  );
}
