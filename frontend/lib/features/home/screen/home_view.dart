import 'package:flutter/material.dart';
import 'package:frontend/features/home/widgets/route_card.dart';
import 'package:frontend/features/preference_matching/screen/route_profile_page.dart';
import 'package:frontend/features/preference_matching/models/route_model.dart';
import 'package:frontend/features/preference_matching/models/mock_route.dart'; // Backup data
import 'package:frontend/utils/app_colors.dart';
import 'package:frontend/utils/app_styles.dart';
import 'package:frontend/screens/home_screen.dart';
import 'package:frontend/widgets/custom_button.dart';

class HomeView extends StatelessWidget {
  // Accepts data from WaitingScreen
  final List<RouteModel>? suggestedRoutes;

  const HomeView({super.key, this.suggestedRoutes});

  @override
  Widget build(BuildContext context) {
    // Priority: API Data > Mock Data
    final List<RouteModel> displayRoutes = suggestedRoutes ?? mockRoutes;

    final String title = suggestedRoutes != null
        ? 'Kết quả phù hợp nhất'
        : 'Gợi ý cho bạn';

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        title: const Text('Gợi ý cho bạn', style: AppStyles.appBarTitle),
        backgroundColor: AppColors.lightGray,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: displayRoutes.isEmpty
          ? const Center(child: Text("Không tìm thấy lộ trình phù hợp :("))
          : ListView(
              // RESOLVED: Use the specific padding from UI branch to avoid bottom sheet overlap
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                const SizedBox(height: 16),
                Text(title, style: AppStyles.heading),
                const SizedBox(height: 16),

                ...displayRoutes.map((route) => Padding(
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
      bottomSheet: Container(
        color: AppColors.lightGray,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: CustomButton(
          text: 'Trang chủ',
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          },
        ),
      ),
    );
  }
}