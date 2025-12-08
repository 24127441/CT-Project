// ignore_for_file: unused_element_parameter
import 'dart:convert';

import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/logger.dart';

// --- CÁC SERVICE CỦA BẠN ---
import '../services/supabase_db_service.dart';
import '../services/plan_service.dart';
import '../models/plan.dart';
import '../services/danger_labels.dart';
import '../services/gemini_service.dart';

// --- IMPORT CHO MAP & CHART ---
import 'package:maplibre_gl/maplibre_gl.dart'; // 3D Map
import 'package:flutter_map/flutter_map.dart' as fmap; // 2D Map
import 'package:latlong2/latlong.dart' as fcoords; // Toạ độ cho 2D Map
import 'package:fl_chart/fl_chart.dart'; // Biểu đồ

const kBgColor = Color(0xFFF8F6F2);
const kPrimaryGreen = Color(0xFF38C148);

class InteractivePoint {
  final fcoords.LatLng coordinate; // Tọa độ (để vẽ marker trên Map)
  final double elevation;          // Độ cao (trục Y Chart)
  final double distance;           // Khoảng cách từ điểm xuất phát (trục X Chart)

  InteractivePoint({
    required this.coordinate,
    required this.elevation,
    required this.distance,
  });
}

class TripDashboard extends StatefulWidget {
  final int? planId;

  const TripDashboard({super.key, this.planId});

  @override
  State<TripDashboard> createState() => _TripDashboardState();
}

class _TripDashboardState extends State<TripDashboard> {
  final SupabaseDbService _db = SupabaseDbService();
  final GeminiService _geminiService = GeminiService();
  late final PlanService _planService = PlanService(db: _db);

  Plan? _latestPlan;
  int _activeIndex = 0;
  final PageController _pageController = PageController();
  final List<String> _notes = [];

  String _notesStorageKeyForPlan(int planId) => 'plan_${planId}_notes';

  Future<void> _loadNotesForPlan(int planId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_notesStorageKeyForPlan(planId));
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>?;
        if (decoded != null) {
          final strings = decoded.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
          if (mounted) {
            setState(() {
              _notes.clear();
              _notes.addAll(strings);
            });
          } else {
            _notes.clear();
            _notes.addAll(strings);
          }
        }
      }
    } catch (e) {
      AppLogger.e('TripDashboard', 'Failed to load notes: ${e.toString()}');
    }
  }

  Future<void> _saveNotesForPlan(int planId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_notesStorageKeyForPlan(planId), jsonEncode(_notes));
    } catch (e) {
      AppLogger.e('TripDashboard', 'Failed to save notes: ${e.toString()}');
    }
  }

  Map<String, Map<String, dynamic>> _equipmentDetails = {};

  String? _aiRouteNote;
  bool _isLoadingNote = false;

  @override
  void initState() {
    super.initState();
    // Tải dữ liệu ngay khi màn hình mở
    SchedulerBinding.instance.addPostFrameCallback((_) => _initSafetyCheck());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _launchBuyLink(String itemName, String? dbLink) async {
    final Uri url;
    if (dbLink != null && dbLink.isNotEmpty) {
      url = Uri.parse(dbLink);
    } else {
      final query = Uri.encodeComponent(itemName);
      url = Uri.parse('https://shopee.vn/search?keyword=$query');
    }
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      AppLogger.e('TripDashboard', 'Error launching URL: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Không thể mở liên kết mua hàng")),
        );
      }
    }
  }

  Future<void> _fetchEquipmentDetails(Plan plan) async {
    final eqMap = plan.personalizedEquipmentList;
    if (eqMap == null || eqMap.isEmpty) return;

    final Set<String> ids = {};
    eqMap.forEach((key, value) {
      if (value is List) {
        for (var item in value) {
          if (item['id'] != null) ids.add(item['id'].toString());
        }
      }
    });

    if (ids.isEmpty) return;

    try {
      final response = await Supabase.instance.client
          .from('equipment')
          .select('id, image_url, buy_link')
          .inFilter('id', ids.toList());

      final Map<String, Map<String, dynamic>> details = {};
      for (var row in response) {
        details[row['id'].toString()] = row;
      }

      if (mounted) {
        setState(() {
          _equipmentDetails = details;
        });
      }
    } catch (e) {
      AppLogger.e('TripDashboard', 'Error fetching equipment details: ${e.toString()}');
    }
  }

  Future<void> _generateAiNote(Plan plan) async {
    if (plan.routes.isEmpty) return;

    final route = plan.routes.first;

    setState(() => _isLoadingNote = true);

    final raw = await _geminiService.generateRouteNote(
        route.name ?? '',
        plan.location
    );

    String display = raw;
    // Defensive: AI service may return structured JSON (e.g. { "note": "..." })
    try {
      if (display.trim().startsWith('{') || display.trim().startsWith('[')) {
        final decoded = jsonDecode(display);
        if (decoded is Map) {
          if (decoded.containsKey('note') && decoded['note'] is String) {
            display = decoded['note'] as String;
          } else if (decoded.containsKey('text') && decoded['text'] is String) {
            display = decoded['text'] as String;
          } else if (decoded.containsKey('content') && decoded['content'] is String) {
            display = decoded['content'] as String;
          } else {
            // Try to find first string value
            final firstStr = decoded.values.firstWhere((v) => v is String, orElse: () => null);
            if (firstStr is String) {
              display = firstStr;
            } else {
              display = decoded.toString();
            }
          }
        } else if (decoded is List && decoded.isNotEmpty) {
          // join list items into readable text
          display = decoded.map((e) => e.toString()).join('\n');
        }
      }
    } catch (e) {
      // ignore JSON parse errors and use raw string
      AppLogger.e('TripDashboard', 'AI note parse error: ${e.toString()}');
    }

    if (mounted) {
      setState(() {
        _aiRouteNote = display.trim();
        _isLoadingNote = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: SafeArea(
        child: Column(
          children: [
            _TripHeader(onBackPressed: () => Navigator.of(context).pop(), onViewDanger: _showDangerViewer),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: _TripTabs(activeIndex: _activeIndex, onTabChanged: _onTab),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _activeIndex = i),
                children: [
                  // Tab 1: Route (Truyền plan vào đây, nếu plan null thì nó hiện loading hoặc fake)
                  _RouteTab(
                      plan: _latestPlan,
                      aiNote: _aiRouteNote,
                      isLoadingNote: _isLoadingNote
                  ),
                  // Tab 2: Equipment
                  _ItemsTab(
                    plan: _latestPlan,
                    equipmentDetails: _equipmentDetails,
                    onBuyPressed: _launchBuyLink,
                  ),
                  // Tab 3: Notes
                  _NotesTab(notes: _notes, onDeleteNote: _deleteNote, onEditNote: _editNote),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _activeIndex == 2
          ? FloatingActionButton(
        backgroundColor: kPrimaryGreen,
        onPressed: _navigateAndAddNote,
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
    );
  }

  void _onTab(int i) {
    setState(() => _activeIndex = i);
    _pageController.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _initSafetyCheck() async {
    final ctx = context;
    final navigator = Navigator.of(ctx);

    // Show loading
    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: const [CircularProgressIndicator(), SizedBox(width: 16), Text('Đang tải dữ liệu...')]),
        ),
      ),
    );

    try {
      Plan? targetPlan;
      if (widget.planId != null) {
        final allPlans = await _planService.getPlans();
        try {
          targetPlan = allPlans.firstWhere((p) => p.id == widget.planId);
        } catch (e) {
          targetPlan = await _planService.getLatestPlan();
        }
      } else {
        targetPlan = await _planService.getLatestPlan();
      }

      if (!mounted) {
        if (navigator.canPop()) navigator.pop();
        return;
      }

      // Update State: Plan đã tải xong
      setState(() => _latestPlan = targetPlan);

      // Load persisted notes for this plan (if available)
      if (targetPlan != null && targetPlan.id != null) {
        try {
          await _loadNotesForPlan(targetPlan.id!);
        } catch (e) {
          AppLogger.e('TripDashboard', 'Error loading notes after plan load: ${e.toString()}');
        }
      }

      if (targetPlan != null) {
        _fetchEquipmentDetails(targetPlan);
        // Check weather and possibly save dangers snapshot
        dynamic returnedSnapshot;
        try {
          returnedSnapshot = await _checkWeatherAndSave(targetPlan);
        } catch (e) {
          AppLogger.e('TripDashboard', 'Weather check failed: ${e.toString()}');
        }
        _generateAiNote(targetPlan);

        // Check Danger: prefer the snapshot returned from the weather check
        // (so newly-created plans will surface their own danger snapshot immediately),
        // fallback to reading the plan row or latest snapshot.
        try {
          dynamic snapshot = returnedSnapshot;
          final pid = _latestPlan?.id;
          AppLogger.d('TripDashboard', 'DEBUG _initSafetyCheck: returnedSnapshot=$returnedSnapshot, pid=$pid');

          if (snapshot == null) {
            AppLogger.d('TripDashboard', 'DEBUG: snapshot is null, fetching from DB');
            if (pid != null) {
              final planRow = await _db.getPlanById(pid);
              snapshot = planRow != null ? planRow['dangers_snapshot'] : null;
              AppLogger.d('TripDashboard', 'DEBUG: getPlanById($pid) dangers_snapshot=$snapshot');
            } else {
              snapshot = await _db.getLatestDangerSnapshot();
              AppLogger.d('TripDashboard', 'DEBUG: getLatestDangerSnapshot()=$snapshot');
            }
          }

          if (snapshot != null) {
            AppLogger.d('TripDashboard', 'DEBUG: snapshot is not null, calling _isAcknowledgedForPlanWithSnapshot');
            if (pid != null) {
              final ack = await _isAcknowledgedForPlanWithSnapshot(pid, snapshot);
              AppLogger.d('TripDashboard', 'DEBUG: ack=$ack');
              if (navigator.canPop()) navigator.pop();
              if (!ack) {
                // Format the danger snapshot properly instead of raw toString()
                final message = _formatDangerSnapshot(snapshot);
                AppLogger.d('TripDashboard', 'DEBUG: Formatted message=$message');
                if (!mounted) return;
                await _showDangerWarning(navigator, snapshot, message);
              }
              return;
            }
          } else {
            AppLogger.d('TripDashboard', 'DEBUG: snapshot is null after all fetches');
          }
          if (navigator.canPop()) navigator.pop();
        } catch (e) {
          AppLogger.e('TripDashboard', 'DEBUG: Exception in danger check: $e');
          if (navigator.canPop()) navigator.pop();
        }
      }
    } catch (err) {
      try {
        if (navigator.canPop()) navigator.pop();
      } catch (_) {}
    }
  }

  Future<void> _acknowledgePlan(int planId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ack_plan_$planId', true);
  }

  Future<bool> _isAcknowledgedForPlanWithSnapshot(int planId, dynamic snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    // If the global plan ack exists, treat as acknowledged
    if (prefs.getBool('ack_plan_$planId') == true) return true;

    // If snapshot is empty/null then not acknowledged
    if (snapshot == null) return false;

    // If snapshot is a map with 'dangers' array (structured format)
    if (snapshot is Map && snapshot['dangers'] is List) {
      final List dangers = snapshot['dangers'] as List;
      for (var i = 0; i < dangers.length; i++) {
        final key = _dangerStorageKey(planId, 'danger_$i');
        if (prefs.getBool(key) != true) return false;
      }
      return true;
    }

    // If snapshot is a map, ensure every danger key has been acknowledged
    if (snapshot is Map) {
      // Skip metadata keys
      final dangerKeys = snapshot.keys.where((k) =>
      k.toString() != 'source' &&
          k.toString() != 'latitude' &&
          k.toString() != 'longitude' &&
          k.toString() != 'start_date' &&
          k.toString() != 'end_date' &&
          k.toString() != 'raw'
      ).toList();

      if (dangerKeys.isEmpty) return true; // No actual dangers

      for (final k in dangerKeys) {
        final key = _dangerStorageKey(planId, k.toString());
        if (prefs.getBool(key) != true) return false;
      }
      return true;
    }

    // If snapshot is a list, check each index key
    if (snapshot is List) {
      for (var i = 0; i < snapshot.length; i++) {
        final key = _dangerStorageKey(planId, i.toString());
        if (prefs.getBool(key) != true) return false;
      }
      return true;
    }

    // For other snapshot types, use a generic 'message' key
    final key = _dangerStorageKey(planId, 'message');
    return prefs.getBool(key) == true;
  }

  String _dangerStorageKey(int planId, String dangerKey) {
    final safe = dangerKey.replaceAll(RegExp(r"[^a-zA-Z0-9_]"), '_');
    return 'ack_plan_${planId}_danger_$safe';
  }

  Future<void> _setDangerAcknowledged(int planId, String dangerKey, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final k = _dangerStorageKey(planId, dangerKey);
    if (value) {
      await prefs.setBool(k, true);
    } else {
      await prefs.remove(k);
      // If the user clears a per-danger acknowledgement, also clear the
      // global plan acknowledgement so the warning dialog can reappear.
      try {
        await prefs.remove('ack_plan_$planId');
      } catch (_) {}
    }
  }

  Future<bool> _isDangerAcknowledged(int planId, String dangerKey) async {
    final prefs = await SharedPreferences.getInstance();
    final k = _dangerStorageKey(planId, dangerKey);
    return prefs.getBool(k) ?? false;
  }

  Future<void> _showDangerWarning(NavigatorState navigator, dynamic snapshot, String message) async {
    if (!mounted) { return; }

    final pid = _latestPlan?.id;
    if (pid == null) return;

    // Build list of danger entries
    final List<MapEntry<String, Map<String, String>>> dangerEntries = [];

    if (snapshot is Map && snapshot['dangers'] is List) {
      final List dangers = snapshot['dangers'] as List;
      for (var i = 0; i < dangers.length; i++) {
        final danger = dangers[i];
        if (danger is Map) {
          final name = danger['name']?.toString() ?? 'Nguy hiểm ${i + 1}';
          final desc = danger['description']?.toString() ?? '';
          dangerEntries.add(MapEntry('danger_$i', {'name': name, 'description': desc}));
        }
      }
    } else if (snapshot is Map) {
      // Weather-based or key-value dangers
      final weatherDangerMap = {
        'heavy_rain': 'Mưa lớn',
        'strong_wind': 'Gió mạnh',
        'extreme_heat': 'Nắng nóng cực độ',
        'extreme_cold': 'Lạnh cực độ',
      };

      snapshot.forEach((k, v) {
        final keyStr = k.toString();
        if (v == true && weatherDangerMap.containsKey(keyStr)) {
          dangerEntries.add(MapEntry(keyStr, {'name': weatherDangerMap[keyStr]!, 'description': ''}));
        } else if (keyStr != 'source' && keyStr != 'latitude' && keyStr != 'longitude' &&
            keyStr != 'start_date' && keyStr != 'end_date' && keyStr != 'raw' && v != null) {
          final label = dangerLabelForKey(keyStr);
          dangerEntries.add(MapEntry(keyStr, {'name': label, 'description': v.toString()}));
        }
      });
    } else if (snapshot is List) {
      for (var i = 0; i < snapshot.length; i++) {
        final item = snapshot[i];
        if (item is Map) {
          final name = item['name']?.toString() ?? 'Nguy hiểm ${i + 1}';
          final desc = item['description']?.toString() ?? '';
          dangerEntries.add(MapEntry(i.toString(), {'name': name, 'description': desc}));
        } else if (item != null) {
          dangerEntries.add(MapEntry(i.toString(), {'name': item.toString(), 'description': ''}));
        }
      }
    }

    // If no structured dangers found, show simple message dialog
    if (dangerEntries.isEmpty) {
      await showDialog<void>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 48),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 8))],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('CẢNH BÁO NGUY HIỂM', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.6)),
                    const SizedBox(height: 10),
                    Text(message, textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic, height: 1.45, color: Color.fromRGBO(0,0,0,0.85))),
                  ]),
                ),
              ),
              Positioned(
                bottom: -22,
                child: Material(
                  color: Colors.transparent,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(28),
                  child: InkWell(
                    onTap: () async {
                      await _acknowledgePlan(pid);
                      if (!mounted) { return; }
                      navigator.pop();
                    },
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                      decoration: BoxDecoration(color: kPrimaryGreen, borderRadius: BorderRadius.circular(28)),
                      child: const Text('Đã hiểu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              )
            ]),
          );
        },
      );
      return;
    }

    // Show dialog with individual danger acknowledgments
    await showDialog<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'CẢNH BÁO NGUY HIỂM',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),

                    // Danger list
                    Flexible(
                      child: FutureBuilder<Map<String, bool>>(
                        future: _loadDangerAcknowledgments(pid, dangerEntries),
                        builder: (context, ackSnapshot) {
                          if (!ackSnapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final ackMap = ackSnapshot.data!;
                          final allAcknowledged = dangerEntries.every((e) => ackMap[e.key] == true);

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: dangerEntries.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1),
                                  itemBuilder: (context, idx) {
                                    final entry = dangerEntries[idx];
                                    final dangerData = entry.value;
                                    final isAcked = ackMap[entry.key] ?? false;

                                    return CheckboxListTile(
                                      value: isAcked,
                                      onChanged: (bool? value) async {
                                        if (value != null) {
                                          await _setDangerAcknowledged(pid, entry.key, value);
                                          setState(() {
                                            ackMap[entry.key] = value;
                                          });
                                        }
                                      },
                                      activeColor: kPrimaryGreen,
                                      title: Text(
                                        dangerData['name']!,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: isAcked ? Colors.grey : Colors.black87,
                                        ),
                                      ),
                                      subtitle: dangerData['description']!.isNotEmpty
                                          ? Text(
                                        dangerData['description']!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isAcked ? Colors.grey : Colors.black54,
                                        ),
                                      )
                                          : null,
                                      controlAffinity: ListTileControlAffinity.leading,
                                    );
                                  },
                                ),
                              ),

                              // Bottom action bar
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${dangerEntries.where((e) => ackMap[e.key] == true).length}/${dangerEntries.length} đã xác nhận',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: allAcknowledged
                                          ? () async {
                                        await _acknowledgePlan(pid);
                                        if (!mounted) return;
                                        navigator.pop();
                                      }
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kPrimaryGreen,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: Colors.grey.shade300,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                      ),
                                      child: const Text(
                                        'Đã hiểu tất cả',
                                        style: TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, bool>> _loadDangerAcknowledgments(int planId, List<MapEntry<String, Map<String, String>>> entries) async {
    final Map<String, bool> ackMap = {};
    for (final entry in entries) {
      ackMap[entry.key] = await _isDangerAcknowledged(planId, entry.key);
    }
    return ackMap;
  }



  /// Format a danger snapshot object for display in the warning dialog
  /// Handles nested structures with 'dangers' array or direct danger list
  String _formatDangerSnapshot(dynamic snapshot) {
    AppLogger.d('TripDashboard', 'DEBUG _formatDangerSnapshot called with: ${snapshot.runtimeType} = $snapshot');

    if (snapshot == null) {
      AppLogger.d('TripDashboard', 'DEBUG: snapshot is null, returning "Không có cảnh báo"');
      return 'Không có cảnh báo.';
    }

    // If it's a Map, check for 'dangers' key first
    if (snapshot is Map) {
      AppLogger.d('TripDashboard', 'DEBUG: snapshot is Map with keys: ${snapshot.keys.toList()}');

      // Check if there's a 'dangers' array with structured data
      if (snapshot['dangers'] is List) {
        AppLogger.d('TripDashboard', 'DEBUG: Found dangers array');
        final List dangers = snapshot['dangers'] as List;
        final parts = <String>[];
        for (final danger in dangers) {
          if (danger is Map) {
            final name = danger['name']?.toString() ?? 'Nguy hiểm không xác định';
            final desc = danger['description']?.toString() ?? '';
            parts.add('• $name${desc.isNotEmpty ? ": $desc" : ""}');
          } else if (danger is String) {
            parts.add('• ${danger.toString()}');
          }
        }
        final result = parts.isNotEmpty ? parts.join('\n') : 'Không có cảnh báo.';
        AppLogger.d('TripDashboard', 'DEBUG: Formatted dangers result: $result');
        return result;
      }

      // Otherwise format as key-value pairs
      AppLogger.d('TripDashboard', 'DEBUG: No dangers array, formatting as key-value pairs');
      final parts = <String>[];

      // Map weather-based danger keys to Vietnamese labels
      final weatherDangerMap = {
        'heavy_rain': 'Mưa lớn',
        'strong_wind': 'Gió mạnh',
        'extreme_heat': 'Nắng nóng cực độ',
        'extreme_cold': 'Lạnh cực độ',
      };

      snapshot.forEach((k, v) {
        if (v == true && weatherDangerMap.containsKey(k)) {
          parts.add('• ${weatherDangerMap[k]}');
        }
      });

      // If no weather dangers, try custom danger keys
      if (parts.isEmpty) {
        snapshot.forEach((k, v) {
          if (v != null && k != 'source' && k != 'latitude' && k != 'longitude' && k != 'start_date' && k != 'end_date' && k != 'raw') {
            final label = dangerLabelForKey(k.toString());
            if (v is bool && v) {
              parts.add('• $label');
            } else if (v is String && v.isNotEmpty) {
              parts.add('• $label: $v');
            } else if (v is! bool) {
              parts.add('• $label: ${v.toString()}');
            }
          }
        });
      }

      final result = parts.isNotEmpty ? parts.join('\n') : 'Không có cảnh báo.';
      AppLogger.d('TripDashboard', 'DEBUG: Formatted key-value result: $result');
      return result;
    }

    // If it's a List, format as bullet points
    if (snapshot is List) {
      AppLogger.d('TripDashboard', 'DEBUG: snapshot is List with ${snapshot.length} items');
      final parts = <String>[];
      for (final item in snapshot) {
        if (item is Map) {
          final name = item['name']?.toString() ?? 'Nguy hiểm';
          final desc = item['description']?.toString() ?? '';
          parts.add('• $name${desc.isNotEmpty ? ": $desc" : ""}');
        } else if (item is String && item.isNotEmpty) {
          parts.add('• $item');
        }
      }
      final result = parts.isNotEmpty ? parts.join('\n') : 'Không có cảnh báo.';
      AppLogger.d('TripDashboard', 'DEBUG: Formatted list result: $result');
      return result;
    }

    // Fallback for other types
    AppLogger.d('TripDashboard', 'DEBUG: snapshot is ${snapshot.runtimeType}, using toString()');
    return snapshot.toString();
  }

  Future<void> _showDangerViewer() async {
    final ctx = context;
    try {
      final pid = _latestPlan?.id;
      AppLogger.d('TripDashboard', 'DEBUG _showDangerViewer: pid=$pid');

      // Get raw snapshot from database (not pre-formatted)
      dynamic snapshot;
      if (pid != null) {
        final planRow = await _db.getPlanById(pid);
        snapshot = planRow != null ? planRow['dangers_snapshot'] : null;
        AppLogger.d('TripDashboard', 'DEBUG: getPlanById($pid) dangers_snapshot=$snapshot');
      } else {
        // Fallback: get latest plan's snapshot
        final res = await Supabase.instance.client
            .from('plans')
            .select('dangers_snapshot')
            .eq('user_id', Supabase.instance.client.auth.currentUser?.id ?? '')
            .order('id', ascending: false)
            .limit(1)
            .maybeSingle();
        snapshot = res?['dangers_snapshot'];
        AppLogger.d('TripDashboard', 'DEBUG: latest plan dangers_snapshot=$snapshot');
      }

      AppLogger.d('TripDashboard', 'DEBUG: Raw snapshot type=${snapshot.runtimeType}, value=$snapshot');

      // Format for display using the same method as the warning popup
      final message = _formatDangerSnapshot(snapshot);
      AppLogger.d('TripDashboard', 'DEBUG: Formatted message=$message');

      final List<MapEntry<String, dynamic>> entries = [];

      // Build entries list for detailed view
      if (snapshot is Map) {
        // Check for 'dangers' array first (structured format)
        if (snapshot['dangers'] is List) {
          final List dangers = snapshot['dangers'] as List;
          for (var i = 0; i < dangers.length; i++) {
            final danger = dangers[i];
            if (danger is Map) {
              final name = danger['name']?.toString() ?? 'Nguy hiểm ${i + 1}';
              final desc = danger['description']?.toString() ?? '';
              entries.add(MapEntry('danger_$i', {'name': name, 'description': desc}));
            }
          }
        } else {
          // Fallback: treat as key-value pairs
          for (final e in snapshot.entries) {
            // Skip metadata fields
            final key = e.key.toString();
            if (key != 'source' && key != 'latitude' && key != 'longitude' &&
                key != 'start_date' && key != 'end_date' && key != 'raw') {
              entries.add(MapEntry(key, e.value));
            }
          }
        }
      } else if (snapshot is List) {
        for (var i = 0; i < snapshot.length; i++) {
          entries.add(MapEntry(i.toString(), snapshot[i]));
        }
      } else if (snapshot != null) {
        entries.add(MapEntry('message', snapshot));
      }

      AppLogger.d('TripDashboard', 'DEBUG: entries count=${entries.length}');

      final Map<String, bool> ackMap = {};
      if (pid != null) {
        for (final e in entries) {
          ackMap[e.key] = await _isDangerAcknowledged(pid, e.key);
        }
      }

      if (!mounted) { return; }
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) { return; }
        showDialog<void>(
          context: ctx,
          builder: (context) {
            const bg = Colors.white;
            final accent = kPrimaryGreen;
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 8))],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Center(child: Text('Chi tiết cảnh báo', textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w900, fontSize: 20))),
                      const SizedBox(height: 8),
                      if (entries.isEmpty) ...[
                        Align(alignment: Alignment.centerLeft, child: Text(message, style: const TextStyle(fontStyle: FontStyle.italic, height: 1.35, color: Colors.black87))),
                      ] else ...[
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 320),
                          child: StatefulBuilder(builder: (context, setState) {
                            return ListView.separated(
                              shrinkWrap: true,
                              itemCount: entries.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final e = entries[idx];
                                final val = e.value;
                                final reviewed = ackMap[e.key] ?? false;
                                final color = reviewed ? Colors.amber : Colors.redAccent;

                                // Format label and subtitle based on danger type
                                String label;
                                String? subtitle;

                                if (val is Map && val.containsKey('name')) {
                                  // Structured danger with name/description
                                  label = val['name']?.toString() ?? 'Nguy hiểm không xác định';
                                  subtitle = val['description']?.toString();
                                } else if (e.key.startsWith('danger_')) {
                                  // Indexed danger entry
                                  label = 'Nguy hiểm ${idx + 1}';
                                  subtitle = val?.toString();
                                } else {
                                  // Key-value pair danger
                                  label = dangerLabelForKey(e.key);
                                  subtitle = val?.toString();
                                }

                                AppLogger.d('TripDashboard', 'DEBUG: Entry $idx - label="$label", subtitle="$subtitle"');

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  leading: CircleAvatar(radius: 10, backgroundColor: color),
                                  title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: subtitle != null && subtitle.isNotEmpty ? Text(subtitle) : null,
                                  trailing: pid != null
                                      ? TextButton(
                                    onPressed: () async {
                                      final newVal = !(ackMap[e.key] ?? false);
                                      await _setDangerAcknowledged(pid, e.key, newVal);
                                      setState(() {
                                        ackMap[e.key] = newVal;
                                      });
                                    },
                                    child: Text(ackMap[e.key] == true ? 'Đã xem' : 'Chưa xem', style: TextStyle(color: accent)),
                                  )
                                      : null,
                                );
                              },
                            );
                          }),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Đóng')),
                      ])
                    ]),
                  ),
                ),
              ),
            );
          },
        );
      });
    } catch (e) {
      if (!mounted) { return; }
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) { return; }
        showDialog<void>(
          context: ctx,
          builder: (c) => AlertDialog(
            title: const Text('Lỗi'),
            content: SingleChildScrollView(child: Text('Không thể tải cảnh báo.\n\n${e.toString()}')),
            actions: [
              TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Đóng')),
            ],
          ),
        );
      });
    }
  }

  Future<dynamic> _checkWeatherAndSave(Plan plan) async {
    AppLogger.d('TripDashboard', 'DEBUG: _checkWeatherAndSave called for plan ${plan.id}');
    final loc = plan.location;
    if (loc == null || loc.trim().isEmpty) {
      AppLogger.d('TripDashboard', 'DEBUG: No location, creating demo dangers');
      // Create demo dangers even without location
      final demoDangers = {
        'dangers': [
          {
            'name': 'Thời tiết không thuận lợi',
            'description': 'Dự báo thời tiết không tốt cho chuyến đi',
            'severity': 'medium',
            'recommendation': 'Kiểm tra dự báo chi tiết trước khi khởi hành'
          },
          {
            'name': 'Cảnh báo địa hình',
            'description': 'Khu vực có địa hình phức tạp',
            'severity': 'high',
            'recommendation': 'Hãy cẩn thận khi đi qua các khu vực núi cao'
          }
        ]
      };
      final planId = plan.id;
      if (planId != null) {
        await _db.saveDangerSnapshotForPlan(planId, demoDangers);
        AppLogger.d('TripDashboard', 'DEBUG: Saved demo dangers for plan $planId');
      }
      return demoDangers;
    }

    double? lat;
    double? lon;
    try {
      final geocodeUrl = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(loc)}&format=json&limit=1');
      final geores = await http.get(geocodeUrl, headers: {'User-Agent': 'CT-Project-App'});
      if (geores.statusCode == 200) {
        final decoded = jsonDecode(geores.body) as List<dynamic>?;
        if (decoded != null && decoded.isNotEmpty) {
          final first = decoded.first as Map<String, dynamic>;
          lat = double.tryParse(first['lat']?.toString() ?? '');
          lon = double.tryParse(first['lon']?.toString() ?? '');
        }
      }
    } catch (e) {
      AppLogger.e('TripDashboard', 'Geocoding failed: ${e.toString()}');
    }

    if (lat == null || lon == null) {
      AppLogger.d('TripDashboard', 'DEBUG: Geocoding failed, creating demo dangers');
      // Create demo dangers if geocoding fails
      final demoDangers = {
        'dangers': [
          {
            'name': 'Thời tiết không thuận lợi',
            'description': 'Dự báo thời tiết không tốt cho chuyến đi',
            'severity': 'medium',
            'recommendation': 'Kiểm tra dự báo chi tiết trước khi khởi hành'
          },
          {
            'name': 'Cảnh báo địa hình',
            'description': 'Khu vực có địa hình phức tạp',
            'severity': 'high',
            'recommendation': 'Hãy cẩn thận khi đi qua các khu vực núi cao'
          }
        ]
      };
      final planId = plan.id;
      if (planId != null) {
        await _db.saveDangerSnapshotForPlan(planId, demoDangers);
        AppLogger.d('TripDashboard', 'DEBUG: Saved demo dangers for plan $planId');
      }
      return demoDangers;
    }

    int? planId = plan.id;
    DateTime? startDate;
    int durationDays = 1;
    if (planId != null) {
      final planRow = await _db.getPlanById(planId);
      if (planRow != null) {
        try {
          final sd = planRow['start_date']?.toString();
          if (sd != null && sd.isNotEmpty) {
            startDate = DateTime.tryParse(sd);
          }
        } catch (_) {}

        try {
          final d = planRow['duration_days'];
          if (d is int) {
            durationDays = d;
          } else if (d is String) {
            durationDays = int.tryParse(d) ?? durationDays;
          }
        } catch (_) {}
      }
    }
    startDate ??= DateTime.now().toUtc();
    final endDate = startDate.add(Duration(days: durationDays));

    final startStr = startDate.toIso8601String().split('T').first;
    final endStr = endDate.toIso8601String().split('T').first;

    final weatherUrl = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,windspeed_10m_max&timezone=UTC&start_date=$startStr&end_date=$endStr');

    Map<String, dynamic>? weatherJson;
    try {
      final wres = await http.get(weatherUrl);
      if (wres.statusCode == 200) weatherJson = jsonDecode(wres.body) as Map<String, dynamic>?;
    } catch (e) {
      AppLogger.e('TripDashboard', 'Weather fetch failed: ${e.toString()}');
    }
    if (weatherJson == null) return null;

    final Map<String, dynamic> snapshot = {};
    try {
      final daily = weatherJson['daily'] as Map<String, dynamic>?;
      if (daily != null) {
        final tempsMax = List<dynamic>.from(daily['temperature_2m_max'] ?? []);
        final tempsMin = List<dynamic>.from(daily['temperature_2m_min'] ?? []);
        final precSum = List<dynamic>.from(daily['precipitation_sum'] ?? []);
        final windMax = List<dynamic>.from(daily['windspeed_10m_max'] ?? []);

        bool heavyRain = precSum.any((v) => (v ?? 0) is num && (v as num) > 20);
        bool strongWind = windMax.any((v) => (v ?? 0) is num && (v as num) > 15);
        bool extremeHeat = tempsMax.any((v) => (v ?? 0) is num && (v as num) > 40);
        bool extremeCold = tempsMin.any((v) => (v ?? 0) is num && (v as num) < -10);

        if (heavyRain) snapshot['heavy_rain'] = true;
        if (strongWind) snapshot['strong_wind'] = true;
        if (extremeHeat) snapshot['extreme_heat'] = true;
        if (extremeCold) snapshot['extreme_cold'] = true;

        if (snapshot.isNotEmpty) {
          snapshot['source'] = 'open-meteo';
          snapshot['latitude'] = lat;
          snapshot['longitude'] = lon;
          snapshot['start_date'] = startStr;
          snapshot['end_date'] = endStr;
          snapshot['raw'] = daily;
        }
      }
    } catch (e) {
      AppLogger.e('TripDashboard', 'Weather analysis error: ${e.toString()}');
    }

    // If no weather dangers found, create DEMO dangers for testing
    if (snapshot.isEmpty) {
      AppLogger.d('TripDashboard', 'No weather dangers found, creating DEMO dangers for testing');
      snapshot['dangers'] = [
        {
          'name': 'Thời tiết không thuận lợi',
          'description': 'Dự báo thời tiết không tốt cho chuyến đi',
          'severity': 'medium',
          'recommendation': 'Kiểm tra dự báo chi tiết trước khi khởi hành'
        },
        {
          'name': 'Cảnh báo địa hình',
          'description': 'Khu vực có địa hình phức tạp',
          'severity': 'high',
          'recommendation': 'Hãy cẩn thận khi đi qua các khu vực núi cao'
        }
      ];
    }

    if (snapshot.isNotEmpty && planId != null) {
      try {
        await _db.saveDangerSnapshotForPlan(planId, snapshot);
        AppLogger.d('TripDashboard', 'Saved danger snapshot for plan $planId: $snapshot');
        return snapshot;
      } catch (e) {
        AppLogger.e('TripDashboard', 'Failed to save danger snapshot: ${e.toString()}');
        return snapshot;
      }
    }

    return null;
  }

  void _navigateAndAddNote() async {
    final res = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _NoteEditorScreen()));
    if (res is String && res.isNotEmpty) {
      setState(() => _notes.add(res));
      final pid = _latestPlan?.id;
      if (pid != null) await _saveNotesForPlan(pid);
    }
  }

  void _editNote(int idx) async {
    if (idx < 0 || idx >= _notes.length) { return; }
    final res = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _NoteEditorScreen(initialText: _notes[idx])));
    if (res is String && res.isNotEmpty) {
      setState(() => _notes[idx] = res);
      final pid = _latestPlan?.id;
      if (pid != null) await _saveNotesForPlan(pid);
    }
  }

  void _deleteNote(int idx) async {
    if (idx < 0 || idx >= _notes.length) { return; }
    setState(() => _notes.removeAt(idx));
    final pid = _latestPlan?.id;
    if (pid != null) await _saveNotesForPlan(pid);
  }
}

class _TripHeader extends StatelessWidget {
  final VoidCallback? onBackPressed;
  final VoidCallback? onViewDanger;
  const _TripHeader({this.onBackPressed, this.onViewDanger});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 8),
      Center(child: Container(width: 18, height: 18, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle))),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
        child: Row(children: [
          IconButton(onPressed: onBackPressed, icon: const Icon(Icons.arrow_back, size: 28)),
          const Expanded(child: Center(child: Text('Bảng thông tin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)))),
          IconButton(onPressed: onViewDanger, icon: const Icon(Icons.info_outline)),
        ]),
      ),
    ]);
  }
}

class _TripTabs extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTabChanged;
  const _TripTabs({required this.activeIndex, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, int idx) {
      final active = idx == activeIndex;
      return Expanded(
        child: GestureDetector(
          onTap: () => onTabChanged(idx),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? kPrimaryGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? Colors.white : Colors.black54))),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: const Color(0xFFECE9E6), borderRadius: BorderRadius.circular(18)),
      child: Row(children: [tab('Lộ trình', 0), const SizedBox(width: 6), tab('Vật dụng', 1), const SizedBox(width: 6), tab('Ghi chú', 2)]),
    );
  }
}

class _ItemsTab extends StatefulWidget {
  final Plan? plan;
  final Map<String, Map<String, dynamic>> equipmentDetails;
  final Function(String, String?) onBuyPressed;

  const _ItemsTab({
    this.plan,
    required this.equipmentDetails,
    required this.onBuyPressed,
  });

  @override
  State<_ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<_ItemsTab> {
  final Set<String> _checked = {};
  bool _loadingLocal = true;

  String? get _planKey => widget.plan?.id != null ? 'local_checklist_plan_${widget.plan!.id}' : null;

  @override
  void initState() {
    super.initState();
    _loadLocalChecklist();
  }

  Future<void> _loadLocalChecklist() async {
    final key = _planKey;
    if (key == null) {
      setState(() => _loadingLocal = false);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(key) ?? [];
    setState(() {
      _checked.addAll(list);
      _loadingLocal = false;
    });
  }

  Future<void> _saveLocalChecklist() async {
    final key = _planKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, _checked.toList());
  }

  void _toggleItemChecked(String id, bool? value) {
    setState(() {
      if (value == true) {
        _checked.add(id);
      } else {
        _checked.remove(id);
      }
    });
    _saveLocalChecklist();
  }

  void _clearLocalChecklist() async {
    final key = _planKey;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    setState(() => _checked.clear());
  }

  @override
  Widget build(BuildContext context) {
    final equipmentMap = widget.plan?.personalizedEquipmentList ?? {};

    if (equipmentMap.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.checklist_rtl_rounded, size: 64, color: Colors.black12),
              SizedBox(height: 12),
              Text(
                'Chưa có danh sách vật dụng.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final entries = equipmentMap.entries.toList();
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 80, top: 0),
        children: entries.asMap().entries.map((mapEntry) {
          final idx = mapEntry.key;
          final entry = mapEntry.value;
          String category = entry.key;
          List<dynamic> items = entry.value is List ? entry.value : [];

          if (items.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 4, height: 18,
                      decoration: BoxDecoration(color: kPrimaryGreen, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        category.toUpperCase(),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 1.0),
                      ),
                    ),
                    if (idx == 0) ...[
                      if (_loadingLocal) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                      TextButton(onPressed: _clearLocalChecklist, child: const Text('Xóa đánh dấu')),
                    ]
                  ],
                ),
              ),
              ...items.map((item) => _buildSingleItem(item)),
              const SizedBox(height: 8),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSingleItem(dynamic itemData) {
    final Map<String, dynamic> item = Map<String, dynamic>.from(itemData);
    final String name = item['name'] ?? 'Vật dụng';
    final int quantity = item['quantity'] ?? 1;
    final String? reason = item['reason'];
    final id = item['id'].toString();

    String? imageUrl;
    String? buyLink;
    if (widget.equipmentDetails.containsKey(id)) {
      imageUrl = widget.equipmentDetails[id]?['image_url'];
      buyLink = widget.equipmentDetails[id]?['buy_link'];
    }

    final priceRaw = item['price'];
    String priceStr = '';
    if (priceRaw != null) {
      priceStr = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(priceRaw);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Local checklist checkbox
              Padding(
                padding: const EdgeInsets.only(top: 2.0, right: 8.0),
                child: Checkbox(
                  value: _checked.contains(id),
                  onChanged: (v) => _toggleItemChecked(id, v),
                ),
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                )
                    : const Icon(Icons.hiking, color: Colors.grey),
              ),
              const SizedBox(width: 8),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300)
                          ),
                          child: Text("x$quantity", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        )
                      ],
                    ),

                    if (priceStr.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(priceStr, style: const TextStyle(fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.w600)),
                    ],

                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => widget.onBuyPressed(name, buyLink),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(26),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withAlpha(128)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_cart_outlined, size: 14, color: Colors.deepOrange),
                            const SizedBox(width: 4),
                            Text(
                                "Mua ngay",
                                style: TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.bold)
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.brown.shade700,
                        fontStyle: FontStyle.italic,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}

class _RouteTab extends StatefulWidget {
  final Plan? plan;
  final String? aiNote;
  final bool isLoadingNote;

  const _RouteTab({super.key, this.plan, this.aiNote, this.isLoadingNote = false});

  @override
  State<_RouteTab> createState() => _RouteTabState();
}

class _RouteTabState extends State<_RouteTab> with AutomaticKeepAliveClientMixin {
  MapLibreMapController? map3DController;
  final fmap.MapController map2DController = fmap.MapController();
  bool _is3DMode = false;
  bool _isMapLoading = true;

  final String _apiKey = dotenv.env['MAPTILER_KEY'] ?? 'your_key';
  String get _style3DUrl => "https://api.maptiler.com/maps/outdoor-v2/style.json?key=$_apiKey";

  List<LatLng> _coords3D = [];
  List<fcoords.LatLng> _coords2D = [];
  List<Map<String, dynamic>> _waypointsData = [];
  List<InteractivePoint> _interactivePoints = [];
  int? _hoverIndex;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _prepareData();
  }

  @override
  void didUpdateWidget(covariant _RouteTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.plan?.id != oldWidget.plan?.id) _prepareData();
  }

  Future<void> _prepareData() async {
    try {
      final routes = widget.plan?.routes ?? [];
      int? routeId = routes.isNotEmpty ? routes.first.id : null;

      if (routeId == null) {
        if (widget.plan != null) _useFakeData();
        return;
      }

      final supabase = Supabase.instance.client;
      final wptResponse = await supabase.from('route_waypoints').select('*').eq('route_id', routeId);
      final routeResponse = await supabase.from('routes').select('path_coordinates').eq('id', routeId).maybeSingle();

      List<fcoords.LatLng> rawPoints = [];
      if (routeResponse != null && routeResponse['path_coordinates'] != null) {
        final List<dynamic> rawCoords = routeResponse['path_coordinates'];
        rawPoints = rawCoords.map((c) => fcoords.LatLng(c[0].toDouble(), c[1].toDouble())).toList();
      }

      if (rawPoints.isEmpty) { _useFakeData(); return; }

      List<fcoords.LatLng> detailedPath = rawPoints;
      if (rawPoints.length >= 2) detailedPath = await _getDetailedPathFromOSRM(rawPoints);

      // --- FETCH REAL ELEVATION ---
      List<InteractivePoint> finalPoints = [];
      final sampledForApi = _sampleCoordinates(detailedPath, 80);
      final realElevations = await _getElevationsFromApi(sampledForApi);

      if (realElevations.isNotEmpty && realElevations.length == sampledForApi.length) {
        double currentDistance = 0;
        const fcoords.Distance distanceCalc = fcoords.Distance();
        for (int i = 0; i < sampledForApi.length; i++) {
          if (i > 0) currentDistance += distanceCalc.as(fcoords.LengthUnit.Kilometer, sampledForApi[i-1], sampledForApi[i]);
          finalPoints.add(InteractivePoint(coordinate: sampledForApi[i], elevation: realElevations[i], distance: currentDistance));
        }
      } else {
        // Fallback to simulated
        _generateSimulatedPoints(detailedPath, widget.plan?.routes.firstOrNull?.elevationGainM ?? 500, seedId: routeId);
        if (mounted) setState(() { _coords2D = detailedPath; _coords3D = detailedPath.map((c) => LatLng(c.latitude, c.longitude)).toList(); _waypointsData = List<Map<String, dynamic>>.from(wptResponse); _isMapLoading = false; });
        return;
      }

      if (mounted) {
        setState(() {
          _coords2D = detailedPath;
          _coords3D = detailedPath.map((c) => LatLng(c.latitude, c.longitude)).toList();
          _waypointsData = List<Map<String, dynamic>>.from(wptResponse);
          _interactivePoints = finalPoints;
          _isMapLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isMapLoading = false);
    }
  }

  // --- HELPERS (API, SAMPLING, OSRM) ---
  List<fcoords.LatLng> _sampleCoordinates(List<fcoords.LatLng> input, int targetCount) {
    if (input.length <= targetCount) return input;
    List<fcoords.LatLng> result = [];
    int step = (input.length / targetCount).floor();
    for (int i = 0; i < input.length; i += step) result.add(input[i]);
    if (result.isNotEmpty && result.last != input.last) result.add(input.last);
    return result;
  }

  Future<List<double>> _getElevationsFromApi(List<fcoords.LatLng> points) async {
    const String url = 'https://api.open-elevation.com/api/v1/lookup';
    Map<String, dynamic> body = {"locations": points.map((p) => {"latitude": p.latitude, "longitude": p.longitude}).toList()};
    try {
      final response = await http.post(Uri.parse(url), headers: {"Content-Type": "application/json"}, body: jsonEncode(body));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['results'] as List).map<double>((item) => (item['elevation'] as num).toDouble()).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<fcoords.LatLng>> _getDetailedPathFromOSRM(List<fcoords.LatLng> sparsePoints) async {
    if (sparsePoints.isEmpty) return [];
    String coordinatesString = sparsePoints.map((p) => "${p.longitude},${p.latitude}").join(';');
    final String url = "http://router.project-osrm.org/route/v1/foot/$coordinatesString?overview=full&geometries=geojson";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final geometry = data['routes'][0]['geometry'];
          final List<dynamic> coords = geometry['coordinates'];
          return coords.map((c) => fcoords.LatLng(c[1], c[0])).toList();
        }
      }
    } catch (_) {}
    return sparsePoints;
  }

  void _generateSimulatedPoints(List<fcoords.LatLng> coords, int maxGain, {int? seedId}) {
    // (Logic giả lập cũ nếu API lỗi)
    int seed = seedId ?? 999;
    List<InteractivePoint> tempPoints = [];
    double currentDistance = 0;
    const fcoords.Distance distanceCalc = fcoords.Distance();
    double startElevation = 500;
    double effectiveMaxGain = maxGain > 0 ? maxGain.toDouble() : 500.0;

    for (int i = 0; i < coords.length; i++) {
      if (i > 0) currentDistance += distanceCalc.as(fcoords.LengthUnit.Kilometer, coords[i-1], coords[i]);
      double progress = i / (coords.length - 1);
      double mountainShape = sin(progress * pi) * effectiveMaxGain;
      double pseudoRandom = sin(i * 13.0 + seed) * (effectiveMaxGain * 0.05);
      double elevation = startElevation + mountainShape + pseudoRandom;
      tempPoints.add(InteractivePoint(coordinate: coords[i], elevation: elevation, distance: currentDistance));
    }
    setState(() => _interactivePoints = tempPoints);
  }

  void _useFakeData() { setState(() => _isMapLoading = false); }

  // --- CHART WIDGET (FLOATING TOOLTIP) ---
  Widget _buildElevationChart() {
    if (_interactivePoints.isEmpty) return const SizedBox(height: 150, child: Center(child: Text("Đang tải độ cao...")));
    InteractivePoint? activePoint;
    if (_hoverIndex != null && _hoverIndex! < _interactivePoints.length) activePoint = _interactivePoints[_hoverIndex!];

    return SizedBox(
      height: 180,
      width: double.infinity,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true, handleBuiltInTouches: true,
                  touchTooltipData: const LineTouchTooltipData(getTooltipItems: _nullTooltip),
                  getTouchedSpotIndicator: (barData, spotIndexes) {
                    return spotIndexes.map((index) => TouchedSpotIndicatorData(
                      const FlLine(color: Colors.grey, strokeWidth: 1, dashArray: [4, 4]),
                      FlDotData(getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: 5, color: Colors.white, strokeWidth: 2, strokeColor: Colors.blueAccent)),
                    )).toList();
                  },
                  touchCallback: (event, response) {
                    if (response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
                      final index = response.lineBarSpots!.first.spotIndex;
                      if (_hoverIndex != index) setState(() => _hoverIndex = index);
                    } else if (event is FlTapUpEvent || event is FlPanEndEvent) {
                      setState(() => _hoverIndex = null);
                    }
                  },
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _interactivePoints.map((p) => FlSpot(p.distance, p.elevation)).toList(),
                    isCurved: true, color: Colors.black87, barWidth: 2, isStrokeCapRound: true, dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [Colors.green.withOpacity(0.3), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                  ),
                ],
              ),
            ),
          ),
          if (activePoint != null)
            Positioned(
              top: 0, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))], border: Border.all(color: Colors.grey.shade200)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _buildInfoItem("Distance", "${activePoint.distance.toStringAsFixed(1)} km"),
                    Container(width: 1, height: 24, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 16)),
                    _buildInfoItem("Elevation", "${activePoint.elevation.toStringAsFixed(0)} m"),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500)),
      const SizedBox(height: 1),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
    ]);
  }

  // --- MAP WIDGETS ---
  void _onMap3DCreated(MapLibreMapController controller) { map3DController = controller; }
  Future<void> _onStyle3DLoaded() async {
    if (map3DController == null || _coords3D.isEmpty) return;
    await map3DController!.addLine(LineOptions(geometry: _coords3D, lineColor: "#E91E63", lineWidth: 4.0));
    await map3DController!.animateCamera(CameraUpdate.newLatLngBounds(_bounds3D(_coords3D), left: 20, right: 20, top: 20, bottom: 20));
  }
  LatLngBounds _bounds3D(List<LatLng> list) {
    double? minLat, maxLat, minLng, maxLng;
    for (final l in list) { minLat = min(minLat ?? l.latitude, l.latitude); maxLat = max(maxLat ?? l.latitude, l.latitude); minLng = min(minLng ?? l.longitude, l.longitude); maxLng = max(maxLng ?? l.longitude, l.longitude); }
    return LatLngBounds(southwest: LatLng(minLat!, minLng!), northeast: LatLng(maxLat!, maxLng!));
  }

  Widget _buildMap2D() {
    if (_coords2D.isEmpty) return const Center(child: Text("Không có dữ liệu bản đồ"));
    fcoords.LatLng? hoverLoc;
    if (_hoverIndex != null && _interactivePoints.isNotEmpty && _hoverIndex! < _interactivePoints.length) {
      hoverLoc = _interactivePoints[_hoverIndex!].coordinate;
    }

    return fmap.FlutterMap(
      mapController: map2DController,
      options: fmap.MapOptions(initialCameraFit: fmap.CameraFit.bounds(bounds: fmap.LatLngBounds.fromPoints(_coords2D), padding: const EdgeInsets.all(40))),
      children: [
        fmap.TileLayer(urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}'),
        fmap.PolylineLayer(polylines: [fmap.Polyline(points: _coords2D, color: const Color(0xFFE91E63), strokeWidth: 5.0, strokeCap: StrokeCap.round, strokeJoin: StrokeJoin.round)]),
        fmap.MarkerLayer(markers: [
          fmap.Marker(point: _coords2D.first, width: 80, height: 50, child: _build2DLabelMarker("START", Icons.circle, Colors.green)),
          fmap.Marker(point: _coords2D.last, width: 80, height: 50, child: _build2DLabelMarker("END", Icons.flag, Colors.red)),
          ..._waypointsData.map((wpt) => fmap.Marker(point: fcoords.LatLng(wpt['latitude'], wpt['longitude']), width: 100, height: 70, child: _build2DDetailMarker(wpt))),
        ]),
        if (hoverLoc != null)
          fmap.MarkerLayer(markers: [fmap.Marker(point: hoverLoc, width: 24, height: 24, child: Container(decoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [const BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))])))]),
      ],
    );
  }

  // Helper Markers
  Widget _build2DLabelMarker(String label, IconData icon, Color color) {
    return Column(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: color, width: 2)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 10, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10))])), Icon(Icons.arrow_drop_down, color: color, size: 20)]);
  }
  Widget _build2DDetailMarker(Map<String, dynamic> wpt) {
    Color color = Colors.blue; IconData icon = Icons.place;
    if (wpt['type'] == 'summit') { color = Colors.brown; icon = Icons.terrain; }
    if (wpt['type'] == 'danger') { color = Colors.red; icon = Icons.warning_rounded; }
    if (wpt['type'] == 'campsite') { color = Colors.green; icon = Icons.night_shelter; }
    return GestureDetector(
      onTap: () {}, // Show modal if needed
      child: Column(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.white.withAlpha(230), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey[300]!)), child: Text(wpt['name'], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), maxLines: 1)), Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)), child: Icon(icon, color: Colors.white, size: 12))]),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final routes = widget.plan?.routes ?? [];
    if (widget.plan == null || routes.isEmpty) return const Center(child: CircularProgressIndicator());
    final r = routes.first;

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        SizedBox(height: 400, child: Stack(children: [
          if (_isMapLoading) const Center(child: CircularProgressIndicator())
          else if (_is3DMode) MapLibreMap(styleString: _style3DUrl, onMapCreated: _onMap3DCreated, onStyleLoadedCallback: _onStyle3DLoaded, initialCameraPosition: const CameraPosition(target: LatLng(21.0, 105.8), zoom: 10.0))
          else _buildMap2D(),
          Positioned(top: 16, right: 16, child: GestureDetector(onTap: () => setState(() => _is3DMode = !_is3DMode), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(30)), child: Row(children: [Icon(_is3DMode ? Icons.map : Icons.view_in_ar, size: 18, color: Colors.white), const SizedBox(width: 8), Text(_is3DMode ? "2D" : "3D", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white))])))),
        ])),
        Container(
          transform: Matrix4.translationValues(0, -20, 0),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.name ?? 'Lộ trình', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.2)),
            const SizedBox(height: 8),
            Text('${r.distanceKm ?? 0} km • ${r.elevationGainM ?? 0} m gain', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
            const SizedBox(height: 24),
            const Text("Biểu đồ độ cao", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
            _buildElevationChart(),
            const SizedBox(height: 24),
            Row(children: const [Icon(Icons.auto_awesome, size: 20, color: Colors.purple), SizedBox(width: 8), Text("Thông tin AI gợi ý", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 12),
            Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.purple.withOpacity(0.05), borderRadius: BorderRadius.circular(12)), child: widget.isLoadingNote ? const Center(child: CircularProgressIndicator()) : Text(widget.aiNote ?? "Không có thông tin", style: const TextStyle(fontSize: 15, height: 1.6))),
          ]),
        ),
      ],
    );
  }
}
List<LineTooltipItem?> _nullTooltip(List<LineBarSpot> spots) => List.generate(spots.length, (index) => null);

class _NoteEditorScreen extends StatefulWidget { final String? initialText; const _NoteEditorScreen({this.initialText}); @override State<_NoteEditorScreen> createState() => _NoteEditorScreenState(); }
class _NoteEditorScreenState extends State<_NoteEditorScreen> { final TextEditingController _ctrl = TextEditingController(); @override void initState() { super.initState(); _ctrl.text = widget.initialText ?? ''; } @override Widget build(BuildContext context) { return Scaffold(appBar: AppBar(title: const Text('Thêm ghi chú'), backgroundColor: kPrimaryGreen), body: Padding(padding: const EdgeInsets.all(16.0), child: Column(children: [Expanded(child: TextField(controller: _ctrl, maxLines: null, expands: true, decoration: const InputDecoration(hintText: 'Nhập ghi chú...'))), ElevatedButton(onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()), child: const Text('Lưu'))]))); } }
class _NotesTab extends StatelessWidget { final List<String> notes; final void Function(int) onDeleteNote; final void Function(int) onEditNote; const _NotesTab({required this.notes, required this.onDeleteNote, required this.onEditNote}); @override Widget build(BuildContext context) { return ListView.builder(itemCount: notes.length, itemBuilder: (context, index) => ListTile(title: Text(notes[index]), trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => onDeleteNote(index)), onTap: () => onEditNote(index))); } }