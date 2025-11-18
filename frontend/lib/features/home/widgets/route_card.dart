// File: lib/features/home/widgets/route_card.dart
// ============================================
// HƯỚNG DẪN ĐIỀU CHỈNH THÔNG SỐ ROUTE CARD
// ============================================
//
// 1. CARD CONTAINER (Dòng 13-16):
//    - elevation: 4 = Độ cao đổ bóng
//    - clipBehavior: Clip.antiAlias = Cắt mượt các góc
//    - borderRadius: 12 = Bo góc card
//
// 2. ROUTE IMAGE (Dòng 22-34):
//    - height: 150 = Chiều cao hình ảnh
//    - width: double.infinity = Rộng toàn bộ card
//    - fit: BoxFit.cover = Cắt ảnh vừa khung
//    - errorBuilder: Hiển thị icon grey khi ảnh lỗi
//      + Container height: 150
//      + Icon size: 50
//
// 3. CONTENT PADDING (Dòng 36):
//    - padding: 12.0 = Khoảng cách xung quaround nội dung text
//
// 4. TEXT STYLES:
//    - Route name (Dòng 41): fontSize 18, fontWeight bold
//    - Location (Dòng 45): fontSize 14, color grey shade 600
//    - Description (Dòng 49-51):
//      + fontSize: 12
//      + maxLines: 2 = Tối đa 2 dòng
//      + overflow: TextOverflow.ellipsis = Thêm "..." nếu dài
//      + color: grey shade 700
//
// 5. SPACING:
//    - SizedBox height: 4 = Khoảng cách giữa name và location (Dòng 44)
//    - SizedBox height: 8 = Khoảng cách giữa location và description (Dòng 48)
//
// 6. INTERACTION:
//    - InkWell onTap = Hiệu ứng ripple khi nhấn
//    - Callback onTap để điều hướng
//
// ============================================

import 'package:flutter/material.dart';
import 'package:frontend/features/preference_matching/models/route_model.dart';

class RouteCard extends StatelessWidget {
  final RouteModel route;
  final VoidCallback? onTap;
  
  const RouteCard({super.key, required this.route, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route Image
            Image.network(
              route.imageUrl,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 150,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.image, size: 50, color: Colors.grey),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    route.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    route.location,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    route.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}