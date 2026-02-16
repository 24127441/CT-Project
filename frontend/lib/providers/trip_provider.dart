import 'package:flutter/material.dart';
import '../models/trip_template.dart';
import '../services/supabase_db_service.dart';
import '../services/gemini_service.dart';
import '../features/preference_matching/models/route_model.dart';
import '../utils/logger.dart';

class TripProvider with ChangeNotifier {

  final SupabaseDbService _supabaseDb = SupabaseDbService();
  final GeminiService _geminiService = GeminiService();

  TripProvider([String? unused]);

  String _searchLocation = '';
  String? _accommodation;
  String? _paxGroup;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _difficultyLevel;
  String _note = '';
  List<String> _selectedInterests = [];
  String _tripName = '';

  int? _currentPlanId; 
  int? get currentPlanId => _currentPlanId;
  
  bool _routeConfirmed = false;
  bool get routeConfirmed => _routeConfirmed;

  String get searchLocation => _searchLocation;
  String? get accommodation => _accommodation;
  String? get paxGroup => _paxGroup;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String? get difficultyLevel => _difficultyLevel;
  String get note => _note;
  List<String> get selectedInterests => _selectedInterests;
  String get tripName => _tripName;

  int get durationDays {
    if (_startDate == null || _endDate == null) return 1;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  int get parsedGroupSize {
    if (_paxGroup == 'Đơn lẻ (1-2 người)') return 2;
    if (_paxGroup == 'Nhóm nhỏ (3-6 người)') return 5;
    if (_paxGroup == 'Nhóm đông (7+ người)') return 8;
    return 1;
  }

  // --- Setters ---
  void setSearchLocation(String value) { _searchLocation = value; notifyListeners(); }
  void setAccommodation(String value) { _accommodation = value; notifyListeners(); }
  void setPaxGroup(String value) { _paxGroup = value; notifyListeners(); }
  void setDifficultyLevel(String value) { _difficultyLevel = value; notifyListeners(); }
  void setNote(String value) { _note = value; notifyListeners(); }
  void setTripName(String value) { _tripName = value; notifyListeners(); }

  void setTripDates(DateTime start, DateTime end) {
    DateTime startDateOnly = DateTime(start.year, start.month, start.day);
    DateTime endDateOnly = DateTime(end.year, end.month, end.day);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (startDateOnly.isBefore(today)) {
      startDateOnly = today;
      if (endDateOnly.isBefore(startDateOnly)) {
        endDateOnly = startDateOnly;
      }
    }

    _startDate = startDateOnly;
    _endDate = endDateOnly;
    notifyListeners();
  }

  void toggleInterest(String interest) {
    if (_selectedInterests.contains(interest)) {
      _selectedInterests.remove(interest);
    } else {
      _selectedInterests.add(interest);
    }
    notifyListeners();
  }

  void applyTemplate(TripTemplate template) {
    _searchLocation = template.location;
    _accommodation = template.accommodation;
    _paxGroup = template.paxGroup;
    _difficultyLevel = template.difficulty;
    _note = template.note;
    _selectedInterests = List.from(template.interests);
    _tripName = template.name;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _startDate = today.add(const Duration(days: 1));
    int d = template.durationDays < 1 ? 1 : template.durationDays;
    _endDate = _startDate!.add(Duration(days: d - 1));
    notifyListeners();
  }

  void applyHistoryInput(Map<String, dynamic> data) {
    _searchLocation = data['location'] ?? data['payload']?['location'] ?? '';
    _accommodation = data['rest_type'] ?? data['payload']?['rest_type'];

    final gs = data['group_size'] ?? data['payload']?['group_size'];
    if (gs is int) {
      if (gs >= 7) {
        _paxGroup = 'Nhóm đông (7+ người)';
      } else if (gs >= 3) {
        _paxGroup = 'Nhóm nhỏ (3-6 người)';
      } else {
        _paxGroup = 'Đơn lẻ (1-2 người)';
      }
    } else if (gs is String) {
      _paxGroup = gs;
    }

    final sd = data['start_date'] ?? data['payload']?['start_date'];
    final dd = data['duration_days'] ?? data['payload']?['duration_days'];
    if (sd != null) {
      try {
        final parsed = DateTime.parse(sd.toString());
        _startDate = DateTime(parsed.year, parsed.month, parsed.day);
        final d = (dd is int) ? dd : int.tryParse(dd?.toString() ?? '') ?? 1;
        _endDate = _startDate!.add(Duration(days: d - 1));
      } catch (_) {
        _startDate = null; _endDate = null;
      }
    }
    _difficultyLevel = data['difficulty'] ?? data['payload']?['difficulty'];
    final interests = data['personal_interests'] ?? data['payload']?['personal_interests'];
    if (interests is List) {
      _selectedInterests = List<String>.from(interests.map((e) => e.toString()));
    }
    _tripName = data['template_name'] ?? data['name'] ?? _tripName;
    notifyListeners();
  }

  // --- VALIDATE & PREPARE DRAFT (Step 1-5) - Local Only ---
  Future<void> saveTripRequest() async {
    try {
      if (_tripName.isEmpty) {
        throw Exception("Vui lòng đặt tên cho chuyến đi");
      }
      if (_startDate == null) {
        throw Exception("Vui lòng chọn ngày khởi hành");
      }
      AppLogger.d('TripProvider', 'Trip data validated locally');
      AppLogger.d('TripProvider', '=== END saveTripRequest SUCCESS ===');

    } catch (e) {
      AppLogger.e('TripProvider', '=== ERROR in saveTripRequest: ${e.toString()} ===');
      rethrow;
    }
  }
  // --- CONFIRM ROUTE & CREATE FINAL PLAN (Step 6) ---
  // Save everything to database when route is confirmed
  Future<void> confirmRouteForPlan(int routeId, {Map<String, dynamic>? checklist}) async {
    try {
      AppLogger.d('TripProvider', 'Confirming route and creating final plan in database');
      AppLogger.d('TripProvider', 'routeId=$routeId, tripName=$_tripName');

      if (_tripName.isEmpty) {
        AppLogger.e('TripProvider', 'Trip name is empty when confirming route');
        throw Exception("Chưa có tên chuyến đi");
      }

      // Create final plan with all data including route
      final response = await _supabaseDb.createPlan(
        name: _tripName,
        routeId: routeId,
        location: _searchLocation,
        restType: _accommodation ?? 'Không xác định',
        groupSize: parsedGroupSize,
        startDate: _startDate?.toIso8601String().split('T').first ?? DateTime.now().toIso8601String().split('T').first,
        durationDays: durationDays,
        difficulty: _difficultyLevel ?? 'Người mới',
        personalInterests: _selectedInterests,
      );

      if (response['id'] != null) {
        _currentPlanId = response['id'];
        AppLogger.d('TripProvider', 'Final plan created successfully. ID=$_currentPlanId');
      }

      // If checklist provided, update the plan with it
      if (checklist != null && _currentPlanId != null) {
        await _supabaseDb.updatePlanRoute(_currentPlanId!, routeId, checklist: checklist);
      }

      // Mark route as confirmed
      _routeConfirmed = true;
      AppLogger.d('TripProvider', 'Plan confirmed and saved to database successfully');
      AppLogger.d('TripProvider', '=== END confirmRouteForPlan SUCCESS ===');
      
    } catch (e) {
      AppLogger.e('TripProvider', 'Error confirming route: ${e.toString()}');
      rethrow;
    }
  }
  Future<void> saveHistoryInput(String name) async {
    if (_searchLocation.isEmpty || _accommodation == null || _paxGroup == null || _difficultyLevel == null) {
      throw Exception("Vui lòng điền đầy đủ thông tin trước khi lưu.");
    }
    
    final payload = {
      'location': _searchLocation,
      'rest_type': _accommodation,
      'group_size': parsedGroupSize,
      'start_date': null,
      'duration_days': null,
      'difficulty': _difficultyLevel ?? 'Người mới',
      'personal_interests': _selectedInterests,
    };
    await _supabaseDb.saveHistoryInput(name, payload);
  }

  /// Cancel and reset all trip data (only resets local state, nothing in database)
  Future<void> cancelDraftPlan() async {
    try {
      AppLogger.d('TripProvider', 'Canceling draft plan - resetting local state only');
      resetTrip();
    } catch (e) {
      AppLogger.e('TripProvider', 'Failed to cancel draft plan: ${e.toString()}');
      rethrow;
    }
  }

  Future<List<RouteModel>> fetchSuggestedRoutes() async {
    try {
      final rawData = await _supabaseDb.getSuggestedRoutes(
        location: _searchLocation,
        difficulty: null,
        accommodation: _accommodation,
        durationDays: durationDays,
      );

      final List<RouteModel> initialRoutes = [];
      for (final item in rawData) {
        try {
          initialRoutes.add(RouteModel.fromJson(Map<String, dynamic>.from(item as Map)));
        } catch (e) {
          AppLogger.e('TripProvider', 'Failed to parse route item: ${e.toString()}');
        }
      }

      if (initialRoutes.isEmpty) {
        AppLogger.d('TripProvider', 'No initial routes found');
        return [];
      }

      final aiRoutes = await _geminiService.recommendRoutes(
        allRoutes: initialRoutes,
        userLocation: _searchLocation,
        userInterests: _selectedInterests.join(", "),
        userExperience: _difficultyLevel ?? "Người mới",
        duration: "$durationDays ngày",
        groupSize: _paxGroup ?? "Nhóm nhỏ",
      );

      return aiRoutes;
    } catch (e) {
      AppLogger.e('TripProvider', 'Error fetching suggested routes: ${e.toString()}');
      return [];
    }
  }

  /// Reset all trip state variables to initial values for a fresh trip creation
  void resetTrip() {
    _searchLocation = '';
    _accommodation = null;
    _paxGroup = null;
    _startDate = null;
    _endDate = null;
    _difficultyLevel = null;
    _note = '';
    _selectedInterests = [];
    _tripName = '';
    _currentPlanId = null;
    _routeConfirmed = false;
    AppLogger.d('TripProvider', 'Trip state reset');
    notifyListeners();
  }
}