import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/features/preference_matching/models/route_model.dart';
import 'package:frontend/utils/app_colors.dart';
import 'package:frontend/utils/app_styles.dart';
import 'package:frontend/widgets/custom_button.dart';
import 'package:frontend/providers/trip_provider.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/screens/PEC.dart';

class InteractiveMapPage extends StatefulWidget {
  final RouteModel route;

  const InteractiveMapPage({super.key, required this.route});

  @override
  State<InteractiveMapPage> createState() => _InteractiveMapPageState();
}

class _InteractiveMapPageState extends State<InteractiveMapPage> {
  bool _isLoading = false;

  Future<void> _confirmRoute(BuildContext context) async {
    // 1. Set loading state
    setState(() => _isLoading = true);
    
    print("🔴 [InteractiveMapPage] Confirm button pressed");

    try {
      // 2. Get user inputs from the TripProvider
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      
      print("🔴 [InteractiveMapPage] Provider data: Name=${tripProvider.tripName}, Location=${tripProvider.searchLocation}");


      // 3. Construct the payload for the Django Backend
      // Note: We map 'route_id' to 'route' as per your API spec.
      // Ensure widget.route.id corresponds to the ID in your database.
      final Map<String, dynamic> payload = {
        "name": tripProvider.tripName.isNotEmpty 
            ? tripProvider.tripName 
            : "Chuyến đi đến ${widget.route.location}",
        "route": widget.route.id, // Sending the Route ID
        "location": tripProvider.searchLocation,
        "rest_type": tripProvider.accommodation ?? "Unknown", // Default if null
        "group_size": tripProvider.parsedGroupSize,
        // Formatting Date to YYYY-MM-DD
        "start_date": tripProvider.startDate?.toIso8601String().split('T').first ?? DateTime.now().toIso8601String().split('T').first,
        "duration_days": tripProvider.durationDays,
        "difficulty": tripProvider.difficultyLevel ?? "Medium", // Default
        "personal_interest": tripProvider.selectedInterests,
      };
      
      print("🔴 [InteractiveMapPage] Payload: $payload");

      // 4. Call the Backend API
      final apiService = ApiService();
      print("🔴 [InteractiveMapPage] Calling ApiService.createPlan...");
      
      // This request triggers the Python logic to generate the PEC list
      final responseData = await apiService.createPlan(payload);
      
      print("🔴 [InteractiveMapPage] API Success! Response: $responseData");

      if (!mounted) return;

      // 5. Navigate to PEC Screen
      // Pass the responseData if needed by PECScreen (e.g. plan ID)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PECScreen()),
      );
      
    } catch (e) {
      print("🔴 [InteractiveMapPage] ERROR: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi kết nối server: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map Background
          Container(
            color: AppColors.lightGray,
            child: Image.network(
              // Using a valid image URL or fallback
              widget.route.imageUrl.isNotEmpty 
                  ? widget.route.imageUrl 
                  : 'https://images.unsplash.com/photo-1585435465945-597426701a4d?q=80&w=1974&auto=format&fit=crop',
              fit: BoxFit.cover,
              height: double.infinity,
              width: double.infinity,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => 
                  const Center(child: Icon(Icons.map_outlined, color: AppColors.textGray, size: 60)),
            ),
          ),

          // Top buttons
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGlassButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                _buildGlassButton(icon: Icons.threed_rotation, text: '3D', onTap: () {}),
              ],
            ),
          ),

          // Bottom Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.45,
            maxChildSize: 0.8,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                decoration: const BoxDecoration(
                  color: AppColors.sheetBackground,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Stats
                      Text('${widget.route.name} - ${widget.route.location}', style: AppStyles.mapTitle),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.route.distanceKm} km, ${widget.route.elevationGainM} m gain, Est. ${widget.route.durationDays} days',
                        style: AppStyles.mapStats,
                      ),
                      const SizedBox(height: 24),

                      // Elevation Graph Placeholder
                      Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(child: Text('Elevation Graph Placeholder', style: TextStyle(color: Colors.grey))),
                      ),
                      const SizedBox(height: 24),

                      // AI Note
                      const Text('AI Note:', style: AppStyles.aiNoteTitle),
                      const SizedBox(height: 8),
                      // Use actual AI note if available, else dummy text
                      Text(
                        widget.route.aiNote ?? 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque euismod, urna eu tincidunt consectetur...',
                        style: AppStyles.bodyText,
                      ),
                      const SizedBox(height: 32),

                      // Confirm Button
                      _isLoading 
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                        : CustomButton(
                            text: 'XÁC NHẬN LỘ TRÌNH',
                            onPressed: () => _confirmRoute(context),
                            backgroundColor: AppColors.primaryGreen,
                            style: AppStyles.profileButton.copyWith(color: Colors.white),
                          ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({required IconData icon, String? text, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            if (text != null) ...[
              const SizedBox(width: 8),
              Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ]
          ],
        ),
      ),
    );
  }
}