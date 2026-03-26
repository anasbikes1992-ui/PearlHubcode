// lib/services/auth_service.dart
// Mirrors AuthContext.tsx — real Supabase signInWithPassword, not mock auth

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile.dart';

// ── Supabase client singleton ──────────────────────────────────────────────
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ── Auth state ─────────────────────────────────────────────────────────────
class AuthState {
  final User? user;
  final UserProfile? profile;
  final bool loading;
  final String? error;

  const AuthState({
    this.user,
    this.profile,
    this.loading = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    UserProfile? profile,
    bool? loading,
    String? error,
    bool clearUser = false,
    bool clearProfile = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      profile: clearProfile ? null : (profile ?? this.profile),
      loading: loading ?? this.loading,
      error: error,
    );
  }

  bool get isAuthenticated => user != null && profile != null;
  bool get isAdmin => profile?.role == UserRole.admin;
  bool get isProvider => profile?.role.isProvider ?? false;
}

// ── Auth notifier — mirrors AuthContext logic exactly ──────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseClient _supabase;

  AuthNotifier(this._supabase) : super(const AuthState(loading: true)) {
    _init();
  }

  void _init() {
    // Listen to Supabase auth changes — same as onAuthStateChange in web
    _supabase.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (user != null) {
        await _fetchProfile(user.id);
      } else {
        state = const AuthState();
      }
    });

    // Check existing session on launch
    final existing = _supabase.auth.currentUser;
    if (existing != null) {
      _fetchProfile(existing.id);
    } else {
      state = const AuthState();
    }
  }

  Future<void> _fetchProfile(String userId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      final profile = UserProfile.fromJson(data);
      state = AuthState(
        user: _supabase.auth.currentUser,
        profile: profile,
      );
    } catch (e) {
      // Profile may not exist for brand-new signups (same as web app behaviour)
      state = AuthState(
        user: _supabase.auth.currentUser,
        error: e.toString(),
      );
    }
  }

  // ── Sign in — matches web: supabase.auth.signInWithPassword ──────────────
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(loading: true);
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return null; // null = success
    } on AuthException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return e.message;
    }
  }

  // ── Sign up ───────────────────────────────────────────────────────────────
  Future<String?> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
  }) async {
    state = state.copyWith(loading: true);
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': role.dbValue,
          if (phone != null) 'phone': phone,
        },
      );
      return null;
    } on AuthException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return e.message;
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    state = const AuthState();
  }

  // ── Password reset ────────────────────────────────────────────────────────
  Future<String?> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  // ── Refresh profile (after role/profile update) ───────────────────────────
  Future<void> refreshProfile() async {
    final user = _supabase.auth.currentUser;
    if (user != null) await _fetchProfile(user.id);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(supabaseProvider));
});
