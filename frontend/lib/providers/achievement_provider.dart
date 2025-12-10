import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/achievement.dart';

class AchievementProvider with ChangeNotifier {
  final Map<String, AchievementProgress> _progressByLocation = {};

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  List<AchievementProgress> get achievements {
    final items = _progressByLocation.values.toList();
    items.sort((a, b) => b.visits.compareTo(a.visits));
    return items;
  }

  Future<void> loadFromStorage() async {
    if (_isLoaded) return;
    await _fetchPlansFromSupabase();
  }

  Future<void> _fetchPlansFromSupabase() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      
      if (currentUser == null) {
        debugPrint('[AchievementProvider] No user logged in, skipping plan fetch');
        _isLoaded = true;
        notifyListeners();
        return;
      }

      debugPrint('[AchievementProvider] Fetching plans for user: ${currentUser.id}');

      // Fetch all plans for the current user from Supabase
      final plans = await supabase
          .from('plans')
          .select()
          .eq('user_id', currentUser.id);

      debugPrint('[AchievementProvider] Found ${plans.length} plans');

      // Count visits by location
      final Map<String, int> locationCount = {};
      for (final plan in plans) {
        final location = plan['location']?.toString() ?? '';
        if (location.isNotEmpty) {
          locationCount[location] = (locationCount[location] ?? 0) + 1;
          debugPrint('[AchievementProvider] Location: $location, Count: ${locationCount[location]}');
        }
      }

      // Convert to AchievementProgress objects
      _progressByLocation.clear();
      locationCount.forEach((location, count) {
        _progressByLocation[location] = AchievementProgress(
          location: location,
          visits: count,
        );
      });

      debugPrint('[AchievementProvider] Loaded ${_progressByLocation.length} unique locations');
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[AchievementProvider] Error fetching plans: $e');
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> refreshAchievements() async {
    _isLoaded = false;
    await _fetchPlansFromSupabase();
  }
}