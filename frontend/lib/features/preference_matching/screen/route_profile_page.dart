// File: lib/features/preference_matching/screens/route_profile_page.dart
// ============================================
// HƯỚNG DẪN ĐIỀU CHỈNH THÔNG SỐ ROUTE PROFILE
// ============================================
// 
// 1. DRAGGABLE SHEET (Dòng 44-46):
//    - initialChildSize: 0.68 = Chiều cao ban đầu (68% màn hình)
//    - minChildSize: 0.68 = Chiều cao tối thiểu khi kéo xuống
//    - maxChildSize: 0.9 = Chiều cao tối đa khi kéo lên (90% màn hình)
//
// 2. GRADIENT OVERLAY (Dòng 51-59):
//    - Colors.transparent = Trong suốt ở trên
//    - Colors.black.withOpacity(0.5) = Đen mờ 50% ở giữa
//    - Colors.black.withOpacity(0.8) = Đen mờ 80% ở dưới
//    - stops: [0.0, 0.1, 0.5] = Điểm chuyển màu
//
// 3. VIỀN KHUNG CHÍNH (Dòng 64):
//    - margin: EdgeInsets.fromLTRB(16, 16, 16, 32) = Khoảng cách từ mép
//      + 16px trái, phải, trên
//      + 32px dưới (tránh gạch ngang điện thoại)
//    - padding: EdgeInsets.all(20) = Khoảng cách bên trong khung
//
// 4. ĐƯỜNG VIỀN TRẮNG (Dòng 67-69):
//    - color: Colors.white.withOpacity(0.3) = Màu trắng mờ 30%
//    - width: 1.5 = Độ dày viền 1.5px
//    - borderRadius: 24 = Bo góc 24px
//
// 5. TEXT STYLES:
//    - Tên route (Dòng 79): fontSize 32, bold, trắng
//    - Location (Dòng 85): fontSize 18, trắng 70%
//
// 6. STAT BOXES (hàm _buildStatBox - Dòng 173):
//    - padding: 16px = Khoảng cách bên trong mỗi box
//    - background: Colors.white.withOpacity(0.1) = Nền trắng mờ 10%
//    - border: width 1.5px, opacity 0.3 = Viền trắng mờ
//    - borderRadius: 12px = Bo góc
//    - Số chính: fontSize 32, bold
//    - Đơn vị: fontSize 16
//    - Label: fontSize 13
//
// 7. NÚT "BẢN ĐỒ" (Dòng 138):
//    - backgroundColor: #76C83A = Màu xanh lá
//    - padding: vertical 18px = Chiều cao nút
//    - fontSize: 18, fontWeight w600
//    - borderRadius: 12px = Bo góc
//    - letterSpacing: 0.5 = Khoảng cách chữ
//
// ============================================

import 'package:flutter/material.dart';
import '../models/route_model.dart';
import 'interactive_map_page.dart';

class RouteProfilePage extends StatelessWidget {
  final RouteModel route;

  const RouteProfilePage({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Image - Full Screen
          Positioned.fill(
            child: Image.network(
              route.imageUrl,
              fit: BoxFit.cover,
            ),
          ),
          // Content Sheet with Gradient Overlay
          DraggableScrollableSheet(
            initialChildSize: 0.68,
            minChildSize: 0.68,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.8),
                    ],
                    stops: const [0.0, 0.1, 0.5],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text(
                        route.name,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        route.location,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Stats Grid - 2x2
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatBox(
                              "${route.distanceKm}",
                              "km",
                              "Tổng chiều dài",
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatBox(
                              "${route.elevationGainM}",
                              "m",
                              "Độ dốc tích lũy",
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatBox(
                              "${route.durationDays}",
                              "ngày ${route.durationNights}đêm",
                              "Quãng thời gian\nước tính",
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatBox(
                              route.terrain,
                              "",
                              "Địa hình",
                            ),
                          ),
                        ],
                      ),
                       const SizedBox(height: 32),
                       SizedBox(
                         width: double.infinity,
                         child: ElevatedButton(
                           onPressed: () {
                             Navigator.push(
                               context,
                               MaterialPageRoute(builder: (context) => InteractiveMapPage(route: route)),
                             );
                           },
                           style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF76C83A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                           ),
                           child: const Text(
                             "Bản đồ",
                             style: TextStyle(
                               fontSize: 18,
                               fontWeight: FontWeight.w600,
                               letterSpacing: 0.5,
                             ),
                           ),
                         ),
                       ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String mainValue, String subValue, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                mainValue,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              if (subValue.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    subValue,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}