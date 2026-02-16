import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class AuthService {
  final _client = Supabase.instance.client;

  /// Check if email already exists using Supabase RPC function
  Future<bool> emailExists(String email) async {
    try {
      debugPrint('[AuthService] Checking if email exists via RPC: $email');
      
      // Call the Supabase RPC function to check email existence
      final response = await _client.rpc('check_email_exists', 
        params: {'email_to_check': email}
      );
      
      final exists = response as bool;
      debugPrint('[AuthService] Email exists: $exists');
      return exists;
      
    } catch (e) {
      debugPrint('[AuthService] Error checking email via RPC: $e');
      // On error, return false to allow signup attempt (fail-open)
      return false;
    }
  }

  Future<AuthResponse> register(String email, String password) async {
    try {
      debugPrint('[AuthService] Attempting to register: $email');
      final response = await _client.auth.signUp(email: email, password: password);
      debugPrint('[AuthService] Registration successful: ${response.user?.id}');
      return response;
    } on AuthException catch (e) {
      debugPrint('[AuthService] Registration failed - AuthException: ${e.message} (${e.statusCode})');
      rethrow;
    } catch (e) {
      debugPrint('[AuthService] Registration failed - Exception: $e');
      rethrow;
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return _client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async => await _client.auth.signOut();

  Session? get currentSession => _client.auth.currentSession;

  Future<void> sendEmailOtp(String email) async {
    await _client.auth.signInWithOtp(email: email);
  }

  Future<void> verifyEmailOtp(String email, String token) async {
    try {
      final response = await _client.auth.verifyOTP(
        token: token,
        type: OtpType.email,
        email: email,
      );

      if (response.session == null && _client.auth.currentSession == null) {
        throw Exception("SDK Verify OK but Session is NULL");
      }
    } catch (e) {

      debugPrint("SDK Verify failed or no session, falling back to REST: $e");
      await _verifyEmailOtpRest(email, token);
    }
  }

  Future<void> _verifyEmailOtpRest(String email, String token) async {
    // This method is no longer needed - verifyOTP from SDK is sufficient
    // Keeping as fallback but we shouldn't reach here
    throw Exception('REST verify fallback not implemented');
  }
}