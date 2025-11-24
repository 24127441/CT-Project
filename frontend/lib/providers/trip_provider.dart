import 'package:flutter/material.dart';
import '../models/trip_template.dart';
import '../services/template_service.dart';

class TripProvider with ChangeNotifier {
  final TemplateService _templateService = TemplateService();

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

  void toggleInterest(String interest) {
    if (_selectedInterests.contains(interest)) {
      _selectedInterests.remove(interest);
    } else {
      _selectedInterests.add(interest);
    }
    notifyListeners();
  }

  // --- FEATURE: APPLY TEMPLATE (Fast Input) ---
  void applyTemplate(TripTemplate template) {
    _searchLocation = template.location;
    _accommodation = template.accommodation;
    _paxGroup = template.paxGroup;
    _difficultyLevel = template.difficulty;
    _note = template.note;
    _selectedInterests = List.from(template.interests);
    _tripName = template.name;

    final now = DateTime.now();
    _startDate = now.add(const Duration(days: 1)); 
    _endDate = _startDate!.add(Duration(days: template.durationDays - 1));

    notifyListeners();
  }

  // --- FEATURE: SAVE TEMPLATE (Fixed Logic) ---
  Future<void> saveHistoryInput(String name) async {
    // 1. Validate Data
    if (_searchLocation.isEmpty || _accommodation == null || _paxGroup == null || _difficultyLevel == null) {
      throw Exception("Vui lòng điền đầy đủ thông tin trước khi lưu.");
    }

    // 2. Prepare Data matching Backend Serializer
    final templateData = {
      "name": name,
      "location": _searchLocation,
      "accommodation": _accommodation,
      "pax_group": _paxGroup,
      "difficulty": _difficultyLevel,
      "duration_days": durationDays,
      "note": _note,
      "interests": _selectedInterests,
    };

    // 3. Call Service
    // This uses TemplateService which automatically handles the Token and Correct URL
    bool success = await _templateService.saveTemplate(templateData);
    
    // 4. Handle Result
    if (!success) {
      throw Exception("Lưu thất bại. Vui lòng kiểm tra kết nối hoặc đăng nhập lại.");
    }
  }

  // --- FEATURE: RESET TRIP (From Route Profile) ---
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
    notifyListeners();
  }
  
  // API 1: Gợi ý Route (Mock implementation for now)
  Future<List<dynamic>> fetchSuggestedRoutes() async {
    await Future.delayed(const Duration(seconds: 2));
    // Return empty list or mock data here
    return []; 
  }
}