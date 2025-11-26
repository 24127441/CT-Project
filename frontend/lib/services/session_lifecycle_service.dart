// lib/services/session_lifecycle_service.dart
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionLifecycleService {
  static const String _keyLastPid = 'last_known_pid';

  /// Trả về TRUE nếu là Cold Start (Cần đăng xuất)
  /// Trả về FALSE nếu là Hot Restart (Giữ session)
  static Future<bool> checkIsColdStart() async {
    print("--- [SessionLifecycle] Bắt đầu kiểm tra ---");

    final prefs = await SharedPreferences.getInstance();
    final int currentPid = pid;
    final int? lastPid = prefs.getInt(_keyLastPid);

    bool isColdStart = false;

    // Logic kiểm tra
    if (lastPid != null && lastPid != currentPid) {
      print("--- [SessionLifecycle] => PHÁT HIỆN COLD START (PID đổi từ $lastPid sang $currentPid).");
      // Thực hiện đăng xuất ở backend cho sạch sẽ
      await Supabase.instance.client.auth.signOut();
      isColdStart = true;
    } else {
      print("--- [SessionLifecycle] => Hot Restart hoặc lần đầu chạy (PID $currentPid). Giữ nguyên.");
      isColdStart = false;
    }

    // Luôn cập nhật PID mới nhất
    await prefs.setInt(_keyLastPid, currentPid);

    return isColdStart;
  }
}