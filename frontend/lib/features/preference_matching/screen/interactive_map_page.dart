// File: lib/features/preference_matching/screens/interactive_map_page.dart
// ============================================
// HƯỚNG DẪN ĐIỀU CHỈNH THÔNG SỐ INTERACTIVE MAP
// ============================================
//
// 1. NÚT BACK (Dòng 26-35):
//    - top: 50 = Khoảng cách từ trên xuống
//    - left: 16 = Khoảng cách từ trái
//    - backgroundColor: Colors.white = Màu nền nút
//    - CircleAvatar tạo nút tròn
//
// 2. NÚT TÙY CHỈNH (Dòng 38-59):
//    - bottom: 200 = Khoảng cách từ dưới lên (tránh bottom sheet)
//    - left: 16 = Khoảng cách từ trái
//    - padding: horizontal 16, vertical 8 = Kích thước nút
//    - backgroundColor: Colors.black.withOpacity(0.6) = Màu nền đen mờ 60%
//    - borderRadius: 20 = Bo góc nút
//    - Icon size: 18 = Kích thước icon
//    - fontSize: 14 = Kích thước chữ
//
// 3. NÚT 3D (Dòng 62-82):
//    - top: 50 = Khoảng cách từ trên xuống
//    - right: 16 = Khoảng cách từ phải
//    - padding: horizontal 12, vertical 6 = Kích thước nút
//    - backgroundColor: Colors.white.withOpacity(0.9) = Nền trắng mờ 90%
//    - borderRadius: 20 = Bo góc
//    - Icon size: 18
//    - fontWeight: w600
//
// 4. BOTTOM INFO SHEET (Dòng 85-158):
//    - padding: fromLTRB(24, 24, 24, 32) = Khoảng cách trong sheet
//    - borderRadius: vertical top 24 = Bo góc trên
//    - boxShadow: blurRadius 20, spreadRadius 5 = Đổ bóng
//
// 5. TEXT STYLES:
//    - Tên route (Dòng 95): fontSize 22, bold
//    - Thông tin (Dòng 99): fontSize 14, grey
//    - AI Note title (Dòng 120): fontSize 16, bold
//    - AI Note content (Dòng 124): fontSize 14
//
// 6. ELEVATION GRAPH (Dòng 103-117):
//    - height: 80 = Chiều cao biểu đồ
//    - borderRadius: 8 = Bo góc
//    - backgroundColor: Colors.grey.shade100
//
// 7. NÚT XÁC NHẬN (Dòng 129-144):
//    - backgroundColor: #76C83A = Màu xanh lá
//    - padding: vertical 16 = Chiều cao nút
//    - borderRadius: 30 = Bo góc tròn
//    - fontSize: 16
//
// ============================================

import 'package:flutter/material.dart';
import '../models/route_model.dart';

class InteractiveMapPage extends StatelessWidget {
  final RouteModel route;
  const InteractiveMapPage({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Placeholder for the map
          // Thay thế bằng widget GoogleMap của bạn
          Container(
            color: Colors.grey.shade300,
            child: Center(
              // Dùng ảnh map tĩnh làm placeholder
              child: Image.asset('assets/images/map_placeholder.png', fit: BoxFit.cover, width: double.infinity, height: double.infinity,),
            ),
          ),
          // Back Button
          Positioned(
            top: 50,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          // Tùy chỉnh Button
          Positioned(
            bottom: 200,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    "Tùy chỉnh",
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          // 3D Button
          Positioned(
            top: 50,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.layers, size: 18, color: Colors.grey.shade700),
                  const SizedBox(width: 4),
                  Text(
                    "3D",
                    style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          // Bottom Info Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5)
                ]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${route.name} - ${route.location}",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${route.distanceKm} km . ${route.elevationGainM} m gain . Est. ${route.durationDays} days",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  // Placeholder for elevation graph
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Image.network(
                        'https://via.placeholder.com/300x80/E8E8E8/999999?text=Elevation+Graph',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Text(
                            "Elevation Graph",
                            style: TextStyle(color: Colors.grey.shade500),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "AI Note:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    route.aiNote,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                   const SizedBox(height: 24),
                  SizedBox(
                     width: double.infinity,
                     child: ElevatedButton(
                       onPressed: () {
                         // Logic xác nhận lộ trình
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text("Lộ trình đã được xác nhận!"))
                         );
                       },
                       style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF76C83A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                       ),
                       child: const Text("XÁC NHẬN LỘ TRÌNH", style: TextStyle(fontSize: 16)),
                     ),
                   )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}