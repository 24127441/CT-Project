// File: lib/features/preference_matching/screens/preference_matching_page.dart
// ============================================
// HƯỚNG DẪN ĐIỀU CHỈNH THÔNG SỐ PREFERENCE MATCHING
// ============================================
//
// 1. SCAFFOLD:
//    - backgroundColor: #F4F4F4 = Màu nền xám nhạt (Dòng 19)
//
// 2. APP BAR (Dòng 20-24):
//    - title: "Cung đường phù hợp" = Tiêu đề
//    - backgroundColor: Colors.transparent = Trong suốt
//    - elevation: 0 = Không đổ bóng
//    - foregroundColor: Colors.black = Màu chữ đen
//
// 3. ROUTE LIST (Dòng 33-48):
//    - padding: horizontal 16.0 = Khoảng cách 2 bên
//    - itemCount: routeList.length = Số lượng route
//    - Sử dụng ListView.builder để hiển thị danh sách
//
// 4. EMPTY STATE (Dòng 50-77):
//    - padding: 32.0 = Khoảng cách xung quanh
//    - Image height: 150 = Chiều cao hình ảnh trống
//    - SizedBox height: 24 = Khoảng cách giữa các phần tử
//
// 5. TEXT STYLES:
//    - Empty message (Dòng 60): fontSize 18, fontWeight w600
//    - textAlign: center = Căn giữa
//
// 6. NÚT VỀ TRANG CHỦ (Dòng 64-73):
//    - backgroundColor: #76C83A = Màu xanh lá
//    - foregroundColor: Colors.white = Chữ trắng
//    - padding: horizontal 40, vertical 16 = Kích thước nút
//    - borderRadius: 30 = Bo góc tròn
//    - Text: "VỀ TRANG CHỦ"
//
// 7. NAVIGATION:
//    - Navigator.push → RouteProfilePage = Xem chi tiết route (Dòng 41)
//    - Navigator.popUntil → Về trang đầu (Dòng 68)
//
// ============================================

import 'package:flutter/material.dart';
import '../models/route_model.dart';
import '../widget/route_suggestion_card.dart';
import 'route_profile_page.dart'; // Màn hình tiếp theo

class PreferenceMatchingPage extends StatelessWidget {
  // Giả sử đây là danh sách route nhận được từ API
  // Để test trường hợp rỗng, chỉ cần truyền vào một list rỗng: final List<RouteModel> routes = [];
  final List<RouteModel>? routes;

  const PreferenceMatchingPage({super.key, this.routes});

  @override
  Widget build(BuildContext context) {
    final routeList = routes ?? [];
    
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        title: const Text("Cung đường phù hợp"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: routeList.isEmpty
          ? _buildEmptyState(context)
          : _buildRouteList(context, routeList),
    );
  }

  Widget _buildRouteList(BuildContext context, List<RouteModel> routeList) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: routeList.length,
      itemBuilder: (context, index) {
        final route = routeList[index];
        return RouteSuggestionCard(
          route: route,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RouteProfilePage(route: route),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Thay bằng file ảnh của bạn trong assets
            Image.asset('assets/images/empty_state.png', height: 150),
            const SizedBox(height: 24),
            const Text(
              "Không có cung đường nào\nphù hợp với nhu cầu của bạn!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Quay về trang chủ
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF76C83A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("VỀ TRANG CHỦ"),
            ),
          ],
        ),
      ),
    );
  }
}