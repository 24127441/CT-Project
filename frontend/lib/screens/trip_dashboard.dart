import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../services/supabase_db_service.dart';
import '../services/plan_service.dart';
import '../models/plan.dart';
import '../services/danger_labels.dart';

const kBgColor = Color(0xFFF8F6F2);
const kPrimaryGreen = Color(0xFF38C148);

class TripDashboard extends StatefulWidget {
  final int? planId;

  const TripDashboard({super.key, this.planId});

  @override
  State<TripDashboard> createState() => _TripDashboardState();
}

class _TripDashboardState extends State<TripDashboard> {
  final SupabaseDbService _db = SupabaseDbService();
  late final PlanService _planService = PlanService(db: _db);
  Plan? _latestPlan;
  int _activeIndex = 0;
  final PageController _pageController = PageController();
  final List<String> _notes = [];
  
  Map<String, Map<String, dynamic>> _equipmentDetails = {};

  @override
  void initState() {
    super.initState();
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
      debugPrint("Error launching URL: $e");
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
      debugPrint("Error fetching equipment details: $e");
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
                  _RouteTab(plan: _latestPlan),
                  _ItemsTab(
                    plan: _latestPlan, 
                    equipmentDetails: _equipmentDetails,
                    onBuyPressed: _launchBuyLink,
                  ),
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
      setState(() => _latestPlan = targetPlan);

      if (targetPlan != null) {
        _fetchEquipmentDetails(targetPlan);
      }

      try {
        final snapshot = await _db.getLatestDangerSnapshot();
        if (snapshot != null) {
          final pid = _latestPlan?.id;
          if (pid != null) {
            final ack = await _isAcknowledgedForPlan(pid);
            if (navigator.canPop()) navigator.pop();
            if (!ack) {
              final message = snapshot.toString();
              if (!mounted) return;
              await _showDangerWarning(navigator, message);
            }
            return;
          }
        }
        if (navigator.canPop()) navigator.pop();
      } catch (_) {
        if (navigator.canPop()) navigator.pop();
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

  Future<bool> _isAcknowledgedForPlan(int planId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('ack_plan_$planId') ?? false;
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
    }
  }

  Future<bool> _isDangerAcknowledged(int planId, String dangerKey) async {
    final prefs = await SharedPreferences.getInstance();
    final k = _dangerStorageKey(planId, dangerKey);
    return prefs.getBool(k) ?? false;
  }

  Future<void> _showDangerWarning(NavigatorState navigator, String message) async {
    if (!mounted) { return; }
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
                    final pid = _latestPlan?.id;
                    if (pid != null) { await _acknowledgePlan(pid); }
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
  }

  String _formatDangerValue(dynamic val) {
    if (val == null) return 'Không có cảnh báo.';
    if (val is String) {
      final s = val.trim();
      return s.isEmpty ? 'Không có cảnh báo.' : s;
    }
    if (val is Map) {
      final parts = <String>[];
      val.forEach((k, v) {
        final label = dangerLabelForKey(k.toString());
          if (v == true) {
            parts.add(label);
          } else if (v != null) {
            parts.add('$label: ${v.toString()}');
          }
      });
      return parts.isNotEmpty ? parts.join('\n') : 'Không có cảnh báo.';
    }
    if (val is List) {
      final parts = val.where((e) => e != null).map((e) => dangerLabelForKey(e.toString())).toList();
      return parts.isNotEmpty ? parts.join(', ') : 'Không có cảnh báo.';
    }
    return val.toString();
  }

  Future<void> _showDangerViewer() async {
    final ctx = context;
    try {
      final snapshot = await _db.getLatestDangerSnapshot();
      final message = _formatDangerValue(snapshot);
      final pid = _latestPlan?.id;
      final List<MapEntry<String, dynamic>> entries = [];
      if (snapshot is Map) {
        final Map snapMap = snapshot as Map;
        for (final e in snapMap.entries) {
          entries.add(MapEntry(e.key.toString(), e.value));
        }
      } else if (snapshot is List) {
        final List snapList = snapshot as List;
        for (var i = 0; i < snapList.length; i++) {
          entries.add(MapEntry(i.toString(), snapList[i]));
        }
      } else if (snapshot != null) {
        entries.add(MapEntry('message', snapshot));
      }

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
                                final label = dangerLabelForKey(e.key);
                                final val = e.value;
                                final reviewed = ackMap[e.key] ?? false;
                                final color = reviewed ? Colors.amber : Colors.redAccent;
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  leading: CircleAvatar(radius: 10, backgroundColor: color),
                                  title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: val != null ? Text(val.toString()) : null,
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
    } catch (e, st) {
      debugPrint('Error loading danger snapshot: $e');
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

  void _navigateAndAddNote() async {
    final res = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _NoteEditorScreen()));
    if (res is String && res.isNotEmpty) { setState(() => _notes.add(res)); }
  }

  void _editNote(int idx) async {
    if (idx < 0 || idx >= _notes.length) { return; }
    final res = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _NoteEditorScreen(initialText: _notes[idx])));
    if (res is String && res.isNotEmpty) { setState(() => _notes[idx] = res); }
  }

  void _deleteNote(int idx) {
    if (idx < 0 || idx >= _notes.length) { return; }
    setState(() => _notes.removeAt(idx));
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

class _ItemsTab extends StatelessWidget {
  final Plan? plan;
  final Map<String, Map<String, dynamic>> equipmentDetails;
  final Function(String, String?) onBuyPressed;

  const _ItemsTab({
    this.plan, 
    required this.equipmentDetails,
    required this.onBuyPressed,
  });

  @override
  Widget build(BuildContext context) {
    final equipmentMap = plan?.personalizedEquipmentList ?? {};

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

    return ListView(
      padding: const EdgeInsets.only(bottom: 80, top: 10),
      children: equipmentMap.entries.map((entry) {
        String category = entry.key;
        List<dynamic> items = entry.value is List ? entry.value : [];

        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 4, height: 18, 
                    decoration: BoxDecoration(color: kPrimaryGreen, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    category.toUpperCase(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 1.0),
                  ),
                ],
              ),
            ),
            ...items.map((item) => _buildSingleItem(item)),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
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
    if (equipmentDetails.containsKey(id)) {
      imageUrl = equipmentDetails[id]?['image_url'];
      buyLink = equipmentDetails[id]?['buy_link'];
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
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        child: Image.network(imageUrl, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.hiking, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              
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
                      onTap: () => onBuyPressed(name, buyLink),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withOpacity(0.5)),
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

class _NotesTab extends StatelessWidget {
  final List<String> notes;
  final void Function(int) onDeleteNote;
  final void Function(int) onEditNote;

  const _NotesTab({required this.notes, required this.onDeleteNote, required this.onEditNote});

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 80, left: 24, right: 24, top: 24),
        child: Center(child: Text('Chưa có ghi chú nào. Nhấn nút + để thêm.', style: TextStyle(color: Colors.black54))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80, left: 24, right: 24, top: 24),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return Dismissible(
          key: ValueKey('${note}_$index'),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) => onDeleteNote(index),
          background: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(right: 20.0),
                child: Icon(Icons.delete, color: Colors.white),
              ),
            ),
          ),
          child: GestureDetector(
            onTap: () => onEditNote(index),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(note, style: const TextStyle(fontSize: 16, color: Colors.black87)),
            ),
          ),
        );
      },
    );
  }
}

class _RouteTab extends StatelessWidget {
  final Plan? plan;
  const _RouteTab({this.plan});

  @override
  Widget build(BuildContext context) {
    // 🔍 Debugging to see what's wrong
    if (plan != null) {
      debugPrint("🛠️ [RouteTab] Plan Routes Count: ${plan!.routes.length}");
      if (plan!.routes.isNotEmpty) {
        debugPrint("🛠️ [RouteTab] First Route Name: ${plan!.routes.first.name}");
      }
    }

    final routes = plan?.routes ?? [];
    
    // Check if we have routes
    if (plan == null || routes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Không tìm thấy thông tin lộ trình.\nCó thể bạn chưa chọn lộ trình cho kế hoạch này.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              if (plan != null) ...[
                const SizedBox(height: 8),
                Text('Plan ID: ${plan!.id}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ]
            ],
          ),
        ),
      );
    }

    // Get the first route (assuming 1 plan = 1 route)
    final r = routes.first;

    return ListView(
      padding: const EdgeInsets.only(bottom: 80), // Add padding for bottom
      children: [
        // 1. Map / Image Placeholder
        Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            image: r.imageUrl != null && r.imageUrl!.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(r.imageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: Stack(
            children: [
              // Fallback Icon if no image
              if (r.imageUrl == null || r.imageUrl!.isEmpty)
                const Center(child: Icon(Icons.terrain, size: 64, color: Colors.white54)),
              
              // "Tùy chỉnh" Button Mockup
              Positioned(
                bottom: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.tune, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text("Tùy chỉnh", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              
              // 3D Button Mockup
              Positioned(
                bottom: 16,
                right: 16,
                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.8),
                      child: const Icon(Icons.layers_outlined, color: Colors.black),
                    ),
                    const SizedBox(height: 4),
                    const Text("3D", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 4, color: Colors.black)]))
                  ],
                ),
              )
            ],
          ),
        ),

        // 2. Info Section (White Background)
        Container(
          transform: Matrix4.translationValues(0, -20, 0), // Pull up overlap
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                r.name ?? 'Lộ trình không tên',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.2),
              ),
              const SizedBox(height: 8),
              
              // Stats Row
              Text(
                '${r.distanceKm ?? 0} km • ${r.elevationGainM ?? 0} m gain • Est. ${r.durationDays ?? 1} days',
                style: TextStyle(fontSize: 16, color: Colors.grey[700], fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),

              // Elevation Chart Placeholder
              Container(
                height: 100,
                width: double.infinity,
                // Simple drawing to mimic the chart
                child: CustomPaint(
                  painter: _ChartPainter(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("0.0 km", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  const Text("5.0 km", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  const Text("10.0 km", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  const Text("15.0 km", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text("${r.distanceKm ?? 20} km", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),

              const SizedBox(height: 24),

              // Description / Note
              const Text("Note", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                r.description ?? "Chưa có mô tả cho lộ trình này.",
                style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Simple Painter for the chart mockup
class _ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.8);
    // Draw a random-looking mountain path
    path.quadraticBezierTo(size.width * 0.2, size.height * 0.7, size.width * 0.4, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.6, size.height * 0.8, size.width * 0.8, size.height * 0.4);
    path.quadraticBezierTo(size.width * 0.9, size.height * 0.6, size.width, size.height * 0.3);

    canvas.drawPath(path, paint);
    
    // Draw fill (optional)
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    
    final fillPaint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..style = PaintingStyle.fill;
      
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NoteEditorScreen extends StatefulWidget {
  final String? initialText;
  const _NoteEditorScreen({this.initialText});

  @override
  State<_NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<_NoteEditorScreen> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.initialText ?? '';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm ghi chú'), backgroundColor: kPrimaryGreen),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          Expanded(child: TextField(controller: _ctrl, maxLines: null, expands: true, decoration: const InputDecoration(hintText: 'Nhập ghi chú...'))),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Hủy')),
            const SizedBox(width: 8),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryGreen),
                onPressed: () {
                  final t = _ctrl.text.trim();
                  Navigator.of(context).pop(t);
                },
                child: const Text('Lưu'))
          ])
        ]),
      ),
    );
  }
}