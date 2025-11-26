import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import '../core/supabase_config.dart';

class AuthService {
  final _client = Supabase.instance.client;

  // ------------------
  // Public API
  // ------------------

  Future<AuthResponse> register(String email, String password) async {
    return await _client.auth.signUp(email: email, password: password);
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

  /// Gửi OTP
  Future<void> sendEmailOtp(String email) async {
    await _client.auth.signInWithOtp(email: email);
  }

  /// Xác thực OTP (Logic đã được sửa lại chuẩn cho SDK v2)
  Future<void> verifyEmailOtp(String email, String token) async {
    try {
      // CÁCH 1: Dùng hàm chuẩn của SDK v2
      // Hàm này tự động lưu session nếu thành công
      final response = await _client.auth.verifyOTP(
        token: token,
        type: OtpType.email,
        email: email,
      );

      // Kiểm tra xem session đã thực sự có chưa
      if (response.session == null && _client.auth.currentSession == null) {
        throw Exception("SDK Verify OK but Session is NULL");
      }
    } catch (e) {
      // Nếu Cách 1 lỗi (hoặc SDK không lưu được session), dùng CÁCH 2:
      // Gọi REST API thủ công và ép lưu Session
      print("SDK Verify failed or no session, falling back to REST: $e");
      await _verifyEmailOtpRest(email, token);
    }
  }

  // ------------------
  // Private Helpers
  // ------------------

  Future<void> _verifyEmailOtpRest(String email, String token) async {
    final dio = Dio();
    final endpoint = '$supabaseUrl/auth/v1/verify';
    final headers = {
      'apikey': supabaseAnonKey,
      'Content-Type': 'application/json',
    };
    final body = {'email': email, 'token': token, 'type': 'email'};

    try {
      final resp = await dio.post(endpoint, data: body, options: Options(headers: headers));

      if (resp.statusCode != null && (resp.statusCode! >= 200 && resp.statusCode! < 300)) {
        // Lấy dữ liệu trả về
        final data = resp.data;
        // Quan trọng: Lấy refresh_token để khôi phục session
        if (data is Map<String, dynamic>) {
          final refreshToken = data['refresh_token'];
          final accessToken = data['access_token'];

          if (refreshToken != null) {
            // Ép SDK lưu session mới từ refresh token
            await _client.auth.setSession(refreshToken);
            return;
          } else if (accessToken != null) {
            // Trường hợp hy hữu chỉ có access token (ít gặp ở verify)
            // Ta không làm gì được nhiều vì setSession cần refresh token ở bản mới
            throw Exception("No refresh token received from REST verify");
          }
        }
        return; // Thành công
      }
    } catch (e) {
      throw Exception('REST verify failed: $e');
    }
    throw Exception('REST verify failed with unknown error');
  }
}