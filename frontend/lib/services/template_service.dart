import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint;
import 'token_service.dart';
import '../models/trip_template.dart';

class TemplateService {
  // ---------------------------------------------------------
  // BƯỚC 1: CẤU HÌNH IP
  // Nếu chạy máy ảo Android: dùng 10.0.2.2
  // Nếu chạy máy thật: dùng IP máy tính (VD: 192.168.1.12)
  // ---------------------------------------------------------
  static const String _serverIp = '10.0.2.2'; // Đổi thành IP LAN nếu chạy máy thật
  static const String baseUrl = 'http://$_serverIp:8000/api/auth/templates/';
  // LƯU Ý: Kiểm tra lại xem backend của bạn là 'api/auth/templates/'
  // hay là 'api/templates/' hay 'api/history-inputs/'?

  final TokenService _tokenService = TokenService();

  // 1. GET: Lấy danh sách mẫu
  Future<List<TripTemplate>> getTemplates() async {
    final token = await _tokenService.getToken();
    debugPrint("==== TOKEN ====");
    debugPrint(token);
    // Debug log
    debugPrint("GET Templates - Token: ${token != null ? 'Có' : 'Không'}");
    if (token == null) return [];

    try {
      debugPrint("Đang gọi API: $baseUrl");
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint("Response Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        // Fix lỗi charset nếu bị lỗi font tiếng Việt
        String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> data = jsonDecode(responseBody);
        return data.map((json) => TripTemplate.fromJson(json)).toList();
      } else {
        debugPrint('Lỗi Server: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Lỗi kết nối (GET): $e');
      return [];
    }
  }

  // 2. POST: Lưu mẫu mới
  Future<bool> saveTemplate(Map<String, dynamic> templateData) async {
    final token = await _tokenService.getToken();

    if (token == null) {
      debugPrint("Lỗi: Chưa đăng nhập (Token null)");
      return false;
    }

    try {
      debugPrint("Đang POST tới: $baseUrl");
      debugPrint("Dữ liệu gửi đi: ${jsonEncode(templateData)}");

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(templateData),
      );

      debugPrint("POST Status Code: ${response.statusCode}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint("✅ Lưu thành công!");
        return true;
      } else {
        // In chi tiết lỗi từ Backend
        debugPrint("❌ Lưu thất bại. Server phản hồi: ${response.body}");

        // Thử throw exception để UI hiện thông báo
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        if (errorData is Map && errorData['name'] != null) {
          throw Exception("Tên mẫu này đã tồn tại, vui lòng chọn tên khác.");
        }
        throw Exception('Lỗi Server: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Lỗi kết nối (POST): $e');
      rethrow;
    }
  }
}