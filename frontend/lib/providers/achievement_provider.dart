import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';

class AchievementProvider with ChangeNotifier {
  static const _prefsKey = 'achievements_v1';
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
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List decoded = jsonDecode(raw) as List;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final progress = AchievementProgress.fromJson(item);
            _progressByLocation[progress.location] = progress;
          }
        }
      } catch (_) {
        // ignore corrupt cache
      }
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> incrementLocationVisit(String location) async {
    final trimmed = location.trim();
    if (trimmed.isEmpty) return;

    final current = _progressByLocation[trimmed] ?? AchievementProgress(location: trimmed, visits: 0);
    _progressByLocation[trimmed] = current.copyWith(visits: current.visits + 1);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _progressByLocation.values.map((a) => a.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(list));
  }
}
