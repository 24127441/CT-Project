import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';
import '../models/trip_template.dart';

class TemplateService {
  // Adjust IP as needed (10.0.2.2 for Emulator, LAN IP for real device)
  static const String baseUrl = 'http://10.0.2.2:8000/api/auth/templates/';
  final TokenService _tokenService = TokenService();

  // 1. GET: Fetch list of templates
  Future<List<TripTemplate>> getTemplates() async {
    final token = await _tokenService.getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => TripTemplate.fromJson(json)).toList();
      } else {
        print('Failed to load templates: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching templates: $e');
      return [];
    }
  }

  // 2. POST: Save a new template
  Future<bool> saveTemplate(Map<String, dynamic> templateData) async {
    final token = await _tokenService.getToken();
    if (token == null) return false;

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(templateData),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        // Throw exception to show specific error message from backend (e.g., duplicate name)
        final errorData = jsonDecode(response.body);
        if (errorData['name'] != null) {
          throw Exception(errorData['name'][0]);
        }
        throw Exception('Lỗi không xác định khi lưu mẫu');
      }
    } catch (e) {
      rethrow; // Let the Provider/UI handle the error display
    }
  }
}