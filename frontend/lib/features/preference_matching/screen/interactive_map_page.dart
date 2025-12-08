import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// --- CÁC THƯ VIỆN BÊN NGOÀI ---
import 'package:maplibre_gl/maplibre_gl.dart'; // 3D Map
import 'package:flutter_map/flutter_map.dart' as fmap; // 2D Map
import 'package:latlong2/latlong.dart' as fcoords; // Toạ độ cho 2D Map
import 'package:fl_chart/fl_chart.dart'; // Biểu đồ
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- IMPORT DỰ ÁN CỦA BẠN ---
import 'package:frontend/services/gemini_service.dart';
import 'package:frontend/features/preference_matching/models/route_model.dart';
import 'package:frontend/widgets/custom_button.dart';
import 'package:frontend/providers/trip_provider.dart';
import 'package:frontend/screens/pec.dart';
import 'package:frontend/utils/notification.dart';
import 'package:frontend/providers/achievement_provider.dart';

// ==========================================
// 1. MODEL ĐỒNG BỘ (Chart <-> Map)
// ==========================================
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

class InteractiveMapPage extends StatefulWidget {
  final RouteModel route;
  const InteractiveMapPage({super.key, required this.route});

  @override
  State<InteractiveMapPage> createState() => _InteractiveMapPageState();
}

class _InteractiveMapPageState extends State<InteractiveMapPage> {
  // --- CONTROLLERS ---
  MapLibreMapController? map3DController;
  final fmap.MapController map2DController = fmap.MapController();

  // --- STATE VARIABLES ---
  bool _isLoading = false;
  bool _isMapReady = false;
  bool _is3DMode = false; // Mặc định 2D giống AllTrails

  // --- DATA ---
  List<LatLng> _coords3D = [];          // Dữ liệu cho 3D Map
  List<fcoords.LatLng> _coords2D = [];  // Dữ liệu vẽ đường Polyline (Đã làm mịn qua OSRM)
  List<Map<String, dynamic>> _waypointsData = [];

  // Dữ liệu tương tác (được lấy mẫu từ đường đi chính)
  List<InteractivePoint> _interactivePoints = [];

  // Vị trí ngón tay đang chạm vào biểu đồ (null = không chạm)
  int? _hoverIndex;

  // API Key (MapTiler)
  final String _apiKey = (() {
    const fromDefine = String.fromEnvironment('MAPTILER_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;
    return dotenv.env['MAPTILER_KEY'] ?? 'your_maptiler_key_here';
  })();

  String get _style3DUrl => "https://api.maptiler.com/maps/outdoor-v2/style.json?key=$_apiKey";

  @override
  void initState() {
    super.initState();
    _prepareData();
  }

  // ==========================================
  // 2. XỬ LÝ DỮ LIỆU & OSRM SNAP TO TRAIL
  // ==========================================

  Future<void> _prepareData() async {
    try {
      final supabase = Supabase.instance.client;

      // A. Lấy toạ độ thô từ Database
      final routeResponse = await supabase
          .from('routes')
          .select('path_coordinates')
          .eq('id', widget.route.id)
          .single();

      List<fcoords.LatLng> rawPoints = [];
      if (routeResponse['path_coordinates'] != null) {
        final List<dynamic> rawCoords = routeResponse['path_coordinates'];
        rawPoints = rawCoords.map((c) => fcoords.LatLng(c[0], c[1])).toList();
      }

      // B. Lấy Waypoints
      final wptResponse = await supabase
          .from('route_waypoints')
          .select('*')
          .eq('route_id', widget.route.id);

      // --- C. MAGIC STEP: SNAP TO TRAIL VỚI OSRM ---
      // Biến các điểm thưa thớt thành đường mòn chi tiết
      List<fcoords.LatLng> detailedPath = [];
      if (rawPoints.length >= 2) {
        debugPrint("🌍 Đang gọi OSRM để làm mịn đường đi...");
        detailedPath = await _getDetailedPathFromOSRM(rawPoints);
      } else {
        detailedPath = rawPoints;
      }

      // Lưu dữ liệu đã làm mịn
      _coords2D = detailedPath;
      _coords3D = detailedPath.map((e) => LatLng(e.latitude, e.longitude)).toList();

      if (mounted) {
        setState(() {
          _waypointsData = List<Map<String, dynamic>>.from(wptResponse);
          _isMapReady = true;
        });

        // D. Tính toán độ cao & Interactive Points dựa trên đường đã làm mịn
        if (_coords2D.isNotEmpty) {
          _fetchRealElevation();
        } else {
          _generateSimulatedElevation();
        }
      }
    } catch (e) {
      debugPrint("🔴 Lỗi tải data: $e");
      _generateSimulatedElevation();
    }
  }

  // Hàm gọi OSRM (Open Source Routing Machine)
  Future<List<fcoords.LatLng>> _getDetailedPathFromOSRM(List<fcoords.LatLng> sparsePoints) async {
    // OSRM giới hạn số lượng điểm URL, nếu quá dài phải chia nhỏ hoặc lấy mẫu.
    // Ở đây ta giả định sparsePoints < 100 điểm.
    if (sparsePoints.isEmpty) return [];

    // Format: lon,lat;lon,lat
    String coordinatesString = sparsePoints
        .map((p) => "${p.longitude},${p.latitude}")
        .join(';');

    // Sử dụng profile 'foot' (đi bộ)
    final String url = "http://router.project-osrm.org/route/v1/foot/$coordinatesString?overview=full&geometries=geojson";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final geometry = data['routes'][0]['geometry'];
          final List<dynamic> coords = geometry['coordinates'];
          // GeoJSON là [lon, lat], FlutterMap cần [lat, lon]
          return coords.map((c) => fcoords.LatLng(c[1], c[0])).toList();
        }
      }
    } catch (e) {
      debugPrint("⚠️ OSRM Error: $e. Fallback to straight lines.");
    }
    return sparsePoints; // Fallback về đường thẳng nếu lỗi
  }

  // ==========================================
  // 3. XỬ LÝ ĐỘ CAO (ELEVATION)
  // ==========================================

  Future<void> _fetchRealElevation() async {
    // Lấy mẫu khoảng 60-80 điểm từ đường chi tiết để vẽ biểu đồ cho mượt
    // (Không cần vẽ hàng nghìn điểm OSRM lên biểu đồ, sẽ rất nặng)
    final List<fcoords.LatLng> sampledCoords = _sampleCoordinates(_coords2D, 80);

    try {
      final List<double> elevations = await _getElevationsFromApi(sampledCoords);

      List<InteractivePoint> tempPoints = [];
      double currentDistance = 0.0;
      const fcoords.Distance distanceCalc = fcoords.Distance();

      for (int i = 0; i < sampledCoords.length; i++) {
        if (i > 0) {
          currentDistance += distanceCalc.as(
            fcoords.LengthUnit.Kilometer,
            sampledCoords[i - 1],
            sampledCoords[i],
          );
        }

        tempPoints.add(InteractivePoint(
          coordinate: sampledCoords[i],
          elevation: elevations[i],
          distance: currentDistance,
        ));
      }

      if (mounted) {
        setState(() {
          _interactivePoints = tempPoints;
        });
      }
    } catch (e) {
      debugPrint("⚠️ API Elevation lỗi, chuyển sang giả lập: $e");
      _generateSimulatedElevation();
    }
  }

  void _generateSimulatedElevation() {
    if (_coords2D.isEmpty) return;

    // Vẫn lấy mẫu từ đường thật để marker chạy đúng
    final int pointsCount = 60;
    final List<fcoords.LatLng> sampledCoords = _sampleCoordinates(_coords2D, pointsCount);

    double maxGain = (widget.route.elevationGainM > 0) ? widget.route.elevationGainM.toDouble() : 500.0;
    double startElevation = 500;
    int seed = widget.route.id.hashCode;

    List<InteractivePoint> tempPoints = [];
    double currentDistance = 0.0;
    const fcoords.Distance distanceCalc = fcoords.Distance();

    for (int i = 0; i < sampledCoords.length; i++) {
      if (i > 0) {
        currentDistance += distanceCalc.as(fcoords.LengthUnit.Kilometer, sampledCoords[i - 1], sampledCoords[i]);
      } else {
        currentDistance = 0;
      }

      // Giả lập độ cao
      double progress = i / (pointsCount - 1);
      double mountainShape = sin(progress * pi) * maxGain;
      double hills = sin(progress * pi * 6) * (maxGain * 0.15);
      double pseudoRandom = sin(i * 13.0 + seed) * (maxGain * 0.05);

      double ele = startElevation + mountainShape + hills + pseudoRandom;
      if (ele < startElevation * 0.8) ele = startElevation * 0.8;

      tempPoints.add(InteractivePoint(
        coordinate: sampledCoords[i],
        elevation: ele,
        distance: currentDistance,
      ));
    }

    if (mounted) setState(() => _interactivePoints = tempPoints);
  }

  // Helper: Sampling & API
  List<fcoords.LatLng> _sampleCoordinates(List<fcoords.LatLng> input, int targetCount) {
    if (input.length <= targetCount) return input;
    List<fcoords.LatLng> result = [];
    int step = (input.length / targetCount).floor();
    for (int i = 0; i < input.length; i += step) {
      result.add(input[i]);
    }
    if (result.isNotEmpty && result.last != input.last) result.add(input.last);
    return result;
  }

  Future<List<double>> _getElevationsFromApi(List<fcoords.LatLng> points) async {
    const String url = 'https://api.open-elevation.com/api/v1/lookup';
    Map<String, dynamic> body = {
      "locations": points.map((p) => {"latitude": p.latitude, "longitude": p.longitude}).toList()
    };
    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['results'] as List).map<double>((item) => (item['elevation'] as num).toDouble()).toList();
    } else {
      throw Exception('API Error');
    }
  }

  // ==========================================
  // 4. MAP WIDGETS (2D & 3D)
  // ==========================================

  Widget _buildMap2D() {
    if (_coords2D.isEmpty) return const Center(child: CircularProgressIndicator());

    // Xác định vị trí Marker Sync
    fcoords.LatLng? hoverLoc;
    if (_hoverIndex != null && _hoverIndex! < _interactivePoints.length) {
      hoverLoc = _interactivePoints[_hoverIndex!].coordinate;
    }

    return fmap.FlutterMap(
      mapController: map2DController,
      options: fmap.MapOptions(
        initialCameraFit: fmap.CameraFit.bounds(
          bounds: fmap.LatLngBounds.fromPoints(_coords2D),
          padding: const EdgeInsets.all(50),
        ),
      ),
      children: [
        // 1. Nền bản đồ (Topo)
        fmap.TileLayer(
          urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.trekking.app',
        ),

        // 2. Đường đi (Màu đỏ hồng AllTrails)
        fmap.PolylineLayer(
          polylines: [
            fmap.Polyline(
              points: _coords2D,
              color: const Color(0xFFE91E63), // Màu đặc trưng của AllTrails
              strokeWidth: 5.0,
              strokeCap: StrokeCap.round, // Bo tròn đầu
              strokeJoin: StrokeJoin.round, // Bo tròn góc
            ),
          ],
        ),

        // 3. Các điểm mốc (Start/End/Waypoints)
        fmap.MarkerLayer(
          markers: [
            fmap.Marker(
              point: _coords2D.first, width: 80, height: 50,
              child: _build2DLabelMarker("START", Icons.circle, Colors.green),
            ),
            fmap.Marker(
              point: _coords2D.last, width: 80, height: 50,
              child: _build2DLabelMarker("END", Icons.flag, Colors.red),
            ),
            ..._waypointsData.map((wpt) => fmap.Marker(
              point: fcoords.LatLng(wpt['latitude'], wpt['longitude']),
              width: 100, height: 70,
              child: _build2DDetailMarker(wpt),
            )),
          ],
        ),

        // 4. SYNC MARKER (QUAN TRỌNG: Chỉ hiện khi chạm biểu đồ)
        if (hoverLoc != null)
          fmap.MarkerLayer(
            markers: [
              fmap.Marker(
                point: hoverLoc,
                width: 24, height: 24,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blueAccent, // Chấm xanh
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3), // Viền trắng đậm
                    boxShadow: [const BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // --- Các hàm Widget con cho Marker ---
  Widget _build2DLabelMarker(String label, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: color, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 10, color: color), const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
          ]),
        ),
        Icon(Icons.arrow_drop_down, color: color, size: 20),
      ],
    );
  }

  Widget _build2DDetailMarker(Map<String, dynamic> wpt) {
    Color color = Colors.blue; IconData icon = Icons.place;
    if (wpt['type'] == 'summit') { color = Colors.brown; icon = Icons.terrain; }
    if (wpt['type'] == 'danger') { color = Colors.red; icon = Icons.warning_rounded; }
    if (wpt['type'] == 'campsite') { color = Colors.green[700]!; icon = Icons.night_shelter; }

    return GestureDetector(
      onTap: () => _showWaypointInfo(wpt),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(color: Colors.white.withAlpha(230), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey[300]!)),
          child: Text(wpt['name'], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)]),
          child: Icon(icon, color: Colors.white, size: 12),
        ),
      ]),
    );
  }

  // --- Map 3D Logic (Giữ nguyên) ---
  void _onMap3DCreated(MapLibreMapController controller) { map3DController = controller; }
  Future<void> _onStyle3DLoaded() async {
    if (map3DController == null || _coords3D.isEmpty) return;
    await map3DController!.addLine(LineOptions(geometry: _coords3D, lineColor: "#E91E63", lineWidth: 4.0, lineOpacity: 0.9));
    await map3DController!.animateCamera(CameraUpdate.newLatLngBounds(_bounds3D(_coords3D), left: 50, right: 50, top: 100, bottom: 50));
    await Future.delayed(const Duration(milliseconds: 500));
    await map3DController!.animateCamera(CameraUpdate.tiltTo(70.0));
  }
  LatLngBounds _bounds3D(List<LatLng> list) {
    double? minLat, maxLat, minLng, maxLng;
    for (final l in list) {
      minLat = (minLat == null) ? l.latitude : min(minLat, l.latitude);
      maxLat = (maxLat == null) ? l.latitude : max(maxLat, l.latitude);
      minLng = (minLng == null) ? l.longitude : min(minLng, l.longitude);
      maxLng = (maxLng == null) ? l.longitude : max(maxLng, l.longitude);
    }
    return LatLngBounds(southwest: LatLng(minLat!, minLng!), northeast: LatLng(maxLat!, maxLng!));
  }

  // ==========================================
  // 5. CHART WIDGET & CUSTOM TOOLTIP
  // ==========================================

  Widget _buildElevationChart() {
    if (_interactivePoints.isEmpty) return const SizedBox(height: 100, child: Center(child: Text("Đang tải dữ liệu độ cao...")));

    // Lấy điểm đang chạm
    InteractivePoint? activePoint;
    if (_hoverIndex != null && _hoverIndex! < _interactivePoints.length) {
      activePoint = _interactivePoints[_hoverIndex!];
    }

    return SizedBox(
      height: 180,
      child: Stack(
        children: [
          // A. BIỂU ĐỒ
          Padding(
            padding: const EdgeInsets.only(top: 50),
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  // Tắt Tooltip mặc định xấu xí
                  touchTooltipData: const LineTouchTooltipData(getTooltipItems: _nullTooltip),
                  // Vẽ đường gióng và chấm tròn khi chạm
                  getTouchedSpotIndicator: (barData, spotIndexes) {
                    return spotIndexes.map((index) {
                      return TouchedSpotIndicatorData(
                        const FlLine(color: Colors.grey, strokeWidth: 1, dashArray: [4, 4]),
                        FlDotData(getDotPainter: (spot, percent, bar, index) {
                          return FlDotCirclePainter(radius: 5, color: Colors.white, strokeWidth: 2, strokeColor: Colors.blueAccent);
                        }),
                      );
                    }).toList();
                  },
                  // Callback cập nhật State
                  touchCallback: (event, response) {
                    if (response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
                      final index = response.lineBarSpots!.first.spotIndex;
                      if (_hoverIndex != index) {
                        setState(() => _hoverIndex = index);
                      }
                    } else if (event is FlTapUpEvent || event is FlPanEndEvent) {
                      setState(() => _hoverIndex = null);
                    }
                  },
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _interactivePoints.map((p) => FlSpot(p.distance, p.elevation)).toList(),
                    isCurved: true,
                    color: Colors.black87,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [Colors.green.withValues(alpha: 0.3), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                  ),
                ],
              ),
            ),
          ),

          // B. FLOATING TOOLTIP CARD (Nổi lên trên biểu đồ)
          if (activePoint != null)
            Positioned(
              top: 0, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildInfoItem("Distance", "${activePoint.distance.toStringAsFixed(1)} km"),
                      Container(width: 1, height: 24, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 16)),
                      _buildInfoItem("Elevation", "${activePoint.elevation.toStringAsFixed(0)} m"),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  // ==========================================
  // 6. GENERAL UI & ACTIONS
  // ==========================================

  Future<void> _confirmRoute(BuildContext context) async {
    setState(() => _isLoading = true);
    final navigator = Navigator.of(context);
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final achievementProvider = Provider.of<AchievementProvider>(context, listen: false);

    try {
      final supabase = Supabase.instance.client;
      final equipmentResponse = await supabase.from('equipment').select('id, name, category');
      final List<Map<String, dynamic>> equipmentList = List<Map<String, dynamic>>.from(equipmentResponse);
      final userProfile = { "difficulty": "Vừa phải", "group_size": 2, "interests": ["Cắm trại", "Trekking"], "duration": widget.route.durationDays };

      final geminiService = GeminiService();
      Map<String, dynamic> aiGeneratedChecklist = {};
      try {
        aiGeneratedChecklist = await geminiService.generateChecklist(route: widget.route, userProfile: userProfile, allEquipment: equipmentList);
      } catch (_) {
        if (mounted) NotificationService.showInfo('AI checklist không khả dụng, dùng mặc định.');
      }

      await tripProvider.confirmRouteForPlan(widget.route.id, checklist: aiGeneratedChecklist);
      await achievementProvider.incrementLocationVisit(widget.route.location);

      if (mounted) {
        NotificationService.showSuccess('Đã cập nhật chuyến đi.');
        navigator.push(MaterialPageRoute(builder: (_) => const PECScreen()));
      }
    } catch (e) {
      if (mounted) NotificationService.showError('Lỗi: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showWaypointInfo(Map<String, dynamic> wpt) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(wpt['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(wpt['description'] ?? 'Không có mô tả'),
          const SizedBox(height: 16),
          CustomButton(text: "Đóng", onPressed: () => Navigator.pop(context)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // MAP LAYER
          _is3DMode
              ? MapLibreMap(
            styleString: _style3DUrl,
            onMapCreated: _onMap3DCreated,
            onStyleLoadedCallback: _onStyle3DLoaded,
            initialCameraPosition: const CameraPosition(target: LatLng(21.0, 105.8), zoom: 10.0),
          )
              : _buildMap2D(),

          if (!_isMapReady && !_is3DMode)
            Container(color: Colors.white, child: const Center(child: CircularProgressIndicator())),

          // UI CONTROLS (Back & Toggle)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10, left: 16,
            child: CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context))),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10, right: 16,
            child: GestureDetector(
              onTap: () => setState(() => _is3DMode = !_is3DMode),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(30), boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 4)]),
                child: Row(children: [
                  Icon(_is3DMode ? Icons.map : Icons.view_in_ar, size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(_is3DMode ? "2D Map" : "3D Map", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ]),
              ),
            ),
          ),

          // BOTTOM SHEET & CHART
          DraggableScrollableSheet(
            initialChildSize: 0.45, minChildSize: 0.2, maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20)), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 40, height: 4, color: Colors.grey[300], margin: const EdgeInsets.symmetric(vertical: 10))),
                      Text(widget.route.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${widget.route.distanceKm} km • ${widget.route.elevationGainM}m gain • ${widget.route.durationDays} days', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(height: 20),
                      const Text("Biểu đồ độ cao:", style: TextStyle(fontWeight: FontWeight.w600)),

                      // BIỂU ĐỒ TƯƠNG TÁC
                      const SizedBox(height: 10),
                      _buildElevationChart(),

                      const SizedBox(height: 32),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), padding: const EdgeInsets.symmetric(vertical: 16)), onPressed: () => _confirmRoute(context), child: const Text('XÁC NHẬN LỘ TRÌNH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
                      const SizedBox(height: 32),
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
}

// Global helper to remove default tooltip
List<LineTooltipItem?> _nullTooltip(List<LineBarSpot> spots) {
  return List.generate(spots.length, (index) => null);
}