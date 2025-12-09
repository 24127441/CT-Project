// lib/services/session_lifecycle_service.dart
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionLifecycleService {
  static const String _keyLastPid = 'last_known_pid';

  /// Trả về TRUE nếu là Cold Start (Cần đăng xuất)
  /// Trả về FALSE nếu là Hot Restart (Giữ session)
  static Future<bool> checkIsColdStart() async {
    debugPrint("--- [SessionLifecycle] Bắt đầu kiểm tra ---");

    final prefs = await SharedPreferences.getInstance();
    final int currentPid = pid;
    final int? lastPid = prefs.getInt(_keyLastPid);

    bool isColdStart = false;

    // Logic kiểm tra
    if (lastPid != null && lastPid != currentPid) {
      debugPrint("--- [SessionLifecycle] => PHÁT HIỆN COLD START (PID đổi từ $lastPid sang $currentPid). Signing out to enforce logout on cold start.");
      // On cold start, clear Supabase session so users are logged out.
      await _clearInvalidSession();
      isColdStart = true;
    } else {
      debugPrint("--- [SessionLifecycle] => Hot Restart hoặc lần đầu chạy (PID $currentPid). Giữ nguyên.");
      isColdStart = false;
    }

    // Luôn cập nhật PID mới nhất
    await prefs.setInt(_keyLastPid, currentPid);

    return isColdStart;
  }

  /// Clear invalid session gracefully, handling refresh token errors
  static Future<void> _clearInvalidSession() async {
    try {
      final client = Supabase.instance.client;
      
      // Check if there's a current session
      if (client.auth.currentSession != null) {
        // Try to sign out gracefully with local scope to avoid refresh token call
        await client.auth.signOut(scope: SignOutScope.local);
        debugPrint('--- [SessionLifecycle] Supabase signOut() completed.');
      } else {
        debugPrint('--- [SessionLifecycle] No active session to clear.');
      }
    } on AuthException catch (e) {
      // Handle specific auth errors like invalid refresh token
      if (e.statusCode == '400' || e.message.contains('refresh_token')) {
        debugPrint('--- [SessionLifecycle] Invalid refresh token detected. Clearing local session.');
        // Force clear local session data without calling the server
        try {
          await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
        } catch (_) {
          // Ignore errors on forced local signout
        }
      } else {
        debugPrint('--- [SessionLifecycle] AuthException during signOut: ${e.message}');
      }
    } catch (e) {
      debugPrint('--- [SessionLifecycle] Error clearing session: ${e.toString()}');
      // Try to clear local storage even if signOut fails
      try {
        await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        // Ignore
      }
    }
  }

  /// Validate current session and clear if invalid
  static Future<bool> validateSession() async {
    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      
      if (session == null) {
        debugPrint('--- [SessionLifecycle] No session found.');
        return false;
      }

      // Check if token is expired
      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (now >= expiresAt) {
          debugPrint('--- [SessionLifecycle] Session expired. Clearing.');
          await _clearInvalidSession();
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('--- [SessionLifecycle] Session validation failed: $e');
      await _clearInvalidSession();
      return false;
    }
  }
}