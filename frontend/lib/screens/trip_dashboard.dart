import 'package:flutter/material.dart';

const kBgColor = Color(0xFFF8F6F2);
const kPrimaryGreen = Color(0xFF38C148);

// The main, consolidated dashboard screen
class TripDashboard extends StatefulWidget {
  const TripDashboard({super.key});

  @override
  State<TripDashboard> createState() => _TripDashboardState();
}

class _TripDashboardState extends State<TripDashboard> {
  int _activeIndex = 0;
  final PageController _pageController = PageController();
  final List<String> _notes = [];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Navigate to the note editor screen and wait for a result
  void _navigateAndAddNote() async {
    final newNote = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const _NoteEditorScreen()),
    );
    if (newNote != null && newNote.isNotEmpty) {
      setState(() {
        _notes.add(newNote);
      });
    }
  }

  void _deleteNote(int index) {
    final note = _notes[index];
    setState(() {
      _notes.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("'$note' đã được xóa")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: SafeArea(
        child: Column(
          children: [
            const _TripHeader(),
            _TripTabs(
              activeIndex: _activeIndex,
              onTabChanged: (index) {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _activeIndex = index;
                  });
                },
                children: [
                  const _RouteTab(),
                  const _ItemsTab(),
                  _NotesTab(notes: _notes, onDeleteNote: _deleteNote),
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
}

// ====== Independent Note Editor Screen (within the same file) ======
class _NoteEditorScreen extends StatefulWidget {
  const _NoteEditorScreen();

  @override
  State<_NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<_NoteEditorScreen> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    const toolbarGrey = Color(0xFFE2E2E2);
    const primaryBlue = Color(0xFF007AFF);

    return Scaffold(
      backgroundColor: kBgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  // CircleAvatar removed
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: toolbarGrey,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.ios_share_rounded, size: 20),
                        SizedBox(width: 10),
                        Icon(Icons.more_horiz, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Text Editing Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Nhập ghi chú của bạn...',
                  ),
                ),
              ),
            ),
            // Bottom Toolbar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: toolbarGrey,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.grid_view_rounded),
                        SizedBox(width: 22),
                        Icon(Icons.attach_file_rounded),
                        SizedBox(width: 22),
                        Icon(Icons.edit_rounded),
                      ],
                    ),
                  ),
                  const Spacer(),
                  FloatingActionButton(
                    onPressed: () {
                      Navigator.of(context).pop(_controller.text);
                    },
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    child: const Icon(Icons.check_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ====== Main Dashboard Components ======

class _TripHeader extends StatelessWidget {
  const _TripHeader();

  @override
  Widget build(BuildContext context) {
    // ... (same as before)
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 12),
      child: Column(
        children: [
          const SizedBox(height: 4),
          // CircleAvatar removed
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Bảng thông tin',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ],
      ),
    );
  }
}

class _TripTabs extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTabChanged;

  const _TripTabs({required this.activeIndex, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    // ... (same as before)
    return Row(
      children: List.generate(3, (index) {
        final label = ['Lộ trình', 'Vật dụng', 'Ghi chú'][index];
        final bool isActive = index == activeIndex;
        return Expanded(
          child: GestureDetector(
            onTap: () => onTabChanged(index),
            child: Container(
              height: 44,
              margin: EdgeInsets.only(
                left: index == 0 ? 24 : 4,
                right: index == 2 ? 24 : 4,
              ),
              decoration: BoxDecoration(
                color: isActive ? kPrimaryGreen : const Color(0xFFE5E1DB),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ====== PageView Tabs ======

class _RouteTab extends StatelessWidget {
  const _RouteTab();

  @override
  Widget build(BuildContext context) {
    // ... (same as before)
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: AspectRatio(
              aspectRatio: 9 / 6,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  image: const DecorationImage(
                    image: AssetImage('assets/images/image 24.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 0),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Text(
                    'Pù Luông - Thanh Hóa',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '25 km · 700 m gain · Est. 2 days',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                  height: 80,
                  color: Colors.grey[200],
                  child: const Center(child: Text('Elevation chart placeholder')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Note',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text(
                  'Lorem ipsum dolor sit amet consectetur. Aenean pellentesque tellus senectus vitae et tempor dui.',
                  style: TextStyle(fontSize: 15, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {},
                child: const Text(
                  'XÁC NHẬN LỘ TRÌNH',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsTab extends StatelessWidget {
  const _ItemsTab();

  @override
  Widget build(BuildContext context) {
    // ... (same as before)
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: 6,
      itemBuilder: (context, index) {
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tên vật dụng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Tên cửa hàng', style: TextStyle(fontSize: 15)),
                    SizedBox(height: 8),
                    Text('xx.xxx.xxx đ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.redAccent)),
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

  const _NotesTab({required this.notes, required this.onDeleteNote});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80, left: 24, right: 24, top: 24),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return Dismissible(
          key: Key(note + index.toString()),
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
        );
      },
    );
  }
}
