import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/trip_template.dart';
import '../services/template_service.dart';

class TripProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  final TemplateService _templateService = TemplateService();

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
  String _tripName = ''; // Name for the trip/template

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
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  // --- Setters ---
  void setSearchLocation(String value) { _searchLocation = value; notifyListeners(); }
  void setAccommodation(String value) { _accommodation = value; notifyListeners(); }
  void setPaxGroup(String value) { _paxGroup = value; notifyListeners(); }
  void setDifficultyLevel(String value) { _difficultyLevel = value; notifyListeners(); }
  void setNote(String value) { _note = value; notifyListeners(); }
  void setTripName(String value) { _tripName = value; notifyListeners(); }

  void setTripDates(DateTime start, DateTime end) {
    _startDate = start;
    _endDate = end;
    notifyListeners();
  }

  // Logic for toggling interests (add/remove)
  void toggleInterest(String interest) {
    if (_selectedInterests.contains(interest)) {
      _selectedInterests.remove(interest);
    } else {
      _selectedInterests.add(interest);
    }
    notifyListeners();
  }

  // --- FEATURE: APPLY TEMPLATE (Fast Input) ---
  // This function fills all the state variables with data from the selected template
  void applyTemplate(TripTemplate template) {
    _searchLocation = template.location;
    _accommodation = template.accommodation;
    _paxGroup = template.paxGroup;
    _difficultyLevel = template.difficulty;
    _note = template.note;
    _selectedInterests = List.from(template.interests);
    _tripName = template.name; // Prefill the name

    // Handle Date Logic for Templates:
    // Since templates store "duration", we set Start Date = Tomorrow, End Date = Tomorrow + Duration
    final now = DateTime.now();
    _startDate = now.add(const Duration(days: 1)); 
    _endDate = _startDate!.add(Duration(days: template.durationDays - 1));

    notifyListeners();
  }

  // --- FEATURE: SAVE TEMPLATE ---
  Future<void> saveHistoryInput(String name) async {
    if (_searchLocation.isEmpty || _accommodation == null || _paxGroup == null || _difficultyLevel == null) {
      throw Exception("Vui lòng điền đầy đủ thông tin trước khi lưu.");
    }

    // Convert list params to repeated query params or comma-separated values depending on backend expectations
    final qp = <String, dynamic>{};
    queryParams.forEach((k, v) {
      if (v is List) qp[k] = v.map((e) => e.toString()).toList();
      else qp[k] = v.toString();
    });

    final res = await _api.fetchSuggestedRoutes(qp);
    return res;
  }

  // API 2: Lưu Mẫu (Cập nhật durationDays)
  Future<void> saveHistoryInput(String templateName) async {
    final Map<String, dynamic> body = {
      'templateName': templateName,
      'location': searchLocation,
      'restType': accommodation ?? '',
      'groupSize': parsedGroupSize,
      'startDate': _formatDate(startDate),
      'durationDays': durationDays, // <--- GỬI SỐ NGÀY ĐÃ TÍNH
      'difficulty': difficultyLevel ?? '',
      'personalInterest': selectedInterests,
    };

    await _api.saveHistoryInput(body);
  }

  // API 3: Tạo Plan (Cập nhật durationDays)
  Future<dynamic> createPlan({required int routeId}) async {
    final Map<String, dynamic> body = {
      'name': tripName,
      'route': routeId,
      'location': searchLocation,
      'restType': accommodation ?? '',
      'groupSize': parsedGroupSize,
      'startDate': _formatDate(startDate),
      'durationDays': durationDays, // <--- GỬI SỐ NGÀY ĐÃ TÍNH
      'difficulty': difficultyLevel ?? '',
      'personalInterest': selectedInterests,
    };

    final created = await _api.createPlan(body);
    return created;
  }
}