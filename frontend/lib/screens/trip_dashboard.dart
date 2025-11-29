// Trip dashboard: single compact implementation
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../services/supabase_db_service.dart';
import '../services/plan_service.dart';
 
import '../models/plan.dart';

const kBgColor = Color(0xFFF8F6F2);
const kPrimaryGreen = Color(0xFF38C148);

class TripDashboard extends StatefulWidget {
  const TripDashboard({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: SafeArea(
        child: Column(
          children: [
            _TripHeader(onBackPressed: () => Navigator.of(context).pop()),
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
                  _ItemsTab(plan: _latestPlan),
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
    try {
      final latest = await _planService.getLatestPlan();
      if (!mounted) return;
      setState(() => _latestPlan = latest);
    } catch (err) {
      // ignore
    }
  }

  

  void _navigateAndAddNote() async {
    final res = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _NoteEditorScreen()));
    if (res is String && res.isNotEmpty) setState(() => _notes.add(res));
  }

  void _editNote(int idx) async {
    if (idx < 0 || idx >= _notes.length) return;
    final res = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _NoteEditorScreen(initialText: _notes[idx])));
    if (res is String && res.isNotEmpty) setState(() => _notes[idx] = res);
  }

  void _deleteNote(int idx) {
    if (idx < 0 || idx >= _notes.length) return;
    setState(() => _notes.removeAt(idx));
  }
}

// ====== Small local widgets used by the dashboard

class _TripHeader extends StatelessWidget {
  final VoidCallback? onBackPressed;
  const _TripHeader({super.key, this.onBackPressed});

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
          const SizedBox(width: 48),
        ]),
      ),
    ]);
  }
}

class _TripTabs extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTabChanged;
  const _TripTabs({super.key, required this.activeIndex, required this.onTabChanged});

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
  const _ItemsTab({super.key, this.plan});

  @override
  Widget build(BuildContext context) {
    final items = plan?.equipmentList ?? [];

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.black38),
              SizedBox(height: 12),
              Text('Chưa có vật dụng trong kế hoạch này.', style: TextStyle(fontSize: 16, color: Colors.black54)),
            ],
          ),
        ),
      );
    }

    // Render plan items
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final name = item.name;
        final source = item.store ?? '';
        final price = item.price ?? '';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9FBE4),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Text('PNG', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(source.toString(), style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 8),
                    Text(price.isNotEmpty ? price.toString() : '—', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.redAccent)),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
                  const Text('1', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.remove)),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}

class _NotesTab extends StatelessWidget {
  final List<String> notes;
  final void Function(int) onDeleteNote;

  final void Function(int) onEditNote;

  const _NotesTab({super.key, required this.notes, required this.onDeleteNote, required this.onEditNote});

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
  const _RouteTab({super.key, this.plan});

  @override
  Widget build(BuildContext context) {
    final routes = plan?.routes ?? [];
    if (plan == null) {
      return const Center(child: Text('Không có kế hoạch nào để xem trước.'));
    }
    if (routes.isEmpty) {
      return const Center(child: Text('Không có lộ trình được lưu trong kế hoạch này.'));
    }

    final r = routes.first;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (r.imageUrl != null && r.imageUrl!.isNotEmpty)
          Container(
            height: 180,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Colors.grey[200]),
            clipBehavior: Clip.hardEdge,
            child: Image.network(r.imageUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.photo))),
          ),
        const SizedBox(height: 12),
        Text(r.name ?? 'Lộ trình không tên', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 8, children: [
          if (r.distanceKm != null) Chip(label: Text('${r.distanceKm} km')),
          if (r.elevationGainM != null) Chip(label: Text('${r.elevationGainM} m độ cao')),
          if (r.durationDays != null) Chip(label: Text('${r.durationDays} ngày')),
        ]),
        const SizedBox(height: 12),
        if (plan?.description != null && plan!.description!.isNotEmpty) Text(plan!.description!),
      ],
    );
  }
}


class _NoteEditorScreen extends StatefulWidget {
  final String? initialText;
  const _NoteEditorScreen({super.key, this.initialText});

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
