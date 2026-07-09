import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wetaran_pharma/features/profile/models/pharma_user_profile.dart';

class PharmaProfileService {
  PharmaProfileService._();
  static final PharmaProfileService instance = PharmaProfileService._();

  final _client = Supabase.instance.client;

  Future<PharmaUserProfile?> fetchCurrentProfile() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return null;

    final row = await _client
        .from('pharma_users')
        .select()
        .eq('auth_user_id', authUser.id)
        .maybeSingle();

    if (row == null) return null;
    return PharmaUserProfile.fromMap(row);
  }
}
