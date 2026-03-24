import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

class AuthModule {
  final SupabaseClient _supabase;
  AuthModule(this._supabase);

  Future<User> signUp(String email, String password, String fullName) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
    return response.user!;
  }

  Future<Session> signIn(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.session!;
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<Profile> getProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final data = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();
    return Profile.fromJson(data);
  }

  Future<Profile> updateProfile({
    String? fullName,
    String? avatarUrl,
    String? phone,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (phone != null) updates['phone'] = phone;
    final data = await _supabase
        .from('profiles')
        .update(updates)
        .eq('id', user.id)
        .select()
        .single();
    return Profile.fromJson(data);
  }
}
