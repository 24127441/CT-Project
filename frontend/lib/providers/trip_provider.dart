import 'package:flutter/material.dart';
import '../models/trip_template.dart';
import '../services/supabase_db_service.dart';
import '../services/gemini_service.dart';
import '../features/preference_matching/models/route_model.dart';
import '../utils/logger.dart';

class TripProvider with ChangeNotifier {

  // Khởi tạo Service Supabase
  final SupabaseDbService _supabaseDb = SupabaseDbService();
  final GeminiService _geminiService = GeminiService();

  TripProvider([String? unused]);

  // --- State Variables ---
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

  // --- Getters ---
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
    // Normalize to date-only
    DateTime startDateOnly = DateTime(start.year, start.month, start.day);
    DateTime endDateOnly = DateTime(end.year, end.month, end.day);

    // Prevent start dates in the past (use local date)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (startDateOnly.isBefore(today)) {
      AppLogger.d('TripProvider', 'Requested start date in past; clamping to today');
      startDateOnly = today;
      // Ensure end is not before start
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

  // --- Logic Apply Template & History (Giữ nguyên) ---
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

  // --- SAVE DRAFT PLAN (Step 1-4) ---
  Future<void> saveTripRequest() async {
    try {
      print('\n🟡🟡🟡 [TripProvider] === START saveTripRequest ===');
      print('🟡 [TripProvider] Trip Name: $_tripName');
      AppLogger.d('TripProvider', '=== START saveTripRequest ===');
      AppLogger.d('TripProvider', 'Trip Name: $_tripName');
      AppLogger.d('TripProvider', 'Start Date: $_startDate');
      AppLogger.d('TripProvider', 'Search Location: $_searchLocation');
      AppLogger.d('TripProvider', 'Accommodation: $_accommodation');
      AppLogger.d('TripProvider', 'Difficulty: $_difficultyLevel');
      AppLogger.d('TripProvider', 'Selected Interests: $_selectedInterests');
      AppLogger.d('TripProvider', 'Duration Days: $durationDays');
      AppLogger.d('TripProvider', 'Parsed Group Size: $parsedGroupSize');
      
      if (_tripName.isEmpty) {
        AppLogger.e('TripProvider', 'Trip name is empty - throwing exception');
        throw Exception("Vui lòng đặt tên cho chuyến đi");
      }
      if (_startDate == null) {
        AppLogger.e('TripProvider', 'Start date is null - throwing exception');
        throw Exception("Vui lòng chọn ngày khởi hành");
      }

      AppLogger.d('TripProvider', 'Creating initial plan via Supabase service...');
      
      // Call Service to create INITIAL plan
      final response = await _supabaseDb.createPlan(
        name: _tripName,
        routeId: null, // Route is null initially
        location: _searchLocation,
        restType: _accommodation ?? 'Không xác định',
        groupSize: parsedGroupSize,
        startDate: _startDate!.toIso8601String().split('T').first,
        durationDays: durationDays,
        difficulty: _difficultyLevel ?? 'Người mới',
        personalInterests: _selectedInterests,
      );

      AppLogger.d('TripProvider', 'Response from createPlan: $response');

      // 🟢 STORE THE ID for later use
      if (response['id'] != null) {
        _currentPlanId = response['id'];
        AppLogger.d('TripProvider', 'Draft Plan saved successfully. ID: $_currentPlanId');
      } else {
        AppLogger.d('TripProvider', 'Response received but no ID found in response');
      }
      
      AppLogger.d('TripProvider', '=== END saveTripRequest SUCCESS ===');

    } catch (e) {
      AppLogger.e('TripProvider', '=== ERROR in saveTripRequest: ${e.toString()} ===');
      rethrow;
    }
  }
  // --- CONFIRM ROUTE & AI CHECKLIST (Step 6) ---
  // Updated to accept the AI generated checklist
  Future<void> confirmRouteForPlan(int routeId, {Map<String, dynamic>? checklist}) async {
    try {
      print('\n🟡🟡🟡 [TripProvider] === START confirmRouteForPlan ===');
      print('🟡 [TripProvider] Route ID: $routeId');
      print('🟡 [TripProvider] Current Plan ID: $_currentPlanId');
      print('🟡 [TripProvider] Trip Name: $_tripName');
      print('🟡 [TripProvider] Location: $_searchLocation');
      print('🟡 [TripProvider] Difficulty: $_difficultyLevel');
      
      AppLogger.d('TripProvider', 'Confirming route for plan. routeId=$routeId, currentPlanId=$_currentPlanId');

      // If we don't have a draft plan on the server yet, create one now attaching the selected route.
      if (_currentPlanId == null) {
        print('🟡 [TripProvider] ⚠️ WARNING: No draft plan ID found, creating new plan with route');
        // Create plan with routeId filled
        final resp = await _supabaseDb.createPlan(
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

        if (resp['id'] != null) {
          _currentPlanId = resp['id'];
          print('🟡 [TripProvider] ✅ Created plan with route. ID=$_currentPlanId');
          AppLogger.d('TripProvider', 'Created plan with route. ID=$_currentPlanId');
        }
      } else {
        print('🟡 [TripProvider] Updating existing draft plan $_currentPlanId with route $routeId');
        // Update existing draft to set route and optionally checklist
        await _supabaseDb.updatePlanRoute(
          _currentPlanId!,
          routeId,
          checklist: checklist,
        );
        print('🟡 [TripProvider] ✅ Draft plan updated successfully');
      }

      // If checklist provided and we just created the plan, ensure checklist is attached
      if (checklist != null && _currentPlanId != null) {
        await _supabaseDb.updatePlanRoute(_currentPlanId!, routeId, checklist: checklist);
      }

      // Mark route as confirmed so draft won't be deleted
      _routeConfirmed = true;
      print('🟡 [TripProvider] ✅ Route confirmed, draft plan will be kept');
      AppLogger.d('TripProvider', 'Route confirmed successfully');
      
    } catch (e) {
      AppLogger.e('TripProvider', 'Error confirming route: ${e.toString()}');
      rethrow;
    }
  }
  Future<void> saveHistoryInput(String name) async {
    if (_searchLocation.isEmpty || _accommodation == null || _paxGroup == null || _difficultyLevel == null) {
      throw Exception("Vui lòng điền đầy đủ thông tin trước khi lưu.");
    }
    
    // Don't validate start date for history input - leave it blank
    
    final payload = {
      'location': _searchLocation,
      'rest_type': _accommodation,
      'group_size': parsedGroupSize,
      'start_date': null,  // Leave start_date blank for history input
      'duration_days': null,  // Leave duration_days blank for history input
      'difficulty': _difficultyLevel ?? 'Người mới',
      'personal_interests': _selectedInterests,
    };
    await _supabaseDb.saveHistoryInput(name, payload);
  }

  // Hàm này lấy dữ liệu từ các biến _searchLocation, _accommodation... (Bước 1-5)
  // Và lấy routeId từ tham số selectedRoute truyền vào
  Future<void> createPlan(RouteModel selectedRoute) async {
    try {
      print('\n🟡🟡🟡 [TripProvider] === START createPlan (Route Confirmation) ===');
      print('🟡 [TripProvider] Current Plan ID: $_currentPlanId');
      print('🟡 [TripProvider] Selected Route ID: ${selectedRoute.id}');
      
      AppLogger.d('TripProvider', '=== START createPlan (Route Confirmation) ===');
      AppLogger.d('TripProvider', 'Trip Name: $_tripName');
      AppLogger.d('TripProvider', 'Selected Route ID: ${selectedRoute.id}');
      AppLogger.d('TripProvider', 'Selected Route Name: ${selectedRoute.name}');
      AppLogger.d('TripProvider', 'Current Plan ID: $_currentPlanId');
      
      if (_tripName.isEmpty) {
        AppLogger.e('TripProvider', 'Trip name is empty when confirming route');
        throw Exception("Chưa có tên chuyến đi");
      }

      // If we have a draft plan, UPDATE it with the route instead of creating new
      if (_currentPlanId != null) {
        print('🟡 [TripProvider] Updating existing draft plan $_currentPlanId with route');
        AppLogger.d('TripProvider', 'Updating existing draft plan with route...');
        
        await _supabaseDb.updatePlanRoute(_currentPlanId!, selectedRoute.id);
        
        print('🟡 [TripProvider] ✅ Draft plan updated successfully');
        print('🟡 [TripProvider] === END createPlan SUCCESS ===\n');
        AppLogger.d('TripProvider', 'Draft plan updated successfully with route');
        AppLogger.d('TripProvider', '=== END createPlan SUCCESS ===');
        return;
      }

      // Otherwise create a new plan (fallback - shouldn't happen in normal flow)
      print('🟡 [TripProvider] ⚠️ No draft plan found, creating new plan');
      AppLogger.d('TripProvider', 'No draft plan found, creating new plan...');
      
      // Xử lý group size
      int size = 1;
      if (_paxGroup != null && _paxGroup!.contains('3-6')) size = 5;
      if (_paxGroup != null && _paxGroup!.contains('7+')) size = 8;
      AppLogger.d('TripProvider', 'Calculated group size: $size (from paxGroup: $_paxGroup)');

      AppLogger.d('TripProvider', 'Creating new plan with route via Supabase service...');

      // GỌI SERVICE LƯU VÀO DB
      final response = await _supabaseDb.createPlan(
        name: _tripName,
        routeId: selectedRoute.id,
        location: _searchLocation,
        restType: _accommodation ?? 'Không xác định',
        groupSize: size,
        startDate: _startDate?.toIso8601String().split('T').first ?? DateTime.now().toString(),
        durationDays: durationDays,
        difficulty: _difficultyLevel ?? 'Người mới',
        personalInterests: _selectedInterests,
      );

      if (response['id'] != null) {
        _currentPlanId = response['id'];
      }

      print('🟡 [TripProvider] ✅ New plan created successfully');
      print('🟡 [TripProvider] === END createPlan SUCCESS ===\n');
      AppLogger.d('TripProvider', 'Plan created successfully with route');
      AppLogger.d('TripProvider', '=== END createPlan SUCCESS ===');

      // Không reset vội, để người dùng còn thấy data nếu cần
      // resetTrip();

    } catch (e) {
      print('🟡 [TripProvider] ❌ ERROR in createPlan: ${e.toString()}\n');
      AppLogger.e('TripProvider', '=== ERROR in createPlan: ${e.toString()} ===');
      rethrow;
    }
  }

  /// Cancel the draft plan if it was previously created on the server.
  /// This is useful when no route was found and the user chooses to go back.
  Future<void> cancelDraftPlan() async {
    try {
      if (_currentPlanId != null) {
        final id = _currentPlanId!;
        await _supabaseDb.deletePlan(id);
        AppLogger.d('TripProvider', 'Cancelled draft plan id=$id');
        _currentPlanId = null;
      }
      // Reset local state so the user can start fresh
      resetTrip();
    } catch (e) {
      AppLogger.e('TripProvider', 'Failed to cancel draft plan: ${e.toString()}');
      rethrow;
    }
  }

  // --- FEATURE QUAN TRỌNG NHẤT: FETCH ROUTES ---
  // Đã chuyển sang gọi Supabase trực tiếp
  Future<List<RouteModel>> fetchSuggestedRoutes() async {
    try {
      // Bước A: Lấy dữ liệu thô từ Supabase (Lọc sơ bộ)
      final rawData = await _supabaseDb.getSuggestedRoutes(
        location: _searchLocation, // Lọc theo địa điểm user nhập
        difficulty: null,          // Mẹo: Lấy tất cả độ khó để AI có nhiều lựa chọn hơn
        accommodation: _accommodation,
        durationDays: durationDays,
      );

      // Convert sang List RouteModel
      final List<RouteModel> initialRoutes = [];
      for (final item in rawData) {
        try {
          initialRoutes.add(RouteModel.fromJson(Map<String, dynamic>.from(item as Map)));
        } catch (e) {
          AppLogger.e('TripProvider', 'Failed to parse route item: ${e.toString()}');
        }
      }

      // Nếu Supabase không tìm thấy gì, trả về rỗng luôn
      if (initialRoutes.isEmpty) {
        AppLogger.d('TripProvider', 'No initial routes found');
        return [];
      }

      // Bước B: Gửi cho AI phân tích (Tinh chỉnh & Viết lời khuyên)
      final aiRoutes = await _geminiService.recommendRoutes(
        allRoutes: initialRoutes,
        userLocation: _searchLocation,
        userInterests: _selectedInterests.join(", "), // VD: "Săn mây, Cắm trại"
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