import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wetaran_pharma/core/config/app_constants.dart';

class SupabaseInitializer {
  static Future<void> initalize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
    );
  }
}
