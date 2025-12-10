// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'tripinfopart1.dart';
import 'fast_input.dart';
import 'trip_list.dart' as trip_list;
import 'profile_screen.dart';
import '../providers/achievement_provider.dart';
import '../models/achievement.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // State to track if the "Plan" card is expanded
  bool _isPlanExpanded = false;

  // Define the Green Color from the design
  final Color _forestGreen = const Color(0xFF425E3C);

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    // Get user's full name from metadata, fallback to email name, then to generic greeting
    String userName = currentUser?.userMetadata?['full_name'] as String? ?? '';
    if (userName.isEmpty && currentUser?.email != null) {
      // Extract first part of email as fallback
      userName = currentUser!.email!.split('@').first;
    }
    if (userName.isEmpty) {
      userName = 'Người dùng';
    }
    
    // Get current time for greeting
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Chào buổi sáng' : hour < 18 ? 'Chào buổi chiều' : 'Chào buổi tối';
    final greetingIcon = hour < 12 ? Icons.wb_sunny : hour < 18 ? Icons.wb_sunny_outlined : Icons.nightlight_round;
    
    return Scaffold(
      body: Column(
        children: [
          // 1. HEADER SECTION with Forest Background Image
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Forest Background Image
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: const AssetImage('assets/images/home_background.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Dark overlay to ensure text readability
                Container(
                  color: Colors.black.withValues(alpha: 0.25),
                ),
                // Decorative Elements
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 30,
                  left: -30,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.03),
                    ),
                  ),
                ),
                // Content
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Bar with Settings
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  greetingIcon,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  greeting,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                                                        GestureDetector(
                              onTap: () async {
                                // Navigate to profile screen
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ProfileScreen(),
                                  ),
                                );

                                // Refresh user data after returning from profile screen
                                if (mounted) {
                                  // Reload current user session to get updated metadata
                                  try {
                                    await Supabase.instance.client.auth.refreshSession();
                                  } catch (e) {
                                    debugPrint('Error refreshing session: $e');
                                  }
                                  // Trigger rebuild to show updated name
                                  setState(() {});
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(10),
                                child: const Icon(
                                  Icons.settings_outlined,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        // User Greeting
                        Text(
                          'Xin chào, $userName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getMotivationalText(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. BODY SECTION - "What do you need today?"
          Expanded(
            flex: 6,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hôm nay bạn cần gì?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3E50),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Main Action Cards
                    _buildMainActionCard(
                      context,
                      icon: Icons.map_rounded,
                      title: 'Lên kế hoạch',
                      subtitle: 'Tạo kế hoạch chuyến đi mới',
                      isExpanded: _isPlanExpanded,
                      onTap: () {
                        setState(() {
                          _isPlanExpanded = !_isPlanExpanded;
                        });
                      },
                      expandedContent: _isPlanExpanded
                          ? Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildSubActionButton(
                                      context,
                                      'Tạo mới',
                                      Icons.add_circle_outline,
                                      () async {
                                        final ctx = context;
                                        await Navigator.push(
                                          ctx,
                                          MaterialPageRoute(
                                            builder: (context) => const TripInfoScreen(),
                                          ),
                                        );
                                        // Refresh achievements after returning from trip creation
                                        if (mounted) {
                                          await ctx.read<AchievementProvider>().refreshAchievements();
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildSubActionButton(
                                      context,
                                      'Nhập nhanh',
                                      Icons.flash_on,
                                      () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const FastInputListView(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildMainActionCard(
                      context,
                      icon: Icons.hiking_rounded,
                      title: 'Chuyến đi đã tạo',
                      subtitle: 'Xem các kế hoạch đã lưu',
                      isExpanded: false,
                      onTap: () async {
                        final ctx = context;
                        await Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (context) => trip_list.TripListView(),
                          ),
                        );
                        // Refresh achievements after returning from trip list
                        if (mounted) {
                          await ctx.read<AchievementProvider>().refreshAchievements();
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildAchievementSection(context),
                    const SizedBox(height: 32),
                    // Tips Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.amber[200]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb,
                            color: Colors.amber[700],
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mẹo hữu ích',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[900],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Luôn kiểm tra thời tiết và chuẩn bị đầy đủ trang thiết bị trước khi lên đường!',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMotivationalText() {
    final texts = [
      'Hãy bắt đầu hành trình khám phá thiên nhiên!',
      'Mỗi đỉnh núi đều có câu chuyện riêng',
      'Thiên nhiên đang chờ đón bạn',
      'Cùng chinh phục những cung đường mới',
    ];
    return texts[DateTime.now().day % texts.length];
  }

  Widget _buildAchievementSection(BuildContext context) {
    return Consumer<AchievementProvider>(
      builder: (context, provider, _) {
        final achievements = provider.achievements;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: _forestGreen.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Huy hiệu hành trình',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3E50),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    decoration: BoxDecoration(
                      color: _forestGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Mốc 1/3/5 lượt',
                      style: TextStyle(color: _forestGreen, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (achievements.isEmpty)
                Row(
                  children: [
                    Icon(Icons.emoji_events_outlined, color: Colors.grey[400]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Chưa có huy hiệu. Xác nhận một cung đường để nhận đồng ngay!',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: achievements.take(4).map((a) {
                    final tier = medalForVisits(a.visits);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          _medalIcon(tier),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.location,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${a.visits} lần ghé',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          _tierLabel(tier),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _medalIcon(MedalTier tier) {
    Color color;
    IconData icon;
    switch (tier) {
      case MedalTier.gold:
        color = const Color(0xFFFFC107);
        icon = Icons.emoji_events;
        break;
      case MedalTier.silver:
        color = const Color(0xFFB0BEC5);
        icon = Icons.emoji_events;
        break;
      case MedalTier.bronze:
        color = const Color(0xFFCD7F32);
        icon = Icons.emoji_events;
        break;
      case MedalTier.none:
        color = Colors.grey[300]!;
        icon = Icons.emoji_events_outlined;
        break;
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _tierLabel(MedalTier tier) {
    String text;
    Color color;
    switch (tier) {
      case MedalTier.gold:
        text = 'Vàng';
        color = const Color(0xFFFFC107);
        break;
      case MedalTier.silver:
        text = 'Bạc';
        color = const Color(0xFF90A4AE);
        break;
      case MedalTier.bronze:
        text = 'Đồng';
        color = const Color(0xFFB87333);
        break;
      case MedalTier.none:
        text = 'Chưa có';
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _buildMainActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isExpanded,
    required VoidCallback onTap,
    Widget? expandedContent,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _forestGreen.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: _forestGreen.withValues(alpha: 0.1),
          highlightColor: _forestGreen.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _forestGreen,
                            _forestGreen.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _forestGreen,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.chevron_right,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
                if (expandedContent != null) expandedContent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubActionButton(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: _forestGreen.withValues(alpha: 0.2),
        highlightColor: _forestGreen.withValues(alpha: 0.1),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: _forestGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _forestGreen.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _forestGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: _forestGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}