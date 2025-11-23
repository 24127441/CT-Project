import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import 'trip_info_waiting_screen.dart';

class TripInfoScreen extends StatefulWidget {
  const TripInfoScreen({super.key});

  @override
  State<TripInfoScreen> createState() => _TripInfoScreenState();
}

class _TripInfoScreenState extends State<TripInfoScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_currentPage == 0) {
              Navigator.pop(context);
            } else {
              _previousPage();
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thông tin chuyến đi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Bước ${_currentPage + 1}/5', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
        backgroundColor: const Color(0xFF388E3C),
        elevation: 0,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (page) {
          setState(() {
            _currentPage = page;
          });
        },
        children: const [
          _TripInfoPart1(),
          _TripInfoPart2(),
          _TripInfoPart3(),
          _TripInfoPart4(),
          _TripInfoPart5(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          if (_currentPage > 0)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 28),
              onPressed: _previousPage,
            ),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                final tripData = context.read<TripProvider>();
                if (_currentPage == 0 && (tripData.accommodation == null || tripData.paxGroup == null)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn đủ thông tin!'), backgroundColor: Colors.red));
                  return;
                }
                if (_currentPage == 1 && tripData.startDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ngày!'), backgroundColor: Colors.red));
                  return;
                }
                if (_currentPage == 2 && tripData.difficultyLevel == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn mức độ!'), backgroundColor: Colors.red));
                  return;
                }
                if (_currentPage == 4) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const WaitingScreen()));
                } else {
                  _nextPage();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_currentPage == 4 ? 'Xác nhận' : 'Tiếp theo', style: const TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// Placeholder for TripInfoPart1
class _TripInfoPart1 extends StatelessWidget {
  const _TripInfoPart1();

  @override
  Widget build(BuildContext context) {
    final tripData = context.watch<TripProvider>();
    return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Địa điểm trekking', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                onChanged: (value) {
                  context.read<TripProvider>().setSearchLocation(value);
                },
                decoration: InputDecoration(
                  hintText: 'Search (VD: Tà Xùa)',
                  prefixIcon: const Icon(Icons.search, color: Colors.black54),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12.0)),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade200,
                ),
                controller: TextEditingController(text: tripData.searchLocation),
              ),
              const SizedBox(height: 24),
              const Text('Loại hình nghỉ ngơi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildChoiceButton(
                label: 'Cắm trại',
                isSelected: tripData.accommodation == 'Cắm trại',
                onTap: () => context.read<TripProvider>().setAccommodation('Cắm trại'),
              ),
              const SizedBox(height: 12),
              _buildChoiceButton(
                label: 'Homestay',
                isSelected: tripData.accommodation == 'Homestay',
                onTap: () => context.read<TripProvider>().setAccommodation('Homestay'),
              ),
              const SizedBox(height: 12),
              _buildChoiceButton(
                label: 'Kết hợp',
                isSelected: tripData.accommodation == 'Kết hợp',
                onTap: () => context.read<TripProvider>().setAccommodation('Kết hợp'),
              ),
              const SizedBox(height: 24),
              const Text('Số người đi cùng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildChoiceButton(
                label: 'Đơn lẻ (1-2 người)',
                isSelected: tripData.paxGroup == 'Đơn lẻ (1-2 người)',
                onTap: () => context.read<TripProvider>().setPaxGroup('Đơn lẻ (1-2 người)'),
              ),
              const SizedBox(height: 12),
              _buildChoiceButton(
                label: 'Nhóm nhỏ (3-6 người)',
                isSelected: tripData.paxGroup == 'Nhóm nhỏ (3-6 người)',
                onTap: () => context.read<TripProvider>().setPaxGroup('Nhóm nhỏ (3-6 người)'),
              ),
              const SizedBox(height: 12),
              _buildChoiceButton(
                label: 'Nhóm đông (7+ người)',
                isSelected: tripData.paxGroup == 'Nhóm đông (7+ người)',
                onTap: () => context.read<TripProvider>().setPaxGroup('Nhóm đông (7+ người)'),
              ),
            ],
          ),
        ),
      );
  }
  Widget _buildChoiceButton({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4CAF50) : Colors.white,
          border: Border.all(color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade300, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Text(
            label,
            style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

// Placeholder for TripInfoPart2
class _TripInfoPart2 extends StatelessWidget {
  const _TripInfoPart2();
  
  @override
  Widget build(BuildContext context) {
    final tripData = context.watch<TripProvider>();
    final String formattedDate = tripData.startDate == null
        ? 'MM/DD/YYYY'
        : DateFormat('dd/MM/yyyy').format(tripData.startDate!);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thời gian chuyến đi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _selectDate(context, tripData),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.search, color: Colors.grey.shade600),
                        const SizedBox(width: 12),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 16,
                            color: tripData.startDate == null ? Colors.grey.shade600 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.calendar_month, color: Color(0xFF4CAF50)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (tripData.startDate == null)
              Text('❗️ Hãy chọn đủ các thông tin bắt buộc', style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, TripProvider tripData) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: tripData.startDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4CAF50),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF388E3C)),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      context.read<TripProvider>().setStartDate(picked);
    }
  }
}


// Placeholder for TripInfoPart3
class _TripInfoPart3 extends StatelessWidget {
  const _TripInfoPart3();

  @override
  Widget build(BuildContext context) {
    final tripData = context.watch<TripProvider>();
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildLevelCard(
              title: 'Người mới',
              description: 'Đường mòn rõ ràng, độ dốc nhẹ, phù hợp cho người mới bắt đầu. Khoảng cách ngắn (5-10km/ngày), độ cao dưới 1500m.',
              themeColor: const Color(0xFF4CAF50),
              value: 'Người mới',
              currentSelection: tripData.difficultyLevel,
              onTap: () => context.read<TripProvider>().setDifficultyLevel('Người mới'),
            ),
            const SizedBox(height: 16),
            _buildLevelCard(
              title: 'Có kinh nghiệm',
              description: 'Địa hình đa dạng, độ dốc vừa phải, yêu cầu thể lực tốt, có tập luyện thường xuyên. Khoảng cách 10-15km/ngày, độ cao 1500m-2500m.',
              themeColor: const Color(0xFFFF7043),
              value: 'Có kinh nghiệm',
              currentSelection: tripData.difficultyLevel,
              onTap: () => context.read<TripProvider>().setDifficultyLevel('Có kinh nghiệm'),
            ),
            const SizedBox(height: 16),
            _buildLevelCard(
              title: 'Chuyên nghiệp',
              description: 'Địa hình hiểm trở, độ dốc cao, yêu cầu có hiểu biết về kỹ thuật và tập luyện cường độ cao. Khoảng cách trên 15km/ngày, độ cao trên 2500m.',
              themeColor: const Color(0xFFF44336),
              value: 'Chuyên nghiệp',
              currentSelection: tripData.difficultyLevel,
              onTap: () => context.read<TripProvider>().setDifficultyLevel('Chuyên nghiệp'),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.yellow.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Lời khuyên:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nếu bạn là người mới, hãy bắt đầu với các tuyến đường dễ để làm quen với trekking. Luôn đi cùng người có kinh nghiệm trong những chuyến đầu tiên!',
                    style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard({
    required String title,
    required String description,
    required Color themeColor,
    required String value,
    required String? currentSelection,
    required VoidCallback onTap,
  }) {
    final bool isSelected = currentSelection == value;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? themeColor : Colors.white,
          border: Border.all(color: themeColor, width: 1.5),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? [BoxShadow(color: themeColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : themeColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder for TripInfoPart4
class _TripInfoPart4 extends StatelessWidget {
  const _TripInfoPart4();

  @override
  Widget build(BuildContext context) {
    final tripData = context.watch<TripProvider>();
    final List<String> _suggestedInterests = [
    'Rừng nguyên sinh', 'Ngắm hoàng hôn', 'Ăn chay',
    'Ngắm bình minh', 'Tiệc BBQ ngoài trời', 'Dị ứng hải sản',
    'Tìm hiểu văn hóa địa phương', 'Chụp ảnh phong cảnh',
    'Leo núi', 'Tắm suối', 'Thiền / Yoga'
  ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Yêu cầu cá nhân', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            onChanged: (value) => context.read<TripProvider>().setNote(value),
            maxLines: 6,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Nhập yêu cầu của bạn...',
              fillColor: const Color(0xFFF1F8E9),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
            ),
            controller: TextEditingController(text: tripData.note),
          ),
          const SizedBox(height: 24),
          if (tripData.selectedInterests.isNotEmpty) ...[
            const Text('Sở thích đã chọn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: tripData.selectedInterests.map((interest) {
                return _buildSelectedChip(context, interest);
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          const Text('Gợi ý sở thích', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _suggestedInterests.map((interest) {
              if (tripData.selectedInterests.contains(interest)) return const SizedBox.shrink();
              return _buildSuggestionChip(context, interest);
            }).toList(),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(BuildContext context, String label) {
    return GestureDetector(
      onTap: () => context.read<TripProvider>().toggleInterest(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('+ $label', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildSelectedChip(BuildContext context, String label) {
    return GestureDetector(
      onTap: () => context.read<TripProvider>().toggleInterest(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            const Icon(Icons.close, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

// Placeholder for TripInfoPart5
class _TripInfoPart5 extends StatelessWidget {
  const _TripInfoPart5();

  @override
  Widget build(BuildContext context) {
    final tripData = context.watch<TripProvider>();
    String displayDate = 'Chưa chọn';
    if (tripData.startDate != null) {
      displayDate = DateFormat('dd/MM/yyyy').format(tripData.startDate!);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          const Text(
            'Xác nhận thông tin',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hãy kiểm tra lại kĩ thông tin trước khi xác nhận!',
            style: TextStyle(color: Colors.black54, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: const Text(
              'Đặt tên cho chuyến đi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (value) {
              context.read<TripProvider>().setTripName(value);
            },
            decoration: InputDecoration(
              hintText: 'Ví dụ: Chuyến đi săn mây Tà Xùa',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.green),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.green),
              ),
              filled: true,
              fillColor: const Color(0xFFF9FFF9),
            ),
            controller: TextEditingController(text: tripData.tripName),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFC8D7C8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryItem('Địa điểm', tripData.searchLocation.isEmpty ? 'Chưa chọn' : tripData.searchLocation),
                _buildSummaryItem('Thời gian', displayDate),
                _buildSummaryItem('Ngân sách', 'Chưa cấu hình'),
                _buildSummaryItem('Loại hình ngủ nghỉ', tripData.accommodation ?? 'Chưa chọn'),
                _buildSummaryItem('Số người', tripData.paxGroup ?? 'Chưa chọn'),
                _buildSummaryItem('Độ khó', tripData.difficultyLevel ?? 'Chưa chọn'),
                if (tripData.selectedInterests.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: _buildSummaryItem('Sở thích', tripData.selectedInterests.join(', ')),
                  ),
                if (tripData.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: _buildSummaryItem('Ghi chú', tripData.note),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.green.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 15,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
