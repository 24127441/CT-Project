import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trip_template.dart';
import '../services/template_service.dart';
import '../providers/trip_provider.dart';
// Import all steps to build the navigation stack
import 'tripinfopart1.dart';
import 'tripinfopart2.dart';
import 'tripinfopart3.dart';
import 'tripinfopart4.dart';
import 'tripinfopart5.dart';

class TripListView extends StatefulWidget {
  const TripListView({super.key});

  @override
  State<TripListView> createState() => _TripListViewState();
}

class _TripListViewState extends State<TripListView> {
  final TemplateService _templateService = TemplateService();
  late Future<List<TripTemplate>> _templatesFuture;

  @override
  void initState() {
    super.initState();
    _refreshTemplates();
  }

  void _refreshTemplates() {
    setState(() {
      _templatesFuture = _templateService.getTemplates();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F2),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Mẫu nhập nhanh',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<TripTemplate>>(
                future: _templatesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)));
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Lỗi: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState();
                  }

                  final templates = snapshot.data!;
                  return RefreshIndicator(
                    onRefresh: () async => _refreshTemplates(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: templates.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _buildTemplateCard(context, templates[index]),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.post_add, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text("Bạn chưa có mẫu nào.", style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          const Text(
            "Hãy tạo một chuyến đi và nhấn 'Lưu mẫu'\nở bước cuối cùng.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(BuildContext context, TripTemplate template) {
    return GestureDetector(
      onTap: () {
        // 1. Apply template data to Provider
        context.read<TripProvider>().applyTemplate(template);

        // 2. BUILD THE STACK: Push Step 1 -> 2 -> 3 -> 4 -> 5
        // We use PageRouteBuilder with zero duration to make it look instant to the user.
        // This ensures that pressing "Back" in Step 5 takes them to Step 4.
        Navigator.push(context, _noAnimRoute(const TripInfoScreen()));    // Step 1
        Navigator.push(context, _noAnimRoute(const TripTimeScreen()));    // Step 2
        Navigator.push(context, _noAnimRoute(const TripLevelScreen()));   // Step 3
        Navigator.push(context, _noAnimRoute(const TripRequestScreen())); // Step 4
        Navigator.push(context, _noAnimRoute(const TripConfirmScreen())); // Step 5
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Container(
              height: 180,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF425E3C), Color(0xFF2E7D32)],
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.2)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      template.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "${template.location} • ${template.durationDays} ngày",
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${template.accommodation} • ${template.paxGroup}",
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper for instant navigation (No Animation)
  PageRouteBuilder _noAnimRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }
}