// File: lib/features/home/screens/home_view.dart
// ============================================
// HƯỚNG DẪN ĐIỀU CHỈNH THÔNG SỐ HOME VIEW
// ============================================
//
// 1. APP BAR (Dòng 18-21):
//    - title: 'Suggested Routes' = Tiêu đề
//    - backgroundColor: #386A20 = Màu xanh lá đậm
//    - foregroundColor: Colors.white = Chữ trắng
//
// 2. BODY LAYOUT (Dòng 23-47):
//    - ListView để có thể cuộn
//    - padding: 16.0 = Khoảng cách xung quaround nội dung
//
// 3. NÚT TEST PREFERENCE MATCHING (Dòng 26-33):
//    - ElevatedButton để test tính năng
//    - Text: "Tìm Cung Đường Phù Hợp (Test)"
//    - Điều hướng đến PreferenceMatchingPage với mockRoutes
//
// 4. SPACING:
//    - SizedBox height: 16 = Khoảng cách giữa nút test và danh sách
//    - padding bottom: 16 = Khoảng cách giữa các route card (Dòng 39)
//
// 5. ROUTE CARDS:
//    - Sử dụng mockRoutes.map() để tạo danh sách card
//    - Mỗi RouteCard có onTap điều hướng đến RouteProfilePage
//
// 6. NAVIGATION:
//    - Test button → PreferenceMatchingPage(routes: mockRoutes)
//    - RouteCard → RouteProfilePage(route: route)
//
// 7. DATA SOURCE:
//    - mockRoutes từ lib/features/preference_matching/models/mock_route.dart
//
// ============================================

import 'package:flutter/material.dart';
import 'package:frontend/features/home/widgets/route_card.dart';
import 'package:frontend/features/preference_matching/screen/preference_matching_page.dart';
import 'package:frontend/features/preference_matching/screen/route_profile_page.dart';
import 'package:frontend/features/preference_matching/models/mock_route.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suggested Routes'),
        backgroundColor: const Color(0xFF386A20), // Màu xanh lá
        foregroundColor: Colors.white,
      ),
      // Sử dụng ListView để có thể cuộn nếu nội dung dài
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // NÚT ĐỂ TEST TÍNH NĂNG PREFERENCE MATCHING
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PreferenceMatchingPage(routes: mockRoutes)),
              );
            },
            child: const Text("Tìm Cung Đường Phù Hợp (Test)"),
          ),
          
          const SizedBox(height: 16),

          // SUGGESTED ROUTE CARDS
          ...mockRoutes.map((route) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: RouteCard(
              route: route,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RouteProfilePage(route: route),
                  ),
                );
              },
            ),
          )),
        ],
      ),
    );
  }
}